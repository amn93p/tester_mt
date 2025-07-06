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
if [ ! -f "$CLIENT" ] || [ ! -f "$SERVER" ]; then
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
    $SERVER > "$SERVER_LOG" &
    SERVER_PID=$!
    sleep 0.5
    REAL_PID=$(grep "PID:" "$SERVER_LOG" | cut -d " " -f2)
    if [ -z "$REAL_PID" ]; then
        echo "❌ PID introuvable."
        kill $SERVER_PID 2>/dev/null
        exit 1
    fi
    echo "PID capturé : $REAL_PID"
}

function test_message {
    local MESSAGE="$1"
    local DESCRIPTION="$2"
    ((TEST_TOTAL++))
    > "$SERVER_LOG"

    $CLIENT "$REAL_PID" "$MESSAGE"
    sleep 1

    RECEIVED=$(tail -n 1 "$SERVER_LOG" | tr -d '\0')

    if [ "$RECEIVED" = "$MESSAGE" ]; then
        echo "${GREEN}✅ $DESCRIPTION${RESET}"
        ((TEST_OK++))
    else
        echo "${RED}❌ $DESCRIPTION${RESET}"
        echo "    Attendu : '$MESSAGE'"
        echo "    Reçu    : '$RECEIVED'"
    fi
}

function test_acknowledgement {
    ((TEST_TOTAL++))
    echo "Test ACK (client doit bloquer sans serveur)..."

    ($CLIENT 999999 "ok" > /dev/null) &
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
test_message "🐍" "Caractère Unicode (🐍)"
test_message "😎" "Emoji (😎)"
test_message "abc" "Message avec terminaison explicite"
test_acknowledgement

echo ""
if [ "$TEST_OK" -eq "$TEST_TOTAL" ]; then
    echo "${GREEN}✅ Tous les tests sont passés ! ($TEST_OK/$TEST_TOTAL)${RESET}"
else
    echo "${RED}❌ $TEST_OK tests réussis sur $TEST_TOTAL${RESET}"
fi

cleanup
