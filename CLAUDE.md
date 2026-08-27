# CLAUDE.md — travailler SUR le gabarit

⚠ **Ce dépôt n'est pas un jeu.** C'est le gabarit dont on instancie les jeux. Le code sous
`squelette/` n'est jamais compilé ici : il porte des jetons `__XXX__` qui ne sont résolus qu'à
l'instanciation. Ne « corrige » donc pas un `__NAMESPACE__` qui ressemble à une erreur.

Ce qu'il fait et comment on s'en sert : **`README.md`**.

## Ce qui vit où

```
README.md              Le mode d'emploi (c'est LE document du dépôt)
tools/new-game.ps1     Le scaffolder : demande, copie, substitue, renomme, git init, premier build
local.settings.json    Réponses mémorisées (dossier des jeux, Unity, pseudo itch) — NON versionné
squelette/             Tout ce qui est copié dans un nouveau projet
```

Le scaffolder n'a **aucune valeur par défaut tirée de cette machine** : ni dossier de destination,
ni chemin d'Unity. Ce qui manque est demandé, puis mémorisé dans `local.settings.json`. Les
fonctions de détection vivent dans `squelette/tools/environnement.ps1`, que `new-game.ps1`
dot-source — une seule implémentation, pas deux qui divergent.

## Modifier le squelette

1. **Éditer dans `squelette/`**, jamais dans un projet généré en espérant que ça remonte.
2. **Utiliser les jetons de la table du README** — pas de nom de jeu en dur, pas de chemin absolu.
   Un chemin d'outil externe (Unity, Python) passe **obligatoirement** par
   `tools/environnement.ps1` : `Get-UnityPathOuMourir`, `Resolve-PythonCommand`. Un chemin écrit en
   dur marche sur la machine où on l'a écrit et nulle part ailleurs — symptôme chez le suivant :
   « Unity.exe : Le terme «Unity.exe» n'est pas reconnu comme nom d'applet de commande ».
3. Ce qui n'est pas une extension texte connue (`$extensions` dans `new-game.ps1`) n'est **pas**
   substitué : ajouter l'extension si un nouveau type de fichier porte un jeton.
4. **Éprouver l'instanciation** avant de committer :
   ```powershell
   & "tools/new-game.ps1" -Name "Test Gabarit" -Destination "$env:TEMP" -ItchUser essai -NoGit -NoCd
   ```
   Le script signale lui-même les jetons survivants. Aucun argument n'est demandé de façon
   interactive ici : c'est la forme à employer depuis un agent ou un CI, où `Read-Host` ne peut
   pas répondre. `-NoCd` garde la session dans le gabarit — sans lui elle finit dans le dossier
   d'essai, qu'on supprime juste après, et le shell se retrouve avec un cwd qui n'existe plus.
   Supprimer le dossier d'essai ensuite.

## Ajouter un piège à `docs/PITFALLS_UNITY.md`

C'est le contenu le plus précieux du dépôt, et il a une règle d'admission stricte :

> **Une entrée décrit un défaut qui ne lève AUCUNE erreur.** Ni compilation, ni exception, ni
> avertissement — seulement un comportement faux. Une bonne pratique ordinaire n'y a pas sa place.

Chaque entrée dit : **ce qui se passe**, **pourquoi ça ne se voit pas**, et **ce qui marche**. Le
symptôme observé vaut mieux qu'une règle abstraite : « le jeu meurt sur un `RuntimeError: memory
access out of bounds` de trois cents lignes » est reconnaissable, « attention au cache » ne l'est
pas.

Marquer **[hérité]** ce qui vient d'un projet antérieur et n'a pas été revérifié depuis.

## Faire évoluer un agent

Si un agent prend systématiquement une mauvaise décision, **enrichir son `.md`** plutôt que de le
corriger à chaque session. Un agent déclare une liste `tools:` **fermée** : s'il n'y déclare pas un
outil, il ne *peut pas* l'appeler, quelle que soit la consigne écrite ailleurs. *Une capacité qu'on
documente sans la câbler n'existe pas.*

## Origine

Distillé de deux projets publiés : **Chimera Protocol** (survivor roguelite, ~800 tests, équipe de
9 agents) et **Smily Volley** (jeu web, scène construite par code, portage tactile). Quand l'un des
deux apprend quelque chose de généralisable, le remonter ici ; quand l'un des deux donne tort au
gabarit, le corriger ici.
