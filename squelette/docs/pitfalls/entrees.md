# Pièges — Entrées


**⚠ `KeyCode` et `Key` désignent une POSITION sur un clavier QWERTY**, jamais le caractère imprimé.
Sur un clavier AZERTY, `Key.A` / `Key.D` / `Key.W` placent les commandes sous les touches marquées
**Q / D / Z**. C'est le résultat voulu, pas un bug. Corollaire : proscrire `A`, `Q`, `Z`, `W`, `M`
pour les raccourcis globaux — préférer `Tab`, `R`, les chiffres ou les flèches, dont la position est
commune aux deux dispositions. **Ce piège n'a été découvert qu'en injectant de vraies touches.**

**⚠ `InputSystemUIInputModule` et non `StandaloneInputModule`.** Avec le package Input System actif,
l'ancien module ne reçoit rien : l'UI cesse simplement de répondre, sans erreur.

**⚠ La toute première touche après une prise de focus se perd**, sur le build Windows comme dans le
navigateur. Toujours en envoyer une pour rien avant de mesurer quoi que ce soit.

