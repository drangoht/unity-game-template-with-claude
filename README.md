# unity-game-template

Gabarit de démarrage pour un jeu Unity 2D destiné à itch.io, **piloté par Claude Code**.

Il ne contient pas un moteur de jeu : il contient **ce qu'on refait à chaque fois** — la chaîne de
build en ligne de commande, la publication itch.io avec ses garde-fous, l'outillage de vérification
en jeu, et une équipe d'agents Claude Code déjà instruite des pièges. Le tout distillé de deux
projets publiés, **Chimera Protocol** et **Smily Volley**.

> **Le vrai contenu de ce dépôt, c'est `docs/pitfalls/`.** Chaque entrée correspond à un
> défaut qui n'a levé **ni erreur de compilation, ni exception, ni avertissement** — seulement un
> jeu qui se comporte mal. C'est la catégorie de bug qui coûte des heures et qu'on ne redécouvre
> jamais avec plaisir.

---

## Créer un jeu

Depuis le dossier du gabarit :

```powershell
& "tools/new-game.ps1"
```

Le script demande ce qui lui manque — nom du jeu, **où ranger les projets**, pseudo itch — et
détecte Unity tout seul. Tout se donne aussi en une ligne, et c'est la forme à employer depuis un
agent ou un CI, où `Read-Host` ne peut pas répondre :

```powershell
& "tools/new-game.ps1" `
    -Name "Mon Jeu" `
    -Destination "D:\Jeux" `
    -Pitch "Le classique jeu de Snake" `
    -ItchUser Drangoht `
    -UnityPath "C:\Program Files\Unity\Hub\Editor\6000.5.6f1" `
    -Build
```

Cette commande crée `D:\Jeux\mon-jeu`, avec le namespace C# `MonJeu`, la page itch
`drangoht.itch.io/mon-jeu`, la version d'Unity `6000.5.6f1` lue dans le chemin de l'éditeur — puis
enchaîne sur le premier build sans rien demander, et laisse le terminal dans `D:\Jeux\mon-jeu`.

Ce qui se passe :

1. `squelette/` est copié vers `<dossier des jeux>\mon-jeu` ;
2. les jetons `__XXX__` sont remplacés dans les fichiers **texte**, et les dossiers qui en portent
   sont renommés ;
3. le script vérifie qu'**aucun jeton ne survit** — un jeton oublié compile (c'est un identifiant
   valide) et ne se manifeste que bien plus tard, sous la forme d'un chemin qui n'existe pas ;
4. le chemin d'Unity est écrit dans `tools/local.settings.json` du projet (hors git) ;
5. `git init` + premier commit ;
6. le premier build est proposé — c'est lui qui importe le projet (~20 min) ;
7. **le terminal est placé dans le dossier du jeu** : tout ce qui suit (`tools/build.ps1`, les
   tests, Claude Code) s'y passe, et non dans le gabarit.

### Les commutateurs

Un seul est obligatoire : `-Name`. Tout le reste est déduit, mémorisé d'une exécution à l'autre, ou
demandé.

| Commutateur | Valeur | Défaut | Ce qu'il change |
|---|---|---|---|
| `-Name` | Nom affiché, espaces et accents permis | **demandé** | Menu de l'éditeur, titre de la fenêtre, docs, page itch. Fixe aussi `-Slug` et `-Namespace` |
| `-Slug` | Minuscules, chiffres, tirets | déduit du nom (`Mon Jeu` → `mon-jeu`) | Nom du dossier créé **et** identifiant de la page itch. Rejeté s'il contient une majuscule, un espace ou un accent |
| `-Namespace` | Identifiant C# PascalCase | déduit du slug (`mon-jeu` → `MonJeu`) | Namespace de tout le code, nom de l'exécutable, nom du dossier `Assets/WebGLTemplates/` |
| `-Destination` | Dossier **parent**, créé s'il manque | mémorisé, sinon demandé | Où ranger le jeu. Le projet atterrit dans `<Destination>\<slug>` ; le script s'arrête si ce dossier existe déjà |
| `-ItchUser` | Pseudo itch.io | mémorisé, sinon demandé | L'URL de publication `<pseudo>.itch.io/<slug>`, utilisée par `tools/release_itch.ps1` |
| `-Company` | Nom d'éditeur | la valeur de `-ItchUser` | `PlayerSettings.companyName`, donc le chemin des sauvegardes (`%APPDATA%\..\<Company>\<jeu>`). Le changer plus tard **égare les sauvegardes existantes** |
| `-Pitch` | Une phrase | `Un jeu.` | Le `<meta description>` de la page web, et l'accroche du `README.md`, du `CLAUDE.md`, du GDD et de la page itch du projet |
| `-Commandes` | Une phrase | `Fleches pour se deplacer, Espace pour agir.` | La note affichée sous la barre de chargement du build web — ce que le joueur lit en attendant |
| `-UnityPath` | L'`Unity.exe`, son dossier `Editor`, ou le dossier de version | détecté dans Unity Hub (2ᵈ disque compris), sinon demandé | L'éditeur utilisé pour les builds. Recopié dans `tools/local.settings.json` du projet, qui ne le redemandera jamais |
| `-UnityVersion` | ex. `6000.5.6f1` | lu dans le chemin de l'éditeur trouvé | Ce qu'écrit `ProjectSettings/ProjectVersion.txt`. ⚠ Le forcer sur une version différente de l'éditeur installé fait proposer une migration à la première ouverture dans le Hub |
| `-Build` | *switch* | absent : proposé en interactif, ignoré sinon | Enchaîne le premier build tout de suite (~20 min). Sans lui **et** sans terminal interactif, le projet reste non importé |
| `-NoGit` | *switch* | absent : `git init` + premier commit | Laisse le dossier sans dépôt. Utile pour un essai jetable du gabarit |
| `-NoCd` | *switch* | absent : la session est placée dans le projet créé | Reste où l'on est. ⚠ Sans lui, un `tools/build.ps1` tapé ensuite vise bien le jeu — c'est le but ; avec lui, penser au `cd`. Sans effet si le script tourne dans un processus séparé (`powershell -File`), qui meurt avec sa location |

Les trois réponses réutilisables — `-Destination`, `-ItchUser`, `-UnityPath` — sont écrites dans
`local.settings.json` à la racine du gabarit (non versionné) : au jeu suivant, `-Name` suffit.

```powershell
& "tools/new-game.ps1" -Name "Mon Deuxieme Jeu" -Build
```

Et pour éprouver le gabarit sans rien laisser derrière soi :

```powershell
& "tools/new-game.ps1" -Name "Test Gabarit" -Destination "$env:TEMP" -ItchUser essai -NoGit -NoCd
```

### Rien de propre à une machine dans le dépôt

Ce gabarit ne connaît ni l'arborescence de vos jeux, ni l'endroit où Unity est installé.

- **Où ranger le projet** est demandé à la première utilisation (`-Destination`), puis mémorisé
  dans `local.settings.json`, à la racine du gabarit et **non versionné**.
- **Unity** est cherché dans les installations d'Unity Hub, y compris le *secondary install path*
  (l'autre disque). S'il reste introuvable, le script le demande, et tous les outils du projet
  généré savent ensuite où il est. Un chemin d'éditeur écrit en dur produit toujours le même
  symptôme sur la machine suivante : `Unity.exe : Le terme «Unity.exe» n'est pas reconnu comme nom
  d'applet de commande`.
- **Le pseudo itch** suit le même chemin : demandé une fois, mémorisé.

### Le premier build fait l'import — pas Unity Hub

Le dossier produit contient `Assets/`, `Packages/` et `ProjectSettings/ProjectVersion.txt`. Le
**premier `tools/build.ps1` importe le projet en batchmode** et génère le reste (`Library/`,
`ProjectSettings/` complet) : compter une vingtaine de minutes, sans ouvrir Unity Hub ni l'éditeur.

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
│   ├── skills/             /carte-projet · /rediger-le-gdd · /verifier-en-jeu · /publier-itch
│   └── hooks/              guard.ps1 · run-rules-tests.ps1
├── .github/workflows/      CI : les tests de Rules/ sur un runner Linux, sans Unity
├── Assets/
│   ├── Editor/             BuildTools · RenderPipelineSetup · SceneBuilder
│   ├── Scripts/Rules/      Logique PURE testable
│   ├── Settings/           Assets URP prêts (pipeline, renderer 2D) — aucun réglage à la souris
│   └── WebGLTemplates/     Page hôte : cadrage, tactile, audio, garde-cache
├── .gitattributes          LF partout + fusion YAML Unity + règles LFS pour les gros assets
├── Packages/manifest.json  URP + Input System + uGUI
├── ProjectSettings/        Version d'Unity, et Burst éteint côté Windows — voir son LISEZ-MOI
├── docs/                   GDD (sommaire + gdd/) · pitfalls/ (12 domaines + index) · RELEASE
│                           DEVLOG · TEST_REPORT · ITCH_STORE_PAGE
├── tests/                  xUnit sur Rules/ — aucun moteur requis
└── tools/
    ├── build.ps1           Construire (Windows/web), lancer, capturer — LE point d'entrée
    ├── configurer.ps1      Dire où sont Unity et Python ; diagnostiquer l'environnement
    ├── environnement.ps1   Résolution + mémorisation des chemins d'outils
    └── release_itch.ps1 · serve_web.py · piloter_jeu.py
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

9 agents, 4 skills, 2 hooks — détail dans `GUIDE-EQUIPE.md` du projet généré.

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
   `docs/pitfalls/<domaine>.md`, une consigne dans l'agent concerné, un garde-fou dans un script. C'est
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
| `__ITCH_USER__` | `mon-pseudo` | URL de la page itch |
| `__COMPANY__` | `mon-pseudo` | `PlayerSettings.companyName`, chemin de sauvegarde |
| `__PITCH__` | … | description de la page, GDD |
| `__COMMANDES__` | … | note affichée pendant le chargement web |
| `__UNITY_VERSION__` | `6000.5.6f1` | `ProjectVersion.txt`, docs — déduit de l'éditeur trouvé |
| `__DATE__` | `2026-08-26` | date de création dans `CLAUDE.md` |

⚠ **`__BUILD_ID__`, dans `index.html`, n'est PAS un jeton du gabarit** : il est remplacé par
`BuildTools.StampWebCacheBuster` à chaque build. Le scaffolder ne remplace que les jetons de la
table ci-dessus, jamais tout ce qui ressemble à `__X__` — c'est délibéré.

⚠ La substitution ne touche que les **extensions texte connues**. Réécrire un binaire en UTF-8 le
corrompt sans rien signaler.

---

## Prérequis

- **Unity 6** installé via Unity Hub, où que ce soit sur le disque : il est détecté, et se donne
  par `-UnityPath` sinon.
- **.NET 8 SDK** pour `dotnet test`.
- **Python 3** pour `serve_web.py` et `piloter_jeu.py` (+ `pillow` pour les captures).
- **L'app itch.io**, qui fournit et met à jour `butler.exe` toute seule.

`tools/configurer.ps1`, dans un projet généré, dit lequel manque et où sont les autres.
