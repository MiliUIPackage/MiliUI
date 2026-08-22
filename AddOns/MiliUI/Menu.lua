------------------------------------------------------------
-- 米利UI選單：一張可以由外部插件掛項目的直式選單。
-- 目前的宿主是 ESC 選單上的「米利UI設定」按鈕（Enhance/GameMenu_MiliUIButton.lua），
-- 滑鼠移過去就往上展開。
--
-- ── 對外接口 ──────────────────────────────────────────────
-- 其他米利系列插件這樣掛一筆進來（放在自己的入口檔就好）：
--
--   MiliUI_MenuEntries = MiliUI_MenuEntries or {}
--   MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = {
--       key     = "unitframes",             -- 唯一鍵，同鍵重複註冊後者覆蓋前者
--       text    = L["MiliUI Unit Frames"],  -- 顯示文字，自己在地化
--       icon    = "Interface\\Icons\\...",  -- 選填，省略用套組圖示
--       order   = 10,                       -- 選填，小的排前面；同序再比文字
--       OnClick = function() ns.OpenOptions() end,
--   }
--
-- 走「往全域表裡塞」而不是「呼叫 MiliUI 的函式」是刻意的：註冊方與 MiliUI 之間
-- 沒有相依宣告，誰先載入不一定；而且玩家可能只裝單一插件、根本沒有 MiliUI。
-- 直接塞表兩種情況都不會炸，MiliUI.RegisterMenuEntry 只是同一件事的糖。
------------------------------------------------------------

local _, _ = ...

MiliUI = MiliUI or {}
MiliUI.Menu = MiliUI.Menu or {}
local M = MiliUI.Menu

local S = MiliUI.Style

-- 註冊表本身是全域的（見檔頭），MiliUI 沒載入時註冊方自己建。
MiliUI_MenuEntries = MiliUI_MenuEntries or {}

function MiliUI.RegisterMenuEntry(entry)
    if type(entry) ~= "table" then return end
    MiliUI_MenuEntries[#MiliUI_MenuEntries + 1] = entry
end

local ROW_H       = 24
local ICON_SIZE   = 16
local PAD         = 4          -- 選單內縮
local MIN_WIDTH   = 150
local HIDE_DELAY  = 0.25       -- 滑鼠離開後多久收起來
local DEFAULT_ICON = "Interface\\AddOns\\MiliUI\\icon"

-- 標籤開頭的 "MiliUI" 是雜訊：這張選單本身就叫米利UI了，
-- 每一列再掛一次只會把真正的名字往右推。
local function CleanLabel(text)
    return (text:gsub("^MiliUI%s*", ""):gsub("^米利UI%s*", ""))
end

------------------------------------------------------------
-- 讀註冊表 → 去重 → 排序
------------------------------------------------------------
function M.GetEntries()
    local list, seen = {}, {}
    for _, e in ipairs(MiliUI_MenuEntries) do
        if type(e) == "table" and type(e.text) == "string" and type(e.OnClick) == "function" then
            local key = e.key or e.text
            if seen[key] then
                list[seen[key]] = e     -- 插件重複註冊（例如 /reload 之外的重進）不長出第二列
            else
                list[#list + 1] = e
                seen[key] = #list
            end
        end
    end
    table.sort(list, function(a, b)
        local ao, bo = a.order or 100, b.order or 100
        if ao ~= bo then return ao < bo end
        return a.text < b.text
    end)
    return list
end

function M.HasEntries()
    return #M.GetEntries() > 0
end

------------------------------------------------------------
-- 選單本體
------------------------------------------------------------
local function Activate(menu, entry)
    menu:Hide()
    -- 宿主可以攔（戰鬥中不開、先關掉 ESC 選單…），回 false 就中止
    if menu.beforeClick and menu.beforeClick(entry) == false then return end
    local ok, err = pcall(entry.OnClick, entry)
    if not ok then
        print("|cff00ff00[MiliUI]|r 選單項目「" .. tostring(entry.text) .. "」執行失敗：" .. tostring(err))
    end
end

local function CreateRow(menu)
    local row = CreateFrame("Button", nil, menu, "BackdropTemplate")
    row:SetHeight(ROW_H)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    row:SetBackdropColor(0, 0, 0, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON_SIZE, ICON_SIZE)
    row.icon:SetPoint("LEFT", 5, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- 切掉暴雪圖示自帶的外框

    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetFont(S.Font, 13, "")
    row.text:SetShadowColor(0, 0, 0)
    row.text:SetShadowOffset(1, -1)
    row.text:SetTextColor(unpack(S.Dark.text))
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", -6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    row:SetScript("OnEnter", function(self) self:SetBackdropColor(S.Accent(0.4)) end)
    row:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0, 0, 0) end)
    row:SetScript("OnClick", function(self)
        if self.entry then Activate(menu, self.entry) end
    end)
    return row
end

-- parent      : 選單掛哪（父層一藏，選單跟著消失）
-- beforeClick : 選填，function(entry) → 回 false 中止
function M.Create(parent, beforeClick)
    local menu = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    menu:Hide()
    menu:EnableMouse(true)
    S.ApplyDarkPanel(menu)
    menu.rows = {}
    menu.count = 0
    menu.beforeClick = beforeClick

    function menu:Rebuild()
        local entries = M.GetEntries()
        local widest = 0
        for i, e in ipairs(entries) do
            local row = self.rows[i]
            if not row then
                row = CreateRow(self)
                self.rows[i] = row
            end
            row.entry = e
            row.icon:SetTexture(e.icon or DEFAULT_ICON)
            row.text:SetText(CleanLabel(e.text))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self, "TOPLEFT", PAD, -(PAD + (i - 1) * ROW_H))
            row:Show()
            -- 量實際字寬：標籤長度各插件自己決定，不撐開的話字會被右邊界切掉
            local w = row.text:GetStringWidth() or 0
            if w > widest then widest = w end
        end
        for i = #entries + 1, #self.rows do
            self.rows[i]:Hide()
            self.rows[i].entry = nil
        end
        self.count = #entries
        if self.count == 0 then return end

        -- 5(圖示左內縮) + 圖示 + 6(圖示到字) + 字 + 6(右留白) + 兩側 PAD
        local width = math.max(MIN_WIDTH, widest + 5 + ICON_SIZE + 6 + 6 + PAD * 2)
        self:SetSize(width, self.count * ROW_H + PAD * 2)
        for i = 1, self.count do
            self.rows[i]:SetWidth(width - PAD * 2)
        end
    end

    -- 貼齊 anchor 上緣往上開，中間不留縫——留了縫滑鼠滑過去的瞬間會判定成離開。
    function menu:OpenAt(anchor)
        self:Rebuild()
        if self.count == 0 then self:Hide(); return end
        self.anchor = anchor
        self.hideTimer = 0
        self:ClearAllPoints()
        local top = anchor:GetTop()
        local screenH = UIParent:GetHeight() or 1080
        if top and (top + self:GetHeight()) > screenH then
            self:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, 0)   -- 上面塞不下就翻下來
        else
            self:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 0)
        end
        self:Show()
    end

    -- 收起來的判定：滑鼠不在選單也不在 anchor 上，撐過 HIDE_DELAY 才收。
    -- 用 OnUpdate 而不是 anchor 的 OnLeave —— OnLeave 在滑鼠踏進選單的那一格
    -- 就會觸發，選單會在還沒摸到之前先消失。
    menu:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() or (self.anchor and self.anchor:IsMouseOver()) then
            self.hideTimer = 0
            return
        end
        self.hideTimer = (self.hideTimer or 0) + elapsed
        if self.hideTimer > HIDE_DELAY then self:Hide() end
    end)

    return menu
end
