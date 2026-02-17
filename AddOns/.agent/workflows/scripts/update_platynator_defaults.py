#!/usr/bin/env python3
"""
從 SavedVariables 提取 Platynator MiliUI profile 並更新預設值檔案
"""

import sys
import os

SOURCE = "/Applications/World of Warcraft/_retail_/WTF/Account/LAXGENIUS/SavedVariables/Platynator.lua"
TARGET = "/Applications/World of Warcraft/_retail_/Interface/AddOns/MiliUI/Config/Luxthos_Platynator.lua"
PROFILE_NAME = "MiliUI"


def extract_profile(content, profile_name):
    """從 PLATYNATOR_CONFIG 中提取指定 profile 的內容"""
    marker = f'["{profile_name}"] = {{'
    start = content.find(marker)
    if start == -1:
        return None, f'找不到 profile "{profile_name}"'

    # 跳過 marker，從 { 之後開始
    brace_start = start + len(marker)
    depth = 1
    i = brace_start
    while i < len(content) and depth > 0:
        if content[i] == '{':
            depth += 1
        elif content[i] == '}':
            depth -= 1
        i += 1

    inner = content[brace_start:i - 1].strip()
    return inner, None


def validate_braces(content):
    """驗證 Lua 大括號是否配對"""
    depth = 0
    for i, ch in enumerate(content):
        if ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
        if depth < 0:
            line = content[:i].count('\n') + 1
            return False, f'第 {line} 行有多餘的 }}'
    if depth != 0:
        return False, f'大括號未配對，差距: {depth}'
    return True, None


def main():
    # 讀取來源
    if not os.path.exists(SOURCE):
        print(f"❌ 來源檔案不存在: {SOURCE}")
        sys.exit(1)

    with open(SOURCE, 'r') as f:
        content = f.read()

    # 提取 profile
    profile_content, err = extract_profile(content, PROFILE_NAME)
    if err:
        print(f"❌ {err}")
        sys.exit(1)

    # 組合輸出
    output = (
        f"MiliUI_PlatynatorProfile = {{\n"
        f"{profile_content}\n"
        f"}}\n"
        f"\n"
        f'MiliUI_PlatynatorProfile.kind = "profile"\n'
        f'MiliUI_PlatynatorProfile.addon = "Platynator"\n'
    )

    # 驗證語法
    ok, err = validate_braces(output)
    if not ok:
        print(f"❌ 語法驗證失敗: {err}")
        sys.exit(1)

    # 寫入目標
    with open(TARGET, 'w') as f:
        f.write(output)

    line_count = output.count('\n')
    print(f"✅ 已更新 Luxthos_Platynator.lua ({line_count} 行)")
    print(f"✅ 語法驗證通過（大括號配對正確）")


if __name__ == "__main__":
    main()
