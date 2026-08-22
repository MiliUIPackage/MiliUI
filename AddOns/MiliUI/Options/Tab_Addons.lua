------------------------------------------------------------
-- 「插件總覽」分頁：套組收錄插件的控制台
--
-- 左：分組清單（勾選開關＋圖示＋名稱），右：選中插件的詳情
-- （預覽圖／說明／CPU 用量／開啟設定按鈕）。
--
-- 開關模型是批次的：勾選變更先記在 pending，底部按「套用並重載」才一次
-- Enable/DisableAddOn ＋ ReloadUI——停用本來就要重載才生效，攢一批只重載一次。
-- 名冊（分組、指令、說明覆蓋）在 Options/Roster.lua。
------------------------------------------------------------
local _, ns = ...

local W, P = ns.W, ns.P

local LIST_X, LIST_W  = 16, 296
local DETAIL_X        = LIST_X + LIST_W + 8
local TOP_Y           = -46
local BAR_H           = 34          -- 底部套用列
local SHOT_W, SHOT_H  = 420, 210    -- 擷圖顯示區（2:1，檔案建議 840x420）
local SHOTS_PATH      = "Interface\\AddOns\\MiliUI\\Media\\Shots\\"
local CPU_TICK        = 2           -- 詳情面板 CPU 數字的更新間隔（秒）

local tab, list, detail
local items = {}                    -- 攤平後的清單（group 列 + entry 列）
local entriesByKey = {}
local autoByFolder = {}             -- 沒列名冊的插件的自動條目（快取，pending 的 key 才穩定）
local pending = {}                  -- key -> 期望的啟用狀態（跟現況不同才留著）
local selectedKey

local applyText, applyBtn, discardBtn, hintText

------------------------------------------------------------
-- 狀態查詢
------------------------------------------------------------
local function IsFolderEnabled(name)
    if not (C_AddOns.GetAddOnEnableState and Enum and Enum.AddOnEnableState) then return true end
    return C_AddOns.GetAddOnEnableState(name, (UnitName("player"))) ~= Enum.AddOnEnableState.None
end

-- 掃描而不是 GetAddOnInfo(name)：未安裝的名字丟進去行為不保證，掃描一定安全
local function GetInstalled()
    local installed = {}
    local total = C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or 0
    for i = 1, total do
        local name = C_AddOns.GetAddOnInfo(i)
        if name then installed[name] = true end
    end
    return installed
end

local function EntryEnabled(entry)
    return IsFolderEnabled(entry.folders[1])
end

local function EntryMeta(entry, field)
    return C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(entry.folders[1], field)
end

local function EntryTitle(entry)
    return EntryMeta(entry, "Title") or entry.folders[1]
end

local function EntryCPU(entry)
    if not (C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric
            and Enum.AddOnProfilerMetric and Enum.AddOnProfilerMetric.RecentAverageTime) then
        return nil
    end
    local total = 0
    for _, f in ipairs(entry.folders) do
        local ok, v = pcall(C_AddOnProfiler.GetAddOnMetric, f, Enum.AddOnProfilerMetric.RecentAverageTime)
        if ok and type(v) == "number" then total = total + v end
    end
    return total
end

------------------------------------------------------------
-- 開啟該插件設定的路由：自製走 MiliUI_MenuEntries、第三方走斜線指令、
-- 都沒有就試暴雪 Settings 分類。解析不到就回 nil（按鈕不長出來）。
------------------------------------------------------------
local function ResolveOpen(entry)
    if entry.menuKey and MiliUI_MenuEntries then
        for _, e in ipairs(MiliUI_MenuEntries) do
            if e.key == entry.menuKey and type(e.OnClick) == "function" then
                return function() e.OnClick(e) end
            end
        end
    end
    -- 指令先查 hash_SlashCmdList 確認真的有註冊——插件被停用（沒載入）時
    -- 指令不存在，這裡就自然解析失敗，不會出現一顆按了沒反應的按鈕
    if entry.slash then
        local hash = _G.hash_SlashCmdList
        local fn = hash and hash[string.upper(entry.slash)]
        if type(fn) == "function" then
            return function() pcall(fn, "") end   -- 處理器簽章是 (msg, editBox)，絕大多數不碰第二參數
        end
    end
    if entry.category and Settings and SettingsPanel and SettingsPanel.GetAllCategories then
        local ok, cats = pcall(SettingsPanel.GetAllCategories, SettingsPanel)
        if ok and type(cats) == "table" then
            for _, c in ipairs(cats) do
                if c.GetName and c:GetName() == entry.category then
                    return function()
                        local id = c.GetID and c:GetID()
                        pcall(Settings.OpenToCategory, id or c)
                    end
                end
            end
        end
    end
    return nil
end

------------------------------------------------------------
-- 套用列
------------------------------------------------------------
local function PendingCount()
    local n = 0
    for _ in pairs(pending) do n = n + 1 end
    return n
end

local function UpdateApplyBar()
    local n = PendingCount()
    if n > 0 then
        hintText:Hide()
        applyText:SetText(("|cffff9900%d 項變更待套用|r"):format(n))
        applyText:Show()
        applyBtn:Show()
        discardBtn:Show()
    else
        applyText:Hide()
        applyBtn:Hide()
        discardBtn:Hide()
        hintText:Show()
    end
end

local function ApplyPending()
    local installed = GetInstalled()
    for key, desired in pairs(pending) do
        local entry = entriesByKey[key]
        if entry then
            for _, folder in ipairs(entry.folders) do
                if installed[folder] then
                    -- 不帶 character 參數 = 所有角色一起開關，跟 LegacyAddons 同一套邏輯
                    if desired then
                        C_AddOns.EnableAddOn(folder)
                    else
                        C_AddOns.DisableAddOn(folder)
                    end
                end
            end
        end
    end
    ReloadUI()
end

------------------------------------------------------------
-- 詳情面板
------------------------------------------------------------
local detailUI = {}

local function CreateDetail()
    detail = W.CreateFrame(nil, tab, 0, 0)
    detail:SetPoint("TOPLEFT", DETAIL_X, TOP_Y)
    detail:SetPoint("BOTTOMRIGHT", -16, BAR_H + 8)
    W.Stylize(detail, { 0.08, 0.08, 0.08, 0.9 })

    -- 擷圖區：佔位層永遠墊在底下，擷圖檔存在時整片蓋過去、
    -- 不存在時 SetTexture 靜默失敗、露出佔位層——不用偵測檔案在不在
    local shotHolder = CreateFrame("Frame", nil, detail, "BackdropTemplate")
    shotHolder:SetPoint("TOP", 0, -12)
    P.Size(shotHolder, SHOT_W, SHOT_H)
    W.Stylize(shotHolder, { 0.06, 0.06, 0.06, 1 })

    local phGrad = shotHolder:CreateTexture(nil, "BACKGROUND", nil, 1)
    phGrad:SetPoint("TOPLEFT", 1, -1)
    phGrad:SetPoint("BOTTOMRIGHT", -1, 1)
    phGrad:SetColorTexture(1, 1, 1, 1)
    local ar, ag, ab = W.Accent()
    phGrad:SetGradient("VERTICAL", CreateColor(ar, ag, ab, 0), CreateColor(ar, ag, ab, 0.10))

    local phIcon = shotHolder:CreateTexture(nil, "ARTWORK")
    P.Size(phIcon, 48, 48)
    phIcon:SetPoint("CENTER", 0, 12)
    phIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local phText = shotHolder:CreateFontString(nil, "ARTWORK")
    phText:SetFontObject(W.fontSmall)
    phText:SetPoint("TOP", phIcon, "BOTTOM", 0, -8)
    phText:SetText("|cff666666尚未提供預覽圖|r")

    local shot = shotHolder:CreateTexture(nil, "OVERLAY")
    shot:SetPoint("TOPLEFT", 1, -1)
    shot:SetPoint("BOTTOMRIGHT", -1, 1)

    -- 詳情大字（具名字型要帶 NAMESPACE 前綴）
    local detailFont = CreateFont(ns.WidgetsEnv.NAMESPACE .. "_FontDetail")
    detailFont:SetFont(MiliUI.Style.Font, 16, "")
    detailFont:SetTextColor(1, 1, 1)
    detailFont:SetShadowColor(0, 0, 0)
    detailFont:SetShadowOffset(1, -1)

    local name = detail:CreateFontString(nil, "OVERLAY")
    name:SetFontObject(detailFont)
    name:SetPoint("TOPLEFT", shotHolder, "BOTTOMLEFT", 2, -10)
    name:SetPoint("RIGHT", detail, "RIGHT", -12, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)

    local meta = detail:CreateFontString(nil, "OVERLAY")
    meta:SetFontObject(W.fontSmall)
    meta:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    meta:SetPoint("RIGHT", detail, "RIGHT", -12, 0)
    meta:SetJustifyH("LEFT")

    local desc = detail:CreateFontString(nil, "OVERLAY")
    desc:SetFontObject(W.fontNormal)
    desc:SetPoint("TOPLEFT", meta, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", detail, "RIGHT", -12, 0)
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    desc:SetSpacing(3)
    desc:SetMaxLines(4)

    local openBtn = W.CreateButton(detail, "開啟該插件設定", "accent", 150, 24)
    openBtn:SetPoint("BOTTOMLEFT", 12, 12)
    openBtn:Hide()

    local openHint = detail:CreateFontString(nil, "OVERLAY")
    openHint:SetFontObject(W.fontSmall)
    openHint:SetPoint("BOTTOMLEFT", 14, 16)
    openHint:Hide()

    -- CPU 數字定期重讀（只在詳情可見時跑）
    local acc = 0
    detail:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < CPU_TICK then return end
        acc = 0
        if detailUI.RefreshMeta then detailUI.RefreshMeta() end
    end)

    detailUI.shotHolder, detailUI.phIcon, detailUI.shot = shotHolder, phIcon, shot
    detailUI.name, detailUI.meta, detailUI.desc = name, meta, desc
    detailUI.openBtn, detailUI.openHint = openBtn, openHint
end

local function ShowDetail(entry)
    if not entry then return end

    detailUI.phIcon:SetTexture(EntryMeta(entry, "IconTexture")
        or "Interface\\Icons\\INV_Misc_QuestionMark")
    detailUI.shot:SetTexture(nil)
    detailUI.shot:SetTexture(SHOTS_PATH .. entry.key .. ".png")

    detailUI.name:SetText(EntryTitle(entry))

    function detailUI.RefreshMeta()
        local bits = {}
        local ver = EntryMeta(entry, "Version")
        if ver then bits[#bits + 1] = "版本 " .. ver end
        if #entry.folders > 1 then bits[#bits + 1] = ("%d 個資料夾"):format(#entry.folders) end

        local enabled = EntryEnabled(entry)
        local want = pending[entry.key]
        local state
        if want ~= nil then
            state = want and "|cffff9900待套用：啟用|r" or "|cffff9900待套用：停用|r"
        else
            state = enabled and "|cff33ff66已啟用|r" or "|cff808080已停用|r"
        end
        bits[#bits + 1] = state

        local cpu = enabled and EntryCPU(entry) or nil
        if cpu then bits[#bits + 1] = ("近期 CPU %.2f ms/幀"):format(cpu) end

        detailUI.meta:SetText("|cff999999" .. table.concat(bits, "  ・  ") .. "|r")
    end
    detailUI.RefreshMeta()

    local descText = entry.desc or EntryMeta(entry, "Notes") or "（這個插件沒有提供說明）"
    detailUI.desc:SetText(descText)

    local open = ResolveOpen(entry)
    if open then
        detailUI.openBtn:SetScript("OnClick", function()
            -- 別家的設定視窗多半在較低的 strata，先讓路
            if ns.Options.panel then ns.Options.panel:Hide() end
            open()
        end)
        detailUI.openBtn:Show()
        detailUI.openHint:Hide()
    else
        detailUI.openBtn:Hide()
        if entry.locked then
            detailUI.openHint:SetText("|cff666666設定就在這個視窗的其他分頁|r")
        elseif not EntryEnabled(entry) then
            detailUI.openHint:SetText("|cff666666插件已停用，啟用並重載後才能開啟它的設定|r")
        else
            detailUI.openHint:SetText("|cff666666這個插件沒有可直接開啟的設定入口|r")
        end
        detailUI.openHint:Show()
    end
end

------------------------------------------------------------
-- 清單
------------------------------------------------------------
local function RefreshRows()
    list:Update(items, list.updateRow)
end

local function SelectKey(key)
    selectedKey = key
    RefreshRows()
    ShowDetail(entriesByKey[key])
end

local function OnRowToggle(row, checked)
    local entry = row.entryKey and entriesByKey[row.entryKey]
    if not entry then return end
    if entry.locked then
        row.cb:SetChecked(true)
        return
    end
    if checked == EntryEnabled(entry) then
        pending[entry.key] = nil
    else
        pending[entry.key] = checked
    end
    UpdateApplyBar()
    RefreshRows()
    if selectedKey ~= entry.key then
        SelectKey(entry.key)
    elseif detailUI.RefreshMeta then
        detailUI.RefreshMeta()
    end
end

local function BuildRow(row)
    row:EnableMouse(true)

    -- hover／選中裝飾：左緣 3px 職業色直條＋整列淡染
    row.indicator = row:CreateTexture(nil, "ARTWORK")
    row.indicator:SetColorTexture(W.Accent(0.9))
    row.indicator:SetPoint("TOPLEFT", 0, 0)
    row.indicator:SetPoint("BOTTOMLEFT", 0, 0)
    row.indicator:SetWidth(P.Scale(3))
    row.indicator:Hide()

    row.sel = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    row.sel:SetAllPoints()
    row.sel:SetColorTexture(W.Accent(0.16))
    row.sel:Hide()

    row.hoverTex = row:CreateTexture(nil, "BACKGROUND", nil, 3)
    row.hoverTex:SetAllPoints()
    row.hoverTex:SetColorTexture(1, 1, 1, 0.05)
    row.hoverTex:Hide()

    -- 分組標題列的元素
    row.groupFS = W.CreateGroupLabel(row, "")
    row.groupFS:SetPoint("LEFT", 8, -2)
    row.groupLine = row:CreateTexture(nil, "ARTWORK")
    row.groupLine:SetColorTexture(W.Accent(0.35))
    row.groupLine:SetPoint("LEFT", row.groupFS, "RIGHT", 8, -1)
    row.groupLine:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.groupLine:SetHeight(P.Scale(1))

    -- 插件列的元素。⚠ 列會回收：onChange 一律讀 row.entryKey，不抓資料進 closure
    row.cb = W.CreateCheckButton(row, nil, function(checked)
        OnRowToggle(row, checked)
    end)
    row.cb:SetPoint("LEFT", 8, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    P.Size(row.icon, 16, 16)
    row.icon:SetPoint("LEFT", 28, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.nameFS = row:CreateFontString(nil, "OVERLAY")
    row.nameFS:SetFontObject(W.fontNormal)
    row.nameFS:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.nameFS:SetPoint("RIGHT", row, "RIGHT", -64, 0)
    row.nameFS:SetJustifyH("LEFT")
    row.nameFS:SetWordWrap(false)

    row.stateFS = row:CreateFontString(nil, "OVERLAY")
    row.stateFS:SetFontObject(W.fontSmall)
    row.stateFS:SetPoint("RIGHT", -6, 0)
    row.stateFS:SetJustifyH("RIGHT")

    row:SetScript("OnEnter", function(self)
        if not self.entryKey then return end
        self.hoverTex:Show()
        self.indicator:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.hoverTex:Hide()
        if self.entryKey ~= selectedKey then self.indicator:Hide() end
    end)
    row:SetScript("OnMouseDown", function(self)
        if self.entryKey then SelectKey(self.entryKey) end
    end)
end

-- ⚠ 列會回收：每一格都要重設，兩種列（分組標題／插件）互相蓋乾淨
local function UpdateRow(row, item)
    if item.kind == "group" then
        row.entryKey = nil
        row.stripe:Hide()
        row.sel:Hide()
        row.indicator:Hide()
        row.hoverTex:Hide()
        row.cb:Hide()
        row.icon:Hide()
        row.nameFS:SetText("")
        row.stateFS:SetText("")
        row.groupFS:SetText(item.label)
        row.groupFS:Show()
        row.groupLine:Show()
        return
    end

    local entry = item.entry
    row.entryKey = entry.key
    row.groupFS:SetText("")
    row.groupLine:Hide()

    local enabled = EntryEnabled(entry)
    local want = pending[entry.key]
    -- 不能寫 (want ~= nil) and want or enabled：want 是 false 時會 fall through 到 enabled
    local shown = enabled
    if want ~= nil then shown = want end

    row.cb:Show()
    row.cb:SetChecked(shown)
    row.cb:SetEnabled(not entry.locked)
    row.cb:SetAlpha(entry.locked and 0.45 or 1)

    row.icon:Show()
    row.icon:SetTexture(EntryMeta(entry, "IconTexture")
        or "Interface\\Icons\\INV_Misc_QuestionMark")
    row.icon:SetDesaturated(not shown)

    row.nameFS:SetText(EntryTitle(entry))
    row.nameFS:SetAlpha(shown and 1 or 0.45)

    if want ~= nil then
        row.stateFS:SetText("|cffff9900待套用|r")
    elseif not enabled then
        row.stateFS:SetText("|cff707070停用|r")
    else
        row.stateFS:SetText("")
    end

    local isSel = (entry.key == selectedKey)
    row.sel:SetShown(isSel)
    row.indicator:SetShown(isSel or row:IsMouseOver())
end

------------------------------------------------------------
-- 名冊 → 攤平清單。沒列名冊的已安裝插件自動歸進「工具與其他」。
------------------------------------------------------------
local function RebuildItems()
    wipe(items)
    local installed = GetInstalled()

    local covered = {}
    for _, e in ipairs(ns.AddonRoster.entries) do
        entriesByKey[e.key] = e
        for _, f in ipairs(e.folders) do covered[f] = true end
    end

    for _, g in ipairs(ns.AddonRoster.groups) do
        local rows = {}
        for _, e in ipairs(ns.AddonRoster.entries) do
            if e.group == g.key and installed[e.folders[1]] then
                rows[#rows + 1] = { kind = "entry", entry = e }
            end
        end
        if g.key == "misc" then
            local extras = {}
            for name in pairs(installed) do
                if not covered[name] then extras[#extras + 1] = name end
            end
            table.sort(extras)
            for _, name in ipairs(extras) do
                local e = autoByFolder[name]
                if not e then
                    e = { key = name, folders = { name }, group = "misc", auto = true }
                    autoByFolder[name] = e
                end
                entriesByKey[e.key] = e
                rows[#rows + 1] = { kind = "entry", entry = e }
            end
        end
        if #rows > 0 then
            items[#items + 1] = { kind = "group", label = g.label }
            for _, r in ipairs(rows) do items[#items + 1] = r end
        end
    end
end

------------------------------------------------------------
-- 分頁組裝
------------------------------------------------------------
local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()

    local title = W.CreateSectionTitle(tab, "插件總覽", ns.Options.PANEL_W - 32)
    title:SetPoint("TOPLEFT", 16, -14)

    list = W.CreateRowList(tab, LIST_W, 1, 24, BuildRow)
    list:SetPoint("TOPLEFT", LIST_X, TOP_Y)
    list:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", LIST_X, BAR_H + 8)
    list.updateRow = UpdateRow

    CreateDetail()

    -- 底部：預設是操作提示，有待套用變更時換成套用列
    hintText = tab:CreateFontString(nil, "OVERLAY")
    hintText:SetFontObject(W.fontSmall)
    hintText:SetPoint("BOTTOMLEFT", 18, 12)
    hintText:SetText("|cff888888勾選＝啟用插件。取消勾選後按「套用並重載」才會生效；"
        .. "點一列可在右側看介紹與開啟該插件的設定。|r")

    applyBtn = W.CreateButton(tab, "套用並重載介面", "green", 140, 24)
    applyBtn:SetPoint("BOTTOMRIGHT", -16, 8)
    applyBtn:SetScript("OnClick", ApplyPending)
    applyBtn:Hide()

    discardBtn = W.CreateButton(tab, "放棄變更", "normal", 90, 24)
    discardBtn:SetPoint("RIGHT", applyBtn, "LEFT", -8, 0)
    discardBtn:SetScript("OnClick", function()
        wipe(pending)
        UpdateApplyBar()
        RefreshRows()
        if detailUI.RefreshMeta then detailUI.RefreshMeta() end
    end)
    discardBtn:Hide()

    applyText = tab:CreateFontString(nil, "OVERLAY")
    applyText:SetFontObject(W.fontNormal)
    applyText:SetPoint("RIGHT", discardBtn, "LEFT", -12, 0)
    applyText:Hide()
end

ns.RegisterCallback("ShowOptionsTab", "addonsTab", function(id)
    if id ~= "addons" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RebuildItems()
    if not selectedKey or not entriesByKey[selectedKey] then
        for _, item in ipairs(items) do
            if item.kind == "entry" then
                selectedKey = item.entry.key
                break
            end
        end
    end
    RefreshRows()
    ShowDetail(entriesByKey[selectedKey])
    UpdateApplyBar()
    tab:Show()
end)
