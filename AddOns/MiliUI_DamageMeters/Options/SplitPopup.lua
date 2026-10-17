------------------------------------------------------------
-- 合併檢視的新增／編輯彈窗
--
-- 共用層沒有「帶下拉的彈窗」，用 W.CreateFrame 拼。遮罩與層級照抄 W.CreateChoicePopup
-- （FULLSCREEN_DIALOG、遮罩 400、彈窗 410）：同一個設定視窗裡的彈窗疊層要一致，
-- 不然確認彈窗跟這個互相蓋來蓋去。下拉的清單是 TOOLTIP 層的共用框，蓋得過這裡。
--
-- 單例、懶建；新增與編輯共用同一個框，只差標題、預設值與確定之後做什麼。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local D = ns.Data

ns.SplitPopup = {}
local SP = ns.SplitPopup

local POPUP_W, POPUP_H = 400, 190
local PAD       = 16
local LABEL_W   = 80
local TYPE_DD_W, TYPE_DD_MAX = 150, 160
local SEG_DD_W  = 100
local DD_GAP    = 8
local ROW1_Y, ROW2_Y = -48, -80     -- 兩列下拉的中線
local PREVIEW_Y, PREVIEW_H = -100, 32
local ERROR_Y   = -138
local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local popup, mask
-- mode = "new" | "edit"；applyTo＝新增完要切過去的視窗（從設定頁新增的不套用）
local state = { mode = nil, id = nil, applyTo = nil,
                left = { type = nil, seg = "follow" }, right = { type = nil, seg = "follow" } }

-- 只列暴雪的類型：合併套合併沒有意義，API 也只認得 Enum 值
local function TypeItems()
    local items = {}
    for _, v in ipairs(D.TYPE_ORDER) do
        if type(v) == "number" then
            items[#items + 1] = { text = D.TYPE_NAMES[v] or "?", value = v }
        end
    end
    return items
end

local function SegItems()
    return {
        { text = L["Follow the window"], value = "follow" },
        { text = L["Current"],           value = "current" },
        { text = L["Overall"],           value = "overall" },
    }
end

local function FirstTypeExcept(except)
    for _, v in ipairs(D.TYPE_ORDER) do
        if type(v) == "number" and v ~= except then return v end
    end
    return except
end

------------------------------------------------------------
-- 父框
--
-- 平常掛設定視窗（跟確認彈窗同一個父層、同一套遮罩範圍）。但右鍵選單也開得出它，
-- 那時設定視窗可能根本沒開過、或是藏著 —— 掛在藏起來的框底下就永遠顯示不出來，
-- 所以那種情況改掛 UIParent，遮罩跟著蓋整個畫面。
------------------------------------------------------------
local function WantedParent()
    local p = ns.WidgetsEnv.PopupParent()
    if p and p:IsShown() then return p end
    return UIParent
end

-- SetParent 會讓框改繼承新父層的層級，所以每次換父層都要把層級補回來
local function ApplyLayer()
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(400)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
end

local function Reparent()
    local parent = WantedParent()
    if popup:GetParent() == parent then return end
    mask:SetParent(parent)
    mask:ClearAllPoints()
    mask:SetAllPoints(parent)
    popup:SetParent(parent)
    popup:ClearAllPoints()
    popup:SetPoint("CENTER", parent, "CENTER", 0, 0)
    ApplyLayer()
end

------------------------------------------------------------
-- 預覽與合法性：任何下拉一變就重算
------------------------------------------------------------
-- 兩欄完全相同才擋。類型相同、分段不同（「傷害輸出·目前 / 傷害輸出·總計」）是正當用法；
-- 一欄跟著視窗、一欄釘住「目前」在視窗剛好也是目前時畫面一樣，那是視窗狀態造成的，不擋
local function IsValid()
    local l, r = state.left, state.right
    return l.type ~= r.type or l.seg ~= r.seg
end

local function UpdatePreview()
    popup.icon:SetTexture(D.TYPE_ICONS[state.left.type] or FALLBACK_ICON)
    popup.name:SetText(D.SplitName(state))
    local ok = IsValid()
    popup.okBtn:SetEnabled(ok)
    -- 合法時留空而不是藏起來：那一列的位置固定，錯誤出現時版面不會跳
    popup.err:SetText(ok and "" or L["The two columns can't be identical."])
end

local function BuildRow(label, y, side)
    local fs = popup:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontNormal)
    fs:SetPoint("LEFT", popup, "TOPLEFT", PAD, y)
    fs:SetWidth(LABEL_W)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetText(label)

    local typeDD = W.CreateDropdown(popup, TYPE_DD_W, TypeItems(), function(value)
        state[side].type = value
        UpdatePreview()
    end)
    typeDD:SetPoint("LEFT", popup, "TOPLEFT", PAD + LABEL_W + DD_GAP, y)
    -- 長譯名讓它撐開；分段下拉錨在它右邊，跟著往右推
    typeDD:SetMaxWidth(TYPE_DD_MAX)

    local segDD = W.CreateDropdown(popup, SEG_DD_W, SegItems(), function(value)
        state[side].seg = value
        UpdatePreview()
    end)
    segDD:SetPoint("LEFT", typeDD, "RIGHT", DD_GAP, 0)
    segDD:SetMaxWidth(POPUP_W - PAD - (PAD + LABEL_W + DD_GAP + TYPE_DD_MAX + DD_GAP))

    popup[side .. "Type"], popup[side .. "Seg"] = typeDD, segDD
end

local function Ensure()
    if popup then return end
    local parent = WantedParent()

    mask = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    mask:SetAllPoints(parent)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    mask:SetBackdropColor(0.15, 0.15, 0.15, 0.7)
    mask:Hide()

    popup = W.CreateFrame(nil, parent, POPUP_W, POPUP_H)
    W.CloseOnEscape(popup)
    popup:SetPoint("CENTER", parent, "CENTER", 0, 0)
    -- 層級先設好再建子物件：之後建的下拉與按鈕才會跟著這一層
    ApplyLayer()
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetScript("OnShow", function() mask:Show() end)
    popup:SetScript("OnHide", function()
        mask:Hide()
        -- 別抓著視窗的參照：彈窗是單例，下一次開可能是從別的視窗
        state.applyTo = nil
    end)

    local title = popup:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetPoint("TOP", 0, -12)
    title:SetWidth(POPUP_W - 24)
    title:SetJustifyH("CENTER")
    popup.title = title

    BuildRow(L["Left column"], ROW1_Y, "left")
    BuildRow(L["Right column"], ROW2_Y, "right")

    -- 預覽：長得像首頁的卡片（左欄圖示＋自動名稱），選完就知道清單裡會出現什麼
    local card = CreateFrame("Frame", nil, popup)
    card:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, PREVIEW_Y)
    card:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -PAD, PREVIEW_Y)
    card:SetHeight(PREVIEW_H)
    local bg = card:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.05)
    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetSize(PREVIEW_H - 8, PREVIEW_H - 8)
    icon:SetPoint("LEFT", card, "LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    popup.icon = icon
    local name = card:CreateFontString(nil, "OVERLAY")
    name:SetFontObject(W.fontNormal)
    name:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    name:SetPoint("RIGHT", card, "RIGHT", -6, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    popup.name = name

    local err = popup:CreateFontString(nil, "OVERLAY")
    err:SetFontObject(W.fontSmall)
    err:SetTextColor(1, 0.3, 0.3)
    err:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, ERROR_Y)
    err:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -PAD, ERROR_Y)
    err:SetJustifyH("LEFT")
    popup.err = err

    -- 確定＝這個區塊唯一的 primary（按鈕上色規則）
    local cancel = W.CreateButton(popup, L["Cancel"], "normal", 80, 22)
    cancel:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -PAD, 12)
    cancel:SetScript("OnClick", function() popup:Hide() end)
    local ok = W.CreateButton(popup, L["Okay"], "primary", 80, 22)
    ok:SetPoint("RIGHT", cancel, "LEFT", -DD_GAP, 0)
    ok:SetScript("OnClick", function() SP.Accept() end)
    popup.okBtn = ok

    -- CreateFrame 建出來預設是顯示的；不關掉的話第一次 Show 不會觸發 OnShow，遮罩出不來
    popup:Hide()
end

------------------------------------------------------------
-- 確定
------------------------------------------------------------
-- 編輯：視窗存的 key 沒變，但兩欄的類型／分段可能都換了 —— 清掉跟資料有關的備忘
-- 並重畫。不走 Win.SetDMType：那支會把正在看的歷史分段清掉，編輯組合不該動到分段
local function RedrawWindowsShowing(key)
    ns.Windows.ForEach(function(w)
        if w.curDMType ~= key then return end
        w._barCacheKey = nil
        w._barSources = nil
        w._cachedTargets = nil
        w._timerSec = nil
        w._segDur = nil
        ns.Breakdown.Close(w)
        ns.Window.UpdateTitle(w)
        w.Refresh()
    end)
end

function SP.Accept()
    if not popup or not IsValid() then return end
    local left, right = state.left, state.right
    if state.mode == "new" then
        local key = ns.DB.AddSplit(left, right)
        local target = state.applyTo
        popup:Hide()
        if key and target and target.frame then ns.Window.SetDMType(target, key) end
    elseif state.mode == "edit" then
        local id = state.id
        popup:Hide()
        if ns.DB.UpdateSplit(id, left, right) then
            RedrawWindowsShowing(ns.DB.SPLIT_PREFIX .. id)
        end
    end
end

------------------------------------------------------------
-- 開啟
------------------------------------------------------------
local function Open(mode, id, applyTo, left, right)
    Ensure()
    Reparent()
    state.mode, state.id, state.applyTo = mode, id, applyTo
    state.left.type, state.left.seg = left.type, left.seg
    state.right.type, state.right.seg = right.type, right.seg

    popup.title:SetText(mode == "edit" and L["Edit split view"] or L["New split view"])
    -- 類型清單每次重灌：開檔時的清單跟這支客戶端有關，但便宜，不值得快取
    for _, side in ipairs({ "left", "right" }) do
        local typeDD, segDD = popup[side .. "Type"], popup[side .. "Seg"]
        typeDD:SetItems(TypeItems())
        typeDD:SetSelectedValue(state[side].type)
        segDD:SetSelectedValue(state[side].seg)
    end
    UpdatePreview()
    popup:Show()
    popup:Raise()
end

-- W＝從哪個視窗的右鍵選單開的（確定之後那個視窗直接切過去）；從設定頁開的傳 nil
function SP.OpenNew(W)
    if #ns.DB.Splits().list >= ns.DB.MAX_SPLITS then return end
    -- 左欄預設＝這個視窗正在看的類型；正在看合併檢視就取它的左欄
    local leftType
    local cur = W and W.curDMType
    local def = cur ~= nil and D.SplitDef(cur)
    if def then
        leftType = def.left.type
    elseif type(cur) == "number" then
        leftType = cur
    end
    if leftType == nil then leftType = FirstTypeExcept(nil) end
    Open("new", nil, W,
        { type = leftType, seg = "follow" },
        { type = FirstTypeExcept(leftType), seg = "follow" })
end

function SP.OpenEdit(id)
    local def = ns.DB.SplitById(id)
    -- 類型在這支客戶端不存在的組合：下拉裡沒有那個選項，編輯會把它悄悄換掉 —— 不給開
    if not def or not D.SplitAvailable(def) then return end
    Open("edit", id, nil,
        { type = def.left.type,  seg = def.left.seg },
        { type = def.right.type, seg = def.right.seg })
end
