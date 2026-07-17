# ロック画面 通知/Live Activity テーマ（2026-07-02・正式）

**2026-07-02 オーナー決定: ロック画面の常設ウィジェットは廃止。** 戻る先の表示は「朝の目標通知＋デイリーLive Activity」に一本化し、**テーマはこの面に適用する**（仕様: doc06 §9）。生成: `gemini-3.1-flash-image`（ムード検証用・実装はActivityKit/UNNotificationで再現）。

## カード構成（全テーマ共通・20b踏襲）

```text
[アイコン] DopaBreak                now
● GOAL 「英語で商談できる自分になる」   ← フル目標文
● 取り戻した時間 · 今週   6時間20分     ← アクセント色の大数字
  開かずに我慢 142回 · 12日連続
```

## テーマ一覧（Free=E1 / Pro=6種）

| ファイル | テーマ | プレビュー所見 |
| --- | --- | --- |
| notif_e1_mono.png | **E1 Dark Mono**（デフォルト・Free） | ◎ ライムの点＋大数字。基準品質 |
| notif_sumi.png | **墨と灯**（Pro第1弾） | ◎ 琥珀×セリフ時計×ランプアイコン。夜の内省 |
| notif_asagiri.png | **朝霧**（Pro・ライト） | ◎ 白カード×スレートブルー。朝の可読性 |
| notif_yozora.png | **夜更け**（Pro） | ◎ ネイビーカード×月光シルバー |
| notif_kpop.png | **K-POPパステル**（Pro・女性向け） | ◎ Y2Kグラデ壁紙×グロッシー白カード×ホットピンク数字×スパークル。目標例「韓国語で推しと話せる自分になる」 |
| notif_kawaii_pink.png | **かわいいピンク**（Pro・日本向け） | ◎ ドット壁紙×苺ピンク縁カード×コーナーリボン×うさぎアイコン（**オリジナル・サンリオキャラ使用禁止** → `../widget_themes/README.md` のIP注意に準拠） |

一覧: `_contact_sheet.png`

## 実装上の重要制約（設計済み・doc06 §9 / doc05 LockSurfaceState）

1. **折りたたみ状態の標準通知はテーマ不可**（iOSシステム描画）。テーマが効くのは ①**Live Activity（主戦場・完全カスタムUI）** ②長押し展開のNotification Content Extension ③添付サムネイル。
2. Live Activityは**最大8時間**で失効 → アプリ起動時・介入時・朝通知タップ時に再開始/更新。
3. 審査対策: Live Activityは「進行中のアクティビティ」要件があるため、**「今日のゲート実績」（止まれた回数・取り戻した時間がライブ更新）**として設計する。静的な目標表示だけにしない。
4. 通知許可が取れないユーザーにはホームウィジェット（維持）が代替接点。

## 再生成

```bash
python3 <scratchpad>/gen_notif_themes.py   # GOOGLE_API_KEY必須
```
