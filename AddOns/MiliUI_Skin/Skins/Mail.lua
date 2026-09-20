------------------------------------------------------------
-- 配方：郵件（MailFrame 收件匣／寄信頁 ＋ OpenMailFrame）
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_MailFrame/MailFrame.xml:274      MailFrame（ButtonFrameTemplate）
--   Blizzard_MailFrame/MailFrame.xml:288,295  InboxFrame ／ InboxFrameBg（UI-MailFrameBG）
--   Blizzard_MailFrame/MailFrame.xml:381,406  InboxPrevPageButton ／ InboxNextPageButton
--   Blizzard_MailFrame/MailFrame.xml:431      OpenAllMail（UIPanelButtonTemplate）
--   Blizzard_MailFrame/MailFrame.xml:447      SendMailFrame
--   Blizzard_MailFrame/MailFrame.xml:494      SendMailScrollFrame（ScrollFrameTemplate）
--   Blizzard_MailFrame/MailFrame.xml:562,650  SendMailNameEditBox ／ SendMailSubjectEditBox
--   Blizzard_MailFrame/MailFrame.xml:728      SendMailMoney（MoneyInputFrameTemplate）
--   Blizzard_MailFrame/MailFrame.xml:741,751  SendMailSendMoneyButton ／ SendMailCODButton
--   Blizzard_MailFrame/MailFrame.xml:763,769  SendMailMoneyInset ／ SendMailMoneyBg（ThinGoldEdgeTemplate）
--   Blizzard_MailFrame/MailFrame.xml:781,792  SendMailCancelButton ／ SendMailMailButton
--   Blizzard_MailFrame/MailFrame.xml:840,850  MailFrameTab1 / Tab2（FriendsFrameTabTemplate）
--   Blizzard_MailFrame/MailFrame.xml:877      OpenMailFrame（ButtonFrameTemplate）
--   Blizzard_MailFrame/MailFrame.xml:921      OpenMailReportSpamButton
--   Blizzard_MailFrame/MailFrame.xml:956,968  OpenMailScrollFrame ／ OpenStationeryBackground*
--   Blizzard_MailFrame/MailFrame.xml:1289,1298,1307  OpenMailCancel／Delete／ReplyButton
--   Blizzard_MailFrame/MailFrame.lua:21,26,27 SetPortraitToAsset ＋ SetNumTabs／SetTab
--   Blizzard_MailFrame/MailFrame.lua:548,1069 兩組信紙 SetTexture
--   Blizzard_MoneyFrame/Mainline/MoneyInputFrame.xml:3,72  MoneyFrameEditBoxTemplate ／ MoneyInputFrameTemplate
--   Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml:4  UIRadioButtonTemplate
--   Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml:1314 ThinGoldEdgeTemplate
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:472          FriendsFrameTabTemplate ← PanelTabButtonTemplate
--   Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:660,684 ButtonFrameBase／ButtonFrameTemplate
--   Blizzard_SharedXML/SecureUIPanelTemplates.lua:1              ScrollFrame_OnLoad → self.ScrollBar（MinimalScrollBar）
--
-- 查證後跟計畫假設不一樣的四件事：
--   1. **郵件不是隨需載入的。** `Blizzard_MailFrame` 的 TOC 是 `## DefaultState: enabled`
--      而且沒有 `LoadOnDemand`（它的相依是 `Blizzard_FriendsFrame`），所以登入就在
--      ⇒ `addon = nil`。
--   2. **底部兩顆分頁走的是 `FriendsFrameTabTemplate`**（定義在 `Blizzard_FriendsFrame`，
--      FriendsFrame.xml:472），而它只是 `PanelTabButtonTemplate` 加一個 OnClick
--      ⇒ 九張貼圖收在 `TabTextures` parentArray，`Skin.Tab(..., "panel")` 直接適用。
--      狀態切換走 `PanelTemplates_SetTab`（MailFrame.lua:27,145），Engine 的三個後置勾吃得到。
--   3. **收件人／主旨輸入框不是 `InputBoxTemplate`。** 它們的三張邊框貼圖是
--      `<Texture name="$parentLeft">`，**只有全域名字、沒有 parentKey**
--      （MailFrame.xml:574,581,588 與 662,669,676）⇒ `Skin.EditBox` 的 `NeutralizeKeys` 找不到，
--      改走本檔的 `SkinLegacyEditBox`。
--   4. **金額輸入框是三個各自獨立的小輸入框。** `MoneyInputFrameTemplate` 底下是
--      `gold` / `silver` / `copper` 三個 `MoneyFrameEditBoxTemplate`，各自帶
--      `parentKey="left"` / `parentKey="right"`（**小寫**）與一張只有全域名字的
--      `$parentMiddle`（MoneyInputFrame.xml:17-40）⇒ 三個框各畫一個 overlay。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- | 物件 | 動作 |
-- |---|---|
-- | MailFrame / OpenMailFrame 的 NineSlice / Bg / TopTileStreaks / PortraitContainer | SetAlpha(0) |
-- | MailFrame / OpenMailFrame 的 TitleContainer.TitleText | SetTextColor |
-- | MailFrame.Inset / OpenMailFrame.Inset 的 Bg 與 NineSlice | SetAlpha(0) |
-- | 兩顆關閉鈕的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | 兩顆關閉鈕的 Highlight/Pushed 貼圖 | SetColorTexture |
-- | MailFrameTab1..2 的 TabTextures（九張） | SetAlpha(0) |
-- | MailFrameTab1..2 | SetNormalFontObject(GameFontHighlightSmall) |
-- | InboxFrameBg | SetAlpha(0) |
-- | InboxPrev/NextPageButton 的 Highlight 貼圖 | SetColorTexture |
-- | 七顆 UIPanelButtonTemplate 的 Left/Right/Middle | SetAlpha(0) |
-- | 同七顆 | SetNormalFontObject(GameFontHighlight) |
-- | SendMailName/SubjectEditBox 的 *Left/*Middle/*Right（全域） | SetAlpha(0) |
-- | SendMailMoney{Gold,Silver,Copper} 的 left/right ＋ *Middle（全域） | SetAlpha(0) |
-- | SendMailMoneyBg 的 *Left/*Middle/*Right（全域） | SetAlpha(0) |
-- | SendMailSendMoneyButton / SendMailCODButton 的 Normal 貼圖 | SetAlpha(0) |
-- | 同兩顆的 Checked 貼圖 | SetVertexColor |
-- | SendMailMoneyInset 的 Bg / NineSlice | SetAlpha(0) |
-- | 兩條 MinimalScrollBar 的 Track/Thumb 六張貼圖 | SetAlpha(0) |
-- | 兩條 MinimalScrollBar 的 Back/Forward.Texture | SetVertexColor |
-- | 以上各框 | CreateFrame 掛自己的 overlay |
--
-- hook：只有 Engine 的三個 `PanelTemplates_*` 全域後置勾（分頁選中態，裝在 Core/Engine.lua）。
-- 寫入暴雪欄位：無。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **兩組信紙**（`SendStationeryBackgroundLeft/Right`、`OpenStationeryBackgroundLeft/Right`，
--   MailFrame.xml:506,512,968,974）—— 信件內文用的是 `MailTextFontNormal`（深色），
--   那個字色就是為信紙設計的。中和掉＝暗字壓暗底（內容底材保留規則）。
--   內文區只補一圈畫在**信紙之上**的 1px 邊（`BorderOnly`）。
-- * **三條 `UI-ClassTrainer-HorizontalBar` 分隔線**（MailFrame.xml:463,477,904）——
--   每條都是「一張具名的左半 ＋ 一張**無名無 parentKey** 的右半」。只中和得到左半，
--   留下半截比整條都在更難看，所以整組不動。等原語層有「無名裝飾貼圖」的作法再處理。
-- * **信件列 `MailItemTemplate` 的格子美術**（MailFrame.xml:15,22 與 :29 的分隔線）—— 同上，
--   三張貼圖全部無名無 parentKey，只能靠 `GetRegions()` 的索引去猜，太脆。
--   信件列本身是池化／逐列的東西，列在下一輪。
-- * **附件格**（`SendMailAttachment*`、`OpenMailAttachmentButton*`、`OpenMailLetterButton`、
--   `OpenMailMoneyButton`）—— 物品格帶品質色，是內容不是 chrome。
-- * **`SmallMoneyFrameTemplate` 的金幣數字**（`SendMailCostMoneyFrame`、
--   `SendMailMoneyFrame`、`OpenMail*MoneyFrame`）—— 那是值不是裝飾。
-- * **`MailFrame.trialError`、`InboxTooMuchMail`、`SendMailErrorText`、
--   `SendMailFrameLockSendMail`** —— 警告與遮罩，顏色本身就是訊息。
-- * **`ConsortiumMailFrame` / `OpenMailInvoiceFrame`** —— 拍賣／訂單收據的內容版面。
--
-- ⚠ 套組裡 **Postal** 也掛在這三個視窗上（見回報）。這一輪只 skin 暴雪自己的物件，
--   Postal 自己建的按鈕維持暴雪原樣。順帶一提 Postal 會把暴雪的 `OpenAllMail`
--   `Hide()` 起來換成自己那顆，所以我們給 `OpenAllMail` 的皮多半看不到 ——
--   照樣套，因為那是暴雪的框，而且玩家可能沒開 Postal。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

local TRANSPARENT = { 0, 0, 0, 0 }

------------------------------------------------------------
-- TODO(升格): 下面四支是「舊式模板」的通用處理，之後應該收進 Core/Primitives.lua。
--   等第二個視窗也用得上再升格 —— 現在只有郵件這一支，先留在配方裡。
------------------------------------------------------------

-- TODO(升格): 只有全域名字、沒有 parentKey 的三張切片（`<Texture name="$parentLeft">`）。
--   舊視窗滿地都是（輸入框、ThinGoldEdge、WhoFrame 的欄位表頭），Primitives 值得有一支。
local function NeutralizeGlobalSlices(prefix)
    E.NeutralizeGlobals({ prefix .. "Left", prefix .. "Middle", prefix .. "Right" })
end

-- TODO(升格): 舊式輸入框 ＝ 全域三張切片 ＋ EditBox overlay。
--   跟 `Skin.EditBox` 的差別只在「區域怎麼找」，升格時應該是 Skin.EditBox 多一個
--   `opts.globalPrefix`，而不是兩支函式。
local function SkinLegacyEditBox(eb, key, prefix)
    if not E.Usable(eb, key) then return end
    NeutralizeGlobalSlices(prefix or key)
    local ov = E.Overlay(eb, { key = key })
    E.Paint(ov, T.fillInset, T.border)
    return ov
end

-- TODO(升格): 只有圖示、沒有 Left/Middle/Right 的按鈕（收件匣的上一頁／下一頁）。
--   圖示本身**不中和** —— 那是「這顆按鈕是幹嘛的」唯一的線索，跟捲軸箭頭同一條理由
--   （STYLE.md ⑤ 的 MinimalScrollBar 那一列）。我們只補底與邊，滑過交給引擎。
local function SkinIconOnlyButton(btn, key)
    if not E.Usable(btn, key) then return end
    E.ButtonStates(btn, key)
    local ov = E.Overlay(btn, { key = key })
    E.Paint(ov, T.fill, T.border)
    return ov
end

-- TODO(升格): 「只畫一圈邊、不動底」。給保留了內容底材（信紙）但還是想要外框的區塊用。
--   層級 +1 才畫得在信紙之上（其餘 overlay 一律 −1），同 `Skin.Icon` 的邊框那一層。
local function BorderOnly(target, key)
    local ov = E.Overlay(target, { key = key .. ".border", levelOffset = 1 })
    E.Paint(ov, TRANSPARENT, T.border)
    return ov
end

------------------------------------------------------------
-- 金額輸入框（MoneyInputFrameTemplate）
--
-- 三個小輸入框各自獨立，所以各畫一個 overlay。三張切片的取法是混的：
-- `left` / `right` 是 **小寫的 parentKey**，`Middle` 只有全域名字
-- （Blizzard_MoneyFrame/Mainline/MoneyInputFrame.xml:17-40）。
--
-- 右邊那張金／銀／銅幣圖（`texture`）**不碰** —— 那是「這格是什麼幣值」，是值不是裝飾。
------------------------------------------------------------
local MONEY_PARTS = {
    { field = "gold",   suffix = "Gold" },
    { field = "silver", suffix = "Silver" },
    { field = "copper", suffix = "Copper" },
}

local function SkinMoneyInput(frame, globalName, key)
    if not E.Usable(frame, key) then return end
    for _, part in ipairs(MONEY_PARTS) do
        local box
        local bkey = key .. "." .. part.field
        if pcall(function() box = frame[part.field] end) and box then
            E.NeutralizeKeys(box, { "left", "right" }, bkey)
            E.NeutralizeGlobals({ globalName .. part.suffix .. "Middle" })
            local ov = E.Overlay(box, { key = bkey })
            E.Paint(ov, T.fillInset, T.border)
        else
            E.Missing(bkey)
        end
    end
end

------------------------------------------------------------
-- 收件匣頁
------------------------------------------------------------
local function SkinInbox()
    local inbox = _G.InboxFrame
    if not inbox then
        E.Missing("InboxFrame")
        return
    end

    -- UI-MailFrameBG：鋪滿內容區的那張大底圖。不中和就看不到皮。
    -- 信件列自己的格子美術留著（見檔頭），所以這一頁實測起來會是
    -- 「深灰底 ＋ 七條暴雪原本的棕色格線」 —— 池化列那一輪才會一致。
    E.NeutralizeGlobals({ "InboxFrameBg" })

    for _, name in ipairs({ "InboxPrevPageButton", "InboxNextPageButton" }) do
        local btn = _G[name]
        if btn then
            SkinIconOnlyButton(btn, name)
        else
            E.Missing(name)
        end
    end

    local openAll = _G.OpenAllMail
    if openAll then
        Skin.Button(openAll, "OpenAllMail")
    else
        E.Missing("OpenAllMail")
    end
end

------------------------------------------------------------
-- 寄信頁
------------------------------------------------------------
local function SkinSendMail()
    local frame = _G.SendMailFrame
    if not frame then
        E.Missing("SendMailFrame")
        return
    end

    SkinLegacyEditBox(_G.SendMailNameEditBox, "SendMailNameEditBox")
    SkinLegacyEditBox(_G.SendMailSubjectEditBox, "SendMailSubjectEditBox")

    -- 內文區：信紙不中和，只在它之上補一圈邊 ＋ 一條捲軸。
    local scroll = _G.SendMailScrollFrame
    if scroll then
        BorderOnly(scroll, "SendMailScrollFrame")
        local bar
        if pcall(function() bar = scroll.ScrollBar end) and bar then
            Skin.ScrollBar(bar, "SendMailScrollFrame.ScrollBar")
        else
            E.Missing("SendMailScrollFrame.ScrollBar")
        end
    else
        E.Missing("SendMailScrollFrame")
    end

    SkinMoneyInput(_G.SendMailMoney, "SendMailMoney", "SendMailMoney")

    -- 送錢／貨到付款是 UIRadioButtonTemplate：只有 Normal / Highlight / Checked 三張，
    -- 沒有 Pushed 也沒有 Disabled。`Skin.CheckBox` 走 getter 不點名 parentKey，所以
    -- 少了兩張也不會出事（拿不到就跳過）。圓鈕換成方框是刻意的 —— 直角是這包的語彙。
    for _, name in ipairs({ "SendMailSendMoneyButton", "SendMailCODButton" }) do
        local btn = _G[name]
        if btn then
            Skin.CheckBox(btn, name)
        else
            E.Missing(name)
        end
    end

    local inset = _G.SendMailMoneyInset
    if inset then
        Skin.Inset(inset, "SendMailMoneyInset")
    else
        E.Missing("SendMailMoneyInset")
    end

    -- ThinGoldEdgeTemplate：金額顯示那條的金邊。三張切片同樣只有全域名字。
    -- 中和就好，不補 overlay —— 它正好疊在 SendMailMoneyInset 上，那一層已經有底有邊了。
    NeutralizeGlobalSlices("SendMailMoneyBg")

    for _, name in ipairs({ "SendMailMailButton", "SendMailCancelButton" }) do
        local btn = _G[name]
        if btn then
            Skin.Button(btn, name)
        else
            E.Missing(name)
        end
    end
end

------------------------------------------------------------
-- 讀信視窗
------------------------------------------------------------
local OPEN_MAIL_BUTTONS = {
    "OpenMailReportSpamButton",
    "OpenMailReplyButton",
    "OpenMailDeleteButton",
    "OpenMailCancelButton",
}

local function SkinOpenMail()
    local f = _G.OpenMailFrame
    if not f then
        E.Missing("OpenMailFrame")
        return
    end

    Skin.PortraitChrome(f, "OpenMailFrame")
    Skin.Panel(f, "OpenMailFrame")

    local inset
    if pcall(function() inset = f.Inset end) and inset then
        Skin.Inset(inset, "OpenMailFrame.Inset")
    else
        E.Missing("OpenMailFrame.Inset")
    end

    local close
    if pcall(function() close = f.CloseButton end) and close then
        Skin.CloseButton(close, "OpenMailFrame.CloseButton")
    else
        E.Missing("OpenMailFrame.CloseButton")
    end

    for _, name in ipairs(OPEN_MAIL_BUTTONS) do
        local btn = _G[name]
        if btn then
            Skin.Button(btn, name)
        else
            E.Missing(name)
        end
    end

    local scroll = _G.OpenMailScrollFrame
    if scroll then
        BorderOnly(scroll, "OpenMailScrollFrame")
        local bar
        if pcall(function() bar = scroll.ScrollBar end) and bar then
            Skin.ScrollBar(bar, "OpenMailScrollFrame.ScrollBar")
        else
            E.Missing("OpenMailScrollFrame.ScrollBar")
        end
    else
        E.Missing("OpenMailScrollFrame")
    end
end

local function Apply()
    local f = MailFrame
    if not f then
        E.Missing("MailFrame")
        return
    end

    Skin.PortraitChrome(f, "MailFrame")
    Skin.Panel(f, "MailFrame")

    local inset
    if pcall(function() inset = f.Inset end) and inset then
        Skin.Inset(inset, "MailFrame.Inset")
    else
        E.Missing("MailFrame.Inset")
    end

    local close
    if pcall(function() close = f.CloseButton end) and close then
        Skin.CloseButton(close, "MailFrame.CloseButton")
    else
        E.Missing("MailFrame.CloseButton")
    end

    -- 底部兩顆分頁（收件匣／寄出郵件）。FriendsFrameTabTemplate ← PanelTabButtonTemplate，
    -- 九張貼圖收在 TabTextures parentArray ⇒ kind = "panel"。
    for i = 1, 2 do
        local key = "MailFrameTab" .. i
        local tab = _G[key]
        if tab then
            Skin.Tab(tab, key, "panel")
        else
            E.Missing(key)
        end
    end

    SkinInbox()
    SkinSendMail()
    SkinOpenMail()
end

E.Register{
    key   = "mail",
    addon = nil,                       -- Blizzard_MailFrame 的 TOC 是 DefaultState: enabled、非 LoD
    title = L["Mail"],
    apply = Apply,
}
