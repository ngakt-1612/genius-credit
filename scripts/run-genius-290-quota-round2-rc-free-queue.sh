#!/bin/bash
# Daily Quota vòng 2 — RC ép trong code cho user free (topup 0): mỗi giá trị = gỡ app (reset bộ đếm offer)
# → sửa codeOverrides → build → chạy. Cuối cùng trả RC về ngưỡng TC (grandfather = hôm nay).
set -u
cd "$(dirname "$0")/.."
export G290_OUT=$PWD/plans/261024-1517-genius-290-daily-quota-topup-round2/runs
export G290_DD=${G290_DD:?đặt G290_DD}
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
RUN=scripts/run-genius-290-device-suite.sh
export TEST_RUNNER_R2_I2I_STYLE="Trending|4|Through the Ring"   # thẻ style ảnh trên feed Home (dò bằng test10_findI2IStyle)
SET=scripts/set-genius-290-rc-code-override.py
GF=quota_grandfather_until=2026-10-24T00:00:00Z
BUNDLE=aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty
uninstall() { xcrun devicectl device uninstall app --device 3869BBF0-7BD4-596F-9389-E70C49E759D8 "$BUNDLE" >/dev/null 2>&1; echo "uninstall rc=$?"; }
while pgrep -f "xcodebuild test-without-building" >/dev/null; do sleep 15; done
for v in 0 -1 abc 2; do
  uninstall
  python3 "$SET" "$GF" "topup_offer_max_per_day=$v" && "$RUN" build || { echo "BUILD FAIL $v"; exit 1; }
  TEST_RUNNER_R2_RC_CASE="$v" "$RUN" RUN_G290_R2 "Genius290QuotaRound2UITests/test07_offerMaxPerDay" "r2rc-offer-$v"
done
python3 "$SET" "$GF" enable_topup=false && "$RUN" build || { echo "BUILD FAIL enable_topup"; exit 1; }
"$RUN" RUN_G290_R2 "Genius290QuotaRound2UITests/test08_enableTopupOff" "r2rc-enable-topup-off"
python3 "$SET" "$GF" && "$RUN" build
echo "== xong RC free"
