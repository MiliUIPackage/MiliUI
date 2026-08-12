"""Find Chinese phrases in our translated files that don't appear anywhere
in the wowhead zhTW corpus — these are likely subagent-guessed names that
don't match official translations.

Strategy: for each step's first questID, check if "thematic" parts of the title
(the Chinese place/NPC names) appear in that quest's zhTW page. If not, flag for review.
"""
import os, re, json, subprocess

mod_dir = '/Applications/World of Warcraft/_retail_/Interface/AddOns/FollowTheArrow/Data/Modules'
UPSTREAM = '/Users/mili/Projects/FollowTheArrow'

with open('/tmp/fta_wowhead/zhcorpus.json', encoding='utf-8') as f:
    corpus = json.load(f)

# Combine all corpus phrases into one big string per quest for substring search
corpus_text = {qid: '\n'.join(pieces) for qid, pieces in corpus.items()}

# Also build a mega-corpus across all quests (any quest mentioning the name)
mega_corpus = '\n'.join('\n'.join(p) for p in corpus.values())

def parse_steps(text):
    lines = text.split('\n')
    steps = []
    cur_title = None
    cur_segs = []
    for i, line in enumerate(lines, 1):
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
            cur_segs.append((m_qn.group(1), m_qid.group(1), i))
    if cur_title is not None:
        steps.append((cur_title, cur_segs))
    return steps

# For each thematic step (EN title doesn't equal any questName), extract the
# place name (after 前往/到/返回/離開/進入/在 etc.) and check if it's in the
# zhTW corpus for that step's questIDs.

THEMATIC_PREFIXES = ['前往', '到', '返回', '離開', '進入', '回到', '抵達', '在']

flagged = []
for fname in sorted(os.listdir(mod_dir)):
    if not fname.endswith('.lua'): continue
    target_path = os.path.join(mod_dir, fname)
    with open(target_path) as f:
        zh_text = f.read()

    try:
        en_text = subprocess.check_output(
            ['git', '-C', UPSTREAM, 'show', f'd62c10c:Data/Modules/{fname}'],
            text=True, stderr=subprocess.DEVNULL
        )
    except subprocess.CalledProcessError:
        continue

    en_steps = parse_steps(en_text)
    zh_steps = parse_steps(zh_text)
    if len(en_steps) != len(zh_steps): continue

    for (en_title, en_segs), (zh_title, zh_segs) in zip(en_steps, zh_steps):
        en_qns = {qn for qn, _, _ in en_segs}
        if en_title in en_qns:
            continue  # not thematic
        if not zh_segs:
            continue
        # Extract Chinese name from title (after any prefix)
        target_name = zh_title
        for p in THEMATIC_PREFIXES:
            if zh_title.startswith(p):
                target_name = zh_title[len(p):]
                break
        # Strip trailing chars
        target_name = re.sub(r'[繳交大會回收]+$', '', target_name).strip()
        if not target_name or len(target_name) < 2:
            continue
        if not all('一' <= c <= '鿿' for c in target_name if not c.isspace()):
            continue
        # Check: is target_name found in corpus of this step's questIDs?
        step_qids = [q for _, q, _ in zh_segs]
        found_in_step = any(target_name in corpus_text.get(q, '') for q in step_qids)
        if not found_in_step:
            # Try mega corpus
            in_mega = target_name in mega_corpus
            flagged.append((fname, zh_segs[0][2], en_title, zh_title, target_name, step_qids, in_mega))

print(f"Total flagged: {len(flagged)}")
print()
print("Flagged titles whose place name is NOT in step's quest corpus:")
print()
for fname, line, en_t, zh_t, name, qids, in_mega in flagged:
    flag = '✓' if in_mega else '✗ NOT IN ANY CORPUS'
    print(f"{fname}:{line}  EN \"{en_t}\"  →  ZH \"{zh_t}\"  [{name}] {flag}")
