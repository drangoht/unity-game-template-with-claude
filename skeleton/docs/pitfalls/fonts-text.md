# Pitfalls -- Fonts and text


**WARNING: Unity's fallback on missing glyphs exists ONLY on desktop.** [inherited]
With a dynamic font, `Text` (uGUI) looks in the **system fonts** for what the font does not contain:
arrow glyphs come out correctly on Windows with a font that contains **none** of them. A browser
offers no system font: the **WebGL build loses them silently** -- no white box, no warning, the text
simply closes over the void. Observed on Smily Volley: truncated help banners, invisible scroll
indicators.

The fallback declared at import time (`fallbackFontReferences` -> `LegacyRuntime.ttf`, set by script
on the `TrueTypeFontImporter`) **changes nothing**: tried, rebuilt, the arrows stayed missing.

**What works**: only write characters the font contains ("Up/Down" rather than arrow glyphs) and
**draw the symbols as sprites**. Check the `cmap` table before trusting it -- a 20-line Python script
reads it and answers yes or no. And check it **in the browser**, not by reasoning.

**Free fonts**: take the `.ttf` **and its `OFL.txt`** from the `google/fonts` repository (SIL OFL):
`https://raw.githubusercontent.com/google/fonts/main/ofl/<family>/<File>.ttf`.
WARNING: many families now exist only in a **variable version** (`Fredoka[wdth,wght].ttf`): list the
folder before guessing the URL
(`https://api.github.com/repos/google/fonts/contents/ofl/<family>`). WARNING: the
`fonts.googleapis.com/css` API returns a URL whose file **is not a valid TTF** (signature `f89b`): a
real TTF starts with `00 01 00 00`, and a 39 KB file containing HTML is a disguised 404 page.
