------------------------------------------------------------
-- 「加入一鍵購買清單」按鈕：製作頁與代工下單頁共用的外觀、狀態與位置
--
-- 位置：材料區標題（「材料：」／「提供施法材料：」）的**右邊、同一列**。
--   * 按鈕講的就是底下那排材料 —— 放在那一區的標題旁，視線讀完標題就看到動作
--   * 標題列的左半是固定的；配方標題那一塊不行：名字長度會變，重新製作的標題
--     「重新製作：xxx」很長，原本貼在標題右上角的按鈕實測整顆蓋在標題上
--   * 材料區的右半也不行：製作頁的詳細資訊面板貼在右上（-20, -125）
--   * 兩頁同一個位置，玩家學一次就會
--
-- 說明文字只在滑鼠移上去時出現（工具提示第一行），平常畫面上只留按鈕本身。
--
-- ⚠ taint 紀律：錨在暴雪的標題字上、讀它的字寬，但**不寫**暴雪框上任何東西。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local AddButton = {}
ns.AddButton = AddButton

local GAP    = 10   -- 標題文字與按鈕之間
local PAD_X  = 12   -- 按鈕左右內距
local HEIGHT = 20   -- ＝材料區標題列的高度：再高就會壓到底下第一排材料的上緣
local MIN_W  = 96

local function Label()
    return L["Add to one-click buy list"]
end

local function TextWidth(fs)
    if not fs then return 0 end
    local w = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
    return tonumber(w) or 0
end

function AddButton.Create(parent, onClick, fillTooltip)
    local b = ns.W.CreateButton(parent, Label(), "accent-hover", MIN_W, HEIGHT)
    -- 停用時滑過也要有提示：「為什麼不能按」本身就是要講的資訊
    b:SetMotionScriptsWhileDisabled(true)
    ns.AttachTooltip(b, fillTooltip)
    b:SetScript("OnClick", onClick)
    b:Hide()
    return b
end

------------------------------------------------------------
-- 啟用與否、文字色、寬度、發光
--
-- ⚠ 金色碼只在啟用時加。W.CreateButton 停用時會把字轉灰，但內嵌色碼蓋得過
--   SetTextColor —— 原本一律帶金色，停用的按鈕看起來跟能按的一模一樣。
-- 寬度跟著字走：按鈕字在不同語系長度差很多，固定寬度不是太空就是溢出。
------------------------------------------------------------
function AddButton.SetState(b, enabled, glow)
    b:SetEnabled(enabled and true or false)
    b:SetText(enabled and ("|cffffd200" .. Label() .. "|r") or Label())
    local w = math.max(MIN_W, math.ceil(TextWidth(b:GetFontString())) + PAD_X * 2)
    ns.P.Size(b, w, HEIGHT)
    -- 還沒加進清單才發光；加過就熄掉（一直亮著的提示等於沒有提示）
    ns.SetGlow(b, (enabled and glow) and true or false)
end

------------------------------------------------------------
-- 貼到第一個顯示中的材料區標題右邊
--
-- ... ＝依序要試的材料區（暴雪的 ProfessionsReagentContainerTemplate，帶 .Label）。
-- 一個都沒有顯示＝這個畫面沒有材料可買（重新製作還沒放物品、訂單已送出…），
-- 按鈕整顆收起來，不留一顆按了也沒用的按鈕。
------------------------------------------------------------
function AddButton.Place(b, ...)
    for i = 1, select("#", ...) do
        local section = select(i, ...)
        local label = section and section.Label
        if label and section:IsShown() then
            -- 標題字串框固定 180 寬，字比框長時畫面上只到框的右緣
            local w, box = TextWidth(label), tonumber(label:GetWidth()) or 0
            if box > 0 then w = math.min(w, box) end
            b:ClearAllPoints()
            b:SetPoint("LEFT", label, "LEFT", math.ceil(w) + GAP, 0)
            b:Show()
            return true
        end
    end
    b:Hide()
    return false
end

-- 工具提示的前兩行：標題＋原本常駐在按鈕底下的那行說明
function AddButton.TooltipHeader(tip)
    tip:SetText(ns.PREFIX_COLOR .. L["MiliUI Shopping List"] .. "|r")
    tip:AddLine(L["Missing reagents can be bought at the auction house in one go"], 1, 1, 1, true)
end
