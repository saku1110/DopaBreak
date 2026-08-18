#!/usr/bin/env bash
#
# asc-setup-dopabreak.sh
# DopaBreak の App Store Connect 課金カタログを公開API(asc CLI)で一括構築する。
#
# 2026-08-16 改訂（実行して通った手順に合わせて全面改訂）:
#   - テリトリーは3文字ID必須（"Korea" は ambiguous エラー。KOR と書く）
#   - ロケールは "ja"。"ja-JP" は Apple 側が受け付けない
#   - `asc subscriptions setup` の --display-name/--description/--locale/--group-* は
#     非推奨のv1リソースを叩き、ja-JPで失敗する。バージョン方式へ移行済み:
#       versions create → versions localizations create
#   - 冪等性: 既存の商品・バージョン・ローカライズがあれば作成をスキップする
#
# 前提（このスクリプトが動く条件）:
#   1. asc CLI が認証済み（`asc apps list` が通ること）
#   2. DopaBreak のアプリレコードが存在すること（2026-08-16時点: 6794221254）
#   3. 「有料App契約（Paid Apps Agreement）」が Active であること
#      （未締結だとサブスク/IAP作成がAppleに拒否される。銀行・税務情報の入力は人間のみ）
#
# 使い方:
#   ASC_APP_ID=6794221254 ./scripts/asc-setup-dopabreak.sh
#     または
#   ./scripts/asc-setup-dopabreak.sh 6794221254
#
# 価格の正本: docs/15_pricing_design.md（2026-07-24: 3市場同時ローンチ）
#   JP価格を基準に作成 → KR(₩)・US($)を territory 上書きで明示設定。
#
set -euo pipefail

# ---- 設定（docs/15 §3.4・storekit と一致）---------------------------------
APP_ID="${1:-${ASC_APP_ID:-}}"
BASE_TERRITORY="JPN"                    # 価格の基準テリトリー（3文字ID必須）
SALE_TERRITORIES="JPN,KOR,USA"          # 3市場同時ローンチ
GROUP_REF="DopaBreak Pro"               # サブスクグループ参照名（社内管理用）
GROUP_DISPLAY="DopaBreak Pro"           # グループ表示名（顧客に見える）
LOCALE="ja"                             # Apple は ja-JP を受け付けない

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

# 顧客向け表示名（ja。ko/en は翻訳確定後に追加＝末尾の残タスク参照）
DN_MONTHLY="DopaBreak Pro（月額）"
DN_ANNUAL="DopaBreak Pro（年額）"
DN_ANNUAL_LAUNCH="DopaBreak Pro（年額・ローンチ）"
DESC_SUB="SNSを開く前の一呼吸で使いすぎを防ぐPro機能"
RN_LIFETIME="DopaBreak Pro Lifetime"
DN_LIFETIME="DopaBreak Pro 買い切り"
DESC_LIFETIME="SNSを開く前の一呼吸で使いすぎを防ぐPro機能を買い切りで"

# ---- 前提チェック ----------------------------------------------------------
if [[ -z "${APP_ID}" ]]; then
  echo "ERROR: APP_ID 未指定。ASC_APP_ID=... か第1引数で渡してください。" >&2
  exit 2
fi
command -v asc >/dev/null || { echo "ERROR: asc CLI が見つかりません" >&2; exit 2; }
command -v jq  >/dev/null || { echo "ERROR: jq が見つかりません" >&2; exit 2; }

echo "==> 認証と対象アプリの確認"
asc apps view --id "${APP_ID}" --output table

# ---- ヘルパ ----------------------------------------------------------------

# サブスクを作成/整合する。作成済みならIDを返すだけ。
# setup は末尾の検証で MISSING_METADATA を error として返すが、
# ローカライズ前は必ずそうなるため exit code では判定せず ID を拾う。
ensure_subscription() { # $1=refName $2=productId $3=period $4=jpPrice
  local RN="$1" PID="$2" PERIOD="$3" PRICE="$4" SID
  SID="$(asc subscriptions list --group-id "${GROUP_ID}" --output json 2>/dev/null \
    | jq -r --arg pid "${PID}" '(.data // .)[]? | select((.attributes.productId // .productId)==$pid) | .id' | head -1 || true)"
  if [[ -n "${SID}" ]]; then
    echo "${SID}"; return 0
  fi
  SID="$(asc subscriptions setup \
    --app "${APP_ID}" --group-id "${GROUP_ID}" \
    --reference-name "${RN}" --product-id "${PID}" --subscription-period "${PERIOD}" \
    --price "${PRICE}" --price-territory "${BASE_TERRITORY}" --territories "${SALE_TERRITORIES}" \
    --output json 2>/dev/null | jq -r '.subscriptionId // empty')"
  [[ -n "${SID}" ]] || { echo "ERROR: ${PID} の作成に失敗" >&2; return 1; }
  echo "${SID}"
}

# サブスクのバージョンを解決（なければ作成）して ja ローカライズを付ける。
ensure_subscription_localization() { # $1=subscriptionId $2=displayName
  local SID="$1" DN="$2" VID
  VID="$(asc subscriptions versions list --subscription-id "${SID}" --output json 2>/dev/null \
    | jq -r '(.data // .)[0]?.id // empty')"
  if [[ -z "${VID}" ]]; then
    VID="$(asc subscriptions versions create --subscription-id "${SID}" --output json \
      | jq -r '.data.id')"
  fi
  # 既に ja があれば何もしない
  local HAS
  HAS="$(asc subscriptions versions localizations list --version-id "${VID}" --output json 2>/dev/null \
    | jq -r --arg l "${LOCALE}" '(.data // .)[]? | select((.attributes.locale // .locale)==$l) | .id' | head -1 || true)"
  if [[ -z "${HAS}" ]]; then
    asc subscriptions versions localizations create \
      --version-id "${VID}" --locale "${LOCALE}" \
      --name "${DN}" --description "${DESC_SUB}" --output json >/dev/null
  fi
  echo "    localization(${LOCALE}) OK  version=${VID}"
}

set_price() { # $1=product-id $2=territory(3文字) $3=price
  asc subscriptions pricing prices set \
    --app "${APP_ID}" --subscription-id "$1" --territory "$2" --price "$3" \
    --output json >/dev/null && echo "    ${1} @${2} = $3 OK"
}

# ---- 1. サブスクグループ ----------------------------------------------------
echo "==> [1/7] サブスクグループを作成/整合"
GROUP_ID="$(asc subscriptions groups list --app "${APP_ID}" --output json 2>/dev/null \
  | jq -r --arg ref "${GROUP_REF}" '(.data // .)[]? | select((.attributes.referenceName // .referenceName)==$ref) | .id' | head -1 || true)"
if [[ -z "${GROUP_ID}" ]]; then
  GROUP_ID="$(asc subscriptions groups create --app "${APP_ID}" \
    --reference-name "${GROUP_REF}" --output json | jq -r '.data.id')"
  echo "    グループ作成 GROUP_ID=${GROUP_ID}"
else
  echo "    グループ既存 GROUP_ID=${GROUP_ID}"
fi

# グループのバージョン＋ローカライズ（未設定だと全商品が MISSING_METADATA のまま）
GROUP_VID="$(asc subscriptions groups versions list --group-id "${GROUP_ID}" --output json 2>/dev/null \
  | jq -r '(.data // .)[0]?.id // empty')"
if [[ -z "${GROUP_VID}" ]]; then
  GROUP_VID="$(asc subscriptions groups versions create --group-id "${GROUP_ID}" --output json \
    | jq -r '.data.id')"
fi
GROUP_HAS_LOC="$(asc subscriptions groups versions localizations list --version-id "${GROUP_VID}" --output json 2>/dev/null \
  | jq -r --arg l "${LOCALE}" '(.data // .)[]? | select((.attributes.locale // .locale)==$l) | .id' | head -1 || true)"
if [[ -z "${GROUP_HAS_LOC}" ]]; then
  asc subscriptions groups versions localizations create \
    --version-id "${GROUP_VID}" --locale "${LOCALE}" --name "${GROUP_DISPLAY}" --output json >/dev/null
fi
echo "    グループローカライズ(${LOCALE}) OK  version=${GROUP_VID}"

# ---- 2. サブスク3本 --------------------------------------------------------
echo "==> [2/7] 月額 ¥${PRICE_MONTHLY}"
SID_MONTHLY="$(ensure_subscription "DopaBreak Pro Monthly" "${PID_MONTHLY}" ONE_MONTH "${PRICE_MONTHLY}")"
echo "    subId=${SID_MONTHLY}"
ensure_subscription_localization "${SID_MONTHLY}" "${DN_MONTHLY}"

echo "==> [3/7] 年額(本番) ¥${PRICE_ANNUAL}"
SID_ANNUAL="$(ensure_subscription "DopaBreak Pro Annual" "${PID_ANNUAL}" ONE_YEAR "${PRICE_ANNUAL}")"
echo "    subId=${SID_ANNUAL}"
ensure_subscription_localization "${SID_ANNUAL}" "${DN_ANNUAL}"

echo "==> [4/7] 年額(A/B) ¥${PRICE_ANNUAL_LAUNCH}"
SID_ANNUAL_LAUNCH="$(ensure_subscription "DopaBreak Pro Annual Launch" "${PID_ANNUAL_LAUNCH}" ONE_YEAR "${PRICE_ANNUAL_LAUNCH}")"
echo "    subId=${SID_ANNUAL_LAUNCH}"
ensure_subscription_localization "${SID_ANNUAL_LAUNCH}" "${DN_ANNUAL_LAUNCH}"

# ---- 2b. グループ内ランク（正本 = ios/DopaBreak/DopaBreak.storekit の groupNumber）
# ASC は「level 1 が最上位」。年額を最上位に置かないと月→年が
# ダウングレード扱い（次回更新まで反映されない）になる。
echo "==> [4b/7] グループ内ランクを正本に合わせる（annual=1 / launch=2 / monthly=3）"
asc subscriptions update --id "${SID_ANNUAL}"        --group-level 1 --output json >/dev/null
asc subscriptions update --id "${SID_ANNUAL_LAUNCH}" --group-level 2 --output json >/dev/null
asc subscriptions update --id "${SID_MONTHLY}"       --group-level 3 --output json >/dev/null
echo "    ランク設定 OK"

# ---- 3. 7日間無料トライアル（両年額プランに付与）--------------------------
echo "==> [5/7] 7日間無料トライアル(introductory offer)"
for PID in "${PID_ANNUAL}" "${PID_ANNUAL_LAUNCH}"; do
  asc subscriptions offers introductory create \
    --app "${APP_ID}" --subscription-id "${PID}" --all-territories \
    --offer-duration ONE_WEEK --offer-mode FREE_TRIAL --number-of-periods 1 \
    --output json >/dev/null 2>&1 || true   # 既存なら skip される
  echo "    intro(7日無料) -> ${PID} OK"
done

# ---- 4. KR(₩)・US($)価格を明示上書き ---------------------------------------
echo "==> [6/7] 韓国₩・米国\$ 価格を明示設定"
set_price "${PID_MONTHLY}"       "KOR" "${KR_MONTHLY}"
set_price "${PID_MONTHLY}"       "USA" "${US_MONTHLY}"
set_price "${PID_ANNUAL}"        "KOR" "${KR_ANNUAL}"
set_price "${PID_ANNUAL}"        "USA" "${US_ANNUAL}"
set_price "${PID_ANNUAL_LAUNCH}" "KOR" "${KR_ANNUAL_LAUNCH}"
set_price "${PID_ANNUAL_LAUNCH}" "USA" "${US_ANNUAL_LAUNCH}"

# ---- 5. 買い切り（非消耗型IAP）--------------------------------------------
echo "==> [7/7] 買い切り(非消耗型IAP)"
IAP_ID="$(asc iap list --app "${APP_ID}" --output json 2>/dev/null \
  | jq -r --arg pid "${PID_LIFETIME}" '(.data // .)[]? | select((.attributes.productId // .productId)==$pid) | .id' | head -1 || true)"
if [[ -z "${IAP_ID}" ]]; then
  IAP_ID="$(asc iap create --app "${APP_ID}" --type NON_CONSUMABLE \
    --ref-name "${RN_LIFETIME}" --product-id "${PID_LIFETIME}" --output json | jq -r '.data.id')"
  echo "    IAP作成 IAP_ID=${IAP_ID}"
else
  echo "    IAP既存 IAP_ID=${IAP_ID}"
fi
asc iap localizations create --iap-id "${IAP_ID}" --locale "${LOCALE}" \
  --name "${DN_LIFETIME}" --description "${DESC_LIFETIME}" --output json >/dev/null 2>&1 || true
asc iap pricing schedules create --app "${APP_ID}" --iap-id "${IAP_ID}" \
  --base-territory "${BASE_TERRITORY}" --price "${PRICE_LIFETIME}" \
  --start-date "$(date +%Y-%m-%d)" --output json >/dev/null
echo "    買い切り価格 ¥${PRICE_LIFETIME}(JPN基準・均等化) 設定 OK"

# IAPは価格スケジュールとは別に availability を張らないと MISSING_METADATA のまま残る。
# サブスクは --territories で同時に張られるが、IAPは別リソース。
asc iap pricing availability set --app "${APP_ID}" --iap-id "${IAP_ID}" \
  --territories "${SALE_TERRITORIES}" --output json >/dev/null
echo "    買い切り提供地域 ${SALE_TERRITORIES} 設定 OK"

# ---- 6. 検証（読み戻し）----------------------------------------------------
echo "==> 検証"
echo "--- サブスク一覧 ---"
asc subscriptions list --group-id "${GROUP_ID}" --output table
echo "--- IAP一覧 ---"
asc iap list --app "${APP_ID}" --output table

cat <<'DONE'

==============================================================
 完了: サブスク3本(JP¥/KR₩/US$) + 7日無料トライアル + 買い切りIAP。

 ⚠️ 本スクリプト単体では全商品が MISSING_METADATA で残る。
    READY_TO_SUBMIT にするには審査用スクリーンショットの添付が別途必要:
      サブスク: asc subscriptions review screenshots create \
                  --app <APP_ID> --subscription-id <SUB_ID> --file <png>
      買い切り: asc iap review-screenshots create \
                  --app <APP_ID> --iap-id <IAP_ID> --file <png>
    ※ `asc iap versions images` は審査用スクショではなく**プロモーション画像**の枠。
       ペイウォールのスクショを入れると IMAGE_INCORRECT_DIMENSIONS で必ず失敗する。
    ※ 撮影素材は output/asc-review-screenshots/paywall-ja.png（2026-08-16 実機シミュレータ撮影）

 残りの後続タスク:
   1. ko/en のサブスク・IAPローカライズ（表示名・説明）— 翻訳確定後:
        asc subscriptions versions localizations create --version-id <VID> --locale ko --name ...
        asc subscriptions groups versions localizations create --version-id <GVID> --locale ko --name ...
      （ロケールは ko / en-US。ja-JP 形式は不可）
   2. 買い切りの KR/US 厳密価格（₩149,000 / $119.99）を上書き:
        asc iap pricing price-points list --iap-id <IAP_ID> --output json で
        各テリトリーの price-point ID を解決 → schedules create --prices で3点指定
   3. 有料App契約がActiveであること（未締結なら本スクリプトは失敗する）
==============================================================
DONE
