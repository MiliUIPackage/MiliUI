------------------------------------------------------------
-- 「單位」分頁
--   左欄：單位清單
--   右上：元件切換列（框架 / 頭像 / 血條 / …）—— 一次只看一個元件的設定
--   右下：該元件的表單（Controls 引擎）
-- 這是 Platynator/Cell 的分層方式：先挑對象，再挑部位，才不會一整面牆的拉桿。
------------------------------------------------------------
local _, ns = ...

local W, Controls = ns.W, ns.Controls
local PosSize, Pos = Controls.PosSize, Controls.Pos

local UNIT_LIST = {
    { key = "player",       label = "玩家" },
    { key = "target",       label = "目標" },
    { key = "targettarget", label = "目標的目標" },
    { key = "focus",        label = "專注目標" },
    { key = "focustarget",  label = "專注的目標" },
    { key = "pet",          label = "寵物" },
    { key = "boss",         label = "首領" },
}

-- 元件切換列（依 DB 有沒有該元件決定要不要出現）
local ELEMENT_LIST = {
    { key = "frame",      label = "框架" },
    { key = "portrait",   label = "頭像" },
    { key = "hpbar",      label = "血條" },
    { key = "mpbar",      label = "能量條" },
    { key = "classpower", label = "職業資源" },
    { key = "manabar",    label = "魔力條" },
    { key = "castbar",    label = "施法條" },
    { key = "buffs",      label = "增益" },
    { key = "debuffs",    label = "減益" },
    { key = "icons",      label = "小圖示" },
    { key = "texts",      label = "文字" },
}

local tab, scroll
local currentUnit, currentElement = "player", "frame"
local elementChips = {}
local chipHighlight
local panels = {}          -- [unitKey .. "/" .. elementKey] = { frame, refreshers, height }

------------------------------------------------------------
-- 各元件的表單 spec
------------------------------------------------------------
local function FrameSpecs(unitKey)
    local list = {
        { type = "toggle", root = "unit", key = "enabled", label = "啟用此單位框",
          hint = "關閉後暴雪原生框不會自動回來，需 /reload" },
        { type = "header", label = "位置與大小" },
        { type = "text", label = "座標是框架中心相對畫面中心的偏移；也可以在編輯模式直接拖曳。" },
        { type = "numbers", root = "frame", label = "位置", fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } },
        { type = "numbers", root = "frame", label = "尺寸", fields = { { key = "w", label = "寬" }, { key = "h", label = "高" } } },
    }
    if unitKey == "boss" then
        tinsert(list, { type = "header", label = "多隻首領排列" })
        tinsert(list, { type = "dropdown", root = "frame", key = "growth", label = "排列方向",
                        items = { { text = "往下", value = "DOWN" }, { text = "往上", value = "UP" } } })
        tinsert(list, { type = "slider", root = "frame", key = "spacing", label = "間距", min = 20, max = 120 })
    end
    tinsert(list, { type = "header", label = "重置" })
    tinsert(list, { type = "button", label = "恢復預設", text = "此單位全部恢復預設", color = "red",
                    confirm = "把「" .. (ns.UNIT_LABELS[unitKey] or unitKey) .. "」的所有設定恢復成預設值？",
                    onClick = function()
                        ns.DB.ResetUnit(unitKey)
                        ns.ApplySettings(unitKey)
                    end })
    tinsert(list, { type = "text", label = "只重置這個單位（位置、各元件、文字）；其他單位與全域樣式不受影響。" })
    return list
end

local function BarSpecs(name, isHP)
    local list = {
        { type = "toggle", sub = name, key = "enabled", label = "顯示" },
        { type = "header", label = "位置與大小" },
        PosSize(name),
        { type = "header", label = "顏色" },
        { type = "dropdown", sub = name, key = "colorMethod", label = "前景", items = Controls.COLOR_METHOD_ITEMS },
        { type = "slider", sub = name, key = "barAlpha", label = "前景透明度", min = 0, max = 1, step = 0.05 },
        { type = "dropdown", sub = name, key = "bgColorMethod", label = "背景", items = Controls.COLOR_METHOD_ITEMS },
        { type = "slider", sub = name, key = "bgAlpha", label = "背景透明度", min = 0, max = 1, step = 0.05 },
        { type = "color", sub = name, key = "barColor", label = "自訂前景色", hasAlpha = false },
        { type = "color", sub = name, key = "bgColor", label = "自訂背景色", hasAlpha = false },
        { type = "text", label = "自訂色只在上方選「自訂色」時生效。" },
        { type = "header", label = "圖層" },
        { type = "slider", sub = name, key = "level", label = "前景圖層", min = 0, max = 15, step = 1 },
        { type = "slider", sub = name, key = "bgLevel", label = "背景圖層", min = 0, max = 15, step = 1 },
        { type = "text", label = "背景圖層低於頭像圖層、前景高於頭像 → 3D 頭像夾在血條中間，扣血區域模型完整露出。" },
        { type = "header", label = "邊框" },
        { type = "toggle", sub = name, key = "border", label = "顯示邊框" },
    }
    if isHP then
        tinsert(list, { type = "header", label = "扣血區" })
        tinsert(list, { type = "slider", sub = name, key = "lossAlpha", label = "扣血區暗化", min = 0, max = 1, step = 0.05 })
        tinsert(list, { type = "text", label = "在扣掉的血量區域蓋一層半透明黑；有 3D 頭像的框沒這層會看不出掉血分界。0 = 不暗化。" })
        tinsert(list, { type = "header", label = "疊加層" })
        tinsert(list, { type = "toggle", sub = name, key = "showHealPrediction", label = "治療預估" })
        tinsert(list, { type = "color", sub = name, key = "healPredictionColor", label = "預估顏色" })
        tinsert(list, { type = "toggle", sub = name, key = "healPredictionFollowBar", label = "預估跟隨血條色" })
        tinsert(list, { type = "slider", sub = name, key = "healPredictionAlpha", label = "跟隨時透明度", min = 0.1, max = 1, step = 0.05 })
        tinsert(list, { type = "toggle", sub = name, key = "showAbsorb", label = "吸收盾" })
        tinsert(list, { type = "color", sub = name, key = "absorbColor", label = "吸收盾顏色" })
        tinsert(list, { type = "toggle", sub = name, key = "showHealAbsorb", label = "治療吸收（實驗）" })
        tinsert(list, { type = "color", sub = name, key = "healAbsorbColor", label = "治療吸收顏色" })
        tinsert(list, { type = "text", label = "吸收盾（條紋）從血量前緣往後填、只對友方顯示。治療吸收（Necrotic 類 debuff）在 12.1 秘密值下無法確認歸零、預設關閉，除非你確定要才開。" })
    end
    return list
end

local function PortraitSpecs()
    return {
        { type = "toggle", sub = "portrait", key = "enabled", label = "顯示" },
        { type = "header", label = "位置與大小" },
        PosSize("portrait"),
        { type = "header", label = "樣式" },
        { type = "dropdown", sub = "portrait", key = "mode", label = "模式",
          items = { { text = "3D 模型", value = "3d" }, { text = "2D 圖像", value = "2d" } } },
        { type = "text", label = "12.1 副本裡的敵人／首領是受限身分，3D 模型拿不到——那時什麼都不畫（不會退回 2D）。玩家、隊友、開放世界的目標正常。" },
        { type = "color", sub = "portrait", key = "bg", label = "底色" },
        { type = "text", label = "底色透明度拉到 0 = 去背，3D 模型直接浮在畫面上（首領框預設就是這樣）。" },
        { type = "slider", sub = "portrait", key = "zoom", label = "3D 鏡頭", min = 0, max = 1, step = 0.05 },
        { type = "text", label = "1 = 臉部特寫，0 = 全身；0.6 左右露到肩膀。" },
        { type = "slider", sub = "portrait", key = "rotation", label = "3D 側身", min = -1.5, max = 1.5, step = 0.05 },
        { type = "slider", sub = "portrait", key = "level", label = "圖層", min = 0, max = 15, step = 1 },
        { type = "text", label = "圖層高過血條（4）就會浮在血條上方，做出「突出」效果。" },
    }
end

local function ClassPowerSpecs()
    return {
        { type = "toggle", sub = "classpower", key = "enabled", label = "顯示" },
        { type = "text", label = "聖能／連擊點／真氣／碎片／秘法充能／精華／符文，依職業自動決定格數。" },
        { type = "header", label = "位置與大小" },
        { type = "text", label = "Y 從框架底邊起算，負值往下。" },
        { type = "numbers", sub = "classpower", label = "位置", fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } },
        { type = "numbers", sub = "classpower", label = "尺寸", fields = { { key = "totalw", label = "總寬" }, { key = "h", label = "高" } } },
        { type = "slider", sub = "classpower", key = "spacing", label = "格間距", min = 0, max = 10 },
        { type = "header", label = "顏色" },
        { type = "color", sub = "classpower", key = "color", label = "亮格顏色", hasAlpha = false },
        { type = "text", label = "未設定時用各職業預設色。" },
    }
end

local function ManaBarSpecs()
    return {
        { type = "toggle", sub = "manabar", key = "enabled", label = "顯示" },
        { type = "text", label = "主資源不是法力時（貓／熊／元素／暗牧）才會出現的小魔力條。" },
        { type = "header", label = "位置與大小" },
        PosSize("manabar"),
        { type = "header", label = "顏色" },
        { type = "color", sub = "manabar", key = "color", label = "前景色" },
        { type = "slider", sub = "manabar", key = "bgAlpha", label = "背景透明度", min = 0, max = 1, step = 0.05 },
    }
end

local function TextStyleSpecs(sub, sub2, label)
    return {
        { type = "header", label = label },
        { type = "numbers", sub = sub, sub2 = sub2, label = "位置與大小",
          fields = { { key = "x", label = "X" }, { key = "y", label = "Y" }, { key = "w", label = "寬" }, { key = "h", label = "高" } } },
        { type = "slider", sub = sub, sub2 = sub2, key = "size", label = "字級", min = 6, max = 32 },
        { type = "dropdown", sub = sub, sub2 = sub2, key = "flags", label = "描邊", items = Controls.FLAGS_ITEMS },
        { type = "dropdown", sub = sub, sub2 = sub2, key = "justifyH", label = "水平對齊", items = Controls.JUSTIFY_H_ITEMS },
        { type = "color", sub = sub, sub2 = sub2, key = "color", label = "顏色" },
    }
end

local function CastbarSpecs()
    local list = {
        { type = "toggle", sub = "castbar", key = "enabled", label = "顯示" },
        { type = "header", label = "位置與大小" },
        PosSize("castbar"),
        { type = "header", label = "外觀" },
        { type = "color", sub = "castbar", key = "bg", label = "背景色" },
        { type = "toggle", sub = "castbar", key = "border", label = "顯示邊框" },
        { type = "text", label = "施法／引導／打斷／不可打斷的顏色在「一般」分頁統一設定。" },
        { type = "dropdown", sub = "castbar", key = "timeFormat", label = "時間格式", items = {
            { text = "剩餘／總長（0.3/1.5）", value = "remainTotal" },
            { text = "已唱／總長（1.2/1.5）", value = "elapsedTotal" },
            { text = "剩餘（0.3）",           value = "remain" },
            { text = "已唱（1.2）",           value = "elapsed" },
        } },
        { type = "text", label = "受限內容（副本／戰鬥）中敵方施法的秒數是秘密值，可能只有條在跑、沒有數字，這是 12.1 的限制。" },
        { type = "header", label = "圖示" },
        { type = "numbers", sub = "castbar", sub2 = "icon", label = "位置與大小",
          fields = { { key = "x", label = "X" }, { key = "y", label = "Y" }, { key = "w", label = "寬" }, { key = "h", label = "高" } } },
        { type = "toggle", sub = "castbar", key = "showShield", label = "不可打斷盾牌" },
        { type = "text", label = "施法不可打斷時在圖示前方顯示盾牌。受限內容裡「可不可打斷」是秘密值，盾牌由遊戲端依秘密布林直接控制顯示，插件不讀值。" },
        { type = "slider", sub = "castbar", key = "shieldScale", label = "盾牌大小（×圖示）", min = 0.5, max = 1.5, step = 0.05 },
        { type = "numbers", sub = "castbar", label = "盾牌偏移",
          fields = { { key = "shieldOffsetX", label = "X" }, { key = "shieldOffsetY", label = "Y" } } },
    }
    for _, s in ipairs(TextStyleSpecs("castbar", "spell", "法術名稱")) do tinsert(list, s) end
    for _, s in ipairs(TextStyleSpecs("castbar", "time", "時間")) do tinsert(list, s) end
    return list
end

local function AuraSpecs(name)
    return {
        { type = "toggle", sub = name, key = "enabled", label = "顯示" },
        { type = "header", label = "位置與排列" },
        Pos(name),
        { type = "numbers", sub = name, label = "圖示大小", fields = { { key = "w", label = "寬" }, { key = "h", label = "高" } } },
        { type = "dropdown", sub = name, key = "growth", label = "排列方向", items = Controls.GROWTH_ITEMS },
        { type = "slider", sub = name, key = "perRow", label = "每行數量", min = 1, max = 20 },
        { type = "slider", sub = name, key = "maxCount", label = "最大數量", min = 1, max = 40 },
        { type = "slider", sub = name, key = "spacing", label = "間距", min = 0, max = 10 },
        { type = "header", label = "過濾" },
        { type = "toggle", sub = name, key = "onlyMine", label = "只顯示自己施放的" },
        { type = "header", label = "文字" },
        { type = "toggle", sub = name, key = "showStack", label = "顯示層數" },
        { type = "slider", sub = name, key = "stackSize", label = "層數字級", min = 6, max = 20 },
        { type = "toggle", sub = name, key = "durationText", label = "顯示倒數" },
        { type = "slider", sub = name, key = "durationThreshold", label = "剩幾秒內顯示", min = 5, max = 600, step = 5 },
        { type = "text", label = "倒數由遊戲端繪製（12.1 插件讀不到剩餘秒數），改設定後會重建圖示。" },
    }
end

local function IconSpecs(els)
    local list = {}
    local defs = {
        { key = "raidtarget", label = "團隊標記" },
        { key = "status",     label = "狀態（戰鬥／休息）" },
        { key = "leader",     label = "隊長" },
        { key = "pvp",        label = "PvP" },
    }
    for _, d in ipairs(defs) do
        if els.icons[d.key] then
            tinsert(list, { type = "header", label = d.label })
            tinsert(list, { type = "toggle", sub = "icons", sub2 = d.key, key = "enabled", label = "顯示" })
            tinsert(list, PosSize("icons", nil, d.key))
        end
    end
    return list
end

local function TextsSpecs(els)
    local list = {
        { type = "text", label = "語法：[name] [level] [curhp] [maxhp] [perchp] [curmp] [maxmp] [percmp] [class] [race] [creaturetype] [classification]；" ..
                                 "條件上色 [gray_if_dead:死亡]、[class:name]、[difficulty:level]。" },
    }
    for i = 1, #els.texts do
        tinsert(list, { type = "header", label = "文字 " .. i })
        tinsert(list, { type = "toggle", sub = "texts", index = i, key = "enabled", label = "顯示" })
        tinsert(list, { type = "input", sub = "texts", index = i, key = "pattern", label = "內容" })
        tinsert(list, { type = "numbers", sub = "texts", index = i, label = "位置與大小",
                        fields = { { key = "x", label = "X" }, { key = "y", label = "Y" }, { key = "w", label = "寬" }, { key = "h", label = "高" } } })
        tinsert(list, { type = "slider", sub = "texts", index = i, key = "size", label = "字級", min = 6, max = 32 })
        tinsert(list, { type = "dropdown", sub = "texts", index = i, key = "flags", label = "描邊", items = Controls.FLAGS_ITEMS })
        tinsert(list, { type = "dropdown", sub = "texts", index = i, key = "justifyH", label = "水平對齊", items = Controls.JUSTIFY_H_ITEMS })
        tinsert(list, { type = "dropdown", sub = "texts", index = i, key = "justifyV", label = "垂直對齊", items = Controls.JUSTIFY_V_ITEMS })
        tinsert(list, { type = "color", sub = "texts", index = i, key = "color", label = "顏色" })
    end
    return list
end

local function SpecsFor(unitKey, elementKey)
    local udb = ns.GetUnitDB(unitKey)
    local els = udb.elements
    if elementKey == "frame" then return FrameSpecs(unitKey) end
    if elementKey == "portrait" then return PortraitSpecs() end
    if elementKey == "hpbar" then return BarSpecs("hpbar", true) end
    if elementKey == "mpbar" then return BarSpecs("mpbar", false) end
    if elementKey == "classpower" then return ClassPowerSpecs() end
    if elementKey == "manabar" then return ManaBarSpecs() end
    if elementKey == "castbar" then return CastbarSpecs() end
    if elementKey == "buffs" then return AuraSpecs("buffs") end
    if elementKey == "debuffs" then return AuraSpecs("debuffs") end
    if elementKey == "icons" then return IconSpecs(els) end
    if elementKey == "texts" then return TextsSpecs(els) end
    return {}
end

------------------------------------------------------------
-- 面板生成
------------------------------------------------------------
local function BuildPanel(unitKey, elementKey)
    local udb = ns.GetUnitDB(unitKey)
    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(520, 1)

    local ctx = {
        get = function(spec)
            local root = (spec.root == "unit" and udb)
                or (spec.root == "frame" and udb.frame)
                or udb.elements
            local t = Controls.Resolve(root, spec)
            return t and t[spec.key]
        end,
        set = function(spec, v)
            local root = (spec.root == "unit" and udb)
                or (spec.root == "frame" and udb.frame)
                or udb.elements
            local t = Controls.Resolve(root, spec)
            if t then t[spec.key] = v end
        end,
        apply = function() ns.ApplySettings(unitKey) end,
    }

    local height, refreshers = Controls.Build(content, SpecsFor(unitKey, elementKey), ctx, 4, -8, 520)
    content:SetHeight(height + 24)
    content:Hide()
    return { frame = content, refreshers = refreshers, height = height + 24 }
end

local function ShowPanel(unitKey, elementKey)
    for _, p in pairs(panels) do p.frame:Hide() end
    local id = unitKey .. "/" .. elementKey
    if not panels[id] then panels[id] = BuildPanel(unitKey, elementKey) end
    local p = panels[id]
    for _, fn in ipairs(p.refreshers) do fn() end
    p.frame:Show()
    scroll:SetContentHeight(p.height)
    scroll:SetVerticalScroll(0)
end

-- 元件切換列：依單位有的元件重排 chip
local function RefreshChips(unitKey)
    local els = ns.GetUnitDB(unitKey).elements
    local prev
    local firstVisible
    for _, chip in ipairs(elementChips) do
        -- DB 有這欄 且 這個職業真的有註冊該元件（職業資源條只對六個職業註冊，
        -- 薩滿看到卻調了沒反應會很困惑）
        local visible = chip.id == "frame"
            or (els[chip.id] ~= nil and ns.Elements[chip.id] ~= nil)
        chip:SetShown(visible)
        if visible then
            chip:ClearAllPoints()
            if prev then
                chip:SetPoint("LEFT", prev, "RIGHT", 3, 0)
            else
                chip:SetPoint("TOPLEFT", tab.chipRow, "TOPLEFT", 0, 0)
            end
            prev = chip
            firstVisible = firstVisible or chip
        end
    end
    -- 目前選的元件這個單位沒有 → 退回框架
    local ok = false
    for _, chip in ipairs(elementChips) do
        if chip.id == currentElement and chip:IsShown() then ok = true end
    end
    if not ok then currentElement = "frame" end
    for _, chip in ipairs(elementChips) do
        if chip.id == currentElement then chipHighlight(chip) end
    end
end

local function SelectUnit(unitKey)
    currentUnit = unitKey
    RefreshChips(unitKey)
    ShowPanel(unitKey, currentElement)
    ns.Preview.Highlight(unitKey)
end

local function SelectElement(elementKey)
    currentElement = elementKey
    ShowPanel(currentUnit, elementKey)
end

------------------------------------------------------------
-- 分頁本體
------------------------------------------------------------
local function Init()
    if tab then return end
    tab = CreateFrame("Frame", nil, ns.Options.panel)
    tab:SetAllPoints(ns.Options.panel)
    tab:Hide()

    -- 左欄單位清單
    local unitButtons = {}
    for i, info in ipairs(UNIT_LIST) do
        local b = W.CreateButton(tab, info.label, "accent-hover", 106, 24)
        b.id = info.key
        b:SetPoint("TOPLEFT", 12, -14 - (i - 1) * 28)
        unitButtons[i] = b
    end
    tab._unitHighlight = W.CreateButtonGroup(unitButtons, SelectUnit)
    tab._unitButtons = unitButtons

    -- 分隔線
    local sep = tab:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    sep:SetVertexColor(0, 0, 0, 1)
    sep:SetPoint("TOPLEFT", 128, -10)
    sep:SetPoint("BOTTOMLEFT", 128, 10)
    sep:SetWidth(ns.P.Scale(1))

    -- 右上：元件切換列
    local chipRow = CreateFrame("Frame", nil, tab)
    chipRow:SetPoint("TOPLEFT", 140, -14)
    chipRow:SetPoint("RIGHT", -12, 0)
    chipRow:SetHeight(22)
    tab.chipRow = chipRow
    for _, info in ipairs(ELEMENT_LIST) do
        local chip = W.CreateButton(chipRow, info.label, "accent-hover", 46, 20)
        chip.id = info.key
        -- 寬度依文字自適應（中文 2-4 字）
        chip:SetWidth(math.max(40, chip:GetFontString():GetStringWidth() + 16))
        tinsert(elementChips, chip)
    end
    chipHighlight = W.CreateButtonGroup(elementChips, SelectElement)

    -- 切換列下方一條淡線
    local chipLine = tab:CreateTexture(nil, "ARTWORK")
    chipLine:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    chipLine:SetVertexColor(1, 1, 1, 0.08)
    chipLine:SetPoint("TOPLEFT", chipRow, "BOTTOMLEFT", 0, -6)
    chipLine:SetPoint("TOPRIGHT", chipRow, "BOTTOMRIGHT", 0, -6)
    chipLine:SetHeight(ns.P.Scale(1))

    -- 右下：表單卷軸
    local scrollHolder = CreateFrame("Frame", nil, tab)
    scrollHolder:SetPoint("TOPLEFT", chipRow, "BOTTOMLEFT", 0, -12)
    scrollHolder:SetPoint("BOTTOMRIGHT", -8, 10)
    scroll = W.CreateScrollFrame(scrollHolder)
end

ns.RegisterCallback("ShowOptionsTab", "unitTab", function(id)
    if id ~= "units" then
        if tab then tab:Hide() end
        return
    end
    Init()
    tab:Show()
    for _, b in ipairs(tab._unitButtons) do
        if b.id == currentUnit then tab._unitHighlight(b) end
    end
    SelectUnit(currentUnit)
end)
