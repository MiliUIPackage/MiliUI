------------------------------------------------------------
-- 已收藏的格子變暗＋打勾
--
-- 為什麼是變暗而不是**整格移除**：移除等於要把商品索引重新映射一次
-- （第 7 格顯示的其實是第 12 件商品），而索引是所有商人 API 的參數 ——
-- 買、拿起、問價、問工具提示全部吃它。重映射一旦做了，同時在場的其他插件
-- 拿到的索引就全是假的，而且錯得靜悄悄。變暗沒有這個代價：格子還是第幾格，
-- 只是看起來已經有了。
--
-- 掛在 Grid 的掛勾**後面**（TOC 的載入順序決定的）：先讓它排好版、決定這一頁
-- 有幾格，我們再逐格上 alpha。
------------------------------------------------------------
local _, ns = ...

ns.Dim = {}
local Dim = ns.Dim

-- 0.4 是「一眼看得出來是灰的、但文字還讀得動」的位置。再低就看不清楚價格了 ——
-- 已收藏不等於不想買（坐騎的第二份可以賣、配方可以當材料）
local DIM_ALPHA = 0.4

------------------------------------------------------------
-- 標記器：變暗＋打勾的畫法只有這一份，商人格與拍賣場各拿一個實例
--
--   marker:Set(target, holder, region, collected)
--     target   要變暗的那一整塊（商人的一格、拍賣場的一列）
--     holder   打勾框的 parent（可以是 nil：只處理變暗）
--     region   打勾貼齊的對象，右下角對右下角（省略＝holder）
--   marker:HideAll()   全部還原（亮度回 1、勾收掉）
--
-- 打勾框與「變暗過誰」都記在**自己的弱鍵表**裡，key 是暴雪的框。
-- ⚠ 不可以寫成 `button.miliuiCheck = f` —— 暴雪的框上一個欄位都不能寫，
--   商人第 13 格以後雖然是我們建的，跑的卻是暴雪的處理器，一視同仁；
--   拍賣場的列更是池化重用的，欄位寫上去就跟著列漂到別的物品去。
--
-- 只還原**自己變暗過的**：沒碰過的框不去 SetAlpha(1)，免得蓋掉暴雪或別人
-- 自己設的亮度。
------------------------------------------------------------
local Marker = {}
Marker.__index = Marker

function Dim.NewMarker(size, offX, offY)
    return setmetatable({
        size   = size,
        offX   = offX or 2,
        offY   = offY or -2,
        checks = setmetatable({}, { __mode = "k" }),
        dimmed = setmetatable({}, { __mode = "k" }),
    }, Marker)
end

function Marker:GetCheck(holder, region)
    local existing = self.checks[holder]
    if existing then return existing end

    local f = CreateFrame("Frame", nil, holder)
    f:SetSize(self.size, self.size)
    f:SetPoint("BOTTOMRIGHT", region or holder, "BOTTOMRIGHT", self.offX, self.offY)
    f:SetFrameLevel(holder:GetFrameLevel() + 5)
    -- ⚠ 變暗的是整格（我們的祖先），打勾要維持全亮，不然它跟著一起淡掉，
    --   「已收藏」就只剩一個很難察覺的灰階差
    f:SetIgnoreParentAlpha(true)

    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetAllPoints()
    if C_Texture.GetAtlasInfo("common-icon-checkmark") then
        t:SetAtlas("common-icon-checkmark")
    else
        t:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    end

    f:Hide()
    self.checks[holder] = f
    return f
end

function Marker:Set(target, holder, region, collected)
    if collected then
        target:SetAlpha(DIM_ALPHA)
        self.dimmed[target] = true
        if holder then self:GetCheck(holder, region):Show() end
        return
    end

    if self.dimmed[target] then
        target:SetAlpha(1)
        self.dimmed[target] = nil
    end
    -- 還沒建過就別為了藏它而建一個
    local existing = holder and self.checks[holder]
    if existing then existing:Hide() end
end

function Marker:HideAll()
    for target in pairs(self.dimmed) do
        target:SetAlpha(1)
    end
    wipe(self.dimmed)
    for _, f in pairs(self.checks) do
        f:Hide()
    end
end

-- 商人格的標記器：勾 14px，貼商品圖示右下角
local CHECK_SIZE = 14
local merchant = Dim.NewMarker(CHECK_SIZE, 2, -2)

------------------------------------------------------------
-- 全部還原（買回分頁用）
------------------------------------------------------------
function Dim.HideAll()
    merchant:HideAll()
end

------------------------------------------------------------
-- 逐格判定
--
-- 索引公式跟暴雪自己的重畫迴圈一字不差：`(page - 1) * perPage + i`。
-- ⚠ `MerchantFrame.page` **只讀**。
------------------------------------------------------------
local function OnMerchantInfo()
    if not MerchantFrame:IsShown() then return end

    local db = ns.db
    if not db then return end

    local perPage  = ns.Grid.PerPage()
    local enabled  = db.dim.enabled
    local numItems = GetMerchantNumItems() or 0
    local page     = tonumber(MerchantFrame.page) or 1

    for i = 1, perPage do
        local cell = _G["MerchantItem" .. i]
        if cell then
            local collected
            if enabled then
                local index = (page - 1) * perPage + i
                if index <= numItems then
                    collected = ns.Collected.Is(index, GetMerchantItemID(index))
                end
            end

            -- 沒收藏、關掉了、或**資料還沒到**都走「不標」：先照原樣顯示，
            -- 資料到了再由 Collected 的重試把這一輪重跑一次
            local button = _G["MerchantItem" .. i .. "ItemButton"]
            merchant:Set(cell, button, button, collected)
        end
    end

    -- 這一頁以外的格子（縮小列欄數之後留下來的）也要還原
    for i = perPage + 1, ns.Grid.CreatedCells() do
        local cell = _G["MerchantItem" .. i]
        if cell then
            merchant:Set(cell, _G["MerchantItem" .. i .. "ItemButton"], nil, false)
        end
    end

    -- 這一輪有格子回 nil 的話掛上 GET_ITEM_INFO_RECEIVED，沒有的話拔掉
    ns.Collected.ArmRetry()
end

function Dim.Init()
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", OnMerchantInfo)
end
