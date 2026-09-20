------------------------------------------------------------
-- 配方：對話視窗（GossipFrame）
--
-- 暴雪原始碼出處（12.1.0.69875）：
--   Blizzard_UIPanels_Game/Mainline/GossipFrame.xml
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml（ButtonFrameTemplate）
--   Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml
--
-- GossipFrame 是 `UIThemeContainerFrame`，繼承 `ButtonFrameTemplate`。
--
------------------------------------------------------------
-- ## taint 接觸面清單（這份配方碰了哪些暴雪物件、各用了哪個白名單動作）
--
-- | 物件 | 動作 |
-- |---|---|
-- | GossipFrame.NineSlice / .Bg / .TopTileStreaks / .PortraitContainer | SetAlpha(0) |
-- | GossipFrame.TitleContainer.TitleText | SetTextColor |
-- | GossipFrame.Inset.Bg / .NineSlice | SetAlpha(0) |
-- | GossipFrame.CloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | GossipFrame.CloseButton 的 Highlight/Pushed 貼圖 | SetColorTexture |
-- | GossipFrame.GreetingPanel.GoodbyeButton 的 Left/Right/Middle | SetAlpha(0) |
-- | GossipFrame.GreetingPanel.GoodbyeButton | SetNormalFontObject(GameFontHighlight) |
-- | GossipFrame.GreetingPanel.ScrollBar 的 Track/Thumb 六張貼圖 | SetAlpha(0) |
-- | GossipFrame.GreetingPanel.ScrollBar 的 Back/Forward.Texture | SetVertexColor |
-- | 以上各框 | CreateFrame 掛自己的 overlay（SetAllPoints，不吃滑鼠） |
--
-- hook：無。
-- 寫入暴雪欄位：無。讀暴雪欄位：只讀 parentKey 找區域，以及 GetFrameLevel（有守衛）。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * `GossipFrame.Background` —— 對話正文的**羊皮紙底**。暴雪的
--   `UIThemeContainerMixin:UpdateBackground` 會依「任務文字對比」設定重新 SetAtlas，
--   而對話選項的字色（QuestFontLeft）就是為那張底設計的。中和掉＝暗字壓暗底。
-- * `GossipFrame.GreetingPanel` 的四張 Material* 貼圖 —— 模板裡沒有 file，
--   實際上畫不出東西，碰它只是多一筆接觸面。
-- * `FriendshipStatusBar`、對話選項按鈕（`GossipTitleButtonTemplate`）—— 內容不是 chrome。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local L = ns.L

local function Apply()
    local f = GossipFrame
    if not f then
        E.Missing("GossipFrame")
        return
    end

    Skin.PortraitChrome(f, "GossipFrame")
    Skin.Panel(f, "GossipFrame")

    local inset
    if pcall(function() inset = f.Inset end) and inset then
        Skin.Inset(inset, "GossipFrame.Inset")
    else
        E.Missing("GossipFrame.Inset")
    end

    local close
    if pcall(function() close = f.CloseButton end) and close then
        Skin.CloseButton(close, "GossipFrame.CloseButton")
    else
        E.Missing("GossipFrame.CloseButton")
    end

    local panel
    if pcall(function() panel = f.GreetingPanel end) and panel then
        local goodbye
        if pcall(function() goodbye = panel.GoodbyeButton end) and goodbye then
            Skin.Button(goodbye, "GossipFrame.GreetingPanel.GoodbyeButton")
        else
            E.Missing("GossipFrame.GreetingPanel.GoodbyeButton")
        end

        local bar
        if pcall(function() bar = panel.ScrollBar end) and bar then
            Skin.ScrollBar(bar, "GossipFrame.GreetingPanel.ScrollBar")
        else
            E.Missing("GossipFrame.GreetingPanel.ScrollBar")
        end
    else
        E.Missing("GossipFrame.GreetingPanel")
    end
end

E.Register{
    key   = "gossip",
    addon = nil,                       -- Blizzard_UIPanels_Game 是 LoadFirst，永遠在
    title = L["Gossip"],
    apply = Apply,
}
