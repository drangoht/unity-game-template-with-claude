This folder is copied as-is next to `index.html` in the web build.

Put here what the PAGE consumes, and nothing else: `favicon.png`, a waiting image, a font for the
loading screen. These files do not go through Unity: they are neither imported, nor compressed, nor
referenced by GUID -- the HTML designates them by relative path (`TemplateData/favicon.png`).

Do not put a game asset here: what Unity must load goes into `Assets/Resources/` (by path) or
`Assets/StreamingAssets/` (raw files downloaded at startup).

For a free and redistributable font, take the `.ttf` **and its `OFL.txt`** from the `google/fonts`
repository (SIL Open Font License):
`https://raw.githubusercontent.com/google/fonts/main/ofl/<family>/<File>.ttf`
