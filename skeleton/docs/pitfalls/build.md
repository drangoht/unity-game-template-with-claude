# Pitfalls -- Build


**WARNING: launching Unity with the `&` operator in PowerShell returns IMMEDIATELY without doing
anything.** [inherited] No log, empty `$LASTEXITCODE`, and the script carries on as if all were well.
Use `Start-Process -Wait`. *A launch that fails silently is worse than a launch that fails.*

**WARNING: a zero exit code does not tell "built" apart from "nothing to do".** Require an **explicit
success phrase** in the log (that is what `tools/build.ps1` does).

**WARNING: worse -- Unity exits with exit code 0 while the build FAILED.** Observed on a Windows
build whose log says `Build Finished, Result: Failure` (6 errors) then, thirty lines further down,
`Exiting batchmode successfully now!` and a code 0. A script that trusts the exit code packages and
publishes an incomplete build folder **without anything warning it**. The success phrase in the log is
the only reliable signal.

**WARNING: the DATE of a build artefact proves nothing**: Unity builds incrementally, an identical
file is **not rewritten**. A timestamp older than the build is normal. The first freshness safeguard
written on that basis failed on perfectly valid builds.

**WARNING: the Windows metadata of a Unity `.exe` describes the ENGINE** ("6000.5.6f1"), not the game.
A check comparing the release version to that metadata always fails.

**WARNING: only the EMBEDDED version settles it**, because it is set just before the build. Hence
`build_stamp.json`, written **by** the build: it cannot announce a version the build did not set. **A
release has already shipped the binary of the previous version without a single error being raised**
-- this check is what prevents it.

**WARNING: a build stamp written by the PUBLISHING script outlives its release.** [inherited] Written
only at publish time, the file then stays in place, and every later local build shows the SHA of the
last release. *A freshness safeguard that lies is worse than no safeguard, since people trust it.* It
is therefore set by the **build** (`BuildTools.StampGitSha`) and ignored by git -- it is an artefact,
not a source.

**WARNING: the command-line build fails if the Unity editor is open** ("another Unity instance is
running"). Check `Get-Process Unity` or `Temp\UnityLockfile` -- and **never kill the editor**: wait,
or work on a copy of `Assets` + `Packages` + `ProjectSettings`.

**WARNING: the first build of a platform reimports every asset** (several tens of minutes); the
following ones are fast. Set the timeout accordingly.

**WARNING: the regenerated scene produces a huge and meaningless diff.** `SceneBuilder` renumbers
every `fileID`: thousands of lines added and as many removed for an identical scene. Discard it
(`git checkout --`) **unless `SceneBuilder.cs` has changed**. Without the matching exclusion in
`BuildTools.HasLocalChanges`, every build would declare itself made from a modified tree.
