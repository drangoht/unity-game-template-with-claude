# Pitfalls -- Audio


**WARNING: an entry missing from the lookup table is SILENT.** [inherited] Fourteen weapons were,
without anything saying so. Write an audit that compares the content list to the sound table.

**WARNING: the browser lets no sound start before a user gesture.** Unity opens its audio context
suspended: without the wake-up placed in the WebGL template, the music only triggers by the chance of
a click.

**WARNING: a `PlayOneShot` log proves an intent, not a sound.** To prove the audio leaves the mixer:
`AudioListener.GetOutputData(buffer, 0)` and log the RMS.
