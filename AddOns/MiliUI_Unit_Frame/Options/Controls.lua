------------------------------------------------------------
-- 表單引擎（Platynator 版面 × Cell 美學）
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
--   dropdown { key, label, items }
--   input    { key, label }
--   text     { label }                                     說明文字（灰）
--   space    { h }                                         空行
-- 共通：sub / sub2 / index 決定 ctx 取值路徑；ctx = { get, set, apply }
------------------------------------------------------------
local _, ns = ...

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
            MakeLabel(parent, spec.label, x0, y, ROW_H_TALL)
            local s = W.CreateSlider(parent, spec.min or 0, spec.max or 100, CONTROL_W,
                spec.step or 1,
                nil,
                function(v)
                    ctx.set(spec, v)
                    ctx.apply()
                end)
            s:SetPoint("LEFT", parent, "TOPLEFT", cx, y - ROW_H_TALL / 2)
            tinsert(refreshers, function()
                s:SetValue(tonumber(ctx.get(spec)) or spec.min or 0)
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
            local dd = W.CreateDropdown(parent, CONTROL_W, spec.items, function(value)
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
            local b = W.CreateButton(parent, spec.text or "執行", spec.color or "normal", spec.width or 140, 22)
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
    { text = "職業色",        value = "class" },
    { text = "職業色（暗）",  value = "classdark" },
    { text = "陣營色",        value = "reaction" },
    { text = "陣營色（暗）",  value = "reactiondark" },
    { text = "職業／陣營",    value = "classreaction" },
    { text = "職業／陣營（暗）", value = "classreactiondark" },
    { text = "能量色",        value = "power" },
    { text = "能量色（暗）",  value = "powerdark" },
    { text = "血量漸層",      value = "hpthreshold" },
    { text = "血量漸層（暗）", value = "hpthresholddark" },
    { text = "綠色",          value = "hpgreen" },
    { text = "綠色（暗）",    value = "hpgreendark" },
    { text = "紅色",          value = "hpred" },
    { text = "紅色（暗）",    value = "hpreddark" },
    { text = "灰色",          value = "gray" },
    { text = "自訂色",        value = "solid" },
    { text = "隱藏",          value = "hide" },
}

Controls.GROWTH_ITEMS = {
    { text = "左→右，往下", value = "LRTB" },
    { text = "左→右，往上", value = "LRBT" },
    { text = "右→左，往下", value = "RLTB" },
    { text = "右→左，往上", value = "RLBT" },
    { text = "上→下，往右", value = "TBLR" },
    { text = "上→下，往左", value = "TBRL" },
    { text = "下→上，往右", value = "BTLR" },
    { text = "下→上，往左", value = "BTRL" },
}

Controls.JUSTIFY_H_ITEMS = {
    { text = "靠左", value = "LEFT" }, { text = "置中", value = "CENTER" }, { text = "靠右", value = "RIGHT" },
}
Controls.JUSTIFY_V_ITEMS = {
    { text = "靠上", value = "TOP" }, { text = "置中", value = "MIDDLE" }, { text = "靠下", value = "BOTTOM" },
}
Controls.FLAGS_ITEMS = {
    { text = "無", value = "" }, { text = "描邊", value = "OUTLINE" }, { text = "粗描邊", value = "THICKOUTLINE" },
}

-- 位置尺寸四件組（最常用，抽成工廠）
function Controls.PosSize(sub, index, sub2)
    return { type = "numbers", sub = sub, sub2 = sub2, index = index, label = "位置與尺寸",
             fields = { { key = "x", label = "X" }, { key = "y", label = "Y" },
                        { key = "w", label = "寬" }, { key = "h", label = "高" } } }
end
function Controls.Pos(sub, index, sub2)
    return { type = "numbers", sub = sub, sub2 = sub2, index = index, label = "位置",
             fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }
end
