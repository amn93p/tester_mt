#!/bin/bash
set +H  # Désactive l'expansion de l'historique pour éviter les bugs avec !

# ╔════════════════════════════════════════════════════════════════════╗
# ║                      Testeur Minitalk Interactif                  ║
# ║              Parfait pour le sujet 42 + bonus Unicode & ACK       ║
# ╚════════════════════════════════════════════════════════════════════╝

# --- ASCII Art ---
echo -e "
\033[1;34m
  _______ __  __ _______ 
 |__   __|  \/  |__   __|
    | |  | \  / |  | |   
    | |  | |\/| |  | |   
    | |  | |  | |  | |   
    |_|  |_|  |_|  |_|   
\033[0m"

# --- Configuration ---
SERVER="./server"
CLIENT="./client"
SERVER_LOG="server_output.txt"

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
    kill $SERVER_PID 2>/dev/null
    rm -f "$SERVER_LOG"
}
trap cleanup EXIT

start_server() {
    echo -e "$INFO Lancement du serveur..."
    $SERVER > "$SERVER_LOG" 2>&1 &
    SERVER_PID=$!
    sleep 0.5
    local detected_pid=$(grep -o '[0-9]\+' "$SERVER_LOG" | head -n1)

    if [[ -z "$detected_pid" ]]; then
        echo -e "$FAIL PID non détecté. Log :"
        cat "$SERVER_LOG"
        exit 1
    fi

    SERVER_PID=$detected_pid
    echo -e "$SUCCESS Serveur prêt. PID : ${C_BOLD}$SERVER_PID${C_RESET}"
}

run_test() {
    local title="$1"
    local message="$2"

    echo -e "\n--- $title ---"
    > "$SERVER_LOG"

    ./$CLIENT "$SERVER_PID" "$message"
    sleep 1
    local received=$(cat "$SERVER_LOG" | tr -d '\0')

    echo -e "📤 ${C_YELLOW}Envoyé   :${C_RESET} '$message'"
    echo -e "📥 ${C_YELLOW}Reçu     :${C_RESET} '$received'"

    if [[ "$received" == *"$message"* ]]; then
        echo -e "$SUCCESS Le message a été correctement reçu."
        ((tests_passed++))
    else
        echo -e "$FAIL Message incorrect ou incomplet."
        ((tests_failed++))
    fi
}

run_multi_client_test() {
    echo -e "\n--- Test: Clients multiples ---"
    > "$SERVER_LOG"
    ./$CLIENT "$SERVER_PID" "A" &
    ./$CLIENT "$SERVER_PID" "B" &
    ./$CLIENT "$SERVER_PID" "C" &
    wait
    sleep 0.5
    local output=$(cat "$SERVER_LOG" | tr -d '\0')

    if [[ "$output" == *"A"* && "$output" == *"B"* && "$output" == *"C"* ]]; then
        echo -e "$SUCCESS Tous les messages ont été reçus."
        ((tests_passed++))
    else
        echo -e "$FAIL Messages manquants dans la sortie."
        echo -e "       ${C_YELLOW}Reçu :${C_RESET} '$output'"
        ((tests_failed++))
    fi
}

show_menu() {
    echo -e "${C_BOLD}Sélectionne les tests à lancer :${C_RESET}"
    echo " 1 - Message simple"
    echo " 2 - Chaîne vide"
    echo " 3 - Emoji / Unicode"
    echo " 4 - Long message"
    echo " 5 - Clients multiples"
    echo " 0 - Tous les tests"
    echo " q - Quitter"
    echo -n "> "
    read -r choice
    case "$choice" in
        1) tests=(1) ;;
        2) tests=(2) ;;
        3) tests=(3) ;;
        4) tests=(4) ;;
        5) tests=(5) ;;
        0) tests=(1 2 3 4 5) ;;
        q|Q) echo "Annulé."; exit 0 ;;
        *) echo "Choix invalide."; show_menu ;;
    esac
}

# === MAIN ===
if [ ! -x "$SERVER" ] || [ ! -x "$CLIENT" ]; then
    echo -e "$FAIL Serveur ou client introuvable/non exécutable."
    exit 1
fi

show_menu
start_server

for test in "${tests[@]}"; do
    case $test in
        1) run_test "Message simple" "Hello42!" ;;
        2) run_test "Chaîne vide" "" ;;
        3) run_test "Emoji / UTF-8" "🐍😎🔥 çøøl" ;;
        4) msg=$(head -c 4000 /dev/urandom | base64 | head -c 4000); run_test "Message long (4k)" "$msg" ;;
        5) run_multi_client_test ;;
    esac
done

# Résumé
echo -e "\n${C_BOLD}RÉSULTAT FINAL${C_RESET}"
echo -e "✅ Réussis : ${C_GREEN}$tests_passed${C_RESET}"
echo -e "❌ Échoués : ${C_RED}$tests_failed${C_RESET}"

if [ "$tests_failed" -eq 0 ]; then
    echo -e "\n${C_GREEN}🎉 Tout est bon, Minitalk est conforme !${C_RESET}"
else
    echo -e "\n${C_RED}⚠️  Des erreurs sont présentes. Vérifie les logs ci-dessus.${C_RESET}"
fi
