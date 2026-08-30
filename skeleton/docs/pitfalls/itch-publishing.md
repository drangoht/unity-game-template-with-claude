# Pitfalls -- Publishing (itch.io)


**WARNING: the "Save" button clicked by element reference does not save.** [inherited] The page
simply scrolls back to the top, with no error and no banner, and the public page keeps the old text.
Wait for the `.global_flash` "Saved" banner to appear -- it is the only sign that tells a submission
from a scroll.

**WARNING: the public page is served from a cache.** [inherited] Re-reading it right after a
*successful* save shows it unchanged. Any URL parameter (`?v=2`) is enough to settle it; without it
one concludes a failure that did not happen, and re-edits for nothing.

**WARNING: itch's text editor is a Redactor.** [inherited] The content lives in `.redactor-layer`
(contenteditable), backed by a hidden `textarea`. Writing to the layer does not always synchronise
the textarea -- **on the devlog form, never**. A devlog submitted without writing both ships with a
correct title and an **empty body**.

**WARNING: an itch `<select>` has only one option in the DOM**: they are Selectize widgets. Go through
`element.selectize.setValue(...)`, never through a click -- which opens a native menu and **freezes
the screenshots**.

**WARNING: a devlog not ticked "Published" stays a draft without saying so.**

**WARNING: three decisive page settings are in NO file of the repo** [inherited] and are therefore
never visible when re-reading the code: the **Mobile friendly** checkbox (it alone decides what itch
offers a visitor on a phone), the **Classification** tab (including the player count), and the
declared **orientation**. All three were wrong up to version 1.1.0 of Smily Volley.

**WARNING: the itch.io iframe is cross-origin** (`html-classic.itch.zone`): neither injected clicks
nor injected keys get into it. To exercise the **published** build, open the iframe URL directly in a
tab.
