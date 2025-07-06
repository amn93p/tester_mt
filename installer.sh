#!/bin/bash

# Script pour télécharger et installer le testeur Minitalk

SCRIPT_NAME="tester_mt"
INSTALL_DIR="$HOME/.local/bin"
INSTALL_PATH="$INSTALL_DIR/$SCRIPT_NAME"
RAW_URL="https://raw.githubusercontent.com/amn93p/tester_mt/refs/heads/main/test_mt.sh"

clear
echo "📦 Installation du testeur $SCRIPT_NAME..."

# Crée le répertoire d'installation s'il n'existe pas
mkdir -p "$INSTALL_DIR"

echo "⬇️  Téléchargement de $SCRIPT_NAME..."
# Télécharge le script
if curl -fsSL "$RAW_URL" -o "$INSTALL_PATH"; then
    # Rend le script exécutable
    chmod +x "$INSTALL_PATH"
    echo "✅ $SCRIPT_NAME installé avec succès dans : $INSTALL_PATH"
else
    echo "❌ Échec du téléchargement depuis $RAW_URL"
    exit 1
fi

# Vérifie si le répertoire d'installation est dans le PATH
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo "🛠️  Le répertoire $INSTALL_DIR n'est pas dans votre PATH."
    SHELL_RC=""
    # Détecte le fichier de configuration du shell (.zshrc, .bashrc, etc.)
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    elif [ -n "$SHELL" ] && [[ "$SHELL" == */zsh ]]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$SHELL" ] && [[ "$SHELL" == */bash ]]; then
        SHELL_RC="$HOME/.bashrc"
    else
        # Fallback générique
        SHELL_RC="$HOME/.profile"
    fi

    echo "🖋️  Ajout de la configuration à $SHELL_RC..."
    # Ajoute la ligne au fichier de config du shell si elle n'y est pas déjà
    if ! grep -q "export PATH=\"\$PATH:$INSTALL_DIR\"" "$SHELL_RC"; then
        echo "" >> "$SHELL_RC"
        echo "# Ajout du répertoire local bin au PATH" >> "$SHELL_RC"
        echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_RC"
        echo "✅ Ligne ajoutée à $SHELL_RC."
    else
        echo "✅ La configuration du PATH existe déjà dans $SHELL_RC."
    fi

    echo "🔁 Pour appliquer les changements, veuillez redémarrer votre terminal ou exécuter :"
    echo "   source $SHELL_RC"
fi

clear
# Affiche les instructions finales
echo "🚀 Installation terminée !"
if command -v $SCRIPT_NAME > /dev/null 2>&1; then
    echo "Vous pouvez maintenant exécuter le testeur depuis n'importe où avec la commande :"
    echo -e "\n  ${C_GREEN}${C_BOLD}$SCRIPT_NAME${C_RESET}\n"
else
    echo "Le testeur n'est pas immédiatement disponible dans votre PATH."
    echo "Veuillez redémarrer votre terminal ou exécuter la commande suggérée ci-dessus."
fi
