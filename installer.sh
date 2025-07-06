#!/bin/bash

# Compilation
echo "📦 Compilation..."
make || { echo "❌ Compilation échouée."; exit 1; }

# Dossier de destination dans PATH
BIN_DIR="$HOME/.local/bin"
SCRIPT_NAME="test_mt.sh"
INSTALL_PATH="$BIN_DIR/$SCRIPT_NAME"

# Vérifie que test_mt.sh existe
if [ ! -f "$SCRIPT_NAME" ]; then
    echo "❌ Fichier $SCRIPT_NAME introuvable dans le répertoire courant."
    exit 1
fi

# Crée ~/.local/bin si nécessaire
mkdir -p "$BIN_DIR"

# Copie test_mt.sh dans ~/.local/bin/
cp "$SCRIPT_NAME" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"

echo "✅ $SCRIPT_NAME installé dans $INSTALL_PATH"

# Vérifie si ~/.local/bin est dans le PATH
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo "⚠️  $BIN_DIR n'est pas dans votre PATH."
    echo "Ajoutez cette ligne à votre ~/.bashrc ou ~/.zshrc :"
    echo "export PATH=\"\$PATH:$BIN_DIR\""
else
    echo "🚀 Vous pouvez maintenant exécuter le testeur depuis n’importe où avec :"
    echo "    test_mt.sh"
fi
