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
--   * 別的插件也在同一個位置擺東西時（例如材料區標題右邊的勾選框），排到它後面，
--     不跟它疊在一起 —— 見下面的 Neighbor
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

-- 主按鈕（primary）：這一區唯一的動作，平時就是職業色，玩家不用靠發光才知道這裡能按。
-- 停用時 W.CreateButton 自己退回中性底＋灰字（規則見 .claude/notes/project-miliui-button-variants.md）。
-- onNeighborChanged：鄰居（見 Neighbor）顯示／隱藏時要重新擺位，呼叫端給一支延一幀的重算
function AddButton.Create(parent, onClick, fillTooltip, onNeighborChanged)
    local b = ns.W.CreateButton(parent, Label(), "primary", MIN_W, HEIGHT)
    b.onNeighborChanged = onNeighborChanged
    -- 停用時滑過也要有提示：「為什麼不能按」本身就是要講的資訊
    b:SetMotionScriptsWhileDisabled(true)
    ns.AttachTooltip(b, fillTooltip)
    b:SetScript("OnClick", onClick)
    b:Hide()
    return b
end

------------------------------------------------------------
-- 啟用與否、字、寬度
--
-- listed ＝這個配方已經在清單裡：字直接寫「已在清單中」、按鈕停用。停用的 primary
-- 自己退回中性底＋灰字，所以「能不能按」跟「加過沒」是同一個訊號，不必在提示裡另外
-- 解釋重按會怎樣（要改份數去清單視窗改；從清單移除之後 ListChanged 會把按鈕叫回來）。
--
-- ⚠ 字裡**不要**放色碼。內嵌色碼蓋得過 W.CreateButton 停用時上的灰字 ——
--   以前啟用時字帶金色，停用的按鈕看起來跟能按的一模一樣。
-- 寬度跟著字走：按鈕字在不同語系長度差很多，固定寬度不是太空就是溢出。
------------------------------------------------------------
function AddButton.SetState(b, enabled, listed)
    b:SetEnabled((enabled and not listed) and true or false)
    b:SetText(listed and L["Already in the list"] or Label())
    local w = math.max(MIN_W, math.ceil(TextWidth(b:GetFontString())) + PAD_X * 2)
    ns.P.Size(b, w, HEIGHT)
end

------------------------------------------------------------
-- 同一個標題右邊的鄰居
--
-- 別的插件也會把東西用 LEFT 錨在材料區標題上、x 同樣是「標題字寬」—— 跟我們的
-- 按鈕只差一個 GAP，兩顆整個疊在一起。不點名、不認欄位名：找「錨點是 LEFT、錨在
-- 這個標題上」的框，有顯示的就排到它後面。暴雪自己的東西是往下疊的
-- （TOPLEFT／BOTTOMLEFT），不會被這條條件撈到。
--
-- 鄰居的顯示／隱藏不一定跟著我們的重算走（它可能在材料區 OnShow 才擺、比我們晚），
-- 所以撈到的每一顆都掛 OnShow／OnHide，變了就叫呼叫端重算。掛在別的插件的框上，
-- 不是暴雪框；每顆只掛一次。
--
-- ⚠ 只讀：GetChildren／GetPoint／IsShown，暴雪框上什麼都不寫。
------------------------------------------------------------
local hooked = setmetatable({}, { __mode = "k" })

local function AnchoredBeside(frame, label)
    for i = 1, frame:GetNumPoints() do
        local point, rel, relPoint = frame:GetPoint(i)
        if rel == label and point == "LEFT" and (relPoint == "LEFT" or relPoint == "RIGHT") then
            return true
        end
    end
    return false
end

local function Watch(b, frame)
    if hooked[frame] or not b.onNeighborChanged then return end
    hooked[frame] = true
    local notify = function() b.onNeighborChanged() end
    frame:HookScript("OnShow", notify)
    frame:HookScript("OnHide", notify)
end

local function ScanChildren(b, label, found, ...)
    for i = 1, select("#", ...) do
        local child = select(i, ...)
        if child ~= b and AnchoredBeside(child, label) then
            Watch(b, child)
            if not found and child:IsShown() then found = child end
        end
    end
    return found
end

local function Neighbor(b, section, label)
    local found = ScanChildren(b, label, nil, section:GetChildren())
    local parent = section:GetParent()
    if parent then
        found = ScanChildren(b, label, found, parent:GetChildren())
    end
    return found
end

-- 鄰居的右緣：勾選框的字畫在框外面（UICheckButtonTemplate 的 Text 貼在框的右邊），
-- 有字就錨字、沒字就錨框本身
local function RightEdge(frame)
    local fs = frame.Text or frame.text
    if fs and fs.GetText and fs:IsShown() and (fs:GetText() or "") ~= "" then
        return fs
    end
    return frame
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
            b:ClearAllPoints()
            local neighbor = Neighbor(b, section, label)
            if neighbor then
                b:SetPoint("LEFT", RightEdge(neighbor), "RIGHT", GAP, 0)
            else
                -- 標題字串框固定 180 寬，字比框長時畫面上只到框的右緣
                local w, box = TextWidth(label), tonumber(label:GetWidth()) or 0
                if box > 0 then w = math.min(w, box) end
                b:SetPoint("LEFT", label, "LEFT", math.ceil(w) + GAP, 0)
            end
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
