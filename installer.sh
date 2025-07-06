#!/bin/bash

SCRIPT_NAME="tester_mt"
INSTALL_DIR="$HOME/.local/bin"
INSTALL_PATH="$INSTALL_DIR/$SCRIPT_NAME"
RAW_URL="https://raw.githubusercontent.com/amn93p/tester_mt/main/tester_mt"

mkdir -p "$INSTALL_DIR"

echo "⬇️  Téléchargement de $SCRIPT_NAME..."
curl -fsSL "$RAW_URL" -o "$INSTALL_PATH" || {
    echo "❌ Échec du téléchargement depuis $RAW_URL"
    exit 1
}

chmod +x "$INSTALL_PATH"
echo "✅ $SCRIPT_NAME installé dans : $INSTALL_PATH"

if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    SHELL_RC=""
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    else
        SHELL_RC="$HOME/.profile"
    fi

    if ! grep -q "$INSTALL_DIR" "$SHELL_RC"; then
        echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_RC"
        echo "🛠️  Ajout de $INSTALL_DIR au PATH dans $SHELL_RC"
    fi

    echo "🔁 Recharge ton terminal ou exécute :"
    echo "    source $SHELL_RC"
else
    echo "🚀 Tu peux maintenant utiliser : tester_mt"
fi
