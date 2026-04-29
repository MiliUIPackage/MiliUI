--------------------------------------------------------------------------------
-- Baganator_Keystone
-- 在 Baganator 背包中強化鑰石顯示：
--   1. 右下角加入白色「鑰石」文字（類似「帳綁」「裝綁」）
--   2. 變更鑰石邊框顏色 + 脈動光暈（顏色可由 MiliUI 設定面板自訂）
--
-- 設定值由 MiliUI_DB.baganatorKeystone 提供，預設為 hot pink。
--
-- 使用 hooksecurefunc 安全掛接，不修改 Baganator 原始碼。
--
-- 技術說明：
--   1. Baganator 較新版本對所有 mixin 表呼叫 table.freeze；同時 Mixin /
--      SetItemButtonQuality 等候選 hook 點不是被禁止 hook 就是 widget method
--      (不會走全域)。改用「事件驅動 + 掃描」策略：
--        - 監聽 BAG_UPDATE_DELAYED / BANKFRAME_OPENED 等事件
--        - 也對每個 Baganator_* 主 frame 掛 OnShow
--        - 觸發後遞迴掃描 children，遇到帶 BGR 欄位的 ItemButton 即視為
--          Baganator 按鈕，對該 instance（非 frozen）掛 SetItemDetails
--          與 IconBorder hook。已 hook 過的 instance 由 hookedButtons 跳過。
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

-- 預設值
local DEFAULT_COLOR_R, DEFAULT_COLOR_G, DEFAULT_COLOR_B = 1.0, 0.85, 0.1 -- 亮金黃

-- 光暈設定
local KEYSTONE_GLOW_TEXTURE = "Interface\\Buttons\\UI-ActionButton-Border"
local KEYSTONE_GLOW_SIZE_PADDING = 14   -- 光暈比按鈕大多少像素

-- 文字設定
local KEYSTONE_LABEL = "鑰石"
local KEYSTONE_FONT_SIZE = 12
local KEYSTONE_FONT_FLAGS = "OUTLINE"

--------------------------------------------------------------------------------
-- 設定值存取
--   讀寫於 MiliUI_DB.baganatorKeystone：
--     enabled  (boolean) — 是否啟用鑰石發光效果（預設 true）
--     r, g, b  (number)  — 邊框與光暈顏色（預設 hot pink）
--------------------------------------------------------------------------------
local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if not MiliUI_DB.baganatorKeystone then
        MiliUI_DB.baganatorKeystone = {
            enabled = true,
            r = DEFAULT_COLOR_R,
            g = DEFAULT_COLOR_G,
            b = DEFAULT_COLOR_B,
        }
    end
    local db = MiliUI_DB.baganatorKeystone
    if db.enabled == nil then db.enabled = true end
    if db.r == nil then db.r = DEFAULT_COLOR_R end
    if db.g == nil then db.g = DEFAULT_COLOR_G end
    if db.b == nil then db.b = DEFAULT_COLOR_B end
    return db
end

local function GetColor()
    local db = GetDB()
    return db.r, db.g, db.b
end

local function IsEnabled()
    return GetDB().enabled
end

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
    local r, g, b = GetColor()
    glow:SetVertexColor(r, g, b, 1)
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
    local r, g, b = GetColor()
    button._miliApplyingBorder = true
    border:Show()
    border:SetVertexColor(r, g, b, 1)
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
        local kr, kg, kb = GetColor()
        if r == kr and g == kg and b == kb then return end
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

    -- 功能停用時：不建立任何 overlay，並關閉既存的 overlay
    if not IsEnabled() then
        button._miliIsKeystone = false
        if button._miliKeystoneLabel then button._miliKeystoneLabel:Hide() end
        if button._miliKeystoneGlow then
            if button._miliKeystoneGlow._anim and button._miliKeystoneGlow._anim:IsPlaying() then
                button._miliKeystoneGlow._anim:Stop()
            end
            button._miliKeystoneGlow:Hide()
        end
        return
    end

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

--------------------------------------------------------------------------------
-- 為什麼不再 hook mixin 表：
--   Baganator 在 ItemButton.lua / Layouts.lua 結尾對 mixin 表呼叫 table.freeze，
--   嘗試 hooksecurefunc(BaganatorRetailLiveContainerItemButtonMixin, "MyOnLoad", ...)
--   會觸發 "attempted to perform indexed assignment on a frozen table"。
--
-- 改用全域 Mixin 函式作為偵測點：
--   1. Baganator 按鈕在 XML OnLoad 中呼叫 Mixin(self, mixin) 把 mixin 方法複製到實例
--   2. Mixin 是 Blizzard 全域函式（SharedXML/Mixin.lua），可被 hooksecurefunc 安全 hook
--   3. 在 hook 中比對傳入的 mixin table 是否為 Baganator 的兩個目標 mixin，
--      若是則 object 即為剛建好的 button 實例 — 此時 mixin 已完成、SetItemDetails
--      尚未呼叫，是最理想的 hook 時機
--   4. instance 表不是 frozen，可正常對其 hooksecurefunc(SetItemDetails) 與
--      hook IconBorder texture 的 SetVertexColor / Hide / SetTexture
--   注意：不能改 hook button 的 SetItemButtonQuality（widget method），
--   因為它是另一個 reference，不會走全域 SetItemButtonQuality 函式。
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- 遞迴掃描 frame 階層，對每個帶 BGR 欄位（Baganator 標記）的 ItemButton
-- 進行首次 hook + 立即套用一次裝飾。已 hook 過的 instance 自動跳過。
--------------------------------------------------------------------------------
local function ScanFrame(frame)
    if not frame then return end
    if frame.BGR ~= nil and not hookedButtons[frame] then
        HookButtonInstance(frame)
        OnSetItemDetails(frame, frame.BGR)
    end
    if frame.GetChildren then
        for _, child in ipairs({frame:GetChildren()}) do
            ScanFrame(child)
        end
    end
end

--------------------------------------------------------------------------------
-- 找出 UIParent 下所有名稱以 "Baganator_" 開頭的 view frame 並掃描。
-- Baganator 主 view frame（backpack / bank / guild / warband）皆此命名。
--------------------------------------------------------------------------------
local scannedFrameOnShow = {} -- 避免重複 HookScript 同一個 frame

local function ScanBaganator()
    local children = {UIParent:GetChildren()}
    for _, child in ipairs(children) do
        -- 跳過 forbidden frame：對外部呼叫其 method 會擲錯
        -- (用 IsForbidden 而非 pcall — pcall 包 C method 在某些情況會當機)
        if not child:IsForbidden() then
            local name = child:GetName()
            if name and name:find("^Baganator_") then
                -- 第一次見到此 view frame：掛 OnShow，後續顯示時自動掃描
                if not scannedFrameOnShow[child] then
                    scannedFrameOnShow[child] = true
                    child:HookScript("OnShow", function(self) ScanFrame(self) end)
                end
                ScanFrame(child)
            end
        end
    end
end

local function SetupHooks()
    local f = CreateFrame("Frame")
    -- 物品變動 / 背包銀行公會打開時觸發掃描
    f:RegisterEvent("BAG_UPDATE_DELAYED")
    f:RegisterEvent("BANKFRAME_OPENED")
    f:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    f:RegisterEvent("GUILDBANKFRAME_OPENED")
    f:RegisterEvent("GUILDBANK_UPDATE_TABS")
    f:SetScript("OnEvent", function()
        -- 0-tick 延遲：等 Baganator 完成這一輪 layout 後再掃描
        C_Timer.After(0, ScanBaganator)
    end)
    -- 立即掃一次（/reload 時背包可能已開啟）
    ScanBaganator()
    Log("Hooked: scan-on-events strategy")
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

--------------------------------------------------------------------------------
-- 對外 API：供 MiliUI 設定面板呼叫
--   Refresh()      — 設定變更後立即重新套用到所有已 hook 的按鈕
--   SetEnabled(b)  — 切換功能開關並 Refresh
--   SetColor(r,g,b)— 設定顏色並 Refresh
--   GetColor()     — 取得目前顏色
--   IsEnabled()    — 取得目前狀態
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- 將某個按鈕的邊框還原為 Baganator / 皮膚應有的品質色。
-- 透過呼叫按鈕本身的 SetItemButtonQuality（Baganator 已經 mixin 過此方法），
-- 讓 Dark 皮膚的 ItemButtonQualityHook 等鏈上的 hook 重新跑一次，
-- 把正確的品質色畫回去。
--------------------------------------------------------------------------------
local function RestoreNormalBorder(button)
    if not button.BGR then return end
    if not button.SetItemButtonQuality then return end
    button:SetItemButtonQuality(button.BGR.quality, button.BGR.itemLink, false, button.BGR.isBound)
end

--------------------------------------------------------------------------------
-- 為某個按鈕啟用鑰石裝飾（建立 overlay、設旗標、套色、播放動畫）
-- 用於 Refresh() 在重新啟用時 / 改色時觸發
--------------------------------------------------------------------------------
local function EnableKeystoneOnButton(button)
    local label, glow = GetOrCreateKeystoneOverlay(button)
    button._miliIsKeystone = true
    label:Show()
    glow:Show()
    if glow._anim and not glow._anim:IsPlaying() then
        glow._anim:Play()
    end
    ApplyKeystoneBorder(button)
end

local function Refresh()
    local r, g, b = GetColor()
    local enabled = IsEnabled()
    for button in pairs(hookedButtons) do
        -- 同步光暈顏色（即使隱藏中也先更新好，下次顯示時就是新色）
        if button._miliKeystoneGlow then
            button._miliKeystoneGlow:SetVertexColor(r, g, b, 1)
        end

        if enabled then
            -- 重新偵測：從 Baganator 的 BGR 快取讀取物品連結，
            -- 判斷此格目前是否為鑰石。這樣即使先前停用過、旗標已清，
            -- 也能在重新啟用時正確還原所有鑰石格的裝飾。
            local itemLink = button.BGR and button.BGR.itemLink
            if IsKeystoneItem(itemLink) then
                EnableKeystoneOnButton(button)
            elseif button._miliIsKeystone then
                -- 之前是鑰石、現在不是：清掉裝飾（理論上 SetItemDetails
                -- 已經處理，但保險起見再做一次）
                button._miliIsKeystone = false
                if button._miliKeystoneLabel then button._miliKeystoneLabel:Hide() end
                if button._miliKeystoneGlow then
                    if button._miliKeystoneGlow._anim and button._miliKeystoneGlow._anim:IsPlaying() then
                        button._miliKeystoneGlow._anim:Stop()
                    end
                    button._miliKeystoneGlow:Hide()
                end
                RestoreNormalBorder(button)
            end
        else
            -- 停用：只處理目前還掛著鑰石裝飾的按鈕，其他格子完全不要碰，
            -- 否則會把整個背包的品質色洗掉。
            if button._miliIsKeystone then
                button._miliIsKeystone = false
                if button._miliKeystoneLabel then button._miliKeystoneLabel:Hide() end
                if button._miliKeystoneGlow then
                    if button._miliKeystoneGlow._anim and button._miliKeystoneGlow._anim:IsPlaying() then
                        button._miliKeystoneGlow._anim:Stop()
                    end
                    button._miliKeystoneGlow:Hide()
                end
                RestoreNormalBorder(button)
            end
        end
    end
end

MiliUI_BaganatorKeystone = {
    Refresh = Refresh,
    IsEnabled = IsEnabled,
    GetColor = GetColor,
    SetEnabled = function(enabled)
        GetDB().enabled = enabled and true or false
        Refresh()
    end,
    SetColor = function(r, g, b)
        local db = GetDB()
        db.r, db.g, db.b = r, g, b
        Refresh()
    end,
    GetDefaultColor = function()
        return DEFAULT_COLOR_R, DEFAULT_COLOR_G, DEFAULT_COLOR_B
    end,
}
