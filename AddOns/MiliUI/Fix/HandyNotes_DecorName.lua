---------------------------------------------------------------
-- MiliUI Fix: HandyNotes 系列的房屋裝飾獎勵沒名字就崩潰
-- Author: Mili
--
-- 症狀：滑過某些寶箱標記時
--   HandyNotes_Midnight/core/rewards.lua:818:
--   attempt to concatenate field 'itemLink' (a nil value)
--   （例：虛空風暴「惡性寶箱」的 Decor({id = 15746}) 虛空精靈火炬）
--
-- 成因：rewards.lua 的 Decor 獎勵在「插件載入的那一刻」就抓名字
--     self.itemLink = C_HousingDecor.GetDecorName(self.id)
--   但 GetDecorName 是 MayReturnNothing —— 裝飾資料還沒到齊、或那個
--   decorID 在正式服無效時回 nil。GetText() 沒有守衛就把 itemLink
--   串進字串，tooltip 一畫就炸。而且名字只在建構時抓一次，之後資料
--   到齊也不會補，所以同一格標記整場遊戲都會炸。
--
-- 修法：換掉 Decor:GetText()，改成會重查、查不到也不會炸的版本：
--     1. 畫 tooltip 當下才查名字，查到才寫回快取（等於延後到資料到齊）
--     2. GetDecorName 沒有就退到 C_HousingCatalog 的目錄資料（順便有圖示）
--     3. 都沒有就顯示 UNKNOWN，不寫回快取，下次還會再試
--   Midnight / TheWarWithin / Dragonflight 三包共用同一份 rewards.lua，
--   透過上游自己註冊的 HandyNotes_ZarPlugins 一起修，不動插件檔案。
---------------------------------------------------------------

local DECOR_ENTRY_TYPE = (Enum and Enum.HousingCatalogEntryType and
                             Enum.HousingCatalogEntryType.Decor) or 1
local FALLBACK_ICON = 'Interface\\Icons\\Inv_misc_questionmark'

-- 對應 rewards.lua 開頭的 local function Icon()
local function Icon(icon) return '|T' .. icon .. ':0:0:1:-1|t ' end

local function IsFilled(text) return type(text) == 'string' and text ~= '' end

local function LookupDecor(id)
    if type(id) ~= 'number' then return end

    local name
    if C_HousingDecor and C_HousingDecor.GetDecorName then
        name = C_HousingDecor.GetDecorName(id)
    end

    local icon
    if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByRecordID then
        local info = C_HousingCatalog.GetCatalogEntryInfoByRecordID(
                         DECOR_ENTRY_TYPE, id)
        if info then
            if not IsFilled(name) then name = info.name end
            icon = info.iconTexture
        end
    end

    if not IsFilled(name) then name = nil end
    return name, icon
end

local function MakeGetText(ns)
    local Item = ns.reward and ns.reward.Item

    return function(self)
        -- 有 item 的裝飾走 Item 那條路，跟上游一樣
        if self.item and Item then return Item.GetText(self) end

        local name, icon = self.itemLink, self.itemIcon
        if not IsFilled(name) then
            local decorName, decorIcon = LookupDecor(self.id)
            if decorName then
                name = decorName
                self.itemLink = decorName
            end
            if not icon and decorIcon then
                icon = decorIcon
                self.itemIcon = decorIcon
            end
        end

        local text = name or UNKNOWN
        if self.type then text = text .. ' (' .. self.type .. ')' end
        return Icon(icon or FALLBACK_ICON) .. text
    end
end

local function PatchDecorRewards()
    -- 上游 core/dev.lua 無條件把每包的 ns 註冊進這張表
    local plugins = _G.HandyNotes_ZarPlugins
    if type(plugins) ~= 'table' then return end

    for _, ns in ipairs(plugins) do
        local Decor = ns and ns.reward and ns.reward.Decor
        if Decor and not rawget(Decor, 'MiliUI_DecorNameFix') then
            Decor.GetText = MakeGetText(ns)
            Decor.MiliUI_DecorNameFix = true
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    PatchDecorRewards()
end)
