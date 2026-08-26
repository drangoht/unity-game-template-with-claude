<#
.SYNOPSIS
    Instancie un nouveau projet Unity a partir du squelette.

.DESCRIPTION
    Copie `squelette/` vers la destination, remplace les jetons `__XXX__` dans les fichiers texte,
    renomme les dossiers qui en portent, initialise git, fait le premier commit -- et, si on le lui
    demande, enchaine sur le premier build Unity, qui importe le projet.

    Rien n'est devine sur la machine : ni ou ranger les jeux, ni ou est installe Unity. Ce qui est
    donne une fois est memorise dans `local.settings.json` (a cote de ce script, non versionne), et
    les fois suivantes il n'y a plus rien a saisir.

    Lance sans argument dans un terminal, le script demande ce qui lui manque.

.PARAMETER Name
    Nom affiche du jeu (ex. « Smily Volley »). Sert au menu de l'editeur, au titre de la fenetre et
    a la page itch.

.PARAMETER Slug
    Identifiant itch et nom de dossier (ex. `smily-volley`). Deduit du nom si absent.

.PARAMETER Namespace
    Namespace C# et nom de l'executable, en PascalCase (ex. `SmilyVolley`). Deduit du nom si absent.
    C'est aussi le nom du gabarit WebGL : le dossier `Assets/WebGLTemplates/` est renomme avec.

.PARAMETER Destination
    Dossier PARENT du nouveau projet -- celui ou l'on range ses jeux. Demande a la premiere
    utilisation, puis memorise. Aucun defaut : ce chemin appartient a la machine, pas au gabarit.

.PARAMETER UnityPath
    Chemin d'Unity.exe (l'exe, son dossier `Editor`, ou le dossier de version). Detecte
    automatiquement dans les installations d'Unity Hub ; demande sinon. Il est recopie dans le
    projet cree, qui n'aura donc jamais a le redemander.

.PARAMETER Build
    Enchaine sur le premier build apres la creation. Il importe tout le projet (~20 min) et rend
    l'etape « ouvrir une fois dans Unity Hub » inutile.

.EXAMPLE
    & "tools/new-game.ps1"
    & "tools/new-game.ps1" -Name "Mon Jeu" -Pitch "Un puzzle a deux boutons." -Build
    & "tools/new-game.ps1" -Name "Mon Jeu" -Destination "D:\Jeux" -UnityPath "D:\Unity\6000.5.6f1"
#>

param(
    [string]$Name = "",
    [string]$Slug = "",
    [string]$Namespace = "",
    [string]$ItchUser = "",
    [string]$Company = "",
    [string]$Pitch = "Un jeu.",
    [string]$Commandes = "Fleches pour se deplacer, Espace pour agir.",
    [string]$UnityPath = "",
    [string]$UnityVersion = "",
    [string]$Destination = "",
    [switch]$Build,
    [switch]$NoGit
)

$ErrorActionPreference = "Stop"

$TemplateRoot = Split-Path -Parent $PSScriptRoot
$Squelette    = Join-Path $TemplateRoot "squelette"

function Fail($msg) { Write-Host "ERREUR : $msg" -ForegroundColor Red; exit 1 }

if (-not (Test-Path $Squelette)) { Fail "Squelette introuvable : $Squelette" }

# Les fonctions de detection d'Unity vivent dans le squelette : le gabarit s'en sert lui aussi
# plutot que d'en tenir une seconde copie, qui divergerait.
. (Join-Path $Squelette "tools\environnement.ps1")

# ⚠ A rediriger IMMEDIATEMENT apres le dot-source : sans cela, les preferences s'ecriraient dans
# `squelette/tools/local.settings.json`, donc dans le gabarit -- et seraient recopiees dans chaque
# projet cree ensuite.
$script:FichierReglages = Join-Path $TemplateRoot "local.settings.json"
$script:RacineProjet    = $TemplateRoot

$prefs = Get-ReglagesLocaux

# --- Saisie ---------------------------------------------------------------------------
# ⚠ Read-Host ne peut pas repondre quand l'entree standard n'est pas une console : lance par un
# agent, un CI ou une tache planifiee, il rend "" -- ou attend indefiniment. On tranche une fois
# pour toutes ici plutot que de risquer un script bloque au milieu d'une creation de projet.
$script:Interactif = $false
try { $script:Interactif = ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) } catch { }

function Demander {
    param([string]$Question, [string]$Defaut = "", [string]$Parametre = "")

    if ($script:Interactif) {
        $invite = if ($Defaut) { "$Question [$Defaut]" } else { $Question }
        $reponse = ""
        try { $reponse = (Read-Host $invite) } catch { $reponse = "" }
        if ($reponse) { return $reponse.Trim() }
    }
    if ($Defaut) { return $Defaut }
    if ($Parametre) {
        Fail "Il manque -$Parametre (rien a saisir : ce terminal n'a pas d'entree interactive)."
    }
    return ""
}

function Confirmer {
    param([string]$Question)
    if (-not $script:Interactif) { return $false }
    $reponse = ""
    try { $reponse = (Read-Host "$Question [O/n]") } catch { return $false }
    return ($reponse -eq "" -or $reponse -match '^[oOyY]')
}

Write-Host "Nouveau jeu Unity" -ForegroundColor Cyan
Write-Host ""

if (-not $Name) { $Name = Demander "Nom du jeu" -Parametre "Name" }

# --- Valeurs deduites -----------------------------------------------------------------
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

if ($Slug -notmatch '^[a-z0-9][a-z0-9-]*$') {
    Fail "Slug invalide : '$Slug'. Minuscules, chiffres et tirets uniquement (le donner via -Slug)."
}
if ($Namespace -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
    Fail "Namespace invalide : '$Namespace'. Identifiant C# attendu (le donner via -Namespace)."
}

# --- Ou ranger le projet ---------------------------------------------------------------
if (-not $Destination) { $Destination = $prefs.gamesRoot }
if (-not $Destination) {
    Write-Host "Ou ranger les projets de jeu ? (dossier parent, il sera cree si besoin)" -ForegroundColor DarkGray
    $Destination = Demander "Dossier des jeux" -Parametre "Destination"
}
$Destination = $Destination.Trim().Trim('"')
if (-not (Test-Path -LiteralPath $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Write-Host "Dossier cree : $Destination" -ForegroundColor DarkGray
}
$Destination = (Resolve-Path -LiteralPath $Destination).Path

$Cible = Join-Path $Destination $Slug
if (Test-Path $Cible) { Fail "Le dossier existe deja : $Cible" }

# --- Ou est Unity ----------------------------------------------------------------------
# Detecte, jamais devine : un chemin en dur produit chez le suivant « Unity.exe : Le terme
# «Unity.exe» n'est pas reconnu comme nom d'applet de commande ».
if (-not $UnityPath) { $UnityPath = $prefs.unityPath }
$unity = Resolve-UnityPath -UnityPath $UnityPath -Version $UnityVersion -Silencieux
if (-not $unity) {
    Write-Host "Unity introuvable dans les emplacements d'Unity Hub :" -ForegroundColor Yellow
    Get-RacinesUnity | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Write-Host "Unity Hub > Installs > roue dentee > « Show in Explorer » donne le dossier exact." -ForegroundColor DarkGray
    $saisi = Demander "Chemin d'Unity.exe (vide = creer le projet sans Unity)"
    if ($saisi) {
        $unity = Expand-CheminUnity $saisi
        if (-not $unity) { Fail "Aucun Unity.exe a cet endroit : $saisi" }
    }
}

# La version du projet suit l'editeur reellement installe : ProjectVersion.txt et le chemin de
# l'editeur doivent designer le MEME Unity, sinon le Hub proposera une migration au premier clic.
if (-not $UnityVersion -and $unity) {
    $dossierVersion = Split-Path -Parent (Split-Path -Parent $unity)
    $UnityVersion = Split-Path -Leaf $dossierVersion
}
if (-not $UnityVersion) {
    $UnityVersion = Demander "Version d'Unity a inscrire dans le projet" "6000.5.6f1"
}

# --- Identite itch ----------------------------------------------------------------------
if (-not $ItchUser) { $ItchUser = $prefs.itchUser }
if (-not $ItchUser) { $ItchUser = Demander "Pseudo itch.io (l'URL sera <pseudo>.itch.io/$Slug)" -Parametre "ItchUser" }
if (-not $Company)  { $Company = $ItchUser }

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

Write-Host ""
$jetons.GetEnumerator() | ForEach-Object {
    Write-Host ("  {0,-20} {1}" -f $_.Key, $_.Value) -ForegroundColor DarkGray
}
if ($unity) { Write-Host ("  {0,-20} {1}" -f "Unity", $unity) -ForegroundColor DarkGray }
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

# --- 5. Chemins locaux du projet cree -------------------------------------------------
# Ecrits dans le projet, hors de git : le projet sait ou est Unity des son premier build, et rien
# de propre a cette machine ne part dans l'historique.
if ($unity) {
    $reglagesProjet = @{ unityPath = $unity }
    $python = Resolve-PythonCommand
    if ($python) { $reglagesProjet["python"] = $python }
    $texte = ($reglagesProjet | ConvertTo-Json)
    [IO.File]::WriteAllText((Join-Path $Cible "tools\local.settings.json"), $texte, [Text.UTF8Encoding]::new($false))
}

# --- 6. Git ---------------------------------------------------------------------------
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

# --- 7. Memorisation des reponses -----------------------------------------------------
Set-ReglageLocal -Nom "gamesRoot" -Valeur $Destination
Set-ReglageLocal -Nom "itchUser"  -Valeur $ItchUser
if ($unity) { Set-ReglageLocal -Nom "unityPath" -Valeur $unity }

Write-Host ""
Write-Host "Projet cree : $Cible" -ForegroundColor Green

# --- 8. Premier build -----------------------------------------------------------------
# C'est lui qui importe le projet et genere Library/ + ProjectSettings/ : il n'y a rien a ouvrir
# dans Unity Hub, contrairement a ce que suppose la plupart des tutoriels.
$construire = $false
if ($unity) {
    if ($Build) {
        $construire = $true
    } elseif ($script:Interactif) {
        Write-Host ""
        Write-Host "Le premier build importe tout le projet : compter une vingtaine de minutes." -ForegroundColor DarkGray
        $construire = Confirmer "Le lancer maintenant ?"
    }
}

if ($construire) {
    & (Join-Path $Cible "tools\build.ps1") -Lancer -Capture "docs\premier-lancement.png"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Le premier build a echoue - voir Logs\build-windows.log dans le projet." -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Ensuite :" -ForegroundColor Green
    Write-Host "  1. Remplir docs/GDD.md : dans Claude Code, /rediger-le-gdd. Puis la phase 0 de CLAUDE.md."
    Write-Host "  2. Creer la page itch : https://$ItchUser.itch.io/$Slug"
} else {
    Write-Host ""
    Write-Host "Ensuite, dans l'ordre :" -ForegroundColor Green
    $n = 1
    Write-Host "  $n. cd `"$Cible`""; $n++
    if (-not $unity) {
        Write-Host "  $n. & `"tools/configurer.ps1`" -UnityPath `"<chemin>\Unity.exe`""; $n++
    }
    Write-Host "  $n. & `"tools/build.ps1`" -Lancer   (premier build : ~20 min, importe le projet)"; $n++
    Write-Host "  $n. Remplir docs/GDD.md : dans Claude Code, /rediger-le-gdd. Puis la phase 0 de CLAUDE.md."; $n++
    Write-Host "  $n. Creer la page itch : https://$ItchUser.itch.io/$Slug"
}

Write-Host ""
Write-Host "Dans Claude Code : /rediger-le-gdd pour ecrire le design, /carte-projet pour explorer," -ForegroundColor Cyan
Write-Host "/verifier-en-jeu pour constater, /publier-itch pour sortir une version. GUIDE-EQUIPE.md" -ForegroundColor Cyan
Write-Host "dit qui fait quoi, dans quel ordre." -ForegroundColor Cyan
