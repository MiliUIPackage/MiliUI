"""40 張總覽。用法：python3 -I overview.py <final 資料夾> <輸出檔> [後綴]"""
import sys, os
from PIL import Image, ImageDraw, ImageFont
SRC, OUT = sys.argv[1], sys.argv[2]
SUF = sys.argv[3] if len(sys.argv) > 3 else ""
F = "/System/Library/Fonts/STHeiti Medium.ttc"
font, small = ImageFont.truetype(F, 20), ImageFont.truetype(F, 14)
CLASSES = [
    ("deathknight", "死亡騎士", (196, 30, 58), [("blood", "血魄"), ("frost", "冰霜"), ("unholy", "穢邪")]),
    ("demonhunter", "惡魔獵人", (163, 48, 201), [("havoc", "浩劫"), ("vengeance", "復仇"), ("devourer", "噬滅")]),
    ("druid", "德魯伊", (255, 124, 10), [("balance", "平衡"), ("feral", "野性"), ("guardian", "守護者"), ("restoration", "恢復")]),
    ("evoker", "喚能師", (51, 147, 127), [("devastation", "破滅"), ("preservation", "護存"), ("augmentation", "增輝")]),
    ("hunter", "獵人", (170, 211, 114), [("beastmastery", "獸王"), ("marksmanship", "射擊"), ("survival", "生存")]),
    ("mage", "法師", (63, 199, 235), [("arcane", "祕法"), ("fire", "火焰"), ("frost", "冰霜")]),
    ("monk", "武僧", (0, 255, 152), [("brewmaster", "釀酒"), ("mistweaver", "織霧"), ("windwalker", "御風")]),
    ("paladin", "聖騎士", (244, 140, 186), [("holy", "神聖"), ("protection", "防護"), ("retribution", "懲戒")]),
    ("priest", "牧師", (255, 255, 255), [("discipline", "戒律"), ("holy", "神聖"), ("shadow", "暗影")]),
    ("rogue", "盜賊", (255, 244, 104), [("assassination", "刺殺"), ("outlaw", "暴徒"), ("subtlety", "敏銳")]),
    ("shaman", "薩滿", (0, 112, 221), [("elemental", "元素"), ("enhancement", "增強"), ("restoration", "恢復")]),
    ("warlock", "術士", (135, 136, 238), [("affliction", "痛苦"), ("demonology", "惡魔學識"), ("destruction", "毀滅")]),
    ("warrior", "戰士", (198, 155, 109), [("arms", "武器"), ("fury", "狂怒"), ("protection", "防護")]),
]
def load(cls, spec):
    return Image.open(os.path.join(SRC, f"{cls}-{spec}{SUF}.png")).convert("RGBA")
def shrink(im, px):
    return im.convert("RGBa").resize((px, px), Image.LANCZOS).convert("RGBA")
def tile(im, px):
    t = Image.new("RGBA", (px, px), (14, 14, 14, 255)); t.alpha_composite(shrink(im, px)); return t

T, GAP, LABEL_W = 96, 14, 130
COL_W = T + GAP + 20
W = LABEL_W + 2 * (4 * COL_W) + 40
ROWS = (len(CLASSES) + 1) // 2
H = 30 + ROWS * (T + 40) + 420
board = Image.new("RGBA", (W, H), (40, 40, 44, 255))
d = ImageDraw.Draw(board)
for idx, (cls, cname, rgb, specs) in enumerate(CLASSES):
    col, row = idx % 2, idx // 2
    x0 = 20 + col * (LABEL_W + 4 * COL_W + 10)
    y0 = 20 + row * (T + 40)
    d.rectangle([x0, y0 + 10, x0 + 6, y0 + T - 10], fill=rgb)
    d.text((x0 + 14, y0 + T // 2 - 12), cname, fill=(230, 230, 230), font=font)
    for j, (spec, sname) in enumerate(specs):
        x = x0 + LABEL_W + j * COL_W
        board.alpha_composite(tile(load(cls, spec), T), (x, y0))
        d.text((x, y0 + T + 4), sname, fill=(170, 170, 170), font=small)
# 實際大小並排
y = 30 + ROWS * (T + 40) + 10
allicons = [(cls, spec, rgb) for cls, _, rgb, specs in CLASSES for spec, _ in specs]
for px in (24, 20):
    d.text((20, y), f"實際大小 {px}px（40 張並排，圖示格深底由程式畫）", fill=(200, 200, 200), font=small)
    y += 22
    x = 20
    for cls, spec, rgb in allicons:
        board.alpha_composite(tile(load(cls, spec), px), (x, y))
        x += px + 4
    y += px + 8
    # 同一排放大 2 倍看像素（拆兩行，20 張一行）
    big = px * 2
    for r in range(2):
        x = 20
        for cls, spec, rgb in allicons[r * 20:(r + 1) * 20]:
            t = tile(load(cls, spec), px).resize((big, big), Image.NEAREST)
            board.alpha_composite(t, (x, y))
            x += big + 4
        y += big + 4
    y += 18
board.convert("RGB").save(OUT)
print(board.size)
