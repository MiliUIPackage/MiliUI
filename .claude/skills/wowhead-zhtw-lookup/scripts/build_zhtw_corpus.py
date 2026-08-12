"""Extract zhTW description text from cached wowhead pages.
Builds a corpus mapping questID → list of Chinese phrases (descriptions, objectives).
"""
import os, re, json
from html import unescape

zh_dir = '/tmp/fta_wowhead/zhpages'
corpus = {}

for fname in sorted(os.listdir(zh_dir)):
    if not fname.endswith('.html'): continue
    qid = fname[:-5]
    with open(os.path.join(zh_dir, fname), encoding='utf-8') as f:
        html = f.read()
    
    # Extract quest description: look for the description div
    # Wowhead uses id="description" or class with description content
    # Also extract objectives from list-quest-objectives or similar
    
    # The page contains chunks of Chinese text. Extract all Chinese-containing
    # text segments by matching <element>chinese text</element> patterns.
    pieces = []
    # Strip scripts/styles first
    html_clean = re.sub(r'<script.*?</script>', '', html, flags=re.DOTALL)
    html_clean = re.sub(r'<style.*?</style>', '', html_clean, flags=re.DOTALL)
    
    # Extract text content between tags that contains Chinese chars
    for m in re.finditer(r'>([^<>]+)<', html_clean):
        text = m.group(1).strip()
        if not text: continue
        text = unescape(text)
        # Has at least one CJK character?
        if any('一' <= c <= '鿿' for c in text):
            # Filter common UI text and very short fragments
            if len(text) >= 2 and text not in ('已完成', '描述', '進度', '獎勵', '上頁', '下頁'):
                pieces.append(text)
    
    if pieces:
        corpus[qid] = pieces

# Save corpus
with open('/tmp/fta_wowhead/zhcorpus.json', 'w', encoding='utf-8') as f:
    json.dump(corpus, f, ensure_ascii=False, indent=1)

print(f"Extracted {len(corpus)} quests, {sum(len(v) for v in corpus.values())} total phrases")
print(f"Saved to /tmp/fta_wowhead/zhcorpus.json")

# Sanity: show 阿曼尼小徑 occurrences
hits = 0
for qid, pieces in corpus.items():
    for p in pieces:
        if '阿曼尼小徑' in p:
            hits += 1
            break
print(f"\n'阿曼尼小徑' appears in {hits} quests' pages")
