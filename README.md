# Testeur Automatique pour `minitalk`

Ce script bash permet de **tester automatiquement** le bon fonctionnement de ton projet `minitalk`, y compris les **bonus**.

---

## Fichier

Nom du script : `test_mt.sh`

---

## Contenu testé

| Test                         | Description |
|------------------------------|-------------|
| ✅ Message simple            | Vérifie l’envoi d’une chaîne de base |
| ✅ Caractères spéciaux       | Teste les caractères comme `!` ou `42` |
| ✅ Unicode                   | Envoie des emojis (`🐍`, `😎`, etc.) |
| ✅ Fin de message (`\0`)     | Le serveur doit couper à `\0` |
| 🔁 Bonus ACK                 | Vérifie si le client **attend bien** un signal du serveur après chaque caractère |

---

## Comment utiliser le testeur

1. Assure-toi d’avoir compilé `server` et `client`  
   (automatiquement fait si `Makefile` présent)

2. Donne les droits d’exécution au script :

```bash
chmod +x test_minitalk_bonus.sh
```

3. Lance le script :

```bash
./test_minitalk_bonus.sh
```

---

## Exemple de sortie réussie

```
🛠️ Compilation...
🚀 Lancement du serveur...
📡 PID capturé : 26475
✅ Message texte simple
✅ Caractère Unicode 🐍
✅ Emoji 😎
✅ Gestion du caractère nul (ne doit afficher que abc)
✅ Le client attend l'accusé de réception

🎉 Tous les tests sont passés ! (5/5)
```

---

## Si un test échoue...

Par exemple :
```
❌ Le client n'attend pas le ACK correctement
```

Cela signifie que tu n’as pas encore implémenté le **bonus d’accusé de réception** (`pause()` côté client + `kill(pid, SIGUSR1)` côté serveur).

---

## 📂 Arborescence minimale

```
.
├── server.c
├── client.c
├── libft_utils.c
├── Makefile (optionnel)
├── test_mt.sh
└── README_TEST.md
```

---
