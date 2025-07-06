#!/bin/bash

SERVER="./server"
CLIENT="./client"
SERVER_LOG="server_output.txt"
TEST_OK=0
TEST_TOTAL=0

GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

# Vérifie la présence des binaires ou compile
if [ ! -x "$CLIENT" ] || [ ! -x "$SERVER" ]; then
    echo "🔍 Binaire client/server introuvable. Tentative de compilation..."
    if [ -f Makefile ]; then
        make > /dev/null
    else
        echo "❌ Aucun Makefile trouvé. Compilation impossible."
        exit 1
    fi
fi

function launch_server {
    echo "Lancement du serveur..."
    $SERVER > "$SERVER_LOG" 2>&1 &
    SERVER_PID=$!

    # Attente active jusqu'à ce que le PID soit affiché
    for i in {1..20}; do
        REAL_PID=$(grep -m1 "PID:" "$SERVER_LOG" | awk '{print $2}')
        if [[ "$REAL_PID" =~ ^[0-9]+$ ]]; then
            echo "PID capturé : $REAL_PID"
            return
        fi
        sleep 0.1
    done

    echo "❌ PID introuvable après 2 secondes."
    kill $SERVER_PID 2>/dev/null
    exit 1
}

function test_message {
    local MESSAGE="$1"
    local DESCRIPTION="$2"
    ((TEST_TOTAL++))
    > "$SERVER_LOG"

    $CLIENT "$REAL_PID" "$MESSAGE" > /dev/null 2>&1
    sleep 1

    RECEIVED=$(tr -d '\0' < "$SERVER_LOG")

    if echo "$RECEIVED" | grep -qF "$MESSAGE"; then
        echo "${GREEN}✅ $DESCRIPTION${RESET}"
        ((TEST_OK++))
    else
        echo "${RED}❌ $DESCRIPTION${RESET}"
        echo "    Attendu : '$MESSAGE'"
        echo "    Reçu (extrait) : '$(tail -n 5 "$SERVER_LOG" | tr -d '\0')'"
    fi
}

function test_acknowledgement {
    ((TEST_TOTAL++))
    echo "Test ACK (client doit bloquer sans serveur)..."

    ($CLIENT 999999 "ok" > /dev/null 2>&1) &
    CLIENT_PID=$!

    sleep 1

    if ps -p $CLIENT_PID > /dev/null; then
        echo "${GREEN}✅ Le client attend bien le ACK en l'absence de serveur${RESET}"
        kill $CLIENT_PID 2>/dev/null
        ((TEST_OK++))
    else
        echo "${RED}❌ Le client n’attend pas le ACK (finit trop tôt sans serveur)${RESET}"
    fi
}

function cleanup {
    kill $SERVER_PID 2>/dev/null
    rm -f "$SERVER_LOG"
    if [ -f Makefile ]; then
        make fclean > /dev/null
        echo "🧹 Projet nettoyé (make fclean)."
    fi
}

launch_server

test_message "salut" "Message texte simple"
test_message "42Paris" "Nom de l'école"
test_message "🐍" "Caractère Unicode (🐍)"
test_message "😎" "Emoji (😎)"
test_message "abc" "Message court"
test_message "message de test long avec plusieurs mots" "Message plus long"
test_acknowledgement

echo ""
if [ "$TEST_OK" -eq "$TEST_TOTAL" ]; then
    echo "${GREEN}✅ Tous les tests sont passés ! ($TEST_OK/$TEST_TOTAL)${RESET}"
else
    echo "${RED}❌ $TEST_OK tests réussis sur $TEST_TOTAL${RESET}"
fi

cleanup
