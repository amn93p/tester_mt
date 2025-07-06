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
CLIENT_TIMEOUT=15 # Timeout généreux pour ne pas pénaliser les implémentations plus lentes

# Détermine le répertoire du script pour y stocker les paramètres
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SETTINGS_FILE="$SCRIPT_DIR/.tester_settings" # Fichier pour sauvegarder les paramètres

# --- Couleurs & Styles ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_BOLD='\033[1m'
C_MAGENTA='\033[0;35m'

# --- Préfixes de message ---
SUCCESS="${C_GREEN}${C_BOLD}[SUCCÈS]${C_RESET}"
FAIL="${C_RED}${C_BOLD}[ÉCHEC]${C_RESET}"
INFO="${C_BLUE}${C_BOLD}[INFO]${C_RESET}"
WARN="${C_YELLOW}${C_BOLD}[ATTENTION]${C_RESET}"
DEBUG="${C_MAGENTA}${C_BOLD}[DÉBOGAGE]${C_RESET}"

# === Banque de messages de test ===
SIMPLE_MSGS=(
    "Hello World!"
    "Minitalk est génial"
    "42 est la réponse à tout"
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
    "Le client C est là"
    "Première partie"
    "Deuxième partie"
    "Partie finale"
    "Un autre message"
    "Et encore un !"
)

# --- Compteurs ---
tests_passed=0
tests_failed=0
SERVER_PID="" # Initialisation à vide est cruciale

# ==================== Fonctions Principales ====================

# === Sauvegarde et chargement des paramètres ===
save_settings() {
    echo "CLEAN_ON_EXIT=$CLEAN_ON_EXIT" > "$SETTINGS_FILE"
    echo "AUTO_COMPILE=$AUTO_COMPILE" >> "$SETTINGS_FILE"
    echo "SHOW_DIFF_ON_FAIL=$SHOW_DIFF_ON_FAIL" >> "$SETTINGS_FILE"
    echo "DEBUG_MODE=$DEBUG_MODE" >> "$SETTINGS_FILE"
    echo "ACK_MODE=$ACK_MODE" >> "$SETTINGS_FILE"
    echo "LENIENT_MODE=$LENIENT_MODE" >> "$SETTINGS_FILE"
}

load_settings() {
    # Valeurs par défaut
    CLEAN_ON_EXIT=false
    AUTO_COMPILE=true
    SHOW_DIFF_ON_FAIL=false
    DEBUG_MODE=false
    ACK_MODE=false # Par défaut, on teste sans le bonus ACK
    LENIENT_MODE=true # Par défaut, la comparaison est stricte

    if [ -f "$SETTINGS_FILE" ]; then
        source "$SETTINGS_FILE"
    else
        # Si le fichier n'existe pas, on le crée avec les valeurs par défaut
        save_settings
    fi
}

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
    echo -e "$INFO Vérification de la présence d'un Makefile..."
    if [ ! -f "Makefile" ] && [ ! -f "makefile" ]; then
        echo -e "$FAIL Aucun Makefile trouvé. Impossible de lancer la compilation."
        echo -e "$INFO Assurez-vous que le testeur est dans le répertoire racine de votre projet Minitalk."
        exit 1
    fi
    echo -e "$SUCCESS Makefile trouvé."

    echo -e "$INFO Lancement de la compilation via 'make'..."
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

# === Nettoyage ===
cleanup() {
    local server_was_running=false
    if [[ -n "$SERVER_PID" ]] && ps -p "$SERVER_PID" > /dev/null; then
        server_was_running=true
    fi

    if [ "$server_was_running" = true ] || [ "$CLEAN_ON_EXIT" = true ]; then
        echo -e "\n$INFO Nettoyage..."
    fi

    if [ "$server_was_running" = true ]; then
        kill "$SERVER_PID" 2>/dev/null
    fi

    if [ "$CLEAN_ON_EXIT" = true ]; then
        if [ -f "Makefile" ] || [ -f "makefile" ]; then
            make fclean > /dev/null 2>&1
        fi
    fi
    rm -f "$SERVER_LOG"
}

# === Fonction de désinstallation ===
uninstall() {
    clear
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
        
        echo -e "$INFO Suppression du fichier de paramètres..."
        rm -f "$SETTINGS_FILE"

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

# === Affichage d'un paramètre ===
print_setting_status() {
    if [ "$1" = true ]; then
        echo -e "${C_GREEN}Activé${C_RESET}"
    else
        echo -e "${C_RED}Désactivé${C_RESET}"
    fi
}

# === Menu des paramètres (AMÉLIORÉ) ===
show_settings_menu() {
    while true; do
        clear
        fancy_title
        echo -e "${C_BOLD}--- Paramètres ---${C_RESET}"
        echo " 1. Nettoyer le projet en quittant ('fclean') : $(print_setting_status $CLEAN_ON_EXIT)"
        echo " 2. Compiler automatiquement au lancement      : $(print_setting_status $AUTO_COMPILE)"
        echo " 3. Afficher le 'diff' en cas d'échec        : $(print_setting_status $SHOW_DIFF_ON_FAIL)"
        echo " 4. Mode Débogage (voir sortie brute)        : $(print_setting_status $DEBUG_MODE)"
        echo " 5. Mode Accusé de Réception (ACK) [BONUS]   : $(print_setting_status $ACK_MODE)"
        echo " 6. Mode de comparaison indulgent             : $(print_setting_status $LENIENT_MODE)"
        echo ""
        echo " r - Retour au menu principal"
        echo -n "> "
        read -r choice
        case "$choice" in
            1)
                if [ "$CLEAN_ON_EXIT" = true ]; then CLEAN_ON_EXIT=false; else CLEAN_ON_EXIT=true; fi
                ;;
            2)
                if [ "$AUTO_COMPILE" = true ]; then AUTO_COMPILE=false; else AUTO_COMPILE=true; fi
                ;;
            3)
                if [ "$SHOW_DIFF_ON_FAIL" = true ]; then SHOW_DIFF_ON_FAIL=false; else SHOW_DIFF_ON_FAIL=true; fi
                ;;
            4)
                if [ "$DEBUG_MODE" = true ]; then DEBUG_MODE=false; else DEBUG_MODE=true; fi
                ;;
            5)
                if [ "$ACK_MODE" = true ]; then ACK_MODE=false; else ACK_MODE=true; fi
                ;;
            6)
                if [ "$LENIENT_MODE" = true ]; then LENIENT_MODE=false; else LENIENT_MODE=true; fi
                ;;
            r|R) break ;;
            *) echo "Choix invalide." && sleep 1 ;;
        esac
        save_settings
    done
}

# === Menu principal (AMÉLIORÉ) ===
show_menu() {
    while true; do
        clear
        fancy_title
        echo -e "${C_BOLD}Sélectionne les tests à lancer :${C_RESET}"
        echo " 0 - Tous les tests"
        echo " 1 - Message simple (aléatoire)"
        echo " 2 - Chaîne vide"
        echo " 3 - Bonus: Emoji / Unicode (aléatoire)"
        echo " 4 - Long message (1000)"
        echo " 5 - Clients multiples (aléatoire)"
        echo " p - Paramètres"
        echo " q - Quitter"
        echo -n "> "
        read -r choice
        case "$choice" in
            0) tests=(1 2 3 4 5); break ;;
            1) tests=(1); break ;;
            2) tests=(2); break ;;
            3) tests=(3); break ;;
            4) tests=(4); break ;;
            5) tests=(5); break ;;
            p|P) show_settings_menu ;;
            q|Q) echo "Annulé."; exit 0 ;;
            *) echo "Choix invalide." && sleep 1 ;;
        esac
    done
}

# === Démarrage du serveur ===
start_server() {
    echo -e "$INFO Lancement du serveur..."
    if [ ! -f "$SERVER" ] || [ ! -x "$SERVER" ]; then
        echo -e "$FAIL L'exécutable du serveur '$SERVER' est introuvable. Compilez votre projet ou activez la compilation auto."
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

# === Moteur de test (AMÉLIORÉ) ===
run_test() {
    local title="$1"
    local message_sent="$2"
    local expected_output
    expected_output=$(printf "%s\n" "$message_sent")

    echo -e "\n--- $title ---"
    >"$SERVER_LOG"

    if [ ! -f "$CLIENT" ] || [ ! -x "$CLIENT" ]; then
        echo -e "$FAIL L'exécutable du client '$CLIENT' est introuvable. Compilez votre projet ou activez la compilation auto."
        ((tests_failed++))
        return
    fi

    timeout "$CLIENT_TIMEOUT" ./"$CLIENT" "$SERVER_PID" "$message_sent"
    local client_exit_code=$?

    if [ $client_exit_code -eq 124 ]; then
        echo -e "$FAIL Le client a dépassé le temps imparti de ${CLIENT_TIMEOUT}s. Le serveur est-il bloqué ou, si le bonus ACK est implémenté, ne le renvoie-t-il pas ?"
        ((tests_failed++))
        return
    elif [ $client_exit_code -ne 0 ]; then
        echo -e "$FAIL Le client a retourné une erreur (code: $client_exit_code)."
        ((tests_failed++))
        return
    fi

    sleep 0.2
    local message_received
    message_received=$(tr -d '\0' < "$SERVER_LOG")
    
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "$DEBUG Contenu brut du log serveur :"
        cat -e "$SERVER_LOG" # Affiche les caractères non imprimables
        echo -e "$DEBUG Fin du contenu brut."
    fi

    echo -e "📤 ${C_YELLOW}Envoyé  :${C_RESET} '$message_sent'"
    echo -e "📥 ${C_YELLOW}Reçu    :${C_RESET} '$(echo -n "$message_received" | sed 's/$/↵/' | tr -d '\n')'"

    local final_check_result=1 # 0 pour succès, 1 pour échec
    if [ "$LENIENT_MODE" = true ]; then
        echo -e "$INFO Mode de comparaison indulgent activé. Les différences d'espacement sont ignorées."
        local sanitized_received=$(echo -n "$message_received" | tr -s '[:space:]' ' ' | xargs)
        local sanitized_expected=$(echo -n "$expected_output" | tr -s '[:space:]' ' ' | xargs)
        if [[ "$sanitized_received" == "$sanitized_expected" ]]; then
            final_check_result=0
        fi
    else
        # Comparaison stricte par défaut
        if [[ "$message_received" == "$expected_output" ]]; then
            final_check_result=0
        fi
    fi

    if [ $final_check_result -eq 0 ]; then
        echo -e "$SUCCESS Le message a été correctement reçu."
        ((tests_passed++))
    else
        echo -e "$FAIL Message reçu incorrect ou incomplet."
        if [ "$SHOW_DIFF_ON_FAIL" = true ]; then
            echo -e "${C_BOLD}--- DIFFÉRENCE ---${C_RESET}"
            diff --color=always <(echo -n "$expected_output") <(echo -n "$message_received")
            echo "--------------------"
        fi
        ((tests_failed++))
    fi
}

# === Test Multi-Clients (AMÉLIORÉ AVEC MODE ACK) ===
run_multi_client_test() {
    echo -e "\n--- Test: Clients multiples (en série, aléatoire) ---"
    >"$SERVER_LOG"

    local msg1=${MULTI_CLIENT_MSGS[$RANDOM % ${#MULTI_CLIENT_MSGS[@]}]}
    local msg2=${MULTI_CLIENT_MSGS[$RANDOM % ${#MULTI_CLIENT_MSGS[@]}]}
    while [[ "$msg1" == "$msg2" ]]; do
        msg2=${MULTI_CLIENT_MSGS[$RANDOM % ${#MULTI_CLIENT_MSGS[@]}]}
    done
    local msg3=${MULTI_CLIENT_MSGS[$RANDOM % ${#MULTI_CLIENT_MSGS[@]}]}
    while [[ "$msg3" == "$msg1" || "$msg3" == "$msg2" ]]; do
        msg3=${MULTI_CLIENT_MSGS[$RANDOM % ${#MULTI_CLIENT_MSGS[@]}]}
    done
    
    local expected_output
    expected_output=$(printf "%s\n%s\n%s\n" "$msg1" "$msg2" "$msg3")
    
    local inter_client_sleep=0.5 # Pause par défaut, généreuse pour les projets SANS ACK
    if [ "$ACK_MODE" = true ]; then
        inter_client_sleep=0.1 # Pause courte, on se fie au mécanisme d'ACK pour la synchronisation
        echo -e "$INFO Mode ACK activé. Utilisation de pauses courtes entre les clients."
    else
        echo -e "$INFO Mode ACK désactivé. Utilisation de pauses longues entre les clients."
    fi

    echo -e "$INFO Envoi de 3 messages à la suite..."
    timeout "$CLIENT_TIMEOUT" ./"$CLIENT" "$SERVER_PID" "$msg1" || { echo -e "$FAIL Le client 1 a échoué."; ((tests_failed++)); return; }
    sleep "$inter_client_sleep"
    timeout "$CLIENT_TIMEOUT" ./"$CLIENT" "$SERVER_PID" "$msg2" || { echo -e "$FAIL Le client 2 a échoué."; ((tests_failed++)); return; }
    sleep "$inter_client_sleep"
    timeout "$CLIENT_TIMEOUT" ./"$CLIENT" "$SERVER_PID" "$msg3" || { echo -e "$FAIL Le client 3 a échoué."; ((tests_failed++)); return; }
    sleep 0.5

    local received_output
    received_output=$(tr -d '\0' < "$SERVER_LOG")
    
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "$DEBUG Contenu brut du log serveur :"
        cat -e "$SERVER_LOG" # Affiche les caractères non imprimables
        echo -e "$DEBUG Fin du contenu brut."
    fi
    
    echo -e "📤 ${C_YELLOW}Attendu :${C_RESET} '$(echo -n "$expected_output" | sed 's/$/↵/' | tr -d '\n')'"
    echo -e "📥 ${C_YELLOW}Reçu    :${C_RESET} '$(echo -n "$received_output" | sed 's/$/↵/' | tr -d '\n')'"

    local final_check_result=1 # 0 pour succès, 1 pour échec
    if [ "$LENIENT_MODE" = true ]; then
        echo -e "$INFO Mode de comparaison indulgent activé. Les différences d'espacement sont ignorées."
        local sanitized_received=$(echo -n "$received_output" | tr -s '[:space:]' ' ' | xargs)
        local sanitized_expected=$(echo -n "$expected_output" | tr -s '[:space:]' ' ' | xargs)
        if [[ "$sanitized_received" == "$sanitized_expected" ]]; then
            final_check_result=0
        fi
    else
        # Comparaison stricte par défaut
        if [[ "$received_output" == "$expected_output" ]]; then
            final_check_result=0
        fi
    fi

    if [ $final_check_result -eq 0 ]; then
        echo -e "$SUCCESS Tous les messages des clients ont été reçus dans le bon ordre."
        ((tests_passed++))
    else
        echo -e "$FAIL Un ou plusieurs messages sont manquants ou corrompus."
        if [ "$SHOW_DIFF_ON_FAIL" = true ]; then
            echo -e "${C_BOLD}--- DIFFÉRENCE ---${C_RESET}"
            diff --color=always <(echo -n "$expected_output") <(echo -n "$message_received")
            echo "--------------------"
        fi
        ((tests_failed++))
    fi
}

# ==================== Exécution Principale ====================

clear # Nettoie le terminal au lancement
load_settings # Charge les paramètres au début

if [ "$1" == "uninstall" ]; then
    uninstall
fi

trap cleanup EXIT

if [ "$AUTO_COMPILE" = true ]; then
    compile_project
else
    fancy_title
    echo -e "$INFO Compilation automatique désactivée. Assurez-vous que le projet est compilé."
fi

show_menu
start_server

for test in "${tests[@]}"; do
    case $test in
        1) 
            msg=${SIMPLE_MSGS[$RANDOM % ${#SIMPLE_MSGS[@]}]}
            run_test "Message simple (aléatoire)" "$msg"
            ;;
        2) run_test "Chaîne vide" "" ;;
        3) 
            msg=${UNICODE_MSGS[$RANDOM % ${#UNICODE_MSGS[@]}]}
            run_test "Bonus: Emoji / UTF-8 (aléatoire)" "$msg"
            ;;
        4) 
            msg=$(head -c 1000 /dev/urandom | base64 | tr -d '\n' | head -c 1000)
            run_test "Message long et complexe (1000)" "$msg"
            ;;
        5) run_multi_client_test ;;
    esac
done

clear # Nettoie avant d'afficher le résumé
# === Résumé Final ===
echo -e "\n${C_BOLD}RÉSULTAT FINAL${C_RESET}"
echo -e "✅ Réussis : ${C_GREEN}$tests_passed${C_RESET}"
echo -e "❌ Échoués : ${C_RED}$tests_failed${C_RESET}"

if [ "$tests_failed" -eq 0 ]; then
    echo -e "\n${C_GREEN}🎉 Tout est bon, Minitalk est conforme !${C_RESET}"
else
    echo -e "\n${C_RED}⚠️  Des erreurs sont présentes. Consulte les logs ci-dessus.${C_RESET}"
fi
