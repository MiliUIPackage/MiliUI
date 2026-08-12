#!/usr/bin/env python3
"""Apply official zhTW quest names from a wowhead TSV mapping into Lua addon files.

Anchors replacement on questIDs (numeric, stable) rather than on the existing
questName, because the existing name may already be a guessed Chinese
translation. Walks every line, and where a line contains both
`questName = "..."` and `questIDs = {NUM}`, replaces the questName with the
official zhTW name from the mapping.

Usage:
    apply_zhtw_names.py <mapping.tsv> <lua_dir>

mapping.tsv format (TAB-separated): id\\ten_name\\tzhtw_name
"""

import os
import re
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 1

    mapping_path, lua_dir = sys.argv[1], sys.argv[2]

    mapping: dict[str, str] = {}
    with open(mapping_path, encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 3 and parts[2]:
                mapping[parts[0]] = parts[2]
    print(f"Loaded {len(mapping)} zhTW names")

    files = [
        os.path.join(lua_dir, f)
        for f in os.listdir(lua_dir)
        if f.endswith(".lua")
    ]

    total = 0
    for fpath in files:
        with open(fpath, encoding="utf-8") as f:
            content = f.read()

        new_lines = []
        file_count = 0
        for line in content.split("\n"):
            m_qid = re.search(r"questIDs\s*=\s*\{\s*(\d+)", line)
            m_name = re.search(r'questName\s*=\s*"([^"]*)"', line)
            if m_qid and m_name:
                qid = m_qid.group(1)
                old = m_name.group(1)
                new = mapping.get(qid)
                if new and new != old:
                    line = line.replace(
                        f'questName = "{old}"', f'questName = "{new}"', 1
                    )
                    file_count += 1
            new_lines.append(line)

        if file_count:
            with open(fpath, "w", encoding="utf-8") as f:
                f.write("\n".join(new_lines))
            print(f"{os.path.basename(fpath)}: {file_count}")
            total += file_count

    print(f"\nTotal: {total} replacements across {len(files)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
