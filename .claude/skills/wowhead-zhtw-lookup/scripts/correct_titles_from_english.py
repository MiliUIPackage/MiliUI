"""For each step, look up the ORIGINAL English title in the upstream file,
find which questID in that step had that questName, and replace current
title with the official zhTW name for that specific questID.

This correctly handles multi-quest steps where the author chose the 2nd or
later quest as the step's main title.
"""
import os, re, subprocess

UPSTREAM_REPO = '/Users/mili/Projects/FollowTheArrow'
UPSTREAM_REF = 'd62c10c'  # original English commit
TARGET_DIR = '/Applications/World of Warcraft/_retail_/Interface/AddOns/FollowTheArrow/Data/Modules'

# Load wowhead zhTW mapping
mapping = {}
with open('/tmp/fta_wowhead/quests.tsv') as f:
    for line in f:
        parts = line.rstrip('\n').split('\t')
        if len(parts) >= 3 and parts[2]:
            mapping[parts[0]] = parts[2]

def parse_steps(text):
    """Parse a Lua module file into a list of (title, [(questName, questID)])."""
    lines = text.split('\n')
    steps = []
    cur_title = None
    cur_segs = []  # list of (questName, questID)
    for line in lines:
        m_title = re.search(r'^\s*title\s*=\s*"([^"]*)"', line)
        if m_title:
            if cur_title is not None:
                steps.append((cur_title, cur_segs))
            cur_title = m_title.group(1)
            cur_segs = []
            continue
        m_qn = re.search(r'questName\s*=\s*"([^"]*)"', line)
        m_qid = re.search(r'questIDs\s*=\s*\{\s*(\d+)', line)
        if m_qn and m_qid:
            cur_segs.append((m_qn.group(1), m_qid.group(1)))
    if cur_title is not None:
        steps.append((cur_title, cur_segs))
    return steps

total_changes = 0
mismatch_count = 0
for fname in sorted(os.listdir(TARGET_DIR)):
    if not fname.endswith('.lua'):
        continue
    upstream_path = f'Data/Modules/{fname}'
    try:
        en_text = subprocess.check_output(
            ['git', '-C', UPSTREAM_REPO, 'show', f'{UPSTREAM_REF}:{upstream_path}'],
            text=True, stderr=subprocess.DEVNULL,
        )
    except subprocess.CalledProcessError:
        continue

    target_path = os.path.join(TARGET_DIR, fname)
    with open(target_path) as f:
        zh_text = f.read()

    en_steps = parse_steps(en_text)
    zh_steps = parse_steps(zh_text)
    if len(en_steps) != len(zh_steps):
        print(f"⚠ {fname}: step count mismatch en={len(en_steps)} zh={len(zh_steps)}, skipping")
        mismatch_count += 1
        continue

    file_changes = []
    for (en_title, en_segs), (zh_title, zh_segs) in zip(en_steps, zh_steps):
        # Find which questID in this step has questName matching the English title
        target_qid = None
        for qn, qid in en_segs:
            if qn == en_title:
                target_qid = qid
                break
        if target_qid is None:
            # Title was thematic (not a quest name) — keep current zh title
            continue
        official_zh = mapping.get(target_qid)
        if not official_zh:
            continue
        if zh_title != official_zh:
            file_changes.append((en_title, zh_title, official_zh, target_qid))

    if file_changes:
        for en_t, old_zh, new_zh, qid in file_changes:
            # Replace `title = "old"` with `title = "new"` (first occurrence per step)
            zh_text = re.sub(
                r'(\n\s*)title\s*=\s*"' + re.escape(old_zh) + r'"',
                lambda m: f'{m.group(1)}title = "{new_zh}"',
                zh_text, count=1
            )
        with open(target_path, 'w') as f:
            f.write(zh_text)
        print(f"\n{fname}: {len(file_changes)} corrections")
        for en_t, old_zh, new_zh, qid in file_changes:
            print(f'  EN "{en_t}" (qid={qid}) → "{old_zh}" → "{new_zh}"')
        total_changes += len(file_changes)

print(f"\n=== Total: {total_changes} title corrections, {mismatch_count} files skipped ===")
