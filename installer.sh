#!/bin/bash
set -e

PROJECT_NAME="minitalk"
SERVER_BIN="server"
CLIENT_BIN="client"

echo "🔧 Installation du projet $PROJECT_NAME..."

if [ -f Makefile ]; then
    echo "Compilation via Makefile..."
    make re
else
    echo "⚠ Aucun Makefile trouvé. Compilation manuelle..."
    gcc -Wall -Wextra -Werror server.c libft_utils.c -o $SERVER_BIN
    gcc -Wall -Wextra -Werror client.c libft_utils.c -o $CLIENT_BIN
fi

if [ ! -f "$SERVER_BIN" ] || [ ! -f "$CLIENT_BIN" ]; then
    echo "❌ Compilation échouée : binaires manquants."
    exit 1
fi

BIN_DIR="./bin"
mkdir -p "$BIN_DIR"

mv -f "$SERVER_BIN" "$BIN_DIR/"
mv -f "$CLIENT_BIN" "$BIN_DIR/"

chmod +x "$BIN_DIR/$SERVER_BIN" "$BIN_DIR/$CLIENT_BIN"

echo "✅ Installation terminée."
echo "Binaires placés dans : $BIN_DIR"
echo "➡ Lancez le serveur avec : $BIN_DIR/$SERVER_BIN"
echo "➡ Et le client avec :     $BIN_DIR/$CLIENT_BIN [PID] [message]"
