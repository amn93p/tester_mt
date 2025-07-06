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

> ## Comment utiliser le testeur  
>
> 1. Assure-toi d’avoir compilé `server` et `client` (automatiquement fait si `Makefile` présent)  
> 2. Télécharge et utilise l'installateur :
> ```bash
> curl -sSL https://raw.githubusercontent.com/amn93p/tester_mt/main/installer.sh | bash
> ```
> 3. Lance le script de test :
> ```bash
> ./test_mt.sh
> ```

---

## Arborescence minimale

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
