------------------------------------------------------------
-- MiliUI: Stuf 光環圖示 ← AuraContainer 補救
--
-- Stuf 讀光環走 C_UnitAuras.GetBuffDataByIndex / GetDebuffDataByIndex，
-- 都是 index 存取 —— 12.1 起在 auras 為 secret 時一律 Lua error，所以它的
-- 增益／減益圖示會在戰鬥中凍結。
--
-- 補救方式跟 Cell_AuraContainer 相同：在 Stuf 的光環群組上掛一個
-- AuraContainer 接管顯示，Stuf 自己的群組淡出。共用邏輯在
-- AuraContainerCore.lua，這裡只負責把 Stuf 的設定翻譯成 core 要的形狀。
--
-- Stuf 的設定比 Cell 好取：群組 frame 上直接掛著 f.db，不用去翻版面表。
--   db.x / db.y            相對 unit frame 的 TOPLEFT 偏移
--   db.w / db.h            圖示大小
--   db.cols / db.rows      格數 = cols * rows，每行 = cols
--   db.spacing / db.vspacing
--   db.growth              "LRTB" 之類，用 Stuf.GrowthBreakdown 解析
--   db.curable             只顯示可驅散的
--   db.counttfont*         層數字型
--
-- /scab           診斷
-- /scab test      非戰鬥時強制顯示，用來確認錨點與大小
-- /scab reset     還原 Stuf 圖示並停用至下次 /reload
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

-- 增益外框：偏深的綠，太亮會在小圖示上蓋過圖示本身
local BUFF_BORDER_COLOR = { 0, 0.55, 0.15, 1 }

-- Stuf 的三個光環元素。tempenchant（武器附魔）沒有對應的 aura filter，
-- AuraContainer 得用 AddItemEnchantment 另外處理，這裡先不接管。
local DISPLAYS = {
    {
        element = "buffgroup",
        filter = "HELPFUL",
        style = {
            borderColor = BUFF_BORDER_COLOR,
            showDuration = true,
            showStack = true,
            durationFormat = "abbrev",   -- 頭像上的光環動輒數十分鐘，純秒數讀不了
        },
    },
    {
        element = "debuffgroup",
        filter = "HARMFUL",
        style = {
            dispelBorder = true,      -- 依驅散類型上色
            showDuration = true,
            showStack = true,
            durationFormat = "abbrev",   -- 頭像上的光環動輒數十分鐘，純秒數讀不了
        },
    },
}

local Core = MiliUI_AuraContainerCore
if not Core then return end

-- 關掉／還原 Stuf 自己的光環群組。Stuf:SuppressElement 會真的 Hide()，並讓
-- UpdateAura 與設定變更都跳過它；舊版 Stuf 沒有這個 API 時退回淡出，外觀一樣。
local function SuppressStufGroup(group, on)
    if not group then return end
    if type(Stuf.SuppressElement) == "function" then
        Stuf:SuppressElement(group, on)
    else
        group:SetAlpha(on and 0 or 1)
    end
end

------------------------------------------------------------
-- 讀 Stuf 的設定
------------------------------------------------------------

local attached = setmetatable({}, { __mode = "k" })  -- [stufFrame] = { [element] = container }
local diag = { skips = {} }

local function Skip(reason)
    diag.skips[reason] = (diag.skips[reason] or 0) + 1
end

-- Stuf.units 的值是 unit frame。原本用 .cache 當判斷，但那是 RefreshUnit 才
-- 填的欄位 —— 框架已經建好但還沒 refresh 過就會被整個濾掉，看起來像「一顆
-- 框架都沒有」。改成直接問它是不是 frame。
local function IsStufFrame(v)
    return type(v) == "table" and type(v.GetObjectType) == "function"
end

-- Stuf 的字型設定散在 db 的多個鍵上，攤平成 core 要的 fontSpec
local function ReadStackFont(db, iconWidth)
    return {
        media = db.counttfont,
        size = db.counttfontsize or db.fontsize
            or (iconWidth and iconWidth > 2 and math.floor(iconWidth * 0.6 + 0.5)) or nil,
        outline = db.counttfontflags ~= "None" and db.counttfontflags or nil,
        r = db.counttfontcolor and db.counttfontcolor.r,
        g = db.counttfontcolor and db.counttfontcolor.g,
        b = db.counttfontcolor and db.counttfontcolor.b,
    }
end

-- 把 Stuf 的 growth 字串翻成 flow layout 的方向。
-- GrowthBreakdown 回傳 d1..d4 與 hdir/vdir：d1 是主軸第一個方向，
-- hdir/vdir 是 1 或 -1（Stuf 自己拿來算偏移用的）。
local function ReadGrowth(db)
    local breakdown = Stuf and Stuf.GrowthBreakdown
    if not breakdown then return false, false, false end

    local d1, _, d3 = breakdown(db.growth)
    local horizontalFirst = (d1 == "LEFT" or d1 == "RIGHT")

    -- 主軸是水平還是垂直
    local vertical = not horizontalFirst
    -- 往左長還是往右長
    local growLeft = (horizontalFirst and d1 == "RIGHT") or (not horizontalFirst and d3 == "RIGHT")
    -- 往上長還是往下長
    local growUp = (horizontalFirst and d3 == "BOTTOM") or (not horizontalFirst and d1 == "BOTTOM")

    return vertical, growLeft, growUp
end

-- 回傳 layout，或 nil + 失敗原因（分開記，否則四種情況混成一句看不出是哪個）
local function ReadLayout(stufFrame, element)
    local group = stufFrame[element]
    if not group then return nil, "沒有這個元素" end
    if not group.db then return nil, "群組上沒有 db" end
    if group.hidden then return nil, "群組是隱藏的（Stuf 裡沒啟用？）" end

    local db = group.db
    local w, h = db.w, db.h
    if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then
        return nil, ("尺寸不合用 w=%s h=%s"):format(tostring(w), tostring(h))
    end

    local cols = db.cols or 1
    local rows = db.rows or 1
    local vertical, growLeft, growUp = ReadGrowth(db)

    return {
        group = group,
        db = db,
        x = db.x or 0,
        y = db.y or 0,
        sizeW = w,
        sizeH = h,
        max = cols * rows,
        perLine = vertical and rows or cols,
        spacing = db.spacing or 0,
        lineSpacing = db.vspacing or 0,
        vertical = vertical,
        growLeft = growLeft,
        growUp = growUp,
        -- Stuf 的「只顯示可驅散」對應 RAID filter，跟它自己 f.filter 的用法一致
        curable = db.curable and true or false,
    }
end

-- 設定簽章：容器建好之後外觀就烘死了（AuraButton 在 initializeFrame 之外
-- 是 forbidden），設定改了只能重建。但 frame 無法銷毀，所以只有簽章變了才重建。
local function BuildSignature(layout, display)
    local db = layout.db
    return table.concat({
        display.element,
        tostring(layout.x), tostring(layout.y),
        tostring(layout.sizeW), tostring(layout.sizeH),
        tostring(layout.max), tostring(layout.perLine),
        tostring(layout.spacing), tostring(layout.lineSpacing),
        tostring(db.growth), tostring(layout.curable),
        tostring(db.counttfont), tostring(db.counttfontsize), tostring(db.counttfontflags),
    }, "|")
end

------------------------------------------------------------
-- 掛載
------------------------------------------------------------

local function AttachOne(stufFrame, unit, display)
    local perFrame = attached[stufFrame]
    local existing = perFrame and perFrame[display.element]

    local layout, why = ReadLayout(stufFrame, display.element)
    if not layout then
        -- 使用者關掉了這個元素，或 Stuf 還沒建好它
        if existing then
            existing:Hide()
            SuppressStufGroup(existing.__stufGroup, false)
            perFrame[display.element] = nil
        end
        -- 「沒有這個元素」是預期情況：使用者本來就只在部分框架開光環。
        -- 記進跳過清單只會製造假警報，其他原因才值得看。
        if why ~= "沒有這個元素" then
            Skip(display.element .. "：" .. (why or "讀不到群組設定"))
        end
        return nil
    end

    local signature = BuildSignature(layout, display)
    if existing then
        if existing.__signature == signature then return existing end
        existing:Hide()
        perFrame[display.element] = nil
    end

    local style = {}
    for k, v in pairs(display.style) do style[k] = v end
    style.stackFont = ReadStackFont(layout.db, layout.sizeW)
    style.durationFont = style.stackFont

    -- 容器不能 parent 到 layout.group：等一下要把那個群組整個關掉（Hide），而
    -- 隱藏會往下傳給所有子物件 —— 容器會跟著一起不見。
    -- 改成掛在一個我們自己的中介 frame 上，跟被關掉的群組脫鉤。
    local holder = stufFrame.__miliuiAuraHost
    if not holder then
        holder = CreateFrame("Frame", nil, stufFrame)
        holder:SetAllPoints(stufFrame)
        stufFrame.__miliuiAuraHost = holder
    end
    -- 蓋過 Stuf 的光環群組，免得圖示被壓在底下
    holder:SetFrameLevel(math.max(holder:GetFrameLevel(), layout.group:GetFrameLevel() + 1))

    -- 容器會自動長大以容納圖示，所以「用哪個角釘住」決定它往哪邊長。
    -- Stuf 的群組是 2x2 的點，圖示靠位移擺出去；往上生長時內容在原點「之上」，
    -- 所以容器要用 BOTTOM 邊釘在同一個原點，才會往上長。
    -- 用 TOPLEFT 釘住的話容器只能往下長，跟往上生長的設定互相打架。
    local anchorPoint = (layout.growUp and "BOTTOM" or "TOP")
        .. (layout.growLeft and "RIGHT" or "LEFT")

    local ok, container = pcall(Core.CreateContainer, {
        host = holder,
        point = anchorPoint,
        -- 原點永遠是 Stuf 的 TOPLEFT + (x, y)，跟 Stuf 自己的 SetPoint 一致
        relativeTo = stufFrame,
        relativePoint = "TOPLEFT",
        x = layout.x,
        y = layout.y,
        unit = unit,
        filter = layout.curable and (display.filter .. "|RAID") or display.filter,
        groupKey = "MiliUIStuf" .. display.element,
        sizeW = layout.sizeW,
        sizeH = layout.sizeH,
        max = layout.max,
        perLine = layout.perLine,
        spacing = layout.spacing,
        lineSpacing = layout.lineSpacing,
        vertical = layout.vertical,
        growLeft = layout.growLeft,
        growUp = layout.growUp,
        style = style,
    })

    if not ok then
        Skip(display.element .. "：建立失敗")
        diag.err = container
        return nil
    end

    container.__signature = signature
    container.__stufGroup = layout.group

    if not perFrame then
        perFrame = {}
        attached[stufFrame] = perFrame
    end
    perFrame[display.element] = container
    return container
end

------------------------------------------------------------
-- 顯示切換
------------------------------------------------------------
-- Stuf 自己的群組交給 Stuf:SuppressElement 關掉。以前是 SetAlpha(0)，因為直接
-- Hide() 會跟 Stuf 自己的 Show/Hide 打架而閃爍；但淡出只是看不見，Stuf 照樣每次
-- UNIT_AURA 掃 32 buff + 40 debuff，畫好的圖示還各自掛著倒數用的 OnUpdate 在跑。
-- Stuf 本體現在認得 f.suppressed：UpdateAura 會跳過、改設定後也不會再把它叫回來，
-- 所以可以真的 Hide()（隱藏的 frame 子區域不跑 OnUpdate，那些倒數才停得下來）。

local function ApplyState(stufFrame, unit, containers, secret, forceUpdate)
    for _, container in pairs(containers) do
        if secret then
            if unit and unit ~= container.__unit then
                container:SetUnit(unit)
                container.__unit = unit
                forceUpdate = true
            end
            -- unit token 沒變但指向的對象換了（切目標／焦點）時，容器不會自己
            -- 重掃 —— Coolinator 也是靠這個 API 處理換目標的。
            if forceUpdate and container.UpdateAllAuras then
                pcall(container.UpdateAllAuras, container)
            end
            container:Show()
        else
            container:Hide()
        end

        SuppressStufGroup(container.__stufGroup, secret)
    end
end

local enabled = false
local forceOn = false
-- 一律接管，避免戰鬥內外兩套渲染樣式不一致（跟 Cell 那支同樣的理由）
local ALWAYS_ON = true

local function IsSecret()
    return ALWAYS_ON or forceOn or Core.AurasAreSecret()
end

-- 由事件設定：切目標／焦點時要叫容器重掃一次
local pendingForceUpdate = false

local function Refresh()
    if not enabled then return end
    local forceUpdate = pendingForceUpdate
    pendingForceUpdate = false
    wipe(diag.skips)
    diag.ranAt = GetTime()

    local secret = IsSecret()
    local units = Stuf and Stuf.units
    diag.total, diag.frames = 0, 0
    if not units then return end

    for unit, stufFrame in pairs(units) do
        diag.total = diag.total + 1
        if IsStufFrame(stufFrame) then diag.frames = diag.frames + 1 end
        if IsStufFrame(stufFrame) then
            for _, display in ipairs(DISPLAYS) do
                AttachOne(stufFrame, unit, display)
            end
            local containers = attached[stufFrame]
            if containers then
                ApplyState(stufFrame, unit, containers, secret, forceUpdate)
            end
        end
    end
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------

EventUtil.ContinueOnAddOnLoaded("Stuf", function()
    local driver = CreateFrame("Frame")
    driver:RegisterEvent("PLAYER_LOGIN")
    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    driver:RegisterEvent("GROUP_ROSTER_UPDATE")
    driver:RegisterEvent("PLAYER_TARGET_CHANGED")
    driver:RegisterEvent("PLAYER_FOCUS_CHANGED")

    local pending = false
    local function ScheduleRefresh()
        if pending then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            Refresh()
        end)
    end

    driver:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED"
            or event == "GROUP_ROSTER_UPDATE" then
            pendingForceUpdate = true
        end
        if event == "PLAYER_LOGIN" then
            Core.Detect()
            local failure = Core.Failure()
            if failure then
                print("|cffffe00a[MiliUI]|r Stuf 光環容器停用：" .. failure)
                return
            end
            enabled = true

            -- Stuf 改設定時會呼叫 UpdateElementLook，掛在它後面重掃。
            -- 簽章比對會自動決定要不要真的重建。
            if type(Stuf.UpdateElementLook) == "function" then
                hooksecurefunc(Stuf, "UpdateElementLook", function()
                    ScheduleRefresh()
                end)
            end

            -- Stuf 的 unit frame 是逐步建起來的，補幾次延遲掃描
            for _, delay in ipairs({ 1, 3, 10 }) do
                C_Timer.After(delay, ScheduleRefresh)
            end
        end
        ScheduleRefresh()
    end)

    ------------------------------------------------------------
    -- 診斷
    ------------------------------------------------------------

    local function Reset()
        enabled = false
        forceOn = false
        for _, containers in pairs(attached) do
            for _, container in pairs(containers) do
                container:Hide()
                SuppressStufGroup(container.__stufGroup, false)
            end
        end
        print("|cffffe00a[MiliUI]|r 已還原 Stuf 光環圖示，本模組停用至下次 /reload")
    end

    SLASH_MILIUISTUFAURACONTAINER1 = "/scab"
    SlashCmdList["MILIUISTUFAURACONTAINER"] = function(msg)
        local cmd = strtrim(msg or ""):lower()

        if cmd == "reset" then Reset() return end

        if cmd == "test" then
            forceOn = not forceOn
            Refresh()
            print("|cffffe00a[MiliUI]|r 強制顯示 " .. (forceOn and "開" or "關"))
            return
        end

        local function line(k, v) print("|cffffe00a[MiliUI]|r " .. k .. "：" .. tostring(v)) end
        line("build", Core.caps.build)
        line("已啟用", enabled)
        line("AuraContainer intrinsic", Core.caps.auraContainer)
        line("AddAuraGroup", Core.caps.addAuraGroup)
        line("全程接管（ALWAYS_ON）", ALWAYS_ON)

        local perElement = {}
        for _, containers in pairs(attached) do
            for element in pairs(containers) do
                perElement[element] = (perElement[element] or 0) + 1
            end
        end
        for _, display in ipairs(DISPLAYS) do
            line("已掛載容器（" .. display.element .. " / " .. display.filter .. "）",
                perElement[display.element] or 0)
        end

        local failure = Core.Failure()
        if failure then line("失敗原因", failure) end

        local anySkip = false
        for reason, count in pairs(diag.skips) do
            anySkip = true
            line("跳過", ("%s x%d"):format(reason, count))
        end
        if not anySkip then line("跳過", "無") end
        line("Stuf.units 項目數／其中是框架的", ("%s / %s"):format(
            tostring(diag.total or "?"), tostring(diag.frames or "?")))
        line("上次 Refresh", diag.ranAt and ("%.1f 秒前"):format(GetTime() - diag.ranAt) or "從未執行")
        if diag.err then line("最後錯誤", diag.err) end

        -- 每顆框架各有各的光環設定（例如 player 不顯示光環、target 才顯示），
        -- 所以要全部倒出來 —— 只看第一顆會得到誤導的結論。
        for unit, stufFrame in pairs(Stuf.units or {}) do
            if IsStufFrame(stufFrame) then
                local found = {}
                for key, value in pairs(stufFrame) do
                    if type(key) == "string" and type(value) == "table"
                        and (key:find("buff") or key:find("aura")
                             or key:find("Buff") or key:find("Aura")) then
                        tinsert(found, ("%s(db=%s hidden=%s)"):format(
                            key, tostring(value.db ~= nil), tostring(value.hidden)))
                    end
                end
                table.sort(found)
                line("框架（" .. tostring(unit) .. "）",
                    #found > 0 and table.concat(found, " ") or "無光環欄位")
            end
        end

        -- 兩個群組各取一筆版面樣本。排版不對時要看的就是這裡：
        -- 每行顆數、格數、growth 字串跟推出來的方向。
        local dumped = {}
        for unit, stufFrame in pairs(Stuf.units or {}) do
            if IsStufFrame(stufFrame) then
                for _, display in ipairs(DISPLAYS) do
                    if not dumped[display.element] then
                        local layout = ReadLayout(stufFrame, display.element)
                        if layout then
                            dumped[display.element] = true
                            line("版面（" .. display.element .. "）",
                                ("unit=%s (%d,%d) %dx%d cols=%s rows=%s 格數=%d 每行=%d 間距=%s/%s growth=%s → 垂直=%s 往左=%s 往上=%s flow錨點=%s"):format(
                                    tostring(unit), layout.x, layout.y, layout.sizeW, layout.sizeH,
                                    tostring(layout.db.cols), tostring(layout.db.rows),
                                    layout.max, layout.perLine,
                                    tostring(layout.spacing), tostring(layout.lineSpacing),
                                    tostring(layout.db.growth),
                                    tostring(layout.vertical), tostring(layout.growLeft),
                                    tostring(layout.growUp),
                                    (layout.growUp and "BOTTOM" or "TOP")
                                        .. (layout.growLeft and "RIGHT" or "LEFT")))
                        end
                    end
                end
            end
        end
    end
end)
