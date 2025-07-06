#!/bin/bash
set +H # Désactive l'expansion de l'historique (!)

# ╔════════════════════════════════════════════════════════════════════╗
# ║           Testeur Minitalk Interactif (Amélioré)                   ║
# ║     Parfait pour le sujet 42 + bonus Unicode & ACK               ║
# ╚════════════════════════════════════════════════════════════════════╝

# === Configuration ===
SERVER="./server"
CLIENT="./client"
SERVER_LOG="server_output.log" # Renommé en .log par convention
CLIENT_TIMEOUT=10 # Temps max en secondes pour qu'un client termine (sécurité)

# --- Couleurs & Styles ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_BOLD='\033[1m'

# --- Préfixes de message ---
SUCCESS="${C_GREEN}${C_BOLD}[SUCCÈS]${C_RESET}"
FAIL="${C_RED}${C_BOLD}[ÉCHEC]${C_RESET}"
INFO="${C_BLUE}${C_BOLD}[INFO]${C_RESET}"

# --- Compteurs ---
tests_passed=0
tests_failed=0
SERVER_PID="" # Initialisation à vide est cruciale

# ==================== Fonctions Principales ====================

# === Dégradé propre : couleur entière par ligne (INCHANGÉ) ===
gradient_line() {
    local text="$1"
    local r=$((RANDOM % 156 + 100))
    local g=$((RANDOM % 156 + 100))
    local b=$((RANDOM % 156 + 100))
    echo -e "\033[38;2;${r};${g};${b}m${text}\033[0m"
}

# === ASCII art stylisé pour le titre du testeur (INCHANGÉ) ===
fancy_title() {
    echo
    gradient_line "  _______ __  __ _______ "
    gradient_line " |__   __|  \/  |__   __|"
    gradient_line "    | |  | \  / |  | |   "
    gradient_line "    | |  | |\/| |  | |   "
    gradient_line "    | |  | |  | |  | |   "
    gradient_line "    |_|  |_|  |_|  |_|   "
    echo
}

# === Nettoyage (CORRIGÉ) ===
cleanup() {
    echo -e "\n$INFO Nettoyage..."
    # On ne tente de tuer le processus QUE si la variable SERVER_PID n'est pas vide
    if [[ -n "$SERVER_PID" ]] && ps -p "$SERVER_PID" > /dev/null; then
       kill "$SERVER_PID" 2>/dev/null # Ajout de 2>/dev/null pour ignorer l'erreur si le proc est déjà mort
    fi
    rm -f "$SERVER_LOG"
}
trap cleanup EXIT

# === Démarrage du serveur (Amélioré) ===
start_server() {
    echo -e "$INFO Lancement du serveur..."
    if [ ! -f "$SERVER" ] || [ ! -x "$SERVER" ]; then
        echo -e "$FAIL L'exécutable du serveur '$SERVER' est introuvable."
        exit 1
    fi
    # On vide le log au cas où il resterait d'une session précédente
    >"$SERVER_LOG"
    $SERVER > "$SERVER_LOG" 2>&1 &
    SERVER_PID=$!
    sleep 0.5

    # Tente de récupérer le PID affiché par le serveur lui-même
    local detected_pid=$(grep -o '[0-9]\+' "$SERVER_LOG" | head -n1)
    if [[ -z "$detected_pid" ]]; then
        echo -e "$FAIL PID du serveur non détecté dans $SERVER_LOG. Le serveur a-t-il pu démarrer ?"
        echo -e "$INFO Contenu du log du serveur :"
        cat "$SERVER_LOG"
        exit 1
    fi
    SERVER_PID=$detected_pid
    echo -e "$SUCCESS Serveur prêt. PID : ${C_BOLD}$SERVER_PID${C_RESET}"
}

# === Moteur de test (AMÉLIORÉ avec timeout et diff) ===
run_test() {
    local title="$1"
    local message_sent="$2"
    echo -e "\n--- $title ---"
    >"$SERVER_LOG"

    if [ ! -f "$CLIENT" ] || [ ! -x "$CLIENT" ]; then
        echo -e "$FAIL L'exécutable du client '$CLIENT' est introuvable."
        ((tests_failed++))
        return
    fi

    # Exécution du client avec un timeout pour éviter les blocages infinis
    timeout "$CLIENT_TIMEOUT" ./"$CLIENT" "$SERVER_PID" "$message_sent"
    local client_exit_code=$?

    if [ $client_exit_code -eq 124 ]; then
        echo -e "$FAIL Le client a dépassé le temps imparti de ${CLIENT_TIMEOUT}s. Le serveur est-il bloqué ?"
        ((tests_failed++))
        return
    elif [ $client_exit_code -ne 0 ]; then
        echo -e "$FAIL Le client a retourné une erreur (code: $client_exit_code)."
        ((tests_failed++))
        return
    fi

    # Laisser une marge au serveur pour finir d'écrire dans son log
    sleep 0.2

    local message_received=$(tr -d '\0' < "$SERVER_LOG")

    echo -e "📤 ${C_YELLOW}Envoyé  :${C_RESET} '$message_sent'"
    echo -e "📥 ${C_YELLOW}Reçu    :${C_RESET} '$message_received'"

    if [[ "$message_received" == "$message_sent" ]]; then
        echo -e "$SUCCESS Le message a été correctement reçu."
        ((tests_passed++))
    else
        echo -e "$FAIL Message reçu incorrect ou incomplet."
        # Affichage du diff pour un débogage facile
        echo -e "${C_BOLD}--- DIFFÉRENCE ---${C_RESET}"
        diff --color=always <(echo -n "$message_sent") <(echo -n "$message_received")
        echo "--------------------"
        ((tests_failed++))
    fi
}

# === Test Multi-Clients (CORRIGÉ) ===
run_multi_client_test() {
    echo -e "\n--- Test: Clients multiples (en série) ---"
    >"$SERVER_LOG"

    local msg1="Premier message."
    local msg2="Deuxième test."
    local msg3="Troisième envoi."
    local expected_output="${msg1}${msg2}${msg3}"

    echo -e "$INFO Envoi de 3 messages à la suite..."
    timeout "$CLIENT_TIMEOUT" ./"$CLIENT" "$SERVER_PID" "$msg1"
    timeout "$CLIENT_TIMEOUT" ./"$CLIENT" "$SERVER_PID" "$msg2"
    timeout "$CLIENT_TIMEOUT" ./"$CLIENT" "$SERVER_PID" "$msg3"
    
    sleep 0.5 # Attendre que le serveur traite tout

    local received_output=$(tr -d '\0' < "$SERVER_LOG")
    echo -e "📤 ${C_YELLOW}Attendu :${C_RESET} '$expected_output'"
    echo -e "📥 ${C_YELLOW}Reçu    :${C_RESET} '$received_output'"

    if [[ "$received_output" == "$expected_output" ]]; then
        echo -e "$SUCCESS Tous les messages des clients ont été reçus dans le bon ordre."
        ((tests_passed++))
    else
        echo -e "$FAIL Un ou plusieurs messages sont manquants ou corrompus."
        echo -e "${C_BOLD}--- DIFFÉRENCE ---${C_RESET}"
        diff --color=always <(echo -n "$expected_output") <(echo -n "$received_output")
        echo "--------------------"
        ((tests_failed++))
    fi
}

# === Menu (INCHANGÉ) ===
show_menu() {
    echo -e "${C_BOLD}Sélectionne les tests à lancer :${C_RESET}"
    echo " 1 - Message simple"
    echo " 2 - Chaîne vide"
    echo " 3 - Emoji / Unicode"
    echo " 4 - Long message (1000)"
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

# ==================== Exécution Principale ====================
fancy_title
show_menu
start_server

for test in "${tests[@]}"; do
    case $test in
        1) run_test "Message simple" "Hello 42!" ;;
        2) run_test "Chaîne vide" "" ;;
        3) run_test "Emoji / UTF-8" "🐍😎🔥 çøøl 漢字" ;;
        4) 
            msg=$(head -c 1000 /dev/urandom | base64 | tr -d '\n' | head -c 1000)
            run_test "Message long et complexe (1000)" "$msg"
            ;;
        5) run_multi_client_test ;;
    esac
done

# === Résumé Final (INCHANGÉ) ===
echo -e "\n${C_BOLD}RÉSULTAT FINAL${C_RESET}"
echo -e "✅ Réussis : ${C_GREEN}$tests_passed${C_RESET}"
echo -e "❌ Échoués : ${C_RED}$tests_failed${C_RESET}"

if [ "$tests_failed" -eq 0 ]; then
    echo -e "\n${C_GREEN}🎉 Tout est bon, Minitalk est conforme !${C_RESET}"
else
    echo -e "\n${C_RED}⚠️  Des erreurs sont présentes. Consulte les logs ci-dessus.${C_RESET}"
fi
