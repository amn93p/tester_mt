#!/bin/bash

# ==============================================================================
# |                      Testeur Minitalk Robuste v3.0                         |
# |      Conçu pour la flexibilité, la robustesse et la conformité au sujet.   |
# ==============================================================================

# --- Configuration ---
SERVER="./server"
CLIENT="./client"
SERVER_LOG="server.log"

# --- Style et Statuts ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_BOLD='\033[1m'

SUCCESS="${C_GREEN}${C_BOLD}[SUCCÈS]${C_RESET}"
FAIL="${C_RED}${C_BOLD}[ÉCHEC]${C_RESET}"
INFO="${C_BLUE}${C_BOLD}[INFO]${C_RESET}"

# --- Compteurs ---
tests_passed=0
tests_failed=0

# ==============================================================================
# | FONCTIONS UTILITAIRES                                                      |
# ==============================================================================

cleanup() {
    echo -e "\n$INFO Nettoyage..."
    # L'option -j permet de tuer tout un groupe de processus, utile si le serveur lance des enfants.
    if [ -n "$SERVER_PID" ]; then
        kill -j $SERVER_PID 2>/dev/null
        kill $SERVER_PID 2>/dev/null
    fi
    rm -f "$SERVER_LOG"
}
# Piège la sortie du script pour lancer le nettoyage quoi qu'il arrive
trap cleanup EXIT

start_server() {
    echo -e "$INFO Démarrage du serveur..."
    ./$SERVER > "$SERVER_LOG" 2>&1 &
    SERVER_PID=$!
    sleep 0.5 # Laisse le temps au serveur de s'initialiser et d'afficher son PID

    # Regex pour extraire le premier nombre de la sortie, le rendant robuste
    local displayed_pid=$(grep -o -m 1 '[0-9]\+' "$SERVER_LOG")

    if [[ -n "$displayed_pid" ]]; then
        echo -e "$SUCCESS Serveur démarré. PID détecté : ${C_BOLD}$displayed_pid${C_RESET}"
        # On utilise le PID détecté pour plus de robustesse
        SERVER_PID=$displayed_pid
        # On vide le log de la ligne du PID pour ne pas fausser les tests
        sed -i '1d' "$SERVER_LOG"
    else
        echo -e "$FAIL Le serveur n'a pas affiché de PID numérique au démarrage. Contenu du log :"
        cat "$SERVER_LOG"
        exit 1
    fi
}

run_test() {
    local test_title="$1"
    local string_to_send="$2"
    
    echo -e "\n--- $test_title ---"
    
    # Vide le log pour ce test
    > "$SERVER_LOG"
    
    # --- Timeout Dynamique ---
    # Calcul : 2 secondes de base + 0.005 seconde par caractère.
    # C'est généreux mais attrapera les serveurs vraiment lents.
    local string_len=${#string_to_send}
    local timeout=$(echo "2 + $string_len * 0.005" | bc)

    # Exécution du client avec le timeout
    ./$CLIENT $SERVER_PID "$string_to_send" &
    local client_pid=$!
    
    (sleep $timeout && kill $client_pid 2>/dev/null) &
    local watcher_pid=$!
    
    wait $client_pid 2>/dev/null
    local client_status=$?
    
    kill $watcher_pid 2>/dev/null; wait $watcher_pid 2>/dev/null

    # --- Analyse du résultat ---
    if [ $client_status -ne 0 ]; then
        echo -e "$FAIL Le client a dépassé le timeout dynamique de ${timeout}s. (ACK non reçu ou serveur trop lent)"
        tests_failed=$((tests_failed + 1))
        return
    fi
    
    # Pause infime pour garantir que le filesystem a bien écrit le log
    sleep 0.1

    # --- Lecture Robuste & Vérification Flexible ---
    # `tr -d '\0'` supprime les octets nuls qui cassent la substitution de commande.
    # La comparaison `== *...*` vérifie si le message attendu est INCLUS dans la sortie.
    local server_output
    server_output=$(tr -d '\0' < "$SERVER_LOG")
    
    if [[ "$server_output" == *"$string_to_send"* ]]; then
        echo -e "$SUCCESS Message reçu correctement (client terminé à temps)."
        tests_passed=$((tests_passed + 1))
    else
        echo -e "$FAIL Message incorrect."
        echo -e "       ${C_YELLOW}Attendu (devait être inclus) :${C_RESET} '$string_to_send'"
        echo -e "       ${C_YELLOW}Reçu dans le log              :${C_RESET} '$server_output'"
        tests_failed=$((tests_failed + 1))
    fi
}

# ==============================================================================
# | SÉQUENCE DE TEST                                                           |
# ==============================================================================

if [ ! -x "$SERVER" ] || [ ! -x "$CLIENT" ]; then
    echo -e "$FAIL Exécutable '$SERVER' ou '$CLIENT' introuvable/non-exécutable."
    exit 1
fi

start_server

# --- Suite de tests logiques ---
run_test "Test 1: Chaîne simple (Validation de base)" \
         "Hello World!"

run_test "Test 2: Chaîne vide (Gestion d'un cas limite)" \
         ""

run_test "Test 3: Bonus - Support des caractères Unicode (UTF-8)" \
         "👋 π Vøici des çàractèrës spîciaux 测验 ✅"
         
long_string_4k=$(head -c 4000 /dev/urandom | base64 | tr -d '[:space:]' | head -c 4000)
run_test "Test 4: Robustesse - Très longue chaîne (4k caractères)" \
         "$long_string_4k"

echo -e "\n--- Test 5: Obligatoire - Gestion de clients multiples ---"
> "$SERVER_LOG"
./$CLIENT $SERVER_PID "Fragment1" &
./$CLIENT $SERVER_PID "Fragment2" &
./$CLIENT $SERVER_PID "Fragment3" &
wait # Attend la fin des 3 clients
sleep 0.5
final_output=$(tr -d '\0' < "$SERVER_LOG")
if [[ "$final_output" == *"Fragment1"* && "$final_output" == *"Fragment2"* && "$final_output" == *"Fragment3"* ]]; then
    echo -e "$SUCCESS Le serveur a reçu les messages de plusieurs clients sans planter."
    tests_passed=$((tests_passed + 1))
else
    echo -e "$FAIL Les messages de plusieurs clients sont manquants ou corrompus."
    echo -e "       ${C_YELLOW}Sortie finale:${C_RESET} '$final_output'"
    tests_failed=$((tests_failed + 1))
fi

# --- Résumé Final ---
echo -e "\n==================== ${C_BOLD}RÉSUMÉ${C_RESET} ===================="
echo -e "Tests réussis : ${C_GREEN}$tests_passed${C_RESET}"
echo -e "Tests échoués : ${C_RED}$tests_failed${C_RESET}"
echo "================================================"

if [ $tests_failed -eq 0 ]; then
    echo -e "\n${C_GREEN}🎉 Excellent ! Le Minitalk semble robuste et conforme au sujet.${C_RESET}"
    exit 0
else
    echo -e "\n${C_RED}🔥 Des tests ont échoué. Examine les logs pour déboguer.${C_RESET}"
    exit 1
fi
