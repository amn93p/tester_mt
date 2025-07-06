#!/bin/bash

TARGET="/usr/local/bin/test_mt.sh"

if [ -f "$TARGET" ]; then
    echo "🧹 Suppression de $TARGET..."
    sudo rm "$TARGET"
    echo "✅ test_mt.sh désinstallé."
else
    echo "❌ Aucun test_mt.sh installé dans /usr/local/bin"
fi
