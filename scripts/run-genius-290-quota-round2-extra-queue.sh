#!/bin/bash
# Daily Quota vòng 2 — case bổ sung sau phần subscriber: N172 gen video, N131 gỡ app cài lại (App User ID).
set -u
cd "$(dirname "$0")/.."
export G290_OUT=$PWD/plans/261024-1517-genius-290-daily-quota-topup-round2/runs
export G290_DD=${G290_DD:?đặt G290_DD}
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
RUN=scripts/run-genius-290-device-suite.sh
export TEST_RUNNER_R2_I2I_STYLE="Trending|4|Through the Ring"
T=Genius290QuotaRound2SubUITests
while pgrep -f "xcodebuild test-without-building.*4b95b1fc" >/dev/null; do sleep 15; done   # chỉ chờ lượt của phiên này (phiên khác chạy máy khác)
# N006 · N022 · N117-a · N123-b chạy lại (bản B, grandfather) — lượt 18:20 dừng sớm vì Setting ẩn My Balance
python3 scripts/set-genius-290-rc-code-override.py quota_grandfather_until=2026-10-25T00:00:00Z && "$RUN" build || exit 1
"$RUN" RUN_G290_R2SUB "$T/test04_grandfatherState" "r2extra-test04-rerun"
"$RUN" RUN_G290_R2SUB "$T/test06_grandfatherGenBeyondQ" "r2extra-test06-rerun"
python3 scripts/set-genius-290-rc-code-override.py quota_grandfather_until=2026-10-24T00:00:00Z && "$RUN" build || exit 1
"$RUN" RUN_G290_R2SUB "$T/test13_buyFrom481Resume" "r2extra-n167b"
"$RUN" RUN_G290_R2SUB "$T/test09_buyThenKillBeforeResume" "r2extra-n078"
"$RUN" RUN_G290_R2SUB "$T/test12_seedanceVideoGen" "r2extra-n172"
"$RUN" RUN_G290_R2SUB "$T/test11_appUserIdAcrossReinstall" "r2extra-n131-truoc"
ID=$(grep -h "^APPUSERID|" "$G290_OUT"/r2extra-n131-truoc-*.log | tail -1 | cut -d'|' -f2 | tr -d '\r')
echo "ID trước gỡ = $ID"
xcrun devicectl device uninstall app --device 3869BBF0-7BD4-596F-9389-E70C49E759D8 aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty
TEST_RUNNER_R2_PREV_ID="$ID" "$RUN" RUN_G290_R2SUB "$T/test11_appUserIdAcrossReinstall" "r2extra-n131-sau"
echo "== xong extra"
