------------------------------------------------------------
-- 視窗內的右鍵／標題鈕選單（全部視窗共用一份）
--
-- 為什麼不用 MiliUIWidgets 的 CreateDropdown：那是設定表單裡的控件，長寬與配色
-- 跟著設定視窗走。這個選單長在遊戲畫面上、貼著統計視窗開，外觀應該跟著**統計視窗
-- 自己的字型與字級**，不是設定面板的。
--
-- 最多兩層（主選單 ＋ 一層子選單），跟 EUI 一樣。三層以上的選單在遊戲裡沒人點得動。
------------------------------------------------------------
local _, ns = ...

ns.Menu = {}
local Menu = ns.Menu
local M = ns.Media

local ITEM_H = 22
local TITLE_H = 20
local SEP_H  = 7
local MIN_W  = 110
local PAD_X  = 10
local FONT_SZ = 12

------------------------------------------------------------
-- 子選單的關閉延遲
--
-- 從「統計類型」斜著移到它右邊的子選單，路徑一定會經過主選單的其他列
-- （分段、鎖定視窗…）。那些列的 OnEnter 若是**立刻**把子選單關掉，
-- 使用者的體感就是「滑鼠稍微移過去就關了」，根本點不到。
--
-- 對策是經典的做法：非子選單列只**排程**關閉，給一段寬限期；期間內
-- 游標進到子選單（或回到帶子選單的列）就取消。世代 token 讓舊的排程自己作廢。
------------------------------------------------------------
local SUB_CLOSE_DELAY = 0.4
local _subGen = 0

local _main, _sub, _catcher
local _anchorBtn      -- 哪顆按鈕開的（同一顆再按一次＝關閉）
local _anchorPoints   -- 上次解出來的錨點，供 keepAnchor 重畫時原地重貼

-- 選單跟著統計視窗自己的字型走（不是設定面板的）
local function StyleFont(fs)
    local s = ns.DB.Style()
    fs:SetFont(M.Font(s and s.font), FONT_SZ, "")
end

local function MakePanel()
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetBackdrop({
        bgFile = M.WHITE8X8,
        edgeFile = M.WHITE8X8,
        edgeSize = 1,
    })
    f:SetBackdropColor(0.06, 0.06, 0.06, 0.96)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f.rows = {}
    f:Hide()
    return f
end

local function EnsureRow(panel, idx)
    local row = panel.rows[idx]
    if row then return row end

    row = CreateFrame("Button", nil, panel)
    row:SetHeight(ITEM_H)
    row:SetPoint("LEFT", panel, "LEFT", 1, 0)
    row:SetPoint("RIGHT", panel, "RIGHT", -1, 0)

    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(M.Accent())
    row.hl:SetAlpha(0.25)
    row.hl:Hide()

    row.text = row:CreateFontString(nil, "OVERLAY")
    StyleFont(row.text)
    row.text:SetPoint("LEFT", row, "LEFT", PAD_X, 0)
    row.text:SetJustifyH("LEFT")

    -- 有子選單的箭頭：用字元不用圖檔
    row.arrow = row:CreateFontString(nil, "OVERLAY")
    StyleFont(row.arrow)
    row.arrow:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.arrow:SetText("|cff888888>|r")
    row.arrow:Hide()

    -- 目前選中的項目左邊點一個小方塊（比打勾號在小字級下清楚）
    row.dot = row:CreateTexture(nil, "OVERLAY")
    row.dot:SetSize(3, 3)
    row.dot:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.dot:Hide()

    row:SetScript("OnEnter", function(self)
        if self.enabled == false then return end
        self.hl:Show()
        if self.submenu then
            _subGen = _subGen + 1            -- 取消還在排隊的關閉
            Menu.ShowSub(self.submenu, self)
        elseif _sub and _sub:IsShown() then
            Menu.ScheduleSubClose()
        end
    end)
    row:SetScript("OnLeave", function(self) self.hl:Hide() end)

    panel.rows[idx] = row
    return row
end

-- 回傳版面高度；items 是 { text, onClick, isActive, isTitle, isSeparator, submenu } 的陣列
local function Layout(panel, items, onDismiss)
    local width = MIN_W
    local y = -1
    local shown = 0

    for i, item in ipairs(items) do
        local row = EnsureRow(panel, i)
        shown = i
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, y)
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, y)
        row.submenu = item.submenu
        row.enabled = not (item.isTitle or item.isSeparator)

        if item.isSeparator then
            row:SetHeight(SEP_H)
            row.text:SetText("")
            row.arrow:Hide()
            row.dot:Hide()
            row:EnableMouse(false)
            if not row.sepTex then
                row.sepTex = row:CreateTexture(nil, "ARTWORK")
                row.sepTex:SetHeight(1)
                row.sepTex:SetPoint("LEFT", row, "LEFT", 6, 0)
                row.sepTex:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                row.sepTex:SetColorTexture(1, 1, 1, 0.12)
            end
            row.sepTex:Show()
            y = y - SEP_H
        else
            if row.sepTex then row.sepTex:Hide() end
            local h = item.isTitle and TITLE_H or ITEM_H
            row:SetHeight(h)
            StyleFont(row.text)
            row:EnableMouse(true)

            if item.isTitle then
                row.text:SetText(item.text or "")
                row.text:SetTextColor(M.Accent())
                row.arrow:Hide()
                row.dot:Hide()
                row:SetScript("OnClick", nil)
                row:EnableMouse(false)
            else
                row.text:SetText(item.text or "")
                if item.isActive then
                    row.text:SetTextColor(M.Accent())
                    row.dot:SetColorTexture(M.Accent())
                    row.dot:Show()
                else
                    row.text:SetTextColor(0.85, 0.85, 0.85)
                    row.dot:Hide()
                end
                row.arrow:SetShown(item.submenu ~= nil)
                local fn = item.onClick
                local keepOpen = item.keepOpen
                row:SetScript("OnClick", function()
                    if item.submenu then return end
                    if fn then fn() end
                    if not keepOpen and onDismiss then onDismiss() end
                end)
            end
            y = y - h
        end

        local w = row.text:GetStringWidth() + PAD_X * 2 + (item.submenu and 14 or 0)
        if w > width then width = w end
    end

    -- 多餘的列藏起來（池化：不銷毀）
    for i = shown + 1, #panel.rows do panel.rows[i]:Hide() end
    for i = 1, shown do panel.rows[i]:Show() end

    panel:SetSize(math.ceil(width), math.ceil(-y) + 1)
    return width
end

local function EnsureCatcher()
    if _catcher then return _catcher end
    -- 點選單外面關掉。用一個全螢幕的透明按鈕，不是 OnUpdate 追滑鼠。
    _catcher = CreateFrame("Button", nil, UIParent)
    _catcher:SetAllPoints(UIParent)
    _catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    _catcher:RegisterForClicks("AnyUp")
    _catcher:SetScript("OnClick", function() Menu.Hide() end)
    _catcher:Hide()
    return _catcher
end

function Menu.Hide()
    if _sub then _sub:Hide() end
    if _main then _main:Hide() end
    if _catcher then _catcher:Hide() end
    _anchorBtn = nil
end

function Menu.IsOpenFor(btn)
    return _main and _main:IsShown() and _anchorBtn == btn
end

-- 排程關閉子選單。時間到才判斷游標在不在子選單裡 —— 判斷點放在「到期時」
-- 而不是「排程時」，游標中途繞進子選單也算數。
function Menu.ScheduleSubClose()
    _subGen = _subGen + 1
    local gen = _subGen
    C_Timer.After(SUB_CLOSE_DELAY, function()
        if gen ~= _subGen then return end             -- 已被新的動作取代
        if not _sub or not _sub:IsShown() then return end
        if _sub:IsMouseOver() then return end         -- 人已經在裡面了
        _sub:Hide()
    end)
end

function Menu.ShowSub(items, parentRow)
    if not _sub then
        _sub = MakePanel()
        _sub:SetFrameLevel(_main and (_main:GetFrameLevel() + 10) or 20)
    end
    Layout(_sub, items, Menu.Hide)
    _sub:ClearAllPoints()
    -- x 偏移 0 而不是 1：留一格空隙的話，游標橫著移過去會先掉進「兩個選單之間」
    -- 那一列縫裡。子選單直接壓在主選單的邊框上，路徑才是連續的。
    _sub:SetPoint("TOPLEFT", parentRow, "TOPRIGHT", 0, 2)
    _sub:Show()
    -- 超出右邊界就翻到左邊
    local right = _sub:GetRight()
    if right and right > UIParent:GetRight() then
        _sub:ClearAllPoints()
        _sub:SetPoint("TOPRIGHT", parentRow, "TOPLEFT", 0, 2)
    end
end

-- anchorBtn 給了就貼著它開，並且「同一顆再按一次＝關閉」。
--
-- keepAnchor：選單裡的開關項目按下去之後要**原地重畫**（更新勾選狀態）。
-- 沒有這個參數的話那條路會撞上上面的「同一顆再按一次＝關閉」而直接關掉選單，
-- 而且用游標錨定（沒有 anchorBtn）的選單會跳到新的游標位置。
function Menu.Show(items, anchorBtn, keepAnchor)
    if not keepAnchor and anchorBtn and Menu.IsOpenFor(anchorBtn) then
        Menu.Hide()
        return
    end
    if not _main then
        _main = MakePanel()
        _main:SetFrameLevel(EnsureCatcher():GetFrameLevel() + 5)
    end
    EnsureCatcher():Show()
    if _sub then _sub:Hide() end

    Layout(_main, items, Menu.Hide)
    _main:ClearAllPoints()

    if keepAnchor and _anchorPoints then
        _main:SetPoint(unpack(_anchorPoints))
        _main:Show()
        _anchorBtn = anchorBtn
        return
    end

    if anchorBtn then
        _anchorPoints = { "TOPRIGHT", anchorBtn, "BOTTOMRIGHT", 0, -2 }
    else
        local scale = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        _anchorPoints = { "TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale }
    end
    _main:SetPoint(unpack(_anchorPoints))
    _main:Show()

    -- 貼齊螢幕：往下開會超出下緣就改成往上開
    local bottom = _main:GetBottom()
    if bottom and bottom < 0 and anchorBtn then
        _anchorPoints = { "BOTTOMRIGHT", anchorBtn, "TOPRIGHT", 0, 2 }
        _main:ClearAllPoints()
        _main:SetPoint(unpack(_anchorPoints))
    end
    local left = _main:GetLeft()
    if left and left < 0 then
        _anchorPoints = { "BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2, 2 }
        _main:ClearAllPoints()
        _main:SetPoint(unpack(_anchorPoints))
    end
    _anchorBtn = anchorBtn
end
