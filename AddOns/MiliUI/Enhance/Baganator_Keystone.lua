--------------------------------------------------------------------------------
-- Baganator_Keystone
-- 在 Baganator 背包中強化鑰石顯示：
--   1. 右下角加入白色「鑰石」文字（類似「帳綁」「裝綁」）
--   2. 變更鑰石邊框顏色（亮青色，與其他物品區分）
--
-- 使用 hooksecurefunc 安全掛接，不修改 Baganator 原始碼。
--
-- 技術說明：
--   Baganator 的 Live 按鈕在 XML OnLoad 中使用 Mixin() 動態複製函式，
--   因此無法透過 hook mixin 表來影響已建立的按鈕。
--   正確做法是 hook mixin 的 MyOnLoad，在每個按鈕實例建立時
--   對該實例的 SetItemDetails 進行 post-hook。
--------------------------------------------------------------------------------

local DEBUG = false
local function Log(...)
    if DEBUG then print("|cff00ccff[MiliUI Keystone]|r", ...) end
end

-- 鑰石邊框顏色 (亮青色)
local KEYSTONE_BORDER_R = 0.0
local KEYSTONE_BORDER_G = 0.8
local KEYSTONE_BORDER_B = 1.0

-- 文字設定
local KEYSTONE_LABEL = "鑰石"
local KEYSTONE_FONT_SIZE = 12
local KEYSTONE_FONT_FLAGS = "OUTLINE"

--------------------------------------------------------------------------------
-- Helper: 判斷是否為鑰石物品
--------------------------------------------------------------------------------
local function IsKeystoneItem(itemLink)
    if not itemLink or type(itemLink) ~= "string" then return false end
    return itemLink:find("keystone:") ~= nil
end

--------------------------------------------------------------------------------
-- Helper: 建立或取得鑰石覆層元素
--------------------------------------------------------------------------------
local function GetOrCreateKeystoneOverlay(button)
    if button._miliKeystoneLabel then
        return button._miliKeystoneLabel
    end

    -- 文字標籤（右下角，與「帳綁」位置一致）
    local label = button:CreateFontString(nil, "OVERLAY", nil)
    label:SetFont(STANDARD_TEXT_FONT, KEYSTONE_FONT_SIZE, KEYSTONE_FONT_FLAGS)
    label:SetPoint("BOTTOMRIGHT", button.icon or button, "BOTTOMRIGHT", -2, 2)
    label:SetTextColor(1, 1, 1, 1)
    label:SetText(KEYSTONE_LABEL)
    label:Hide()

    button._miliKeystoneLabel = label
    Log("Created overlay for button:", button:GetName() or tostring(button))
    return label
end

--------------------------------------------------------------------------------
-- Core: 套用鑰石邊框顏色
--------------------------------------------------------------------------------
local function ApplyKeystoneBorder(button)
    if button.IconBorder then
        button.IconBorder:SetVertexColor(KEYSTONE_BORDER_R, KEYSTONE_BORDER_G, KEYSTONE_BORDER_B)
        button.IconBorder:Show()
    end
end

--------------------------------------------------------------------------------
-- Core: 鑰石裝飾更新（作為 SetItemDetails 的 post-hook）
--
-- 問題：Baganator 的 SetItemDetails 內部透過 GetInfo() 註冊了
-- 非同步的 finalCallback，會在物品資料載入完成後再次呼叫
-- SetItemButtonQuality()，覆蓋我們設定的邊框顏色。
--
-- 解決：在按鈕上標記 _miliIsKeystone 旗標，並額外 hook
-- SetItemButtonQuality，在每次品質更新後重新套用鑰石邊框。
--------------------------------------------------------------------------------
local function OnSetItemDetails(button, cacheData)
    local itemLink = cacheData and cacheData.itemLink
    local label = GetOrCreateKeystoneOverlay(button)

    if IsKeystoneItem(itemLink) then
        Log("Keystone detected:", itemLink)
        button._miliIsKeystone = true
        -- 顯示文字
        label:Show()
        -- 套用邊框顏色
        ApplyKeystoneBorder(button)
    else
        -- 非鑰石：清除旗標，隱藏文字（邊框由 Baganator 自行管理）
        button._miliIsKeystone = false
        label:Hide()
    end
end

--------------------------------------------------------------------------------
-- Hook 策略：
--
-- Live 按鈕 (BaganatorRetailLiveContainerItemButtonTemplate):
--   OnLoad 中 → Mixin(self, mixin) → self:MyOnLoad()
--   hook MyOnLoad 來在每個實例建立時 hook 該實例的 SetItemDetails
--
-- Cached 按鈕 (BaganatorRetailCachedItemButtonTemplate):
--   XML attribute mixin="..." → 在 CreateFrame 時自動混入
--   OnLoad 中 → self:OnLoad()
--   hook mixin 表的 SetItemDetails 即可（因為 mixin= 屬性在
--   XML 解析時就設定好了，後續不會重新 Mixin）
--   ⚠ 不對：mixin= 屬性也是複製函式引用，需要用同樣的策略
--   改為 hook OnLoad 來 hook 每個實例
--------------------------------------------------------------------------------

local hookedButtons = {} -- 防止重複 hook
local hookCount = 0

local function HookButtonInstance(button)
    if hookedButtons[button] then return end
    hookedButtons[button] = true
    hookCount = hookCount + 1

    hooksecurefunc(button, "SetItemDetails", OnSetItemDetails)

    -- Hook SetItemButtonQuality：Baganator 的非同步 finalCallback 會
    -- 再次呼叫此函式來重設邊框顏色，我們需要在之後重新套用鑰石邊框。
    hooksecurefunc(button, "SetItemButtonQuality", function(self)
        if self._miliIsKeystone then
            ApplyKeystoneBorder(self)
        end
    end)

    Log("Hooked instance #" .. hookCount, button:GetName() or "")
end

local function SetupHooks()
    local liveMixin = BaganatorRetailLiveContainerItemButtonMixin
    local cachedMixin = BaganatorRetailCachedItemButtonMixin

    if liveMixin and liveMixin.MyOnLoad then
        hooksecurefunc(liveMixin, "MyOnLoad", function(self)
            HookButtonInstance(self)
        end)
        Log("Hooked Live mixin MyOnLoad")
    else
        Log("|cffff0000FAILED: Live mixin not found|r")
    end

    if cachedMixin and cachedMixin.OnLoad then
        hooksecurefunc(cachedMixin, "OnLoad", function(self)
            HookButtonInstance(self)
        end)
        Log("Hooked Cached mixin OnLoad")
    else
        Log("|cffff0000FAILED: Cached mixin not found|r")
    end

    Log("Setup complete. Live mixin:", liveMixin and "OK" or "nil",
        "Cached mixin:", cachedMixin and "OK" or "nil")
end

--------------------------------------------------------------------------------
-- 載入時機：Baganator 在字母順序上比 MiliUI 先載入，
-- 所以 PLAYER_LOGIN 時 mixin 表已經存在。
-- 但按鈕尚未建立（要等玩家打開背包），所以 hook mixin 的
-- MyOnLoad/OnLoad 可以攔截所有未來建立的按鈕。
--------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event)
    self:UnregisterEvent("PLAYER_LOGIN")
    SetupHooks()
    Log("PLAYER_LOGIN: hooks installed")
end)

-- 如果 Baganator 已載入（例如從 /reload），立即設定
if C_AddOns.IsAddOnLoaded("Baganator") then
    SetupHooks()
    Log("Immediate: hooks installed (Baganator already loaded)")
end
