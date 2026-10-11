#!/usr/bin/env python3
import sys
import json
import re
import urllib.request
import urllib.parse

def detect_pair(text, sl, tl):
    has_cyrillic = bool(re.search(r'[а-яА-ЯёЁ]', text))
    if sl == 'auto' or not sl:
        if has_cyrillic:
            sl = 'ru'
            tl = 'en'
        else:
            sl = 'en'
            tl = 'ru'
    return sl, tl

def translate(text, sl='auto', tl='ru'):
    if not text.strip():
        return ""
    sl, tl = detect_pair(text, sl, tl)
    pair = f"{sl}|{tl}"
    url = f"https://api.mymemory.translated.net/get?q={urllib.parse.quote(text)}&langpair={pair}"
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Linux; x86_64)'})
        with urllib.request.urlopen(req, timeout=8) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            if data and 'responseData' in data and data['responseData']['translatedText']:
                return data['responseData']['translatedText']
    except Exception:
        pass

    try:
        url_g = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl={sl}&tl={tl}&dt=t&q={urllib.parse.quote(text)}"
        req_g = urllib.request.Request(url_g, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req_g, timeout=8) as resp_g:
            data_g = json.loads(resp_g.read().decode('utf-8'))
            return "".join([part[0] for part in data_g[0] if part and part[0]])
    except Exception as e:
        return f"Ошибка перевода: {e}"

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("")
        sys.exit(0)
    text = sys.argv[1]
    sl = sys.argv[2] if len(sys.argv) > 2 else "auto"
    tl = sys.argv[3] if len(sys.argv) > 3 else "ru"
    print(translate(text, sl, tl))
