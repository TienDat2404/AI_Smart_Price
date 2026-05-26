"""Test dialect normalization — standalone, khong can FastAPI."""
import re, json, os

_EXTENDED = {}
json_path = os.path.join(os.path.dirname(__file__), "dialect_extended.json")
if os.path.exists(json_path):
    with open(json_path, encoding="utf-8") as f:
        data = json.load(f)
    _EXTENDED = data.get("all_dialect_map", {})
    print(f"Loaded {len(_EXTENDED)} entries from CentralVietnamDataset\n")

DIALECT_WORD_MAP = {
    "mfan": "an", "nhau": "an", "nac": "nuoc", "mo": "dau",
    "rang": "sao", "rua": "vay", "ni": "nay", "te": "kia",
    "chu": "gio", "tau": "toi", "mi": "ban", "eng": "anh",
    "no": "khong", "khong": "khong", "benh": "banh",
    "kiem": "mua", "chop": "mua", "dzo": "vao", "dze": "ve",
    "dzay": "vay", "hong": "khong", "tui": "toi", "xai": "dung",
    "ngan": "nghin", "honda om": "xe om",
    # Unicode versions
    "m\u1ea7n": "\u0103n",
    "n\u1ea1c": "n\u01b0\u1edbc",
    "m\u00f4": "\u0111\u00e2u",
    "r\u0103ng": "sao",
    "r\u1ee9a": "v\u1eady",
    "ch\u1eeb": "gi\u1edd",
    "n\u1ecf": "kh\u00f4ng",
    "kh\u00f2ng": "kh\u00f4ng",
    "b\u00e9nh": "b\u00e1nh",
    "ki\u1ebfm": "mua",
    "ch\u1ed9p": "mua",
    "dz\u00f4": "v\u00e0o",
    "dz\u1ec1": "v\u1ec1",
    "dz\u1eady": "v\u1eady",
    "h\u1ed5ng": "kh\u00f4ng",
    "x\u00e0i": "d\u00f9ng",
    "ng\u00e0n": "ngh\u00ecn",
    "honda \u00f4m": "xe \u00f4m",
}

# Regex patterns — thu tu: dai truoc, muoi+so truoc lam don le
DIALECT_NUMBER_PATTERNS = [
    # ham + so
    (r"\bh\u0103m\s*l\u0103m\b", "25"),
    (r"\bh\u0103m\s*m\u1ed1t\b", "21"),
    (r"\bh\u0103m\s*hai\b", "22"),
    (r"\bh\u0103m\s*ba\b", "23"),
    (r"\bh\u0103m\s*b\u1ed1n\b", "24"),
    (r"\bh\u0103m\s*s\u00e1u\b", "26"),
    (r"\bh\u0103m\s*b\u1ea3y\b", "27"),
    (r"\bh\u0103m\s*t\u00e1m\b", "28"),
    (r"\bh\u0103m\s*ch\u00edn\b", "29"),
    (r"\bh\u0103m\b", "20"),
    (r"\bnh\u0103m\b", "25"),
    # X chuc -> X0 nghin (ngam hieu la nghin dong)
    (r"\bn\u0103m\s*ch\u1ee5c\s*(?:ngh\u00ecn|ng\u00e0n|k)?\b", "50 ngh\u00ecn"),
    (r"\bb\u1ed1n\s*ch\u1ee5c\s*(?:ngh\u00ecn|ng\u00e0n|k)?\b", "40 ngh\u00ecn"),
    (r"\bba\s*ch\u1ee5c\s*(?:ngh\u00ecn|ng\u00e0n|k)?\b", "30 ngh\u00ecn"),
    (r"\bhai\s*ch\u1ee5c\s*(?:ngh\u00ecn|ng\u00e0n|k)?\b", "20 ngh\u00ecn"),
    (r"\bm\u1ed9t\s*ch\u1ee5c\s*(?:ngh\u00ecn|ng\u00e0n|k)?\b", "10 ngh\u00ecn"),
    (r"\bs\u00e1u\s*ch\u1ee5c\s*(?:ngh\u00ecn|ng\u00e0n|k)?\b", "60 ngh\u00ecn"),
    (r"\bb\u1ea3y\s*ch\u1ee5c\s*(?:ngh\u00ecn|ng\u00e0n|k)?\b", "70 ngh\u00ecn"),
    (r"\bt\u00e1m\s*ch\u1ee5c\s*(?:ngh\u00ecn|ng\u00e0n|k)?\b", "80 ngh\u00ecn"),
    (r"\bch\u00edn\s*ch\u1ee5c\s*(?:ngh\u00ecn|ng\u00e0n|k)?\b", "90 ngh\u00ecn"),
    # muoi + so — PHAI truoc lam don le
    (r"\bm\u01b0\u1eddi\s*l\u0103m\b", "15"),
    (r"\bm\u01b0\u1eddi\s*m\u1ed1t\b", "11"),
    (r"\bm\u01b0\u1eddi\s*hai\b", "12"),
    (r"\bm\u01b0\u1eddi\s*ba\b", "13"),
    (r"\bm\u01b0\u1eddi\s*b\u1ed1n\b", "14"),
    (r"\bm\u01b0\u1eddi\s*s\u00e1u\b", "16"),
    (r"\bm\u01b0\u1eddi\s*b\u1ea3y\b", "17"),
    (r"\bm\u01b0\u1eddi\s*t\u00e1m\b", "18"),
    (r"\bm\u01b0\u1eddi\s*ch\u00edn\b", "19"),
    # lam don le (sau khi da xu ly muoi lam, ham lam)
    (r"\bl\u0103m\b", "5"),
    (r"\bm\u1ed1t\b", "1"),
    # don vi tien
    (r"\bng\u00e0n\b", "ngh\u00ecn"),
]

CATEGORY_KEYWORDS = {
    "An uong":   ["\u0103n", "u\u1ed1ng", "ph\u1edf", "c\u01a1m", "b\u00fan",
                  "b\u00e1nh", "cafe", "tr\u00e0", "c\u00e0 ph\u00ea",
                  "m\u1ea7n", "t\u00f4", "ch\u00e9n", "nh\u1eadu", "l\u1ea9u"],
    "Di chuyen": ["grab", "xe", "x\u0103ng", "bus", "taxi", "xe \u00f4m",
                  "honda \u00f4m", "\u0111i xe", "\u0111\u1ed5 x\u0103ng"],
    "Mua sam":   ["shopee", "lazada", "qu\u1ea7n", "\u00e1o", "mua", "ch\u1ee3",
                  "ki\u1ebfm", "ch\u1ed9p", "mua \u0111\u1ed3", "\u0111\u1ed3"],
    "Suc khoe":  ["thu\u1ed1c", "b\u00e1c s\u0129", "kh\u00e1m", "gym"],
    "Hoa don":   ["\u0111i\u1ec7n", "n\u01b0\u1edbc", "internet"],
    "Thu nhap":  ["l\u01b0\u01a1ng", "th\u01b0\u1edfng", "freelance"],
}
# Map display names
CAT_DISPLAY = {
    "An uong": "\u0102n u\u1ed1ng",
    "Di chuyen": "Di chuy\u1ec3n",
    "Mua sam": "Mua s\u1eafm",
    "Suc khoe": "S\u1ee9c kh\u1ecfe",
    "Hoa don": "H\u00f3a \u0111\u01a1n",
    "Thu nhap": "Thu nh\u1eadp",
}


def normalize_dialect(text):
    result = text.lower().strip()
    for pat, rep in DIALECT_NUMBER_PATTERNS:
        result = re.sub(pat, rep, result, flags=re.IGNORECASE)
    for d, s in sorted(DIALECT_WORD_MAP.items(), key=lambda x: -len(x[0])):
        result = re.sub(r'\b' + re.escape(d) + r'\b', s, result, flags=re.IGNORECASE)
    if _EXTENDED:
        for d, s in sorted(_EXTENDED.items(), key=lambda x: -len(x[0])):
            if d in result:
                result = re.sub(r'\b' + re.escape(d) + r'\b', s, result, flags=re.IGNORECASE)
    return result


def extract_amount(text):
    m = re.search(r'(\d+(?:[.,]\d+)?)\s*k\b', text, re.IGNORECASE)
    if m: return float(m.group(1).replace(',', '.')) * 1000
    m = re.search(r'(\d+)\s*(?:ngh\u00ecn|ng\u00e0n|nghin)\b', text, re.IGNORECASE)
    if m: return float(m.group(1)) * 1000
    matches = re.findall(r'\b(\d{1,3}(?:[.,]\d{3})+)\b', text)
    if matches:
        amounts = []
        for raw in matches:
            try: amounts.append(float(raw.replace('.','').replace(',','')))
            except: pass
        if amounts: return max(amounts)
    m = re.search(r'\b(\d{4,})\b', text)
    if m: return float(m.group(1))
    return 0.0


def detect_category(text):
    lower = text.lower()
    for cat, kws in CATEGORY_KEYWORDS.items():
        for kw in kws:
            if kw in lower: return CAT_DISPLAY.get(cat, cat)
    return "Khac"


tests = [
    ("S\u00e1ng nay u\u1ed1ng c\u00e0 ph\u00ea h\u1ebft h\u0103m l\u0103m ng\u00e0n", 25000, "\u0102n u\u1ed1ng"),
    ("M\u1ea7n c\u00e1i b\u00e1nh m\u1ef3 m\u01b0\u1eddi l\u0103m ng\u00e0n",          15000, "\u0102n u\u1ed1ng"),
    ("\u0110i xe \u00f4m h\u1ebft hai ch\u1ee5c",                                        20000, "Di chuy\u1ec3n"),
    ("Tui x\u00e0i h\u1ebft n\u0103m ch\u1ee5c ng\u00e0n mua \u0111\u1ed3",             50000, "Mua s\u1eafm"),
    ("N\u1ecf th\u00edch nh\u01b0ng v\u1eabn m\u1ea7n t\u00f4 ph\u1edf h\u1ebft ba ch\u1ee5c", 30000, "\u0102n u\u1ed1ng"),
    ("H\u00f4m nay \u0103n ph\u1edf h\u1ebft 50k",                                       50000, "\u0102n u\u1ed1ng"),
    ("Grab v\u1ec1 nh\u00e0 35 ngh\u00ecn",                                               35000, "Di chuy\u1ec3n"),
    ("Mua \u00e1o h\u1ebft h\u0103m l\u0103m ng\u00e0n",                                 25000, "Mua s\u1eafm"),
]

passed = 0
print("=" * 65)
for text, exp_amount, exp_cat in tests:
    norm     = normalize_dialect(text)
    amount   = extract_amount(norm) or extract_amount(text)
    category = detect_category(text + " " + norm)
    ok_a = abs(amount - exp_amount) < 1000
    ok_c = category == exp_cat
    ok   = ok_a and ok_c
    if ok: passed += 1
    icon = "PASS" if ok else "FAIL"
    print(f"[{icon}] \"{text}\"")
    if norm.lower() != text.lower():
        print(f"       -> normalized: \"{norm}\"")
    print(f"       amount:   {amount:,.0f}d  (exp {exp_amount:,.0f}d) {'OK' if ok_a else 'WRONG'}")
    print(f"       category: {category}  (exp {exp_cat}) {'OK' if ok_c else 'WRONG'}")
    print()

print("=" * 65)
print(f"RESULT: {passed}/{len(tests)} passed")
