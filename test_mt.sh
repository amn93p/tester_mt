#!/bin/bash
set +H # Désactive l'expansion de l'historique (!)

# ╔════════════════════════════════════════════════════════════════════╗
# ║           Testeur Minitalk Interactif (Amélioré)                   ║
# ║     Parfait pour le sujet 42 + bonus Unicode & ACK               ║
# ╚════════════════════════════════════════════════════════════════════╝

# === Configuration ===
SERVER="./server"
CLIENT="./client"
SERVER_LOG="server_output.log"
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
WARN="${C_YELLOW}${C_BOLD}[ATTENTION]${C_RESET}"

# === Paramètres configurables (NOUVEAU) ===
CLEAN_ON_EXIT=true
AUTO_COMPILE=true
SHOW_DIFF_ON_FAIL=true

# --- Compteurs ---
tests_passed=0
tests_failed=0
SERVER_PID="" # Initialisation à vide est cruciale

# ==================== Fonctions Principales ====================

# === Dégradé propre : couleur entière par ligne ===
gradient_line() {
    local text="$1"
    local r=$((RANDOM % 156 + 100))
    local g=$((RANDOM % 156 + 100))
    local b=$((RANDOM % 156 + 100))
    echo -e "\033[38;2;${r};${g};${b}m${text}\033[0m"
}

# === ASCII art stylisé pour le titre du testeur ===
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

# === Compilation du projet ===
compile_project() {
    echo -e "$INFO Vérification des fichiers sources et du Makefile..."
    if [ ! -f "server.c" ] || [ ! -f "client.c" ]; then
        echo -e "$FAIL 'server.c' ou 'client.c' est introuvable."
        echo -e "$INFO Assurez-vous que le testeur est dans le bon répertoire."
        exit 1
    fi
    if [ ! -f "Makefile" ] && [ ! -f "makefile" ]; then
        echo -e "$FAIL Aucun Makefile trouvé. Impossible de compiler le projet."
        exit 1
    fi
    echo -e "$SUCCESS Fichiers sources et Makefile trouvés."

    echo -e "$INFO Lancement de la compilation si nécessaire..."
    local make_output
    make_output=$(make 2>&1)
    local make_exit_code=$?

    if [ $make_exit_code -ne 0 ]; then
        echo -e "$FAIL La compilation a échoué. Veuillez corriger les erreurs."
        echo -e "--- Sortie de Make ---"
        echo "$make_output"
        echo "----------------------"
        exit 1
    fi

    if [[ "$make_output" == *"Nothing to be done"* ]]; then
        echo -e "$INFO Le projet est déjà à jour."
    else
        echo -e "$SUCCESS Compilation terminée."
    fi
}

# === Nettoyage (respecte maintenant les paramètres) ===
cleanup() {
    echo -e "\n$INFO Nettoyage..."
    if [[ -n "$SERVER_PID" ]] && ps -p "$SERVER_PID" > /dev/null; then
       kill "$SERVER_PID" 2>/dev/null
    fi
    rm -f "$SERVER_LOG"

    if [ "$CLEAN_ON_EXIT" = true ]; then
        if [ -f "Makefile" ] || [ -f "makefile" ]; then
            echo -e "$INFO Exécution de 'make fclean' pour nettoyer le projet..."
            make fclean > /dev/null 2>&1
        fi
    fi
}

# === Fonction de désinstallation ===
uninstall() {
    echo -e "$WARN Cette action va nettoyer le projet (make fclean) et ${C_BOLD}supprimer ce script (${0})${C_RESET}."
    read -p "Êtes-vous sûr de vouloir continuer? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "$INFO Nettoyage du projet via 'make fclean'..."
        if [ -f "Makefile" ] || [ -f "makefile" ]; then
            make fclean
            echo -e "$SUCCESS Projet nettoyé."
        else
            echo -e "$FAIL Aucun Makefile trouvé. Impossible de nettoyer le projet."
        fi
        
        echo -e "$INFO Auto-destruction du script..."
        if rm -- "$0"; then
            echo -e "$SUCCESS Script '$0' supprimé."
            trap - EXIT
            exit 0
        else
            echo -e "$FAIL Impossible de supprimer le script '$0'."
            exit 1
        fi
    else
        echo -e "$INFO Désinstallation annulée."
        exit 0
    fi
}

# === Affichage d'un paramètre (NOUVEAU) ===
print_setting_status() {
    if [ "$1" = true ]; then
        echo -e "${C_GREEN}Activé${C_RESET}"
    else
        echo -e "${C_RED}Désactivé${C_RESET}"
    fi
}

# === Menu des paramètres (NOUVEAU) ===
show_settings_menu() {
    while true; do
        clear
        fancy_title
        echo -e "${C_BOLD}--- Paramètres ---${C_RESET}"
        echo " 1. Nettoyer le projet en quittant (`fclean`) : $(print_setting_status $CLEAN_ON_EXIT)"
        echo " 2. Compiler automatiquement au lancement      : $(print_setting_status $AUTO_COMPILE)"
        echo " 3. Afficher le 'diff' en cas d'échec        : $(print_setting_status $SHOW_DIFF_ON_FAIL)"
        echo ""
        echo " r - Retour au menu principal"
        echo -n "> "
        read -r choice
        case "$choice" in
            1) CLEAN_ON_EXIT=$(! $CLEAN_ON_EXIT) ;;
            2) AUTO_COMPILE=$(! $AUTO_COMPILE) ;;
            3) SHOW_DIFF_ON_FAIL=$(! $SHOW_DIFF_ON_FAIL) ;;
            r|R) break ;;
            *) echo "Choix invalide." && sleep 1 ;;
        esac
    done
}

# === Menu principal (mis à jour) ===
show_menu() {
    while true; do
        clear
        fancy_title
        echo -e "${C_BOLD}Sélectionne les tests à lancer :${C_RESET}"
        echo " 1 - Message simple"
        echo " 2 - Chaîne vide"
        echo " 3 - Emoji / Unicode"
        echo " 4 - Long message (1000)"
        echo " 5 - Clients multiples"
        echo " 0 - Tous les tests"
        echo " s - Paramètres"
        echo " q - Quitter"
        echo -n "> "
        read -r choice
        case "$choice" in
            1) tests=(1); break ;;
            2) tests=(2); break ;;
            3) tests=(3); break ;;
            4) tests=(4); break ;;
            5) tests=(5); break ;;
            0) tests=(1 2 3 4 5); break ;;
            s|S) show_settings_menu ;;
            q|Q) echo "Annulé."; exit 0 ;;
            *) echo "Choix invalide." && sleep 1 ;;
        esac
    done
}

# === Démarrage du serveur ===
start_server() {
    echo -e "$INFO Lancement du serveur..."
    if [ ! -f "$SERVER" ] || [ ! -x "$SERVER" ]; then
        echo -e "$FAIL L'exécutable du serveur '$SERVER' est introuvable. Problème de compilation ?"
        exit 1
    fi
    >"$SERVER_LOG"
    $SERVER > "$SERVER_LOG" 2>&1 &
    SERVER_PID=$!
    sleep 0.5

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

# === Moteur de test (respecte maintenant les paramètres) ===
run_test() {
    local title="$1"
    local message_sent="$2"
    echo -e "\n--- $title ---"
    >"$SERVER_LOG"

    if [ ! -f "$CLIENT" ] || [ ! -x "$CLIENT" ]; then
        echo -e "$FAIL L'exécutable du client '$CLIENT' est introuvable. Problème de compilation ?"
        ((tests_failed++))
        return
    fi

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

    sleep 0.2
    local message_received=$(tr -d '\0' < "$SERVER_LOG")
    echo -e "📤 ${C_YELLOW}Envoyé  :${C_RESET} '$message_sent'"
    echo -e "📥 ${C_YELLOW}Reçu    :${C_RESET} '$message_received'"

    if [[ "$message_received" == "$message_sent" ]]; then
        echo -e "$SUCCESS Le message a été correctement reçu."
        ((tests_passed++))
    else
        echo -e "$FAIL Message reçu incorrect ou incomplet."
        if [ "$SHOW_DIFF_ON_FAIL" = true ]; then
            echo -e "${C_BOLD}--- DIFFÉRENCE ---${C_RESET}"
            diff --color=always <(echo -n "$message_sent") <(echo -n "$message_received")
            echo "--------------------"
        fi
        ((tests_failed++))
    fi
}

# === Test Multi-Clients (respecte maintenant les paramètres) ===
run_multi_client_test() {
    echo -e "\n--- Test: Clients multiples (en série) ---"
    >"$SERVER_LOG"

    local msg1="Premier message."
    local msg2="Deuxième test."
    local msg3="Troisième envoi."
    local expected_output
    expected_output=$(printf "%s\n%s\n%s" "$msg1" "$msg2" "$msg3")

    echo -e "$INFO Envoi de 3 messages à la suite, avec une pause entre chaque..."
    timeout "$CLIENT_TIMEOUT" ./"$CLIENT" "$SERVER_PID" "$msg1" || { echo -e "$FAIL Le client 1 a échoué."; ((tests_failed++)); return; }
    sleep 0.2
    timeout "$CLIENT_TIMEOUT" ./"$CLIENT" "$SERVER_PID" "$msg2" || { echo -e "$FAIL Le client 2 a échoué."; ((tests_failed++)); return; }
    sleep 0.2
    timeout "$CLIENT_TIMEOUT" ./"$CLIENT" "$SERVER_PID" "$msg3" || { echo -e "$FAIL Le client 3 a échoué."; ((tests_failed++)); return; }
    sleep 0.5

    local received_output=$(tr -d '\0' < "$SERVER_LOG")
    echo -e "📤 ${C_YELLOW}Attendu :${C_RESET} '$(echo "$expected_output" | sed 's/$/↵/' | tr -d '\n')'"
    echo -e "📥 ${C_YELLOW}Reçu    :${C_RESET} '$(echo "$received_output" | sed 's/$/↵/' | tr -d '\n')'"

    if [[ "$received_output" == "$expected_output" ]]; then
        echo -e "$SUCCESS Tous les messages des clients ont été reçus dans le bon ordre."
        ((tests_passed++))
    else
        echo -e "$FAIL Un ou plusieurs messages sont manquants ou corrompus."
        if [ "$SHOW_DIFF_ON_FAIL" = true ]; then
            echo -e "${C_BOLD}--- DIFFÉRENCE ---${C_RESET}"
            diff --color=always <(echo -n "$expected_output") <(echo -n "$received_output")
            echo "--------------------"
        fi
        ((tests_failed++))
    fi
}

# ==================== Exécution Principale ====================

if [ "$1" == "uninstall" ]; then
    uninstall
fi

trap cleanup EXIT

if [ "$AUTO_COMPILE" = true ]; then
    compile_project
else
    # On affiche le titre seulement si on ne compile pas, sinon il s'affiche déjà
    fancy_title
    echo -e "$INFO Compilation automatique désactivée. Assurez-vous que le projet est compilé."
fi

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

# === Résumé Final ===
echo -e "\n${C_BOLD}RÉSULTAT FINAL${C_RESET}"
echo -e "✅ Réussis : ${C_GREEN}$tests_passed${C_RESET}"
echo -e "❌ Échoués : ${C_RED}$tests_failed${C_RESET}"

if [ "$tests_failed" -eq 0 ]; then
    echo -e "\n${C_GREEN}🎉 Tout est bon, Minitalk est conforme !${C_RESET}"
else
    echo -e "\n${C_RED}⚠️  Des erreurs sont présentes. Consulte les logs ci-dessus.${C_RESET}"
fi
