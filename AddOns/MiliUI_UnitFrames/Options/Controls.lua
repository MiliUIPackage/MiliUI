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
-- 共通：sub / sub2 / index 決定 ctx 取值路徑；ctx = { get, set, apply }
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

ns.Controls = {}
local Controls = ns.Controls

-- 版面常數
local LABEL_W    = 128     -- 標籤欄寬（靠右對齊）
local GAP        = 12      -- 標籤與控件間距
local ROW_H      = 26      -- toggle / color / number
local ROW_H_TALL = 30      -- slider / dropdown / input / numbers
local HEADER_H   = 24
local HEADER_GAP = 10      -- 小節上方留白
local CONTROL_W  = 230     -- 滑桿 / 下拉 標準寬

function Controls.Resolve(tbl, spec)
    if spec.sub then tbl = tbl[spec.sub] end
    if spec.sub2 then tbl = tbl[spec.sub2] end
    if spec.index then tbl = tbl[spec.index] end
    return tbl
end

local function MakeLabel(parent, text, x, y, h)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontNormal)
    fs:SetPoint("TOPRIGHT", parent, "TOPLEFT", x + LABEL_W, y)
    fs:SetHeight(h)
    fs:SetJustifyH("RIGHT")
    fs:SetJustifyV("MIDDLE")
    fs:SetText(text or "")
    return fs
end

-- 建一整組；回傳 (總高度, refreshers)
function Controls.Build(parent, controls, ctx, startX, startY, width)
    local x0 = startX or 0
    local y = startY or 0
    width = width or 500
    local cx = x0 + LABEL_W + GAP          -- 控件起點
    local refreshers = {}

    for _, spec in ipairs(controls) do
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
                    ctx.apply()
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
                ctx.apply()
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
                local sub = { sub = spec.sub, sub2 = spec.sub2, index = spec.index, key = field.key }
                local tag = parent:CreateFontString(nil, "OVERLAY")
                tag:SetFontObject(W.fontSmall)
                tag:SetTextColor(0.6, 0.6, 0.6)
                tag:SetPoint("LEFT", parent, "TOPLEFT", px, y - ROW_H_TALL / 2)
                tag:SetText(field.label)
                px = px + tag:GetStringWidth() + 4
                local nb = W.CreateNumberBox(parent, 46, field.step or 1, function(v)
                    ctx.set(sub, v)
                    ctx.apply()
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
                        b.popup = W.CreateConfirmPopup(ns.Options.panel, 300, spec.confirm, function()
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
            tinsert(refreshers, function()
                eb:SetText(tostring(ctx.get(spec) or ""))
                eb:SetCursorPosition(0)
            end)
            y = y - ROW_H_TALL
        end
    end
    return -(y - startY), refreshers
end

------------------------------------------------------------
-- 常用選單項
------------------------------------------------------------
Controls.COLOR_METHOD_ITEMS = {
    { text = L["Class color"],        value = "class" },
    { text = L["Class color (dark)"],  value = "classdark" },
    { text = L["Reaction color"],        value = "reaction" },
    { text = L["Reaction color (dark)"],  value = "reactiondark" },
    { text = L["Class / reaction"],    value = "classreaction" },
    { text = L["Class / reaction (dark)"], value = "classreactiondark" },
    { text = L["Power color"],        value = "power" },
    { text = L["Power color (dark)"],  value = "powerdark" },
    { text = L["Health gradient"],      value = "hpthreshold" },
    { text = L["Health gradient (dark)"], value = "hpthresholddark" },
    { text = L["Green"],          value = "hpgreen" },
    { text = L["Green (dark)"],    value = "hpgreendark" },
    { text = L["Red"],          value = "hpred" },
    { text = L["Red (dark)"],    value = "hpreddark" },
    { text = L["Gray"],          value = "gray" },
    { text = L["Custom color"],        value = "solid" },
    { text = L["Hidden"],          value = "hide" },
}

Controls.GROWTH_ITEMS = {
    { text = L["Left to right, downward"], value = "LRTB" },
    { text = L["Left to right, upward"], value = "LRBT" },
    { text = L["Right to left, downward"], value = "RLTB" },
    { text = L["Right to left, upward"], value = "RLBT" },
    { text = L["Top to bottom, rightward"], value = "TBLR" },
    { text = L["Top to bottom, leftward"], value = "TBRL" },
    { text = L["Bottom to top, rightward"], value = "BTLR" },
    { text = L["Bottom to top, leftward"], value = "BTRL" },
}

Controls.JUSTIFY_H_ITEMS = {
    { text = L["Left"], value = "LEFT" }, { text = L["Center"], value = "CENTER" }, { text = L["Right"], value = "RIGHT" },
}
Controls.JUSTIFY_V_ITEMS = {
    { text = L["Top"], value = "TOP" }, { text = L["Center"], value = "MIDDLE" }, { text = L["Bottom"], value = "BOTTOM" },
}
Controls.FLAGS_ITEMS = {
    { text = L["None"], value = "" }, { text = L["Outline"], value = "OUTLINE" }, { text = L["Thick outline"], value = "THICKOUTLINE" },
}

-- 位置尺寸四件組（最常用，抽成工廠）
function Controls.PosSize(sub, index, sub2)
    return { type = "numbers", sub = sub, sub2 = sub2, index = index, label = L["Position and size"],
             fields = { { key = "x", label = "X" }, { key = "y", label = "Y" },
                        { key = "w", label = L["Width"] }, { key = "h", label = L["Height"] } } }
end
function Controls.Pos(sub, index, sub2)
    return { type = "numbers", sub = sub, sub2 = sub2, index = index, label = L["Position"],
             fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }
end
