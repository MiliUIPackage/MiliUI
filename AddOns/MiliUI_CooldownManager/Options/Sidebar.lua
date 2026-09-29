------------------------------------------------------------
-- 設定視窗左欄（寬 150）
--
--   條
--     核心技能／輔助技能／增益圖示／增益長條
--     ＋ 新增群組            ← 主動作（primary），不參與選取
--   資源條
--   施法條
--   全域
--     主題／設定檔／關於
--
-- 選取用 accent-hover 按鈕 ＋ W.CreateButtonGroup（單位框架單位欄同款）。
-- 小節只靠「留白 ＋ accent 小字標題」分開，不畫隔線。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

ns.Sidebar = {}
local Sidebar = ns.Sidebar

local PAD_X    = 8
local TOP_Y    = -12
local BTN_H    = 22
local BTN_GAP  = 2
local HEAD_H   = 18       -- 小節標題那一行
local HEAD_GAP = 10       -- 小節之間的留白

local ITEMS = {
    { header = L["Bars"] },
    { id = "essential" }, { id = "utility" }, { id = "buffs" }, { id = "buffbars" },
    { action = "newGroup" },
    { gap = HEAD_GAP },
    { id = "resources" }, { id = "castbar" },
    { header = L["Global"] },
    { id = "theme" }, { id = "profile" }, { id = "about" },
}

local col, btnW
local rows = {}             -- { kind = "head"|"button"|"gap", region, h }
local byId = {}
local highlight
local groupPopup

local function NewGroup()
    -- 自訂群組還沒做：先講清楚，不要按了沒反應
    if not groupPopup then
        groupPopup = W.CreateChoicePopup(ns.Options.panel, 320,
            L["Custom groups are coming in a later version."],
            { { text = L["Okay"], color = "primary" } })
    end
    groupPopup:Show()
end

------------------------------------------------------------
-- 縱向排版
--
-- ⚠ y 是**累加**的：放不下的語系按鈕會換行長高（W.WrapButton），後面的要往下讓。
-- 跑兩次：建完一次、視窗真的顯示之後再一次 —— 沒顯示的框量字高可能是 0，
-- 那種情況 WrapButton 會收手不換行，要等顯示後重量。
------------------------------------------------------------
function Sidebar.Relayout()
    if not col then return end
    local y = TOP_Y
    for i, row in ipairs(rows) do
        if row.kind == "head" then
            if i > 1 then y = y - HEAD_GAP end
            row.region:ClearAllPoints()
            row.region:SetPoint("TOPLEFT", col, "TOPLEFT", PAD_X + 2, y - 2)
            y = y - HEAD_H
        elseif row.kind == "gap" then
            y = y - row.h
        else
            row.region:ClearAllPoints()
            row.region:SetPoint("TOPLEFT", col, "TOPLEFT", PAD_X, y)
            y = y - (W.WrapButton(row.region, btnW, BTN_H) + BTN_GAP)
        end
    end
end

function Sidebar.Build(panel, width)
    if col then return col end
    col = CreateFrame("Frame", nil, panel)
    col:SetPoint("TOPLEFT", 0, 0)
    col:SetPoint("BOTTOMLEFT", 0, 0)
    col:SetWidth(width)
    btnW = width - PAD_X * 2

    local group = {}
    for _, item in ipairs(ITEMS) do
        if item.header then
            rows[#rows + 1] = { kind = "head", region = W.CreateGroupLabel(col, item.header) }
        elseif item.gap then
            rows[#rows + 1] = { kind = "gap", h = item.gap }
        elseif item.action == "newGroup" then
            local b = W.CreateButton(col, L["+ New Group"], "primary", btnW, BTN_H)
            b:SetScript("OnClick", NewGroup)
            rows[#rows + 1] = { kind = "button", region = b }
        else
            local b = W.CreateButton(col, ns.Options.PageTitle(item.id) or item.id, "accent-hover", btnW, BTN_H)
            b.id = item.id
            byId[item.id] = b
            group[#group + 1] = b
            rows[#rows + 1] = { kind = "button", region = b }
        end
    end
    highlight = W.CreateButtonGroup(group, function(id) ns.Options.ShowPage(id) end)

    -- 左欄與頁面之間的分隔線（1px 黑）
    local sep = col:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    sep:SetVertexColor(0, 0, 0, 1)
    sep:SetPoint("TOPLEFT", col, "TOPRIGHT", 0, -10)
    sep:SetPoint("BOTTOMLEFT", col, "BOTTOMRIGHT", 0, 10)
    sep:SetWidth(P.Scale(1))

    Sidebar.Relayout()
    return col
end

-- ⚠ 按鈕群組的高亮掛在按鈕自己的 OnClick 上。從外面切頁（開窗回到上次那頁、
-- 編輯模式的齒輪）不經過點擊，要從這裡補，不然左欄會亮著上一頁。
function Sidebar.Highlight(id)
    local b = byId[id]
    if b and highlight then highlight(b) end
end
