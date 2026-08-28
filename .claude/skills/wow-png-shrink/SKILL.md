---
name: wow-png-shrink
description: 把插件的 PNG 壓到最小又不掉畫質（壓縮圖片、圖太大、預覽圖瘦身、Media 資料夾肥、repo 太大）。當使用者說「幫我壓縮這些圖」「檔案越小越好」「圖片太肥」，或往 Media/ 丟了新的擷圖／貼圖時使用。跑 scripts/shrink_png.py，不要臨時寫一個一次性腳本——這裡的判準（哪些手段可以用、縮圖要拿什麼尺寸驗證、什麼格式遊戲載不動）都是量測過才定下來的，重推很容易做出「看起來小了但畫質掉了」的東西。
---

# 壓縮插件的 PNG

```bash
python3 .claude/skills/wow-png-shrink/scripts/shrink_png.py <資料夾或檔案> [選項]
```

**預設乾跑**，只印出每張圖的前後大小與畫質數字。確認過再加 `--apply` 覆蓋。
需要 `pip install pillow numpy scipy` 與 `brew install oxipng`（`zopfli` 選配，
裝了會多試一輪 zopflipng）。

改完記得原檔在 git 裡，`git checkout` 就能還原 —— 但**新加入還沒 commit 的圖沒有退路**，
先 `git add` 再壓。

## 套組預覽圖的固定跑法

`AddOns/MiliUI/Media/Shots/` 的顯示區是 **420×210 UI 單位**
（[Tab_Addons.lua](../../../AddOns/MiliUI/Options/Tab_Addons.lua) 的 `SHOT_W, SHOT_H`），
規格是 2 倍圖 840×420：

```bash
cd "/Applications/World of Warcraft/_retail_/Interface" && python3 .claude/skills/wow-png-shrink/scripts/shrink_png.py AddOns/MiliUI/Media/Shots --max-width 840 --display 420x210
```

新擷圖丟進去之後跑這行就好。2026-08-29 那次把 5.63 MB 壓到 2.47 MB（-56%）。

## 三個手段，以及為什麼是這三個

腳本依序套用，每一步都量測過才決定要不要留：

**1. 去掉沒在用的 alpha** —— alpha 全 255 就轉 RGB，白省四分之一的原始資料量，
像素完全不變。擷圖幾乎都是這種。

**2. 縮到 `--max-width`** —— 通常是省最多的一刀，但**要自己指定，腳本不猜**。
只有你知道遊戲裡的顯示框多大；猜錯就是真的把畫質壓掉了。
先去程式碼裡把顯示框的 `SetSize` 找出來，再決定 2 倍是多少。

判斷「縮了會不會看得出來」**不能拿原尺寸直接比** —— 那比的是「有沒有丟像素」，
答案一定是有。要把原圖跟縮圖**都降到實際顯示尺寸再比**，那才是玩家看到的東西。
`--display` 就是餵這個用的。上次四張超規格的圖在 420×210 下 PSNR 44～54 dB、
SSIM 0.9987+，等於沒差別，但檔案掉了 60～75%。

順帶一提縮到 2 倍圖對遊戲的取樣也比較好：GPU 是雙線性加 mipmap，
從 1600 縮到 420 的縮減幅度比從 840 縮更容易糊。

**3. ±2 階雜訊吸附** —— 3×3 中位數濾波，但**只在偏差 ≤2 時吸附**。
文字與邊緣的相鄰差異遠大於 2 所以原封不動，被抹掉的只有遊戲渲染的散粒雜訊，
而雜訊正是讓 PNG 行預測器失效的東西。PSNR 通常 50～62 dB，最大色偏 2/255。

只有省超過 5%（`--denoise-gain`）才採用，否則保留**像素完全相同**的版本 ——
乾淨的介面截圖本來就沒什麼雜訊可抹，套了只是白白動到像素。

## 不要做的事

**不要用 pngquant 轉索引色。** 能再砍到 25%，但遊戲擷圖漸層多，256 色下
PSNR 只有 23～31 dB、最大色偏到 110，漸層會明顯斷階。這是唯一測過但整批否決的手段。

（順帶一提遊戲**吃**索引色 PNG ——
[Cell/Indicators/Supporter.lua:152](../../../AddOns/Cell/Indicators/Supporter.lua)
`SetTexture` 載入的 `mvp.png` 就是 8-bit 調色盤含 tRNS，跑得好好的。
所以否決理由是畫質，不是相容性。哪天有純色少的圖，索引色是可以考慮的。）

**不要把透明像素的 RGB 清成 0**（`zopflipng --lossy_transparent` 會這麼做）。
遊戲用雙線性取樣，透明像素的 RGB 會被鄰近的不透明像素採到，邊緣會冒黑邊。
腳本對有真 alpha 的圖只動 RGB，A 完全不碰。

**不要為了壓縮改動 alpha 通道**，那會改變邊緣形狀，是真的畫質損失。

## 遊戲吃得下的格式

腳本每張輸出都會驗，不合格就跳過不寫。實測可用的是 **8-bit** 的
RGB／RGBA／調色盤，**非交錯**。16-bit 與交錯式沒驗過，不要產生。

**這就是不要自己臨時跑 oxipng 的原因**：它預設會自作主張改色彩型別。
拿一張平面色與一張灰階內容各測一次就看得到 ——

| 旗標 | 灰階內容 | 平面色 |
|---|---|---|
| 無 | 8-bit **灰階** | **1-bit** 調色盤 |
| `--nb` | 8-bit **灰階** | 8-bit 調色盤 |
| `--nb --nc` | 8-bit RGB | 8-bit RGBA（丟了調色盤的壓縮優勢） |

1-bit 調色盤幾乎確定載不動，灰階沒驗過。腳本的做法是用 `--nb` 保住 8-bit
與調色盤，真的變成灰階才補 `--nc` 重壓一次 —— 兩邊都要。
zopflipng 沒有保持色彩型別的旗標，所以腳本會比對前後的表頭，型別被改掉就不採用它的結果。

想確認整包目前有哪些格式在用：

```bash
python3 - <<'EOF'
import os, struct, collections
ct={0:'gray',2:'RGB',3:'PALETTE',4:'gray+A',6:'RGBA'}
s=collections.Counter(); ex={}
for root,_,files in os.walk('AddOns'):
    for f in files:
        if not f.lower().endswith('.png'): continue
        p=os.path.join(root,f)
        with open(p,'rb') as fh: h=fh.read(33)
        if h[:8]!=b'\x89PNG\r\n\x1a\n': continue
        w,hh,bd,c,_,_,i=struct.unpack('>IIBBBBB',h[16:29])
        k=(bd,ct.get(c,c),'交錯' if i else '')
        s[k]+=1; ex.setdefault(k,p)
for k,v in s.most_common(): print(f'{str(k):32s} {v:5d}  例：{ex[k]}')
EOF
```

## 新圖要重開客戶端

放進 `Media/` 的**新**檔案要重啟遊戲才會進客戶端的檔案清單，`/reload` 不夠。
覆蓋既有檔名則 `/reload` 就會生效 —— 這個技能是覆蓋，所以 `/reload` 就能看到。
