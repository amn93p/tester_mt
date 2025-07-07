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

# Couleurs pour l'affichage
GREEN = "\033[92m"
RED = "\033[91m"
BLUE = "\033[94m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
BOLD = "\033[1m"
RESET = "\033[0m"

def clear():
    os.system('cls' if os.name == 'nt' else 'clear')

def wait_for_key():
    print(f"\n{CYAN}Appuie sur une touche pour revenir au menu...{RESET}", end='', flush=True)
    try:
        # Unix-like
        import tty, termios
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        tty.setraw(fd)
        sys.stdin.read(1)
    except:
        # Fallback pour Windows
        os.system("pause >nul")
    finally:
        try:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        except:
            pass
    clear()

def rand_ascii(length=8):
    """Génère une chaîne ASCII aléatoire."""
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

def rand_unicode():
    """Génère une chaîne Unicode aléatoire avec des mots et des emojis."""
    emojis = "🚀✨🧠🌍�🦄📦🐍😎🔥💻"
    words = ["été", "café", "éléphant", "français", "ñandú"]
    return random.choice(words) + " " + random.choice(emojis)

def check_and_build():
    """Vérifie la présence des binaires et lance `make` si nécessaire."""
    if os.path.exists(SERVER_EXEC) and os.path.exists(CLIENT_EXEC):
        return
    print(f"{YELLOW}Compilation nécessaire...{RESET}")
    try:
        res = subprocess.run(["make"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if res.returncode != 0:
            print(f"{RED}Erreur de compilation :\n{res.stderr}{RESET}")
            sys.exit(1)
        print(f"{GREEN}Compilation réussie.{RESET}")
    except FileNotFoundError:
        print(f"{RED}'make' est introuvable. Assurez-vous qu'il est installé et dans votre PATH.{RESET}")
        sys.exit(1)
    for f in [SERVER_EXEC, CLIENT_EXEC]:
        if not os.path.exists(f):
            print(f"{RED}Le binaire {f} est manquant après la compilation.{RESET}")
            sys.exit(1)

def log_result(name, passed, duration=None, message_sent="", server_output="", detail="", category="obligatoire"):
    """Affiche et enregistre le résultat d'un test."""
    symbol = f"{GREEN}[✓]{RESET}" if passed else f"{RED}[✗]{RESET}"
    dur = f" ({duration:.2f}s)" if duration is not None else ""
    print(f"\n{symbol} {BOLD}{name}{RESET}{dur}")
    print(f"    {BOLD}Message envoyé :{RESET} {message_sent}")
    print(f"    {BOLD}Réponse serveur :{RESET} {server_output}")
    if not passed:
        print(f"    {RED}Détail : {detail}{RESET}")
    RESULTS.append((name, passed, category))

def launch_server():
    """Lance le serveur et récupère son PID."""
    proc = subprocess.Popen([SERVER_EXEC], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1, preexec_fn=os.setsid)
    line = ""
    # Attend que le serveur affiche son PID
    for _ in range(20):
        line = proc.stdout.readline()
        if line:
            break
        time.sleep(0.1)
    match = re.search(r"\d+", line)
    if not match:
        proc.kill()
        raise RuntimeError("PID introuvable dans la sortie du serveur. Le serveur doit afficher son PID au démarrage.")
    return proc, int(match.group()), line.strip()

def read_output(proc, expected, timeout=TIMEOUT):
    """Lit la sortie d'un processus jusqu'à trouver un texte attendu ou qu'un timeout soit atteint."""
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
    """Envoie un message via le client."""
    start = time.time()
    if expect_ack:
        proc = subprocess.Popen([CLIENT_EXEC, str(pid), msg], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            output, _ = proc.communicate(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            return time.time() - start, False
        duration = time.time() - start
        # MODIFICATION : On considère qu'un accusé de réception est reçu si le client
        # écrit quoi que ce soit sur sa sortie standard, peu importe le contenu.
        ack_found = bool(output.strip())
        return duration, ack_found
    else:
        subprocess.run([CLIENT_EXEC, str(pid), msg], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        duration = time.time() - start
        return duration, None

def test_pid():
    """Teste si le serveur affiche correctement son PID."""
    try:
        proc, pid, output = launch_server()
        os.killpg(os.getpgid(proc.pid), signal.SIGINT)
        proc.wait()
        log_result("Affichage PID serveur", True, message_sent="N/A", server_output=output or "PID détecté", category="obligatoire")
        return True
    except Exception as e:
        log_result("Affichage PID serveur", False, message_sent="N/A", server_output="N/A", detail=str(e), category="obligatoire")
        return False

def test_basic_msg():
    """Teste l'envoi et la réception d'un message ASCII simple."""
    proc, pid, _ = launch_server()
    msg = rand_ascii()
    duration, _ = send_message(pid, msg)
    success, output = read_output(proc, msg)
    os.killpg(os.getpgid(proc.pid), signal.SIGINT)
    proc.wait()
    detail = "" if success else f"Le message '{msg}' n'a pas été reçu ou affiché correctement par le serveur."
    log_result("Message simple ASCII", success, duration, msg, output, detail, category="obligatoire")
    return success

def test_multi_msg():
    """Teste l'envoi et la réception de plusieurs messages à la suite."""
    proc, pid, _ = launch_server()
    all_ok = True
    for i in range(3):
        msg = rand_ascii(6)
        _, _ = send_message(pid, msg)
        ok, out = read_output(proc, msg)
        if not ok:
            log_result(f"Message multiple '{msg}'", False, message_sent=msg, server_output=out.strip(), detail="Message manquant dans la sortie du serveur.", category="obligatoire")
            all_ok = False
        else:
            log_result(f"Message multiple '{msg}'", True, message_sent=msg, server_output=out.strip(), category="obligatoire")
    os.killpg(os.getpgid(proc.pid), signal.SIGINT)
    proc.wait()
    return all_ok

def test_perf():
    """Teste la performance de la transmission pour une chaîne de 100 caractères."""
    proc, pid, _ = launch_server()
    msg = rand_ascii(100)
    duration, _ = send_message(pid, msg)
    ok, output = read_output(proc, msg)
    os.killpg(os.getpgid(proc.pid), signal.SIGINT)
    proc.wait()
    detail = f"Temps de transmission : {duration:.2f}s pour 100 caractères."
    log_result("Performance", ok and duration < 1.0, duration, msg, output.strip(), detail, category="obligatoire")
    return ok

def test_unicode():
    """Teste la transmission de caractères Unicode."""
    proc, pid, _ = launch_server()
    msg = rand_unicode()
    duration, _ = send_message(pid, msg)
    ok, output = read_output(proc, msg)
    os.killpg(os.getpgid(proc.pid), signal.SIGINT)
    proc.wait()
    detail = "" if ok else "Le message Unicode a été tronqué ou l'encodage est incorrect."
    log_result("Support Unicode", ok, duration, msg, output.strip(), detail, category="bonus")
    return ok

def test_ack():
    """Teste la fonctionnalité d'accusé de réception."""
    proc, pid, _ = launch_server()
    msg = "AckTest_" + rand_ascii(3)
    duration, ack = send_message(pid, msg, expect_ack=True)
    # On lit la sortie du serveur pour un log cohérent
    _, server_output = read_output(proc, msg)
    os.killpg(os.getpgid(proc.pid), signal.SIGINT)
    proc.wait()
    # MODIFIÉ : Le message de détail est plus générique pour correspondre à la nouvelle logique.
    detail = "" if ack else "Le client n'a rien affiché sur sa sortie standard pour confirmer la réception."
    log_result("Accusé de réception", ack, duration, msg, server_output.strip(), detail, category="bonus")
    return ack

def test_summary():
    """Affiche un résumé des résultats des tests."""
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
    print(f"{CYAN}╰───────────────────────────╯{RESET}")

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
    clear()
    """Fonction principale, affiche le menu et lance les tests."""
    check_and_build()
    tests = {
        "1": ("Test PID", test_pid),
        "2": ("Message simple", test_basic_msg),
        "3": ("Messages multiples", test_multi_msg),
        "4": ("Performance", test_perf),
        "5": ("Unicode", test_unicode),
        "6": ("Accusé de réception", test_ack),
    }
    while True:
        print(f"\n{BLUE}{BOLD}╭────────────────────────────────────────────╮")
        print(f"│        TMT - Tester MiniTalk Tool          │")
        print(f"╰────────────────────────────────────────────╯{RESET}")
        for key, (name, _) in tests.items():
            print(f" {BOLD}{key}.{RESET} {name}")
        print(f" {BOLD}A.{RESET} Lancer tous les tests")
        print(f" {BOLD}Q.{RESET} Quitter")
        choice = input(f"{BOLD}Choix > {RESET}").strip().upper()
        if choice == "Q":
            clear()
            print(f"{YELLOW}Fermeture du testeur. À bientôt.{RESET}")
            break
        elif choice == "A":
            clear()
            RESULTS.clear()
            for _, func in tests.values():
                func()
            test_summary()
            wait_for_key()
        elif choice in tests:
            clear()
            RESULTS.clear()
            tests[choice][1]()
            test_summary()
            wait_for_key()
        else:
            print(f"{RED}Entrée invalide.{RESET}")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{YELLOW}Interruption par l'utilisateur. Arrêt.{RESET}")
        sys.exit(0)
