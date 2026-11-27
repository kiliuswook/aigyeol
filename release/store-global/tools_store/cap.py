"""스토어 스크린샷용 앱 화면 캡처(360x640 x3 = 1080x1920). usage: cap.py <lang> <locale> <out_dir> steps..."""
import sys, os
from playwright.sync_api import sync_playwright
lang, loc, out, *steps = sys.argv[1:]
state = open(f"state_{lang}.json", encoding="utf-8").read()
os.makedirs(out, exist_ok=True)
with sync_playwright() as pw:
    b = pw.chromium.launch()
    p = b.new_context(viewport={"width": 432, "height": 768}, device_scale_factor=2.5, locale=loc).new_page()
    p.goto("http://127.0.0.1:8767/"); p.wait_for_timeout(1500)
    p.evaluate("s => { localStorage.clear(); localStorage.setItem('flutter.childmbti', JSON.stringify(s)); }", state)
    p.goto("http://127.0.0.1:8767/?l=" + lang); p.wait_for_timeout(9000)
    n = 0
    for st in steps:
        if st == "k": p.screenshot(path=f"{out}/{n}.png"); n += 1; continue
        if st.startswith("w"): p.wait_for_timeout(int(st[1:])); continue
        x, y = map(int, st.split(",")); p.mouse.click(x, y); p.wait_for_timeout(2200)
    b.close()
