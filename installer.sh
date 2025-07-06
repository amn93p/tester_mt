#!/bin/bash

SCRIPT_NAME="test_mt.sh"
BIN_DIR="$HOME/.local/bin"
DEST="$BIN_DIR/$SCRIPT_NAME"
RAW_URL="https://raw.githubusercontent.com/amn93p/tester_mt/main/test_mt.sh"

mkdir -p "$BIN_DIR"

echo "⬇️  Téléchargement de $SCRIPT_NAME..."
curl -fsSL "$RAW_URL" -o "$DEST" || {
    echo "❌ Échec du téléchargement depuis $RAW_URL"
    exit 1
}

chmod +x "$DEST"

echo "✅ $SCRIPT_NAME installé dans $DEST"

if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo "⚠️  $BIN_DIR n'est pas dans votre PATH."
    echo "Ajoutez cette ligne à votre ~/.bashrc ou ~/.zshrc :"
    echo "    export PATH=\"\$PATH:$BIN_DIR\""
else
    echo "🚀 Vous pouvez maintenant exécuter le testeur depuis n’importe où avec :"
    echo "    test_mt.sh"
fi
