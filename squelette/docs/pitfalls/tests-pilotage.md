# Pièges — Tests headless et pilotage


Voir le skill **`/verifier-en-jeu`** pour la procédure complète. Les pièges, en résumé :

- **Le focus est LE point de blocage** : hors focus, Unity ne reçoit aucune touche et aucun mouvement
  de souris — le test ment en silence. `SetForegroundWindow` seul échoue depuis un shell non
  interactif ; seul un **vrai clic** donne le focus légitimement.
- **`keybd_event` doit porter le code de balayage** (Unity lit le raw input), et **les flèches
  exigent `KEYEVENTF_EXTENDEDKEY`** — sans lui, leur scan code est celui du pavé numérique et la
  touche est perdue en silence.
- **`SetCursorPos` ne met rien dans le flux d'entrée** : utiliser `SendInput` avec
  `MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE`, coordonnées normalisées sur 0..65535.
- **Un appui instantané ne teste que `wasPressedThisFrame`** : tout ce qui demande un maintien exige
  un vrai maintien. Conclure « les flèches ne marchent pas » sur un appui instantané est faux.
- **Le splash Unity dure ~2 s**, et **le pare-feu Windows ouvre une alerte modale au premier
  lancement de chaque nouveau chemin d'exe** — elle vole le focus et grise la fenêtre.
- **Ne pas coder en dur la position des éléments visés** : une refonte les déplace, et les clics
  tombent dans le vide sans aucune erreur.
- **Les PlayerPrefs sont persistants** : piloter une option par N appuis donne un résultat *relatif*
  à la session précédente.
- **Les seuils d'analyse de pixels** : deux conclusions fausses de suite (un centroïde contaminé par
  un élément de décor, un comptage de pixels clairs qui comptait le texte du HUD). Cadrer hors HUD,
  exclure chaque élément connu par sa teinte, **puis regarder l'image**.
- **Ce qui est de la pure géométrie ne se prouve pas en jouant** : un fichier jetable dans
  `Assets/Editor` appelé par `-executeMethod` logge les bornes à deux pixels près. C'est ce qui a
  rattrapé une zone trois fois trop large dont la formule se relisait parfaitement.

