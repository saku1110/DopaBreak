#!/usr/bin/env bash
#
# asc-setup-dopabreak.sh
# DopaBreak の App Store Connect 課金カタログを公開API(asc CLI)で一括構築する。
#
# 前提（このスクリプトが動く条件）:
#   1. asc CLI が公開APIキーで認証済み（`asc apps list` が通ること）
#   2. DopaBreak のアプリレコードが既に存在し、その APP_ID が判明していること
#      （アプリレコード作成は web セッション必須＝別手順。本スクリプトの対象外）
#   3. 「有料App契約（Paid Apps Agreement）」が Active であること
#      （未締結だとサブスク/IAP作成がAppleに拒否される。銀行・税務情報の入力は人間のみ）
#
# 使い方:
#   ASC_APP_ID=xxxxxxxxxx ./scripts/asc-setup-dopabreak.sh
#     または
#   ./scripts/asc-setup-dopabreak.sh <APP_ID>
#
# 価格の正本: docs/15_pricing_design.md（2026-07-24: 3市場同時ローンチ）
#   JP価格を基準に作成 → KR(₩)・US($)を territory 上書きで明示設定。
#   地域差原則: 月額のみUS=1.5倍・KR/JP=同水準。年額はほぼ据え置き。
#
set -euo pipefail

# ---- 設定（docs/15 §3.4・storekit と一致）---------------------------------
APP_ID="${1:-${ASC_APP_ID:-}}"
BASE_TERRITORY="Japan"                  # 価格の基準テリトリー
SALE_TERRITORIES="Japan,Korea,USA"      # 3市場同時ローンチ
GROUP_REF="DopaBreak Pro"               # サブスクグループ参照名（社内管理用）
GROUP_DISPLAY="DopaBreak Pro"           # グループ表示名（顧客に見える）
LOCALE="ja-JP"

# 商品ID（storekit と完全一致・変更禁止）
PID_MONTHLY="dopabreak.pro.monthly"
PID_ANNUAL="dopabreak.pro.annual"
PID_ANNUAL_LAUNCH="dopabreak.pro.annual.launch"
PID_LIFETIME="dopabreak.pro.lifetime"

# JP価格（基準）
PRICE_MONTHLY="980"
PRICE_ANNUAL="4980"
PRICE_ANNUAL_LAUNCH="3980"
PRICE_LIFETIME="14800"

# KR価格（₩・APAC帯）／ US価格（$）— docs/15 §3.4
KR_MONTHLY="9900";  US_MONTHLY="9.99"
KR_ANNUAL="49000";  US_ANNUAL="39.99"
KR_ANNUAL_LAUNCH="39000"; US_ANNUAL_LAUNCH="49.99"
KR_LIFETIME="149000";     US_LIFETIME="119.99"

# 顧客向け表示名（暫定・最終はdocs/11 §5c＋asc-subscription-localizationで確認）
DN_MONTHLY="DopaBreak Pro（月額）"
DN_ANNUAL="DopaBreak Pro（年額）"
DN_ANNUAL_LAUNCH="DopaBreak Pro（年額・ローンチ）"
DESC_SUB="SNSを開く前の一呼吸で使いすぎを防ぐPro機能"
RN_LIFETIME="DopaBreak Pro Lifetime"

# ---- 前提チェック ----------------------------------------------------------
if [[ -z "${APP_ID}" ]]; then
  echo "ERROR: APP_ID 未指定。ASC_APP_ID=... か第1引数で渡してください。" >&2
  exit 2
fi
command -v asc >/dev/null || { echo "ERROR: asc CLI が見つかりません" >&2; exit 2; }
command -v jq  >/dev/null || { echo "ERROR: jq が見つかりません" >&2; exit 2; }

echo "==> 認証と対象アプリの確認"
asc apps view --id "${APP_ID}" --output table

# ---- 1. 月額サブスク（この呼び出しでサブスクグループも作成される）----------
echo "==> [1/6] サブスクグループ + 月額 を作成/整合"
asc subscriptions setup \
  --app "${APP_ID}" \
  --group-reference-name "${GROUP_REF}" \
  --group-display-name "${GROUP_DISPLAY}" \
  --group-locale "${LOCALE}" \
  --reference-name "DopaBreak Pro Monthly" \
  --product-id "${PID_MONTHLY}" \
  --subscription-period ONE_MONTH \
  --display-name "${DN_MONTHLY}" \
  --description "${DESC_SUB}" \
  --locale "${LOCALE}" \
  --price "${PRICE_MONTHLY}" \
  --price-territory "${BASE_TERRITORY}" \
  --territories "${SALE_TERRITORIES}" \
  --output json >/tmp/dopabreak_monthly.json
echo "    monthly OK"

# グループIDを取得（以降のサブスクは同一グループに束ねる）
GROUP_ID="$(asc subscriptions groups list --app "${APP_ID}" --output json \
  | jq -r --arg ref "${GROUP_REF}" '.[] | select(.referenceName==$ref) | .id' | head -1)"
if [[ -z "${GROUP_ID}" ]]; then
  echo "ERROR: サブスクグループIDを取得できませんでした" >&2; exit 1
fi
echo "    GROUP_ID=${GROUP_ID}"

# ---- 2. 年額サブスク（本番）------------------------------------------------
echo "==> [2/6] 年額(本番 ¥${PRICE_ANNUAL}) を作成/整合"
asc subscriptions setup \
  --group-id "${GROUP_ID}" \
  --app "${APP_ID}" \
  --reference-name "DopaBreak Pro Annual" \
  --product-id "${PID_ANNUAL}" \
  --subscription-period ONE_YEAR \
  --display-name "${DN_ANNUAL}" \
  --description "${DESC_SUB}" \
  --locale "${LOCALE}" \
  --price "${PRICE_ANNUAL}" \
  --price-territory "${BASE_TERRITORY}" \
  --territories "${SALE_TERRITORIES}" \
  --output json >/tmp/dopabreak_annual.json
echo "    annual OK"

# ---- 3. 年額サブスク（A/B用ローンチ価格）----------------------------------
echo "==> [3/6] 年額(A/B ¥${PRICE_ANNUAL_LAUNCH}) を作成/整合"
asc subscriptions setup \
  --group-id "${GROUP_ID}" \
  --app "${APP_ID}" \
  --reference-name "DopaBreak Pro Annual Launch" \
  --product-id "${PID_ANNUAL_LAUNCH}" \
  --subscription-period ONE_YEAR \
  --display-name "${DN_ANNUAL_LAUNCH}" \
  --description "${DESC_SUB}" \
  --locale "${LOCALE}" \
  --price "${PRICE_ANNUAL_LAUNCH}" \
  --price-territory "${BASE_TERRITORY}" \
  --territories "${SALE_TERRITORIES}" \
  --output json >/tmp/dopabreak_annual_launch.json
echo "    annual.launch OK"

# ---- 4. 7日間無料トライアル（両年額プランに付与）--------------------------
echo "==> [4/6] 7日間無料トライアル(introductory offer) を付与"
for PID in "${PID_ANNUAL}" "${PID_ANNUAL_LAUNCH}"; do
  asc subscriptions offers introductory create \
    --app "${APP_ID}" \
    --subscription-id "${PID}" \
    --all-territories \
    --offer-duration ONE_WEEK \
    --offer-mode FREE_TRIAL \
    --number-of-periods 1 \
    --output json >/dev/null
  echo "    intro(7日無料) -> ${PID} OK"
done

# ---- 5. KR(₩)・US($)価格を明示上書き（equalizeでなく各市場の意図価格）------
echo "==> [5/7] 韓国₩・米国\$ 価格を明示設定"
set_price() { # $1=product-id $2=territory $3=price
  asc subscriptions pricing prices set \
    --app "${APP_ID}" --subscription-id "$1" --territory "$2" --price "$3" \
    --output json >/dev/null && echo "    ${1} @${2} = $3 OK"
}
set_price "${PID_MONTHLY}"       "Korea" "${KR_MONTHLY}"
set_price "${PID_MONTHLY}"       "USA"   "${US_MONTHLY}"
set_price "${PID_ANNUAL}"        "Korea" "${KR_ANNUAL}"
set_price "${PID_ANNUAL}"        "USA"   "${US_ANNUAL}"
set_price "${PID_ANNUAL_LAUNCH}" "Korea" "${KR_ANNUAL_LAUNCH}"
set_price "${PID_ANNUAL_LAUNCH}" "USA"   "${US_ANNUAL_LAUNCH}"

# ---- 6. 買い切り（非消耗型IAP ¥14,800 / ₩149,000 / $119.99）---------------
echo "==> [6/7] 買い切り(非消耗型IAP) を作成/整合"
# 既存チェック（冪等）
EXISTING_IAP_ID="$(asc iap list --app "${APP_ID}" --output json 2>/dev/null \
  | jq -r --arg pid "${PID_LIFETIME}" '.[]? | select(.productId==$pid) | .id' | head -1 || true)"
if [[ -z "${EXISTING_IAP_ID}" ]]; then
  IAP_ID="$(asc iap create \
    --app "${APP_ID}" \
    --type NON_CONSUMABLE \
    --ref-name "${RN_LIFETIME}" \
    --product-id "${PID_LIFETIME}" \
    --output json | jq -r '.id')"
  echo "    IAP作成 IAP_ID=${IAP_ID}"
else
  IAP_ID="${EXISTING_IAP_ID}"
  echo "    IAP既存 IAP_ID=${IAP_ID}（作成スキップ）"
fi
# 買い切りは JPN基準で均等化。KR/USの厳密上書きは価格点ID解決が必要なため
# 実行時に別途（下の残タスク参照）。均等化でもJP¥14,800→US≒$100/KR≒₩133k と近い。
asc iap pricing schedules create \
  --app "${APP_ID}" \
  --iap-id "${IAP_ID}" \
  --base-territory "JPN" \
  --price "${PRICE_LIFETIME}" \
  --start-date "$(date +%Y-%m-%d)" \
  --output json >/dev/null
echo "    買い切り価格 ¥${PRICE_LIFETIME}(JPN基準・均等化) 設定 OK"

# ---- 7. 検証（読み戻し）----------------------------------------------------
echo "==> [7/7] 作成結果の検証（3市場）"
echo "--- サブスク一覧 ---"
asc subscriptions list --group-id "${GROUP_ID}" --output table
echo "--- サブスク価格サマリ（JP/KR/US確認）---"
asc subscriptions pricing summary --app "${APP_ID}" --output table || true
echo "--- IAP一覧 ---"
asc iap list --app "${APP_ID}" --output table

cat <<'DONE'

==============================================================
 完了: サブスク3本(JP¥/KR₩/US$) + 7日無料トライアル + 買い切りIAP。
 残りの人間/後続タスク:
   1. ko/en のサブスク・IAPローカライズ（表示名・説明）— 翻訳確定後に追加:
      asc subscriptions groups versions localizations create ...（ko-KR/en-US）
      asc subscriptions ... localizations create --locale ko-KR ...
   2. 買い切りの KR/US 厳密価格（₩149,000 / $119.99）を上書き:
      asc iap pricing price-points list --iap-id <IAP_ID> --output json で
      各テリトリーの price-point ID を解決 → schedules create --prices で3点指定
   3. 各商品の審査用スクリーンショット添付（未添付だと審査提出不可）
   4. 有料App契約がActiveであること（未締結なら本スクリプトは失敗する）
==============================================================
DONE
==============================================================
DONE
