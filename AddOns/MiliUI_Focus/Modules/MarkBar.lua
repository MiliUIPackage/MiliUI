------------------------------------------------------------
-- 標記切換列
-- 兩顆按鈕：
--   1. 標記圖示：點擊彈出 8 格選單自行點選，切換焦點自動標記的圖示，
--      並立即重標目前焦點（走 raidtarget 安全動作，戰鬥中可用）
--   2. 宣告：把「我的焦點自動標記圖示是哪個」送到 副本/團隊/隊伍 頻道
--      （{icon} → {rtN}；宣告的是設定的圖示，不讀焦點單位，避開秘密值）
-- 整條工具列本身是非安全框架，但選單格子是保護按鈕（標記只能走安全動作），
-- 所以開關與建立都要 InCombatLockdown 守衛。
------------------------------------------------------------
local _, ns = ...

ns.MarkBar = {}
local MarkBar = ns.MarkBar

local ICON_SIZE  = 34
local ICON_SPACE = 5
local PADDING    = 6
local GRIP_WIDTH = 12

-- 預設放在畫面下方 16% 高的位置（爆發藥水列預設在 10%，錯開避免疊在一起）
local DEFAULT_Y_FRACTION = 0.16

local ANNOUNCE_ICON  = "Interface\\AddOns\\MiliUI_Focus\\Media\\announce"
local MARK_NONE_ICON = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local MARKS_TEXTURE  = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

-- 套組慣用「無邊框」外觀：1px 像素邊 + 深色半透明底
local BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local bar, markBtn, announceBtn
local picker, pickerCells

local function DB()
    return ns.db.bar
end

----------------------------------------------------------------------
-- 標記圖示
----------------------------------------------------------------------
-- 單一標記圖示的材質跳脫字（tooltip / 聊天預覽用）
local function MarkIcon(index, size)
    return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_"
        .. index .. ":" .. (size or 14) .. "|t"
end

-- UI-RaidTargetingIcons 是 4x4 圖集，1-8 由左至右、由上而下
local function SetMarkTexCoord(tex, index)
    local col = (index - 1) % 4
    local row = math.floor((index - 1) / 4)
    tex:SetTexCoord(col * 0.25, col * 0.25 + 0.25, row * 0.25, row * 0.25 + 0.25)
end

local function UpdateMarkIcon()
    local index = ns.db and ns.db.focus.markIndex or 0
    if markBtn then
        if index >= 1 and index <= 8 then
            markBtn.icon:SetTexture(MARKS_TEXTURE)
            SetMarkTexCoord(markBtn.icon, index)
        else
            -- 尚未選過標記：顯示紅色禁止圖
            markBtn.icon:SetTexture(MARK_NONE_ICON)
            markBtn.icon:SetTexCoord(0, 1, 0, 1)
        end
    end
    -- 選單上目前選擇的黃框
    if pickerCells then
        for i, cell in ipairs(pickerCells) do
            cell.border:SetShown(i == index)
        end
    end
end

-- 點選標記後的非安全記帳（實際標記由格子的 raidtarget 安全動作執行）
local function OnPickMark(index)
    -- SetMarkIndex 內部處理巨集更新（戰鬥中自動延後到脫戰）
    ns.Focuser.SetMarkIndex(index)
    UpdateMarkIcon()
    ns.Fire("SettingsChanged")
    -- 收合選單交給安全 postbody（放開邊緣）；這裡不能收——本函式在
    -- 按下邊緣執行，先收會把放開邊緣才觸發的標記動作吃掉
end

----------------------------------------------------------------------
-- 標記選單：點圖示按鈕彈出，8 個標記排成 4x2，點選後套用並關閉。
-- 12.0 Midnight 起 SetRaidTarget 是（戰鬥）保護函式，插件不能直接呼叫，
-- 標記改走暴雪的 raidtarget 安全動作（SECURE_ACTIONS.raidtarget：
-- 讀 marker / action / unit 屬性）。因此格子是保護按鈕，選單的開關
-- 也必須走 SecureHandler 快照（戰鬥中一般程式不能 Show/Hide 保護框架）。
----------------------------------------------------------------------
local PICK_SIZE  = 28
local PICK_SPACE = 4

local function CreatePicker()
    if picker then return picker end
    ns.Focuser.EnsureButtons()   -- 見 Focuser.EnsureButtons 的註解（Init 順序不保證）
    -- SecureHandlerBaseTemplate：讓安全快照拿得到 picker 的 handle 來開關
    picker = CreateFrame("Frame", "MiliUIFocus_MarkPicker", bar,
        "SecureHandlerBaseTemplate,BackdropTemplate")
    local w = PADDING * 2 + PICK_SIZE * 4 + PICK_SPACE * 3
    local h = PADDING * 2 + PICK_SIZE * 2 + PICK_SPACE
    picker:SetSize(w, h)
    picker:SetPoint("BOTTOM", markBtn, "TOP", 0, PADDING + 2)
    picker:SetBackdrop(BACKDROP)
    picker:SetBackdropColor(0.06, 0.06, 0.10, 0.92)
    picker:SetBackdropBorderColor(0, 0, 0, 1)
    -- strata 跟著母框（MEDIUM），只靠 level 疊在列上面
    picker:SetFrameLevel(bar:GetFrameLevel() + 10)
    picker:SetClampedToScreen(true)
    picker:Hide()

    -- ESC 關閉：加入 UISpecialFrames。它會從一般（非安全）路徑呼叫 :Hide()，
    -- 戰鬥中隱藏保護框架會被擋並報錯，所以把 Lua 端的 Hide 覆寫成戰鬥中不動作；
    -- 安全快照走 frame handle 的 C 路徑，不經過這個覆寫，不受影響。
    local rawHide = picker.Hide
    picker.Hide = function(self)
        if InCombatLockdown() then return end
        rawHide(self)
    end
    tinsert(UISpecialFrames, "MiliUIFocus_MarkPicker")

    pickerCells = {}
    for i = 1, 8 do
        local cell = CreateFrame("Button", nil, picker, "SecureActionButtonTemplate")
        cell:SetSize(PICK_SIZE, PICK_SIZE)
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        cell:SetPoint("TOPLEFT", picker, "TOPLEFT",
            PADDING + col * (PICK_SIZE + PICK_SPACE),
            -(PADDING + row * (PICK_SIZE + PICK_SPACE)))

        -- 標記走安全動作，戰鬥中也能執行；"set" 具冪等性（已是該標記就跳過），
        -- 所以 down/up 兩個邊緣都註冊也不會閃爍
        cell:RegisterForClicks("AnyDown", "AnyUp")
        cell:SetAttribute("type1", "raidtarget")
        cell:SetAttribute("marker", i)
        cell:SetAttribute("action1", "set")
        cell:SetAttribute("unit", "focus")

        -- 點選後在安全環境裡：收起選單 + 把巨集換成此編號對應的版本
        -- （受限環境可改保護屬性，戰鬥中也能執行，這樣戰鬥中換圖示後，
        -- 下一次 Shift+點擊立刻用新標記）。巨集文字預存在格子的
        -- focusermacro 屬性（SyncCellMacros 維護）。
        -- OnClick wrap 的 prebody 回傳值是 (改寫按鍵, message)，
        -- postbody 只在 message 非 nil 時執行：按鍵不改，第一個回 nil
        SecureHandlerSetFrameRef(cell, "picker", picker)
        local focuserBtn = ns.Focuser.GetButton()
        if focuserBtn then
            SecureHandlerSetFrameRef(cell, "focuser", focuserBtn)
        end
        -- postbody 兩個邊緣都會跑：換巨集冪等，跑兩次無妨；收選單只能在
        -- 「放開」邊緣做——按下就藏的話，放開邊緣送不到已隱藏的按鈕，
        -- 依 cvar 設定在放開才執行的標記動作與記帳 hook 都會被吃掉
        SecureHandlerWrapScript(cell, "OnClick", cell,
            [[ return nil, true ]],
            [[
                local fb = self:GetFrameRef("focuser")
                local macro = self:GetAttribute("focusermacro")
                if fb and macro and macro ~= "" then
                    fb:SetAttribute("macrotext", macro)
                    fb:SetAttribute("macrotextrelease", macro)
                    fb:SetAttribute("macrotext1", macro)
                end
                if not down then
                    self:GetFrameRef("picker"):Hide()
                end
            ]])

        -- 目前選擇的黃框
        cell.border = cell:CreateTexture(nil, "BACKGROUND", nil, 1)
        cell.border:SetPoint("TOPLEFT", -2, 2)
        cell.border:SetPoint("BOTTOMRIGHT", 2, -2)
        cell.border:SetColorTexture(1, 0.82, 0, 1)
        cell.border:Hide()

        cell.slotBg = cell:CreateTexture(nil, "BACKGROUND", nil, 2)
        cell.slotBg:SetPoint("TOPLEFT", 1, -1)
        cell.slotBg:SetPoint("BOTTOMRIGHT", -1, 1)
        cell.slotBg:SetColorTexture(0.05, 0.05, 0.07, 1)

        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetPoint("TOPLEFT", 3, -3)
        cell.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        cell.icon:SetTexture(MARKS_TEXTURE)
        SetMarkTexCoord(cell.icon, i)

        cell.highlight = cell:CreateTexture(nil, "HIGHLIGHT")
        cell.highlight:SetPoint("TOPLEFT", 1, -1)
        cell.highlight:SetPoint("BOTTOMRIGHT", -1, 1)
        cell.highlight:SetColorTexture(1, 1, 1, 0.15)

        -- 非安全記帳（存檔 + 更新圖示）：做在「按下」邊緣——按下一定送達；
        -- 放開邊緣可能因 postbody 已收起選單而不會觸發
        cell:HookScript("OnClick", function(_, _, down)
            if not down then return end
            OnPickMark(i)
        end)
        cell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(_G["RAID_TARGET_" .. i] or ("" .. i))
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", GameTooltip_Hide)

        pickerCells[i] = cell
    end

    MarkBar.SyncCellMacros()   -- 預存各編號的巨集文字
    UpdateMarkIcon()           -- 套上目前選擇的黃框
    return picker
end

----------------------------------------------------------------------
-- 宣告
----------------------------------------------------------------------
local function GetAnnounceChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end
    return nil
end

-- 隊友設定（由 Sync 收集）。回傳兩個清單：有標記的、沒設定的。
local function GetPeerLists()
    local marked, idle = {}, {}
    for _, p in ipairs(ns.Sync.GetPeers()) do
        if p.index >= 1 and p.index <= 8 then
            marked[#marked + 1] = p
        else
            idle[#idle + 1] = p
        end
    end
    return marked, idle
end

-- 組出宣告訊息。宣告的是「設定的自動標記圖示」（告訴隊友：這個標記就是
-- 我的焦點打斷目標），不讀焦點身上的標記，所以不需要焦點存在。
-- forChat = true 用 {rtN}（送進頻道由客戶端轉圖示）；
-- false 用 |T...|t 材質跳脫（print / tooltip 本地顯示用，{rtN} 在本地不會轉）
local function BuildAnnounceMessage(forChat)
    local index = ns.db.focus.markIndex or 0
    if index < 1 or index > 8 then
        return nil, ns.L["Pick a marker icon first (click the icon on the left)."]
    end
    local iconToken
    if forChat then
        iconToken = "{rt" .. index .. "}"
    else
        iconToken = MarkIcon(index, 16)
    end
    local text = DB().announceText or ns.L["My focus interrupt target is {icon}!"]
    local msg = (text:gsub("{icon}", iconToken))

    -- 帶上隊友的標記，隊友一眼就看得出誰盯哪一隻。
    -- 只列有設標記的；上限 6 個，免得團隊裡洗出一整面牆。
    local marked = GetPeerLists()
    if #marked > 0 then
        local parts, shown = {}, math.min(#marked, 6)
        for i = 1, shown do
            local p = marked[i]
            local token = forChat and ("{rt" .. p.index .. "}") or MarkIcon(p.index, 16)
            parts[#parts + 1] = p.name .. token
        end
        if #marked > shown then parts[#parts + 1] = "…" end
        msg = msg .. "(" .. ns.L["Teammates:"] .. " " .. table.concat(parts, " ") .. ")"
    end
    return msg
end

local lastAnnounce = 0
local function Announce()
    -- 防連點洗頻
    if GetTime() - lastAnnounce < 1 then return end
    local msg, err = BuildAnnounceMessage(true)
    if not msg then
        ns.Print(err)
        return
    end
    lastAnnounce = GetTime()
    local channel = GetAnnounceChannel()
    if channel then
        SendChatMessage(msg, channel)
    else
        -- 本地預覽：{rtN} 不會被聊天框轉換，改用材質跳脫顯示
        ns.Print(ns.L["Not in a group; the announcement would read:"]
            .. " " .. BuildAnnounceMessage(false))
    end
end

----------------------------------------------------------------------
-- 位置（BOTTOMLEFT 錨定，拖完存左/下緣座標）
----------------------------------------------------------------------
local function PositionBar()
    if not bar then return end
    local db = DB()
    if not db.x then
        db.x = math.max(0, math.floor((UIParent:GetWidth() - bar:GetWidth()) / 2))
    end
    if not db.y then
        db.y = math.floor(UIParent:GetHeight() * DEFAULT_Y_FRACTION)
    end
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.x, db.y)
end

local function SavePosition()
    local x, y = bar:GetLeft(), bar:GetBottom()
    if not (x and y) then return end
    local db = DB()
    db.x, db.y = x, y
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

----------------------------------------------------------------------
-- 建立
----------------------------------------------------------------------
local function CreateBarButton(parent, template)
    local btn = CreateFrame("Button", nil, parent, template)
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn.slotBg = btn:CreateTexture(nil, "BACKGROUND")
    btn.slotBg:SetPoint("TOPLEFT", 1, -1)
    btn.slotBg:SetPoint("BOTTOMRIGHT", -1, 1)
    btn.slotBg:SetColorTexture(0.05, 0.05, 0.07, 1)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 4, -4)
    btn.icon:SetPoint("BOTTOMRIGHT", -4, 4)

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetPoint("TOPLEFT", 1, -1)
    btn.highlight:SetPoint("BOTTOMRIGHT", -1, 1)
    btn.highlight:SetColorTexture(1, 1, 1, 0.15)

    return btn
end

local function CreateBar()
    if bar then return bar end
    local L = ns.L

    local width = PADDING * 2 + GRIP_WIDTH + 4 + ICON_SIZE * 2 + ICON_SPACE
    bar = CreateFrame("Frame", "MiliUIFocus_MarkBar", UIParent, "BackdropTemplate")
    bar:SetSize(width, PADDING * 2 + ICON_SIZE)
    -- ⚠ 層級：MEDIUM ＋ frame level 600，兩邊都不要碰。
    --   * 要越過的數字是 **500**，不是快捷列按鈕自己的 level。
    --     Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml 把按鍵文字與數量
    --     單獨放在 `TextOverlayContainer`，寫死 `frameLevel="500"` ＋ setAllPoints；
    --     按鈕本體才 level 3。所以列擺在快捷列附近時，蓋上來的是那層 500。
    --     （`/framestack` 滑過按鈕就看得到：`MultiBar5Button5` <3> 但
    --      `MultiBar5Button5.TextOverlayContainer` <500>。）
    --   * 但不能改 strata 去 HIGH：暴雪的面板（天賦樹 PlayerSpellsFrame 等）其實
    --     **也在 MEDIUM**（XML 沒設 frameStrata），只是帶 toplevel 會把自己抬到同層
    --     最上面。跳到 HIGH 就變成連天賦樹、角色面板都蓋住。
    --   留在 MEDIUM、level 600：越過文字層那 500，而面板每次顯示都會重新抬到同層
    --   最高，所以照樣蓋得住我們。
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(600)
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:SetBackdrop(BACKDROP)
    bar:SetBackdropColor(0.06, 0.06, 0.10, 0.92)
    bar:SetBackdropBorderColor(0, 0, 0, 1)
    bar:Hide()

    -- 拖曳握把（左側）：左鍵拖曳移動、右鍵開啟設定
    local grip = CreateFrame("Frame", nil, bar)
    grip:SetPoint("TOPLEFT", 4, -4)
    grip:SetPoint("BOTTOMLEFT", 4, 4)
    grip:SetWidth(GRIP_WIDTH)
    grip:EnableMouse(true)
    grip:RegisterForDrag("LeftButton")

    -- 三條橫線的握把記號
    for i = 1, 3 do
        local line = grip:CreateTexture(nil, "ARTWORK")
        line:SetSize(8, 1)
        line:SetPoint("CENTER", grip, "CENTER", 0, (2 - i) * 4)
        line:SetColorTexture(0.6, 0.65, 0.75, 0.8)
    end

    -- 列上有保護子框架（標記選單），戰鬥中不能移動
    grip:SetScript("OnDragStart", function()
        if not InCombatLockdown() then bar:StartMoving() end
    end)
    grip:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        SavePosition()
    end)
    grip:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton == "RightButton" then ns.OpenOptions("bar") end
    end)
    grip:SetScript("OnEnter", function()
        GameTooltip:SetOwner(grip, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Focus marker bar"])
        GameTooltip:AddLine(L["Left-drag to move"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Right-click to open settings"], 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", GameTooltip_Hide)

    -- 按鈕 1：焦點標記圖示（點擊彈出選單自行點選）。
    -- 選單含保護按鈕，開關必須在安全環境執行（戰鬥中才不會被擋），
    -- 所以這顆是 SecureHandlerClickTemplate，用 _onclick 快照切換
    markBtn = CreateBarButton(bar, "SecureHandlerClickTemplate")
    markBtn:SetPoint("LEFT", grip, "RIGHT", 4, 0)
    CreatePicker()
    SecureHandlerSetFrameRef(markBtn, "picker", picker)
    markBtn:SetAttribute("_onclick", [[
        if button ~= "LeftButton" then return end
        local p = self:GetFrameRef("picker")
        if p:IsShown() then p:Hide() else p:Show() end
    ]])
    markBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Switch focus marker"])
        GameTooltip:AddLine(L["Click to open the picker and choose a marker icon"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Your current focus is re-marked right away (works in combat)"], 0.7, 0.7, 0.7)
        GameTooltip:AddLine(L["Switching in combat: the shift-click macro picks up the new marker after combat"], 0.5, 0.5, 0.5)

        -- 隊友設定（只有同樣裝這個插件／米利UI套組的人才會回報）
        local mine = ns.Focuser.GetEffectiveMarkIndex()
        local marked, idle = GetPeerLists()
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Teammate focus markers"], 1, 0.82, 0)
        if mine >= 1 then
            GameTooltip:AddDoubleLine(L["You"], MarkIcon(mine), 0.9, 0.9, 0.9, 1, 1, 1)
        else
            GameTooltip:AddDoubleLine(L["You"], L["Not set"], 0.9, 0.9, 0.9, 0.6, 0.6, 0.6)
        end
        for _, p in ipairs(marked) do
            if p.index == mine then
                -- 撞號：這正是想知道「要不要換」的那一刻
                GameTooltip:AddDoubleLine(p.name, MarkIcon(p.index) .. " " .. L["same as yours"],
                    1, 0.3, 0.3, 1, 0.3, 0.3)
            else
                GameTooltip:AddDoubleLine(p.name, MarkIcon(p.index), 0.8, 0.8, 0.8, 1, 1, 1)
            end
        end
        for _, p in ipairs(idle) do
            GameTooltip:AddDoubleLine(p.name, L["Not set"], 0.6, 0.6, 0.6, 0.5, 0.5, 0.5)
        end
        if #marked == 0 and #idle == 0 then
            GameTooltip:AddLine(L["No teammates running this addon were detected"], 0.5, 0.5, 0.5)
        end
        if ns.Sync.IsRestricted() then
            GameTooltip:AddLine(L["(Blizzard blocks addon comms during boss fights / M+ / battlegrounds; the list above is what arrived before the pull)"],
                0.5, 0.5, 0.5, true)
        end
        GameTooltip:Show()
    end)
    markBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- 按鈕 2：宣告焦點目標
    announceBtn = CreateBarButton(bar)
    announceBtn:SetPoint("LEFT", markBtn, "RIGHT", ICON_SPACE, 0)
    -- 線條風自製圖示，保留 4px 留白（不像技能圖示要填滿裁邊）
    announceBtn.icon:SetTexture(ANNOUNCE_ICON)
    announceBtn:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then Announce() end
    end)
    announceBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Announce focus marker"])
        local msg = BuildAnnounceMessage(false)   -- tooltip 用材質跳脫顯示圖示
        if msg then
            GameTooltip:AddLine(msg, 1, 1, 1)
        end
        local channelNames = {
            INSTANCE_CHAT = L["Instance chat"],
            RAID = L["Raid chat"],
            PARTY = L["Party chat"],
        }
        local channel = GetAnnounceChannel()
        GameTooltip:AddLine(L["Sends to:"] .. " "
            .. (channelNames[channel] or L["(not in a group, shown to you only)"]), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["The announcement text can be changed in the settings"], 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    announceBtn:SetScript("OnLeave", GameTooltip_Hide)

    UpdateMarkIcon()
    PositionBar()
    return bar
end

----------------------------------------------------------------------
-- 顯示邏輯：選項開啟 + Shift+點擊功能啟用才顯示
----------------------------------------------------------------------
local function ShouldShow()
    return ns.db and DB().shown and ns.db.focus.enabled
end

local pendingRefresh = false

function MarkBar.Refresh()
    if not ns.db then return end
    -- 標記選單是保護框架，建立（寫安全屬性）與顯示/隱藏都不能在戰鬥中做，
    -- 延後到脫戰（PLAYER_REGEN_ENABLED）再套用；圖示更新只碰材質，隨時安全
    if InCombatLockdown() then
        pendingRefresh = true
        if bar then UpdateMarkIcon() end
        return
    end
    if ShouldShow() then
        CreateBar()
        UpdateMarkIcon()
        PositionBar()
        bar:Show()
    elseif bar then
        picker:Hide()
        bar:Hide()
    end
end

----------------------------------------------------------------------
-- 對外
----------------------------------------------------------------------
function MarkBar.UpdateMarkIcon()
    UpdateMarkIcon()
end

-- 預存「選了編號 i 時巨集該長什麼樣」到各格子的屬性，讓格子的安全快照
-- 能在戰鬥中直接換上。自動標記等設定改變時由 Focuser 呼叫重算（保護屬性，
-- 只能脫戰寫；戰鬥中改設定由 Focuser 的 pendingMacro 延後到脫戰）
function MarkBar.SyncCellMacros()
    if not pickerCells then return end
    if InCombatLockdown() then return end
    for i, cell in ipairs(pickerCells) do
        cell:SetAttribute("focusermacro", ns.Focuser.GetMacroForMarkIndex(i))
    end
end

function MarkBar.ResetPosition()
    local db = DB()
    db.x, db.y = nil, nil
    PositionBar()
end

function MarkBar.PreviewAnnounce()
    return BuildAnnounceMessage(false)
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event)
    if event == "GLOBAL_MOUSE_DOWN" then
        -- 點選單以外的地方收起選單。排除標記按鈕本身（它的安全 _onclick
        -- 自己會切換，這裡先收會互相抵消變成永遠關不掉／關了又開）。
        -- 戰鬥中不能從一般程式隱藏保護框架，略過（改用再點一次標記按鈕
        -- 或直接選一個標記）。
        if picker and picker:IsShown() and not InCombatLockdown()
           and not picker:IsMouseOver() and not (markBtn and markBtn:IsMouseOver()) then
            picker:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingRefresh then
            pendingRefresh = false
            MarkBar.Refresh()
        end
    end
end)

ns.RegisterCallback("Init", "markbar", function()
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("GLOBAL_MOUSE_DOWN")
    MarkBar.Refresh()
end)
