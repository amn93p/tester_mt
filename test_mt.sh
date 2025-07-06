#!/bin/bash

# ==============================================================================
# |                                                                            |
# |                 --= Universal Minitalk Tester (Advanced) =--               |
# |                                                                            |
# |      Ce script teste la partie obligatoire ET le bonus (ACK).              |
# |      Il utilise un système de timeout pour valider l'accusé de réception.  |
# |                                                                            |
# ==============================================================================

# --- Configuration ---
SERVER_EXEC="./server"
CLIENT_EXEC="./client"
SERVER_LOG="server.log"
# Timeout en secondes pour le client. S'il dépasse ce temps, il est tué.
# Un client avec bonus DOIT se terminer avant ce timeout.
CLIENT_TIMEOUT=5 

# --- Couleurs ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'

# --- Variables de suivi ---
tests_passed=0
tests_failed=0
test_count=0

# --- Fonctions ---

print_header() {
    echo -e "${C_CYAN}${C_BOLD}"
    echo "    __  __ _       _ _   _      _   _             "
    echo "   |  \\/  (_)     (_) | | |    | | | |   _ __  _   "
    echo "   | \\  / |_ _ __  _| |_| | ___| |_| |_ | '_ \\| | | |"
    echo "   | |\\/| | | '_ \\| | __| |/ _ \\ __| __|| |_) | |_| |"
    echo "   | |  | | | | | | | |_| |  __/ |_| || .__/ \\__, |"
    echo "   |_|  |_|_|_| |_|_|\\__|_|\\___|\\__|\\__||_|    |___/ "
    echo "                      Advanced w/ ACK & Timeout Test"
    echo -e "${C_RESET}"
}

start_server() {
    echo -e "${C_YELLOW}🚀 Démarrage du serveur...${C_RESET}"
    ./$SERVER_EXEC > "$SERVER_LOG" 2>&1 &
    SERVER_PID=$!
    sleep 0.5
    if ! ps -p $SERVER_PID > /dev/null; then
        echo -e "${C_RED}❌ ERREUR: Le serveur n'a pas pu démarrer.${C_RESET}"
        cat "$SERVER_LOG"; exit 1
    fi
    echo -e "${C_GREEN}✅ Serveur démarré avec le PID: ${C_BOLD}$SERVER_PID${C_RESET}\n"
}

kill_server() {
    echo
    echo -e "${C_YELLOW}🛑 Arrêt du serveur (PID: $SERVER_PID)...${C_RESET}"
    if ps -p $SERVER_PID > /dev/null; then
        kill $SERVER_PID; wait $SERVER_PID 2>/dev/null
        echo -e "${C_GREEN}✅ Serveur arrêté.${C_RESET}"
    else
        echo -e "${C_YELLOW}ℹ️ Le serveur n'était plus en cours d'exécution.${C_RESET}"
    fi
    rm -f "$SERVER_LOG"
}

# Fonction de test, maintenant avec gestion du timeout pour l'ACK
run_test() {
    local description="$1"
    local test_string="$2"
    local client_status=0
    
    ((test_count++))
    echo -e "${C_BLUE}${C_BOLD}[TEST $test_count]${C_RESET} - ${description}"
    > "$SERVER_LOG"

    # Lance le client en arrière-plan pour pouvoir le surveiller
    ./$CLIENT_EXEC $SERVER_PID "$test_string" &
    CLIENT_PID=$!

    # Lance un "gardien" qui tuera le client s'il ne se termine pas à temps
    # C'est le test clé pour l'ACK : le serveur doit répondre avant le timeout.
    (sleep $CLIENT_TIMEOUT && kill $CLIENT_PID 2>/dev/null && echo -e "   -> ${C_RED}${C_BOLD}TIMEOUT ⏰${C_RESET}") &
    WATCHER_PID=$!

    # Attend la fin du client
    wait $CLIENT_PID 2>/dev/null
    client_status=$?

    # "Désarmer" le gardien (s'il n'a pas déjà agi)
    kill $WATCHER_PID 2>/dev/null
    wait $WATCHER_PID 2>/dev/null

    # --- Vérification des résultats ---
    # 1. Le client a-t-il été tué par le timeout ?
    if [ $client_status -ne 0 ]; then
        echo -e "   -> ${C_RED}${C_BOLD}ÉCHEC : Le client a été terminé (timeout de $CLIENT_TIMEOUT s dépassé). Soit le client attend un ACK que le serveur n'envoie pas, soit le serveur est trop lent.${C_RESET}"
        ((tests_failed++))
    else
        # 2. Si le client s'est bien terminé, le message est-il correct ?
        sleep 0.1 # Petite marge pour que le dernier caractère s'imprime dans le log
        local server_output=$(cat "$SERVER_LOG" | tr -d '\n')
        local expected_string=$(echo -n "$test_string" | tr -d '\n')

        if [[ "$server_output" == "$expected_string" ]]; then
            echo -e "   -> ${C_GREEN}${C_BOLD}SUCCÈS ✅ (Client terminé à temps et message correct)${C_RESET}"
            ((tests_passed++))
        else
            echo -e "   -> ${C_RED}${C_BOLD}ÉCHEC ❌ (Client terminé, mais message incorrect)${C_RESET}"
            echo -e "      ${C_YELLOW}Attendu :${C_RESET} '$expected_string'"
            echo -e "      ${C_YELLOW}Reçu    :${C_RESET} '$server_output'"
            ((tests_failed++))
        fi
    fi
    echo
}

# --- Séquence de test principale ---

print_header

if [ ! -f "$SERVER_EXEC" ] || [ ! -x "$SERVER_EXEC" ]; then
    echo -e "${C_RED}❌ ERREUR: Serveur '$SERVER_EXEC' introuvable ou non exécutable.${C_RESET}"; exit 1
fi
if [ ! -f "$CLIENT_EXEC" ] || [ ! -x "$CLIENT_EXEC" ]; then
    echo -e "${C_RED}❌ ERREUR: Client '$CLIENT_EXEC' introuvable ou non exécutable.${C_RESET}"; exit 1
fi

start_server

# --- Suite de tests ---
run_test "Chaîne ASCII simple" "Hello Minitalk, with ACK test!"
run_test "Chaîne vide" ""
run_test "Chaîne avec caractères spéciaux" "\"\$'\t*&^%#@![]{}()\\"
long_string=$(head -c 2000 /dev/urandom | base64 | tr -d '\n' | head -c 2000)
run_test "Longue chaîne (2000 caractères)" "$long_string"
run_test "Chaîne avec caractères Unicode (UTF-8)" "👋 Hey, ça va ? 測試 ✅ 絵文字"

kill_server

# --- Résumé ---
echo -e "${C_CYAN}${C_BOLD}========== Résumé des Tests ==========${C_RESET}"
echo -e "Total: ${C_BOLD}$test_count${C_RESET} | ${C_GREEN}Succès: ${C_BOLD}$tests_passed${C_RESET} | ${C_RED}Échecs: ${C_BOLD}$tests_failed${C_RESET}"
echo -e "${C_CYAN}${C_BOLD}=====================================${C_RESET}"

if [ $tests_failed -eq 0 ]; then
    echo -e "\n${C_GREEN}${C_BOLD}🎉 Excellent travail ! Le projet semble robuste et gère correctement l'ACK ! 🎉${C_RESET}"
    exit 0
else
    echo -e "\n${C_RED}${C_BOLD}🔥 Il y a des erreurs. Vérifie la gestion des signaux, l'envoi de l'ACK par le serveur ou les timeouts. 🔥${C_RESET}"
    exit 1
fi
