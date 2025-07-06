#!/bin/bash

# ╔═════════════════════════════════════════════════════════════════════════╗
# ║                  Minitalk Tester — Mode Interactif + ASCII             ║
# ║          Robuste, compatible bonus, avec sélection des tests           ║
# ╚═════════════════════════════════════════════════════════════════════════╝

# ASCII art
echo -e "
${C_BOLD}${C_BLUE}
_________ _______ _________
\\__   __/(       )\\__   __/
   ) (   | () () |   ) (   
   | |   | || || |   | |   
   | |   | |(_)| |   | |   
   | |   | |   | |   | |   
   | |   | )   ( |   | |   
   )_(   |/     \\|   )_(   
                          
${C_RESET}
"

# --- Configuration ---
SERVER="./server"
CLIENT="./client"
SERVER_LOG="server.log"

C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_BOLD='\033[1m'

SUCCESS="${C_GREEN}${C_BOLD}[SUCCÈS]${C_RESET}"
FAIL="${C_RED}${C_BOLD}[ÉCHEC]${C_RESET}"
INFO="${C_BLUE}${C_BOLD}[INFO]${C_RESET}"

tests_passed=0
tests_failed=0

cleanup() {
    echo -e "\n$INFO Nettoyage..."
    [ -n "$SERVER_PID" ] && kill -j $SERVER_PID 2>/dev/null
    kill $SERVER_PID 2>/dev/null
    rm -f "$SERVER_LOG"
}
trap cleanup EXIT

start_server() {
    echo -e "$INFO Démarrage du serveur..."
    ./$SERVER > "$SERVER_LOG" 2>&1 &
    SERVER_PID=$!
    sleep 0.5
    local displayed_pid=$(grep -o -m 1 '[0-9]\+' "$SERVER_LOG")
    if [[ -n "$displayed_pid" ]]; then
        echo -e "$SUCCESS Serveur démarré. PID détecté : ${C_BOLD}$displayed_pid${C_RESET}"
        SERVER_PID=$displayed_pid
        sed -i '1d' "$SERVER_LOG"
    else
        echo -e "$FAIL PID non détecté. Contenu du log :"
        cat "$SERVER_LOG"
        exit 1
    fi
}

run_test() {
    local title="$1"
    local string="$2"

    echo -e "\n--- $title ---"
    > "$SERVER_LOG"
    local timeout=$(echo "2 + ${#string} * 0.005" | bc)
    ./$CLIENT $SERVER_PID "$string" &
    local client_pid=$!
    (sleep $timeout && kill $client_pid 2>/dev/null) &
    local watchdog=$!
    wait $client_pid 2>/dev/null
    local status=$?
    kill $watchdog 2>/dev/null

    sleep 0.1
    local output=$(tr -d '\0' < "$SERVER_LOG")
    if [ $status -ne 0 ]; then
        echo -e "$FAIL Client bloqué ou timeout après $timeout s."
        ((tests_failed++))
    elif [[ "$output" == *"$string"* ]]; then
        echo -e "$SUCCESS Message reçu correctement."
        ((tests_passed++))
    else
        echo -e "$FAIL Message incorrect."
        echo -e "       ${C_YELLOW}Attendu :${C_RESET} '$string'"
        echo -e "       ${C_YELLOW}Reçu    :${C_RESET} '$output'"
        ((tests_failed++))
    fi
}

run_multi_client_test() {
    echo -e "\n--- Test 5: Clients multiples simultanés ---"
    > "$SERVER_LOG"
    ./$CLIENT $SERVER_PID "One" &
    ./$CLIENT $SERVER_PID "Two" &
    ./$CLIENT $SERVER_PID "Three" &
    wait
    sleep 0.5
    local output=$(tr -d '\0' < "$SERVER_LOG")
    if [[ "$output" == *"One"* && "$output" == *"Two"* && "$output" == *"Three"* ]]; then
        echo -e "$SUCCESS Tous les messages reçus."
        ((tests_passed++))
    else
        echo -e "$FAIL Messages manquants."
        echo -e "       ${C_YELLOW}Reçu:${C_RESET} $output"
        ((tests_failed++))
    fi
}

# === MENU DE SÉLECTION DES TESTS ===

tests_to_run=()

function show_menu() {
    echo -e "${C_BOLD}Sélectionne les tests à exécuter :${C_RESET}"
    echo " 1 - Message simple"
    echo " 2 - Chaîne vide"
    echo " 3 - Unicode (emoji + UTF-8)"
    echo " 4 - Chaîne très longue (4k)"
    echo " 5 - Clients multiples"
    echo " 0 - Tous les tests"
    echo " q - Quitter"
    echo -n "> "
    read -r choice

    case "$choice" in
        1) tests_to_run+=(1) ;;
        2) tests_to_run+=(2) ;;
        3) tests_to_run+=(3) ;;
        4) tests_to_run+=(4) ;;
        5) tests_to_run+=(5) ;;
        0) tests_to_run=(1 2 3 4 5) ;;
        q|Q) echo "Annulé."; exit 0 ;;
        *) echo "Option inconnue." ; show_menu ;;
    esac
}

# === Lancement ===

if [ ! -x "$SERVER" ] || [ ! -x "$CLIENT" ]; then
    echo -e "$FAIL Exécutable '$SERVER' ou '$CLIENT' introuvable."
    exit 1
fi

show_menu
start_server

for test_id in "${tests_to_run[@]}"; do
    case $test_id in
        1) run_test "Test 1: Message simple" "Hello World!" ;;
        2) run_test "Test 2: Chaîne vide" "" ;;
        3) run_test "Test 3: Unicode (UTF-8 + emoji)" "👋 π Vøici çàractèrës 测验 ✅" ;;
        4) 
            long_msg=$(head -c 4000 /dev/urandom | base64 | tr -d '[:space:]' | head -c 4000)
            run_test "Test 4: Chaîne longue (4k)" "$long_msg"
            ;;
        5) run_multi_client_test ;;
    esac
done

# === Résumé ===
echo -e "\n==================== ${C_BOLD}RÉSUMÉ${C_RESET} ===================="
echo -e "Tests réussis : ${C_GREEN}$tests_passed${C_RESET}"
echo -e "Tests échoués : ${C_RED}$tests_failed${C_RESET}"
echo "================================================"

if [ $tests_failed -eq 0 ]; then
    echo -e "\n${C_GREEN}🎉 Bravo ! Tous les tests sont passés avec succès.${C_RESET}"
else
    echo -e "\n${C_RED}⚠️ Certains tests ont échoué. Consulte les logs.${C_RESET}"
fi
