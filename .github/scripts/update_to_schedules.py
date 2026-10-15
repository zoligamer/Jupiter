import json
import os
import requests
from bs4 import BeautifulSoup

JSON_PATH = "universities_with_to_schedule.json"

def check_and_update_urls():
    if not os.path.exists(JSON_PATH):
        print(f"Error: {JSON_PATH} not found.")
        return

    with open(JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    institutes = data.get("Institutes", [])
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }

    print(f"Verifying {len(institutes)} institutes...")

    for inst in institutes:
        name = inst.get("Name")
        
        # Ha kari bontás van:
        if "Faculties" in inst:
            for fac in inst["Faculties"]:
                to_url = fac.get("ToUrl")
                if to_url:
                    try:
                        res = requests.get(to_url, headers=headers, timeout=8, allow_redirects=True)
                        if res.status_code == 200 and res.url != to_url:
                            print(f"[{name} - {fac.get('FacultyName')}] URL redirect frissítve: {res.url}")
                            fac["ToUrl"] = res.url
                    except Exception as e:
                        print(f"[{name}] Hiba az ellenőrzéskor ({to_url}): {e}")
        else:
            # Központi TO esetén:
            to_url = inst.get("ToUrl")
            if to_url:
                try:
                    res = requests.get(to_url, headers=headers, timeout=8, allow_redirects=True)
                    if res.status_code == 200 and res.url != to_url:
                        print(f"[{name}] URL redirect frissítve: {res.url}")
                        inst["ToUrl"] = res.url
                except Exception as e:
                    print(f"[{name}] Hiba az ellenőrzéskor ({to_url}): {e}")

    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=3)

    print("Ellenőrzés befejezve, JSON frissítve.")

if __name__ == "__main__":
    check_and_update_urls()
