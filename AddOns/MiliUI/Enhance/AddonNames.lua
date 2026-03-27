-- AddonNames.lua
-- 集中管理插件在「選項 > 插件」面板中的中文顯示名稱
-- 透過 hook SettingsPanel 的 CategoryList，在分類列表刷新後自動替換名稱
-- 只需在此檔案中維護翻譯對照表，無需修改其他插件

if GetLocale() ~= "zhTW" then return end

------------------------------------------------------------------------
-- 翻譯對照表
-- key   = 插件在「選項 > 插件」面板中顯示的原始名稱（去除顏色碼後的純文字）
-- value = 你想要的中文名稱
--
-- 新增翻譯只需加一行，刪除翻譯只需移除一行。
------------------------------------------------------------------------
local addonNames = {
    -- ==================== 介面 / 通用 ====================
    ["AdvancedInterfaceOptions"]                            = "進階介面選項",
    ["AppearanceTooltip"]                                   = "外觀預覽提示",
    ["Leatrix Plus"]                                        = "功能百寶箱",
    ["Plumber"]                                             = "實用工具包",
    ["Masque"]                                              = "快捷列樣式",
    ["tullaRange"]                                          = "技能範圍提示",
    ["EasyExperienceBar"]                                   = "經驗條",
    ["BugSack"]                                             = "錯誤訊息收集袋",
    ["Stuf"]                                                = "Stuf 頭像設定",

    -- ==================== 拍賣 / 物品 / 背包 ====================
    ["Auctionator"]                                         = "拍賣小幫手",
    ["Baganator"]                                           = "背包整合",
    ["Syndicator"]                                          = "物品資訊",

    -- ==================== 聊天 ====================
    ["Chattynator"]                                         = "聊天視窗增強",

    -- ==================== 地圖 ====================
    ["HandyNotes"]                                          = "地圖標記",
    ["Mapster"]                                             = "地圖增強",

    -- ==================== M+ / 副本工具 ====================
    ["Method Raid Tools"]                                   = "團隊工具箱",
    ["Premade Groups Filter"]                               = "預組隊伍過濾",
    ["RaiderIO"]                                            = "Raider.IO 分數查詢",
    ["WarpDeplete"]                                         = "M+ 計時介面",
    ["MplusAdventureGuide"]                                 = "冒險指南強化",

    -- ==================== 名條 / 提示 ====================
    ["Platynator"]                                          = "Platynator 名條",
    ["TinyInspect"]                                         = "裝備觀察",
    ["TinyTooltip-Remake"]                                  = "浮動提示增強",

    -- ==================== 有中文但想修改的 ====================
    -- 去除 [前綴] 方括號
    ["[商人] 介面增強"]                                       = "商人介面增強",
    ["MCL | 坐騎收集日誌"]                                    = "坐騎收集日誌",

    -- ==================== MiliUI（排序用的隱藏前綴會被去除） ====================
    ["0米利UI設定"]                                          = "米利UI設定",

    -- ==================== 已有中文但想微調的 ====================
    -- 如果你覺得這些名稱 OK 可以把它們刪掉
    ["傳送選單"]                                             = "傳送選單",
    ["地圖增強"]                                             = "地圖增強",
    ["廣告守衛"]                                             = "廣告守衛",
    ["快捷聊天列"]                                            = "快捷聊天列",
    ["聲望"]                                                 = "巔峰聲望",
    
}

------------------------------------------------------------------------
-- 以下為 hook 機制，不需要修改
------------------------------------------------------------------------

-- 去除 WoW 顏色碼和特殊標記
local function StripColorCodes(text)
    if not text then return "" end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):match("^%s*(.-)%s*$") or ""
end

-- 重新命名單一按鈕
local function RenameButton(button)
    -- 安全取得文字元素（不是所有 frame 都有 GetFontString）
    local textObj = button.Text or button.Label
    if not textObj then
        if button.GetFontString then
            textObj = button:GetFontString()
        end
    end
    if not textObj then return end

    local text = textObj:GetText()
    if not text then return end

    local cleanText = StripColorCodes(text)
    local newName = addonNames[cleanText]
    if newName then
        textObj:SetText(newName)
    end
end

-- 掃描所有可見的分類按鈕並重新命名
local function RenameAllVisible(scrollBox)
    if not scrollBox then return end
    if scrollBox.ForEachFrame then
        scrollBox:ForEachFrame(RenameButton)
    elseif scrollBox.GetFrames then
        for _, button in pairs({scrollBox:GetFrames()}) do
            RenameButton(button)
        end
    end
end

------------------------------------------------------------------------
-- Hook SettingsPanel（選項面板）
------------------------------------------------------------------------
local settingsHooked = false

local function HookSettingsPanel()
    if settingsHooked then return end
    if not SettingsPanel then return end

    local categoryList = SettingsPanel.CategoryList
    if not categoryList then return end

    settingsHooked = true

    local scrollBox = categoryList.ScrollBox
    if scrollBox then
        -- 每次列表捲動或刷新時重新命名
        hooksecurefunc(scrollBox, "Update", function(self)
            RenameAllVisible(self)
        end)
    end

    -- 面板顯示時也執行一次
    SettingsPanel:HookScript("OnShow", function()
        C_Timer.After(0.1, function()
            RenameAllVisible(scrollBox)
        end)
    end)

    -- 切換「遊戲/插件」分頁時也執行
    if SettingsPanel.GameTab then
        SettingsPanel.GameTab:HookScript("OnClick", function()
            C_Timer.After(0.1, function() RenameAllVisible(scrollBox) end)
        end)
    end
    if SettingsPanel.AddOnsTab then
        SettingsPanel.AddOnsTab:HookScript("OnClick", function()
            C_Timer.After(0.1, function() RenameAllVisible(scrollBox) end)
        end)
    end

    -- 如果面板目前正在顯示，立即執行一次
    if SettingsPanel:IsShown() then
        C_Timer.After(0.1, function() RenameAllVisible(scrollBox) end)
    end
end

-- 等待 SettingsPanel 載入（它是延遲載入的）
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addonName)
    if SettingsPanel then
        HookSettingsPanel()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- 如果 SettingsPanel 已經存在就直接 hook
if SettingsPanel then
    HookSettingsPanel()
end
