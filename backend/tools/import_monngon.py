#!/usr/bin/env python3
"""
=============================================================================
CHUYỂN DỮ LIỆU MÓN VIỆT (Món Ngon Mỗi Ngày) → SEED CỦA BACKEND RUST
=============================================================================

ĐẦU VÀO
  `crawled_vietnamese_recipes_3000.json` do `crawl_vietnamese_recipes.py` của
  project cũ (Food_tip_system) cào từ monngonmoingay.com. Mỗi món có:
  shortName, fullTitle, ingredientsStr ("A: 100g | B 2 củ | ..."),
  stepsStr ("Sơ Chế: ... | Thực hiện: ... | Cách dùng: ... | Mách nhỏ: ..."),
  imageUrl, sourceUrl.

ĐẦU RA
  `backend/assets/vietnamese_recipes.json`, cùng dạng với `spoonacular.json`:
  {id, title, image, source, sourceUrl, category, time, servings, nutrients,
   steps, ingredients:[{name, amount, unit}]}

FLOW
  1. Lọc món đủ dữ liệu: nguyên liệu > 60 ký tự (bỏ 648 món chỉ ghi
     "Nguyên liệu tươi ngon theo mùa") và các bước > 150 ký tự.
  2. Bỏ trùng tên (không phân biệt hoa thường), ưu tiên bản có ảnh.
  3. Sắp theo sourceUrl rồi cấp id = 1_000_000 + thứ tự → id ổn định giữa
     các lần chạy, không đụng id Spoonacular (< 1 triệu).
  4. Tách nguyên liệu: "Tên: 150g" / "Tên 150 g" / "Tên" → {name, amount, unit};
     M → "muỗng canh", m → "muỗng cà phê" (quy ước của trang nguồn).
  5. Mỗi phần "Sơ chế / Thực hiện / Cách dùng / Mách nhỏ" là một bước.
  6. Xếp danh mục theo từ khoá trong tên món (xem CATEGORY_RULES).

KHÔNG BỊA DỮ LIỆU
  Trang nguồn không có thời gian nấu, khẩu phần, dinh dưỡng → để `null` / `{}`.
  Backend lưu 0 và app hiển thị "—".

CÁCH CHẠY
  python tools/import_monngon.py <đường-dẫn>/crawled_vietnamese_recipes_3000.json
=============================================================================
"""

import html
import json
import re
import sys
import unicodedata
from pathlib import Path

ID_BASE = 1_000_000
SOURCE = "Món Ngon Mỗi Ngày"

# Thứ tự quan trọng: luật đầu tiên khớp sẽ được dùng ("bánh canh" là món sợi,
# không phải canh; "chè" trước "bánh" để "chè bánh lọt" vào Chè).
CATEGORY_RULES = [
    ("Đồ uống", ["sinh tố", "nước ép", "trà ", "trà sữa", "cà phê", "nước chanh", "smoothie", "soda", "đá me", "sữa chua uống"]),
    ("Chè & Tráng miệng", ["chè", "rau câu", "thạch", "flan", "kem ", "pudding", "tào phớ", "sữa chua"]),
    ("Bún, Phở & Mì", ["bún", "phở", "mì", "miến", "hủ tiếu", "hủ tíu", "bánh canh", "bánh đa cua", "nui", "spaghetti", "mỳ"]),
    ("Lẩu", ["lẩu"]),
    ("Cháo & Súp", ["cháo", "súp", "soup"]),
    ("Canh", ["canh"]),
    ("Cơm & Xôi", ["cơm", "xôi"]),
    ("Gỏi & Salad", ["gỏi", "nộm", "salad", "trộn"]),
    ("Bánh", ["bánh"]),
    ("Món cuốn", ["cuốn", "cuộn"]),
    ("Món kho", ["kho", "rim", "om ", "khìa"]),
    ("Món chiên", ["chiên", "rán", "giòn"]),
    ("Món nướng", ["nướng", "quay"]),
    ("Món xào", ["xào", "áp chảo"]),
    ("Hấp & Luộc", ["hấp", "luộc", "hầm"]),
    ("Món sốt & Om", ["sốt", "xốt", "tiềm", "nấu", "vang", "nhúng", "ngâm", "chao"]),
]
DEFAULT_CATEGORY = "Món khác"

UNIT_ALIASES = {"M": "muỗng canh", "m": "muỗng cà phê"}
FRACTIONS = {"½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1 / 3, "⅔": 2 / 3}
NUMBER = r"(?:\d+\s*/\s*\d+|\d+(?:[.,]\d+)?|[½¼¾⅓⅔])"
# "Tên: 150g", "Tên : 2M", "Tên 200g", "Tên 1 quả"
INGREDIENT_RE = re.compile(rf"^(?P<name>.+?)\s*:?\s+(?P<amount>{NUMBER})\s*(?P<unit>[^\d\s][^|]*)?$")
INGREDIENT_COLON_RE = re.compile(rf"^(?P<name>.+?)\s*:\s*(?P<amount>{NUMBER})\s*(?P<unit>[^|]*)$")


def clean(text: str) -> str:
    text = html.unescape(text)  # "&#8211;" → "–", "&amp;" → "&"
    text = unicodedata.normalize("NFC", text)
    text = text.replace("\xa0", " ").replace("​", "")
    return re.sub(r"\s+", " ", text).strip(" .;,")


def parse_amount(raw: str) -> float:
    raw = raw.replace(" ", "")
    if raw in FRACTIONS:
        return FRACTIONS[raw]
    if "/" in raw:
        a, b = raw.split("/")
        return float(a) / float(b) if float(b) else 0.0
    return float(raw.replace(",", "."))


def parse_ingredient(item: str) -> dict:
    item = clean(item)
    m = INGREDIENT_COLON_RE.match(item) or INGREDIENT_RE.match(item)
    if m:
        unit = clean(m.group("unit") or "")
        unit = UNIT_ALIASES.get(unit, unit)
        return {"name": clean(m.group("name")).rstrip(":").strip(), "amount": round(parse_amount(m.group("amount")), 3), "unit": unit}
    return {"name": item.rstrip(":").strip(), "amount": 0, "unit": ""}


def parse_steps(steps_str: str) -> list[str]:
    steps = []
    for part in steps_str.split("|"):
        part = clean(part)
        m = re.match(r"^([^:]{2,20}):\s*(.+)$", part)
        if m:
            head = m.group(1).strip().capitalize()
            part = f"{head}: {m.group(2).strip()}"
        if len(part) > 3:
            steps.append(part)
    return steps


def categorize(title: str) -> str:
    """Ưu tiên từ khoá ở ĐẦU tên món ("Bánh Áp Chảo Mì Gói" → Bánh, không phải Mì),
    sau đó mới xét từ khoá nằm giữa tên ("Ba Rọi Kho Gừng" → Món kho)."""
    t = f" {title.lower()} "
    for category, keywords in CATEGORY_RULES:
        if any(t.startswith(f" {k.strip()} ") for k in keywords):
            return category
    for category, keywords in CATEGORY_RULES:
        if any(k in t for k in keywords):
            return category
    return DEFAULT_CATEGORY


def convert(rows: list[dict]) -> list[dict]:
    good = [r for r in rows if len(r.get("ingredientsStr", "")) > 60 and len(r.get("stepsStr", "")) > 150]

    by_title: dict[str, dict] = {}
    for r in sorted(good, key=lambda r: (not r.get("imageUrl"), r["sourceUrl"])):
        by_title.setdefault(clean(r["shortName"]).casefold(), r)

    out = []
    for index, r in enumerate(sorted(by_title.values(), key=lambda r: r["sourceUrl"])):
        title = clean(r["shortName"])
        ingredients = [parse_ingredient(x) for x in r["ingredientsStr"].split("|") if clean(x)]
        out.append({
            "id": ID_BASE + index,
            "title": title,
            "image": r.get("imageUrl") or None,
            "source": SOURCE,
            "sourceUrl": r["sourceUrl"],
            "category": categorize(title),
            "time": None,
            "servings": None,
            "nutrients": {},
            "steps": parse_steps(r["stepsStr"]),
            "ingredients": [i for i in ingredients if i["name"]],
        })
    return out


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    rows = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    recipes = convert(rows)
    target = Path(__file__).resolve().parent.parent / "assets" / "vietnamese_recipes.json"
    target.write_text(json.dumps(recipes, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    from collections import Counter
    with_amount = sum(1 for r in recipes for i in r["ingredients"] if i["amount"])
    total_ing = sum(len(r["ingredients"]) for r in recipes)
    print(f"Đã ghi {len(recipes)} món → {target}")
    print(f"Nguyên liệu: {total_ing} (có định lượng: {with_amount})")
    print("Danh mục:", Counter(r["category"] for r in recipes).most_common())


if __name__ == "__main__":
    main()
