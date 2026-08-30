"""Launches the Windows build, injects real input into it, and captures its window.

Why this tool exists
--------------------
"It compiles" proves nothing about a game. An inverted key mapping, a character stuck in a wall, a
ball flying off screen, a menu that does not react: none of these defects show up at compile time,
and all of them are visible in thirty seconds on a screenshot of the running game.

This script makes that possible **without opening the editor and without a human hand** -- so
inside an agent loop. Every safeguard it contains matches a wrong conclusion that has already been
drawn.

Usage
-----
    py tools/drive_game.py --launch --wait 4 --capture docs/check.png
    py tools/drive_game.py --keys "enter,down,down,enter" --capture docs/menu.png
    py tools/drive_game.py --hold right --duration 1.2 --capture docs/movement.png
    py tools/drive_game.py --close

Screenshots are scaled down to 960 px wide (see CAPTURE_WIDTH): they are read by an agent, and an
image costs in proportion to its area. Use `--full-resolution` for fine detail.

Pitfalls already paid for (do not rediscover them)
--------------------------------------------------
1. **Focus is THE blocking point.** `SetForegroundWindow` alone fails from a non-interactive shell:
   the window stays in the background and Unity then receives **no key at all**. What works:
   injecting a real click into the window, which earns it the foreground legitimately. Always check
   `GetForegroundWindow() == hwnd` before concluding anything.
2. **`keybd_event` must carry the SCAN CODE**, not just the virtual key code: Unity's input system
   reads the raw input.
3. **Arrow keys require `KEYEVENTF_EXTENDEDKEY`**: without it, their scan code is the numeric
   keypad's and the key is silently lost.
4. **The very first key after launch is lost** (the game has just taken focus): this script
   therefore always primes with a throwaway key.
5. **The Unity splash screen lasts ~2 s**: capturing before that is capturing a logo.
6. **The Windows firewall opens a modal alert on the first launch of EVERY new exe path.** It
   steals focus and greys out the window. Close it (`Get-Process PickerHost`) then relaunch, or
   always rebuild to the same path.
7. **Do not hard-code the position of the elements you aim at.** A menu that moved makes the clicks
   land in the void -- with no error, just a screenshot showing something other than expected.
8. **Settings are persistent (PlayerPrefs).** Driving an option with N presses on Right gives a
   result *relative* to the previous session: go back to a known extreme first.
"""

from __future__ import annotations

import argparse
import ctypes
import ctypes.wintypes as wt
import pathlib
import subprocess
import sys
import time

EXE = pathlib.Path(__file__).resolve().parent.parent / "Build" / "Windows" / "__NAMESPACE__.exe"
TITLE = "__GAME_NAME__"

user32 = ctypes.windll.user32
user32.SetProcessDPIAware()

# --- Key table ---------------------------------------------------------------------
# (virtual key code, scan code, extended key?). The scan codes are those of a QWERTY keyboard --
# see the AZERTY note below.
KEYS = {
    "enter":  (0x0D, 0x1C, False),
    "space":  (0x20, 0x39, False),
    "escape": (0x1B, 0x01, False),
    "tab":    (0x09, 0x0F, False),
    "left":   (0x25, 0x4B, True),
    "up":     (0x26, 0x48, True),
    "right":  (0x27, 0x4D, True),
    "down":   (0x28, 0x50, True),
}
# The letters: scan codes of the QWERTY positions.
# WARNING: ON AN AZERTY KEYBOARD, Unity's `Key.A` falls under the key marked Q, `Key.W` under Z,
# and so on. Unity always designates a PHYSICAL POSITION, never the printed character. The letters
# whose position differs between AZERTY and QWERTY (A, Q, Z, W, M) are therefore to be avoided for
# a global shortcut: prefer Tab, R, the digits or the arrow keys.
for _letter, _vk, _sc in [
    ("a", 0x41, 0x1E), ("d", 0x44, 0x20), ("e", 0x45, 0x12), ("q", 0x51, 0x10),
    ("r", 0x52, 0x13), ("s", 0x53, 0x1F), ("w", 0x57, 0x11), ("z", 0x5A, 0x2C),
]:
    KEYS[_letter] = (_vk, _sc, False)

KEYEVENTF_EXTENDEDKEY = 0x0001
KEYEVENTF_KEYUP = 0x0002
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004


# --- Window ------------------------------------------------------------------------

def find_window() -> int | None:
    """Returns the handle of the game window, or None."""
    found = []

    @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def callback(hwnd, _):
        if not user32.IsWindowVisible(hwnd):
            return True
        length = user32.GetWindowTextLengthW(hwnd)
        if length == 0:
            return True
        buffer = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, buffer, length + 1)
        if TITLE.lower() in buffer.value.lower():
            found.append(hwnd)
            return False
        return True

    user32.EnumWindows(callback, 0)
    return found[0] if found else None


def wait_for_window(timeout: float = 30.0) -> int:
    """Waits for the game window to appear. Raises if it never comes."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        hwnd = find_window()
        if hwnd:
            return hwnd
        time.sleep(0.3)
    raise RuntimeError(
        f"Window '{TITLE}' not found after {timeout:.0f} s. "
        "Did the game crash at startup? Read the player's -logFile."
    )


def rectangle(hwnd: int) -> tuple[int, int, int, int]:
    rect = wt.RECT()
    user32.GetWindowRect(hwnd, ctypes.byref(rect))
    return rect.left, rect.top, rect.right, rect.bottom


def take_focus(hwnd: int) -> bool:
    """
    Brings the window to the foreground -- with a REAL click at its centre.

    `SetForegroundWindow` alone is refused to a non-interactive process: Windows merely flashes the
    taskbar. A click, on the other hand, gives focus legitimately. The cursor is put back where it
    was.
    """
    HWND_TOPMOST, SWP_NOMOVE, SWP_NOSIZE = -1, 0x0002, 0x0001
    user32.SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE)
    user32.SetForegroundWindow(hwnd)

    if user32.GetForegroundWindow() == hwnd:
        return True

    left, top, right, bottom = rectangle(hwnd)
    previous = wt.POINT()
    user32.GetCursorPos(ctypes.byref(previous))

    user32.SetCursorPos((left + right) // 2, (top + bottom) // 2)
    time.sleep(0.05)
    user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.03)
    user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
    time.sleep(0.25)

    user32.SetCursorPos(previous.x, previous.y)
    return user32.GetForegroundWindow() == hwnd


# --- Input -------------------------------------------------------------------------

def _send(name: str, release: bool) -> None:
    if name not in KEYS:
        raise SystemExit(f"Unknown key: '{name}'. Known: {', '.join(sorted(KEYS))}")
    vk, scan, extended = KEYS[name]
    flags = KEYEVENTF_EXTENDEDKEY if extended else 0
    if release:
        flags |= KEYEVENTF_KEYUP
    user32.keybd_event(vk, scan, flags, 0)


def press(name: str, duration: float = 0.06) -> None:
    """A single press, held for `duration` second(s) then released."""
    _send(name, False)
    time.sleep(duration)
    _send(name, True)


def prime() -> None:
    """
    Sends a throwaway key.

    The very first key after taking focus is systematically lost -- the game has just regained
    control and its input system has not resynchronised its devices yet. Without this priming, the
    first press of a scenario disappears and the result looks random.
    """
    press("down")
    time.sleep(0.15)
    press("up")
    time.sleep(0.15)


# --- Capture -----------------------------------------------------------------------

# Recording width for screenshots. A screenshot is READ by an agent, and an image costs in
# proportion to its area: 1280x720 is worth ~1200 tokens, 960x540 ~700, for the same information
# (a menu is displayed, the snake is in the right place, the health bar is empty).
# Pass --full-resolution when a pixel-level detail must be judged (aliasing, tiny text).
CAPTURE_WIDTH = 960


def capture(hwnd: int, destination: pathlib.Path, width: int = CAPTURE_WIDTH) -> None:
    """
    Captures the game WINDOW, never the whole screen.

    Framing on the window avoids two reading mistakes: a desktop wallpaper taken for scenery, and
    pixel measurements skewed by whatever spills out of the game.
    """
    try:
        from PIL import Image, ImageGrab
    except ImportError:
        raise SystemExit(
            "Pillow is required for capturing: py -m pip install pillow"
        )

    if not take_focus(hwnd):
        print("!! The window does NOT have focus: the capture may show something else.",
              file=sys.stderr)

    time.sleep(0.2)
    image = ImageGrab.grab(bbox=rectangle(hwnd), all_screens=True)
    raw_size = (image.width, image.height)

    if width and image.width > width:
        height = round(image.height * width / image.width)
        image = image.resize((width, height), Image.LANCZOS)

    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination)
    if (image.width, image.height) != raw_size:
        print(f"Capture: {destination} ({image.width} x {image.height}, "
              f"scaled down from {raw_size[0]} x {raw_size[1]})")
    else:
        print(f"Capture: {destination} ({image.width} x {image.height})")


# --- Life cycle --------------------------------------------------------------------

def launch() -> int:
    """
    Launches the game windowed. Full screen makes capturing and regaining focus unreliable.
    """
    if not EXE.exists():
        raise SystemExit(
            f"Build missing: {EXE}\n"
            "Build it first: powershell -File tools/build.ps1"
        )

    log = EXE.parent / "player.log"
    process = subprocess.Popen([
        str(EXE),
        "-screen-width", "1280",
        "-screen-height", "720",
        "-screen-fullscreen", "0",
        "-logFile", str(log),
    ])
    print(f"Launched (pid {process.pid}) - log: {log}")
    return process.pid


def close() -> None:
    hwnd = find_window()
    if not hwnd:
        print("No game window.")
        return
    user32.PostMessageW(hwnd, 0x0010, 0, 0)  # WM_CLOSE
    print("Close requested.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Drives the Windows build of the game.")
    parser.add_argument("--launch", action="store_true", help="launch the executable windowed")
    parser.add_argument("--wait", type=float, default=4.0,
                        help="seconds before acting (the Unity splash lasts ~2 s)")
    parser.add_argument("--keys", default="",
                        help="comma-separated sequence of presses (e.g. 'enter,down,enter')")
    parser.add_argument("--hold", default="", help="a single key held down")
    parser.add_argument("--duration", type=float, default=0.9, help="hold duration, in seconds")
    parser.add_argument("--capture", default="", help="path of the PNG to write")
    parser.add_argument("--full-resolution", action="store_true", dest="full_resolution",
                        help="do not scale the capture down (expensive to read: only ask for it to "
                             "judge a pixel-level detail)")
    parser.add_argument("--close", action="store_true", help="close the game window")
    args = parser.parse_args()

    if args.close:
        close()
        return 0

    if args.launch:
        launch()

    hwnd = wait_for_window()
    time.sleep(args.wait)

    if not take_focus(hwnd):
        print("!! Cannot give focus to the game: the injected keys will be lost.",
              file=sys.stderr)
        print("   Check that no dialog box (Windows firewall) is covering it.",
              file=sys.stderr)
        return 1

    if args.keys or args.hold:
        prime()

    for name in [k.strip() for k in args.keys.split(",") if k.strip()]:
        press(name)
        time.sleep(0.25)

    if args.hold:
        _send(args.hold, False)
        time.sleep(args.duration)
        _send(args.hold, True)

    if args.capture:
        capture(hwnd, pathlib.Path(args.capture),
                width=0 if args.full_resolution else CAPTURE_WIDTH)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
