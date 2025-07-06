#!/bin/bash

SCRIPT_NAME="tester_mt"
INSTALL_PATH="$HOME/.local/bin/$SCRIPT_NAME"

echo "🧹 Désinstallation du testeur..."

if [ -f "$INSTALL_PATH" ]; then
    rm "$INSTALL_PATH"
    echo "✅ $SCRIPT_NAME supprimé de $INSTALL_PATH"
else
    echo "❌ Aucun script trouvé à $INSTALL_PATH"
fi

# Suppression du PATH si nécessaire (facultatif mais propre)
RC_FILE=""
if [ -n "$ZSH_VERSION" ]; then
    RC_FILE="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    RC_FILE="$HOME/.bashrc"
elif [[ "$SHELL" == */zsh ]]; then
    RC_FILE="$HOME/.zshrc"
elif [[ "$SHELL" == */bash ]]; then
    RC_FILE="$HOME/.bashrc"
else
    RC_FILE="$HOME/.profile"
fi

# Supprimer ligne export PATH si présente
if grep -q "$HOME/.local/bin" "$RC_FILE"; then
    sed -i.bak "/.local\/bin/d" "$RC_FILE"
    echo "🧽 Ligne PATH supprimée de $RC_FILE (backup dans $RC_FILE.bak)"
    echo "💡 Tu devras relancer ton terminal pour que le changement prenne effet."
fi
