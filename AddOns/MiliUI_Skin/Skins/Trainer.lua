------------------------------------------------------------
-- 配方：訓練師（`ClassTrainerFrame`，隨需載入 `Blizzard_TrainerUI`）
--
-- 第十二／十三輪。範圍與掛點照「成熟同類實作」的訓練師段落搬：外框、兩塊內嵌只淡不畫、
-- 篩選下拉、捲軸、「訓練」鈕、技能等級條、技能清單的每一列（方形圖示、底圖淡掉、
-- 滑過／選中換成平面的明暗）、專業訓練師上方那顆「下一階」技能鈕。外觀換成這一包的皮。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_TrainerUI/Blizzard_TrainerUI_Mainline.toc:2  `## LoadOnDemand: 1`
--   Blizzard_TrainerUI/Mainline/Blizzard_TrainerUI.xml:28
--     `ClassTrainerSkillButtonTemplate`（**沒有 mixin**）：`money`（SmallMoneyFrameTemplate）／
--     `icon`（OVERLAY）／`name`（GameFontNormal）／`subText`／`selectedTex`（OVERLAY 1，ADD，
--     **Lua 依選中 Show/Hide**）／`lock`／`disabledBG`（BACKGROUND，MOD 灰，不可學時 Show）／
--     NormalTexture（`TrainerTextures` 的列底）／HighlightTexture `$parentHighlight`（ADD）
--   同檔 :110 `ClassTrainerFrame` ← ButtonFrameTemplate：
--     `$parentMoneyBg`（ARTWORK）／`$parentBg` parentKey **`BG`**（BACKGROUND，TrainerTextures ——
--     ⚠ 跟 ButtonFrameBaseTemplate 的 `Bg`（岩石底）是**兩張**，全域名 `ClassTrainerFrameBg`
--     被後宣告的這一張蓋走）／`ClassTrainerStatusBar`（Left/Right/Middle/Background **只有全域名**）／
--     `FilterDropdown`（WowStyle1FilterDropdownTemplate）／`ClassTrainerTrainButton`（MagicButtonTemplate
--     ← UIPanelButtonTemplate，SharedUIPanelTemplates.xml:722）／`$parentMoneyFrame`／
--     `skillStepButton`（ClassTrainerSkillButtonTemplate，**XML 期建、不是池化**）／
--     `ScrollBox`（WowScrollBoxList）／`ScrollBar`（MinimalScrollBar）／`bottomInset`（InsetFrameTemplate）
--   Blizzard_TrainerUI/Mainline/Blizzard_TrainerUI.lua:47-53  ScrollBox 的 initializer 是 local，
--     裡面只呼叫**全域** `ClassTrainerFrame_InitServiceButton(button, elementData)`
--   同檔 :197-319 `ClassTrainerFrame_InitServiceButton`：
--     `icon:SetTexture`（⇒ texCoord 被打回，裁邊要 reapply）、`icon:SetDesaturated`、
--     `name:SetText`（不可學時字串裡帶灰色碼）、`disabledBG:Show/Hide`、
--     **`selectedTex:Show()/Hide()`（:303,309）**、`SetMoneyFrameColorByFrame`（金錢字色＝資訊）
--     ⇒ 所有路徑（捲動重用、點選、`TRAINER_UPDATE`、`skillStepButton`）都走這一支。
--   同檔 :120-139 `ClassTrainerFrame_SetTrainButtonEnabled`：**對「訓練」鈕 `SetScript("OnEnter"/"OnLeave")`**
--     ⇒ 那顆上任何 HookScript 都會被蓋掉；而且它按下去就是 `BuyTrainerService`（花錢）⇒ 零腳本。
--   同檔 :44-45 `BG` 被 Lua 重錨到 ScrollBox（只有 SetPoint，沒有換材質）⇒ alpha 中和撐得住。
--
------------------------------------------------------------
-- ## 照抄的做法 ／ 照抄不了的地方
--
-- 照抄：
--   * 外框整組美術淡掉（兩張 Bg、金錢框的邊、九宮格、肖像），標題白字，關閉鈕。
--   * **兩塊 Inset 只淡掉美術、不另畫內嵌底**。
--   * 篩選下拉、捲軸、「訓練」鈕（它是一般按鈕，我們是零腳本 primary）。
--   * 技能等級條：裝飾全淡掉、填充換平面材質、等級字白。
--   * 技能列：`NormalTexture`（列底）淡掉、`disabledBG` 淡掉、圖示方形、滑過與選中換平面的明暗。
--   * 「下一階」技能鈕：同一套列的皮。
-- 照抄不了：
--   * 它在 `ScrollBox` **實例**的 `Update` 掛後置勾重掃每一列 —— 我們改勾**全域**
--     `ClassTrainerFrame_InitServiceButton`（`Engine.HookRows{ mixin = _G }`），每一列每次初始化都會進來。
--   * 它把 `selectedTex`／`Highlight` 直接 `SetColorTexture` 成白 15%／10%：`selectedTex` 是
--     **Lua 在 Show/Hide 的一般貼圖**，不是 C 端依狀態顯示的那幾張，不在 `SetColorTexture` 的白名單上。
--     改成：`selectedTex` alpha 0，選中態由我們自己的 overlay 畫（壓暗職業色底 ＋ 左緣 2px 職業色條，
--     `Skin.Row` 的 `ownHover`），選中與否在後置勾裡讀 `selectedTex:IsShown()` ——
--     暴雪在**同一支函式**裡剛 Show/Hide 它（讀取例外表的同型條目，見下面「讀了什麼」）。
--   * 「下一階」技能鈕的重錨（貼齊視窗全寬、加高 15、上移 5）與它加的那張 `Ui-Dialog-New-Background`
--     半透明底：`ClearAllPoints`／`SetPoint`／`SetHeight`／`CreateTexture`＋`SetAtlas` 全是契約禁止的。
--   * 篩選下拉的「文字靠左」：重錨下拉裡的 FontString，禁止。
--   * 它的 `HookScript("OnShow")` 重跑：我們的中和全是 alpha、列靠後置勾，不需要。
--
-- ## 刻意不碰
--   * 列上的金錢（`money`，`SetMoneyFrameColorByFrame` 的白／紅＝買不買得起）、`subText`
--     （紅字＝條件不足）、`lock` 鎖頭、圖示的去飽和（不可學）。
--   * 視窗底部的 `ClassTrainerFrameMoneyFrame`（玩家的錢）。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 對暴雪物件做的事（全部在白名單內）
--
-- | 對象 | 動作 |
-- |---|---|
-- | `ClassTrainerFrame` 自己的每一張貼圖（`Bg`／`BG`／`TopTileStreaks`／`$parentMoneyBg`，`GetRegions`） | `SetAlpha(0)` |
-- | NineSlice／PortraitContainer | `SetAlpha(0)`（`Skin.PortraitChrome`） |
-- | `ClassTrainerFrame` 本身 | `Engine.RegionBackdrop`（底＋邊＋標題帶） |
-- | `TitleContainer.TitleText` | `SetTextColor` |
-- | `Inset`／`bottomInset` 的 Bg／NineSlice | `SetAlpha(0)`（不畫底） |
-- | `CloseButton` | `Skin.CloseButton` |
-- | `FilterDropdown` | `Skin.Dropdown`（filter，白字走 `Engine.DropdownText`） |
-- | `ScrollBar` | `Skin.ScrollBar` |
-- | `ClassTrainerTrainButton` | 零腳本 primary（`Engine.ScriptlessButton`） |
-- | `ClassTrainerStatusBar` 的四張裝飾（`GetRegions`，排除填充） | `SetAlpha(0)`；填充換 `T.barTexture`（`Engine.BarTexture`）＋ `SetVertexColor`（XML 的藍） |
-- | 技能列與 `skillStepButton`：NormalTexture／PushedTexture／HighlightTexture／`disabledBG`／`selectedTex` | `SetAlpha(0)` |
-- | 同上：`name` | `SetTextColor(text)`（暗金→白；不可學時字串自帶灰色碼，照樣是灰的） |
-- | 同上：`icon` | `SetTexCoord`（裁邊，每次初始化重下）＋ 1px 黑邊 overlay |
--
-- ### 讀了什麼
-- * 結構：parentKey、`GetRegions()`、`GetObjectType`。
-- * **`row.selectedTex:IsShown()`**（`InitServiceButton` 的後置勾裡）：暴雪在同一支函式的
--   :303／:309 對它 `Show()`／`Hide()`，它就是暴雪自己表達「這一列是選中的」的依據；
--   純 C 端布林、過 `Secret.ToBool`，問不到就當「沒選中」（少一條職業色線，失敗方向安全）。
--   ⚠ 這一條要**補進 STYLE.md ③ 的讀取例外表**（同「成就子目標的 `Check:IsShown()`」那一型）。
-- * **不讀** `elementData`（後置勾的第二個參數原封不動丟掉）、`skillIndex`、`selectedService`、
--   `GetID()`、任何技能或金錢資料。
--
-- ### 掛了哪些 hook
--
-- | hook | 型別 | 裡面做什麼 |
-- |---|---|---|
-- | `hooksecurefunc("ClassTrainerFrame_InitServiceButton", …)` | 全域函式後置勾（`Engine.HookRows{ mixin = _G }`） | 第一次見到這一列：中和、建 overlay；每次：重裁圖示、讀 `selectedTex:IsShown()` 換選中底色。**不讀第二個參數** |
-- | 列的 `HookScript("OnEnter"/"OnLeave")`（`Skin.Row` 的 `ownHover` → `Engine.TrackSelectable`） | frame script 後掛 | 只換我們自己 overlay 的底色（滑過提亮一階） |
-- | 關閉鈕、篩選下拉的 `HookScript("OnEnter"/"OnLeave")` | frame script 後掛 | 同上 |
--
-- **「訓練」鈕上的 `HookScript`：0 支。`hooksecurefunc` 在 `ClassTrainerFrame` 實例上：0 支。
-- `HookScript("OnShow")`：0 支。**
-- 後置勾的執行時機：`BuyTrainerService` 是 `ClassTrainerTrainButton_OnClick`／確認彈窗的 `OnAccept`
-- 裡**先**呼叫的（Blizzard_TrainerUI.lua:18,402），列的重新初始化排在它**後面**，而且
-- `hooksecurefunc` 的後置勾跑完就把執行權的 taint 還原 ⇒ 購買那一步的執行流裡沒有我們的 Lua。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L
local S = ns.Secret

------------------------------------------------------------
-- 小工具（跟 `Skins/PlayerSpells.lua` 同一組寫法）
------------------------------------------------------------
local function Sub(owner, key, label)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then
        return child
    end
    E.Missing(label)
    return nil
end

local function Optional(owner, key)
    if type(owner) ~= "table" then return nil end
    local child
    if pcall(function() child = owner[key] end) and child then return child end
    return nil
end

------------------------------------------------------------
-- 零腳本按鈕（同 `Skins/PlayerSpells.lua`）
-- TODO(升格): 見 `Skins/Macro.lua` 同名那一支的 TODO。
------------------------------------------------------------
local PANEL_BUTTON_ART = { "Left", "Right", "Middle" }

local function ScriptlessButton(btn, key, variant)
    if not E.Usable(btn, key) then return nil end
    local ov = E.Overlay(btn, { key = key })       -- 先建 overlay 再中和
    if not ov then return nil end
    E.NeutralizeKeys(btn, PANEL_BUTTON_ART, key)
    E.ButtonFonts(btn, GameFontHighlight, key)
    E.ScriptlessButton(btn, ov, variant or "primary", key)   -- **不掛腳本**
    return ov
end

------------------------------------------------------------
-- 技能列（`ClassTrainerSkillButtonTemplate`）
--
-- 列底換成 `fillInset`：面板本身是 `fill`，列要是同色，滑過之前整張清單就是一片空白。
-- `Skin.Row` 的 `ownHover`：暴雪的 Highlight 中和、滑過與選中都由我們畫在同一個矩形上
-- （選中＝壓暗的職業色底 ＋ 左緣 2px 職業色條，④「清單列的選中／滑過語彙」）。
-- `disabledBG`（MOD 灰）與 `selectedTex` 一起中和：前者成熟同類實作也淡掉（不可學的列
-- 靠去飽和的圖示與灰字已經看得出來），後者換成我們的選中態。
------------------------------------------------------------
local ROW_ART_KEYS = { "disabledBG", "selectedTex" }
local rowCount = 0

local function RowKey(row)
    local st = E.State[row]
    if st and st.trainerKey then return st.trainerKey end
    rowCount = rowCount + 1
    local key = "ClassTrainerFrame.row" .. rowCount
    st = st or {}
    st.trainerKey = key
    E.State[row] = st
    return key
end

local function ApplyRow(row)
    local key = RowKey(row)
    Skin.Row(row, key, { fill = T.fillInset, ownHover = true, keys = ROW_ART_KEYS })

    local name = Optional(row, "name")
    if name then E.TextColor(name, T.text, key .. ".name") end

    local icon = Optional(row, "icon")
    if icon then Skin.Icon(icon, key .. ".icon") end
end

local function ReapplyRow(row)
    -- `icon:SetTexture` 每次都把 texCoord 打回 0,1（Blizzard_TrainerUI.lua:210）
    local icon = Optional(row, "icon")
    if icon then E.CropIcon(icon, "ClassTrainerFrame.row.icon") end

    -- 選中態：讀暴雪剛 Show/Hide 的那張（檔頭「讀了什麼」）
    local sel = Optional(row, "selectedTex")
    local selected = false
    if sel and type(sel.IsShown) == "function" then
        local ok, v = pcall(sel.IsShown, sel)
        if ok then selected = S.ToBool(v) == true end
    end
    E.SetSelected(row, selected)
end

local rowSweep

------------------------------------------------------------
-- 外框
------------------------------------------------------------
-- XML 的 `<BarColor r="0" g="0" b="1" a="0.5"/>`（Blizzard_TrainerUI.xml:175）抄成常數，
-- 換材質之後用貼圖的 SetVertexColor 重下一次（同收藏視窗的做法：萬一換材質把顏色重置
-- 就沒人補得回來）。這是暴雪自己的顏色，不是我們挑的。
local TRAINER_BAR_COLOR = { 0, 0, 1, 0.5 }

local function SkinChrome(f)
    E.NeutralizeRegions(f, "ClassTrainerFrame")      -- 兩張 Bg、TopTileStreaks、金錢框的邊
    Skin.PortraitChrome(f, "ClassTrainerFrame")
    Skin.Panel(f, "ClassTrainerFrame")

    for _, k in ipairs({ "Inset", "bottomInset" }) do
        local inset = Optional(f, k)
        if inset then
            E.NeutralizeKeys(inset, { "Bg", "NineSlice" }, "ClassTrainerFrame." .. k)
        else
            E.Missing("ClassTrainerFrame." .. k)
        end
    end

    local close = Sub(f, "CloseButton", "ClassTrainerFrame.CloseButton")
    if close then Skin.CloseButton(close, "ClassTrainerFrame.CloseButton") end

    local dd = Sub(f, "FilterDropdown", "ClassTrainerFrame.FilterDropdown")
    if dd then Skin.Dropdown(dd, "ClassTrainerFrame.FilterDropdown", "filter") end

    local bar = Sub(f, "ScrollBar", "ClassTrainerFrame.ScrollBar")
    if bar then Skin.ScrollBar(bar, "ClassTrainerFrame.ScrollBar") end

    -- 「訓練」：按下去就是 `BuyTrainerService`（花錢）⇒ 零腳本、primary（這個視窗唯一的執行鈕）
    local train = _G.ClassTrainerTrainButton
    if train then
        ScriptlessButton(train, "ClassTrainerTrainButton", "primary")
    else
        E.Missing("ClassTrainerTrainButton")
    end

    -- 技能等級條（專業訓練師才顯示）。裝飾只有全域名 ⇒ `stripArt` 走 `GetRegions`，填充排除在外。
    local sbar = _G.ClassTrainerStatusBar
    if sbar then
        Skin.StatusBar(sbar, "ClassTrainerStatusBar", { stripArt = true, color = TRAINER_BAR_COLOR })
        local rank = Optional(sbar, "rankText")
        if rank then E.TextColor(rank, T.text, "ClassTrainerStatusBar.rankText") end
    else
        E.Missing("ClassTrainerStatusBar")
    end
end

------------------------------------------------------------
-- hooks：一支全域函式後置勾
--
-- 列是 ScrollBox 第一次 `SetDataProvider`（視窗 OnShow）才建的，而那比 ADDON_LOADED 晚
-- ⇒ 在 `hooks` 裝就接得到每一列。`skillStepButton` 是 XML 期建的，但它同樣只經由這一支
-- 更新（Blizzard_TrainerUI.lua:169,383），第一次更新時就會被接住；`Apply` 另外補一次。
------------------------------------------------------------
local function InstallHooks()
    rowSweep = E.HookRows{
        key     = "ClassTrainerFrame_InitServiceButton",
        mixin   = _G,
        method  = "ClassTrainerFrame_InitServiceButton",
        apply   = ApplyRow,
        reapply = ReapplyRow,
    }
end

local function Apply()
    local f = _G.ClassTrainerFrame
    if not f then
        E.Missing("ClassTrainerFrame")
        return
    end
    if not E.Usable(f, "ClassTrainerFrame") then return end

    SkinChrome(f)

    if rowSweep then
        local box = Optional(f, "ScrollBox")
        if box then E.SweepRows(box, "ClassTrainerFrame.ScrollBox", rowSweep) end
        local step = Optional(f, "skillStepButton")
        if step then rowSweep(step) end
    end
end

E.Register{
    key   = "trainer",
    addon = "Blizzard_TrainerUI",
    title = L["Trainer"],
    hooks = InstallHooks,
    apply = Apply,
}
