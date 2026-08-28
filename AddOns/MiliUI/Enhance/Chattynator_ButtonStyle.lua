------------------------------------------------------------
-- MiliUI: Chattynator 側邊按鈕樣式
--
-- 內建 skin 的側邊按鈕（好友／頻道／語音／快捷聊天／搜尋／複製／設定／捲到底）
-- 是拿一張圓角 PNG（Assets/ChatButton.png）當底，四個角都是圓弧。這裡換成跟
-- 設定介面、分頁標籤同一套：純色方底 ＋ 1px 直角硬邊，沒有圓角。
--
-- 另外四件事：
--   * 滑過時邊框與圖示換職業色（內建 skin 是寫死的青色，跟套組其他地方對不起來）
--   * 好友數那串數字挪到圖示底下（原本疊在圖示身上）並加黑色描邊
--   * 按鈕間距從 5 收到 2
--   * 整排往下拉進聊天框背景，左右上三邊邊距統一（原本是左 3、右 5、上 7）
--
-- 怎麼掛上去的
-- ------------
-- 跟 Chattynator_TabStyle 同一條路：addonTable 是私有的，但聊天視窗的父層是
-- 具名全域 ChattynatorHyperlinkHandler，從它的 children 就能撈到每個聊天視窗，
-- 再拿 chatFrame.ButtonsBar。
--
-- 按鈕不從 bar.buttons 撈，改掃 bar:GetChildren() —— 因為
--   * ScrollToBottomButton 沒有被放進 bar.buttons
--   * 語音的靜音／關閉喇叭兩顆也沒有
-- 而這幾顆一樣是 skin 畫的同一張圓角圖。ButtonsBar 的子框架只有按鈕，掃過去
-- 剛好全涵蓋。
--
-- 貼圖的作法
-- ----------
-- 直接把 skin 那張 normal／pushed 貼圖換成 WHITE8X8 加自己的顏色（不動它的
-- 錨點 —— skin 已經把幾何對好了，動了反而要記一堆東西才能還原），再自己補
-- 四條 1px 邊 ＋ 一張淡的滑過薄膜。
--
-- skin 會在這幾個時機把貼圖重畫回圓角圖，所以要重套：
--   1. SetIconToState —— 頻道／語音按鈕換狀態時，skin 掛在上面整組重設
--   2. ButtonsBar:Update —— 換位置、縮放、開關按鈕列都會跑
--   3. 按鈕自己的 OnShow —— 滑鼠移進來淡入時會 Show，等於免費的自我修復點
--
-- 讀寫於 MiliUI_DB.chattynatorButtonStyle（boolean，預設 true）。
------------------------------------------------------------

local _, ns = ...
local P = ns.P

local WHITE = "Interface\\Buttons\\WHITE8X8"

-- 這排按鈕沒有身分色（不是玩家設的、也不是職業／品質色），所以走 Widgets.lua
-- 那套既有的色階，不是標籤那套 seed 推導：閒置 0.115、滑過 0.23。
--
-- 滑過那階的**底色**交給 highlight 貼圖，引擎自己管顯示，不用掛腳本。
-- 白色 alpha 0.13 疊在 0.115 上剛好等於 0.23：0.115 x (1 - 0.13) + 0.13 = 0.23。
-- （職業色那半是掛 OnEnter／OnLeave 的，理由見 ApplyButton。）
local FILL_IDLE    = { 0.115, 0.115, 0.115, 1 }
local FILL_PUSHED  = { 0.04, 0.04, 0.04, 1 }
local HIGHLIGHT    = { 1, 1, 1, 0.13 }

-- 邊框沒有跟著 Widgets.lua 用純黑：那套的元件坐在 0.1 的面板上，黑邊有東西可襯；
-- 這排按鈕坐在會動的遊戲畫面上，黑邊會讓整顆糊成一團看不出是方的。
-- 拉到 0.30（比滑過那階再亮一點）才描得出方形，也還沒跳出既有色階。
local EDGE         = { 0.30, 0.30, 0.30, 1 }

-- 滑過時邊框與圖示換職業色。底色的明暗階梯（0.115 → 0.23）照舊 ——
-- 明暗說「它現在怎麼了」，職業色說「焦點在這」，跟設定視窗的深色按鈕
-- （Style.lua 的 DarkEnter）、勾選框、下拉是同一句話。
-- 顏色只加在 1px 的邊跟 15x15 的圖示上，大面積的底色不碰。
--
-- 內建 skin 自己有一組 hover 色，但是寫死的青色（Dark.lua 的 hoverColor
-- = 59/210/237），跟套組其他地方對不起來，這裡整個蓋掉。
local function Accent(alpha)
    return MiliUI.Style.Accent(alpha)
end

-- 間距：按鈕之間 2，跟聊天框邊緣 4（左、右、上三邊同一個值）。
-- 內小外大是刻意的 —— 差一倍，這排才會讀成「一組」而不是四散的方塊。
--
-- 外距不寫死，用空欄算：outside_left 時聊天框左緣到訊息區左緣有 34（背景鋪滿
-- 整個聊天框，所以那條空欄是看得見的深色），扣掉按鈕寬度除以二就是置中的邊距，
-- 剛好 4。換 skin 把按鈕加寬也還是置中。算不出來（rect 還沒生效）才退回 4。
local BUTTON_GAP = 2
local EDGE_MARGIN = 4
-- 訊息區上緣再往上 5px 也還是背景（wrapper 一律內縮 5，有沒有分頁列都一樣），
-- 所以「距離背景上緣 margin」換算成錨點偏移是 5 - margin。
local WRAPPER_INSET = 5
-- 好友數字級上限。按鈕只有 28 高，圖示自己就佔掉 14，
-- 暴雪原本的字級塞不下才會跟圖示疊在一起。
local COUNT_MAX_SIZE = 11

local active = false
local styledButtons = {}
local hookedBars = {}

local function GetDB()
    if not MiliUI_DB then MiliUI_DB = {} end
    if MiliUI_DB.chattynatorButtonStyle == nil then
        MiliUI_DB.chattynatorButtonStyle = true
    end
    return MiliUI_DB
end

local function IsEnabled()
    return GetDB().chattynatorButtonStyle and true or false
end

------------------------------------------------------------
-- 原樣記錄（關掉功能時要還回去）
--
-- 貼圖有可能是 atlas（暴雪 skin 的 chatframe-button-up 就是），GetTexture()
-- 拿到的只有底圖，座標會掉，所以 atlas 要另外記。
------------------------------------------------------------
local function SnapshotTexture(tex)
    if not tex then return nil end
    local layer, sublayer = tex:GetDrawLayer()
    return {
        atlas = tex.GetAtlas and tex:GetAtlas() or nil,
        file = tex:GetTexture(),
        color = { tex:GetVertexColor() },
        layer = layer,
        sublayer = sublayer,
    }
end

local function RestoreTexture(tex, snap)
    if not tex or not snap then return end
    if snap.atlas then
        tex:SetAtlas(snap.atlas)
    else
        tex:SetTexture(snap.file)
    end
    tex:SetVertexColor(snap.color[1], snap.color[2], snap.color[3], snap.color[4])
    tex:SetDrawLayer(snap.layer, snap.sublayer)
end

local function Snapshot(button)
    if button._miliBtnOrig then return end
    button._miliBtnOrig = {
        normal = SnapshotTexture(button:GetNormalTexture()),
        pushed = SnapshotTexture(button:GetPushedTexture()),
        highlight = SnapshotTexture(button:GetHighlightTexture()),
        -- 有些 skin（ElvUI、GW2）根本把三張都清掉，還原時要清回去，
        -- 不然會留下我們補的那張白方塊
        hadNormal = button:GetNormalTexture() ~= nil,
        hadPushed = button:GetPushedTexture() ~= nil,
        hadHighlight = button:GetHighlightTexture() ~= nil,
    }
end

local function SavePoints(region)
    if region._miliBtnPoints then return end
    local pts = {}
    for i = 1, region:GetNumPoints() do
        pts[i] = { region:GetPoint(i) }
    end
    region._miliBtnPoints = pts
end

local function RestorePoints(region)
    local pts = region and region._miliBtnPoints
    if not pts then return end
    region:ClearAllPoints()
    for _, pt in ipairs(pts) do
        region:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5])
    end
end

------------------------------------------------------------
-- 自己的四條邊
------------------------------------------------------------
local function EnsureEdges(button)
    local edges = button._miliBtnEdges
    if not edges then
        edges = {}
        for i = 1, 4 do
            local e = button:CreateTexture(nil, "BORDER")
            e:SetTexture(WHITE)
            edges[i] = e
        end
        edges[1]:SetPoint("TOPLEFT");    edges[1]:SetPoint("TOPRIGHT")
        edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT")
        edges[3]:SetPoint("TOPLEFT");    edges[3]:SetPoint("BOTTOMLEFT")
        edges[4]:SetPoint("TOPRIGHT");   edges[4]:SetPoint("BOTTOMRIGHT")
        button._miliBtnEdges = edges
    end

    -- 每次重套都重算，UI 縮放改過也跟著對齊
    local px = P.Scale(1)
    edges[1]:SetHeight(px)
    edges[2]:SetHeight(px)
    edges[3]:SetWidth(px)
    edges[4]:SetWidth(px)
    for _, e in ipairs(edges) do
        e:Show()
    end
    return edges
end

-- 邊框顏色每次重套都重問一次滑鼠焦點：ApplyLook 會在滑鼠還停在按鈕上時重跑
-- （SetIconToState、Update 都會），無條件塗回灰色的話滑過的職業色會被自己抹掉。
local function UpdateEdgeColor(button)
    local edges = button._miliBtnEdges
    if not edges then return end
    if button:IsMouseMotionFocus() then
        local r, g, b = Accent(1)
        for _, e in ipairs(edges) do e:SetVertexColor(r, g, b, 1) end
    else
        for _, e in ipairs(edges) do
            e:SetVertexColor(EDGE[1], EDGE[2], EDGE[3], EDGE[4])
        end
    end
end

------------------------------------------------------------
-- 把圓角底換成方底
------------------------------------------------------------
local function ApplyLook(button)
    local normal = button:GetNormalTexture()
    if not normal then
        button:SetNormalTexture(WHITE)
        normal = button:GetNormalTexture()
    end
    if normal then
        normal:SetTexture(WHITE)
        normal:SetVertexColor(FILL_IDLE[1], FILL_IDLE[2], FILL_IDLE[3], FILL_IDLE[4])
        normal:SetDrawLayer("BACKGROUND")
    end

    local pushed = button:GetPushedTexture()
    if not pushed then
        button:SetPushedTexture(WHITE)
        pushed = button:GetPushedTexture()
    end
    if pushed then
        pushed:SetTexture(WHITE)
        pushed:SetVertexColor(FILL_PUSHED[1], FILL_PUSHED[2], FILL_PUSHED[3], FILL_PUSHED[4])
        pushed:SetDrawLayer("BACKGROUND")
    end

    -- skin 把 highlight 清掉了，滑過完全沒回饋。補一張很淡的白薄膜，
    -- 交給引擎管顯示，不用掛 OnEnter／OnLeave（那種掛法會被之後的
    -- SetScript 洗掉）。
    local highlight = button:GetHighlightTexture()
    if not highlight then
        button:SetHighlightTexture(WHITE)
        highlight = button:GetHighlightTexture()
    end
    if highlight then
        highlight:SetTexture(WHITE)
        highlight:SetVertexColor(HIGHLIGHT[1], HIGHLIGHT[2], HIGHLIGHT[3], HIGHLIGHT[4])
    end

    EnsureEdges(button)
    UpdateEdgeColor(button)
end

------------------------------------------------------------
-- 好友數：描邊 ＋ 挪到圖示底下
--
-- 只認 Chattynator 自己用的那兩個欄位（button.FriendCount 或全域
-- FriendsMicroButtonCount），不掃 regions —— 那顆按鈕還掛著別的文字。
--
-- 它沒有被圖示蓋住（數字畫在上層），是位置重疊：skin 把按鈕壓成 26x28、
-- 圖示釘在 TOP 佔掉上半，好友數卻還留在暴雪原本的錨點，就疊到圖示身上。
-- 這裡改釘到 BOTTOM，字級壓到塞得下的大小，再補 OUTLINE 描邊。
-- 字體檔沿用，字級只會變小不會變大 —— 放大才會讓 FontString 重新配置吃掉字。
------------------------------------------------------------
local function GetCountText(button)
    if button.FriendCount then return button.FriendCount end
    if FriendsMicroButton and button == FriendsMicroButton then
        return FriendsMicroButtonCount
    end
    return nil
end

local function ApplyCountFont(button)
    local fs = GetCountText(button)
    if not fs or not fs.GetFont then return end

    local file, size, flags = fs:GetFont()
    if not file then return end

    if not fs._miliBtnFont then
        local layer, sublayer = fs:GetDrawLayer()
        fs._miliBtnFont = { file, size, flags, fs:GetShadowOffset() }
        fs._miliBtnLayer = { layer, sublayer }
        SavePoints(fs)
    end

    -- 描邊：本來就有就別動，免得把 THICKOUTLINE 降級
    if not (flags and flags:find("OUTLINE")) then
        fs:SetFont(file, math.min(size, COUNT_MAX_SIZE), "OUTLINE")
        fs:SetShadowOffset(0, 0)                         -- 描邊之後陰影只會糊掉
    end

    -- 挪到圖示底下，並確保永遠壓在圖示上層
    fs:SetDrawLayer("OVERLAY")
    fs:ClearAllPoints()
    fs:SetPoint("BOTTOM", button, "BOTTOM", 0, 1)
end

local function RestoreCountFont(button)
    local fs = GetCountText(button)
    local orig = fs and fs._miliBtnFont
    if not orig then return end
    fs:SetFont(orig[1], orig[2], orig[3] or "")
    fs:SetShadowOffset(orig[4] or 0, orig[5] or 0)
    if fs._miliBtnLayer then
        fs:SetDrawLayer(fs._miliBtnLayer[1], fs._miliBtnLayer[2])
    end
    RestorePoints(fs)
end

------------------------------------------------------------
-- 滑過的職業色：圖示 ＋ 好友數
--
-- 閒置色不寫死，改成從按鈕身上抄一份 —— 語音／頻道按鈕的閒置色會隨狀態變
-- （通話中是綠的），寫死就會把那個狀態訊號抹掉。抄的時機是「滑鼠不在按鈕上」
-- 的每一次重套，所以狀態換過就跟著更新。
------------------------------------------------------------
local function SnapshotIdleTint(button)
    if button:IsMouseMotionFocus() then return end
    local icon = button.Icon
    if icon and icon.GetVertexColor then
        button._miliIconIdle = { icon:GetVertexColor() }
    end
    local fs = GetCountText(button)
    if fs then
        button._miliCountIdle = { fs:GetTextColor() }
    end
end

local function SetAccentTint(button, on)
    local icon, fs = button.Icon, GetCountText(button)
    if on then
        local r, g, b = Accent(1)
        if icon and icon.SetVertexColor then icon:SetVertexColor(r, g, b) end
        if fs then fs:SetTextColor(r, g, b) end
    else
        local c = button._miliIconIdle
        if icon and icon.SetVertexColor and c then
            icon:SetVertexColor(c[1], c[2], c[3], c[4])
        end
        local t = button._miliCountIdle
        if fs and t then fs:SetTextColor(t[1], t[2], t[3], t[4]) end
    end
end

------------------------------------------------------------
-- 單顆按鈕
------------------------------------------------------------
local function ApplyButton(button)
    if not styledButtons[button] then
        Snapshot(button)

        -- 淡入時會 Show，等於免費的重套點
        button:HookScript("OnShow", function()
            if not active then return end
            ApplyLook(button)
            SnapshotIdleTint(button)
        end)

        -- 頻道／語音按鈕換狀態時，skin 會把整組貼圖重設回圓角圖、順便重上圖示色。
        -- 我們比 skin 晚掛 → 晚執行，蓋得回來；滑鼠還停在上面的話職業色要補回去。
        if button.SetIconToState then
            hooksecurefunc(button, "SetIconToState", function()
                if not active then return end
                ApplyLook(button)
                SnapshotIdleTint(button)
                if button:IsMouseMotionFocus() then SetAccentTint(button, true) end
            end)
        end

        -- 滑過換職業色。這裡掛 OnEnter／OnLeave 是安全的：Chattynator 只在建按鈕
        -- 那一刻 SetScript 一次（AddButtons 被 madeButtons 擋著不會重跑），之後
        -- 它自己跟各家 skin 一律走 HookScript，洗不掉我們。
        button:HookScript("OnEnter", function()
            if not active then return end
            SetAccentTint(button, true)
            UpdateEdgeColor(button)
        end)
        button:HookScript("OnLeave", function()
            if not active then return end
            SetAccentTint(button, false)
            UpdateEdgeColor(button)
        end)

        styledButtons[button] = true
    end

    ApplyLook(button)
    ApplyCountFont(button)
    SnapshotIdleTint(button)
end

local function RestoreButton(button)
    local orig = button._miliBtnOrig
    if not orig then return end

    SetAccentTint(button, false)

    if orig.hadNormal then
        RestoreTexture(button:GetNormalTexture(), orig.normal)
    else
        button:ClearNormalTexture()
    end
    if orig.hadPushed then
        RestoreTexture(button:GetPushedTexture(), orig.pushed)
    else
        button:ClearPushedTexture()
    end
    if orig.hadHighlight then
        RestoreTexture(button:GetHighlightTexture(), orig.highlight)
    else
        button:ClearHighlightTexture()
    end

    for _, e in ipairs(button._miliBtnEdges or {}) do
        e:Hide()
    end

    RestoreCountFont(button)
end

------------------------------------------------------------
-- 找出每個聊天視窗的按鈕列
------------------------------------------------------------
local function ApplyBar(bar)
    for _, child in ipairs({ bar:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Button" then
            ApplyButton(child)
        end
    end
end

-- 語音的靜音／關閉喇叭兩顆是特例：Chattynator 只把「關閉喇叭」重新掛到按鈕列上，
-- 「靜音」那顆留在原本的父層，卻一樣套了 ChatButton 樣式。掃 children 撈不到它，
-- 只好認全域名字 —— 用 skin 蓋的 added 旗標確認確實是 Chattynator 畫的那顆。
local function ApplyVoiceButtons()
    local deafen, mute = ChatFrameToggleVoiceDeafenButton, ChatFrameToggleVoiceMuteButton
    if deafen and deafen.added then ApplyButton(deafen) end
    if mute and mute.added then ApplyButton(mute) end
end

------------------------------------------------------------
-- 重排：間距縮小 ＋ 整排往下拉
--
-- 原本的排法在 ButtonsBarMixin:Update 裡，間距寫死 5、起點 y 寫死 +20
-- （分頁列那一行的高度），x 寫死 -5。量出來三邊邊距全都不一樣：
-- 左 3、右 5、上 7。我們後掛同一個方法、照它的錨點語意重排一次，
-- 三邊統一成 margin，按鈕之間換成 BUTTON_GAP。
--
-- 只管左側直排、而且是掛在聊天框外面那種：
--   * 橫排（按鈕擺在分頁列那排）bar 的錨點是 TOPLEFT
--   * inside_left（按鈕壓在訊息區裡面）x 是正的
-- 看錨點與 x 的正負比猜設定值可靠，那些設定都在私有的 addonTable 裡。
--
-- bar 本身也要跟著挪 —— 按鈕淡出隱藏之後，要靠 bar 的範圍接滑鼠才會淡回來，
-- 只挪按鈕會讓感應區跟按鈕對不上。
--
-- Chattynator 自己算的「塞不下就藏起來」用的是舊間距，我們不去接管：
-- 我們排得比它緊，它判斷塞得下的就一定塞得下。
------------------------------------------------------------
local function SideMargin(bar, relTo, button)
    local chatFrame = bar:GetParent()
    if not (chatFrame and chatFrame:IsRectValid() and relTo:IsRectValid()) then
        return EDGE_MARGIN
    end
    local gutterLeft, contentLeft = chatFrame:GetLeft(), relTo:GetLeft()
    if not (gutterLeft and contentLeft) then return EDGE_MARGIN end

    local margin = (contentLeft - gutterLeft - button:GetWidth()) / 2
    if margin < 0 then return EDGE_MARGIN end
    return math.floor(margin + 0.5)
end

local function RepositionBar(bar)
    if not active then return end

    local point, relTo, relPoint, x = bar:GetPoint(1)
    if point ~= "TOPRIGHT" or not relTo or not x or x >= 0 then return end

    local first = (bar.buttons or {})[1]
    if not first then return end

    local offsetY = WRAPPER_INSET - SideMargin(bar, relTo, first)

    bar:ClearAllPoints()
    bar:SetPoint(point, relTo, relPoint, x, offsetY)

    for _, b in ipairs(bar.buttons) do
        -- 每顆各自置中：同一個 skin 裡按鈕通常一樣寬，但 GW2 的好友鈕就比別人大一號
        local offsetX = -SideMargin(bar, relTo, b)

        -- 好友按鈕被 Chattynator 掛了 SetPoint 監視：只要 relativeTo 不是
        -- socialAnchor1[2] 就會被彈回去。我們錨在同一個 relTo，所以不會觸發，
        -- 但還是把 socialAnchor1 同步成新位置，免得暴雪那邊重新錨定時彈回舊的。
        if b == QuickJoinToastButton or b == FriendsMicroButton then
            bar.socialAnchor1 = { "TOPRIGHT", relTo, relPoint, offsetX, offsetY }
        end
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", relTo, relPoint, offsetX, offsetY)
        offsetY = offsetY - b:GetHeight() - BUTTON_GAP
    end
end

local function ForEachBar(func)
    local handler = ChattynatorHyperlinkHandler
    if not handler then return end
    for _, child in ipairs({ handler:GetChildren() }) do
        if child.ButtonsBar and child.ButtonsBar.buttons then
            func(child.ButtonsBar)
        end
    end
end

local function Refresh()
    if not active then return end
    ForEachBar(function(bar)
        if not hookedBars[bar] then
            hookedBars[bar] = true
            -- 換按鈕列位置、視窗縮放、開關按鈕列都會跑這個；
            -- 順便接上這中間開出來的新聊天視窗
            hooksecurefunc(bar, "Update", function()
                if active then Refresh() end
            end)
        end
        ApplyBar(bar)
        RepositionBar(bar)
    end)
    ApplyVoiceButtons()
end

local function SetEnabled(enabled)
    GetDB().chattynatorButtonStyle = enabled and true or false
    if IsEnabled() then
        active = true
        Refresh()
    else
        active = false
        for button in pairs(styledButtons) do
            RestoreButton(button)
        end
        -- active 關掉之後 RepositionBar 就不動手了，讓它照原本的間距重排
        ForEachBar(function(bar) bar:Update() end)
    end
end

------------------------------------------------------------
-- 對外 API（給 Options/Tab_Enhance.lua 用）
------------------------------------------------------------
MiliUI_ChattynatorButtons = {
    IsEnabled = IsEnabled,
    SetEnabled = SetEnabled,
    Refresh = Refresh,
}

-- skin 是在 PLAYER_LOGIN 才套到按鈕上的，兩邊註冊同一個事件不保證誰先跑，
-- 所以延一幀再動 —— 那時 skin 一定畫完了，按鈕也都建好了
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if not C_AddOns.IsAddOnLoaded("Chattynator") then return end
    C_Timer.After(0, function()
        if IsEnabled() then
            active = true
            Refresh()
        end
    end)
end)
