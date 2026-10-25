#!/usr/bin/env python3
"""Ghi giá trị Remote Config ép trong code (DEBUG) rồi để runner build lại.

Sửa dict `codeOverrides` trong RemoteConfigRepositoryImpl.swift — giá trị là chuỗi thô như gõ trên
Firebase console (đi qua cùng luật parse với syncAllKeys).

  scripts/set-genius-290-rc-code-override.py quota_grandfather_until=2026-10-25T00:00:00Z
  scripts/set-genius-290-rc-code-override.py topup_offer_max_per_day=abc enable_topup=false
  scripts/set-genius-290-rc-code-override.py --clear
"""
import json
import re
import sys
from pathlib import Path

SWIFT = Path(__file__).resolve().parent.parent / "iosApp/Data/Repositories/RemoteConfig/RemoteConfigRepositoryImpl.swift"
PATTERN = re.compile(r"(static let codeOverrides: \[String: String\] = )\[[^\n]*\]")


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    pairs = {} if args == ["--clear"] else dict(a.split("=", 1) for a in args)
    literal = "[:]" if not pairs else "[" + ", ".join(f"{json.dumps(k)}: {json.dumps(v)}" for k, v in pairs.items()) + "]"
    src = SWIFT.read_text(encoding="utf-8")
    if not PATTERN.search(src):
        sys.exit(f"Không thấy `codeOverrides` trong {SWIFT}")
    SWIFT.write_text(PATTERN.sub(lambda m: m.group(1) + literal, src, count=1), encoding="utf-8")
    print(f"RC_CODE_OVERRIDE|{literal}")


if __name__ == "__main__":
    main()
