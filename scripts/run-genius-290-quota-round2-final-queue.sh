#!/bin/bash
# Daily Quota vòng 2 — phần còn lại (24/10 tối). Máy free 0/0 lúc bắt đầu; test cần gói tự mua lại Yearly.
set -u
cd "$(dirname "$0")/.."
export G290_OUT=$PWD/plans/261024-1517-genius-290-daily-quota-topup-round2/runs
export G290_DD=${G290_DD:?đặt G290_DD}
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export TEST_RUNNER_R2_I2I_STYLE="Trending|4|Through the Ring"
export TEST_RUNNER_R2_GEN_VIA=enhance   # 25/10: Home lỗi server — gen qua Enhance (tab Create)
RUN=scripts/run-genius-290-device-suite.sh
SET=scripts/set-genius-290-rc-code-override.py
A=quota_grandfather_until=2026-10-24T00:00:00Z
B=quota_grandfather_until=2026-10-26T00:00:00Z   # ngày mai (chạy 25/10)
T=Genius290QuotaRound2SubUITests
build() { python3 "$SET" "$@" && "$RUN" build || { echo "BUILD FAIL $*"; exit 1; }; }
t() { "$RUN" RUN_G290_R2SUB "$T/$1" "r2fin-$1"; }
while pgrep -f "xcodebuild test-without-building.*4b95b1fc" >/dev/null; do sleep 15; done
# test04 + test06 (grandfather) xong 25/10 11:49; N087 chạy riêng khi máy free
build "$A"; t test13_buyFrom481Resume; t test09_buyThenKillBeforeResume
# N172 (gen video I2V) cần Home — chờ server
t test11_appUserIdAcrossReinstall
ID=$(grep -h "^APPUSERID|" "$G290_OUT"/r2fin-test11_appUserIdAcrossReinstall-*.log | tail -1 | cut -d'|' -f2 | tr -d '\r')
echo "ID trước gỡ = $ID"
xcrun devicectl device uninstall app --device 3869BBF0-7BD4-596F-9389-E70C49E759D8 aiphotogenerator.aifaceeditor.aivideogenerator.aibeauty
TEST_RUNNER_R2_PREV_ID="$ID" "$RUN" RUN_G290_R2SUB "$T/test11_appUserIdAcrossReinstall" "r2fin-n131-sau"
for v in "" "01/11/2026" "abc" "2026-13-45"; do
  build "quota_grandfather_until=$v"
  case "$v" in "") c=empty;; "01/11/2026") c=ddmmyyyy;; *) c="$v";; esac
  TEST_RUNNER_R2_RC_CASE="$c" "$RUN" RUN_G290_R2SUB "$T/test10_rcGrandfatherInvalid" "r2fin-rc-$c"
done
build "$A"
echo "== xong final"
