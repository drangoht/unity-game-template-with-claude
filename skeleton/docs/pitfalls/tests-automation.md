# Pitfalls -- Headless tests and game driving


See the **`/verify-in-game`** skill for the full procedure. The pitfalls, in short:

- **Focus is THE blocking point**: out of focus, Unity receives no key and no mouse movement -- the
  test lies silently. `SetForegroundWindow` alone fails from a non-interactive shell; only a **real
  click** gives focus legitimately.
- **`keybd_event` must carry the scan code** (Unity reads the raw input), and **arrow keys require
  `KEYEVENTF_EXTENDEDKEY`** -- without it, their scan code is the numeric keypad's and the key is
  silently lost.
- **`SetCursorPos` puts nothing into the input stream**: use `SendInput` with
  `MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE`, coordinates normalised over 0..65535.
- **An instant press only tests `wasPressedThisFrame`**: anything requiring a hold needs a real hold.
  Concluding "the arrow keys do not work" from an instant press is wrong.
- **The Unity splash lasts ~2 s**, and **the Windows firewall opens a modal alert on the first launch
  of every new exe path** -- it steals focus and greys out the window.
- **Do not hard-code the position of the elements you aim at**: an overhaul moves them, and the clicks
  land in the void with no error at all.
- **PlayerPrefs are persistent**: driving an option with N presses gives a result *relative* to the
  previous session.
- **Pixel analysis thresholds**: two false conclusions in a row (a centroid contaminated by a piece of
  scenery, a count of light pixels that was counting the HUD text). Frame outside the HUD, exclude
  every known element by its hue, **then look at the image**.
- **What is pure geometry cannot be proven by playing**: a throwaway file in `Assets/Editor` called
  with `-executeMethod` logs the bounds to within two pixels. That is what caught a zone three times
  too wide whose formula read perfectly.
