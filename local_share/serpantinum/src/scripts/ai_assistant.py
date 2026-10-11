#!/usr/bin/env python3
import sys
import subprocess
import shutil

def query_ai(prompt):
    if not prompt.strip():
        return "Пожалуйста, введите вопрос."
    
    # Try gemini CLI if configured
    gemini_bin = shutil.which("gemini")
    if gemini_bin:
        try:
            res = subprocess.run([gemini_bin, "-p", prompt], capture_output=True, text=True, timeout=12)
            if res.returncode == 0 and res.stdout.strip():
                return res.stdout.strip()
        except Exception:
            pass

    # Quick local system helper responses
    p = prompt.lower()
    if any(w in p for w in ["привет", "hello", "hi", "здаров"]):
        return "Привет! Готов помочь с командами, заметками, кодом или любыми вопросами по системе."
    elif any(w in p for w in ["память", "ram", "озу"]):
        try:
            out = subprocess.check_output(["free", "-h"], text=True)
            return f"Статистика памяти:\n```\n{out.strip()}\n```"
        except Exception:
            pass
    elif any(w in p for w in ["диск", "место", "память на диске"]):
        try:
            out = subprocess.check_output(["df", "-h", "/"], text=True)
            return f"Место на основном диске:\n```\n{out.strip()}\n```"
        except Exception:
            pass
    elif any(w in p for w in ["батарея", "заряд"]):
        try:
            out = subprocess.check_output(["cat", "/sys/class/power_supply/BAT0/capacity"], text=True)
            return f"Текущий уровень заряда батареи: {out.strip()}%"
        except Exception:
            pass
    elif any(w in p for w in ["кто ты", "что ты умеешь"]):
        return "Я встроенный смарт-ассистент в боковой панели Hyprland / Serpantinum. Могу переводить тексты, запускать утилиты, проверять ресурсы системы и помогать в работе!"

    return f"Запрос принят: «{prompt}». Чтобы подключить Gemini API или локальную LLM на постоянной основе, укажи ключ в окружении или используй локальный ollama."

if __name__ == '__main__':
    if len(sys.argv) > 1:
        print(query_ai(" ".join(sys.argv[1:])))
    else:
        print("")
