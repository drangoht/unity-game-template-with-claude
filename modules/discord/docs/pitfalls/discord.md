# Pitfalls -- Discord Rich Presence

Optional module (`new-game.ps1 -Discord`): `Assets/Scripts/Platform/DiscordPresence.cs`,
`Assets/Plugins/DiscordRPC.dll` (Lachee/discord-rpc-csharp 1.2.1, MIT), `Assets/Editor/PluginPlatforms.cs`,
the `com.unity.nuget.newtonsoft-json` package.

## Setting it up (once per game)

1. discord.com/developers/applications > New Application, named like the game: that name is what
   Discord shows after "Playing". Copy the **Application ID** into `AppId` in `DiscordPresence.cs`.
2. Rich Presence > Art Assets: upload two images (512x512 min.) keyed `__GAME_SLUG__` (large) and
   `__GAME_SLUG___small` (small). Discord can take several minutes to serve new assets.
3. Call `DiscordPresence.SetStatus("What the player does", "progress")` on CHANGES of phase.
4. Offer the switch in the options **only if `DiscordPresence.Available`**, bound to
   `DiscordPresence.Enabled` (it persists and applies itself).
5. Check on the Windows build, Discord running: `[DiscordPresence] connected` in `Player.log`, and
   the status visible on your profile.
6. Credit the library (MIT) where the game lists its third-party content.

## Entries

**WARNING: the presence exists only in a desktop build.** [inherited] It goes through a local named
pipe to the installed client; a web page has neither. The DLL is excluded from WebGL by its `.meta`,
and `PluginPlatforms` fails the build once (after fixing it) if that setting was lost -- a regenerated
`.meta` silently goes back to "Any Platform". On a web-only game, the module is useless: publish a
Windows build too, or do not install it.

**WARNING: a switch that drives nothing.** [inherited] In Chimera Protocol, the `Discord` setting was
saved, migrated, read back -- and drove nothing: the presence itself had been lost in a port. The
save made the feature look present. Hence `Enabled` living in `DiscordPresence` itself, and
`Available` hiding the switch where the presence cannot exist (web, or no Application ID).

**WARNING: without Newtonsoft.Json, the LINKER fails, not the compiler.** [inherited] DiscordRPC
depends on it. Without the `com.unity.nuget.newtonsoft-json` package, everything compiles and the
build stops at the linking step, with a message about the project's assemblies, not about the
missing dependency.

**WARNING: Discord silently drops updates beyond one every 15 s.** The last status sent may never be
displayed. `SetStatus` filters identical statuses; never call it from `Update()` with a value that
moves (a score, a counter): show milestones instead.

**WARNING: a silent log does not say "connected".** [inherited] With Discord absent, the connection
fails without an error, by design. Hence the `connected` line logged on success: without it, "it
works" and "it was never installed" look the same.

**WARNING: the image keys live on Discord's side.** A wrong key shows no image and raises nothing.
They must match the Art Assets names exactly (lowercase).
