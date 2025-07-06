
# 🧪 Testeur Automatique pour `minitalk`

Ce dépôt contient deux testeurs distincts pour tester le projet `minitalk` de l’école 42 :

- Une version **Bash** (`test_mt.sh`)
- Une version **Python** plus complète (`tmt.py`)

---

## 📁 Fichiers importants

| Fichier            | Rôle                                                   |
|--------------------|--------------------------------------------------------|
| `test_mt.sh`       | Testeur rapide en Bash (ancien)                        |
| `installer.sh`     | Installe le testeur Bash (`tester_mt`)                |
| `tmt.py`           | Testeur avancé en Python avec menu interactif         |
| `installer_py.sh`  | Installe la version Python globalement (`tmt`)        |

---

## ✅ Fonctionnalités testées

| Test                           | Bash (`test_mt.sh`) | Python (`tmt.py`) |
|--------------------------------|----------------------|--------------------|
| Message simple                 | ✅                   | ✅                 |
| Caractères spéciaux            | ✅                   | ✅ (aléatoire)     |
| Unicode                        | ✅                   | ✅                 |
| Fin de message (`\0`)         | ✅                   | ✅                 |
| Accusé de réception (SIGUSR)   | ✅                   | ✅ (bonus clair)   |
| PID affiché                    | ❌                   | ✅                 |
| Messages multiples             | ❌                   | ✅                 |
| Performance (<1s pour 100c)    | ❌                   | ✅                 |
| Résumé détaillé et coloré      | ❌                   | ✅                 |
| Menu interactif                | ❌                   | ✅                 |

---

## 🧰 Installation

### 🔹 Version Bash

```bash
curl -sSL https://raw.githubusercontent.com/amn93p/tester_mt/main/installer.sh | bash
```

Utilisation :

```bash
tester_mt
```

---

### 🔸 Version Python (recommandée)

```bash
curl -sSL https://raw.githubusercontent.com/amn93p/tester_mt/main/installer_py.sh | bash
```

Utilisation :

```bash
tmt
```

---

## 🚀 Utilisation locale (sans installation)

Si tu ne veux pas installer globalement, tu peux exécuter directement :

```bash
python3 tmt.py
```
ou
```bash
bash test_mt.sh
```

---

## 📂 Arborescence minimale du projet

```
.
├── server.c
├── client.c
├── Makefile (optionnel)
└── autres fichiers...
```

---

## 📌 Remarques

- Le testeur Python détecte automatiquement le `Makefile` et compile si besoin.
- Il distingue les tests obligatoires et les bonus.
- Un résumé final indique si le projet est **validé**, **partiellement**, ou **incomplet**.

Bon courage pour ton projet `minitalk` ! 🚀
