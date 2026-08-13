#!/usr/bin/env python3
"""表示コピー(見出し/ボタン/ラベル系キー)の句読点リンター＋廃止語彙の検出。
CLAUDE.mdの日本語ディスプレイコピー規則: 見出し・キャッチに句読点(、。)を使わない。
本文系キー(body/description/lead/legal等)は句読点チェックの対象外。
廃止語彙(docs/11 §19b)は本文も含む全キー・全言語を対象に検出する。"""
import json, sys, re

CATALOGS = [
    "ios/DopaBreak/Localizable.xcstrings",
    "ios/MonitorExtension/Localizable.xcstrings",
    "ios/WidgetsExtension/Localizable.xcstrings",
    "ios/ShieldConfigExtension/Localizable.xcstrings",
]
# 廃止済みのUI語彙(docs/11 §19b・2026-08-11追補)。1件でも残っていたら失敗させる。
# 「戻る先/戻れた」= 2026-07-25の全廃指示 / 「監視」= ユーザーに向けて使わない内部語。
BANNED = re.compile(r'戻る先|戻れた|監視')
# 本文扱い(句読点OK)のキー成分
BODY = re.compile(r'\.(body|description|lead|note|legal|disclaimer|message|detail|research|footer|hint|placeholder|fallback_body|accessibility_label|manual_fallback)(\.|$)|\.error\.|privacy_note|empty_selection_message')
# 表示コピー扱い(句読点NG)のキー成分
DISPLAY = re.compile(r'\.(title|tagline|action|eyebrow|label|cta|badge|option|metric|step\d)(\.|$)|\.action$|savings_badge')

def values(entry):
    """stringUnit も variations(plural/device) も辿って全言語の文字列を返す。"""
    found = []
    def walk(node):
        if isinstance(node, dict):
            if "value" in node and isinstance(node["value"], str):
                found.append(node["value"])
            for child in node.values():
                walk(child)
    walk(entry.get("localizations", {}))
    return found


banned = []
problems = []
for path in CATALOGS:
    d = json.load(open(path))["strings"]
    for k, v in sorted(d.items()):
        for value in values(v):
            if BANNED.search(value):
                banned.append((k, value, "+".join(sorted(set(BANNED.findall(value))))))
        if BODY.search(k) or not DISPLAY.search(k):
            continue
        ja = v.get("localizations", {}).get("ja", {}).get("stringUnit", {}).get("value", "")
        hits = []
        if "。" in ja: hits.append("句点")
        if ja.count("、") >= 2: hits.append(f"読点x{ja.count('、')}")
        elif "、" in ja and "\n" in ja and ja.split("\n")[0].endswith("、"):
            hits.append("1行目末尾読点(AI典型)")
        elif "、" in ja: hits.append("読点x1(意図的なら可)")
        if hits:
            problems.append((path.split("/")[-2], k, ja, "+".join(hits)))

if not problems:
    print("OK: 表示コピーに句読点違反なし")
else:
    print(f"{len(problems)}件の要確認:")
    for tgt, k, ja, why in problems:
        print(f"  [{why}] {k}\n      {ja!r}")

if banned:
    print(f"\n廃止語彙 {len(banned)}件（docs/11 §19b・必ず修正する）:")
    for k, value, why in banned:
        print(f"  [{why}] {k}\n      {value!r}")
else:
    print("OK: 廃止語彙(戻る先/戻れた/監視)の残存なし")

fatal = any('句点' in p[3] or 'x2' in p[3] or 'AI典型' in p[3] for p in problems) or bool(banned)
sys.exit(1 if fatal else 0)
