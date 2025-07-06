#!/bin/bash

SCRIPT_NAME="test_mt.sh"
DEST_DIR="$HOME/.local/bin"
DEST_PATH="$DEST_DIR/$SCRIPT_NAME"

if [ ! -f "$SCRIPT_NAME" ]; then
    echo "❌ $SCRIPT_NAME introuvable dans le répertoire courant."
    exit 1
fi

mkdir -p "$DEST_DIR"

cp "$SCRIPT_NAME" "$DEST_PATH"
chmod +x "$DEST_PATH"

echo "✅ Testeur installé dans : $DEST_PATH"

if ! echo "$PATH" | grep -q "$DEST_DIR"; then
    echo "⚠️  $DEST_DIR n'est pas dans votre PATH."
    echo "Ajoutez ceci à votre ~/.bashrc ou ~/.zshrc :"
    echo "    export PATH=\"\$PATH:$DEST_DIR\""
else
    echo "🚀 Vous pouvez maintenant exécuter le testeur depuis n’importe où avec :"
    echo "    test_mt.sh"
fi
