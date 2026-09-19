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

local CHECK_SIZE = 14

-- 打勾貼圖的參照存在**自己的表**裡，用格子編號當 key。
-- ⚠ 不可以寫成 `cell.miliuiCheck = f` —— 暴雪的框上一個欄位都不能寫，
--   而我們自己建的第 13 格以後跑的是暴雪的處理器，一視同仁。
local checks = {}

------------------------------------------------------------
-- 打勾：自己的 overlay 框，貼在商品圖示的右下角
------------------------------------------------------------
local function GetCheck(i)
    local existing = checks[i]
    if existing then return existing end

    local button = _G["MerchantItem" .. i .. "ItemButton"]
    if not button then return nil end

    local f = CreateFrame("Frame", nil, button)
    f:SetSize(CHECK_SIZE, CHECK_SIZE)
    f:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    f:SetFrameLevel(button:GetFrameLevel() + 5)
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
    checks[i] = f
    return f
end

local function SetCheckShown(i, shown)
    if not shown then
        -- 還沒建過就別為了藏它而建一個
        local existing = checks[i]
        if existing then existing:Hide() end
        return
    end
    local f = GetCheck(i)
    if f then f:Show() end
end

------------------------------------------------------------
-- 全部還原（買回分頁用）
------------------------------------------------------------
function Dim.HideAll()
    for _, f in pairs(checks) do
        f:Hide()
    end
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

            if collected then
                cell:SetAlpha(DIM_ALPHA)
                SetCheckShown(i, true)
            else
                -- 沒收藏、關掉了、或**資料還沒到**都走這條：先照原樣顯示，
                -- 資料到了再由 Collected 的重試把這一輪重跑一次
                cell:SetAlpha(1)
                SetCheckShown(i, false)
            end
        end
    end

    -- 這一頁以外的格子（縮小列欄數之後留下來的）打勾也要收掉
    for i = perPage + 1, ns.Grid.CreatedCells() do
        SetCheckShown(i, false)
    end

    -- 這一輪有格子回 nil 的話掛上 GET_ITEM_INFO_RECEIVED，沒有的話拔掉
    ns.Collected.ArmRetry()
end

function Dim.Init()
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", OnMerchantInfo)
end
