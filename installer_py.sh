#!/bin/bash

# Nouveau script pour installer le testeur Python TMT

INSTALL_DIR="$HOME/.local/bin"
TARGET="$INSTALL_DIR/tmt"
PY_URL="https://raw.githubusercontent.com/amn93p/tester_mt/main/tmt.py"

echo "📦 Installation de TMT (version Python)..."
mkdir -p "$INSTALL_DIR"

# Télécharger et renommer tmt.py => tmt
echo "⬇️  Téléchargement..."
if curl -fsSL "$PY_URL" -o "$TARGET"; then
    chmod +x "$TARGET"
    echo "✅ Script installé à : $TARGET"
else
    echo "❌ Erreur lors du téléchargement depuis : $PY_URL"
    exit 1
fi

# Vérifie si ~/.local/bin est dans le PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    SHELL_RC=""
    [ -n "$ZSH_VERSION" ] && SHELL_RC="$HOME/.zshrc"
    [ -n "$BASH_VERSION" ] && SHELL_RC="$HOME/.bashrc"
    [ -z "$SHELL_RC" ] && SHELL_RC="$HOME/.profile"

    echo "🛠️  Ajout de ~/.local/bin au PATH dans $SHELL_RC..."
    echo -e "\n# Ajout automatique du testeur TMT\nexport PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_RC"
    echo "✅ Ligne ajoutée. Rechargez votre shell : source $SHELL_RC"
fi

echo -e "\n🚀 Installation terminée !"
echo "Vous pouvez maintenant exécuter le testeur avec :"
echo -e "\n  tmt\n"
