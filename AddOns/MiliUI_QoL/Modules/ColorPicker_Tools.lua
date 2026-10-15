------------------------------------------------------------
-- MiliUI_QoL: 調色盤工具列（暴雪 ColorPickerFrame 右邊多一塊）（2026-10 從本體 MiliUI/Enhance 搬來）
--
-- 內容：
--   * R／G／B（0～255）與透明度（0～100，只在該次選色有透明度時出現）數值輸入
--   * 複製／貼上：存的是 RGBA，跨重載保留（MiliUI_QoL_DB.colorPicker.clip）
--   * 職業色一排：點一下套用
--   * 最近使用：按「確定」收下來的顏色，最多 7 個（MiliUI_QoL_DB.colorPicker.recent）
-- 所有呼叫暴雪調色盤的地方（聊天設定、套組各插件的色票、第三方插件）都會長出來。
-- 開關讀寫於 MiliUI_QoL_DB.colorPicker.enabled（預設 true），關掉就整塊藏起來。
--
-- ## taint 紀律
--
-- 出處：Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.lua（12.x live）
--   :3   OnColorSelect 腳本：更新色塊／hex 框，接著叫呼叫端給的 swatchFunc／opacityFunc
--   :20  確定鈕 OnClick：swatchFunc → opacityFunc → Hide
--   :69  GLOBAL_MOUSE_DOWN：點在調色盤「祖先鏈」以外就當取消
--
--   * 不在 ColorPickerFrame 或它的子框上寫任何 Lua 欄位，也不 hooksecurefunc 它的方法
--     （那會把實例上的欄位換成包裝函式）。掛點只有 HookScript：框的 OnShow／OnHide、
--     確定鈕的 OnClick、ColorSelect 的 OnColorSelect —— 都是安全掛勾。
--   * 工具列是 ColorPickerFrame 的**子框**：:69 的「點外面＝取消」看的是祖先鏈，
--     掛在 UIParent 上的話玩家一點我們的按鈕，暴雪就先把調色盤取消掉了。
--   * 套用顏色只呼叫 ColorSelect 的 C 方法（SetColorRGB／SetColorAlpha）。暴雪的
--     OnColorSelect 會在我們的執行裡跑，叫到的是**開調色盤那一方**的回呼 ——
--     這跟玩家用滑鼠拖色輪是同一條路，只是執行歸屬算我們的。調色盤不是保護框，
--     也沒有暴雪的保護流程會讀它的欄位，所以這裡是安全的。
--   * 有別的調色盤增強插件在就整支不動（兩塊工具列疊在一起沒意義）。
------------------------------------------------------------
local _, ns = ...
if ns.legacyCore then return end

-- ns.W（共用層）在 QoL 的 TOC 排在 Modules\ 之後，檔案載入當下還是 nil ⇒ Build 時才取
-- （用到 W 的 Label／CreateSwatch／NumberRow 都只從 Build 裡叫）
local W

local PANEL_W   = 132
local PAD       = 8
local SWATCH    = 14
local GAP       = 3
local PER_ROW   = 7
local RECENT_MAX = 7

local OTHER_PICKERS = { "ColorPickerPlus", "ColorTools", "ColorPickerExtensions" }

local function GetDB()
    -- ns.db（＝MiliUI_QoL_DB）在自己的 ADDON_LOADED 才有；那之前不會有人叫到這裡，
    -- 萬一有就給一份預設值，不碰存檔
    local root = ns.db
    if not root then return { enabled = true, recent = {} } end
    local db = root.colorPicker
    if type(db) ~= "table" then
        db = {}
        root.colorPicker = db
    end
    if db.enabled == nil then db.enabled = true end
    if type(db.recent) ~= "table" then db.recent = {} end
    return db
end

local function IsEnabled() return GetDB().enabled and true or false end

local function Plain(v)
    return not (issecretvalue and issecretvalue(v))
end

local function ValidChannel(v)
    return Plain(v) and type(v) == "number" and v == v and v >= 0 and v <= 1
end

local function ValidColor(c)
    return type(c) == "table" and ValidChannel(c[1]) and ValidChannel(c[2])
        and ValidChannel(c[3]) and ValidChannel(c[4])
end

local function To255(v) return math.floor(v * 255 + 0.5) end

local function SameColor(a, b)
    for i = 1, 4 do
        if To255(a[i]) ~= To255(b[i]) then return false end
    end
    return true
end

local function Hex(c)
    return string.format("%02X%02X%02X", To255(c[1]), To255(c[2]), To255(c[3]))
end

------------------------------------------------------------
-- 讀／寫調色盤
------------------------------------------------------------
local picker            -- ColorPickerFrame
local colorSerial = 0   -- OnColorSelect 觸發一次 +1：判斷 SetColorAlpha 有沒有連帶觸發

local function HasOpacity()
    return picker and picker.hasOpacity and true or false
end

local function ReadColor()
    local r, g, b = picker:GetColorRGB()
    local a = HasOpacity() and picker:GetColorAlpha() or 1
    local c = { r, g, b, a }
    if not ValidColor(c) then return nil end
    return c
end

local function CallSafe(fn)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn)
    if not ok then geterrorhandler()(err) end
end

local function WriteColor(c, withAlpha)
    if not picker or not picker:IsShown() or not ValidColor(c) then return end
    local wheel = picker.Content and picker.Content.ColorPicker
    if not wheel then return end
    wheel:SetColorRGB(c[1], c[2], c[3])
    if withAlpha and HasOpacity() then
        local serial = colorSerial
        wheel:SetColorAlpha(c[4])
        -- 透明度在某些版本不會連帶觸發 OnColorSelect；沒觸發就自己叫一次 opacityFunc，
        -- 不然呼叫端拿不到新的透明度（叫兩次無害：它只是「讀目前值套上去」）
        if colorSerial == serial then CallSafe(picker.opacityFunc) end
    end
end

------------------------------------------------------------
-- 最近使用
------------------------------------------------------------
local function Remember(c)
    if not ValidColor(c) then return end
    local list = GetDB().recent
    for i = #list, 1, -1 do
        if not ValidColor(list[i]) or SameColor(list[i], c) then table.remove(list, i) end
    end
    table.insert(list, 1, { c[1], c[2], c[3], c[4] })
    while #list > RECENT_MAX do table.remove(list) end
end

------------------------------------------------------------
-- 工具列
------------------------------------------------------------
local panel
local boxes = {}            -- r / g / b / a 四個數字框
local alphaRow              -- 透明度那一列（標籤＋框），沒透明度時藏起來
local lowerBlock            -- 透明度列以下的全部，跟著上移下移
local pasteBtn, clipSwatch
local recentSwatches = {}
local recentEmpty

local function Label(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontSmall)
    fs:SetTextColor(0.7, 0.7, 0.7)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function ShowSwatchTip(self)
    if not self.color then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if self.tipTitle then GameTooltip:AddLine(self.tipTitle, 1, 1, 1) end
    GameTooltip:AddLine("#" .. Hex(self.color), 0.8, 0.8, 0.8)
    if HasOpacity() and self.useAlpha then
        GameTooltip:AddLine(string.format("透明度 %d%%", math.floor(self.color[4] * 100 + 0.5)), 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

local function CreateSwatch(parent)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(SWATCH, SWATCH)
    W.Stylize(b, { 1, 1, 1, 1 })
    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 1, 1, 1)
        ShowSwatchTip(self)
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0, 0, 0, 1)
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(self)
        if self.color then WriteColor(self.color, self.useAlpha) end
    end)
    function b:SetSwatchColor(c)
        self.color = c
        if c then
            self:SetBackdropColor(c[1], c[2], c[3], 1)
            self:Show()
        else
            self:Hide()
        end
    end
    return b
end

local function PlaceGrid(list, parent, anchor, yOff)
    for i, sw in ipairs(list) do
        local col, row = (i - 1) % PER_ROW, math.floor((i - 1) / PER_ROW)
        sw:ClearAllPoints()
        sw:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", col * (SWATCH + GAP), yOff - row * (SWATCH + GAP))
    end
end

local function RefreshBoxes()
    if not panel or not panel:IsShown() then return end
    local c = ReadColor()
    if not c then return end
    local vals = { r = To255(c[1]), g = To255(c[2]), b = To255(c[3]), a = math.floor(c[4] * 100 + 0.5) }
    for key, eb in pairs(boxes) do
        -- 正在打字的那一格不要被拖色輪的即時值蓋掉
        if not eb:HasFocus() and eb:GetValue() ~= vals[key] then eb:SetValue(vals[key]) end
    end
end

local function RefreshClip()
    local clip = GetDB().clip
    local ok = ValidColor(clip)
    pasteBtn:SetEnabled(ok)
    clipSwatch:SetSwatchColor(ok and clip or nil)
end

local function RefreshRecent()
    local list = GetDB().recent
    local n = 0
    for i = 1, RECENT_MAX do
        local c = list[i]
        local sw = recentSwatches[i]
        if ValidColor(c) then
            n = n + 1
            sw:SetSwatchColor(c)
        else
            sw:SetSwatchColor(nil)
        end
    end
    recentEmpty:SetShown(n == 0)
end

local function Layout()
    local hasA = HasOpacity()
    alphaRow:SetShown(hasA)
    -- 數字列一列 18 高＋6 間距；最後一列下面再空 4 才接複製鈕
    local top = PAD + (hasA and 4 or 3) * 24 + 4
    lowerBlock:ClearAllPoints()
    lowerBlock:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -top)
    lowerBlock:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    panel:SetHeight(top + lowerBlock:GetHeight() + PAD)
end

local function NumberRow(parent, key, text, maxV, anchor)
    local eb = W.CreateNumberBox(parent, 52, 1, function(v)
        local c = ReadColor()
        if not c then return end
        v = math.max(0, math.min(maxV, math.floor(v + 0.5)))
        if key == "a" then
            c[4] = v / 100
            WriteColor(c, true)
        else
            local idx = (key == "r" and 1) or (key == "g" and 2) or 3
            c[idx] = v / 255
            WriteColor(c, false)
        end
        RefreshBoxes()
    end)
    if anchor then
        eb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    else
        eb:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD + 46, -PAD)
    end
    local lb = Label(parent, text)
    lb:SetPoint("RIGHT", eb, "LEFT", -6, 0)
    boxes[key] = eb
    return eb, lb
end

local function Build()
    W = W or ns.W
    panel = W.CreateFrame(nil, picker, PANEL_W, 200)
    panel:SetPoint("TOPLEFT", picker, "TOPRIGHT", 2, 0)
    panel:SetBackdropColor(0.06, 0.06, 0.06, 0.95)

    local r = NumberRow(panel, "r", "紅", 255)
    local g = NumberRow(panel, "g", "綠", 255, r)
    NumberRow(panel, "b", "藍", 255, g)

    -- 透明度列包一層，才能整列藏起來
    alphaRow = CreateFrame("Frame", nil, panel)
    alphaRow:SetSize(52, 18)
    alphaRow:SetPoint("TOPLEFT", boxes.b, "BOTTOMLEFT", 0, -6)
    local a = NumberRow(alphaRow, "a", "透明度", 100)
    a:ClearAllPoints()
    a:SetAllPoints(alphaRow)
    local pct = Label(alphaRow, "%")
    pct:SetPoint("LEFT", a, "RIGHT", 4, 0)

    lowerBlock = CreateFrame("Frame", nil, panel)

    -- 複製／貼上
    local copyBtn = W.CreateButton(lowerBlock, "複製", "normal", 44, 20)
    copyBtn:SetPoint("TOPLEFT", lowerBlock, "TOPLEFT", 0, 0)
    copyBtn:SetScript("OnClick", function()
        local c = ReadColor()
        if not c then return end
        GetDB().clip = c
        RefreshClip()
    end)
    pasteBtn = W.CreateButton(lowerBlock, "貼上", "normal", 44, 20)
    pasteBtn:SetPoint("LEFT", copyBtn, "RIGHT", 4, 0)
    pasteBtn:SetScript("OnClick", function()
        local clip = GetDB().clip
        if ValidColor(clip) then WriteColor(clip, true) end
        RefreshBoxes()
    end)
    clipSwatch = CreateSwatch(lowerBlock)
    clipSwatch:SetPoint("LEFT", pasteBtn, "RIGHT", 4, 0)
    clipSwatch.tipTitle = "剪貼簿"
    clipSwatch.useAlpha = true

    -- 職業色
    local classTitle = Label(lowerBlock, "職業色")
    classTitle:SetPoint("TOPLEFT", copyBtn, "BOTTOMLEFT", 0, -8)
    local classSwatches = {}
    for _, token in ipairs(CLASS_SORT_ORDER or {}) do
        local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
        if cc then
            local sw = CreateSwatch(lowerBlock)
            sw:SetSwatchColor({ cc.r, cc.g, cc.b, 1 })
            sw.tipTitle = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token
            classSwatches[#classSwatches + 1] = sw
        end
    end
    PlaceGrid(classSwatches, lowerBlock, classTitle, -4)
    local classRows = math.max(1, math.ceil(#classSwatches / PER_ROW))

    -- 最近使用
    local recentTitle = Label(lowerBlock, "最近使用")
    recentTitle:SetPoint("TOPLEFT", classTitle, "BOTTOMLEFT", 0,
        -4 - classRows * (SWATCH + GAP) - 6)
    for i = 1, RECENT_MAX do
        local sw = CreateSwatch(lowerBlock)
        sw.useAlpha = true
        recentSwatches[i] = sw
    end
    PlaceGrid(recentSwatches, lowerBlock, recentTitle, -4)
    recentEmpty = Label(lowerBlock, "還沒有記錄")
    recentEmpty:SetPoint("TOPLEFT", recentTitle, "BOTTOMLEFT", 0, -4)

    -- 高度照內容算：按鈕 20、職業色標題＋格子、最近使用標題＋一排格子
    lowerBlock:SetHeight(20 + 8 + 12 + 4 + classRows * (SWATCH + GAP) + 6 + 12 + 4 + SWATCH)

    -- 拖色輪時數字要跟著跑：OnColorSelect 只在換 RGB 時觸發，拖透明度那一條不一定，
    -- 所以補一個 0.1 秒的輕量輪詢（只在調色盤開著時跑）
    local elapsed = 0
    panel:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.1 then return end
        elapsed = 0
        RefreshBoxes()
    end)
end

local function OtherPickerLoaded()
    for _, name in ipairs(OTHER_PICKERS) do
        if C_AddOns.IsAddOnLoaded(name) then return true end
    end
    return false
end

local function OnPickerShow()
    if not IsEnabled() then
        if panel then panel:Hide() end
        return
    end
    if not panel then Build() end
    Layout()
    RefreshClip()
    RefreshRecent()
    panel:Show()
    RefreshBoxes()
end

local installed = false
local function Install()
    if installed then return end
    local f = _G.ColorPickerFrame
    local wheel = f and f.Content and f.Content.ColorPicker
    local okay = f and f.Footer and f.Footer.OkayButton
    if not (wheel and okay and f.GetColorRGB and f.GetColorAlpha) then return end
    if f.IsForbidden and f:IsForbidden() then return end
    if OtherPickerLoaded() then
        installed = true    -- 讓位：不掛任何東西
        return
    end
    installed = true
    picker = f
    f:HookScript("OnShow", OnPickerShow)
    wheel:HookScript("OnColorSelect", function() colorSerial = colorSerial + 1 end)
    okay:HookScript("OnClick", function()
        if not IsEnabled() then return end
        local c = ReadColor()
        if c then Remember(c) end
    end)
    -- 已經開著（極少見：載入當下剛好有人開了調色盤）就補畫一次
    if f:IsShown() then OnPickerShow() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(self, event, name)
    if event == "PLAYER_LOGIN" or name == "Blizzard_ColorPickerFrame" then
        Install()
        if installed then self:UnregisterAllEvents() end
    end
end)

------------------------------------------------------------
-- 對外（給 Options/Controls.lua 用）
------------------------------------------------------------
ns.ColorPickerTools = {
    IsEnabled = IsEnabled,
    SetEnabled = function(v)
        GetDB().enabled = v and true or false
        if panel then panel:SetShown(v and picker and picker:IsShown() or false) end
        if v and picker and picker:IsShown() then OnPickerShow() end
    end,
    IsStandingDown = function() return installed and picker == nil end,
}
