#!/bin/bash

# ==============================================================================
#                      MINITALK UNIVERSAL TESTER
# ==============================================================================
# Ce script teste la fonctionnalité d'un projet Minitalk (client/serveur)
# en se basant sur le comportement attendu plutôt que sur des détails
# d'implémentation spécifiques.
#
# Principales améliorations par rapport à une version basique :
#   1. Détection de PID flexible : Trouve le premier nombre que le serveur
#      affiche, peu importe le formatage (ex: "PID: 123" ou juste "123").
#   2. Attente active (Polling) : Au lieu d'un `sleep` fixe, le script
#      vérifie activement si le message est arrivé, avec un timeout.
#      Cela s'adapte aux implémentations rapides comme aux plus lentes.
#   3. Configuration facile : Les noms des binaires et le timeout sont
#      aisément modifiables au début du script.
#   4. Messages d'erreur clairs : En cas d'échec, le script montre ce qui
#      était attendu et ce qui a été reçu.
# ==============================================================================


# --- Configuration ---
# Noms des exécutables. Modifiez-les si votre projet utilise des noms différents.
CLIENT_BIN="./client"
SERVER_BIN="./server"

# Fichier de log pour la sortie du serveur.
SERVER_LOG="server_output.log"

# Timeout en secondes pour attendre la réception d'un message par le serveur.
MESSAGE_TIMEOUT=5


# --- Couleurs pour l'affichage ---
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)


# --- Variables globales ---
TEST_OK=0
TEST_TOTAL=0
SERVER_PROCESS_ID=0
SERVER_REAL_PID=""


# --- Fonctions de test ---

## 🔎 Étape 1 : Compilation
# Vérifie la présence des binaires ou tente de les compiler avec 'make'.
function check_and_compile {
    echo "🔎 Vérification des binaires '${CLIENT_BIN}' et '${SERVER_BIN}'..."
    if [ ! -x "$CLIENT_BIN" ] || [ ! -x "$SERVER_BIN" ]; then
        echo "${YELLOW}Binaires non trouvés. Tentative de compilation avec 'make'...${RESET}"
        if [ ! -f "Makefile" ]; then
            echo "${RED}❌ Aucun Makefile trouvé. Impossible de compiler.${RESET}"
            exit 1
        fi
        
        make_output=$(make 2>&1)
        if [ $? -ne 0 ]; then
            echo "${RED}❌ La compilation a échoué. Erreur :${RESET}"
            echo "$make_output"
            exit 1
        fi
        echo "${GREEN}✅ Compilation réussie.${RESET}"
    fi

    if [ ! -x "$CLIENT_BIN" ] || [ ! -x "$SERVER_BIN" ]; then
        echo "${RED}❌ Les binaires sont toujours introuvables après la compilation.${RESET}"
        exit 1
    fi
}

## 🚀 Étape 2 : Lancement du serveur
# Lance le serveur et capture son PID de manière flexible.
function launch_server {
    echo "🚀 Lancement du serveur..."
    > "$SERVER_LOG" # Nettoie le log précédent
    
    # Lance le serveur en arrière-plan et stocke son PID de processus
    $SERVER_BIN > "$SERVER_LOG" 2>&1 &
    SERVER_PROCESS_ID=$!

    echo "⏳ Attente du PID affiché par le serveur..."
    # Boucle pendant 5s max pour trouver le PID dans le log du serveur.
    # Cette méthode est universelle car elle cherche le PREMIER nombre affiché.
    for i in {1..50}; do
        SERVER_REAL_PID=$(grep -o -m 1 '[0-9]\+' "$SERVER_LOG")
        if [[ "$SERVER_REAL_PID" =~ ^[0-9]+$ ]]; then
            echo "${GREEN}PID du serveur capturé : $SERVER_REAL_PID${RESET}"
            return
        fi
        sleep 0.1
    done

    echo "${RED}❌ Le PID du serveur n'a pas été trouvé dans '$SERVER_LOG' après 5 secondes.${RESET}"
    echo "--- Contenu du log serveur ---"
    cat "$SERVER_LOG"
    echo "----------------------------"
    kill $SERVER_PROCESS_ID 2>/dev/null
    exit 1
}

## 🧪 Étape 3 : Test de transmission de messages
# Envoie un message et vérifie activement sa réception.
function test_message {
    local MESSAGE="$1"
    local DESCRIPTION="$2"
    ((TEST_TOTAL++))
    
    echo -n "   - Test: $DESCRIPTION..."

    # Le client est exécuté et sa sortie n'est pas masquée pour voir les erreurs.
    $CLIENT_BIN "$SERVER_REAL_PID" "$MESSAGE"
    
    # Boucle d'attente active (polling) avec timeout.
    local start_time=$(date +%s)
    while true; do
        # `tr -d '\0'` supprime les octets nuls qui peuvent gêner `grep`.
        # `grep -qF` cherche une chaîne de caractères fixe silencieusement.
        if tr -d '\0' < "$SERVER_LOG" | grep -qF -- "$MESSAGE"; then
            echo " ${GREEN}✅ Reçu${RESET}"
            ((TEST_OK++))
            return
        fi
        
        local current_time=$(date +%s)
        if (( current_time - start_time >= MESSAGE_TIMEOUT )); then
            echo " ${RED}❌ Échec (Timeout)${RESET}"
            echo "     Message attendu: '$MESSAGE'"
            echo "     Log du serveur:"
            echo "     ----------------"
            # Affiche les 5 dernières lignes du log pour le diagnostic.
            tail -n 5 "$SERVER_LOG" | sed 's/^/     /'
            echo "     ----------------"
            return
        fi
        sleep 0.1
    done
}

## 🤝 Étape 4 : Test de l'accusé de réception (ACK)
# Vérifie si le client se bloque quand le serveur n'envoie pas d'ACK.
function test_acknowledgement {
    ((TEST_TOTAL++))
    echo -n "   - Test: Le client attend l'accusé de réception (ACK)..."

    # Lance un client vers un PID invalide en arrière-plan.
    ($CLIENT_BIN 999999 "test_ack" > /dev/null 2>&1) &
    local CLIENT_PID=$!

    sleep 2 # Laisse le temps au client de se lancer et de se bloquer.

    # Vérifie si le processus client est toujours en cours d'exécution.
    if ps -p $CLIENT_PID > /dev/null; then
        echo " ${GREEN}✅ Bloqué (comportement attendu)${RESET}"
        kill $CLIENT_PID 2>/dev/null # Termine le client qui est bloqué.
        ((TEST_OK++))
    else
        echo " ${RED}❌ Échec (le client n'a pas attendu l'ACK)${RESET}"
    fi
}


## 🧹 Étape 5 : Nettoyage
# Arrête le serveur et supprime les fichiers générés.
function cleanup {
    echo "🧹 Nettoyage des processus et des fichiers..."
    if [ $SERVER_PROCESS_ID -ne 0 ]; then
        kill $SERVER_PROCESS_ID 2>/dev/null
    fi
    rm -f "$SERVER_LOG"
    if [ -f "Makefile" ] && grep -q "fclean:" "Makefile"; then
        make fclean > /dev/null 2>&1
    fi
}


# --- Exécution principale ---
trap cleanup EXIT # Assure que la fonction cleanup est appelée à la fin du script.

check_and_compile

launch_server

echo -e "\n--- Début des tests de transmission ---"
test_message "salut" "Message simple"
test_message "Ceci est une chaîne de caractères plus longue avec des espaces" "Phrase longue"
test_message "42" "Nombres"
test_message "特殊文字" "Caractères Unicode (Japonais)"
test_message "The quick brown 🦊 jumps over the lazy 🐶" "Phrase complexe avec emojis"
test_message "" "Chaîne vide (cas particulier)"

echo -e "\n--- Début des tests de comportement ---"
test_acknowledgement

# --- Bilan ---
echo ""
echo "--- Bilan des tests ---"
if [ "$TEST_OK" -eq "$TEST_TOTAL" ]; then
    echo "${GREEN}✅ Tous les tests sont passés ! ($TEST_OK/$TEST_TOTAL)${RESET}"
else
    echo "${RED}❌ $TEST_OK tests réussis sur $TEST_TOTAL.${RESET}"
fi
echo "-----------------------"
