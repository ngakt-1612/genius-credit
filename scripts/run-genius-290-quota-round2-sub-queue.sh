#!/bin/bash
# Daily Quota vòng 2 — phần subscriber. RC grandfather ép trong code: A = hôm nay (áp quota), B = ngày mai (grandfather).
set -u
cd "$(dirname "$0")/.."
export G290_OUT=$PWD/plans/261024-1517-genius-290-daily-quota-topup-round2/runs
export G290_DD=${G290_DD:?đặt G290_DD}
RUN=scripts/run-genius-290-device-suite.sh
export TEST_RUNNER_R2_I2I_STYLE="Trending|4|Through the Ring"   # thẻ style ảnh trên feed Home (dò bằng test10_findI2IStyle)
SET=scripts/set-genius-290-rc-code-override.py
A=quota_grandfather_until=2026-10-24T00:00:00Z
B=quota_grandfather_until=2026-10-25T00:00:00Z
T=Genius290QuotaRound2SubUITests
build() { python3 "$SET" "$@" && "$RUN" build || { echo "BUILD FAIL $*"; exit 1; }; }
t() { "$RUN" RUN_G290_R2SUB "$T/$1" "r2sub-$1"; }
while pgrep -f "xcodebuild test-without-building" >/dev/null; do sleep 15; done
# test01 (17:16) + test03 (N098 + mua Yearly, 17:30) đã chạy
build "$B"; t test04_grandfatherState
build "$A"; t test05_todayStateThenGenTwo
build "$B"; t test06_grandfatherGenBeyondQ
# test07 (N048/049/050/100, chờ BE auto-release 10′) → Pending theo user 24/10 17:41
build "$A"; t test08_exhaustQuotaThenBuy; t test09_buyThenKillBeforeResume
for v in "" "01/11/2026" "abc" "2026-13-45"; do
  build "quota_grandfather_until=$v"
  case "$v" in "") c=empty;; "01/11/2026") c=ddmmyyyy;; *) c="$v";; esac
  TEST_RUNNER_R2_RC_CASE="$c" "$RUN" RUN_G290_R2SUB "$T/test10_rcGrandfatherInvalid" "r2sub-rc-$c"
done
build "$A"
echo "== xong phần sub"
