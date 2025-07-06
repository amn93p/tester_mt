#!/bin/bash

SCRIPT_NAME="tester_mt"
INSTALL_DIR="$HOME/.local/bin"
INSTALL_PATH="$INSTALL_DIR/$SCRIPT_NAME"
RAW_URL="https://raw.githubusercontent.com/amn93p/tester_mt/main/test_mt.sh"

mkdir -p "$INSTALL_DIR"

echo "⬇️  Téléchargement de $SCRIPT_NAME..."
curl -fsSL "$RAW_URL" -o "$INSTALL_PATH" || {
    echo "❌ Échec du téléchargement depuis $RAW_URL"
    exit 1
}

chmod +x "$INSTALL_PATH"

echo "✅ $SCRIPT_NAME installé dans : $INSTALL_PATH"

if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo "⚠️  $INSTALL_DIR n'est pas dans votre PATH."
    echo "➡️  Ajoutez ceci à votre ~/.bashrc ou ~/.zshrc :"
    echo "    export PATH=\"\$PATH:$INSTALL_DIR\""
else
    echo "🚀 Vous pouvez maintenant exécuter le testeur avec :"
    echo "    tester_mt"
fi
