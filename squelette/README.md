# __GAME_NAME__

__PITCH__

Unity __UNITY_VERSION__ · C# · URP 2D · Input System · publié sur
[itch.io](https://__ITCH_USER__.itch.io/__GAME_SLUG__).

> Ce dépôt est né du gabarit `unity-game-template`. Les fichiers `.claude/`, `docs/PITFALLS_UNITY.md`
> et `tools/` en viennent : ils portent l'expérience de projets précédents. **Les corriger ici quand
> le projet leur donne tort**, et remonter au gabarit ce qui est généralisable.

## Démarrer

```powershell
# 1. Ouvrir une premiere fois dans Unity Hub  ->  genere ProjectSettings/ et Library/
#    (compter ~20 min : le premier import traite tous les assets)

# 2. Construire et lancer, sans ouvrir l'editeur
& "C:\Program Files\Unity\Hub\Editor\__UNITY_VERSION__\Editor\Unity.exe" `
    -batchmode -quit -projectPath "." `
    -executeMethod __NAMESPACE__.EditorTools.BuildTools.RebuildEverything `
    -logFile build.log

py tools/piloter_jeu.py --lancer --attendre 4 --capture docs/premier-lancement.png
```

## Structure

```
Assets/
  Editor/            BuildTools · RenderPipelineSetup · SceneBuilder
  Scripts/Core/      BuildInfo et socle
  Scripts/Rules/     ⚠ Logique PURE testable — aucun `using UnityEngine`
  Scripts/Gameplay/  MonoBehaviour
  Scripts/UI/        Écrans, HUD
  Settings/          Assets URP (pipeline, renderer 2D)
  Scenes/Game.unity  ⚠ ARTEFACT régénéré par SceneBuilder
  WebGLTemplates/    Page hôte du build web
tests/               xUnit sur Assets/Scripts/Rules/ — aucun moteur requis
tools/               release_itch.ps1 · serve_web.py · piloter_jeu.py
docs/                GDD · PITFALLS_UNITY · RELEASE · DEVLOG · TEST_REPORT · ITCH_STORE_PAGE
.claude/             9 agents · 3 skills · 2 hooks
```

## Les trois choix structurants

**1. La scène est un artefact, pas une source.** `Assets/Scenes/Game.unity` est régénérée par
`SceneBuilder.Build()` à chaque build. On ajoute un objet au jeu **en écrivant du code**, pas en
cliquant dans l'éditeur. En échange, tout le jeu se pilote en ligne de commande — construire,
lancer, injecter des touches, capturer — donc se vérifie sans main humaine.
⚠ Corollaire : la scène ressort modifiée après chaque build. L'écarter (`git checkout --`) sauf si
`SceneBuilder.cs` a changé.

**2. Toute règle chiffrée vit dans `Assets/Scripts/Rules/`**, en classe statique sans dépendance
moteur, avec ses tests. `dotnet test tests/__NAMESPACE__.Tests.csproj` s'exécute en quelques
secondes, sans Unity — et un hook les rejoue après chaque édition.

**3. Le binaire porte son identité.** Chaque build écrit `build_stamp.json` et un tampon
`v<version>-<sha>` affiché en bas à droite. Ni la date d'un fichier (build incrémental) ni les
métadonnées Windows (qui décrivent le moteur) ne disent quelle version on regarde. Ce tampon, si.

## Commandes utiles

| But | Commande |
|---|---|
| Build Windows | `-executeMethod __NAMESPACE__.EditorTools.BuildTools.RebuildEverything` |
| Build web | `-executeMethod __NAMESPACE__.EditorTools.BuildTools.RebuildWeb` |
| Tests | `dotnet test tests/__NAMESPACE__.Tests.csproj` |
| Lancer et capturer | `py tools/piloter_jeu.py --lancer --capture docs/x.png` |
| Servir le build web | `py tools/serve_web.py` (⚠ **sans cache** — voir PITFALLS) |
| Publier | `& "tools/release_itch.ps1" -Version X.Y.Z -DryRun` |

⚠ **L'éditeur Unity doit être fermé** pour tout build en ligne de commande.
⚠ En PowerShell, lancer Unity par `&` rend la main **immédiatement sans rien faire** :
`Start-Process -Wait`.

## Travailler avec Claude Code

9 agents et 3 skills sont livrés avec le projet — voir **`GUIDE-EQUIPE.md`**.

Les trois réflexes qui comptent :
- **`/carte-projet`** avant d'explorer le code ;
- **`docs/PITFALLS_UNITY.md`** avant de coder dans un domaine ;
- **`/verifier-en-jeu`** avant d'écrire « ça devrait marcher ».

## Publier

`/publier-itch`, ou l'agent `release-manager` pour le faire de bout en bout, devlog compris.
Runbook : `docs/RELEASE.md`.

## Licences

<!-- Polices : SIL OFL (joindre OFL.txt à côté du .ttf). Sons : CC0 / Kenney.
     Musique : vérifier l'usage commercial. Détail dans docs/CREDITS.md. -->
