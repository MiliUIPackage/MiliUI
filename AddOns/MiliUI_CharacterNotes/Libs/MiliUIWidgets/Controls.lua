------------------------------------------------------------
-- 表單引擎（Platynator 式的版面配置）
--
-- 每個控制項一列、全寬、固定高度；標籤靠右對齊在左欄、控件從中線起算。
-- 統一的垂直節奏是「精緻感」的來源——不要再用左右兩欄塞不同高度的東西。
--
-- spec.type：
--   header   { label }                                     小節標題（accent 小字）
--   toggle   { key, label }
--   slider   { key, label, min, max, step }
--   number   { key, label, step }                          單一微調數字框
--   numbers  { label, fields = { {key,label}, ... } }      一列多個微調框（位置/尺寸）
--   color    { key, label, hasAlpha }
--   dropdown { key, label, items }                         items 也可以是回傳清單的函式
--                                                          （見材質／字型：要等 LSM 註冊完）
--   input    { key, label }
--   text     { label }                                     說明文字（灰）
--   space    { h }                                         空行
--   custom   { label, build, h }                           宿主自畫的一列（見下方分支）
-- 共通：sub / sub2 / index 決定 ctx 取值路徑；ctx = { get, set, apply }
--
-- ⚠ 共用層：這支可以逐字複製到其他 MiliUI 插件，宿主專屬的東西一律走
--   ns.WidgetsEnv（見 Libs/MiliUIWidgets/Env.lua）。改這裡時不要引進新的 ns.* 依賴——
--   本插件專屬的選單清單與 spec 工廠放在 Options/Specs_UF.lua，不要寫回這裡。
------------------------------------------------------------
local _, ns = ...

local Env = ns.WidgetsEnv
local L = Env.L

local W = ns.W

ns.Controls = {}
local Controls = ns.Controls

-- 版面常數
-- 標籤欄寬：宿主可用 Env.LABEL_W 覆蓋（選用）。zhTW 的長標籤在 128 會塞不下，
-- 例如滑鼠提示插件的「隱藏『右鍵點擊顯示選單』提示行」，那邊用 200。
local LABEL_W    = ns.WidgetsEnv.LABEL_W or 128     -- 標籤欄寬（靠右對齊）
local GAP        = 12      -- 標籤與控件間距
local ROW_H      = 26      -- toggle / color / number
local ROW_H_TALL = 30      -- slider / dropdown / input / numbers
local HEADER_H   = 24
local HEADER_GAP = 10      -- 小節上方留白
local CONTROL_W  = 230     -- 滑桿 / 下拉 標準寬

------------------------------------------------------------
-- 連續型控件的 apply 合併
--
-- 滑桿拖曳與數字框滾輪會在**每一格**觸發 ctx.apply()，而 apply 通常是「整個單位
-- 重建」等級的工作。最貴的一條是光環：容器的簽章一變就得重建，而暴雪的 frame
-- 刪不掉（舊的只是被 Hide、永久留著）⇒ 把某個滑桿從 5 拖到 600 就是上百顆孤兒
-- 容器，面板當場卡住。
-- 值本身照舊立刻寫進 DB（ctx.set 不延後），只把「套用到畫面」合併成一次。
------------------------------------------------------------
local APPLY_DELAY = 0.05
local pendingCtx, applyScheduled

local function FlushApply()
    applyScheduled = false
    local ctx = pendingCtx
    pendingCtx = nil
    if ctx and ctx.apply then ctx.apply() end
end

-- 連續調整用；一次性的控件（toggle / dropdown / color）維持立刻套用
local function ApplySoon(ctx)
    pendingCtx = ctx
    if applyScheduled then return end
    applyScheduled = true
    C_Timer.After(APPLY_DELAY, FlushApply)
end

function Controls.Resolve(tbl, spec)
    if spec.sub then tbl = tbl[spec.sub] end
    if spec.sub2 then tbl = tbl[spec.sub2] end
    if spec.index then tbl = tbl[spec.index] end
    return tbl
end

-- ctx 工廠：多個分頁的 get/set 一字不差，差別只有「root 從哪來」與 apply 做什麼。
-- rootFor(spec) 回傳這條 spec 該讀寫的那張表。
-- ⚠ 不是每個分頁都適用 —— 有額外語意的（例如 spec.default 備援、自動建子表）
-- 就自己寫，不要為了共用而把那些語意塞進來。
function Controls.MakeCtx(rootFor, applyFn)
    return {
        get = function(spec)
            local t = Controls.Resolve(rootFor(spec), spec)
            return t and t[spec.key]
        end,
        set = function(spec, v)
            local t = Controls.Resolve(rootFor(spec), spec)
            if t then t[spec.key] = v end
        end,
        apply = applyFn,
    }
end

local function MakeLabel(parent, text, x, y, h)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontNormal)
    fs:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + LABEL_W, y)
    -- 左緣也要夾住：只錨右緣的話，比 LABEL_W 長的標籤會往左溢出、
    -- 被捲軸邊緣裁掉開頭（字的前面被吃掉）。夾住之後太長改成換行。
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetHeight(h)
    fs:SetJustifyH("RIGHT")
    fs:SetJustifyV("MIDDLE")
    fs:SetWordWrap(true)
    fs:SetText(text or "")
    return fs
end

-- 建一整組；回傳 (總高度, refreshers, rows)
--
-- rows 是給搜尋用的：每一列記下它在 content 裡的上下緣（`{ spec, top, bottom }`，
-- 都是負值，跟 SetPoint 的 y 同一套座標）。設定面板的搜尋要「跳過去並標示那一列」，
-- 而唯一知道每列落在哪的地方就是這支 —— 版面是它一列一列往下堆出來的。
-- 不記的話搜尋只能跳到分頁、跳不到那一行。
function Controls.Build(parent, controls, ctx, startX, startY, width)
    local x0 = startX or 0
    local y = startY or 0
    width = width or 500
    local cx = x0 + LABEL_W + GAP          -- 控件起點
    local refreshers = {}
    local rows = {}

    for _, spec in ipairs(controls) do
        local rowTop = y
        if spec.type == "header" then
            y = y - HEADER_GAP
            local fs = W.CreateGroupLabel(parent, spec.label)
            fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x0 + 6, y - 6)
            y = y - HEADER_H

        elseif spec.type == "space" then
            y = y - (spec.h or 8)

        elseif spec.type == "text" then
            local fs = parent:CreateFontString(nil, "OVERLAY")
            fs:SetFontObject(W.fontSmall)
            fs:SetPoint("TOPLEFT", parent, "TOPLEFT", cx, y - 4)
            fs:SetWidth(width - cx - 10)
            fs:SetJustifyH("LEFT")
            fs:SetText(spec.label)
            y = y - math.max(ROW_H, fs:GetStringHeight() + 10)

        elseif spec.type == "toggle" then
            MakeLabel(parent, spec.label, x0, y, ROW_H)
            local cb = W.CreateCheckButton(parent, spec.hint, function(checked)
                ctx.set(spec, checked)
                ctx.apply()
            end)
            cb:SetPoint("LEFT", parent, "TOPLEFT", cx, y - ROW_H / 2)
            tinsert(refreshers, function()
                cb:SetChecked(ctx.get(spec) and true or false)
            end)
            y = y - ROW_H

        elseif spec.type == "slider" then
            -- spec.scale：顯示值 = 實際值 × scale（例如模型偏移實際是 0~1，
            -- 顯示成 0~100 才好調）。min/max/step 都用「顯示單位」寫
            local scale = spec.scale or 1
            MakeLabel(parent, spec.label, x0, y, ROW_H_TALL)
            local s = W.CreateSlider(parent, spec.min or 0, spec.max or 100, CONTROL_W,
                spec.step or 1,
                nil,
                function(v)
                    ctx.set(spec, scale == 1 and v or (v / scale))
                    ApplySoon(ctx)
                end)
            s:SetPoint("LEFT", parent, "TOPLEFT", cx, y - ROW_H_TALL / 2)
            tinsert(refreshers, function()
                local raw = tonumber(ctx.get(spec))
                s:SetValue(raw and (raw * scale) or spec.min or 0)
            end)
            y = y - ROW_H_TALL

        elseif spec.type == "number" then
            MakeLabel(parent, spec.label, x0, y, ROW_H)
            local nb = W.CreateNumberBox(parent, 52, spec.step or 1, function(v)
                ctx.set(spec, v)
                ApplySoon(ctx)
            end)
            nb:SetPoint("LEFT", parent, "TOPLEFT", cx, y - ROW_H / 2)
            tinsert(refreshers, function()
                nb:SetValue(tonumber(ctx.get(spec)) or 0)
            end)
            y = y - ROW_H

        elseif spec.type == "numbers" then
            MakeLabel(parent, spec.label, x0, y, ROW_H_TALL)
            local px = cx
            for _, field in ipairs(spec.fields) do
                -- ⚠ root 一定要一起帶過去：ctx 靠它決定寫進 udb / udb.frame / udb.elements。
                -- 漏掉的話「位置」「尺寸」那兩條（唯二帶 root="frame" 的 spec）會 fall-through
                -- 到 elements ⇒ 四個數字框永遠顯示 0、改不動框，還在 elements 裡塞孤兒鍵。
                local sub = { root = spec.root, sub = spec.sub, sub2 = spec.sub2,
                              index = spec.index, key = field.key }
                local tag = parent:CreateFontString(nil, "OVERLAY")
                tag:SetFontObject(W.fontSmall)
                tag:SetTextColor(0.6, 0.6, 0.6)
                tag:SetPoint("LEFT", parent, "TOPLEFT", px, y - ROW_H_TALL / 2)
                tag:SetText(field.label)
                px = px + tag:GetStringWidth() + 4
                local nb = W.CreateNumberBox(parent, 46, field.step or 1, function(v)
                    ctx.set(sub, v)
                    ApplySoon(ctx)
                end)
                nb:SetPoint("LEFT", parent, "TOPLEFT", px, y - ROW_H_TALL / 2)
                px = px + 46 + 10
                tinsert(refreshers, function()
                    nb:SetValue(tonumber(ctx.get(sub)) or 0)
                end)
            end
            y = y - ROW_H_TALL

        elseif spec.type == "color" then
            MakeLabel(parent, spec.label, x0, y, ROW_H)
            local cp = W.CreateColorPicker(parent, nil, spec.hasAlpha ~= false,
                function(r, g, b, a)
                    local c = ctx.get(spec)
                    if type(c) ~= "table" then
                        c = {}
                        ctx.set(spec, c)
                    end
                    c.r, c.g, c.b, c.a = r, g, b, a
                    ctx.apply()
                end)
            cp:SetPoint("LEFT", parent, "TOPLEFT", cx, y - ROW_H / 2)
            tinsert(refreshers, function()
                cp:SetColor(ctx.get(spec))
            end)
            y = y - ROW_H

        elseif spec.type == "dropdown" then
            MakeLabel(parent, spec.label, x0, y, ROW_H_TALL)
            -- items 可以是函式：清單要到開分頁那一刻才算得準的（材質／字型要等
            -- LibSharedMedia 與其他插件註冊完）就傳函式，別在檔案層先算好
            local items = spec.items
            if type(items) == "function" then items = items() end
            local dd = W.CreateDropdown(parent, CONTROL_W, items, function(value)
                ctx.set(spec, value)
                ctx.apply()
            end)
            dd:SetPoint("LEFT", parent, "TOPLEFT", cx, y - ROW_H_TALL / 2)
            tinsert(refreshers, function()
                dd:SetSelectedValue(ctx.get(spec))
            end)
            y = y - ROW_H_TALL

        elseif spec.type == "button" then
            -- { label(左欄), text(按鈕字), color, confirm(有就先問), onClick }
            MakeLabel(parent, spec.label, x0, y, ROW_H_TALL)
            local b = W.CreateButton(parent, spec.text or L["Apply"], spec.color or "normal", spec.width or 140, 22)
            b:SetPoint("LEFT", parent, "TOPLEFT", cx, y - ROW_H_TALL / 2)
            b:SetScript("OnClick", function()
                if spec.confirm then
                    if not b.popup then
                        b.popup = W.CreateConfirmPopup(Env.PopupParent(), 300, spec.confirm, function()
                            spec.onClick()
                            for _, fn in ipairs(refreshers) do fn() end
                        end)
                    end
                    b.popup:Show()
                else
                    spec.onClick()
                    for _, fn in ipairs(refreshers) do fn() end
                end
            end)
            y = y - ROW_H_TALL

        elseif spec.type == "input" then
            MakeLabel(parent, spec.label, x0, y, ROW_H_TALL)
            local eb = W.CreateEditBox(parent, width - cx - 10, 20)
            eb:SetPoint("LEFT", parent, "TOPLEFT", cx, y - ROW_H_TALL / 2)
            eb:SetScript("OnEnterPressed", function(self)
                ctx.set(spec, self:GetText())
                ctx.apply()
                self:ClearFocus()
            end)
            -- 失焦＝提交（同數字框）。還原的話會變成「打完點別處就沒了」，
            -- 使用者的感受是這個欄位壞掉。
            -- ⚠ 用 HookScript：CreateEditBox 自己的 OnEditFocusLost 負責把邊框色復原，
            -- SetScript 會把它蓋掉、讓失焦後的邊框一直留在強調色。
            eb:HookScript("OnEditFocusLost", function(self)
                local cur = self:GetText()
                if cur ~= tostring(ctx.get(spec) or "") then
                    ctx.set(spec, cur)
                    ctx.apply()
                end
                self:SetCursorPosition(0)
            end)
            tinsert(refreshers, function()
                eb:SetText(tostring(ctx.get(spec) or ""))
                eb:SetCursorPosition(0)
            end)
            y = y - ROW_H_TALL

        elseif spec.type == "custom" then
            -- 宿主自畫的一列。共用層做不出來、又只有一個插件會用的控件
            -- （擷取按鍵、唯讀的複製框…）走這裡，不要為了它在共用層長出新型別。
            --   build(parent, x, y, width, ctx) → 高度, refresh(選用)
            -- x / y 是控件欄的左上角（跟其他型別同一套座標），width 是可用寬度；
            -- 回傳的 refresh 會併進 refreshers，跟其他列一起被叫。
            if spec.label then MakeLabel(parent, spec.label, x0, y, spec.h or ROW_H_TALL) end
            local h, refresh = spec.build(parent, cx, y, width - cx - 10, ctx)
            if refresh then tinsert(refreshers, refresh) end
            y = y - (h or spec.h or ROW_H_TALL)
        end
        -- space 沒有東西可以標示；header 留著（搜尋也讓人跳到小節）
        if spec.type ~= "space" then
            rows[#rows + 1] = { spec = spec, top = rowTop, bottom = y }
        end
    end
    return -(y - startY), refreshers, rows
end
