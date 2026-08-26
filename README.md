# unity-game-template

Gabarit de démarrage pour un jeu Unity 2D destiné à itch.io, **piloté par Claude Code**.

Il ne contient pas un moteur de jeu : il contient **ce qu'on refait à chaque fois** — la chaîne de
build en ligne de commande, la publication itch.io avec ses garde-fous, l'outillage de vérification
en jeu, et une équipe d'agents Claude Code déjà instruite des pièges. Le tout distillé de deux
projets publiés, **Chimera Protocol** et **Smily Volley**.

> **Le vrai contenu de ce dépôt, c'est `docs/PITFALLS_UNITY.md`.** Chaque entrée correspond à un
> défaut qui n'a levé **ni erreur de compilation, ni exception, ni avertissement** — seulement un
> jeu qui se comporte mal. C'est la catégorie de bug qui coûte des heures et qu'on ne redécouvre
> jamais avec plaisir.

---

## Créer un jeu

```powershell
cd C:\CODE\JEUX\unity-game-template
& "tools/new-game.ps1" -Name "Mon Jeu" -Pitch "Un puzzle a deux boutons."
```

Ce qui se passe :

1. `squelette/` est copié vers `C:\CODE\JEUX\mon-jeu` ;
2. les jetons `__XXX__` sont remplacés dans les fichiers **texte**, et les dossiers qui en portent
   sont renommés ;
3. le script vérifie qu'**aucun jeton ne survit** — un jeton oublié compile (c'est un identifiant
   valide) et ne se manifeste que bien plus tard, sous la forme d'un chemin qui n'existe pas ;
4. `git init` + premier commit ;
5. le script affiche ce qu'il reste à faire.

Paramètres : `-Slug`, `-Namespace`, `-ItchUser`, `-Company`, `-Pitch`, `-Commandes`,
`-UnityVersion`, `-Destination`, `-NoGit`. Le slug et le namespace sont déduits du nom si on ne les
donne pas.

### Ce que le script ne peut pas faire

**Créer le projet côté Unity.** Le dossier produit contient `Assets/`, `Packages/` et
`ProjectSettings/ProjectVersion.txt` — c'est ce qu'Unity Hub demande pour reconnaître un projet.
**Ouvrir le dossier une fois dans Unity Hub** génère le reste (`Library/`, `ProjectSettings/`
complet) et prend une vingtaine de minutes au premier import. Ensuite, tout se pilote en ligne de
commande.

---

## Ce qu'on obtient

```
mon-jeu/
├── CLAUDE.md               Mémoire de projet — chargée à chaque session, à garder COURTE
├── GUIDE-EQUIPE.md         Qui fait quoi, dans quel ordre
├── README.md               Le projet vu de l'extérieur
├── version.json            Manifeste lu par le bandeau « nouvelle version »
├── .claude/
│   ├── settings.json       Permissions + les deux hooks
│   ├── agents/             9 agents
│   ├── skills/             /carte-projet · /verifier-en-jeu · /publier-itch
│   └── hooks/              guard.ps1 · run-rules-tests.ps1
├── .github/workflows/      CI : les tests de Rules/ sur un runner Linux, sans Unity
├── Assets/
│   ├── Editor/             BuildTools · RenderPipelineSetup · SceneBuilder
│   ├── Scripts/Rules/      Logique PURE testable
│   ├── Settings/           Assets URP prêts (pipeline, renderer 2D) — aucun réglage à la souris
│   └── WebGLTemplates/     Page hôte : cadrage, tactile, audio, garde-cache
├── .gitattributes          LF partout + fusion YAML Unity + règles LFS pour les gros assets
├── Packages/manifest.json  URP + Input System + uGUI
├── docs/                   GDD · PITFALLS_UNITY · RELEASE · DEVLOG · TEST_REPORT · ITCH_STORE_PAGE
├── tests/                  xUnit sur Rules/ — aucun moteur requis
└── tools/                  release_itch.ps1 · serve_web.py · piloter_jeu.py
```

---

## Les quatre partis pris

### 1. La scène est un artefact, pas une source

`Assets/Scenes/Game.unity` est **régénérée par `SceneBuilder.Build()`** à chaque build. On ajoute un
objet au jeu en écrivant du code, pas en cliquant dans l'éditeur.

C'est le choix qui rend tout le reste possible : un agent peut modifier une valeur, relancer le
build en batchmode et **regarder le résultat**. Un fichier `.unity` édité à la souris ferme cette
porte.

⚠ Corollaire : la scène ressort modifiée après chaque build (tous les `fileID` renumérotés).
L'écarter par `git checkout --`, sauf si `SceneBuilder.cs` a changé. `BuildTools.HasLocalChanges`
l'exclut déjà du constat de propreté de l'arbre — sans quoi tout build se déclarerait « sale ».

### 2. Toute règle chiffrée vit hors du moteur

`Assets/Scripts/Rules/` contient des classes **statiques sans aucun `using UnityEngine`**, compilées
**par chemin** dans l'assembly de test. Conséquence : `dotnet test` s'exécute en quelques secondes,
sans Unity installé — donc en CI sur un runner Linux, et **automatiquement après chaque édition**
via un hook `PostToolUse` qui réveille Claude si un test casse.

Un fichier de `Rules/` qui écrirait `using UnityEngine` casse la compilation des tests. C'est voulu :
l'erreur arrive au bon moment, avant que la dépendance ne s'installe.

### 3. Le binaire porte son identité

Chaque build écrit `build_stamp.json` et un tampon `v<version>-<sha>` affiché en bas de l'écran.
Il n'est pas là pour le joueur, mais pour le **rapport de bug** — et pour le script de publication,
qui refuse de pousser un build dont le tampon ne porte pas la version demandée.

Pourquoi ce garde-fou existe : **une release a déjà expédié le binaire de la version précédente sans
qu'aucune erreur ne soit levée.** Ni la date d'un fichier (Unity construit de façon incrémentale : un
fichier identique n'est pas réécrit) ni les métadonnées Windows (qui décrivent le **moteur**, pas le
jeu) ne permettent de s'en apercevoir. Seule la version embarquée tranche.

Le tampon est posé **par le build**, jamais par le script de publication : écrit seulement au moment
de publier, il resterait ensuite en place et tout build local suivant afficherait le SHA de la
dernière release. *Un garde-fou de fraîcheur qui se trompe est pire que pas de garde-fou, puisqu'on
lui fait confiance.*

### 4. Un changement se constate, il ne se raisonne pas

`tools/piloter_jeu.py` lance le build Windows, lui donne le focus par un **vrai clic** (le seul moyen
depuis un shell non interactif), injecte de vraies touches avec leur code de balayage, et capture la
fenêtre. Le skill `/verifier-en-jeu` en fait la procédure de référence.

« Ça compile » ne prouve rien sur un jeu : un mapping clavier positionnel, un décor rendu noir faute
de lumière globale, un menu qui ne réagit pas — aucun de ces défauts n'apparaît à la compilation, et
tous se voient en trente secondes sur une capture.

---

## L'équipe d'agents

9 agents, 3 skills, 2 hooks — détail dans `GUIDE-EQUIPE.md` du projet généré.

| Agent | Rôle |
|---|---|
| `developpeur` | Code, architecture, build, tests |
| `game-designer` | Design, équilibrage, scope |
| `game-tester` | Joue le jeu et documente ce qui cloche |
| `release-manager` | Publie de bout en bout + rédige le devlog |
| `directeur-artistique` · `graphiste` · `musicien` · `story-teller` · `marketing` | Production et vitrine |

**Les hooks font le travail qu'on oublie de faire :**
- `guard.ps1` (PreToolUse) refuse `git push --force`, `git reset --hard`, `git clean -f`, et toute
  suppression récursive visant l'extérieur du projet. Il inspecte la **ligne entière** (chaînages
  compris) là où les règles `deny` ne matchent que par préfixe — et il **exclut le texte des messages
  de commit**, sans quoi un message qui *cite* une commande dangereuse bloquerait le commit.
- `run-rules-tests.ps1` (PostToolUse, asynchrone) rejoue les tests dès qu'un fichier de `Rules/` ou
  de `tests/` est édité, et **réveille Claude** si quelque chose casse.

Les deux hooks déduisent la racine du projet de leur propre emplacement : rien à substituer.

---

## Maintenir le gabarit

Ce dépôt n'a de valeur que s'il vieillit bien. Deux règles :

1. **Quand un projet enseigne quelque chose de généralisable, le remonter ici** — un piège dans
   `docs/PITFALLS_UNITY.md`, une consigne dans l'agent concerné, un garde-fou dans un script. C'est
   moins coûteux que de le redécouvrir sur le projet suivant.
2. **Quand un projet donne tort au gabarit, le corriger ici aussi.** Une consigne périmée transmise à
   chaque nouveau projet est pire qu'une consigne absente : elle est fausse, et elle a l'autorité du
   fichier de référence.

Les jetons reconnus par `new-game.ps1` :

| Jeton | Exemple | Où il sert |
|---|---|---|
| `__GAME_NAME__` | `Smily Volley` | menu éditeur, titre de fenêtre, docs |
| `__GAME_SLUG__` | `smily-volley` | slug itch, nom du dossier |
| `__NAMESPACE__` | `SmilyVolley` | namespace C#, nom de l'exe, dossier WebGLTemplates |
| `__ITCH_USER__` | `drangoht` | URL de la page itch |
| `__COMPANY__` | `drangoht` | `PlayerSettings.companyName`, chemin de sauvegarde |
| `__PITCH__` | … | description de la page, GDD |
| `__COMMANDES__` | … | note affichée pendant le chargement web |
| `__UNITY_VERSION__` | `6000.5.6f1` | chemin de l'éditeur, `ProjectVersion.txt` |
| `__DATE__` | `2026-08-26` | date de création dans `CLAUDE.md` |

⚠ **`__BUILD_ID__`, dans `index.html`, n'est PAS un jeton du gabarit** : il est remplacé par
`BuildTools.StampWebCacheBuster` à chaque build. Le scaffolder ne remplace que les jetons de la
table ci-dessus, jamais tout ce qui ressemble à `__X__` — c'est délibéré.

⚠ La substitution ne touche que les **extensions texte connues**. Réécrire un binaire en UTF-8 le
corrompt sans rien signaler.

---

## Prérequis

- **Unity 6** (`6000.5.6f1` par défaut) installé via Unity Hub.
- **.NET 8 SDK** pour `dotnet test`.
- **Python 3** pour `serve_web.py` et `piloter_jeu.py` (+ `pillow` pour les captures).
- **L'app itch.io**, qui fournit et met à jour `butler.exe` toute seule.
