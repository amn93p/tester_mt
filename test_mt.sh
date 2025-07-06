#!/bin/bash
set +H # Désactive l'expansion de l'historique via '!'

# ╔══════════════════════════════════════════════════════════════════════╗
# ║             Testeur Minitalk Interactif (v4 - Compact)               ║
# ║          Parfait pour le sujet 42 + bonus Unicode & ACK              ║
# ║  Améliorations : Mode compact pour "Tous les tests", serveur unique  ║
# ╚══════════════════════════════════════════════════════════════════════╝

# === Configuration ===
SERVER="./server"
CLIENT="./client"
SERVER_LOG="server_output.log"
CLIENT_TIMEOUT=15 # Timeout généreux pour ne pas pénaliser les implémentations lentes

# Détermine le répertoire du script pour y stocker les paramètres
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SETTINGS_FILE="$SCRIPT_DIR/.tester_settings" # Fichier pour sauvegarder les paramètres

# --- Couleurs & Styles ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'
C_DIM='\033[2m'

# --- Préfixes de message ---
SUCCESS="${C_GREEN}${C_BOLD}[✓ SUCCÈS]${C_RESET}"
FAIL="${C_RED}${C_BOLD}[✗ ÉCHEC]${C_RESET}"
INFO="${C_BLUE}${C_BOLD}[i INFO]${C_RESET}"
WARN="${C_YELLOW}${C_BOLD}[⚠ ATTENTION]${C_RESET}"
DEBUG_PREFIX="${C_CYAN}${C_BOLD}[⚙ DÉBOGAGE]${C_RESET}"

# === Banque de messages de test ===
SIMPLE_MSGS=(
    "Hello World!"
    "Minitalk est genial"
    "42 est la reponse a tout"
    "Ceci est un message de test."
    "abcdefghijklmnopqrstuvwxyz"
    "0123456789"
    "Les signaux, c'est la vie."
)
UNICODE_MSGS=(
    "你好世界 🌍"
    "Привет, мир 👋"
    "こんにちは世界 🐱"
    "안녕하세요 세계 🇰🇷"
    "नमस्ते दुनिया 🙏"
    "αβγδεζηθικλμνξοπρστυφχψω"
    "Merci Minitalk ! 👍"
    "¿Qué tal, École 42?"
)
MULTI_CLIENT_MSGS=(
    "Message du client A"
    "Le client B dit bonjour"
    "Le client C est la"
    "Premiere partie"
    "Deuxieme partie"
    "Partie finale"
    "Un autre message"
    "Et encore un !"
)

# --- Variables Globales ---
tests_passed=0
tests_failed=0
SERVER_PID="" # Initialisation à vide est cruciale
COMPACT_MODE=false # Flag pour l'affichage des tests

# ==================== Fonctions Principales ====================

save_settings() {
    echo "CLEAN_ON_EXIT=$CLEAN_ON_EXIT" > "$SETTINGS_FILE"
    echo "AUTO_COMPILE=$AUTO_COMPILE" >> "$SETTINGS_FILE"
    echo "SHOW_DIFF_ON_FAIL=$SHOW_DIFF_ON_FAIL" >> "$SETTINGS_FILE"
    echo "DEBUG_MODE=$DEBUG_MODE" >> "$SETTINGS_FILE"
    echo "ACK_MODE=$ACK_MODE" >> "$SETTINGS_FILE"
    echo "LENIENT_MODE=$LENIENT_MODE" >> "$SETTINGS_FILE"
}

load_settings() {
    CLEAN_ON_EXIT=false
    AUTO_COMPILE=true
    SHOW_DIFF_ON_FAIL=true
    DEBUG_MODE=false
    ACK_MODE=false
    LENIENT_MODE=false
    if [ -f "$SETTINGS_FILE" ]; then
        source "$SETTINGS_FILE"
    else
        save_settings
    fi
}

print_separator() {
    printf "${C_DIM}%*s\n${C_RESET}" "$(tput cols)" '' | tr ' ' '─'
}

show_title() {
    echo -e "╔══════════════════════════╗"
    echo -e "║ ${C_YELLOW}      Minitalkette      ${C_RESET} ║"
    echo -e "╚══════════════════════════╝"
}

compile_project() {
    print_separator
    echo -e "$INFO Vérification de la présence d'un Makefile..."
    if [ ! -f "Makefile" ] && [ ! -f "makefile" ]; then
        echo -e "$FAIL Aucun Makefile trouvé. Impossible de compiler."
        exit 1
    fi
    echo -e "$SUCCESS Makefile trouvé."

    echo -e "$INFO Lancement de la compilation via 'make'..."
    local make_output
    make_output=$(make 2>&1)
    local make_exit_code=$?

    if [ $make_exit_code -ne 0 ]; then
        echo -e "$FAIL La compilation a échoué."
        echo -e "${C_DIM}--- Sortie de Make ---${C_RESET}\n$make_output\n${C_DIM}----------------------${C_RESET}"
        exit 1
    fi

    if [[ "$make_output" == *"Nothing to be done"* || "$make_output" == *"est à jour"* ]]; then
        echo -e "$INFO Le projet est déjà à jour."
    else
        echo -e "$SUCCESS Compilation terminée."
    fi
}

cleanup() {
    echo # Newline for cleaner exit
    if [[ -n "$SERVER_PID" ]] && ps -p "$SERVER_PID" > /dev/null; then
        echo -e "$INFO Arrêt du serveur (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null
    fi

    if [ "$CLEAN_ON_EXIT" = true ]; then
        if [ -f "Makefile" ] || [ -f "makefile" ]; then
            echo -e "$INFO Nettoyage du projet (make fclean)..."
            make fclean > /dev/null 2>&1
        fi
    fi
    rm -f "$SERVER_LOG"
    echo -e "$INFO Fichiers temporaires supprimés. Au revoir !"
}

uninstall() {
    clear
    show_title
    echo -e "$WARN Cette action va nettoyer le projet (make fclean) et ${C_BOLD}supprimer ce script (${0})${C_RESET}."
    read -p "Êtes-vous sûr de vouloir continuer? (o/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        echo -e "$INFO Nettoyage du projet via 'make fclean'..."
        make fclean 2>/dev/null
        echo -e "$INFO Suppression du fichier de paramètres et du script..."
        rm -f "$SETTINGS_FILE"
        if rm -- "$0"; then
            echo -e "$SUCCESS Désinstallation terminée."
            trap - EXIT
            exit 0
        fi
    else
        echo -e "$INFO Désinstallation annulée."
    fi
}

print_setting_status() {
    if [ "$1" = true ]; then echo -e "${C_GREEN}Activé${C_RESET}"; else echo -e "${C_RED}Désactivé${C_RESET}"; fi
}

show_settings_menu() {
    while true; do
        clear
        show_title
        echo -e "${C_BOLD}--- Paramètres ---${C_RESET}"
        echo " 1. Nettoyer en quittant ('fclean')          : $(print_setting_status $CLEAN_ON_EXIT)"
        echo " 2. Compiler automatiquement au lancement      : $(print_setting_status $AUTO_COMPILE)"
        echo " 3. Afficher le 'diff' en cas d'échec        : $(print_setting_status $SHOW_DIFF_ON_FAIL)"
        echo " 4. Mode Débogage (voir sortie brute)        : $(print_setting_status $DEBUG_MODE)"
        echo " 5. Mode Accusé de Réception (ACK) [BONUS]   : $(print_setting_status $ACK_MODE)"
        echo " 6. Mode comparaison indulgent [¹]          : $(print_setting_status $LENIENT_MODE)"
        echo -e "\n${C_DIM}[1] Ignore les espaces et sauts de ligne superflus.${C_RESET}\n"
        echo " r - Retour au menu principal"
        echo -n "> "
        read -r choice
        case "$choice" in
            1) CLEAN_ON_EXIT=$(! $CLEAN_ON_EXIT) ;;
            2) AUTO_COMPILE=$(! $AUTO_COMPILE) ;;
            3) SHOW_DIFF_ON_FAIL=$(! $SHOW_DIFF_ON_FAIL) ;;
            4) DEBUG_MODE=$(! $DEBUG_MODE) ;;
            5) ACK_MODE=$(! $ACK_MODE) ;;
            6) LENIENT_MODE=$(! $LENIENT_MODE) ;;
            r|R) break ;;
            *) echo "Choix invalide." && sleep 1 ;;
        esac
        save_settings
    done
}

show_menu() {
    clear
    show_title
    echo -e "${C_BOLD}Sélectionnez les tests à lancer :${C_RESET}"
    echo " 1. Message simple (ASCII)"
    echo " 2. Chaîne vide"
    echo " 3. Bonus: Emoji / Unicode (UTF-8)"
    echo " 4. Long message (1000 caractères)"
    echo " 5. Bonus: Clients multiples"
    print_separator
    echo " a - Lancer TOUS les tests ${C_DIM}(mode compact)${C_RESET}"
    echo " p - Paramètres"
    echo " u - Désinstaller le testeur"
    echo " q - Quitter"
    echo -n "> "
    read -r choice
    case "$choice" in
        a|A) tests=(1 2 3 4 5) ;;
        1) tests=(1) ;;
        2) tests=(2) ;;
        3) tests=(3) ;;
        4) tests=(4) ;;
        5) tests=(5) ;;
        p|P) show_settings_menu; show_menu ;;
        u|U) uninstall; show_menu ;;
        q|Q) cleanup; exit 0 ;;
        *) echo "Choix invalide." && sleep 1 && show_menu ;;
    esac
}

start_server() {
    print_separator
    echo -e "$INFO Lancement du serveur..."
    if [ ! -f "$SERVER" ] || [ ! -x "$SERVER" ]; then
        echo -e "$FAIL Exécutable '$SERVER' introuvable. Activez la compilation auto ou compilez manuellement."
        exit 1
    fi

    $SERVER > "$SERVER_LOG" 2>&1 &
    sleep 0.5

    local pid_line=$(head -n 1 "$SERVER_LOG")
    SERVER_PID=$(echo "$pid_line" | grep -oE '[0-9]+' | head -n 1)

    if [[ -z "$SERVER_PID" ]]; then
        echo -e "$FAIL PID du serveur non détecté !"
        echo -e "$INFO Le serveur doit afficher son PID comme première information."
        echo -e "${C_DIM}--- Log du serveur ($SERVER_LOG) ---${C_RESET}\n$(cat "$SERVER_LOG")"
        exit 1
    fi
    echo -e "$SUCCESS Serveur prêt. ${C_BOLD}PID : $SERVER_PID${C_RESET}"
}

run_test() {
    local title="$1"
    local message_sent="$2"
    local expected_output=$(printf "%s" "$message_sent")

    if [ "$COMPACT_MODE" = true ]; then
        printf "  - %-45s" "$title"
    else
        print_separator
        echo -e "${C_BOLD}LANCEMENT TEST : $title${C_RESET}"
    fi

    >"$SERVER_LOG"

    if [ "$COMPACT_MODE" = false ]; then
        printf "   (i) Message envoyé : [%s]\n" "$message_sent"
    fi

    timeout "$CLIENT_TIMEOUT" "$CLIENT" "$SERVER_PID" "$message_sent" >/dev/null 2>&1
    local client_exit_code=$?

    if [ $client_exit_code -ne 0 ]; then
        if [ "$COMPACT_MODE" = true ]; then
            echo -e "${C_RED}[✗ CLIENT]${C_RESET}"
        else
            local reason="Code d'erreur non nul : $client_exit_code."
            if [ $client_exit_code -eq 124 ]; then
                reason="Timeout (${CLIENT_TIMEOUT}s). Serveur bloqué ou pas d'ACK (bonus) ?"
            fi
            echo -e "$FAIL Échec du client. Raison : $reason"
        fi
        ((tests_failed++))
        return
    fi

    sleep 0.3

    local message_received=$(tr -d '\0' < "$SERVER_LOG")

    if [ "$COMPACT_MODE" = false ]; then
        printf "   (i) Message reçu   : [%s]\n" "$message_received"
        if [ "$DEBUG_MODE" = true ]; then
            echo -e "$DEBUG_PREFIX Contenu brut du log serveur :"
            cat -A "$SERVER_LOG"; echo
        fi
    fi

    local final_check_result=1
    if [ "$LENIENT_MODE" = true ]; then
        if [[ "$(echo -n "$message_received" | tr -s '[:space:]' ' ' | xargs)" == "$(echo -n "$expected_output" | tr -s '[:space:]' ' ' | xargs)" ]]; then
            final_check_result=0
        fi
    elif [[ "$message_received" == "$expected_output" ]]; then
        final_check_result=0
    fi

    if [ $final_check_result -eq 0 ]; then
        if [ "$COMPACT_MODE" = true ]; then echo -e "${C_GREEN} [✓]${C_RESET}"; else echo -e "$SUCCESS Le message a été correctement reçu."; fi
        ((tests_passed++))
    else
        if [ "$COMPACT_MODE" = true ]; then
            echo -e "${C_RED}[✗ MSG]${C_RESET}"
        else
            echo -e "$FAIL Le message reçu ne correspond pas au message envoyé."
            if [ "$SHOW_DIFF_ON_FAIL" = true ]; then
                echo -e "${C_DIM}--- DIFFÉRENCE ---${C_RESET}"
                diff --color=always <(printf "%s" "$expected_output") <(printf "%s" "$message_received")
                echo -e "${C_DIM}------------------${C_RESET}"
            fi
        fi
        ((tests_failed++))
    fi
}

run_multi_client_test() {
    local title="Bonus: Clients multiples"

    if [ "$COMPACT_MODE" = true ]; then
        printf "  - %-45s" "$title"
    else
        print_separator
        echo -e "${C_BOLD}LANCEMENT TEST : $title${C_RESET}"
    fi

    >"$SERVER_LOG"

    local msg1=${MULTI_CLIENT_MSGS[$RANDOM % ${#MULTI_CLIENT_MSGS[@]}]}
    local msg2=${MULTI_CLIENT_MSGS[$RANDOM % ${#MULTI_CLIENT_MSGS[@]}]}
    while [[ "$msg1" == "$msg2" ]]; do
        msg2=${MULTI_CLIENT_MSGS[$RANDOM % ${#MULTI_CLIENT_MSGS[@]}]}
    done

    local expected_output=$(printf "%s\n%s" "$msg1" "$msg2")
    local inter_client_sleep=0.5
    if [ "$ACK_MODE" = true ]; then inter_client_sleep=0.1; fi

    if [ "$COMPACT_MODE" = false ]; then
        echo -e "${C_DIM}Envoi de 2 messages à la suite...${C_RESET}"
        printf "   (i) Message 1 : [%s]\n" "$msg1"
    fi
    timeout "$CLIENT_TIMEOUT" "$CLIENT" "$SERVER_PID" "$msg1" >/dev/null 2>&1 || { if [ "$COMPACT_MODE" = true ]; then echo -e "${C_RED}[✗ CLIENT 1]${C_RESET}"; else echo -e "$FAIL Client 1 KO."; fi; ((tests_failed++)); return; }

    sleep "$inter_client_sleep"

    if [ "$COMPACT_MODE" = false ]; then
        printf "   (i) Message 2 : [%s]\n" "$msg2"
    fi
    timeout "$CLIENT_TIMEOUT" "$CLIENT" "$SERVER_PID" "$msg2" >/dev/null 2>&1 || { if [ "$COMPACT_MODE" = true ]; then echo -e "${C_RED}[✗ CLIENT 2]${C_RESET}"; else echo -e "$FAIL Client 2 KO."; fi; ((tests_failed++)); return; }
    sleep 0.5

    local received_output=$(tr -d '\0' < "$SERVER_LOG")

    if [ "$COMPACT_MODE" = false ]; then
        printf "\n   (i) Attendu total : [%s]\n" "$(echo -n "$expected_output" | sed 's/\n/\\n/g')"
        printf "   (i) Reçu total    : [%s]\n" "$(echo -n "$received_output" | sed 's/\n/\\n/g')"
    fi

    if [[ "$received_output" == "$expected_output" ]]; then
        if [ "$COMPACT_MODE" = true ]; then echo -e "${C_GREEN}[✓]${C_RESET}"; else echo -e "$SUCCESS Les messages ont été reçus correctement et dans le bon ordre."; fi
        ((tests_passed++))
    else
        if [ "$COMPACT_MODE" = true ]; then
            echo -e "${C_RED}[✗ MSG]${C_RESET}"
        else
            echo -e "$FAIL L'enchaînement des messages est incorrect."
            echo -e "$WARN Le serveur doit afficher chaque message sur une nouvelle ligne."
            if [ "$SHOW_DIFF_ON_FAIL" = true ]; then
                diff --color=always <(printf "%s" "$expected_output") <(printf "%s" "$received_output")
            fi
        fi
        ((tests_failed++))
    fi
}

# ==================== Exécution Principale ====================

trap cleanup EXIT
clear
load_settings

if [ "$AUTO_COMPILE" = true ]; then
    compile_project
else
    show_title
    echo -e "$INFO Compilation auto désactivée. Assurez-vous que le projet est à jour."
fi

start_server

# Boucle principale du testeur
while true; do
    tests_passed=0
    tests_failed=0
    tests=()
    choice=""

    show_menu

    COMPACT_MODE=false
    if [[ "$choice" == "a" || "$choice" == "A" ]]; then
        COMPACT_MODE=true
    fi

    clear
    if [ "$COMPACT_MODE" = true ]; then
        echo -e "${C_BOLD}Rapport des tests :${C_RESET}"
    fi

    for test_id in "${tests[@]}"; do
        case $test_id in
            1) msg=${SIMPLE_MSGS[$RANDOM % ${#SIMPLE_MSGS[@]}]}; run_test "Message simple (aléatoire)" "$msg" ;;
            2) run_test "Chaîne vide" "" ;;
            3) msg=${UNICODE_MSGS[$RANDOM % ${#UNICODE_MSGS[@]}]}; run_test "Bonus: Emoji / UTF-8 (aléatoire)" "$msg" ;;
            4) msg=$(head -c 1000 /dev/urandom | base64 | tr -d '\n' | head -c 1000); run_test "Message long (1000)" "$msg" ;;
            5) run_multi_client_test ;;
        esac
    done

    print_separator
    echo -e "\n${C_BOLD}RÉSUMÉ DE LA SESSION${C_RESET}"
    echo -e "  ${C_GREEN}Tests réussis : $tests_passed${C_RESET}"
    echo -e "  ${C_RED}Tests échoués : $tests_failed${C_RESET}"

    if [ "$tests_failed" -eq 0 ] && [ ${#tests[@]} -gt 0 ]; then
        echo -e "\n${C_GREEN}${C_BOLD}🎉 Tous les tests de cette session ont réussi !${C_RESET}"
    elif [ ${#tests[@]} -gt 0 ]; then
        echo -e "\n${C_RED}${C_BOLD}⚠️  Des erreurs ont été détectées.${C_RESET}"
    fi

    echo
    read -n1 -s -r -p "Appuyez sur une touche pour retourner au menu..."
done
