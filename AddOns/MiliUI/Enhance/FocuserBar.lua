------------------------------------------------------------
-- MiliUI Focuser 標記切換列
-- 樣式抄 MiliUI_BurstPotionHelper/Bar.lua（1px 邊框 + 深色底 + 左側拖曳握把）
-- 兩顆按鈕：
--   1. 標記圖示：點擊彈出 8 格選單自行點選，切換焦點自動標記的圖示，
--      並立即重標目前焦點（走 raidtarget 安全動作，戰鬥中可用）
--   2. 宣告：把「我的焦點自動標記圖示是哪個」送到 副本/團隊/隊伍 頻道
--      （{icon} → {rtN}；宣告的是設定的圖示，不讀焦點單位，避開秘密值）
-- 整條工具列都是非安全框架，戰鬥中顯示 / 點擊皆合法。
------------------------------------------------------------
MiliUI_FocuserBar = {}

local ICON_SIZE  = 34
local ICON_SPACE = 5
local PADDING    = 6
local GRIP_WIDTH = 12

-- 預設放在爆發藥水列（y=10%）上方一點，避免兩條疊在一起
local DEFAULT_Y_FRACTION = 0.16

local DEFAULT_ANNOUNCE = "我的焦點打斷目標是{icon}！"

-- 宣告按鈕：MiliUI 自製的簡約廣播喇叭（白色線條+透明底 64x64 TGA，
-- 產生器：Interface/.agent/gen_announce_icon.py）
local ANNOUNCE_ICON    = "Interface\\AddOns\\MiliUI\\Media\\announce"
local MARK_NONE_ICON   = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local MARKS_TEXTURE    = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

-- MiliUI 慣用「無邊框」外觀：1px 像素邊 + 深色半透明底
local MILIUI_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

local bar, markBtn, announceBtn
local picker, pickerCells

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.focuserBarShown == nil then MiliUI_DB.focuserBarShown = false end
    if MiliUI_DB.focuserAnnounceText == nil then MiliUI_DB.focuserAnnounceText = DEFAULT_ANNOUNCE end
    return MiliUI_DB
end

----------------------------------------------------------------------
-- 標記圖示
----------------------------------------------------------------------
-- UI-RaidTargetingIcons 是 4x4 圖集，1-8 由左至右、由上而下
local function SetMarkTexCoord(tex, index)
    local col = (index - 1) % 4
    local row = math.floor((index - 1) / 4)
    tex:SetTexCoord(col * 0.25, col * 0.25 + 0.25, row * 0.25, row * 0.25 + 0.25)
end

local function UpdateMarkIcon()
    local index = MiliUI_Focuser and MiliUI_Focuser.GetMarkIndex() or 0
    if markBtn then
        if index >= 1 and index <= 8 then
            markBtn.icon:SetTexture(MARKS_TEXTURE)
            SetMarkTexCoord(markBtn.icon, index)
        else
            -- 尚未選過標記：顯示紅色禁止圖（同爆發藥水列的「不用藥水」格）
            markBtn.icon:SetTexture(MARK_NONE_ICON)
            markBtn.icon:SetTexCoord(0, 1, 0, 1)
        end
    end
    -- 選單上目前選擇的黃框（同藥水列 selected border）
    if pickerCells then
        for i, cell in ipairs(pickerCells) do
            cell.border:SetShown(i == index)
        end
    end
end

-- 點選標記後的非安全記帳（實際標記由格子的 raidtarget 安全動作執行）
local function OnPickMark(index)
    if not MiliUI_Focuser then return end
    -- SetMarkIndex 內部處理巨集更新（戰鬥中自動延後到脫戰）
    MiliUI_Focuser.SetMarkIndex(index)
    UpdateMarkIcon()
    -- 收合選單交給安全 postbody（放開邊緣）；這裡不能收——本函式在
    -- 按下邊緣執行，先收會把放開邊緣才觸發的標記動作吃掉
end

----------------------------------------------------------------------
-- 標記選單：點圖示按鈕彈出，8 個標記排成 4x2，點選後套用並關閉。
-- 12.0 Midnight 起 SetRaidTarget 是（戰鬥）保護函式，插件不能直接呼叫，
-- 標記改走 Blizzard 的 raidtarget 安全動作（SECURE_ACTIONS.raidtarget：
-- 讀 marker / action / unit 屬性）。因此格子是保護按鈕，選單的開關
-- 也必須走 SecureHandler 快照（戰鬥中一般程式不能 Show/Hide 保護框架）。
----------------------------------------------------------------------
local PICK_SIZE  = 28
local PICK_SPACE = 4

local function CreatePicker()
    if picker then return picker end
    -- SecureHandlerBaseTemplate：讓安全快照拿得到 picker 的 handle 來開關
    picker = CreateFrame("Frame", "MiliUI_FocuserMarkPicker", bar,
        "SecureHandlerBaseTemplate,BackdropTemplate")
    local w = PADDING * 2 + PICK_SIZE * 4 + PICK_SPACE * 3
    local h = PADDING * 2 + PICK_SIZE * 2 + PICK_SPACE
    picker:SetSize(w, h)
    picker:SetPoint("BOTTOM", markBtn, "TOP", 0, PADDING + 2)
    picker:SetBackdrop(MILIUI_BACKDROP)
    picker:SetBackdropColor(0.06, 0.06, 0.10, 0.92)
    picker:SetBackdropBorderColor(0, 0, 0, 1)
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
    table.insert(UISpecialFrames, "MiliUI_FocuserMarkPicker")

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
        -- 所以 down/up 兩個邊緣都註冊也不會閃爍（抄藥水列的註冊方式）
        cell:RegisterForClicks("AnyDown", "AnyUp")
        cell:SetAttribute("type1", "raidtarget")
        cell:SetAttribute("marker", i)
        cell:SetAttribute("action1", "set")
        cell:SetAttribute("unit", "focus")

        -- 點選後在安全環境裡：收起選單 + 把 FocuserButton 的巨集換成
        -- 此編號對應的版本（受限環境可改保護屬性，戰鬥中也能執行，
        -- 這樣戰鬥中換圖示後，下一次 Shift+點擊立刻用新標記）。
        -- 巨集文字預存在格子的 focusermacro 屬性（SyncCellMacros 維護）。
        -- OnClick wrap 的 prebody 回傳值是 (改寫按鍵, message)，
        -- postbody 只在 message 非 nil 時執行：按鍵不改，第一個回 nil
        SecureHandlerSetFrameRef(cell, "picker", picker)
        local focuserBtn = MiliUI_Focuser and MiliUI_Focuser.GetFocuserButton
            and MiliUI_Focuser.GetFocuserButton()
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

        -- 目前選擇的黃框（同藥水列）
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
            GameTooltip:SetText(_G["RAID_TARGET_" .. i] or ("標記 " .. i))
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", GameTooltip_Hide)

        pickerCells[i] = cell
    end

    MiliUI_FocuserBar.SyncCellMacros()   -- 預存各編號的巨集文字
    UpdateMarkIcon()                     -- 套上目前選擇的黃框
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

-- 組出宣告訊息。宣告的是「設定的自動標記圖示」（告訴隊友：這個標記就是
-- 我的焦點打斷目標），不讀焦點身上的標記，所以不需要焦點存在。
-- forChat = true 用 {rtN}（送進頻道由客戶端轉圖示）；
-- false 用 |T...|t 材質跳脫（print / tooltip 本地顯示用，{rtN} 在本地不會轉）
local function BuildAnnounceMessage(forChat)
    local index = MiliUI_Focuser and MiliUI_Focuser.GetMarkIndex() or 0
    if index < 1 or index > 8 then
        return nil, "還沒選擇標記圖示，請先點左邊的圖示選一個。"
    end
    local iconToken
    if forChat then
        iconToken = "{rt" .. index .. "}"
    else
        iconToken = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. index .. ":16|t"
    end
    local text = GetDB().focuserAnnounceText or DEFAULT_ANNOUNCE
    return (text:gsub("{icon}", iconToken))
end

local lastAnnounce = 0
local function Announce()
    -- 防連點洗頻
    if GetTime() - lastAnnounce < 1 then return end
    local msg, err = BuildAnnounceMessage(true)
    if not msg then
        print("|cffff6600[MiliUI]|r " .. err)
        return
    end
    lastAnnounce = GetTime()
    local channel = GetAnnounceChannel()
    if channel then
        SendChatMessage(msg, channel)
    else
        -- 本地預覽：{rtN} 不會被聊天框轉換，改用材質跳脫顯示
        print("|cffff6600[MiliUI]|r 未加入隊伍，宣告內容：" .. BuildAnnounceMessage(false))
    end
end

----------------------------------------------------------------------
-- 位置（抄爆發藥水列：BOTTOMLEFT 錨定，拖完存左/下緣座標）
----------------------------------------------------------------------
local function PositionBar()
    if not bar then return end
    local db = GetDB()
    if not db.focuserBarX then
        db.focuserBarX = math.max(0, math.floor((UIParent:GetWidth() - bar:GetWidth()) / 2))
    end
    if not db.focuserBarY then
        db.focuserBarY = math.floor(UIParent:GetHeight() * DEFAULT_Y_FRACTION)
    end
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", db.focuserBarX, db.focuserBarY)
end

local function SavePosition()
    local x, y = bar:GetLeft(), bar:GetBottom()
    if not (x and y) then return end
    local db = GetDB()
    db.focuserBarX, db.focuserBarY = x, y
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

----------------------------------------------------------------------
-- 建立
----------------------------------------------------------------------
local function OpenFocusSettings()
    if InCombatLockdown() then
        print("|cff00ff00[MiliUI]|r 戰鬥中無法開啟。")
        return
    end
    if not (Settings and Settings.OpenToCategory) then return end
    -- Blizzard 12.0+ OpenToCategory 需要 numeric ID；「焦點目標」子分類的 ID
    -- 被覆寫成字串 "MiliUI_Focus"，非數字時退回 MiliUI 主分類（同 GameMenu 入口做法）
    local cat = MiliUI and MiliUI.FocusSettingsCategory
    local id = cat and (cat.GetID and cat:GetID() or cat.ID)
    if type(id) ~= "number" then
        cat = MiliUI and MiliUI.SettingsCategory
        id = cat and (cat.GetID and cat:GetID() or cat.ID)
    end
    if type(id) == "number" then
        Settings.OpenToCategory(id)
    elseif cat then
        Settings.OpenToCategory(cat)
    end
end

local function CreateButton(parent, template)
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
    local db = GetDB()

    local width = PADDING * 2 + GRIP_WIDTH + 4 + ICON_SIZE * 2 + ICON_SPACE
    bar = CreateFrame("Frame", "MiliUI_FocuserBarFrame", UIParent, "BackdropTemplate")
    bar:SetSize(width, PADDING * 2 + ICON_SIZE)
    bar:SetClampedToScreen(true)
    bar:SetMovable(true)
    bar:SetBackdrop(MILIUI_BACKDROP)
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

    -- 三條橫線的握把記號（本列沒有收合功能，不用藥水列的箭頭）
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
        if mouseButton == "RightButton" then OpenFocusSettings() end
    end)
    grip:SetScript("OnEnter", function()
        GameTooltip:SetOwner(grip, "ANCHOR_RIGHT")
        GameTooltip:SetText("焦點標記切換列")
        GameTooltip:AddLine("左鍵拖曳移動", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("右鍵開啟設定", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", GameTooltip_Hide)

    -- 按鈕 1：焦點標記圖示（點擊彈出選單自行點選）。
    -- 選單含保護按鈕，開關必須在安全環境執行（戰鬥中才不會被擋），
    -- 所以這顆是 SecureHandlerClickTemplate，用 _onclick 快照切換
    markBtn = CreateButton(bar, "SecureHandlerClickTemplate")
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
        GameTooltip:SetText("切換焦點標記圖示")
        GameTooltip:AddLine("點擊開啟選單，選一個標記圖示", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("選擇後會立即重標目前的焦點目標（戰鬥中可用）", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("戰鬥中切換時，Shift+點擊巨集的標記編號會在脫戰後更新", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    markBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- 按鈕 2：宣告焦點目標
    announceBtn = CreateButton(bar)
    announceBtn:SetPoint("LEFT", markBtn, "RIGHT", ICON_SPACE, 0)
    -- 線條風自製圖示，保留 4px 留白（不像技能圖示要填滿裁邊）
    announceBtn.icon:SetTexture(ANNOUNCE_ICON)
    announceBtn:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then Announce() end
    end)
    announceBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("宣告焦點標記")
        local msg = BuildAnnounceMessage(false)   -- tooltip 用材質跳脫顯示圖示
        if msg then
            GameTooltip:AddLine(msg, 1, 1, 1)
        end
        local channelNames = {
            INSTANCE_CHAT = "副本頻道", RAID = "團隊頻道", PARTY = "隊伍頻道",
        }
        local channel = GetAnnounceChannel()
        GameTooltip:AddLine("發送到：" .. (channelNames[channel] or "（未組隊，只顯示給自己）"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine("宣告內容可在設定內修改", 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    announceBtn:SetScript("OnLeave", GameTooltip_Hide)

    UpdateMarkIcon()
    PositionBar()
    return bar
end

----------------------------------------------------------------------
-- 顯示邏輯：選項開啟 + Focuser 功能啟用才顯示
-- （純非安全框架，戰鬥中 Show/Hide 也合法）
----------------------------------------------------------------------
local function ShouldShow()
    return GetDB().focuserBarShown
        and MiliUI_Focuser and MiliUI_Focuser.IsEnabled()
end

local pendingRefresh = false

function MiliUI_FocuserBar.Refresh()
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
        bar:Show()
    elseif bar then
        picker:Hide()
        bar:Hide()
    end
end

----------------------------------------------------------------------
-- 公開 API（給 Settings.lua / Focuser.lua 用）
----------------------------------------------------------------------
function MiliUI_FocuserBar.IsShown()
    return GetDB().focuserBarShown
end

function MiliUI_FocuserBar.SetShown(val)
    GetDB().focuserBarShown = val and true or false
    MiliUI_FocuserBar.Refresh()
end

function MiliUI_FocuserBar.GetAnnounceText()
    return GetDB().focuserAnnounceText
end

function MiliUI_FocuserBar.SetAnnounceText(text)
    if not text or text == "" then text = DEFAULT_ANNOUNCE end
    GetDB().focuserAnnounceText = text
end

function MiliUI_FocuserBar.GetDefaultAnnounceText()
    return DEFAULT_ANNOUNCE
end

-- 標記圖示在設定面板改變時同步列上的圖示
function MiliUI_FocuserBar.UpdateMarkIcon()
    UpdateMarkIcon()
end

-- 預存「選了編號 i 時 FocuserButton 該用的巨集文字」到各格子的屬性，
-- 讓格子的安全快照能在戰鬥中直接換上。自動標記/清除標記等設定改變時
-- 由 Focuser.SwitchMacro 呼叫重算（保護屬性，只能脫戰寫；戰鬥中改設定
-- 由 Focuser 的 pendingMacro 延後到脫戰，屆時會再進到這裡）
function MiliUI_FocuserBar.SyncCellMacros()
    if not pickerCells then return end
    if InCombatLockdown() then return end
    if not (MiliUI_Focuser and MiliUI_Focuser.GetMacroForMarkIndex) then return end
    for i, cell in ipairs(pickerCells) do
        cell:SetAttribute("focusermacro", MiliUI_Focuser.GetMacroForMarkIndex(i))
    end
end

function MiliUI_FocuserBar.ResetPosition()
    local db = GetDB()
    db.focuserBarX, db.focuserBarY = nil, nil
    PositionBar()
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("GLOBAL_MOUSE_DOWN")
ev:SetScript("OnEvent", function(_, event)
    if event == "GLOBAL_MOUSE_DOWN" then
        -- 點選單以外的地方收起選單。排除標記按鈕本身（它的安全 _onclick
        -- 自己會切換，這裡先收會互相抵消變成永遠關不掉／關了又開）。
        -- 戰鬥中不能從一般程式隱藏保護框架，略過（可用 ESC 以外的
        -- 方式：再點一次標記按鈕或直接選一個標記）。
        if picker and picker:IsShown() and not InCombatLockdown()
           and not picker:IsMouseOver() and not (markBtn and markBtn:IsMouseOver()) then
            picker:Hide()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingRefresh then
            pendingRefresh = false
            MiliUI_FocuserBar.Refresh()
        end
    else
        MiliUI_FocuserBar.Refresh()
    end
end)
