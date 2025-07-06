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

GREEN = "\033[92m"
RED = "\033[91m"
BLUE = "\033[94m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
BOLD = "\033[1m"
RESET = "\033[0m"

def rand_ascii(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

def rand_unicode():
    emojis = "🚀✨🧠🌍🎉🦄📦🐍😎🔥💻"
    words = ["été", "café", "éléphant", "français", "ñandú"]
    return random.choice(words) + " " + random.choice(emojis)

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

def log_result(name, passed, duration=None, message_sent="", server_output="", detail="", category="obligatoire"):
    symbol = f"{GREEN}[✓]{RESET}" if passed else f"{RED}[✗]{RESET}"
    dur = f" ({duration:.2f}s)" if duration else ""
    print(f"\n{symbol} {BOLD}{name}{RESET}{dur}")
    print(f"    {BOLD}Message envoyé :{RESET} {message_sent}")
    print(f"    {BOLD}Réponse serveur :{RESET} {server_output}")
    if not passed:
        print(f"    {RED}Détail : {detail}{RESET}")
    RESULTS.append((name, passed, category))

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
    return proc, int(match.group()), line.strip()

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
        proc = subprocess.Popen([CLIENT_EXEC, str(pid), msg], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            output, _ = proc.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            return time.time() - start, False
        duration = time.time() - start
        ack_found = "[ACK]" in output
        return duration, ack_found
    else:
        subprocess.run([CLIENT_EXEC, str(pid), msg], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        duration = time.time() - start
        return duration, None

def test_pid():
    try:
        proc, pid, output = launch_server()
        proc.send_signal(signal.SIGINT)
        proc.wait()
        log_result("Affichage PID serveur", True, message_sent="N/A", server_output=output or "PID détecté", category="obligatoire")
        return True
    except Exception as e:
        log_result("Affichage PID serveur", False, message_sent="N/A", server_output="N/A", detail=str(e), category="obligatoire")
        return False

def test_basic_msg():
    proc, pid, _ = launch_server()
    msg = rand_ascii()
    duration, _ = send_message(pid, msg)
    success, output = read_output(proc, msg)
    proc.send_signal(signal.SIGINT)
    proc.wait()
    detail = "" if success else f"Attendu : '{msg}'"
    log_result("Message simple", success, duration, msg, output, detail, category="obligatoire")
    return success

def test_multi_msg():
    proc, pid, _ = launch_server()
    all_ok = True
    for _ in range(3):
        msg = rand_ascii(6)
        _, _ = send_message(pid, msg)
        ok, out = read_output(proc, msg)
        if not ok:
            log_result(f"Message multiple '{msg}'", False, message_sent=msg, server_output=out.strip(), detail="Message manquant dans la sortie", category="obligatoire")
            all_ok = False
        else:
            log_result(f"Message multiple '{msg}'", True, message_sent=msg, server_output=out.strip(), category="obligatoire")
    proc.send_signal(signal.SIGINT)
    proc.wait()
    return all_ok

def test_perf():
    proc, pid, _ = launch_server()
    msg = rand_ascii(100)
    duration, _ = send_message(pid, msg)
    ok, output = read_output(proc, msg)
    proc.send_signal(signal.SIGINT)
    proc.wait()
    detail = f"{duration:.2f}s pour 100c"
    log_result("Performance (<1s pour 100c)", ok and duration < 1.0, duration, msg, output.strip(), detail, category="obligatoire")
    return ok

def test_unicode():
    proc, pid, _ = launch_server()
    msg = rand_unicode()
    duration, _ = send_message(pid, msg)
    ok, output = read_output(proc, msg)
    proc.send_signal(signal.SIGINT)
    proc.wait()
    detail = "" if ok else "Encodage incorrect ou message tronqué"
    log_result("Support Unicode", ok, duration, msg, output.strip(), detail, category="bonus")
    return ok

def test_ack():
    proc, pid, _ = launch_server()
    msg = "AckTest_" + rand_ascii(3)
    duration, ack = send_message(pid, msg, expect_ack=True)
    read_output(proc, msg)
    proc.send_signal(signal.SIGINT)
    proc.wait()
    detail = "" if ack else "Aucun signal SIGUSR1/SIGUSR2 reçu"
    log_result("Accusé de réception (SIGUSR)", ack, duration, msg, msg, detail, category="bonus")
    return ack

def test_summary():
    print(f"\n{CYAN}{BOLD}╭──── Résumé des tests ─────╮{RESET}")
    passed = total = 0
    obligatory = bonus = passed_ob = passed_bn = 0
    for name, ok, cat in RESULTS:
        total += 1
        passed += ok
        if cat == "obligatoire":
            obligatory += 1
            passed_ob += ok
        else:
            bonus += 1
            passed_bn += ok
        symbol = f"{GREEN}✓{RESET}" if ok else f"{RED}✗{RESET}"
        print(f" {symbol} {name}")
    print(f"{CYAN}╰────────────────────────────╯{RESET}")

    ob_status = f"{GREEN}VALIDÉ{RESET}" if passed_ob == obligatory else f"{RED}INCOMPLET{RESET}"
    if bonus == 0:
        bn_status = "-"
    elif passed_bn == bonus:
        bn_status = f"{GREEN}ACQUIS (Bonus complet){RESET}"
    elif passed_bn > 0:
        bn_status = f"{YELLOW}PARTIEL (Bonus partiellement validé){RESET}"
    else:
        bn_status = f"{RED}NON VALIDÉ (Aucun bonus acquis){RESET}"

    if passed_ob == obligatory and passed_bn == bonus:
        note = f"{GREEN}🎉 Toutes les fonctionnalités sont validées (obligatoire + bonus){RESET}"
    elif passed_ob == obligatory:
        note = f"{YELLOW}Partie obligatoire validée, bonus partiel ou manquant{RESET}"
    else:
        note = f"{RED}Partie obligatoire incomplète. Corrigez les erreurs bloquantes.{RESET}"

    print(f"\n{BOLD}Résultat global :{RESET}")
    print(f" Partie obligatoire : {passed_ob}/{obligatory} → {ob_status}")
    print(f" Bonus : {passed_bn}/{bonus} → {bn_status}")
    print(f"\n→ {note}\n")

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
        print(f"\n{BLUE}{BOLD}╭────────────────────────────────────────────╮")
        print(f"│        TMT - Tester MiniTalk Tool          │")
        print(f"╰────────────────────────────────────────────╯{RESET}")
        for key, func in tests.items():
            print(f" {BOLD}{key}.{RESET} {func.__name__}")
        print(f" {BOLD}A.{RESET} Lancer tous les tests")
        print(f" {BOLD}Q.{RESET} Quitter")
        choice = input(f"{BOLD}Choix > {RESET}").strip().upper()
        if choice == "Q":
            print(f"{YELLOW}Fermeture du testeur. À bientôt.{RESET}")
            break
        elif choice == "A":
            RESULTS.clear()
            for func in tests.values():
                func()
            test_summary()
        elif choice in tests:
            RESULTS.clear()
            tests[choice]()
            test_summary()
        else:
            print(f"{RED}Entrée invalide.{RESET}")

if __name__ == "__main__":
    main()
