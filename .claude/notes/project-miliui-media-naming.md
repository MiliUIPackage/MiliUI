---
name: project-miliui-media-naming
description: "套組自製材質的命名與顯示規則（2026-11-06 使用者拍板）：LSM 登記名 `MiliUI <英文名>` 永遠不翻、中文顯示名 `米利UI: <譯名>`、下拉裡置頂；名冊與譯名只有一份在共用 vendor Libs/MiliUIMedia，六支有材質下拉的插件都接它"
metadata:
  node_type: memory
  type: project
  originSessionId: 1dd27889-afe0-4ec4-b88c-da42c1bfaab7
  modified: 2026-11-06T04:10:19.787Z
---

2026-11-06 使用者看 MCDM 的材質下拉（MiliUI Rainbow／Rainbow Soft／Satin 夾在字母順序中間、沒中文）要求：
米利的材質**要有繁簡中文名、放最上面**，寫成規則、**所有材質都照這套**、命名與翻譯統一，格式指定 **`米利UI: XXXX`**。

**規則**
- **登記名**（LibSharedMedia key＝存檔值＝英文顯示名）：`MiliUI <英文名>`，純 ASCII，**永遠不翻、不改**——它在存檔與匯入字串裡，
  也是別家插件材質選單看到的名字。在地化只做在**我們自己下拉的顯示文字**（這是我的判斷：翻 key 會讓舊存檔與跨語系分享的設定找不到圖）。
- **中文顯示名**：`米利UI: <譯名>`，半形冒號＋一個空白，繁簡各一份；變體用全形括號接後面（`米利UI: 彩虹（柔和）`）。
  其他語系照登記名原樣。現有款式以名冊為準（Satin＝緞面／缎面、Rainbow＝彩虹、Rainbow Soft＝彩虹（柔和），同日另一個 session 加了 Cosmos／Lightning／Lava／Flame 四款施法條動畫材質）。
- **順序**：不是材質的項目（跟隨…／預設）→ 米利的材質（名冊順序，Satin 第一）→ 保留項（純色、暴雪施法條）→ 其餘 LSM。
- **譯名只寫在名冊**：`AddOns/MiliUI/Libs/MiliUIMedia/MiliUIMedia.lua`（單檔 vendor，`sync-widgets.py` 鋪到各插件的 `Libs/MiliUIMedia.lua`，
  掛 `ns.MiliMedia`、無全域、不依賴 LSM）。**不要進各插件語系檔**——之前就是各翻各的（單位框／傷害統計「內建（Satin）」、滑鼠提示寫死英文）。
  規則由 source 旁的 `Tests/MiliUIMedia_test.lua` 守（前綴、繁簡都要有、順序）。

**How to apply:** 新增一款材質＝名冊 `TEXTURES` 加一列（含 zhTW／zhCN）→ 跑 `sync-widgets.py` → 帶檔的那支在自己的 `Core/Media.lua` 登記 LSM。
新插件要材質下拉＝複製 `Libs/MiliUIMedia.lua`、TOC 排在 `Libs\Callbacks.lua` 後面，下拉用 `ns.MiliMedia.TextureItems(lsmList, always)` 拿 `own, rest` 兩段，
自己帶檔的材質放 `always = { [登記名] = 存檔值 }`（清單裡沒有也列）。MCDM 另有 `ns.Media.OWN_TEXTURES` 與 `Specs.InsertAfterSolid`（純色的位置不能寫死索引）。
消費者：MCDM、UnitFrames、DamageMeters、Tooltip、BossTimeline、CrusadingStrikes、**Cell**（同日使用者說「Cell 也套」）。
- **Cell 的接法不一樣**：`Libs/LoadLibs.xml` 載 `MiliUIMedia.lua`（掛 `Cell.MiliMedia`），`Utils.lua` 的 `F.SortBarTextureNames`／`F.GetBarTextureLabel`
  給外觀頁（`Modules/Appearance/Appearance.lua` 的 `CheckTextures`）與快速協助（`Utilities/QuickAssist_Config.lua` 的 `LoadTextures`）兩個材質選單用；
  順序是 米利的材質 → 「Cell 預設」→ 其餘。⚠ Cell 的下拉 `SetSelected(text, …)` **比對的是顯示文字**不是登記名，
  所以還原選取時要傳 `F.GetBarTextureLabel(存檔名)`——直接傳存檔名在中文客戶端會選不到、下拉顯示空白。
- **沒做的**：字型／音效／邊框沒有自製登記名，未套這套。MCDM 的動畫材質在別支插件（含 Cell）的下拉裡選到只有靜態底圖，動畫只有 MCDM 施法條做。
相關：[[project-miliui-satin-texture]]、[[project-miliui-widgets-vendor]]、[[project-miliui-cooldownmanager]]
