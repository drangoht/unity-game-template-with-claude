<#
.SYNOPSIS
    Instantiates a new Unity project from the skeleton.

.DESCRIPTION
    Copies `skeleton/` to the destination, replaces the `__XXX__` tokens in the text files, renames
    the folders that carry them, initialises git, makes the first commit -- and, if asked to, goes
    on to the first Unity build, which imports the project.

    Nothing is guessed about the machine: neither where to keep the games, nor where Unity is
    installed. What is given once is remembered in `local.settings.json` (next to this script, not
    versioned), and the following times there is nothing left to type.

    Run with no argument in a terminal, the script asks for what it is missing.

.PARAMETER Name
    Display name of the game (e.g. "Smily Volley"). Used by the editor menu, the window title and
    the itch page.

.PARAMETER Slug
    itch identifier and folder name (e.g. `smily-volley`). Derived from the name if absent.

.PARAMETER Namespace
    C# namespace and executable name, in PascalCase (e.g. `SmilyVolley`). Derived from the name if
    absent. It is also the name of the WebGL template: the `Assets/WebGLTemplates/` folder is
    renamed with it.

.PARAMETER Destination
    PARENT folder of the new project -- the one where you keep your games. Asked for on first use,
    then remembered. No default: that path belongs to the machine, not to the template.

.PARAMETER UnityPath
    Path to Unity.exe (the exe, its `Editor` folder, or the version folder). Detected automatically
    in the Unity Hub installations; asked for otherwise. It is copied into the created project,
    which will therefore never have to ask for it again.

.PARAMETER Build
    Goes on to the first build after creation. It imports the whole project (~20 min) and makes the
    "open once in Unity Hub" step unnecessary.

.PARAMETER NoRemember
    Remembers nothing in `local.settings.json` (games folder, itch username, Unity path). For a
    throwaway trial of the template: without it, `-Destination "$env:TEMP" -ItchUser trial` would
    become the default of every following game.

.PARAMETER NoCd
    Stays in the current folder. By default the script puts the session inside the created project:
    the rest of the work (build, tests, Claude Code) happens entirely there, and a
    `tools/build.ps1` launched from the template would build the wrong project -- or nothing at all.

.EXAMPLE
    & "tools/new-game.ps1"
    & "tools/new-game.ps1" -Name "My Game" -Pitch "A two-button puzzle." -Build
    & "tools/new-game.ps1" -Name "My Game" -Destination "D:\Games" -UnityPath "D:\Unity\6000.5.6f1"
#>

param(
    [string]$Name = "",
    [string]$Slug = "",
    [string]$Namespace = "",
    [string]$ItchUser = "",
    [string]$Company = "",
    [string]$Pitch = "A game.",
    [string]$Controls = "Arrow keys to move, Space to act.",
    [string]$UnityPath = "",
    [string]$UnityVersion = "",
    [string]$Destination = "",
    [switch]$Build,
    [switch]$NoGit,
    [switch]$NoRemember,
    [switch]$NoCd
)

$ErrorActionPreference = "Stop"

$TemplateRoot = Split-Path -Parent $PSScriptRoot
$Skeleton     = Join-Path $TemplateRoot "skeleton"

function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

if (-not (Test-Path $Skeleton)) { Fail "Skeleton not found: $Skeleton" }

# The Unity detection functions live in the skeleton: the template uses them too rather than
# keeping a second copy, which would drift.
. (Join-Path $Skeleton "tools\environment.ps1")

# WARNING: to be redirected IMMEDIATELY after the dot-source: without this, the preferences would be
# written to `skeleton/tools/local.settings.json`, hence into the template -- and would be copied
# into every project created afterwards.
$script:SettingsFile = Join-Path $TemplateRoot "local.settings.json"
$script:ProjectRoot  = $TemplateRoot

$prefs = Get-LocalSettings

# --- Input ----------------------------------------------------------------------------
# WARNING: Read-Host cannot answer when standard input is not a console: launched by an agent, a CI
# or a scheduled task, it returns "" -- or waits forever. We settle it once and for all here rather
# than risk a script stuck in the middle of a project creation.
$script:Interactive = $false
try { $script:Interactive = ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) } catch { }

function Ask {
    param([string]$Question, [string]$Default = "", [string]$Parameter = "")

    if ($script:Interactive) {
        $prompt = if ($Default) { "$Question [$Default]" } else { $Question }
        $answer = ""
        try { $answer = (Read-Host $prompt) } catch { $answer = "" }
        if ($answer) { return $answer.Trim() }
    }
    if ($Default) { return $Default }
    if ($Parameter) {
        Fail "Missing -$Parameter (nothing to type: this terminal has no interactive input)."
    }
    return ""
}

function Confirm-Choice {
    param([string]$Question)
    if (-not $script:Interactive) { return $false }
    $answer = ""
    try { $answer = (Read-Host "$Question [Y/n]") } catch { return $false }
    return ($answer -eq "" -or $answer -match '^[yYoO]')
}

Write-Host "New Unity game" -ForegroundColor Cyan
Write-Host ""

if (-not $Name) { $Name = Ask "Game name" -Parameter "Name" }

# --- Derived values -------------------------------------------------------------------
# The slug serves as the itch identifier AND as the folder name: it tolerates neither accents, nor
# spaces, nor capitals. We derive it rather than asking for it, but leave it overridable.
if (-not $Slug) {
    # Unicode decomposition then removal of the diacritics: "Epee" from "E'pe'e". A plain -replace
    # would drop the accented letters instead of transliterating them.
    $decomposed = $Name.Normalize([Text.NormalizationForm]::FormD)
    $stripped = -join ($decomposed.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne
            [Globalization.UnicodeCategory]::NonSpacingMark
    })
    $Slug = ($stripped.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
}
if (-not $Namespace) {
    $Namespace = -join (($Slug -split '-') | ForEach-Object {
        if ($_.Length -gt 0) { $_.Substring(0,1).ToUpper() + $_.Substring(1) }
    })
}

if ($Slug -notmatch '^[a-z0-9][a-z0-9-]*$') {
    Fail "Invalid slug: '$Slug'. Lowercase letters, digits and hyphens only (supply it with -Slug)."
}
if ($Namespace -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
    Fail "Invalid namespace: '$Namespace'. A C# identifier is expected (supply it with -Namespace)."
}

# --- Where to keep the project ---------------------------------------------------------
if (-not $Destination) { $Destination = $prefs.gamesRoot }
if (-not $Destination) {
    Write-Host "Where should the game projects go? (parent folder, it will be created if needed)" -ForegroundColor DarkGray
    $Destination = Ask "Games folder" -Parameter "Destination"
}
$Destination = $Destination.Trim().Trim('"')
if (-not (Test-Path -LiteralPath $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Write-Host "Folder created: $Destination" -ForegroundColor DarkGray
}
$Destination = (Resolve-Path -LiteralPath $Destination).Path

$Target = Join-Path $Destination $Slug
if (Test-Path $Target) { Fail "The folder already exists: $Target" }

# --- Where Unity is --------------------------------------------------------------------
# Detected, never guessed: a hard-coded path produces, on the next machine, "Unity.exe : The term
# 'Unity.exe' is not recognized as the name of a cmdlet".
if (-not $UnityPath) { $UnityPath = $prefs.unityPath }
$unity = Resolve-UnityPath -UnityPath $UnityPath -Version $UnityVersion -Quiet
if (-not $unity) {
    Write-Host "Unity not found in the Unity Hub locations:" -ForegroundColor Yellow
    Get-UnityRoots | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Write-Host "Unity Hub > Installs > gear icon > 'Show in Explorer' gives the exact folder." -ForegroundColor DarkGray
    $typed = Ask "Path to Unity.exe (empty = create the project without Unity)"
    if ($typed) {
        $unity = Expand-UnityPath $typed
        if (-not $unity) { Fail "No Unity.exe at that location: $typed" }
    }
}

# The project version follows the editor actually installed: ProjectVersion.txt and the editor path
# must designate the SAME Unity, otherwise the Hub will offer a migration at the first click.
if (-not $UnityVersion -and $unity) {
    $versionFolder = Split-Path -Parent (Split-Path -Parent $unity)
    $UnityVersion = Split-Path -Leaf $versionFolder
}
if (-not $UnityVersion) {
    $UnityVersion = Ask "Unity version to write into the project" "6000.5.6f1"
}

# --- itch identity ----------------------------------------------------------------------
if (-not $ItchUser) { $ItchUser = $prefs.itchUser }
if (-not $ItchUser) { $ItchUser = Ask "itch.io username (the URL will be <user>.itch.io/$Slug)" -Parameter "ItchUser" }
if (-not $Company)  { $Company = $ItchUser }

$tokens = [ordered]@{
    '__GAME_NAME__'     = $Name
    '__GAME_SLUG__'     = $Slug
    '__NAMESPACE__'     = $Namespace
    '__ITCH_USER__'     = $ItchUser
    '__COMPANY__'       = $Company
    '__PITCH__'         = $Pitch
    '__CONTROLS__'      = $Controls
    '__UNITY_VERSION__' = $UnityVersion
    '__DATE__'          = (Get-Date -Format "yyyy-MM-dd")
}

Write-Host ""
$tokens.GetEnumerator() | ForEach-Object {
    Write-Host ("  {0,-20} {1}" -f $_.Key, $_.Value) -ForegroundColor DarkGray
}
if ($unity) { Write-Host ("  {0,-20} {1}" -f "Unity", $unity) -ForegroundColor DarkGray }
Write-Host "  -> $Target" -ForegroundColor Cyan

# --- 1. Copy -------------------------------------------------------------------------
# What git would hand to a fresh clone: tracked files + new files not ignored yet (a skeleton file
# being added must be testable before its commit). NOT what lies on this disk: a plain recursive copy
# also shipped local leftovers that .gitignore keeps out of the template (tools/__pycache__, ...).
# Without git (template downloaded as a zip), the whole folder is copied as before.
$listed = $null
if (Get-Command git -ErrorAction SilentlyContinue) {
    $listed = git -C $TemplateRoot -c core.quotepath=off ls-files --cached --others --exclude-standard -- skeleton 2>$null
    if ($LASTEXITCODE -ne 0) { $listed = $null }
}
if ($listed) {
    foreach ($relative in $listed) {
        $source = Join-Path $TemplateRoot $relative
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue } # deleted, not yet committed
        $destination = Join-Path $Target ($relative.Substring("skeleton/".Length))
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
} else {
    Copy-Item $Skeleton $Target -Recurse -Force
}

# --- 2. Renaming of the folders and files carrying tokens -----------------------------
# From the deepest to the shallowest: renaming a parent first would invalidate the paths collected
# for its children.
Get-ChildItem $Target -Recurse -Force |
    Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object {
        $newName = $_.Name
        foreach ($t in $tokens.GetEnumerator()) {
            $newName = $newName.Replace($t.Key, $t.Value)
        }
        if ($newName -ne $_.Name) {
            Rename-Item -LiteralPath $_.FullName -NewName $newName
        }
    }

# --- 3. Substitution in the text files ------------------------------------------------
# WARNING: only the known text extensions: rewriting a binary in UTF-8 corrupts it without
# reporting anything. Unity's .asset and .meta files are YAML, hence text -- they are included on
# purpose.
$extensions = @('.cs', '.md', '.json', '.ps1', '.py', '.html', '.yml', '.yaml',
                '.txt', '.csproj', '.asset', '.meta', '.css', '.js',
                '.gitignore', '.gitattributes')

$files = Get-ChildItem $Target -Recurse -File -Force | Where-Object {
    $extensions -contains $_.Extension
}

$touched = 0
foreach ($file in $files) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    if ($null -eq $content) { continue }

    $before = $content
    foreach ($t in $tokens.GetEnumerator()) {
        $content = $content.Replace($t.Key, $t.Value)
    }

    if ($content -ne $before) {
        # WARNING: UTF8 WITHOUT BOM: Unity reads .cs and .asset files with a BOM without
        # complaining, but git then shows a spurious diff on the first line, and some Python tools
        # crash.
        [IO.File]::WriteAllText($file.FullName, $content, [Text.UTF8Encoding]::new($false))
        $touched++
    }
}
Write-Host "$touched file(s) customised." -ForegroundColor DarkGray

# --- 4. Check: no token must survive --------------------------------------------------
# A forgotten token breaks nothing straight away: it compiles (it is a valid identifier) and shows
# up much later, in the form of a path that does not exist.
$remaining = Get-ChildItem $Target -Recurse -File -Force |
             Where-Object { $extensions -contains $_.Extension } |
             Select-String -Pattern '__(GAME_NAME|GAME_SLUG|NAMESPACE|ITCH_USER|COMPANY|PITCH|CONTROLS|UNITY_VERSION|DATE)__' -List
if ($remaining) {
    Write-Host "WARNING: tokens remain in:" -ForegroundColor Yellow
    $remaining | ForEach-Object { Write-Host "  $($_.Path)" -ForegroundColor Yellow }
}

# --- 5. Local paths of the created project ---------------------------------------------
# Written into the project, out of git: the project knows where Unity is from its first build, and
# nothing specific to this machine goes into the history.
if ($unity) {
    $projectSettings = @{ unityPath = $unity }
    $python = Resolve-PythonCommand
    if ($python) { $projectSettings["python"] = $python }
    $text = ($projectSettings | ConvertTo-Json)
    [IO.File]::WriteAllText((Join-Path $Target "tools\local.settings.json"), $text, [Text.UTF8Encoding]::new($false))
}

# --- 6. Git ---------------------------------------------------------------------------
if (-not $NoGit) {
    Push-Location $Target
    # WARNING: do NOT test $? after git: it writes its progress on stderr even when all is well.
    git init -b main | Out-Null
    git add -A
    git commit -m @"
Lay the foundations of $Name

Generated from unity-game-template: Unity skeleton (URP 2D, Input System),
scene built in code, pure logic tested outside the engine, itch.io publishing
chain, and the Claude Code agent team with its safeguards.
"@ | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: the first commit failed (is git configured?)." -ForegroundColor Yellow
    }
    Pop-Location
}

# --- 7. Remembering the answers --------------------------------------------------------
if (-not $NoRemember) {
    Set-LocalSetting -Name "gamesRoot" -Value $Destination
    Set-LocalSetting -Name "itchUser"  -Value $ItchUser
    if ($unity) { Set-LocalSetting -Name "unityPath" -Value $unity }
}

Write-Host ""
Write-Host "Project created: $Target" -ForegroundColor Green

# --- 8. First build --------------------------------------------------------------------
# It is what imports the project and generates Library/ + ProjectSettings/: there is nothing to open
# in Unity Hub, contrary to what most tutorials assume.
$doBuild = $false
if ($unity) {
    if ($Build) {
        $doBuild = $true
    } elseif ($script:Interactive) {
        Write-Host ""
        Write-Host "The first build imports the whole project: reckon on about twenty minutes." -ForegroundColor DarkGray
        $doBuild = Confirm-Choice "Run it now?"
    }
}

if ($doBuild) {
    & (Join-Path $Target "tools\build.ps1") -Run -Capture "docs\first-launch.png"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "The first build failed - see Logs\build-windows.log in the project." -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Next:" -ForegroundColor Green
    Write-Host "  1. Fill in docs/GDD.md: in Claude Code, /write-the-gdd. Then phase 0 of CLAUDE.md."
    Write-Host "  2. Create the itch page: https://$ItchUser.itch.io/$Slug"
} else {
    Write-Host ""
    Write-Host "Next, in order:" -ForegroundColor Green
    $n = 1
    if ($NoCd) { Write-Host "  $n. cd `"$Target`""; $n++ }
    if (-not $unity) {
        Write-Host "  $n. & `"tools/configure.ps1`" -UnityPath `"<path>\Unity.exe`""; $n++
    }
    Write-Host "  $n. & `"tools/build.ps1`" -Run   (first build: ~20 min, imports the project)"; $n++
    Write-Host "  $n. Fill in docs/GDD.md: in Claude Code, /write-the-gdd. Then phase 0 of CLAUDE.md."; $n++
    Write-Host "  $n. Create the itch page: https://$ItchUser.itch.io/$Slug"
}

Write-Host ""
Write-Host "In Claude Code: /write-the-gdd to write the design, /project-map to explore," -ForegroundColor Cyan
Write-Host "/verify-in-game to see it, /publish-itch to ship a version. TEAM-GUIDE.md" -ForegroundColor Cyan
Write-Host "says who does what, in what order." -ForegroundColor Cyan

# --- 9. Move into the project ----------------------------------------------------------
# A Set-Location made from a script applies to the calling session: the location is carried by the
# runspace, not by the script scope. That is what we want here -- everything that follows (build,
# tests, Claude Code) happens in the project, and `tools/build.ps1` launched by mistake from the
# template builds nothing.
# WARNING: no effect if the script runs in a separate process (`powershell -File new-game.ps1`):
# that one dies with its location. The path is therefore always printed, not merely suggested.
if (-not $NoCd) {
    Set-Location -LiteralPath $Target
    Write-Host ""
    Write-Host "Session moved to $Target" -ForegroundColor DarkGray
}
