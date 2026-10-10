# `ProjectSettings/` -- what the template puts here, and why

Unity generates this folder itself at the first import. Two files are shipped in advance, because a
fresh project either does not build without them or does not open with the right editor.

## `ProjectVersion.txt`

Declares the project's Unity version. It is the file Unity Hub reads to decide which editor to open,
and the one `tools/environment.ps1` reads to choose among the installed editors.
`tools/new-game.ps1` writes into it the version of the editor actually found on the machine.

## `BurstAotSettings_StandaloneWindows.json` -- Burst disabled for the Windows build

**What happens without it**: the Windows build of a fresh project fails at the very last step
(`GenerateNativePluginsForAssemblies`), on

```
BuildFailedException: Burst compiler failed running
Error: Failed to find entry-points:
  Failed to resolve assembly 'Unity.InternalAPIEngineBridge.RenderPipelines.Core.Runtime.Shared'
  in directories: Library\Bee\artifacts\WinPlayerBuildProgram\ManagedStripped
```

The Burst compiler is looking for an internal URP assembly that the *stripping* step has just
removed. Nothing in the project asks for Burst: it arrives as a transitive dependency of URP and of
the Input System.

**Why it is nasty**: Unity nevertheless exits with **exit code 0** ("Exiting batchmode successfully
now!"). A script trusting the exit code would publish an incomplete build folder. That is what
justifies `tools/build.ps1` requiring the success phrase written by `BuildTools` in the log, and not
just a zero exit code.

**What works**: `"EnableBurstCompilation": false` for the Standalone target. A 2D game whose logic
fits in ordinary C# classes has no Burst job to compile -- nothing is lost.

WARNING: the day the project really uses the C# Job System or the native Collections, set it back to
`true` and deal with the stripping error (`link.xml`, or a more permissive `managedStrippingLevel`)
rather than keeping Burst off without knowing it.

Observed on Unity 6000.5.6f1, URP 17.5.0, Burst 1.8.29.
