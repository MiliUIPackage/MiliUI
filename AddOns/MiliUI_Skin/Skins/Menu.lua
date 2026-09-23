------------------------------------------------------------
-- 配方：暴雪共用選單的**外框**（`Blizzard_Menu`：下拉選單、右鍵選單、篩選選單…）
--
-- 全遊戲的彈出選單都是同一套（拍賣場「過濾方式」、背包排序、單位右鍵…），所以這一份
-- 一開就是全部一起換。範圍與掛點照 EllesmereUI（`EllesmereUIBlizzardSkin.lua` 的
-- context menu 段落）：**只換選單框的底與邊**，列、勾選框、勾、文字一律不碰。
-- 外觀是**提示皮**（`T.tipFill` ＋ 1px 職業色邊）：浮在世界上方、彈出來讀一眼（STYLE.md ①）。
--
-- 暴雪原始碼出處（Gethe/wow-ui-source live）：
--   Blizzard_Menu/Mainline/MenuTemplates.lua:51-61  `MenuStyle1Mixin:Generate`：
--     `self:AttachTexture()` 一張 → `SetAtlas("common-dropdown-bg")`、錨點往外長 10／3、
--     `SetAlpha(.925)`。**每次開選單都重跑**（選單框是池化的，材質跟著描述重建）。
--   Blizzard_Menu/Menu.lua `MenuManagerMixin:AcquireMenu` → `SecureGenerate`：
--     `Mixin(proxy, menuDescription:GetMenuMixin()); proxy:Generate()` ——
--     `GetMenuMixin()` 解析到**全域** `MenuStyle1Mixin`（WowStyle2 是 `MenuStyle2Mixin`），
--     `Mixin()` 在每次開選單時拷貝 ⇒ 勾在 mixin 表上的後置勾會跟著拷到每一個選單框，
--     `self` 就是那個框 —— 根選單與每一層子選單都接得到。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 對象 | 動作 |
-- |---|---|
-- | `MenuStyle1Mixin.Generate`／`MenuStyle2Mixin.Generate`（全域 mixin 表） | `hooksecurefunc`，內容**只有**把框收進我們自己的待辦表、排一個 `C_Timer.After(0)` |
-- | 選單框自己的貼圖（那張 `common-dropdown-bg`） | `SetAlpha(0)`（`Engine.NeutralizeRegions`），**延一幀之後**才做 |
-- | 選單框 | `Engine.Overlay`（我們自己的子框，提示皮），同樣延一幀 |
--
-- **讀了什麼**：`GetRegions()`（讀結構，只挑貼圖）。不讀選單描述、不讀列的任何東西。
--
-- ## 為什麼延一幀（照抄 Elles 的理由）
-- 後置勾跑在暴雪建選單的保護流程裡；在那裡直接碰暴雪物件，會污染同一條執行流
-- （它實測過：快捷列按鈕被染髒）。所以勾裡只收框，真正上皮在我們自己的計時器裡跑，
-- 那時暴雪那條執行流已經結束。代價是開選單的第一幀看得到原本的圓角底。
--
-- ## 刻意不碰（也是照 Elles）
-- * **`menuDescription:AddMenuAcquiredCallback`**：Elles 明文禁止 —— 那會把插件的函式塞進
--   暴雪的建選單流程、由暴雪**直接呼叫**（沒有 securecall 包著），同一條流程也負責列的點擊。
--   它踩過：右鍵「密語」之後聊天輸入框壞掉（秘密值目標名＋被污染的 OpenChat）。
-- * **選單管理器（`Menu.GetManager()`）上的 `hooksecurefunc`**：Elles 有勾 `OpenMenu`／
--   `OpenContextMenu`，但那是對**暴雪物件實例**做 hooksecurefunc（＝在它身上寫欄位），
--   契約不准；而且 mixin 的 `Generate` 已經涵蓋根選單與子選單，少這兩支不缺東西。
-- * 列、勾選框、勾、單選點、分隔線、子選單箭頭、文字與字色。
--   選單開著時框的 metatable 被 compositor 換掉、不准 `CreateTexture`，本來也只能動那張底。
--
-- ## 照抄不了的地方
-- * Elles 把那張底 `SetColorTexture` 成自己的顏色並重錨 ⇒ 契約只准 alpha 中和、不准重錨
--   暴雪的貼圖；改成中和 ＋ 我們自己的子框 overlay（`Engine.Overlay`：建子框不是在框上建貼圖）。
------------------------------------------------------------
local _, ns = ...

local E = ns.Engine
local T = ns.Tokens
local L = ns.L

local KEY = "Menu"

local function SkinMenu(frame)
    if not E.Usable(frame, KEY) then return end
    -- 池化：同一個框下次開別的選單時，暴雪會重新 Attach 一張底並 SetAlpha(.925)
    -- ⇒ 中和每次都要重下；overlay 是我們的子框，建一次就一直在（Engine.Overlay 冪等）。
    E.NeutralizeRegions(frame, KEY)
    -- ⚠ parent 一定要明確給選單框本身：選單框**沒有 parent**（根選單與子選單都是
    --   無父的頂層框，自己設 strata），交給 SafeParent 往上找不到就會退回 UIParent（MEDIUM）
    --   ⇒ 底跑到拍賣場這類視窗後面，看起來像「背景消失」（2026-09-24 實機）。
    local ov = E.Overlay(frame, { key = KEY, parent = frame })
    if ov then E.Paint(ov, T.tipFill, { T.Accent() }) end
end

local pending, armed, broken = {}, false, false

local function Flush()
    armed = false
    for i = #pending, 1, -1 do
        local f = pending[i]
        pending[i] = nil
        if not broken then
            local ok, err = pcall(SkinMenu, f)
            if not ok then
                broken = true
                E.NoteBrokenHook("MenuStyleMixin:Generate")
                ns.ReportError(err)
            end
        end
    end
end

-- 勾裡只收、不碰（見檔頭「為什麼延一幀」）
local function OnGenerate(frame)
    if broken then return end
    pending[#pending + 1] = frame
    if not armed then
        armed = true
        C_Timer.After(0, Flush)
    end
end

local function Hooks()
    local hooked = false
    for _, name in ipairs({ "MenuStyle1Mixin", "MenuStyle2Mixin" }) do
        local mixin = _G[name]
        if type(mixin) == "table" and type(mixin.Generate) == "function" then
            hooksecurefunc(mixin, "Generate", OnGenerate)
            hooked = true
        end
    end
    if not hooked then E.Missing("MenuStyle1Mixin.Generate") end
end

E.Register{
    key   = "menu",
    title = L["Dropdown Menus"],
    hooks = Hooks,
}
