#!/bin/bash

# Script d'installation de TMT (Tester MiniTalk Tool - version Python)

SCRIPT_NAME="tmt"
INSTALL_DIR="$HOME/.local/bin"
INSTALL_PATH="$INSTALL_DIR/$SCRIPT_NAME"
PYTHON_SCRIPT_URL="https://raw.githubusercontent.com/amn93p/tester_mt/main/tmt.py"

clear
echo "📦 Installation du testeur ${SCRIPT_NAME}..."

mkdir -p "$INSTALL_DIR"

echo "⬇️  Téléchargement du script Python..."
if curl -fsSL "$PYTHON_SCRIPT_URL" -o "$INSTALL_PATH"; then
    chmod +x "$INSTALL_PATH"
    echo "✅ Script installé : $INSTALL_PATH"
else
    echo "❌ Échec du téléchargement depuis $PYTHON_SCRIPT_URL"
    exit 1
fi

if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    SHELL_RC=""
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    elif [[ "$SHELL" == */zsh ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [[ "$SHELL" == */bash ]]; then
        SHELL_RC="$HOME/.bashrc"
    else
        SHELL_RC="$HOME/.profile"
    fi

    echo "🛠️  Ajout de $INSTALL_DIR au PATH dans $SHELL_RC..."
    if ! grep -q "$INSTALL_DIR" "$SHELL_RC"; then
        echo "" >> "$SHELL_RC"
        echo "# Ajout du testeur Minitalk au PATH" >> "$SHELL_RC"
        echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_RC"
        echo "✅ Ligne ajoutée à $SHELL_RC"
    fi

    echo "🔁 Veuillez exécuter : source $SHELL_RC ou redémarrer le terminal."
fi

clear
echo "🚀 Installation terminée !"
echo "Utilisez maintenant le testeur avec la commande :"
echo -e "\n  ${BOLD}${GREEN}tmt${RESET}\n"
