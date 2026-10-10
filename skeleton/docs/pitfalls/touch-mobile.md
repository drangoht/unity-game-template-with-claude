# Pitfalls -- Touch and mobile


**WARNING: half the mobile port lives in `index.html`, not in Unity.** [inherited] Zoom, scrolling,
the back gesture from the edge, the long press that opens a system menu, the URL bar that eats the
bottom of the screen (hence the controls that are there): Unity can do nothing about what happens
**before** it. None of these defects is visible in the editor, none raises an error, and each of them
makes the game unplayable with a finger. The project template deals with all of them -- do not undo
them.

**WARNING: `maxTouchPoints` is the only reliable test to detect a mobile**: the user agent string
lies (desktop mode on a phone, an iPad declaring itself a Mac).

**WARNING: use `dvh` and not `vh`** for the canvas height: `vh` ignores the retracting URL bar, and
the bottom of the game ends up hidden behind it.

**WARNING: desktop Chrome provides NO `Touchscreen`.** [inherited] `Touchscreen.current` stays `null`
and any touch code exits immediately. Dispatching real `TouchEvent`s in JS is useless -- the event
propagates, but the engine has no device to file it under, and **no error** says so. Only a `?touch`
mode (which calls `TouchSimulation.Enable()`) makes touch testable.
