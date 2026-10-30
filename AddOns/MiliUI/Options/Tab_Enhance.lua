------------------------------------------------------------
-- 「插件強化」分頁：Baganator 鑰石發光、
-- Chattynator 聊天視窗樣式、Raider.IO 右鍵選單
--
-- 分界：這頁只管**第三方插件**的強化（Baganator、Chattynator、Raider.IO）。
-- 暴雪介面本身的便利功能（商人、任務、探究、世界地圖、調色盤、巨集視窗、好友名單、
-- 拍賣行……）在獨立插件 MiliUI_QoL，它自己向本體註冊「便利功能」分頁。
--
-- 每一條 spec 自帶 get/set，直接接各 Enhance 模組的全域 API
-- （MiliUI_BaganatorKeystone / MiliUI_ChattynatorTabs /
--   MiliUI_ChattynatorButtons / MiliUI_ChattynatorURLs / MiliUI_RaiderIOUnitMenu）。
-- 模組沒載入時 get/set 都靜默略過。
------------------------------------------------------------
local _, ns = ...

local W = ns.W

local tab, scroll, refreshers

local function RefreshAll()
    if not refreshers then return end
    for _, fn in ipairs(refreshers) do fn() end
end

-- 「需要重載」的設定改動後問一聲
local reloadPopup
local function AskReload()
    if not reloadPopup then
        reloadPopup = W.CreateConfirmPopup(ns.WidgetsEnv.PopupParent(), 300,
            "此設定需要重新載入介面才會完全生效，現在重載嗎？",
            function() ReloadUI() end)
    end
    reloadPopup:Show()
end

-- Baganator 鑰石發光的顏色列：色票＋重設鈕（只有這頁用，走 custom spec）
local function BuildKeystoneColorRow(parent, x, y, width)
    local cp = W.CreateColorPicker(parent, nil, false, function(r, g, b)
        if MiliUI_BaganatorKeystone then MiliUI_BaganatorKeystone.SetColor(r, g, b) end
    end)
    cp:SetPoint("LEFT", parent, "TOPLEFT", x, y - 13)

    local function Refresh()
        if not MiliUI_BaganatorKeystone then return end
        local r, g, b = MiliUI_BaganatorKeystone.GetColor()
        cp:SetColor({ r = r, g = g, b = b, a = 1 })
    end

    local reset = W.CreateButton(parent, "重設為預設色", "normal", 100, 20)
    reset:SetPoint("LEFT", cp, "RIGHT", 10, 0)
    reset:SetScript("OnClick", function()
        if not MiliUI_BaganatorKeystone then return end
        MiliUI_BaganatorKeystone.SetColor(MiliUI_BaganatorKeystone.GetDefaultColor())
        Refresh()
    end)

    return 26, Refresh
end

local CONTROLS = {
    { type = "header", label = "Baganator 背包" },
    { type = "toggle", label = "鑰石發光提示",
      get = function() return MiliUI_BaganatorKeystone and MiliUI_BaganatorKeystone.IsEnabled() end,
      set = function(v) if MiliUI_BaganatorKeystone then MiliUI_BaganatorKeystone.SetEnabled(v) end end },
    { type = "text", label = "在 Baganator 背包中為鑰石加上彩色邊框、脈動光暈與「鑰石」文字標籤。" },
    { type = "custom", label = "發光顏色", build = BuildKeystoneColorRow },

    { type = "header", label = "Chattynator 聊天視窗" },
    { type = "toggle", label = "分頁標籤改用套組樣式",
      get = function() return MiliUI_ChattynatorTabs and MiliUI_ChattynatorTabs.IsEnabled() end,
      set = function(v) if MiliUI_ChattynatorTabs then MiliUI_ChattynatorTabs.SetEnabled(v) end end },
    { type = "text", label = "把聊天視窗的分頁標籤換成跟設定介面同一套：不透明純色底、1px 直角硬邊、白字。"
        .. "每個標籤的顏色仍然由 Chattynator 自己的設定決定（右鍵標籤 →「標籤顏色」），這裡只換樣式。" },
    { type = "toggle", label = "側邊按鈕改用套組樣式",
      get = function() return MiliUI_ChattynatorButtons and MiliUI_ChattynatorButtons.IsEnabled() end,
      set = function(v) if MiliUI_ChattynatorButtons then MiliUI_ChattynatorButtons.SetEnabled(v) end end },
    { type = "text", label = "把左側那排按鈕（好友／頻道／語音／快捷聊天／搜尋／複製／設定）的圓角底"
        .. "換成純色方底加 1px 直角硬邊，按鈕間距收窄、整排下移到訊息區頂端，"
        .. "好友數那串數字也挪到圖示底下並加上描邊。" },
    { type = "toggle", label = "網址可點擊複製",
      get = function() return MiliUI_ChattynatorURLs and MiliUI_ChattynatorURLs.IsEnabled() end,
      set = function(v) if MiliUI_ChattynatorURLs then MiliUI_ChattynatorURLs.SetEnabled(v) end end },
    { type = "text", label = "訊息裡的網址變成藍色 [網址] 連結，點一下跳出複製框並自動全選，"
        .. "依 Mac／Windows 提示按 Cmd+C 或 Ctrl+C，複製後自動關閉。"
        .. "緊貼中文的網址、沒寫 https:// 的網域（如 raider.io/…）也認得出來。" },

    { type = "header", label = "Raider.IO" },
    { type = "toggle", label = "關閉右鍵選單的 Raider.IO 項目",
      get = function() return MiliUI_RaiderIOUnitMenu and MiliUI_RaiderIOUnitMenu.IsEnabled() end,
      set = function(v)
          if not MiliUI_RaiderIOUnitMenu then return end
          MiliUI_RaiderIOUnitMenu.SetEnabled(v)
          AskReload()
      end },
    { type = "text", label = "不在玩家右鍵選單裡加「複製 Raider.IO 網址」。那個項目會讓選單裡的「密語」"
        .. "把聊天輸入框弄髒，首領戰／傳奇鑰石中可能打不了字，要重載才恢復。"
        .. "這裡的勾選會蓋過 Raider.IO 自己設定裡的同一個選項。" },
}

-- spec 自帶 get/set，ctx 只是轉接
local ctx = {
    get = function(spec) if spec.get then return spec.get() end end,
    set = function(spec, v) if spec.set then spec.set(v) end end,
    apply = function() end,
}

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab("插件強化")
    local _
    _, refreshers = ns.Options.BuildScrollBody(scroll, CONTROLS, ctx)
end

ns.RegisterCallback("ShowOptionsTab", "enhanceTab", function(id)
    if id ~= "enhance" then
        if tab then tab:Hide() end
        return
    end
    Init()
    RefreshAll()
    tab:Show()
end)
