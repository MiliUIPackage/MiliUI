------------------------------------------------------------
-- 觀察按鈕：貼在單位框上的小按鈕，點下去開暴雪的觀察面板
-- （左右鍵都一樣，不分工）
--
-- 圖示全部用暴雪內建的 atlas／圖示檔，本插件不自帶貼圖；「圓底問號」那款連底
-- 都是白方塊套內建圓形遮罩裁出來的。
--
-- 12.1：可以觀察的只有玩家單位，而玩家單位的身分本來就不受限
-- （受限的定義是「非玩家操控、又不在自己隊伍裡」）→ 顯示閘門用 cache.isPlayer
-- （Cache 已經 ToBool 過）就夠，這裡不再自己讀任何 Unit API。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local Media = ns.Media

------------------------------------------------------------
-- 圖示樣式
--
-- 一律用自己的圖，**不碰暴雪的 atlas**：實測 Midnight 已經把
-- UI-HUD-MicroMenu-CharacterInfo-Up 拿掉（微型選單整組重畫過），而 atlas 消失是
-- 靜默的——畫面上只會變成一張莫名其妙的備援圖示，沒有任何錯誤。
--
-- 三張圖都是畫出來的、不是素材：來源腳本在 `.claude/skills/miliui-inspect-icons/`
-- （開發工具不放插件裡）。改造型就改那支再跑一次，不要拿繪圖軟體修 PNG。
-- 樣式：扁平白 + 套組主色 #4DD2FF 的鏡片，每個形狀都帶深色描邊與投影，
-- 貼在 3D 頭像那種亮的、花的背景上才撐得住對比。
--
-- ⚠ 圓底問號以前是「白方塊套圓形遮罩」即時畫的，已經改成跟另外兩款一樣是圖。
-- 那條路徑的問題不是畫得不好看，是**失敗時不出聲**：遮罩貼圖是外部資產，
-- 中途拋錯會被 BuildElements 的錯誤隔離接走，畫面停在上一款的樣子——症狀是
-- 「選了圓底問號卻跑出觀察者的圖」，完全指不到真正的原因。三款走同一條路徑之後，
-- 要壞就一起壞、而且壞法看得出來。
------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\MiliUI_UnitFrames\\Media\\"

local STYLE_DEFS = {
    inspector = { texture = MEDIA .. "inspect-inspector.png" },
    glass     = { texture = MEDIA .. "inspect-glass.png" },
    round     = { texture = MEDIA .. "inspect-round.png" },
}
ns.INSPECT_STYLE_DEFS = STYLE_DEFS      -- /muf debug 的探針要列

-- 設定面板的下拉選單（唯一來源就是這裡）
ns.INSPECT_STYLE_ITEMS = {
    { text = L["Inspector"],           value = "inspector" },
    { text = L["Magnifier"],           value = "glass" },
    { text = L["Round question mark"], value = "round" },
}

-- 自己的圖四周留白是畫進去的，不要再裁 texcoord（那是給暴雪 icon 檔用的，
-- 它們四邊各有一圈邊框留白）；明寫 0,1 是為了洗掉舊版本留下的裁切
local function ApplyIcon(tex, style)
    local def = STYLE_DEFS[style] or STYLE_DEFS.inspector
    tex:SetTexture(def.texture)
    tex:SetTexCoord(0, 1, 0, 1)
end

------------------------------------------------------------
-- 動作：交給暴雪的安全巨集 `/inspect`
--
-- 以前是自己的 OnClick 呼叫 InspectUnit(unit)。那條流程不安全，InspectFrame.unit
-- 從此帶著我們的 taint，天賦頁把單位交給 PlayerSpellsFrame 之後「複製」按
-- CopyToClipboard（保護函式）就被封鎖，帳算到 MiliUI_UnitFrames 頭上。
--
-- 改法：按鈕本身用 SecureActionButtonTemplate，type="macro"、macrotext="/inspect"，
-- 點下去由暴雪的巨集執行器跑，InspectFrame.unit 由安全流程寫入，後面天賦／複製
-- 全部乾淨。跟右鍵選單走 /click 代理鈕 → togglemenu 是同一套機制。
--
-- ⚠ `/inspect` 寫死觀察 target（SlashCommands.lua：InspectUnit("target")），沒有
--   單位參數。這顆按鈕目前只掛在目標框（DB.lua 的 target 區塊），所以剛好夠用；
--   將來要在焦點框加觀察鈕的話，那顆沒有 secure 入口，只能走舊路。
--
-- ⚠ 變成 secure 框之後，戰鬥中 Show/Hide/EnableMouse/SetPoint/SetAttribute 全部
--   被擋（EnableMouse 也在保護清單裡）。所以：
--   • 屬性與版面只在 Build 寫（Build 不會在戰鬥中跑，跟單位框本身一樣）
--   • 「不是玩家就不畫」改用 alpha 表達（SetAlpha 不受保護），另外用一片普通的
--     遮擋框蓋在上面吃掉滑鼠——遮擋框不是 secure、也不是 secure 框的父層，
--     戰鬥中 Show/Hide 合法。遮擋框把點擊往父層傳，對 NPC 目標時那個角落
--     就跟框的其他地方一樣是選取目標。
------------------------------------------------------------
local INSPECT_MACRO = "/inspect"

local function ArmSecure(btn)
    if btn.secureArmed or InCombatLockdown() then return end
    btn.secureArmed = true
    btn:RegisterForClicks("AnyUp")
    -- secure 解析是按「按鈕後綴」查 type（RightButton→type2），裸 type 不保證備援，
    -- 每個後綴都設；左右鍵同一件事（右鍵也接住是為了不要穿過去變成單位框的右鍵選單）
    btn:SetAttribute("type", "macro")
    for i = 1, 5 do btn:SetAttribute("type" .. i, "macro") end
    btn:SetAttribute("macrotext", INSPECT_MACRO)
    -- 不管「按鍵按下時施放」CVar 設哪邊都在放開那一下執行
    btn:SetAttribute("useOnKeyDown", false)
end

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Inspect"], 1, 1, 1)
    GameTooltip:AddLine(L["Opens the inspect window."], 0.4, 1, 0.4)
    GameTooltip:Show()
end

local function OnLeave()
    GameTooltip:Hide()
end

------------------------------------------------------------
-- 建構／更新
------------------------------------------------------------
-- 高亮貼圖依情況換：有底框時用白方塊罩整顆，光禿禿只有圖示時改用圖示自己
-- （白方塊會在透明的地方憑空冒出一個方塊）。
--
-- ⚠ 判斷要連貼圖一起比。只看「種類」的話，在同一種類裡換樣式（放大鏡→觀察者，
-- 兩款都是無底框）貼圖不會更新——症狀是滑過去亮出來的是**上一款**的圖。
local function SetHighlight(btn, kind, texture)
    if btn.hlKind ~= kind or btn.hlTexture ~= texture then
        btn.hlKind, btn.hlTexture = kind, texture
        btn:SetHighlightTexture(texture, "ADD")
    end
    local hl = btn:GetHighlightTexture()
    hl:SetVertexColor(1, 1, 1, kind == "icon" and 0.45 or 0.15)
    return hl
end

local function Build(uf, edb)
    local btn = uf.elements.inspect
    if not btn then
        btn = ns.CreateElementBase(uf, "inspect", "Button", "SecureActionButtonTemplate, BackdropTemplate")
        btn.bg = btn:CreateTexture(nil, "BACKGROUND")
        btn.bg:SetTexture(Media.WHITE8X8)
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        -- ⚠ 不要 SetScript("OnClick")：那會蓋掉模板的 SecureActionButton_OnClick
        btn:SetScript("OnEnter", OnEnter)
        btn:SetScript("OnLeave", OnLeave)
        -- 遮擋框：普通 Frame，掛在單位框下（不是按鈕的父層），吃掉非玩家時的滑鼠
        local shield = CreateFrame("Frame", nil, uf)
        shield:EnableMouse(true)
        shield:SetPropagateMouseClicks(true)
        shield:Hide()
        btn.shield = shield
    end
    ns.ApplyElementBase(uf, btn, edb)
    btn.baseAlpha = edb.alpha or 1
    ArmSecure(btn)
    -- 預覽孿生上的按鈕只是排版用：關掉滑鼠，免得它把編輯模式的拖曳吃掉
    btn:EnableMouse(not uf.isPreview)
    local shield = btn.shield
    shield:ClearAllPoints()
    shield:SetAllPoints(btn)
    shield:SetFrameLevel(btn:GetFrameLevel() + 1)

    -- 邊框有畫就要內縮，內縮量一律問 BorderInset（直接寫 1 會在 Retina 露縫）
    local bordered = edb.border ~= false
    local inset = bordered and Media.BorderInset() or 0
    local c = edb.bgColor or { r = 0, g = 0, b = 0, a = 0.6 }
    -- 沒邊框又沒底色 = 圖示直接浮在框上（預設），那時整套底框都不要畫
    local bare = not bordered and (c.a or 1) <= 0
    local def = STYLE_DEFS[edb.style] or STYLE_DEFS.glass

    if bordered then
        Media.ApplyBorder(btn)
    else
        btn:SetBackdrop(nil)
    end

    btn.bg:ClearAllPoints()
    btn.bg:SetPoint("TOPLEFT", inset, -inset)
    btn.bg:SetPoint("BOTTOMRIGHT", -inset, inset)
    btn.bg:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    btn.bg:SetShown(not bare)

    local pad = inset + ns.P.Scale(edb.iconPadding or 0)
    btn.icon:ClearAllPoints()
    btn.icon:SetPoint("TOPLEFT", pad, -pad)
    btn.icon:SetPoint("BOTTOMRIGHT", -pad, pad)
    ApplyIcon(btn.icon, edb.style)
    btn.icon:Show()

    -- 有底框：高亮跟著內縮，不然滑過去會把邊框一起蓋掉
    -- 光禿禿：高亮就是圖示本身，貼齊圖示才不會位移
    local hl = SetHighlight(btn, bare and "icon" or "rect", bare and def.texture or Media.WHITE8X8)
    local edge = bare and pad or inset
    hl:ClearAllPoints()
    hl:SetPoint("TOPLEFT", edge, -edge)
    hl:SetPoint("BOTTOMRIGHT", -edge, edge)

    -- 顯示與否由 Update 決定；secure 框戰鬥中不能 Show/Hide，所以這裡一律 Show、
    -- 之後只動 alpha 與遮擋框（Build 不在戰鬥中跑，保險起見還是閘一下）
    if not InCombatLockdown() then btn:Show() end
end

local function Update(uf, edb)
    local btn = uf.elements.inspect
    if not btn then return end
    -- 預覽一律畫出來：對著空氣調位置很痛苦
    -- 只有玩家觀察得了 → 其他單位一律不畫，不然就是一顆按不動的按鈕
    local shown = uf.isPreview or (uf.cache.isPlayer and true or false)
    btn:SetAlpha(shown and (btn.baseAlpha or 1) or 0)
    btn.shield:SetShown(not shown)
end

ns.RegisterElement{
    name = "inspect",
    order = 75,
    -- 「是不是玩家」跟著身分欄位走，跟隊長圖示／PvP 圖示同一個桶
    buckets = { "reaction" },
    build = Build,
    update = Update,
}
