#!/bin/bash

# ==============================================================================
# | Testeur Minitalk Conforme au Sujet 42                                      |
# | Ce script vérifie les exigences obligatoires et bonus de manière logique.  |
# ==============================================================================

# --- Configuration ---
SERVER="./server"
CLIENT="./client"
SERVER_LOG="server_output.log"
TIMEOUT=8 # Secondes max pour qu'un client (avec bonus) se termine.

# --- Style et Statut ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_BOLD='\033[1m'

SUCCESS="${C_GREEN}${C_BOLD}[SUCCÈS]${C_RESET}"
FAIL="${C_RED}${C_BOLD}[ÉCHEC]${C_RESET}"
INFO="${C_BLUE}${C_BOLD}[INFO]${C_RESET}"
WARN="${C_YELLOW}${C_BOLD}[AVERT]${C_RESET}"

# --- Compteurs ---
tests_passed=0
tests_failed=0

# ==============================================================================
# | FONCTIONS UTILITAIRES                                                      |
# ==============================================================================

# Démarre le serveur et vérifie qu'il affiche un PID valide.
start_server() {
    echo -e "$INFO Démarrage du serveur..."
    
    # Lance le serveur, capture sa sortie initiale (le PID) dans un fichier
    # et le reste dans le log principal.
    stdbuf -o0 ./$SERVER > "$SERVER_LOG" 2>&1 &
    SERVER_PID=$!
    
    # Laisse le temps au serveur d'écrire son PID
    sleep 0.5
    
    # Le PID affiché par le serveur est la première ligne du log
    local displayed_pid=$(head -n 1 "$SERVER_LOG")

    # Nettoie le log pour ne garder que la sortie des messages
    tail -n +2 "$SERVER_LOG" > tmp.log && mv tmp.log "$SERVER_LOG"

    if [[ "$displayed_pid" =~ ^[0-9]+$ ]] && [ "$displayed_pid" -eq "$SERVER_PID" ]; then
        echo -e "$SUCCESS Le serveur a démarré et affiché son PID correctement : ${C_BOLD}$SERVER_PID${C_RESET}"
        return 0
    else
        echo -e "$FAIL Le serveur n'a pas affiché un PID valide au démarrage."
        echo -e "       PID attendu: $SERVER_PID | PID affiché: '$displayed_pid'"
        kill $SERVER_PID 2>/dev/null
        exit 1
    fi
}

# Arrête proprement le serveur
stop_server() {
    echo -e "\n$INFO Arrêt du serveur..."
    if kill $SERVER_PID 2>/dev/null; then
        wait $SERVER_PID 2>/dev/null
        echo -e "$SUCCESS Serveur arrêté proprement."
    else
        echo -e "$WARN Le serveur ne tournait plus."
    fi
    rm -f "$SERVER_LOG"
}

# Exécute un test unitaire
# Arguments: 1: Titre du test | 2: Chaîne à envoyer | 3: Chaîne attendue (si différente)
run_test() {
    local test_title="$1"
    local string_to_send="$2"
    local expected_output="${3:-$string_to_send}" # Utilise l'argument 3 ou le 2 par défaut
    
    echo -e "\n--- $test_title ---"
    
    # Vide le log serveur avant le test
    > "$SERVER_LOG"
    
    # Exécution du client avec un timeout pour gérer le bonus ACK
    ./$CLIENT $SERVER_PID "$string_to_send" &
    local client_pid=$!
    
    (sleep $TIMEOUT && kill $client_pid 2>/dev/null) &
    local watcher_pid=$!
    
    wait $client_pid 2>/dev/null
    local client_status=$?
    
    # Nettoie le processus de surveillance
    kill $watcher_pid 2>/dev/null
    wait $watcher_pid 2>/dev/null

    # Analyse du résultat
    if [ $client_status -ne 0 ]; then
        echo -e "$FAIL Le client a dépassé le timeout de $TIMEOUT s. Le serveur n'a probablement pas envoyé d'ACK (bonus)."
        tests_failed=$((tests_failed + 1))
        return 1
    fi

    # Laisse une marge infime pour que le dernier signal soit traité et écrit
    sleep 0.1
    local server_output=$(cat "$SERVER_LOG" | tr -d '\n')

    if [ "$server_output" == "$expected_output" ]; then
        echo -e "$SUCCESS Le message a été reçu et affiché correctement."
        tests_passed=$((tests_passed + 1))
    else
        echo -e "$FAIL Le message reçu est incorrect."
        echo -e "       ${C_YELLOW}Attendu :${C_RESET} '$expected_output'"
        echo -e "       ${C_YELLOW}Reçu    :${C_RESET} '$server_output'"
        tests_failed=$((tests_failed + 1))
    fi
}

# ==============================================================================
# | SÉQUENCE DE TEST                                                           |
# ==============================================================================

# --- Vérification initiale ---
if [ ! -x "$SERVER" ] || [ ! -x "$CLIENT" ]; then
    echo -e "$FAIL Un des exécutables ($SERVER, $CLIENT) est introuvable ou non exécutable."
    exit 1
fi

start_server

# --- Tests Mandatoires ---
run_test "Test 1 (Obligatoire): Chaîne de caractères simple" \
         "Hello World!"

# --- Tests Bonus ---
run_test "Test 2 (Bonus): Support des caractères Unicode" \
         "👋 π Vøici des çàractèrës spîciaux 测验 ✅"

# --- Tests de Robustesse (implicites dans le sujet) ---
long_string=$(head -c 4000 /dev/urandom | base64 | tr -d '\n' | head -c 4000)
run_test "Test 3 (Robustesse): Très longue chaîne (4000 caractères)" \
         "$long_string"

run_test "Test 4 (Robustesse): Chaîne vide" \
         ""

echo -e "\n--- Test 5 (Obligatoire): Gestion de clients multiples et consécutifs ---"
> "$SERVER_LOG"
./$CLIENT $SERVER_PID "Message 1. " &
./$CLIENT $SERVER_PID "Message 2. " &
./$CLIENT $SERVER_PID "Message 3." &
wait # Attend la fin de tous les processus en arrière-plan
sleep 0.5 # Laisse le temps au serveur de tout afficher
server_output=$(cat "$SERVER_LOG" | tr -d '\n')
expected_output="Message 1. Message 2. Message 3."
if [ "$server_output" == "$expected_output" ]; then
    echo -e "$SUCCESS Les messages de plusieurs clients ont été traités correctement et dans l'ordre."
    tests_passed=$((tests_passed + 1))
else
    echo -e "$FAIL Les messages de plusieurs clients sont mélangés ou incorrects."
    echo -e "       ${C_YELLOW}Attendu :${C_RESET} '$expected_output'"
    echo -e "       ${C_YELLOW}Reçu    :${C_RESET} '$server_output'"
    tests_failed=$((tests_failed + 1))
fi

stop_server

# --- Résumé Final ---
echo -e "\n==================== ${C_BOLD}RÉSUMÉ${C_RESET} ===================="
echo -e "Tests réussis : ${C_GREEN}$tests_passed${C_RESET}"
echo -e "Tests échoués : ${C_RED}$tests_failed${C_RESET}"
echo "================================================"

if [ $tests_failed -eq 0 ]; then
    exit 0
else
    exit 1
fi
