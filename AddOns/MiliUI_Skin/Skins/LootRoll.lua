------------------------------------------------------------
-- 配方：骰裝彈窗（`GroupLootFrame1..4`，需求／貪婪／塑形／放棄）
--
-- 做法照「成熟同類實作」的骰裝段落搬過來、外觀換成本包的提示皮：
--   * **容器 `GroupLootContainer` 一根手指都不碰**（UIParent 管理的框，
--     STYLE.md ⑦ C 級；`GroupLootContainer_Update` 在受管排版流程裡跑）。
--   * 四顆需求／貪婪／塑形／放棄按鈕**保留暴雪原圖、零腳本、零 overlay**：
--     它們的 OnClick 就是 `RollOnLoot`（送出擲骰請求）。那個實作也保留原圖，
--     理由是「圖示本身就是這個彈窗的識別」；我們多一條：按鈕上什麼都不掛。
--   * 物品圖示方形 ＋ 1px 品質色（傳遞者規則，見下）；計時條換成平面條。
--   * 物品名稱保留暴雪的品質色（只換「框」不換「值」）。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_UIPanels_Game/Mainline/GroupLootFrame.xml:290-536  `GroupLootFrameTemplate`
--     （DIALOG strata、toplevel、277x67）：`Background`（BACKGROUND，LootToast 切片，setAllPoints）／
--     `Border`（BORDER，286x76 CENTER）／`Name`（GameFontNormal）／
--     `IconFrame`（Button 34x34：`Icon` ARTWORK、`Count`、`Border` OVERLAY atlas
--       `loottoast-itemborder-green` 42x42）／`NeedButton`・`PassButton`・`GreedButton`・
--     `TransmogButton`（LootRollButtonTemplate，:3-21，OnClick → `RollOnLoot`）／
--     `Timer`（StatusBar 190x8，`Background` 黑底貼圖、BarTexture `UI-Character-Skills-Bar`、
--       BarColor 黃）／`NeedRollAnim`（擲骰動畫）
--   同檔 :537-549  `GroupLootContainer`（BottomManagedFrameTemplate）＋ `GroupLootFrame1..4`（XML 靜態）
--   Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua
--     :25-41   `GroupLootContainer_AddFrame(self, frame)` → `_Update` → `frame:Show()`
--              ⇒ **OnShow 在這支函式裡同步跑完**，它的後置勾看到的是上好品質的框
--     :108-120 `GroupLootContainer_OpenNewFrame` 用**全域名**呼叫 AddFrame ⇒ 後置勾接得到
--     :162-212 `GroupLootFrame_OnShow`：`IconFrame.Icon:SetTexture`（⇒ texCoord 打回，要重裁）、
--              `IconFrame.Border:SetAtlas(品質 atlas)`（⇒ 只能 alpha）、
--              `self.Name:SetVertexColor(品質色)`、**`self.Border:SetVertexColor(品質色)`**（:176）、
--              `self.Timer:SetFrameLevel(self:GetFrameLevel() - 1)`（:209 ⇒ 計時條在框**之下**，見下）
--     :243-254 `GroupLootFrame_OnUpdate` 只 `GetMinMaxValues`／`SetValue`，**不讀回條的材質**
--              ⇒ `Engine.BarTexture` 換材質安全
--
------------------------------------------------------------
-- ## 品質色從哪裡來（傳遞者規則的新來源）
--
-- 那個實作讀 `GetLootRollItemInfo(f.rollID)` 拿品質再查色 —— 我們不讀 `rollID`
-- （暴雪框上的 Lua 欄位，不在讀取例外表上），也不做它的「彩度 > 0.1 才畫」比較
-- （那是在讀值）。改走傳遞者：`GroupLootFrame_OnShow` 每次都把品質色
-- `SetVertexColor` 到外框那張 `Border` 貼圖上（:176），我們把它**原封不動轉交**給
-- 自己的四條邊（`Engine.PassBorderColor`）。`Border` 已經 alpha 0，但 alpha 不影響
-- `IsShown()` 與 vertex color。
-- ⚠ 這是 `PassBorderColor` 第一次拿**不是 `IconBorder`** 的貼圖當來源 ⇒ STYLE.md ③
--   讀取例外表要多一列（回報裡有）。失敗方向照舊：問不到就 1px 黑邊。
-- ⚠ 普通（白）品質會畫成白邊 —— 那個實作的「白品質＝黑邊」要做比較，做不到。
--
-- ## 為什麼底是子框而不是 `RegionBackdrop`
--
-- 暴雪每次 OnShow 都把 `Timer` 壓到 `框的層級 − 1`（:209），計時條因此畫在框自己的
-- 貼圖**之下**（原圖在那一條留了洞）。我們的不透明提示底要是建成框自己的貼圖，
-- 就會把計時條整條蓋掉。所以底改用 `Engine.Overlay`、層級 `−2`：
-- 在計時條（−1）之下、框之下。⚠ 待實機驗：toplevel 框被點一下會提層，
-- 子框的相對層級應該跟著一起移動（見回報）。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 對象 | 動作 |
-- |---|---|
-- | `GroupLootFrameN.Background`／`.Border` | `SetAlpha(0)` |
-- | `GroupLootFrameN` | 以它為 parent 建一個不吃滑鼠的子框（提示皮底 ＋ 職業色邊），層級 −2 |
-- | `IconFrame.Border`（圓角品質框） | `SetAlpha(0)` |
-- | `IconFrame.Icon` | `SetTexCoord`（裁邊，每次顯示重下） |
-- | `IconFrame` | 以它為 parent 建一個前景子框（1px 品質色方框，不吃滑鼠） |
-- | `Timer` | `SetStatusBarTexture(tuktex)`（`Engine.BarTexture`）；`Background` `SetAlpha(0)`；條自己的底與邊貼圖（`Engine.RegionBackdrop`） |
--
-- **讀了什麼**：parentKey；`GroupLootFrameN.Border` 的 `IsShown()`／`GetVertexColor()`
-- （只經 `Engine.PassBorderColor` 轉交，不存、不比、不算）。**不讀** `rollID`、
-- `GroupLootContainer.rollFrames`／`.maxIndex`（暴雪欄位）；框的全域名只有四個，XML 寫死。
--
-- **hook**：`hooksecurefunc("GroupLootContainer_AddFrame", …)` ×1（全域函式後置勾），
-- 內容只有 `C_Timer.After(0, …)` —— 真正上色的那一段跑在下一幀，**不在**
-- 受管排版（`_Update` → `layoutParent:Layout()`）的執行流裡（那個實作同一個理由）。
-- 不讀它的參數。**四顆擲骰按鈕上：0 個 HookScript、0 個 overlay、0 次 SetAlpha。**
--
-- ## 刻意不碰
-- * `GroupLootContainer`（位置、高度、layoutIndex，全部）。
-- * 需求／貪婪／塑形／放棄四顆按鈕、`NeedRollAnim` 的擲骰動畫、`Name` 的品質色、`Count`。
-- * `BonusRollFrame`（額外戰利品骰；套組本體另有過濾它的功能）。
--
-- ## 照抄不了的地方
-- * 那個實作用 `HookShow(GroupLootContainer)` 與自建 `START_LOOT_ROLL` 事件框當補掃：
--   前者是在 C 級容器上 HookScript OnShow，後者是配方自建事件框，兩者契約都不准。
--   只剩 AddFrame 那一支全域後置勾（它就是 START_LOOT_ROLL 的唯一出口）。
-- * 品質色走「讀 API ＋ 彩度判斷」那條 → 改成轉交 `Border` 的 vertex color（見上）。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

local NUM_FRAMES = 4                  -- GroupLootFrame.lua:1 的 NUM_GROUP_LOOT_FRAMES（local，抄常數）
local TRANSPARENT = { 0, 0, 0, 0 }

local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

local function Required(owner, key, label)
    local child = Optional(owner, key)
    if not child then E.Missing(label) end
    return child
end

-- hook 的共同包裝（同 Skins/EncounterJournal.lua 的 Guard）：出錯一次就停用
local function Guard(label, fn)
    local broken = false
    return function(...)
        if broken then return end
        local ok, err = pcall(fn, ...)
        if not ok then
            broken = true
            E.NoteBrokenHook(label)
            ns.ReportError(err)
        end
    end
end

------------------------------------------------------------
-- 每次顯示都要重申的：裁邊（`Icon:SetTexture` 打回 texCoord）＋ 轉交品質色
------------------------------------------------------------
local function Refresh(f, key)
    if not f or not E.Usable(f, key) then return end
    local iconFrame = Optional(f, "IconFrame")
    if not iconFrame then return end
    local icon = Optional(iconFrame, "Icon")
    if icon then E.CropIcon(icon, key .. ".IconFrame.Icon") end
    local ov = E.GetOverlay(iconFrame, "front")
    if ov then E.PassBorderColor(ov, Optional(f, "Border")) end
end

local function SkinRollFrame(f, key)
    if not E.Usable(f, key) then return end

    E.NeutralizeKeys(f, { "Background", "Border" }, key)

    -- 提示皮（浮在世界上方、彈出來看一眼）。層級 −2：要壓在計時條（−1）之下，見檔頭。
    local ov = E.Overlay(f, { key = key, parent = f, levelOffset = -2 })
    E.Paint(ov, T.tipFill, { T.Accent() })

    local iconFrame = Required(f, "IconFrame", key .. ".IconFrame")
    if iconFrame then
        E.NeutralizeKeys(iconFrame, { "Border" }, key .. ".IconFrame")
        local q = E.Overlay(iconFrame, {
            key = key .. ".IconFrame.quality",
            levelOffset = 1,
            borderSize = T.itemBorderSize,
        })
        E.Paint(q, TRANSPARENT, T.border)
    end

    local timer = Required(f, "Timer", key .. ".Timer")
    if timer then
        Skin.StatusBar(timer, key .. ".Timer", { keys = { "Background" } })
    end

    Refresh(f, key)
end

local function RefreshAll()
    for i = 1, NUM_FRAMES do
        local f = _G["GroupLootFrame" .. i]
        if f then Refresh(f, "GroupLootFrame" .. i) end
    end
end

local function InstallHooks()
    if type(_G.GroupLootContainer_AddFrame) ~= "function" then
        E.Missing("GroupLootContainer_AddFrame")
        return
    end
    local refresh = Guard("GroupLootContainer_AddFrame", RefreshAll)
    hooksecurefunc("GroupLootContainer_AddFrame", function()
        -- ⚠ 只延一幀：不讀參數、不在受管排版的執行流裡做事
        C_Timer.After(0, refresh)
    end)
end

local function Apply()
    for i = 1, NUM_FRAMES do
        local name = "GroupLootFrame" .. i
        local f = _G[name]
        if f then SkinRollFrame(f, name) else E.Missing(name) end
    end
end

E.Register{
    key   = "lootroll",
    title = L["Loot Roll Popups"],
    hooks = InstallHooks,
    apply = Apply,
}
