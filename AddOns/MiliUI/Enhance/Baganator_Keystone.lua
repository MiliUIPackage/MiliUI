--------------------------------------------------------------------------------
-- Baganator_Keystone
-- 在 Baganator 背包中強化鑰石顯示：
--   1. 右下角加入白色「鑰石」文字（類似「帳綁」「裝綁」）
--   2. 變更鑰石邊框顏色（亮粉紅色，與其他物品區分）
--
-- 使用 hooksecurefunc 安全掛接，不修改 Baganator 原始碼。
--
-- 技術說明：
--   1. Baganator 的 Live 按鈕在 XML OnLoad 中使用 Mixin() 動態複製函式，
--      因此無法透過 hook mixin 表來影響已建立的按鈕。
--      正確做法是 hook mixin 的 MyOnLoad，在每個按鈕實例建立時
--      對該實例的 SetItemDetails 進行 post-hook。
--
--   2. Baganator 的皮膚（Dark / ElvUI / NDui）會在 layout 階段對
--      SetItemButtonQuality 安裝自己的 hook，比我們的 hook 更晚註冊，
--      所以會在 hooksecurefunc 鏈中覆蓋我們設定的邊框顏色。
--      因此我們不能只 hook SetItemButtonQuality，必須直接 hook
--      IconBorder texture 本身的 SetVertexColor / Hide / SetTexture，
--      作為邊框變更的最終攔截點。
--------------------------------------------------------------------------------

local DEBUG = false
local function Log(...)
    if DEBUG then print("|cff00ccff[MiliUI Keystone]|r", ...) end
end

-- 鑰石邊框顏色 (亮粉紅色 hot pink — WoW 物品品質沒有粉紅色，最容易辨識)
local KEYSTONE_BORDER_R = 1.0
local KEYSTONE_BORDER_G = 0.1
local KEYSTONE_BORDER_B = 0.8
local KEYSTONE_BORDER_A = 1.0

-- 光暈設定
local KEYSTONE_GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local KEYSTONE_GLOW_SIZE_PADDING = 14   -- 光暈比按鈕大多少像素
local KEYSTONE_GLOW_R = 1.0
local KEYSTONE_GLOW_G = 0.1
local KEYSTONE_GLOW_B = 0.8

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
-- Helper: 建立或取得鑰石覆層元素（文字標籤 + 脈動光暈）
--------------------------------------------------------------------------------
local function GetOrCreateKeystoneOverlay(button)
    if button._miliKeystoneLabel then
        return button._miliKeystoneLabel, button._miliKeystoneGlow
    end

    -- 光暈 texture（覆蓋於按鈕外圍，使用 ADD 混色以產生發光感）
    local glow = button:CreateTexture(nil, "OVERLAY", nil, 7)
    glow:SetTexture(KEYSTONE_GLOW_TEXTURE)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(KEYSTONE_GLOW_R, KEYSTONE_GLOW_G, KEYSTONE_GLOW_B, 1)
    glow:SetPoint("TOPLEFT", button, "TOPLEFT", -KEYSTONE_GLOW_SIZE_PADDING, KEYSTONE_GLOW_SIZE_PADDING)
    glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", KEYSTONE_GLOW_SIZE_PADDING, -KEYSTONE_GLOW_SIZE_PADDING)
    glow:Hide()

    -- 脈動動畫（透明度 0.3 → 1.0 → 0.3 循環）
    local ag = glow:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1.0)
    fadeOut:SetToAlpha(0.3)
    fadeOut:SetDuration(0.7)
    fadeOut:SetOrder(1)
    local fadeIn = ag:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0.3)
    fadeIn:SetToAlpha(1.0)
    fadeIn:SetDuration(0.7)
    fadeIn:SetOrder(2)
    glow._anim = ag

    -- 文字標籤（右下角，與「帳綁」位置一致）
    local label = button:CreateFontString(nil, "OVERLAY", nil)
    label:SetFont(STANDARD_TEXT_FONT, KEYSTONE_FONT_SIZE, KEYSTONE_FONT_FLAGS)
    label:SetPoint("BOTTOMRIGHT", button.icon or button, "BOTTOMRIGHT", -2, 2)
    label:SetTextColor(1, 1, 1, 1)
    label:SetText(KEYSTONE_LABEL)
    label:Hide()

    button._miliKeystoneLabel = label
    button._miliKeystoneGlow = glow
    Log("Created overlay for button:", button:GetName() or tostring(button))
    return label, glow
end

--------------------------------------------------------------------------------
-- Core: 套用鑰石邊框顏色
-- 使用 _miliApplyingBorder 旗標避免遞迴 hook 自己造成的修改
--------------------------------------------------------------------------------
local function ApplyKeystoneBorder(button)
    local border = button.IconBorder
    if not border then return end
    button._miliApplyingBorder = true
    border:Show()
    border:SetVertexColor(KEYSTONE_BORDER_R, KEYSTONE_BORDER_G, KEYSTONE_BORDER_B, KEYSTONE_BORDER_A)
    button._miliApplyingBorder = false
end

--------------------------------------------------------------------------------
-- 在 IconBorder texture 上安裝守護 hook
--
-- 為什麼必須直接 hook texture：
--   Baganator Dark 皮膚（以及 ElvUI / NDui 等其他皮膚）會在按鈕被 skin 化
--   時對 SetItemButtonQuality 安裝它自己的 hook，覆蓋我們設定的邊框顏色。
--   按鈕的 skin 化發生在 layout 階段，比我們在 MyOnLoad 時安裝 hook 更晚，
--   所以它們的 hook 在 hooksecurefunc 鏈中排在我們之後執行。
--
--   解決方法：直接 hook IconBorder 這個 texture 物件本身的 SetVertexColor
--   與 Hide 方法 — 這是邊框顏色變更的最終出口，不論誰呼叫都會被攔截。
--   配合 _miliApplyingBorder 守衛避免我們自己的呼叫造成無限遞迴。
--------------------------------------------------------------------------------
local function HookIconBorder(button)
    local border = button.IconBorder
    if not border or button._miliBorderHooked then return end
    button._miliBorderHooked = true

    hooksecurefunc(border, "SetVertexColor", function(self, r, g, b, a)
        if not button._miliIsKeystone then return end
        if button._miliApplyingBorder then return end
        -- 顏色已經是鑰石色就不必再設一次（雙重保險）
        if r == KEYSTONE_BORDER_R and g == KEYSTONE_BORDER_G and b == KEYSTONE_BORDER_B then return end
        ApplyKeystoneBorder(button)
    end)

    hooksecurefunc(border, "Hide", function(self)
        if not button._miliIsKeystone then return end
        if button._miliApplyingBorder then return end
        ApplyKeystoneBorder(button)
    end)

    hooksecurefunc(border, "SetTexture", function(self)
        if not button._miliIsKeystone then return end
        if button._miliApplyingBorder then return end
        ApplyKeystoneBorder(button)
    end)
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
    local label, glow = GetOrCreateKeystoneOverlay(button)

    if IsKeystoneItem(itemLink) then
        Log("Keystone detected:", itemLink)
        button._miliIsKeystone = true
        -- 顯示文字
        label:Show()
        -- 顯示並啟動脈動光暈
        glow:Show()
        if glow._anim and not glow._anim:IsPlaying() then
            glow._anim:Play()
        end
        -- 套用邊框顏色
        ApplyKeystoneBorder(button)
    else
        -- 非鑰石：清除旗標，隱藏文字與光暈（邊框由 Baganator 自行管理）
        button._miliIsKeystone = false
        label:Hide()
        if glow then
            if glow._anim and glow._anim:IsPlaying() then
                glow._anim:Stop()
            end
            glow:Hide()
        end
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

    -- 在 IconBorder texture 上安裝守護 hook（最終攔截，最可靠）
    HookIconBorder(button)

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
