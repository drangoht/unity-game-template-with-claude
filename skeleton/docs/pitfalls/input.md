# Pitfalls -- Input


**WARNING: `KeyCode` and `Key` designate a POSITION on a QWERTY keyboard**, never the printed
character. On an AZERTY keyboard, `Key.A` / `Key.D` / `Key.W` place the controls under the keys marked
**Q / D / Z**. That is the intended result, not a bug. Corollary: avoid `A`, `Q`, `Z`, `W`, `M` for
global shortcuts -- prefer `Tab`, `R`, the digits or the arrow keys, whose position is common to both
layouts. **This pitfall was only discovered by injecting real keys.**

**WARNING: `InputSystemUIInputModule` and not `StandaloneInputModule`.** With the Input System package
active, the old module receives nothing: the UI simply stops responding, with no error.

**WARNING: the very first key after taking focus is lost**, on the Windows build as in the browser.
Always send one for nothing before measuring anything.
