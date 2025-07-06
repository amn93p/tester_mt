#!/bin/bash

SERVER="./server"
CLIENT="./client"
SERVER_LOG="server_output.txt"
TEST_OK=0
TEST_TOTAL=0

GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

function compile_project {
    echo "Compilation..."
    if [ -f Makefile ]; then
        make re > /dev/null
    else
        gcc -Wall -Wextra -Werror server.c libft_utils.c -o server
        gcc -Wall -Wextra -Werror client.c libft_utils.c -o client
    fi
}

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
    > "$SERVER_LOG"

    echo "Test ACK (accusé de réception)..."

    ($CLIENT "$REAL_PID" "ok" > /dev/null) &

    CLIENT_PID=$!

    sleep 0.5

    if ps -p $CLIENT_PID > /dev/null; then
        echo "${GREEN}✅ Le client attend l'accusé de réception${RESET}"
        kill $CLIENT_PID 2>/dev/null
        ((TEST_OK++))
    else
        echo "${RED}❌ Le client n'attend pas le ACK correctement${RESET}"
    fi
}

function cleanup {
    kill $SERVER_PID 2>/dev/null
    rm -f "$SERVER_LOG"
}

compile_project
launch_server

test_message "salut" "Message texte simple"
test_message "🐍" "Caractère Unicode 🐍"
test_message "😎" "Emoji 😎"
test_message "abc\0def" "Gestion du caractère nul (ne doit afficher que abc)"
test_acknowledgement

echo ""
if [ "$TEST_OK" -eq "$TEST_TOTAL" ]; then
    echo "${GREEN}🎉 Tous les tests sont passés ! ($TEST_OK/$TEST_TOTAL)${RESET}"
else
    echo "${RED}❌ $TEST_OK tests réussis sur $TEST_TOTAL${RESET}"
fi

cleanup
