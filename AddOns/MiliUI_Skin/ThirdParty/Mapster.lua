------------------------------------------------------------
-- 伴隨元件：套組內建的地圖增強插件（掛在世界地圖上）
--
-- 世界地圖換皮之後，標題帶右上還擺著它那顆原生紅色的「地圖增強」按鈕，
-- 跟 Postal 那一排當初的情況一樣 ⇒ 走 STYLE.md ③ 的「伴隨元件」。
--
-- ## 掛了哪些元件
--
-- | 全域名稱 | 是什麼 | 模板 | 建立時機 | 用哪個原語 |
-- |---|---|---|---|---|
-- | `MapsterOptionsButton` | 世界地圖標題帶右上「地圖增強」（開它的設定頁） | `UIPanelButtonTemplate` | `Mapster:OnEnable`（`PLAYER_LOGIN`）→ `SetupMapButton`（`Mapster/Config.lua`） | `Skin.Button`，`secondary` |
--
-- 為什麼是 secondary：它是「開設定頁」的導覽鈕，不是這個視窗的主動作
-- （`project-miliui-button-variants` 判準 5／6）。世界地圖上沒有 primary。
--
-- ## 觸發時機與理由
--
-- `atLogin = true`。按鈕是 AceAddon 在 `PLAYER_LOGIN` 的 `OnEnable` 裡建的，
-- 不是「地圖第一次打開才建」—— 沒有一個暴雪事件擺在對的時間點上。
-- `atLogin` 在 `Engine.Boot` 之後再延一幀跑，那時 `PLAYER_LOGIN` 已經派送完，
-- 所以不是在賭載入順序。
--
-- ⚠ 已知缺口：玩家在它的設定裡先勾「隱藏地圖按鈕」登入、之後才取消勾選，
--   按鈕是那一刻才建的 ⇒ 要 /reload 才有皮。不為了這個去 hook 它的函式（③ 第 3 條）。
--
-- host ＝ `worldmap`；單獨關掉走設定頁「其他插件」那一節（`addonKey = "mapster"`）。
--
------------------------------------------------------------
-- ## taint 接觸面清單（伴隨元件）
--
-- ⚠ 這一份**一個暴雪物件都沒有碰**（按鈕的 parent 是 `WorldMapFrame.BorderFrame.TitleContainer`，
--   但我們只動按鈕自己）。
--
-- | 物件 | 動作 |
-- |---|---|
-- | `MapsterOptionsButton` 的 `Left`／`Right`／`Middle` | `SetAlpha(0)`（`Skin.Button`） |
-- | 同一顆 | `SetNormalFontObject(GameFontHighlight)` |
-- | 同一顆的 Highlight | `SetAlpha(0)`（滑過自己畫，`Engine.TrackButtonHover`） |
-- | 同一顆 | `CreateFrame` 掛自己的 overlay（錨在它身上、不吃滑鼠、零腳本） |
--
-- hook：**一支都沒有掛在它的函式上**。只有原語內建的
--   `HookScript("OnEnter"/"OnLeave"/"OnEnable"/"OnDisable")`，只碰我們自己的 overlay。
-- 寫入它的欄位：無。讀它的物件：只有 `_G[名字]` 在不在。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * 按鈕的位置、寬高、文字內容（`SetPoint`／`SetSize` 契約禁止）。
-- * 它的設定頁（AceConfig 面板，住在暴雪「選項 > 插件」裡）。
-- * 它對世界地圖本身做的事（縮放、淡出、移位）—— 那是它的功能，不是外觀。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine

local function Apply()
    -- ⚠ `_G[...]` 找不到就靜默跳過，不走 `E.Missing`（③ 第 2 條）
    local btn = _G.MapsterOptionsButton
    if btn then
        Skin.Button(btn, "MapsterOptionsButton", { variant = "secondary" })
    end
end

E.AddCompanion("worldmap", {
    atLogin  = true,
    addonKey = "mapster",
    apply    = Apply,
})
