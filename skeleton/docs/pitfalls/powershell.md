# Pitfalls -- PowerShell (build and release scripts)


**WARNING: NEVER test `$?` after a native executable in PowerShell 5.1.** `git`, Unity and Butler
write their progress on **stderr even when all is well**, which sets `$?` to `$false` while the exit
code is 0. The release script announced "git push failed" at **every successful release**. Only
`$LASTEXITCODE` is authoritative.

**WARNING: `$ErrorActionPreference = 'Stop'` is a trap in a build script**, for the same reason: the
slightest progress line on stderr aborts the script.

**WARNING: a release script that can only be tried by publishing is never tested anywhere but in
production.** Hence `-DryRun`, which goes as far as the distribution folder and stops before any
visible effect.

**WARNING: a script called with `&` that does not end with an explicit `exit` leaves `$LASTEXITCODE`
STALE.** The caller then reads the code of whatever native command ran last in the session, not the
script's outcome. Found on Glassbloom: `build.ps1` printed "web build OK", and `release_itch.ps1`
stopped on "web build failed" right after. (Unity is launched with `Start-Process`, which never sets
`$LASTEXITCODE`.) Every script another script calls ends with `exit 0`, and fails with `exit 1`.

**WARNING: in PowerShell 5.1, `Set-Content -Encoding utf8` writes a BOM.** Found on Glassbloom:
`release_itch.ps1` wrote `bundleVersion` that way and committed it; the next Unity build rewrote the file
without the BOM, so `ProjectSettings.asset` showed as modified after every release -- with no real change.
(`Get-Content` has the mirror defect: it reads BOM-less UTF-8 as ANSI.) For any file Unity also writes,
use `[IO.File]::ReadAllText` / `[IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))`.
