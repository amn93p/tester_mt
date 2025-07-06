#!/bin/bash
set +H # Désactive l'expansion de l'historique (!)

# ╔════════════════════════════════════════════════════════════════════╗
# ║           Testeur Minitalk Interactif                            ║
# ║     Parfait pour le sujet 42 + bonus Unicode & ACK               ║
# ╚════════════════════════════════════════════════════════════════════╝

# === Dégradé propre : couleur entière par ligne ===
# Cette fonction fonctionne bien pour l'affichage DANS le script lui-même.
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

# === Configuration ===
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
    # Silencieux si le processus n'existe plus
    if ps -p $SERVER_PID > /dev/null; then
       kill $SERVER_PID
    fi
    rm -f "$SERVER_LOG"
}
trap cleanup EXIT

start_server() {
    echo -e "$INFO Lancement du serveur..."
    if [ ! -f "$SERVER" ] || [ ! -x "$SERVER" ]; then
        echo -e "$FAIL L'exécutable du serveur '$SERVER' est introuvable."
        exit 1
    fi
    $SERVER > "$SERVER_LOG" 2>&1 &
    SERVER_PID=$!
    sleep 0.5 # Laisse le temps au serveur de démarrer et d'afficher son PID

    # Tente de récupérer le PID de manière plus robuste
    local detected_pid=$(grep -o '[0-9]\+' "$SERVER_LOG" | head -n1)
    if [[ -z "$detected_pid" ]]; then
        echo -e "$FAIL PID du serveur non détecté dans $SERVER_LOG. Le serveur a-t-il pu démarrer ?"
        echo -e "$INFO Contenu du log du serveur :"
        cat "$SERVER_LOG"
        exit 1
    fi
    SERVER_PID=$detected_pid # On utilise le PID affiché par le serveur
    echo -e "$SUCCESS Serveur prêt. PID : ${C_BOLD}$SERVER_PID${C_RESET}"
}

run_test() {
    local title="$1"
    local message="$2"
    echo -e "\n--- $title ---"
    # Vide le log serveur avant chaque test pour ne pas avoir les résultats des tests précédents
    >"$SERVER_LOG"

    # Vérifie si le client existe et est exécutable
    if [ ! -f "$CLIENT" ] || [ ! -x "$CLIENT" ]; then
        echo -e "$FAIL L'exécutable du client '$CLIENT' est introuvable."
        ((tests_failed++))
        return
    fi

    # L'envoi du message
    ./$CLIENT "$SERVER_PID" "$message"
    sleep 1.5 # On augmente un peu le délai pour les messages longs ou complexes

    # tr -d '\0' supprime les caractères nuls qui peuvent apparaître
    local received=$(cat "$SERVER_LOG" | tr -d '\0')

    echo -e "📤 ${C_YELLOW}Envoyé  :${C_RESET} '$message'"
    echo -e "📥 ${C_YELLOW}Reçu    :${C_RESET} '$received'"

    # La comparaison doit être exacte. "==" est plus strict que "*...*".
    if [[ "$received" == "$message" ]]; then
        echo -e "$SUCCESS Le message a été correctement reçu."
        ((tests_passed++))
    else
        echo -e "$FAIL Message reçu incorrect ou incomplet."
        ((tests_failed++))
    fi
}

run_multi_client_test() {
    echo -e "\n--- Test: Clients multiples ---"
    >"$SERVER_LOG"

    ./$CLIENT "$SERVER_PID" "Message_Client_A" &
    pid1=$!
    ./$CLIENT "$SERVER_PID" "Message_Client_B" &
    pid2=$!
    ./$CLIENT "$SERVER_PID" "Message_Client_C" &
    pid3=$!

    wait $pid1 $pid2 $pid3
    sleep 1 # Attendre que le serveur traite tout

    output=$(tr -d '\0' < "$SERVER_LOG")
    echo -e "📥 ${C_YELLOW}Reçu total :${C_RESET} '$output'"

    # On vérifie que les 3 messages sont bien présents
    if [[ "$output" == *"Message_Client_A"* && "$output" == *"Message_Client_B"* && "$output" == *"Message_Client_C"* ]]; then
        echo -e "$SUCCESS Tous les messages des clients ont été reçus."
        ((tests_passed++))
    else
        echo -e "$FAIL Un ou plusieurs messages sont manquants ou corrompus."
        ((tests_failed++))
    fi
}

# ======================= NOUVELLE FONCTION DE TEST =======================
run_gradient_art_test() {
    local title="Test: ASCII Art en dégradé"
    
    # On définit l'art ASCII ligne par ligne.
    # La syntaxe $'\...' permet à Bash d'interpréter les codes \033 comme en C.
    # Cela crée une chaîne avec les VRAIS caractères de contrôle, pas le texte "\033".
    # On ajoute aussi les sauts de ligne `\n` pour que ce soit multi-ligne.
    ART_MESSAGE=""
    ART_MESSAGE+=$'\033[38;2;200;255;50m  _ _ _ _ _    _ _ _ _ _ \n'
    ART_MESSAGE+=$'\033[38;2;190;250;40m|           |/           |\n'
    ART_MESSAGE+=$'\033[38;2;180;245;30m|           /            |\n'
    ART_MESSAGE+=$'\033[38;2;170;240;20m| _ _ _ _ _ | _ _ _ _ _ _|\n'
    ART_MESSAGE+=$'\033[0m' # Reset de la couleur à la fin

    # On lance le test normalement avec la variable qui contient maintenant les bons codes
    run_test "$title" "$ART_MESSAGE"
}
# =========================================================================


show_menu() {
    echo -e "${C_BOLD}Sélectionne les tests à lancer :${C_RESET}"
    echo " 1 - Message simple"
    echo " 2 - Chaîne vide"
    echo " 3 - Emoji / Unicode"
    echo " 4 - Long message (1000)"
    echo " 5 - Clients multiples"
    echo " 6 - Art ASCII en dégradé (Bonus)"
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
        6) tests=(6) ;; # Ajout de l'option de menu
        0) tests=(1 2 3 4 5 6) ;; # Ajout au "tous les tests"
        q|Q) echo "Annulé."; exit 0 ;;
        *) echo "Choix invalide."; show_menu ;;
    esac
}

# === MAIN ===
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
        6) run_gradient_art_test ;; # Appel de la nouvelle fonction de test
    esac
done

# Résumé
echo -e "\n${C_BOLD}RÉSULTAT FINAL${C_RESET}"
echo -e "✅ Réussis : ${C_GREEN}$tests_passed${C_RESET}"
echo -e "❌ Échoués : ${C_RED}$tests_failed${C_RESET}"

if [ "$tests_failed" -eq 0 ]; then
    echo -e "\n${C_GREEN}🎉 Tout est bon, Minitalk est conforme !${C_RESET}"
else
    echo -e "\n${C_RED}⚠️  Des erreurs sont présentes. Consulte les logs ci-dessus.${C_RESET}"
fi
