#!/usr/bin/env python3
"""
Antigravity Multi-Account & Quota Backend (agy_accounts_backend)
Shared logic for CLI and GTK4/Libadwaita GUI.
"""

import sys
import os
import time
import json
import base64
import subprocess
import datetime
from pathlib import Path

ACCOUNTS_DIR = Path.home() / ".gemini" / "antigravity-cli" / "accounts"
ACCOUNTS_INDEX = ACCOUNTS_DIR / "accounts.json"
BRAIN_DIR = Path.home() / ".gemini" / "antigravity-cli" / "brain"
LOG_DIR = Path.home() / ".gemini" / "antigravity-cli" / "log"
SERVICE_NAME = "gemini"
USERNAME = "antigravity"
SECRET_LABEL = "Password for 'antigravity' on 'gemini'"
DEFAULT_COOLDOWN_SECONDS = 1800 # 30 min cooldown when 429 occurs
ROTATION_MIN_COOLDOWN = 45      # 45s anti-burnout safety between rotations
POOL_TARGET_ACCOUNTS = 5

def ensure_accounts_dir():
    ACCOUNTS_DIR.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(ACCOUNTS_DIR, 0o700)
    except Exception:
        pass

def notify(title, message, urgency="normal"):
    try:
        subprocess.run(
            ["notify-send", "-a", "Google Antigravity", "-u", urgency, title, message],
            check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
    except Exception:
        pass

def get_keyring_secret():
    """Reads credentials JSON from GNOME Keyring via secret-tool with DBus fallback."""
    try:
        res = subprocess.run(
            ["secret-tool", "lookup", "service", SERVICE_NAME, "username", USERNAME],
            capture_output=True, text=True, check=False
        )
        if res.returncode == 0 and res.stdout.strip():
            return res.stdout.strip()
    except Exception:
        pass

    # DBus fallback
    try:
        import dbus
        bus = dbus.SessionBus()
        ss = bus.get_object('org.freedesktop.secrets', '/org/freedesktop/secrets')
        ss_iface = dbus.Interface(ss, 'org.freedesktop.Secret.Service')
        res = ss_iface.SearchItems({'service': SERVICE_NAME, 'username': USERNAME})
        unlocked, _ = res
        if unlocked:
            session = ss_iface.OpenSession('plain', '')[1]
            item = bus.get_object('org.freedesktop.secrets', unlocked[0])
            secret = item.GetSecret(session, dbus_interface='org.freedesktop.Secret.Item')
            return bytes(secret[2]).decode('utf-8')
    except Exception:
        pass

    return None

def set_keyring_secret(secret_json_str):
    """Writes credentials JSON into GNOME Keyring."""
    try:
        p = subprocess.Popen(
            ["secret-tool", "store", f"--label={SECRET_LABEL}", "service", SERVICE_NAME, "username", USERNAME],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        _, err = p.communicate(input=secret_json_str)
        if p.returncode == 0:
            return True
    except Exception:
        pass

    # DBus fallback
    try:
        import dbus
        bus = dbus.SessionBus()
        ss = bus.get_object('org.freedesktop.secrets', '/org/freedesktop/secrets')
        ss_iface = dbus.Interface(ss, 'org.freedesktop.Secret.Service')
        session = ss_iface.OpenSession('plain', '')[1]
        collection = bus.get_object('org.freedesktop.secrets', '/org/freedesktop/secrets/aliases/default')
        col_iface = dbus.Interface(collection, 'org.freedesktop.Secret.Collection')
        secret_bytes = secret_json_str.encode('utf-8')
        secret_struct = (session, dbus.Array([], signature='y'), dbus.ByteArray(secret_bytes), 'text/plain; charset=utf8')
        properties = {
            'org.freedesktop.Secret.Item.Label': SECRET_LABEL,
            'org.freedesktop.Secret.Item.Attributes': {'service': SERVICE_NAME, 'username': USERNAME}
        }
        col_iface.CreateItem(properties, secret_struct, True)
        return True
    except Exception as e:
        print(f"Error setting keyring secret: {e}", file=sys.stderr)
        return False

def clear_keyring_secret():
    """Removes credentials from GNOME Keyring."""
    try:
        subprocess.run(
            ["secret-tool", "clear", "service", SERVICE_NAME, "username", USERNAME],
            check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        return True
    except Exception:
        return False

def extract_email(secret_json):
    """Extracts email address from id_token or payload."""
    try:
        if isinstance(secret_json, str):
            secret_json = json.loads(secret_json)
        if secret_json.get("email"):
            return secret_json["email"]
        id_tok = secret_json.get("id_token", "")
        if id_tok and "." in id_tok:
            payload = id_tok.split(".")[1]
            payload += "=" * (-len(payload) % 4)
            try:
                info = json.loads(base64.urlsafe_b64decode(payload).decode("utf-8"))
            except Exception:
                info = json.loads(base64.b64decode(payload).decode("utf-8"))
            return info.get("email")
    except Exception:
        pass
    return None

def load_accounts_index():
    ensure_accounts_dir()
    default_structure = {
        "active": None,
        "auto_switch_enabled": True,
        "rotation_cooldown_seconds": ROTATION_MIN_COOLDOWN,
        "last_rotated_timestamp": 0,
        "circuit_breaker_active": False,
        "global_last_total_tokens": 0,
        "accounts": []
    }
    if not ACCOUNTS_INDEX.exists():
        return default_structure
    try:
        with open(ACCOUNTS_INDEX, "r", encoding="utf-8") as f:
            data = json.load(f)
            # Ensure defaults
            for k, v in default_structure.items():
                if k not in data:
                    data[k] = v
            return data
    except Exception:
        return default_structure

def save_accounts_index(data):
    ensure_accounts_dir()
    with open(ACCOUNTS_INDEX, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    try:
        os.chmod(ACCOUNTS_INDEX, 0o600)
    except Exception:
        pass

WINDOW_CONFIGS = [
    ("5h", "5 часов (Сессия)", 5 * 3600),
    ("24h", "24 часа (День)", 24 * 3600),
    ("7d", "7 дней (Неделя)", 7 * 86400),
    ("30d", "30 дней (Месяц)", 30 * 86400),
]

def format_duration(seconds):
    """Formats duration in seconds to human readable string (e.g. 45с, 12м, 1ч 59м, 6д 20ч)."""
    if seconds <= 0:
        return "сейчас"
    days = seconds // 86400
    rem = seconds % 86400
    hours = rem // 3600
    rem = rem % 3600
    minutes = rem // 60
    secs = rem % 60
    if days > 0:
        return f"{days}д {hours}ч"
    elif hours > 0:
        return f"{hours}ч {minutes}м"
    elif minutes > 0:
        return f"{minutes}м {secs}с"
    else:
        return f"{secs}с"

def scan_all_transcripts():
    """
    Calculates cumulative and window token metrics across all conversation transcripts:
    5h (session), 24h (day), 7d (week), 30d (month), and all-time.
    """
    now_ts = time.time()
    totals = {
        "input": 0,
        "output": 0,
        "cache": 0,
        "total": 0,
        "today": 0,
        "last_hour": 0,
        "windows": {}
    }

    for key, label, secs in WINDOW_CONFIGS:
        totals["windows"][key] = {
            "key": key,
            "label": label,
            "seconds": secs,
            "total": 0,
            "input": 0,
            "output": 0,
            "cache": 0,
            "earliest_ts": None,
            "latest_ts": None,
            "next_reset_secs": 0,
            "next_reset_str": "—"
        }

    if not BRAIN_DIR.exists():
        return totals

    for root, _, files in os.walk(BRAIN_DIR):
        if "transcript.jsonl" in files:
            fp = os.path.join(root, "transcript.jsonl")
            try:
                with open(fp, "r", encoding="utf-8") as f:
                    for line in f:
                        try:
                            s = json.loads(line)
                            inp = s.get("input_tokens", 0)
                            out = s.get("output_tokens", 0)
                            cch = s.get("cache_read_tokens", 0)
                            tot = inp + out + cch

                            totals["input"] += inp
                            totals["output"] += out
                            totals["cache"] += cch
                            totals["total"] += tot

                            created = s.get("created_at")
                            if created:
                                dt = datetime.datetime.fromisoformat(created.replace("Z", "+00:00")).timestamp()
                                age = now_ts - dt
                                if age <= 86400:
                                    totals["today"] += tot
                                if age <= 3600:
                                    totals["last_hour"] += tot

                                for key, label, secs in WINDOW_CONFIGS:
                                    if age <= secs:
                                        w = totals["windows"][key]
                                        w["total"] += tot
                                        w["input"] += inp
                                        w["output"] += out
                                        w["cache"] += cch
                                        if w["earliest_ts"] is None or dt < w["earliest_ts"]:
                                            w["earliest_ts"] = dt
                                        if w["latest_ts"] is None or dt > w["latest_ts"]:
                                            w["latest_ts"] = dt
                        except Exception:
                            pass
            except Exception:
                pass

    for key, label, secs in WINDOW_CONFIGS:
        w = totals["windows"][key]
        if w["earliest_ts"]:
            rem = max(0, int((w["earliest_ts"] + secs) - now_ts))
            w["next_reset_secs"] = rem
            w["next_reset_str"] = format_duration(rem)
        else:
            w["next_reset_str"] = "квота свободна"

    return totals

def sync_tokens_and_active_account():
    """
    Syncs live tokens from transcripts, credits newly spent tokens to active account,
    records window metrics, and updates refresh token from GNOME Keyring.
    """
    index = load_accounts_index()
    active_email = index.get("active")
    accounts = index.get("accounts", [])

    # 1. Check keyring secret to keep stored token fresh
    sec = get_keyring_secret()
    if sec:
        em = extract_email(sec)
        if em:
            if not active_email or active_email != em:
                index["active"] = em
                active_email = em
            file_path = ACCOUNTS_DIR / f"{em}.json"
            try:
                with open(file_path, "w", encoding="utf-8") as f:
                    f.write(sec)
                os.chmod(file_path, 0o600)
            except Exception:
                pass

    # 2. Token Accounting
    current_metrics = scan_all_transcripts()
    current_total = current_metrics["total"]
    last_total = index.get("global_last_total_tokens", 0)
    delta_total = max(0, current_total - last_total)
    index["global_last_total_tokens"] = current_total

    # Find active account
    active_acc = next((a for a in accounts if a["email"] == active_email), None)
    if active_acc:
        active_acc["last_used"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        t = active_acc.setdefault("tokens", {
            "input": 0, "output": 0, "cache": 0, "total": 0, "today": 0
        })

        # Track per-account windows
        win_data = {}
        for k, w_obj in current_metrics["windows"].items():
            win_data[k] = {
                "total": w_obj["total"],
                "input": w_obj["input"],
                "output": w_obj["output"],
                "cache": w_obj["cache"],
                "next_reset_secs": w_obj["next_reset_secs"],
                "next_reset_str": w_obj["next_reset_str"]
            }
        active_acc["windows"] = win_data

        if last_total == 0:
            # First initialization: initialize with current stats
            t["input"] = current_metrics["input"]
            t["output"] = current_metrics["output"]
            t["cache"] = current_metrics["cache"]
            t["total"] = current_metrics["total"]
            t["today"] = current_metrics["today"]
        else:
            # Incremental update
            t["total"] += delta_total
            t["input"] += delta_total
            t["today"] = current_metrics["today"]

    save_accounts_index(index)
    return index

def is_account_ready(acc):
    """
    Checks if account is authenticated and ready to take over queries.
    Returns (ready: bool, status_badge: str, status_desc: str, remaining_seconds: int)
    """
    now_ts = time.time()
    email = acc.get("email")
    cred_file = ACCOUNTS_DIR / f"{email}.json"
    if not cred_file.exists():
        return False, "НЕ НАСТРОЕН", "Файл авторизации отсутствует", 0

    cooldown_until = acc.get("cooldown_until", 0)
    if cooldown_until > now_ts:
        rem = int(cooldown_until - now_ts)
        mins = rem // 60
        secs = rem % 60
        timer_str = f"{mins:02d}:{secs:02d}"
        reason = acc.get("cooldown_reason") or "Лимит токенов"
        return False, "КУЛДАУН", f"Сброс квоты через {timer_str} ({reason})", rem

    return True, "ГОТОВ", "Квота свободна, готов к работе", 0

def format_tokens(n):
    """Formats large token numbers nicely (e.g. 102.5M, 450K, 1,234)."""
    if n >= 1_000_000_000:
        return f"{n / 1_000_000_000:.2f}B"
    elif n >= 1_000_000:
        return f"{n / 1_000_000:.2f}M"
    elif n >= 1_000:
        return f"{n / 1_000:.1f}K"
    return f"{n:,}"

def save_account_credentials(email, secret_json_str, alias=None):
    ensure_accounts_dir()
    file_path = ACCOUNTS_DIR / f"{email}.json"
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(secret_json_str)
    try:
        os.chmod(file_path, 0o600)
    except Exception:
        pass

    index = load_accounts_index()
    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
    existing = next((acc for acc in index.get("accounts", []) if acc["email"] == email), None)

    if existing:
        existing["last_updated"] = now_iso
        existing["cooldown_until"] = 0
        existing["cooldown_reason"] = None
        if alias:
            existing["alias"] = alias
    else:
        index["accounts"].append({
            "email": email,
            "alias": alias or email.split("@")[0],
            "file": f"{email}.json",
            "added_at": now_iso,
            "last_used": now_iso,
            "last_updated": now_iso,
            "cooldown_until": 0,
            "cooldown_reason": None,
            "tokens": {
                "input": 0, "output": 0, "cache": 0, "total": 0, "today": 0
            }
        })

    index["active"] = email
    save_accounts_index(index)
    return file_path

def switch_to_account(target_email_or_alias, continue_session=False, force=False):
    """
    Switches active Antigravity account in GNOME Keyring.
    Protected by anti-burnout cooldown.
    """
    sync_tokens_and_active_account()
    index = load_accounts_index()
    accounts = index.get("accounts", [])

    if not accounts:
        return False, "В пуле нет сохранённых аккаунтов"

    target_clean = target_email_or_alias.strip().lower()
    matched = None
    ordinal_map = {
        "1": 0, "первый": 0, "main": 0,
        "2": 1, "второй": 1,
        "3": 2, "третий": 2,
        "4": 3, "четвертый": 3, "четвёртый": 3,
        "5": 4, "пятый": 4
    }
    if target_clean in ordinal_map and ordinal_map[target_clean] < len(accounts):
        matched = accounts[ordinal_map[target_clean]]

    if not matched:
        for a in accounts:
            if a["email"].lower() == target_clean or a.get("alias", "").lower() == target_clean:
                matched = a
                break
    if not matched:
        for a in accounts:
            if target_clean in a["email"].lower():
                matched = a
                break

    if not matched:
        return False, f"Аккаунт '{target_email_or_alias}' не найден в пуле"

    # Cooldown check
    now_ts = time.time()
    last_rot = index.get("last_rotated_timestamp", 0)
    cooldown = index.get("rotation_cooldown_seconds", ROTATION_MIN_COOLDOWN)
    if not force and (now_ts - last_rot) < cooldown:
        rem = int(cooldown - (now_ts - last_rot))
        return False, f"Защита от бана: подождите {rem}с перед следующим переключением (или --force)"

    file_path = ACCOUNTS_DIR / f"{matched['email']}.json"
    if not file_path.exists():
        return False, f"Файл ключей для {matched['email']} не найден"

    try:
        with open(file_path, "r", encoding="utf-8") as f:
            secret_str = f.read()
    except Exception as e:
        return False, f"Ошибка чтения ключа: {e}"

    if set_keyring_secret(secret_str):
        index["active"] = matched["email"]
        index["last_rotated_timestamp"] = now_ts
        index["circuit_breaker_active"] = False
        matched["last_used"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        save_accounts_index(index)
        alias_info = f" ({matched.get('alias')})" if matched.get('alias') else ""
        notify("Аккаунт переключен", f"Активен: {matched['email']}{alias_info}")
        return True, f"Успешно переключено на {matched['email']}{alias_info}"
    else:
        return False, "Не удалось сохранить ключ в GNOME Keyring"

def mark_account_cooldown(email, duration_seconds=DEFAULT_COOLDOWN_SECONDS, reason="Лимит токенов (429)"):
    """Marks an account into rate-limit cooldown to prevent reuse until quota resets."""
    index = load_accounts_index()
    acc = next((a for a in index.get("accounts", []) if a["email"] == email), None)
    if acc:
        acc["cooldown_until"] = time.time() + duration_seconds
        acc["cooldown_reason"] = reason
        save_accounts_index(index)
        mins = duration_seconds // 60
        notify("Лимит токенов Antigravity", f"{email}: кулдаун на {mins} мин ({reason})", urgency="critical")
        return True
    return False

def reset_account_cooldown(email):
    """Manually clears cooldown on an account."""
    index = load_accounts_index()
    acc = next((a for a in index.get("accounts", []) if a["email"] == email), None)
    if acc:
        acc["cooldown_until"] = 0
        acc["cooldown_reason"] = None
        save_accounts_index(index)
        notify("Сброс кулдауна", f"Квота для {email} помечена как доступная")
        return True
    return False

def rotate_to_next_ready(force=False):
    """
    Selects the next READY account and switches to it.
    Equipped with circuit breaker: halts if all accounts are cooling down.
    """
    sync_tokens_and_active_account()
    index = load_accounts_index()
    accounts = index.get("accounts", [])

    if len(accounts) < 2:
        return False, "В пуле недостаточно аккаунтов для ротации (нужно минимум 2)"

    now_ts = time.time()
    last_rot = index.get("last_rotated_timestamp", 0)
    cooldown = index.get("rotation_cooldown_seconds", ROTATION_MIN_COOLDOWN)
    if not force and (now_ts - last_rot) < cooldown:
        rem = int(cooldown - (now_ts - last_rot))
        return False, f"Защита от быстрого сжигания: подождите {rem}с (или --force)"

    active_email = index.get("active")
    curr_idx = -1
    for i, a in enumerate(accounts):
        if a["email"] == active_email:
            curr_idx = i
            break

    # Search for next ready account in round-robin order
    ready_account = None
    for offset in range(1, len(accounts) + 1):
        cand_idx = (curr_idx + offset) % len(accounts)
        cand = accounts[cand_idx]
        ready, _, _, _ = is_account_ready(cand)
        if ready and cand["email"] != active_email:
            ready_account = cand
            break

    if not ready_account:
        # CIRCUIT BREAKER TRIGGERED!
        index["circuit_breaker_active"] = True
        save_accounts_index(index)
        msg = "Все аккаунты исчерпали квоту токенов! Ротация остановлена для предотвращения 126ч бана."
        notify("⚠️ Внимание: Все аккаунты на кулдауне", msg, urgency="critical")
        return False, msg

    return switch_to_account(ready_account["email"], force=force)

def check_recent_log_for_rate_limit():
    """
    Checks if a recent 429/quota error was logged.
    Returns (hit_limit: bool, reason: str)
    """
    try:
        if not LOG_DIR.exists():
            return False, ""
        log_files = sorted(LOG_DIR.glob("cli-*.log"), key=os.path.getmtime, reverse=True)
        if not log_files:
            return False, ""
        latest_log = log_files[0]
        # Check last 50 lines
        with open(latest_log, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()[-60:]
        text = "".join(lines).lower()
        if "resource_exhausted" in text or "quota exceeded" in text or "status: 429" in text or "rate limit" in text:
            return True, "Лимит токенов (429 / Quota Exceeded)"
    except Exception:
        pass
    return False, ""

def remove_account(email_or_alias):
    index = load_accounts_index()
    accounts = index.get("accounts", [])
    target = email_or_alias.strip().lower()

    matched = None
    for a in accounts:
        if a["email"].lower() == target or a.get("alias", "").lower() == target:
            matched = a
            break

    if not matched:
        return False, f"Аккаунт '{email_or_alias}' не найден"

    if len(accounts) <= 1:
        return False, "Нельзя удалить единственный оставшийся аккаунт в пуле"

    accounts.remove(matched)
    file_path = ACCOUNTS_DIR / f"{matched['email']}.json"
    if file_path.exists():
        try:
            file_path.unlink()
        except Exception:
            pass

    if index.get("active") == matched["email"]:
        # Fall back to first available account
        first_acc = accounts[0]
        index["active"] = first_acc["email"]
        fp = ACCOUNTS_DIR / f"{first_acc['email']}.json"
        if fp.exists():
            with open(fp, "r", encoding="utf-8") as f:
                set_keyring_secret(f.read())

    save_accounts_index(index)
    return True, f"Аккаунт {matched['email']} успешно удалён из пула"

def handle_session_exit(exit_code=0):
    """
    Called upon CLI session completion: syncs tokens, inspects exit status/logs
    for 429 quota exhaustion, and safely triggers auto-switch if enabled.
    """
    sync_tokens_and_active_account()
    hit, reason = check_recent_log_for_rate_limit()
    if hit or exit_code == 429:
        index = load_accounts_index()
        curr = index.get("active")
        if curr:
            mark_account_cooldown(curr, reason=reason or "Лимит токенов (429)")
        if index.get("auto_switch_enabled", True):
            success, msg = rotate_to_next_ready()
            if success:
                notify("Автопереключение аккаунта", f"Лимит токенов на {curr} исчерпан. {msg}")
            else:
                notify("Все аккаунты на кулдауне", msg, urgency="critical")

QUOTA_CACHE_FILE = ACCOUNTS_DIR / "live_quota.json"
_quota_refresh_in_progress = False

def fetch_live_google_quota(force=False, sync=False):
    """
    Retrieves live official quota from Google Antigravity servers via `agy.bin --print=/usage`.
    Caches results for 25 seconds. If background refresh is needed, spawns a thread so UI never freezes.
    """
    global _quota_refresh_in_progress
    now_ts = time.time()
    cached = None
    if QUOTA_CACHE_FILE.exists():
        try:
            with open(QUOTA_CACHE_FILE, "r", encoding="utf-8") as f:
                cached = json.load(f)
        except Exception:
            pass

    if cached:
        if "antigravity" not in cached and "models" in cached:
            cached["antigravity"] = cached["models"].get("Gemini Models", {})
        if not force and (now_ts - cached.get("updated_at", 0) < 25):
            return cached

    def _do_fetch():
        global _quota_refresh_in_progress
        try:
            real_agy = Path.home() / ".local" / "bin" / "agy.bin"
            if not real_agy.exists():
                real_agy = Path.home() / ".local" / "bin" / "agy"
            res = subprocess.run([str(real_agy), "--print=/usage"], capture_output=True, text=True, timeout=8)
            lines = res.stdout.strip().split("\n")
            data = {"models": {}, "updated_at": time.time()}
            for line in lines:
                parts = [p.strip() for p in line.split("\t") if p.strip()]
                if len(parts) >= 4:
                    m_name, l_name, rem_pct_str, reset_iso = parts[0], parts[1], parts[2], parts[3]
                    rem_pct = int(rem_pct_str.replace("%", ""))
                    used_pct = 100 - rem_pct
                    rem_secs = 0
                    rem_str = "—"
                    try:
                        dt = datetime.datetime.fromisoformat(reset_iso.replace("Z", "+00:00")).timestamp()
                        rem_secs = max(0, int(dt - time.time()))
                        hours = rem_secs // 3600
                        mins = (rem_secs % 3600) // 60
                        days = rem_secs // 86400
                        if days > 0:
                            rem_str = f"{days}д {hours % 24}ч"
                        elif hours > 0:
                            rem_str = f"{hours}ч {mins}м"
                        else:
                            rem_str = f"{mins}м"
                    except Exception:
                        pass

                    data["models"].setdefault(m_name, {})[l_name] = {
                        "remaining_pct": rem_pct,
                        "used_pct": used_pct,
                        "reset_iso": reset_iso,
                        "reset_secs": rem_secs,
                        "reset_str": rem_str
                    }
            if data["models"]:
                data["antigravity"] = data["models"].get("Gemini Models", {})
                with open(QUOTA_CACHE_FILE, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)
            return data
        except Exception:
            return None
        finally:
            _quota_refresh_in_progress = False

    if sync or not cached:
        res = _do_fetch()
        return res or cached or {"models": {}, "updated_at": now_ts}

    if not _quota_refresh_in_progress:
        _quota_refresh_in_progress = True
        import threading
        t = threading.Thread(target=_do_fetch, daemon=True)
        t.start()

    return cached or {"models": {}, "updated_at": now_ts}
