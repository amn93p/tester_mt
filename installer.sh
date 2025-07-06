#!/bin/bash

SCRIPT_NAME="tester_mt"
INSTALL_DIR="$HOME/.local/bin"
INSTALL_PATH="$INSTALL_DIR/$SCRIPT_NAME"
RAW_URL="https://raw.githubusercontent.com/amn93p/tester_mt/main/tester_mt"

echo "📦 Installation du testeur $SCRIPT_NAME..."

mkdir -p "$INSTALL_DIR"

echo "⬇️  Téléchargement de $SCRIPT_NAME..."
if curl -fsSL "$RAW_URL" -o "$INSTALL_PATH"; then
    chmod +x "$INSTALL_PATH"
    echo "✅ $SCRIPT_NAME installé dans : $INSTALL_PATH"
else
    echo "❌ Échec du téléchargement depuis $RAW_URL"
    exit 1
fi

if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    SHELL_RC=""
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    elif [ -n "$SHELL" ] && [[ "$SHELL" == */zsh ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$SHELL" ] && [[ "$SHELL" == */bash ]]; then
        SHELL_RC="$HOME/.bashrc"
    else
        SHELL_RC="$HOME/.profile"
    fi

    if [ ! -f "$SHELL_RC" ]; then
        touch "$SHELL_RC"
    fi

    if ! grep -q "$INSTALL_DIR" "$SHELL_RC"; then
        echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_RC"
        echo "🛠️  Ajout de $INSTALL_DIR au PATH dans $SHELL_RC"
    fi

    echo "🔁 Recharge du shell..."
    source "$SHELL_RC"
    echo "✅ PATH mis à jour pour cette session."
fi

if command -v $SCRIPT_NAME > /dev/null 2>&1; then
    echo "🚀 Tu peux maintenant exécuter le testeur depuis n'importe où avec :"
    echo "    $SCRIPT_NAME"
else
    echo "⚠️  Le testeur n'est pas immédiatement disponible. Essaie :"
    echo "    source $SHELL_RC"
    echo "puis relance ton terminal si nécessaire."
fi
