#!/usr/bin/env python3
"""
從 SavedVariables 提取 SenseiClassResourceBar「米利」設定並更新 MiliUI 預設值檔案

提取邏輯：
- _Settings: 整個區塊直接複製（全域設定，不分 layout）
- PrimaryResourceBarDB/SecondaryResourceBarDB/tertiaryResourceBarDB/healthBarDB:
  從中提取「米利」layout 的設定，儲存為通用 key「MiliUI」
  這樣 GetMiliUIBarDefaults() 會取到這份設定作為所有 layout 的預設值
"""

import sys
import os
import re

SOURCE = "/Applications/World of Warcraft/_retail_/WTF/Account/LAXGENIUS/SavedVariables/SenseiClassResourceBar.lua"
TARGET = "/Applications/World of Warcraft/_retail_/Interface/AddOns/MiliUI/Config/Luxthos_Sensei.lua"
VARIABLE_NAME = "SenseiClassResourceBarDB"
OUTPUT_VARIABLE = "MiliUI_Luxthos_SenseiDB"
PROFILE_NAME = "米利"
OUTPUT_PROFILE = "MiliUI"

# Bar DB keys that store per-layout settings
BAR_DB_KEYS = [
    "PrimaryResourceBarDB",
    "SecondaryResourceBarDB",
    "tertiaryResourceBarDB",
    "healthBarDB",
]


def extract_block(content, marker):
    """提取一個 Lua table block 的內容 (不含外層大括號)"""
    start = content.find(marker)
    if start == -1:
        return None, None, f'找不到 "{marker}"'

    brace_pos = content.find('{', start + len(marker))
    if brace_pos == -1:
        return None, None, f'找不到 "{marker}" 後的開括號'

    depth = 1
    i = brace_pos + 1
    while i < len(content) and depth > 0:
        if content[i] == '{':
            depth += 1
        elif content[i] == '}':
            depth -= 1
        i += 1

    inner = content[brace_pos + 1:i - 1].strip()
    return inner, i, None


def extract_profile_from_section(section_content, profile_name):
    """從 bar DB section 中提取指定 profile (layout) 的設定"""
    marker = f'["{profile_name}"] = {{'
    start = section_content.find(marker)
    if start == -1:
        return None, f'在此區塊中找不到 profile "{profile_name}"'

    brace_start = section_content.find('{', start + len(f'["{profile_name}"] ='))
    depth = 1
    i = brace_start + 1
    while i < len(section_content) and depth > 0:
        if section_content[i] == '{':
            depth += 1
        elif section_content[i] == '}':
            depth -= 1
        i += 1

    inner = section_content[brace_start + 1:i - 1].strip()
    return inner, None


def reindent(content, base_depth=0):
    """將 SavedVariables 的無縮排格式轉換為 4 空格縮排"""
    lines = content.split('\n')
    result = []
    depth = base_depth
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        close_count = stripped.count('}') - stripped.count('{')
        if close_count > 0:
            depth = max(0, depth - close_count)
            result.append('    ' * depth + stripped)
        else:
            result.append('    ' * depth + stripped)
            open_count = stripped.count('{') - stripped.count('}')
            depth += open_count
    return '\n'.join(result)


def fix_numeric_keys(content):
    """將字串數字 key（如 ["0"]）轉換為數字 key（如 [0]）"""
    return re.sub(r'\["(\d+)"\]', lambda m: f'[{m.group(1)}]', content)


def validate_braces(content):
    """驗證大括號是否配對"""
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
    if not os.path.exists(SOURCE):
        print(f"❌ 來源檔案不存在: {SOURCE}")
        sys.exit(1)

    with open(SOURCE, 'r') as f:
        content = f.read()

    # 提取整個 DB
    db_content, _, err = extract_block(content, f"{VARIABLE_NAME} =")
    if err:
        print(f"❌ {err}")
        sys.exit(1)

    # 提取 _Settings（全域設定）
    settings_content, _, err = extract_block(db_content, '["_Settings"] =')
    if err:
        print(f"⚠️  找不到 _Settings，跳過")
        settings_content = None

    # 提取各 bar DB 中的指定 profile
    bar_sections = {}
    for key in BAR_DB_KEYS:
        section_content, _, err = extract_block(db_content, f'["{key}"] =')
        if err:
            print(f"⚠️  找不到 {key}，跳過")
            continue

        profile_content, err = extract_profile_from_section(section_content, PROFILE_NAME)
        if err:
            print(f"⚠️  {key}: {err}，跳過")
            continue

        bar_sections[key] = profile_content

    if not settings_content and not bar_sections:
        print("❌ 沒有提取到任何設定")
        sys.exit(1)

    # 組合輸出
    parts = []

    if settings_content:
        formatted_settings = reindent(settings_content, base_depth=3)
        parts.append(f'    ["_Settings"] = {{\n{formatted_settings}\n    }},')

    for key in BAR_DB_KEYS:
        if key in bar_sections:
            formatted = reindent(bar_sections[key], base_depth=4)
            parts.append(
                f'    ["{key}"] = {{\n'
                f'        ["{OUTPUT_PROFILE}"] = {{\n'
                f'{formatted}\n'
                f'        }},\n'
                f'    }},'
            )

    body = '\n'.join(parts)
    body = fix_numeric_keys(body)
    output = f"{OUTPUT_VARIABLE} = {{\n{body}\n}}\n"

    ok, err = validate_braces(output)
    if not ok:
        print(f"❌ 語法驗證失敗: {err}")
        sys.exit(1)

    with open(TARGET, 'w') as f:
        f.write(output)

    line_count = output.count('\n')
    print(f"✅ 已更新 Luxthos_Sensei.lua ({line_count} 行)")
    print(f"✅ 提取 profile: {PROFILE_NAME} → {OUTPUT_PROFILE}")
    print(f"✅ 包含區塊: _Settings, {', '.join(bar_sections.keys())}")
    print(f"✅ 語法驗證通過")


if __name__ == "__main__":
    main()
