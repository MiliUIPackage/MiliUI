---
name: miliui-inspect-icons
description: 重新產生 MiliUI_UnitFrames 觀察按鈕的三款圖示（觀察者／放大鏡／圓底問號）。當使用者說「換觀察按鈕的圖」「觀察鈕圖示重畫」「調一下放大鏡的造型」「加一款觀察按鈕樣式」，或要動 Elements/Inspect.lua 的 STYLE_DEFS／inspect-*.png 時使用。圖示是 Pillow 腳本畫出來的，不要用繪圖軟體手改 PNG——那樣下次要調就沒有來源了。
---

# MiliUI 觀察按鈕圖示

`AddOns/MiliUI_UnitFrames/Media/inspect-{inspector,glass,round}.png` 這三張圖**不是素材，是
`scripts/inspect-icons.py` 畫出來的**。要改造型就改腳本再跑一次，不要拿繪圖軟體去修 PNG。

腳本本身放在這裡而不是 `Media/`：它是開發工具，玩家 clone 下來不需要
（見 [notes/project-agent-dir-convention](../../notes/project-agent-dir-convention.md)）。

## 跑法

```bash
cd "/Applications/World of Warcraft/_retail_/Interface/AddOns/MiliUI_UnitFrames/Media" && python3 "../../../.claude/skills/miliui-inspect-icons/scripts/inspect-icons.py"
```

**一定要 `cd` 到 `Media/`** —— 腳本用相對檔名 `save()`，在別的地方跑就把圖寫到別的地方了。
三個檔案會被直接覆蓋，改壞了用 `git checkout` 還原。

需要 Pillow（`python3 -m pip install pillow`）。`roundmark()` 讀
`/System/Library/Fonts/Supplemental/Arial Bold.ttf`，換平台要改那一行。

## 改造型前要知道的三條限制

腳本開頭的 docstring 就是這三條，重複在這裡是因為**它們決定了每一個造型決定**，
不知道的話很容易改出「在設定面板裡很好看、貼到頭像上就糊掉」的東西：

1. **實際顯示 25×25，圖案區只有 ~21px** → 大色塊 + 粗筆畫，細節一律砍掉。
   觀察者那款把人像與放大鏡分佔左上／右下就是為了這個 —— 疊在一起的版本在這個尺寸糊成一團。
2. **貼在 3D 頭像上，背景可能是亮的、花的** → 每個形狀都要有深色描邊（`STROKE`）撐開對比，
   外加 `shadow()` 那層投影。沒有底框時描邊是**唯一**的分離手段，寧可粗。
3. **調性要跟套組一致** → 扁平、白（`LIGHT`）+ 少量套組青（`CYAN` `#4DD2FF`），不要漸層不要擬真。

畫法是 8 倍超取樣後 LANCZOS 縮到 128px，邊緣才不會鋸齒；描邊靠「先畫大一號的深色形狀，
再疊上淺色本體」做出來。

## 新增一款樣式

四個地方要一起動，漏一個就是「選單有這一項但選了沒反應」：

| 檔案 | 改什麼 |
|---|---|
| `scripts/inspect-icons.py` | 加一支畫圖函式，並在 `__main__` 裡呼叫 |
| `Elements/Inspect.lua` 的 `STYLE_DEFS` | 加 `<key> = { texture = MEDIA .. "inspect-<key>.png" }` |
| `Elements/Inspect.lua` 的 `ns.INSPECT_STYLE_ITEMS` | 加下拉選單項（`L["..."]`） |
| `Locales/*.lua` | 九個語系都要有那個 key，跑 `miliui-locale-audit` 技能確認 |

⚠ **不要走「即時用遮罩貼圖畫」那條路。** 圓底問號以前是白方塊套圓形遮罩即時裁出來的，
問題不是不好看，是**失敗時不出聲**：遮罩是外部資產，中途拋錯會被 `BuildElements` 的錯誤
隔離接走，畫面停在上一款的樣子 —— 症狀是「選了圓底問號卻跑出觀察者的圖」，完全指不到原因。
三款走同一條路徑之後，要壞就一起壞、而且壞法看得出來。

同理**不要碰暴雪的 atlas**：實測 Midnight 已經把 `UI-HUD-MicroMenu-CharacterInfo-Up` 拿掉，
而 atlas 消失同樣是靜默的。
