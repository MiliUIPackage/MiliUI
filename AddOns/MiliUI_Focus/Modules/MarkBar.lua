------------------------------------------------------------
-- 標記切換列
-- 兩顆按鈕：
--   1. 標記圖示：點擊彈出 8 格選單自行點選，切換專注目標自動標記的圖示，
--      並立即重標目前的專注目標（走 raidtarget 安全動作，戰鬥中可用）
--   2. 宣告：把「我的專注目標自動標記圖示是哪個」送到 副本/團隊/隊伍 頻道
--      （{icon} → {rtN}；宣告的是設定的圖示，不讀專注目標單位，避開秘密值）。
--      走巨集書裡的保留巨集（Modules/AnnounceMacro.lua），M+／首領戰中也送得出去；
--      巨集掛不上（沒組隊、欄位滿）才退回 Lua 路徑。
--      右鍵切換「每次設專注目標都宣告」（開著時角落掛「自動」）。
-- 整條工具列本身是非安全框架，但選單格子與宣告鈕是保護按鈕（標記只能走安全動作、
-- 宣告只能走巨集），所以開關與建立都要 InCombatLockdown 守衛。
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
                    -- 「每次設專注目標都宣告」的巨集書巨集戰鬥中改不了，標記換了
                    -- 就先不跑它（退回 macrotext），脫戰由 AnnounceMacro 掛回來
                    if fb:GetAttribute("macrotext") ~= macro then
                        fb:SetAttribute("macro", nil)
                        fb:SetAttribute("macrorelease", nil)
                        fb:SetAttribute("macro1", nil)
                    end
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
    return ns.AnnounceMacro.GetChannel()
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

-- 宣告訊息本體在 Modules/AnnounceMacro.lua（巨集與這裡的預覽要同一句）。
-- forChat = true 用 {rtN}；false 用材質跳脫（tooltip／print 本地顯示用）
local function BuildAnnounceMessage(forChat)
    return ns.AnnounceMacro.BuildMessage(forChat)
end

-- 宣告鈕的可用狀態：送不出去時把圖示壓暗（套組慣例，狀態只換明暗不換色）。
-- 巨集掛著就送得出去（M+／首領戰也一樣）；只有退回 Lua 路徑又遇到聊天封鎖
-- 才是真的送不出去。只碰材質顏色，戰鬥中隨時能做。
local function UpdateAnnounceState()
    if not announceBtn then return end
    local blocked = not ns.AnnounceMacro.IsUsable() and ns.IsChatRestricted()
    local g = blocked and 0.42 or 1
    announceBtn.icon:SetVertexColor(g, g, g)
end

-- 「每次設專注目標都宣告」開著的話，喇叭鈕角落掛「自動」小字
local function UpdateAnnounceModeBadge()
    if not announceBtn then return end
    announceBtn.autoText:SetShown(DB().announceOnMark and true or false)
end

-- 喇叭鈕右鍵：切換「每次設專注目標都宣告」
local function ToggleAnnounceOnMark()
    local db = DB()
    db.announceOnMark = not db.announceOnMark
    UpdateAnnounceModeBadge()
    local L = ns.L
    if db.announceOnMark then
        ns.Print(L["Announce on every focus: |cff00ff00on|r"])
        if ns.Focuser.GetEffectiveMarkIndex() < 1 then
            ns.Print(L["Auto-mark is off in the Focus settings, so nothing is announced until you turn it on."])
        end
    else
        ns.Print(L["Announce on every focus: |cffff5555off|r (click the speaker to announce)"])
    end
    if InCombatLockdown() then
        ns.Print(L["Takes effect after combat."])
    end
    -- AnnounceMacro.Refresh 會建／改第二顆巨集並切換巨集按鈕（戰鬥中延到脫戰）
    ns.Fire("SettingsChanged")
end

-- 巨集掛不上時的退路（沒組隊／還沒選標記／巨集欄位滿／內容太長）。
-- 正常情況點擊由按鈕的安全動作跑巨集，這裡不會被叫到。
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
    if not channel then
        -- 本地預覽：{rtN} 不會被聊天框轉換，改用材質跳脫顯示
        ns.Print(ns.L["Not in a group; the announcement would read:"]
            .. " " .. BuildAnnounceMessage(false))
        return
    end
    -- 12.x：M+ 計時中／首領戰／戰場，插件 Lua 送聊天訊息會被暴雪擋下（見
    -- Core/Init.lua 的限制閘）。不先問就送＝吃一個封鎖對話框，而且訊息還是沒出去。
    -- 走到這裡代表巨集那條路也不通，只能把**可以照打的原文**印出來。
    if ns.IsChatRestricted() then
        ns.Print("|cffff5555" .. ns.L["Blizzard blocks addon chat messages during Mythic+ runs, boss fights and battlegrounds. Type it yourself:"] .. "|r")
        print("   " .. msg)
        UpdateAnnounceState()   -- 鈕還亮著表示漏接了狀態事件，順手補上
        return
    end
    SendChatMessage(msg, channel)
end

-- 把巨集掛上宣告鈕（或拿掉）。保護屬性，只能脫戰寫；AnnounceMacro.Refresh 算完
-- 狀態後呼叫。明暗隨時可更新。
function MarkBar.ApplyAnnounceButton()
    if not announceBtn then return end
    UpdateAnnounceState()
    if InCombatLockdown() then return end
    if ns.AnnounceMacro.IsUsable() then
        announceBtn:SetAttribute("type1", "macro")
        announceBtn:SetAttribute("macro", ns.AnnounceMacro.MACRO_NAME)
    else
        announceBtn:SetAttribute("type1", nil)
        announceBtn:SetAttribute("macro", nil)
    end
end

----------------------------------------------------------------------
-- 位置（BOTTOMLEFT 錨定，拖完存左/下緣座標）
----------------------------------------------------------------------
-- 磁吸註冊表裡的名字（Libs/MiliUISnap.lua）。別條插件的 db.snapTo.target 記的就是它，
-- 改了名字等於把玩家吸好的組合拆掉
local SNAP_KEY = "focusMarkBar"

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
    -- 吸在別條上的話改錨到它身上（Libs/MiliUISnap.lua）；目標不在就維持上面的絕對座標
    if ns.Snap then ns.Snap.Restore(SNAP_KEY) end
end

local function SavePosition()
    local x, y = bar:GetLeft(), bar:GetBottom()
    if not (x and y) then return end
    local db = DB()
    db.x, db.y = x, y
    -- 吸著的時候錨點在別條身上，不能改回 UIParent（那會把「跟著走」拆掉）；
    -- x/y 照存，當作它哪天不在時的退路
    if ns.Snap and ns.Snap.IsAttached(SNAP_KEY) then return end
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
    if ns.Snap then
        ns.Snap.Register(SNAP_KEY, bar, {
            db = DB, attach = true, label = L["Focus marker bar"],
            -- 滑鼠淡出。active：標記選單彈在列的**上方**、不在列的矩形裡，
            -- 開著的時候整條不准淡（不然選標記的當下列自己糊掉）
            fade = {
                db = DB,
                active = function() return picker and picker:IsShown() end,
            },
        })
    end

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
        if InCombatLockdown() then return end
        if ns.Snap then ns.Snap.OnDragStart(SNAP_KEY) end   -- 拖自己＝先脫離
        bar:StartMoving()
    end)
    grip:SetScript("OnDragStop", function()
        bar:StopMovingOrSizing()
        if ns.Snap then ns.Snap.OnDragStop(SNAP_KEY) end    -- 放手離得近就吸上去
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

    -- 按鈕 1：專注標記圖示（點擊彈出選單自行點選）。
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

    -- 按鈕 2：宣告專注標記。
    -- SecureActionButton 跑巨集書裡的保留巨集（type1="macro"，屬性由
    -- ApplyAnnounceButton 掛）。真實滑鼠點擊在 SecureActionButton_OnClick 裡
    -- 只會在「放開」邊緣執行一次（isSecureAction 的滑鼠按下不算 useOnKeyDown），
    -- 所以上下兩個邊緣都註冊、不設 pressAndHoldAction，恰好送一次。
    announceBtn = CreateBarButton(bar, "SecureActionButtonTemplate")
    announceBtn:SetPoint("LEFT", markBtn, "RIGHT", ICON_SPACE, 0)
    announceBtn:RegisterForClicks("AnyDown", "AnyUp")
    -- 線條風自製圖示，保留 4px 留白（不像技能圖示要填滿裁邊）
    announceBtn.icon:SetTexture(ANNOUNCE_ICON)
    -- 「自動」角標：純白小字、靠右下，不換顏色（套組慣例，狀態只換明暗不換色）
    announceBtn.autoText = announceBtn:CreateFontString(nil, "OVERLAY")
    announceBtn.autoText:SetFont(ns.Media.Font(), 10, "OUTLINE")
    announceBtn.autoText:SetPoint("BOTTOMRIGHT", -1, 2)
    announceBtn.autoText:SetText(L["Auto"])
    UpdateAnnounceModeBadge()
    -- 巨集有掛上：安全動作已經送出，這裡只補「戰鬥中內容還沒更新」的提醒；
    -- 沒掛上：退回 Lua 路徑（印預覽／提示／封鎖時印原文）。放開邊緣做一次就好。
    -- 右鍵（type2 沒設，安全動作不做事）：切換「每次設專注目標都宣告」。
    announceBtn:SetScript("PostClick", function(_, mouseButton, down)
        if down then return end
        if mouseButton == "RightButton" then
            ToggleAnnounceOnMark()
            return
        end
        if mouseButton ~= "LeftButton" then return end
        if ns.AnnounceMacro.IsUsable() then
            if ns.AnnounceMacro.IsPending() then
                ns.Print(L["In combat: the announcement macro still holds the previous content; it updates after combat."])
            end
            return
        end
        Announce()
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
        local AM = ns.AnnounceMacro
        local macroName = "|cffffd200" .. AM.MACRO_NAME .. "|r"
        if AM.IsUsable() then
            GameTooltip:AddLine(L["Sent through the %s macro in your macro book, so it also goes out in Mythic+ and boss fights."]:format(macroName),
                0.6, 0.6, 0.6, true)
            if AM.IsPending() then
                GameTooltip:AddLine(L["Changed in combat: the macro still holds the previous content until combat ends."],
                    1, 0.6, 0.2, true)
            end
        elseif AM.GetState() == "noslot" then
            GameTooltip:AddLine(L["No free macro slot, so the %s announcement macro could not be created."]:format(macroName),
                1, 0.3, 0.3, true)
        elseif AM.GetState() == "toolong" then
            GameTooltip:AddLine(L["The announcement is longer than 255 bytes and does not fit in a macro; shorten the text."],
                1, 0.3, 0.3, true)
        end
        if not AM.IsUsable() and ns.IsChatRestricted() then
            GameTooltip:AddLine(L["Blizzard blocks addon chat messages during Mythic+ runs, boss fights and battlegrounds — right now this can only be printed to you."],
                1, 0.3, 0.3, true)
        end
        -- 「每次設專注目標都宣告」現況
        GameTooltip:AddLine(" ")
        if DB().announceOnMark then
            GameTooltip:AddLine(L["Announce on every focus: |cff00ff00on|r"], 1, 1, 1)
            local ms = AM.GetMarkState()
            local why = (ms == "noautomark" and L["Auto-mark is off in the Focus settings, so nothing is announced until you turn it on."])
                or (ms == "nogroup" and L["Not in a group: nothing to announce to yet."])
                or (ms == "noslot" and L["No free macro slot, so the %s macro could not be created."]:format("|cffffd200" .. AM.MARK_MACRO_NAME .. "|r"))
                or (ms == "toolong" and L["The announcement is longer than 255 bytes and does not fit in a macro; shorten the text."])
                or (ms == "failed" and L["Could not write the %s macro."]:format("|cffffd200" .. AM.MARK_MACRO_NAME .. "|r"))
            if why then
                GameTooltip:AddLine(why, 1, 0.3, 0.3, true)
            else
                GameTooltip:AddLine(L["Shift-click / the focus hotkey announces whenever it lands on a living enemy."], 0.6, 0.6, 0.6, true)
            end
        else
            GameTooltip:AddLine(L["Announce on every focus: |cffff5555off|r (click the speaker to announce)"], 1, 1, 1)
        end
        GameTooltip:AddLine(L["Right-click to toggle announcing on every focus"], 0.5, 0.8, 1)
        GameTooltip:AddLine(L["The announcement text can be changed in the settings"], 0.5, 0.8, 1)
        GameTooltip:Show()
    end)
    announceBtn:SetScript("OnLeave", GameTooltip_Hide)
    UpdateAnnounceState()

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
    -- 宣告巨集跟著列的顯示與設定走（列沒開就不建巨集；開了就把內容寫進去並掛上鈕）
    ns.AnnounceMacro.Refresh()
end

----------------------------------------------------------------------
-- 對外
----------------------------------------------------------------------
function MarkBar.UpdateMarkIcon()
    UpdateMarkIcon()
end

function MarkBar.UpdateAnnounceModeBadge()
    UpdateAnnounceModeBadge()
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

-- 淡出設定改過：立刻重算，不必等下一次輪詢（設定頁的 Apply 會叫）
function MarkBar.ApplyFade()
    if ns.Snap and ns.Snap.RefreshFade then ns.Snap.RefreshFade() end
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
        UpdateAnnounceState()
    else
        -- 限制狀態變了 → 重算宣告鈕的明暗。
        -- ⚠ ADDON_RESTRICTION_STATE_CHANGED 派送的當下，
        --   C_RestrictedActions.IsAddOnRestrictionActive 對「正在變的那個型別」
        --   一律回 false（官方文件明寫），所以要延一幀才讀得到終值。
        C_Timer.After(0, UpdateAnnounceState)
    end
end)

ns.RegisterCallback("Init", "markbar", function()
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("GLOBAL_MOUSE_DOWN")
    -- 限制狀態變動。有 ADDON_RESTRICTION_STATE_CHANGED 就只要它一個
    -- （Combat／Encounter／ChallengeMode／PvPMatch／Map／Chat 全包），
    -- 沒有才退回逐個情境事件
    if C_EventUtils and C_EventUtils.IsEventValid
       and C_EventUtils.IsEventValid("ADDON_RESTRICTION_STATE_CHANGED") then
        ev:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
    else
        ev:RegisterEvent("CHALLENGE_MODE_START")
        ev:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        ev:RegisterEvent("CHALLENGE_MODE_RESET")
        ev:RegisterEvent("ENCOUNTER_START")
        ev:RegisterEvent("ENCOUNTER_END")
    end
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")   -- 進副本／重載後對一次狀態
    MarkBar.Refresh()
end)
