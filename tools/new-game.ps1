<#
.SYNOPSIS
    Instancie un nouveau projet Unity a partir du squelette.

.DESCRIPTION
    Copie `squelette/` vers la destination, remplace les jetons `__XXX__` dans les fichiers texte,
    renomme les dossiers qui en portent, initialise git et fait le premier commit.

    Ce que le script NE fait PAS, et ne peut pas faire : creer le projet cote Unity. Le dossier
    produit contient `Assets/`, `Packages/` et `ProjectSettings/ProjectVersion.txt` -- c'est ce
    qu'Unity Hub demande pour reconnaitre un projet. La premiere ouverture genere le reste
    (`Library/`, le reste de `ProjectSettings/`) et prend une vingtaine de minutes.

.PARAMETER Name
    Nom affiche du jeu (ex. « Smily Volley »). Sert au menu de l'editeur, au titre de la fenetre et
    a la page itch.

.PARAMETER Slug
    Identifiant itch et nom de dossier (ex. `smily-volley`). Deduit du nom si absent.

.PARAMETER Namespace
    Namespace C# et nom de l'executable, en PascalCase (ex. `SmilyVolley`). Deduit du nom si absent.
    C'est aussi le nom du gabarit WebGL : le dossier `Assets/WebGLTemplates/` est renomme avec.

.PARAMETER Destination
    Dossier parent du nouveau projet. Defaut : le dossier parent du gabarit (C:\CODE\JEUX).

.EXAMPLE
    & "tools/new-game.ps1" -Name "Mon Jeu" -Pitch "Un puzzle a deux boutons."
    & "tools/new-game.ps1" -Name "Mon Jeu" -Slug mon-jeu -Namespace MonJeu -ItchUser drangoht
#>

param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Slug = "",
    [string]$Namespace = "",
    [string]$ItchUser = "drangoht",
    [string]$Company = "",
    [string]$Pitch = "Un jeu.",
    [string]$Commandes = "Fleches pour se deplacer, Espace pour agir.",
    [string]$UnityVersion = "6000.5.6f1",
    [string]$Destination = "",
    [switch]$NoGit
)

$ErrorActionPreference = "Stop"

$TemplateRoot = Split-Path -Parent $PSScriptRoot
$Squelette    = Join-Path $TemplateRoot "squelette"

function Fail($msg) { Write-Host "ERREUR : $msg" -ForegroundColor Red; exit 1 }

if (-not (Test-Path $Squelette)) { Fail "Squelette introuvable : $Squelette" }

# --- Valeurs deduites ---------------------------------------------------------------
# Le slug sert d'identifiant itch ET de nom de dossier : il ne tolere ni accent, ni espace, ni
# majuscule. On le derive plutot que de le demander, mais on le laisse surchargeable.
if (-not $Slug) {
    # Decomposition Unicode puis retrait des diacritiques : « Épée » -> « epee ». Un simple
    # -replace laisserait tomber les lettres accentuees au lieu de les translitterer.
    $decompose = $Name.Normalize([Text.NormalizationForm]::FormD)
    $sansAccent = -join ($decompose.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne
            [Globalization.UnicodeCategory]::NonSpacingMark
    })
    $Slug = ($sansAccent.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
}
if (-not $Namespace) {
    $Namespace = -join (($Slug -split '-') | ForEach-Object {
        if ($_.Length -gt 0) { $_.Substring(0,1).ToUpper() + $_.Substring(1) }
    })
}
if (-not $Company)     { $Company = $ItchUser }
if (-not $Destination) { $Destination = Split-Path -Parent $TemplateRoot }

if ($Slug -notmatch '^[a-z0-9][a-z0-9-]*$') {
    Fail "Slug invalide : '$Slug'. Minuscules, chiffres et tirets uniquement (le donner via -Slug)."
}
if ($Namespace -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
    Fail "Namespace invalide : '$Namespace'. Identifiant C# attendu (le donner via -Namespace)."
}

$Cible = Join-Path $Destination $Slug
if (Test-Path $Cible) { Fail "Le dossier existe deja : $Cible" }

$jetons = [ordered]@{
    '__GAME_NAME__'     = $Name
    '__GAME_SLUG__'     = $Slug
    '__NAMESPACE__'     = $Namespace
    '__ITCH_USER__'     = $ItchUser
    '__COMPANY__'       = $Company
    '__PITCH__'         = $Pitch
    '__COMMANDES__'     = $Commandes
    '__UNITY_VERSION__' = $UnityVersion
    '__DATE__'          = (Get-Date -Format "yyyy-MM-dd")
}

Write-Host "Nouveau projet" -ForegroundColor Cyan
$jetons.GetEnumerator() | ForEach-Object {
    Write-Host ("  {0,-20} {1}" -f $_.Key, $_.Value) -ForegroundColor DarkGray
}
Write-Host "  -> $Cible" -ForegroundColor Cyan

# --- 1. Copie ------------------------------------------------------------------------
Copy-Item $Squelette $Cible -Recurse -Force

# --- 2. Renommage des dossiers et fichiers porteurs de jetons ------------------------
# Du plus profond vers le moins profond : renommer un parent d'abord invaliderait les chemins
# collectes pour ses enfants.
Get-ChildItem $Cible -Recurse -Force |
    Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object {
        $nouveau = $_.Name
        foreach ($j in $jetons.GetEnumerator()) {
            $nouveau = $nouveau.Replace($j.Key, $j.Value)
        }
        if ($nouveau -ne $_.Name) {
            Rename-Item -LiteralPath $_.FullName -NewName $nouveau
        }
    }

# --- 3. Substitution dans les fichiers texte -----------------------------------------
# ⚠ Uniquement les extensions texte connues : reecrire un binaire en UTF-8 le corrompt sans rien
# signaler. Les .asset et .meta d'Unity sont du YAML, donc du texte -- ils sont inclus a dessein.
$extensions = @('.cs', '.md', '.json', '.ps1', '.py', '.html', '.yml', '.yaml',
                '.txt', '.csproj', '.asset', '.meta', '.css', '.js',
                '.gitignore', '.gitattributes')

$fichiers = Get-ChildItem $Cible -Recurse -File -Force | Where-Object {
    $extensions -contains $_.Extension
}

$touches = 0
foreach ($fichier in $fichiers) {
    $contenu = Get-Content -LiteralPath $fichier.FullName -Raw -Encoding UTF8
    if ($null -eq $contenu) { continue }

    $avant = $contenu
    foreach ($j in $jetons.GetEnumerator()) {
        $contenu = $contenu.Replace($j.Key, $j.Value)
    }

    if ($contenu -ne $avant) {
        # ⚠ UTF8 SANS BOM : Unity lit les .cs et les .asset sans broncher avec un BOM, mais git
        # affiche alors un diff parasite sur la premiere ligne, et certains outils Python plantent.
        [IO.File]::WriteAllText($fichier.FullName, $contenu, [Text.UTF8Encoding]::new($false))
        $touches++
    }
}
Write-Host "$touches fichier(s) personnalise(s)." -ForegroundColor DarkGray

# --- 4. Verification : aucun jeton ne doit survivre ----------------------------------
# Un jeton oublie ne casse rien tout de suite : il compile (c'est un identifiant valide) et se
# manifeste bien plus tard, sous la forme d'un chemin qui n'existe pas.
$restants = Get-ChildItem $Cible -Recurse -File -Force |
            Where-Object { $extensions -contains $_.Extension } |
            Select-String -Pattern '__(GAME_NAME|GAME_SLUG|NAMESPACE|ITCH_USER|COMPANY|PITCH|COMMANDES|UNITY_VERSION|DATE)__' -List
if ($restants) {
    Write-Host "AVERTISSEMENT : des jetons subsistent dans :" -ForegroundColor Yellow
    $restants | ForEach-Object { Write-Host "  $($_.Path)" -ForegroundColor Yellow }
}

# --- 5. Git ---------------------------------------------------------------------------
if (-not $NoGit) {
    Push-Location $Cible
    # ⚠ Ne PAS tester $? apres git : il ecrit sa progression sur stderr meme quand tout va bien.
    git init -b main | Out-Null
    git add -A
    git commit -m @"
Pose les fondations de $Name

Genere depuis unity-game-template : squelette Unity (URP 2D, Input System),
scene construite par code, logique pure testee hors moteur, chaine de
publication itch.io, et l'equipe d'agents Claude Code avec ses garde-fous.
"@ | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "AVERTISSEMENT : le premier commit a echoue (git est-il configure ?)." -ForegroundColor Yellow
    }
    Pop-Location
}

# --- 6. Ce qu'il reste a faire --------------------------------------------------------
Write-Host ""
Write-Host "Projet cree : $Cible" -ForegroundColor Green
Write-Host ""
Write-Host "Ensuite, dans l'ordre :" -ForegroundColor Green
Write-Host "  1. Ouvrir le dossier dans Unity Hub (version $UnityVersion)."
Write-Host "     -> genere ProjectSettings/ et Library/. Compter ~20 min au premier import."
Write-Host "  2. Fermer l'editeur, puis construire en ligne de commande :"
Write-Host "     Unity.exe -batchmode -quit -projectPath `"$Cible`" ``" -ForegroundColor DarkGray
Write-Host "       -executeMethod $Namespace.EditorTools.BuildTools.RebuildEverything -logFile build.log" -ForegroundColor DarkGray
Write-Host "  3. py tools/piloter_jeu.py --lancer --capture docs/premier-lancement.png"
Write-Host "  4. Remplir docs/GDD.md (la boucle de jeu en une page) et la phase 0 de CLAUDE.md."
Write-Host "  5. Creer la page itch : https://$ItchUser.itch.io/$Slug"
Write-Host ""
Write-Host "Dans Claude Code : /carte-projet pour explorer, /verifier-en-jeu pour constater," -ForegroundColor Cyan
Write-Host "/publier-itch pour sortir une version. Le detail : GUIDE-EQUIPE.md." -ForegroundColor Cyan
