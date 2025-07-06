#!/usr/bin/env python3

import subprocess
import time
import os
import signal
import re
import sys
import random
import string

SERVER_EXEC = "./server"
CLIENT_EXEC = "./client"
TIMEOUT = 2
RESULTS = []

# === ANSI STYLES ===
GREEN = "\033[92m"
RED = "\033[91m"
BLUE = "\033[94m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
BOLD = "\033[1m"
RESET = "\033[0m"

# === DIVERS ===
def rand_ascii(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

def rand_unicode():
    emojis = "🚀✨🧠🌍🎉🦄📦🐍😎🔥💻"
    words = ["été", "café", "éléphant", "français", "ñandú"]
    return random.choice(words) + " " + random.choice(emojis)

# === COMPILATION ===
def check_and_build():
    if os.path.exists(SERVER_EXEC) and os.path.exists(CLIENT_EXEC):
        return
    print(f"{YELLOW}Compilation nécessaire...{RESET}")
    try:
        res = subprocess.run(["make"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if res.returncode != 0:
            print(f"{RED}Erreur compilation :\n{res.stderr}{RESET}")
            sys.exit(1)
        print(f"{GREEN}Compilation réussie.{RESET}")
    except FileNotFoundError:
        print(f"{RED}'make' introuvable.{RESET}")
        sys.exit(1)
    for f in [SERVER_EXEC, CLIENT_EXEC]:
        if not os.path.exists(f):
            print(f"{RED}Binaire {f} manquant après compilation.{RESET}")
            sys.exit(1)

# === OUTILS DE TEST ===
def log_result(name, passed, duration=None, message_sent="", server_output="", detail=""):
    symbol = f"{GREEN}[✓]{RESET}" if passed else f"{RED}[✗]{RESET}"
    dur = f" ({duration:.2f}s)" if duration else ""
    print(f"\n{symbol} {BOLD}{name}{RESET}{dur}")
    print(f"    {BOLD}Message envoyé :{RESET} {message_sent}")
    print(f"    {BOLD}Réponse serveur :{RESET} {server_output}")
    if not passed:
        print(f"    {RED}Détail : {detail}{RESET}")
    RESULTS.append((name, passed, duration, message_sent, server_output, detail))

def launch_server():
    proc = subprocess.Popen([SERVER_EXEC], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
    line = ""
    for _ in range(20):
        line = proc.stdout.readline()
        if line:
            break
        time.sleep(0.1)
    match = re.search(r"\d+", line)
    if not match:
        proc.kill()
        raise RuntimeError("PID introuvable dans la sortie du serveur.")
    return proc, int(match.group())

def read_output(proc, expected, timeout=TIMEOUT):
    output = ""
    start = time.time()
    while time.time() - start < timeout:
        line = proc.stdout.readline()
        if line:
            output += line
            if expected in output:
                return True, output.strip()
        time.sleep(0.01)
    return False, output.strip()

def send_message(pid, msg, expect_ack=False):
    start = time.time()

    if expect_ack:
        # Rediriger stdout du client
        proc = subprocess.Popen([CLIENT_EXEC, str(pid), msg],
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE,
                                text=True)

        try:
            output, _ = proc.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            return time.time() - start, False

        duration = time.time() - start
        ack_found = "[ACK]" in output
        return duration, ack_found
    else:
        subprocess.run([CLIENT_EXEC, str(pid), msg],
                       stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)
        duration = time.time() - start
        return duration, None

# === TESTS ===
def test_pid():
    try:
        proc, _ = launch_server()
        proc.send_signal(signal.SIGINT)
        proc.wait()
        log_result("Affichage PID serveur", True)
        return True
    except Exception as e:
        log_result("Affichage PID serveur", False, detail=str(e))
        return False

def test_basic_msg():
    proc, pid = launch_server()
    msg = rand_ascii()
    duration, _ = send_message(pid, msg)
    success, output = read_output(proc, msg)
    proc.send_signal(signal.SIGINT)
    proc.wait()
    detail = "" if success else f"Attendu : '{msg}'"
    log_result("Message simple", success, duration, msg, output, detail)
    return success

def test_multi_msg():
    proc, pid = launch_server()
    all_ok = True
    for _ in range(3):
        msg = rand_ascii(6)
        _, _ = send_message(pid, msg)
        ok, out = read_output(proc, msg)
        if not ok:
            log_result(f"Message multiple '{msg}'", False, message_sent=msg, server_output=out.strip(), detail="Message manquant dans la sortie")
            all_ok = False
        else:
            log_result(f"Message multiple '{msg}'", True, message_sent=msg, server_output=out.strip())
    proc.send_signal(signal.SIGINT)
    proc.wait()
    return all_ok

def test_perf():
    proc, pid = launch_server()
    msg = rand_ascii(100)
    duration, _ = send_message(pid, msg)
    ok, output = read_output(proc, msg)
    proc.send_signal(signal.SIGINT)
    proc.wait()
    detail = f"{duration:.2f}s pour 100c"
    log_result("Performance (<1s pour 100c)", ok and duration < 1.0, duration, msg, output.strip(), detail)
    return ok

def test_unicode():
    proc, pid = launch_server()
    msg = rand_unicode()
    duration, _ = send_message(pid, msg)
    ok, output = read_output(proc, msg)
    proc.send_signal(signal.SIGINT)
    proc.wait()
    detail = "" if ok else "Encodage incorrect ou message tronqué"
    log_result("Support Unicode", ok, duration, msg, output.strip(), detail)
    return ok

def test_ack():
    proc, pid = launch_server()
    msg = "AckTest_" + rand_ascii(3)
    duration, ack = send_message(pid, msg, expect_ack=True)
    read_output(proc, msg)
    proc.send_signal(signal.SIGINT)
    proc.wait()
    detail = "" if ack else "Aucun signal SIGUSR1/SIGUSR2 reçu"
    log_result("Accusé de réception (SIGUSR)", ack, duration, msg, msg, detail)
    return ack

# === MENU ET EXPORT ===
def print_menu():
    print(f"\n{BLUE}{BOLD}╭────────────────────────────────────────────╮")
    print(f"│        TMT - Tester MiniTalk Tool          │")
    print(f"╰────────────────────────────────────────────╯{RESET}")
    print(f"{BOLD} 1.{RESET} Test affichage PID")
    print(f"{BOLD} 2.{RESET} Test message simple")
    print(f"{BOLD} 3.{RESET} Test messages multiples")
    print(f"{BOLD} 4.{RESET} Test performance")
    print(f"{BOLD} 5.{RESET} Test Unicode")
    print(f"{BOLD} 6.{RESET} Test accusé de réception")
    print(f"{BOLD} 7.{RESET} Lancer tous les tests")
    print(f"{BOLD} 8.{RESET} Quitter")

def show_results():
    print(f"\n{CYAN}{BOLD}╭──── Résumé des tests ─────────╮{RESET}")
    total = len(RESULTS)
    passed = sum(1 for _, ok, *_ in RESULTS if ok)
    for name, ok, *_ in RESULTS:
        mark = f"{GREEN}✓{RESET}" if ok else f"{RED}✗{RESET}"
        print(f" {mark} {name}")
    print(f"{CYAN}╰──── {passed}/{total} test(s) réussi(s) ────╯{RESET}\n")

def main():
    check_and_build()
    tests = {
        "1": test_pid,
        "2": test_basic_msg,
        "3": test_multi_msg,
        "4": test_perf,
        "5": test_unicode,
        "6": test_ack,
    }

    while True:
        print_menu()
        choice = input(f"{BOLD}Choix > {RESET}").strip()
        if choice == "8":
            print(f"{YELLOW}Fermeture du testeur. À bientôt.{RESET}")
            break
        elif choice == "7":
            RESULTS.clear()
            for func in tests.values():
                func()
            show_results()
        elif choice in tests:
            RESULTS.clear()
            tests[choice]()
            show_results()
        else:
            print(f"{RED}Entrée invalide.{RESET}")

if __name__ == "__main__":
    main()
