------------------------------------------------------------
-- 配方：郵件（MailFrame 收件匣／寄信頁 ＋ OpenMailFrame）
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_MailFrame/MailFrame.xml:11       MailItemTemplate（三張**無名**美術 ＋ 兩條 FontString）
--   Blizzard_MailFrame/MailFrame.xml:71       MailItemTemplate 的 `$parentButton`（CheckButton，
--                                             帶 `$parentSlot` / `Icon` / `IconBorder` / COD / Count）
--   Blizzard_MailFrame/MailFrame.xml:173      SendMailAttachment（Button ＋ 無名 UI-Slot-Background ＋ IconBorder）
--   Blizzard_MailFrame/MailFrame.xml:274      MailFrame（ButtonFrameTemplate）
--   Blizzard_MailFrame/MailFrame.xml:288,295  InboxFrame ／ InboxFrameBg（UI-MailFrameBG）
--   Blizzard_MailFrame/MailFrame.xml:381,406  InboxPrevPageButton ／ InboxNextPageButton
--                                             （32x32，箭頭是 Normal/Pushed/Disabled 三張；
--                                              「上頁」「繼續」是**無名無 parentKey** 的 layer FontString，:388,:413）
--   Blizzard_MailFrame/MailFrame.xml:431      OpenAllMail（UIPanelButtonTemplate）
--   Blizzard_MailFrame/MailFrame.xml:447      SendMailFrame
--   Blizzard_MailFrame/MailFrame.xml:463,477  SendMailHorizontalBarLeft / Left2（＋各自一張**無名**右半，:470,:484）
--   Blizzard_MailFrame/MailFrame.xml:494      SendMailScrollFrame（ScrollFrameTemplate）
--   Blizzard_MailFrame/MailFrame.xml:506,512  SendStationeryBackgroundLeft / Right（信紙）
--   Blizzard_MailFrame/MailFrame.xml:527      SendMailBodyEditBox（FontString 走 MailTextFontNormal）
--   Blizzard_MailFrame/MailFrame.xml:562,650  SendMailNameEditBox ／ SendMailSubjectEditBox
--   Blizzard_MailFrame/MailFrame.xml:574-594  收件人框的三張切片：$parentLeft 錨 TOPLEFT(-8,-2) 8x20、
--                                             $parentMiddle 100x20、$parentRight 8x20（框本身 109x25）
--   Blizzard_MailFrame/MailFrame.xml:662-682  主旨框：$parentLeft 錨 TOPLEFT(-8,0)、Middle 221、Right 8（框 220x20）
--   Blizzard_MailFrame/MailFrame.xml:697-712  SendMailAttachment1..16
--   Blizzard_MailFrame/MailFrame.xml:728      SendMailMoney（MoneyInputFrameTemplate）
--   Blizzard_MailFrame/MailFrame.xml:741,751  SendMailSendMoneyButton ／ SendMailCODButton
--   Blizzard_MailFrame/MailFrame.xml:763,769  SendMailMoneyInset ／ SendMailMoneyBg（ThinGoldEdgeTemplate）
--   Blizzard_MailFrame/MailFrame.xml:781,792  SendMailCancelButton ／ SendMailMailButton
--   Blizzard_MailFrame/MailFrame.xml:840,850  MailFrameTab1 / Tab2（FriendsFrameTabTemplate）
--   Blizzard_MailFrame/MailFrame.xml:877      OpenMailFrame（ButtonFrameTemplate）
--   Blizzard_MailFrame/MailFrame.xml:904,911  OpenMailHorizontalBarLeft ＋一張無名右半
--   Blizzard_MailFrame/MailFrame.xml:956,968  OpenMailScrollFrame ／ OpenStationeryBackground*
--   Blizzard_MailFrame/MailFrame.xml:989      OpenMailBodyText（SimpleHTML，MailTextFontNormal）
--   Blizzard_MailFrame/MailFrame.xml:996      ConsortiumMailFrame（五條 InvoiceTextFontNormal ＋ 兩個金錢框）
--   Blizzard_MailFrame/MailFrame.xml:1094     OpenMailInvoiceFrame（九條具名 InvoiceTextFontNormal ＋四個金錢框）
--   Blizzard_MailFrame/MailFrame.xml:1224,1242,1258  OpenMailLetterButton／AttachmentButton1..16／MoneyButton（皆 ItemButton）
--   Blizzard_MailFrame/MailFrame.xml:1289,1298,1307  OpenMailCancel／Delete／ReplyButton
--   Blizzard_MailFrame/MailFrame.lua:190      InboxFrame_Update
--   Blizzard_MailFrame/MailFrame.lua:233-262  信件鈕的 SetItemButtonQuality／IconBorder:Hide()／
--                                             Slot 每次重設 vertex color／Icon 每次 SetTexture
--   Blizzard_MailFrame/MailFrame.lua:516      OpenMail_Update
--   Blizzard_MailFrame/MailFrame.lua:736-739,1065-1070  兩組信紙每次 SetTexture/SetTexCoord/SetHeight
--   Blizzard_MailFrame/MailFrame.lua:958      SendMailFrame_Update
--   Blizzard_MoneyFrame/Mainline/MoneyInputFrame.xml:3,72  MoneyFrameEditBoxTemplate ／ MoneyInputFrameTemplate
--   Blizzard_MoneyFrame/Shared/MoneyFrame.lua:311          SetMoneyFrameColorByFrame → **SetNormalFontObject**
--   Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml:4   UIRadioButtonTemplate
--   Blizzard_ItemButton/Shared/ItemButtonTemplate.xml:4           ItemButton intrinsic
--   Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua:76,94,189,241  SetItemButtonTexture／Quality／Border
--   Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml:1314 ThinGoldEdgeTemplate
--   Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:472          FriendsFrameTabTemplate ← PanelTabButtonTemplate
--   Blizzard_SharedXML/SecureUIPanelTemplates.lua:1              ScrollFrame_OnLoad → self.ScrollBar（MinimalScrollBar）
--
-- 查證後跟計畫假設不一樣的五件事：
--   1. **郵件不是隨需載入的。** `Blizzard_MailFrame` 的 TOC 是 `## DefaultState: enabled`
--      而且沒有 `LoadOnDemand` ⇒ `addon = nil`。
--   2. **底部兩顆分頁走的是 `FriendsFrameTabTemplate`** ← `PanelTabButtonTemplate`
--      ⇒ 九張貼圖收在 `TabTextures` parentArray，`Skin.Tab(..., "panel")` 直接適用。
--   3. **收件人／主旨輸入框不是 `InputBoxTemplate`。** 三張邊框貼圖是
--      `<Texture name="$parentLeft">`，**只有全域名字、沒有 parentKey**
--      ⇒ 走 `Skin.EditBox` 的 `opts.globalPrefix`。
--      而且**美術的矩形比框小一圈**（見上面的行號），overlay 一定要給 `points`，
--      不然畫出來的方塊會往右壓到「郵資」。
--   4. **金額輸入框是三個各自獨立的小輸入框。** `gold`/`silver`/`copper` 三個
--      `MoneyFrameEditBoxTemplate`，切片是 `parentKey="left"`/`"right"`（**小寫**）
--      ＋ 只有全域名字的 `$parentMiddle`。
--   5. **收件匣的信件鈕不是 `ItemButton`**，是手寫的 `CheckButton`
--      （MailFrame.xml:71），圖示欄位叫 `Icon`（大寫）而不是 `icon`。
--      `Skin.ItemButton` 兩種都找，所以照樣適用。
--      它的 `CheckedTexture`（`CheckButtonHilight`，ADD）是「目前打開的是哪一封」
--      的**選中**訊號 ⇒ 走 `Engine.CheckedTexture` 換成職業色。
--
------------------------------------------------------------
-- ## 信紙為什麼這一輪改成深色（內容底材規則的第二個實例）
--
-- 第二輪的結論是「信紙不碰」。第三輪改掉，理由跟成就視窗一模一樣：深色外框裡
-- 包著一整張亮橘信紙是整個視窗最不協調的地方。
--
-- 破例的代價是規則的後半段 —— **換底材就要連同上面所有文字顏色一起接管，而且
-- 要查清楚暴雪在哪些路徑重設那些顏色。** 這個視窗查出來是：
--
--   寄信頁：信紙上只有一條文字線 —— `SendMailBodyEditBox`（`MailTextFontNormal`）。
--           `MailFrame.lua` 全檔沒有任何一行重設它的顏色 ⇒ 設一次就撐得住。
--   讀信視窗：信紙上有三種互斥的內容，全部查過：
--           a. `OpenMailBodyText`（SimpleHTML）—— 只被 `SetText(bodyText, true)`
--              （.lua:546）。`SetText` 會依字型物件重排 ⇒ 顏色放在
--              `OpenMail_Update` 的後置勾裡重申，不是只設一次。
--           b. `OpenMailInvoiceFrame` 的九條具名 `InvoiceTextFontNormal` ——
--              沒有任何一條在 Lua 裡被重設顏色。
--           c. `ConsortiumMailFrame` 的五條 parentKey FontString ＋
--              `CommissionPaidDisplay.CommissionPaidText` —— 同上。
--              它的 `Separator` 是 `DEFAULT_MATERIAL_TEXT_COLOR`（深色）⇒ 改亮。
--           另外那幾個金錢框（`SmallMoneyFrameTemplate` / `MoneyDisplayFrameTemplate`）
--           **不用碰**：它們的字色走 `SetMoneyFrameColorByFrame` →
--           `SetNormalFontObject(NumberFontNormalRight…)`（MoneyFrame.lua:311-316），
--           那一族本來就是**白／紅／綠**，深底上讀得到。
--           躲在金錢框裡的 `+` `-` 與數量是**無名** `InvoiceTextFontNormal`
--           ⇒ 走 `Engine.RecolorRegions` 掃那一層的 FontString。
--
-- ⚠ 接不乾淨的殘留（回報裡有列）：**信件內文自己帶的色碼**。玩家寫的信不會有，
--   但系統信與拍賣信會用 `|cff……|r` 指定顏色（多半是亮金／亮白，深底上沒問題），
--   而 GM 信件與部分活動信件會出現深色色碼 —— 那是字串裡的資料，任何顏色接管
--   都蓋不過去。這是已知殘留，不是漏查。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 兩個視窗的 chrome
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
-- | 九顆 UIPanelButtonTemplate 的 Left/Right/Middle | SetAlpha(0) |
-- | 同九顆 | SetNormalFontObject(GameFontHighlight) |
-- | 兩條 MinimalScrollBar 的 Track/Thumb 六張貼圖 | SetAlpha(0) |
-- | 兩條 MinimalScrollBar 的 Back/Forward.Texture | SetVertexColor |
--
-- ### 收件匣
--
-- | 物件 | 動作 |
-- |---|---|
-- | InboxFrameBg | SetAlpha(0) |
-- | MailItem1..7 自己的三張無名貼圖（兩片棕框 ＋ 列底那條 0.33/0.16/0 的線） | SetAlpha(0)（GetRegions 掃） |
-- | MailItem1..7ButtonSlot（UI-EmptySlot-White） | SetAlpha(0) |
-- | MailItem1..7 的列底與列間髮絲線 | overlay **parent ＝ MailItem<i>Button**（跟著暴雪的 Show/Hide 一起出現／消失） |
-- | MailItem1..7Button 的 IconBorder | SetAlpha(0) |
-- | 同七顆的 Icon | SetTexCoord |
-- | 同七顆的 NormalTexture（沒有）／Highlight | SetColorTexture |
-- | 同七顆的 CheckedTexture | SetAlpha(1) ＋ SetColorTexture（職業色） |
-- | InboxPrev/NextPageButton 的 Normal/Pushed/Disabled 貼圖 | SetAlpha(0)（第七輪：整組中和，改畫自己的 ‹ › 線條圖記） |
-- | 同兩顆的 OnEnable / OnDisable | HookScript（第七輪；圖記的停用態，見 `Engine.TrackGlyph`） |
-- | 同兩顆的無名 FontString（「上頁」「繼續」） | SetTextColor |
-- | 同兩顆的 Highlight 貼圖 | SetColorTexture |
--
-- ### 寄信頁
--
-- ⚠ **第七輪加的三條欄位標籤**（文字層級規則見 STYLE.md ④）：
--
-- | 物件 | 動作 |
-- |---|---|
-- | SendMailMoneyText（`SEND_MONEY`，MailFrame.xml:387） | SetTextColor(textDim) |
-- | SendMailNameEditBox 那一層的無名 FontString（`MAIL_TO_LABEL`，:345） | SetTextColor(textDim)（GetRegions） |
-- | SendMailSubjectEditBox 那一層的無名 FontString（`MAIL_SUBJECT_LABEL`，:433） | 同上 |
-- | SendMailCostMoneyFrame 那一層的無名 FontString（`SEND_MAIL_COST`，:458） | 同上 |
--
-- 三條都是 XML 靜態文字、暴雪不重設顏色 ⇒ **零 hook**。
--
-- | 物件 | 動作 |
-- |---|---|
-- | SendMailName/SubjectEditBox 的 *Left/*Middle/*Right（全域） | SetAlpha(0) |
-- | SendStationeryBackgroundLeft/Right | SetAlpha(0) |
-- | SendMailBodyEditBox | SetTextColor |
-- | SendMailHorizontalBarLeft/Left2 ＋ 兩張無名右半 | SetAlpha(0)（GetRegions 掃 SendMailFrame） |
-- | SendMailAttachment1..16 的無名 UI-Slot-Background、IconBorder | SetAlpha(0) |
-- | 同 16 顆的 icon | SetTexCoord |
-- | SendMailMoney{Gold,Silver,Copper} 的 left/right ＋ *Middle（全域） | SetAlpha(0) |
-- | SendMailMoneyBg 的 *Left/*Middle/*Right（全域） | SetAlpha(0) |
-- | SendMailSendMoneyButton / SendMailCODButton 的 Normal 貼圖 | SetAlpha(0) |
-- | 同兩顆的 Checked 貼圖 | SetAlpha(1) ＋ SetColorTexture（職業色） |
-- | SendMailMoneyInset 的 Bg / NineSlice | SetAlpha(0) |
--
-- ### 讀信視窗
--
-- | 物件 | 動作 |
-- |---|---|
-- | OpenStationeryBackgroundLeft/Right | SetAlpha(0) |
-- | OpenMailBodyText | SetTextColor |
-- | OpenMailInvoice* 九條 FontString | SetTextColor |
-- | ConsortiumMailFrame 的五條 FontString ＋ CommissionPaidText | SetTextColor |
-- | ConsortiumMailFrame.CommissionPaidDisplay.Separator | SetVertexColor |
-- | 四個金錢框裡的無名 InvoiceTextFontNormal | SetTextColor |
-- | OpenMailHorizontalBarLeft ＋一張無名右半 | SetAlpha(0)（GetRegions 掃 OpenMailFrame） |
-- | OpenMailLetterButton / OpenMailMoneyButton / OpenMailAttachmentButton1..16 | 同附件格 |
--
-- ### 伴隨元件（套組內建的郵件增強插件）
--
-- **見 `ThirdParty/Postal.lua`** —— 這一份對它一行都不做。
-- 那一份用 `Engine.AddCompanion("mail", { event = "MAIL_SHOW", … })` 自己掛上來，
-- 接觸面清單也在它自己的檔頭。
--
-- hook（全部是後置勾，不換函式）：
--   * Engine 的三個 `PanelTemplates_*` 全域後置勾（分頁選中態，裝在 Core/Engine.lua）。
--   * Engine 的 `SetItemButtonQuality` / `SetItemButtonTexture` 兩個全域後置勾
--     （物品格的品質方框與裁邊，裝在 Core/Engine.lua，第一行查弱鍵表）。
--   * `hooksecurefunc("InboxFrame_Update", …)` —— 七列的重畫（Slot 的 vertex color
--     與寄件人／主旨的顏色每次都被重設）。
--   * `hooksecurefunc("OpenMail_Update", …)` —— 信紙與上面所有文字顏色的重申。
--   * `hooksecurefunc("SendMailFrame_Update", …)` —— 信紙的重申。
--
-- 寫入暴雪欄位：無。
-- 讀暴雪物件：只有 `Engine.PassBorderColor` 那一條（`IconBorder` 的
--   `IsShown()` / `GetVertexColor()`，**當傳遞者不當讀取者**，見 STYLE.md ③ 的讀取例外表）。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **`SmallMoneyFrameTemplate` / `MoneyDisplayFrameTemplate` 的金幣數字** ——
--   那是值不是裝飾，而且字色走字型物件（白／紅／綠），深底上讀得到。
-- * **`MailFrame.trialError`、`InboxTooMuchMail`、`SendMailErrorText`、
--   `SendMailFrameLockSendMail`** —— 警告與遮罩，顏色本身就是訊息。
-- * **寄件人金字／主旨白字／到期天數的綠紅** —— 資訊，`InboxFrame_Update`
--   每次都重設（.lua:253-268），我們也不該蓋。
-- * **`SendMailCODButtonText`** —— `SendMailFrame_Update` 依能不能送在金／灰之間切
--   （.lua:998,1014），那是狀態。
-- * **附件格的 `Count` 與 `IconOverlay`/`IconOverlay2`** —— 數量與特殊品質圈，都是值。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

------------------------------------------------------------
-- 物品格上的裝飾是無名的、要留的反而全部有 parentKey ⇒ 列出要留的那一邊才寫得出來。
-- （第五輪把三份配方各寫一支的 `KeepSet` 升格進 `Engine.KeepSet`。）
local ATTACHMENT_KEEP = { "icon", "Icon", "IconBorder", "IconOverlay", "IconOverlay2" }

------------------------------------------------------------
-- 舊式輸入框的美術矩形（照 XML 的錨點抄，不要量測）
--
-- 收件人框 109x25，三張切片涵蓋 x ∈ [-8, 108]、y ∈ [-2, -22]
--   ⇒ TOPLEFT(-8, -2) / BOTTOMRIGHT(109-108 = -1, 25-22 = +3)
-- 主旨框 220x20，切片涵蓋 x ∈ [-8, 229]、y ∈ [0, -20]
--   ⇒ TOPLEFT(-8, 0) / BOTTOMRIGHT(229-220 = +9, 0)
------------------------------------------------------------
-- ⚠ 收件人框的右下角**錨在自己的 TOPLEFT 上**，不是 BOTTOMRIGHT（第五輪改的）。
--
--   第四輪寫成 `BOTTOMRIGHT (-1, +3)`，也就是「跟著 EditBox 的矩形走」。
--   但這個框的**視覺**寬度不是 EditBox 的寬度 —— 三張切片是從 `TOPLEFT` 開始
--   用固定尺寸串起來的（8 ＋ 100 ＋ 8），右端帽落在 `x = 108` 這個定值上，
--   EditBox 的框再怎麼寬，暴雪畫出來的輸入框就是那 116 點。
--   實機擷圖 22 的症狀（我們的深色方塊一路伸到「郵資：30」底下、把那行字蓋在
--   方塊裡）就是跟著框跑、而不是跟著美術跑的結果。
--
--   右邊那一塊是誰：`SendMailCostMoneyFrame` 錨 `TOPRIGHT x=-50`（SendMailFrame
--   寬 384 ⇒ 右緣在 334），「郵資：」是它 BACKGROUND 層一條**無名無 parentKey**
--   的 `GameFontNormal`，錨 `RIGHT → 它自己的 LEFT x=-3` ⇒ 那條字的左緣位置
--   由**譯文長度**決定，算不出來也不該算。所以正解不是「往左讓多少」，
--   而是「不要多畫」——把矩形釘回 XML 寫死的美術範圍就不會撞到任何東西。
--
--   幾何：Left 錨 TOPLEFT(-8,-2) 8x20、Middle 100x20、Right 8x20
--   ⇒ x ∈ [-8, 108]、y ∈ [-2, -22]。
local NAME_BOX_POINTS = {
    { "TOPLEFT", "TOPLEFT", -8, -2 },
    { "BOTTOMRIGHT", "TOPLEFT", 108, -22 },
}
-- 主旨框右邊沒有東西，維持跟著框走（真的被誰加寬了，皮也跟著寬比較好看）。
local SUBJECT_BOX_POINTS = {
    { "TOPLEFT", "TOPLEFT", -8, 0 },
    { "BOTTOMRIGHT", "BOTTOMRIGHT", 9, 0 },
}

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
-- 收件匣
------------------------------------------------------------
local INBOX_ROWS = 7

------------------------------------------------------------
-- 收件匣七列：**列底只在那一列真的有信的時候才畫**
--
-- 第四輪走「隔行明暗」（奇 `fill`／偶 `fillInset`）。信箱空的時候七列的底照樣
-- 都畫著，畫面上就是三條沒有內容的暗帶浮在空白裡（實機擷圖 21）——
-- 隔行明暗的前提是「每一行都有東西」，這裡不成立。
--
-- 怎麼知道「這一列有沒有信」而**不讀任何東西**：
--   `InboxFrame_Update`（Blizzard_MailFrame/MailFrame.lua）對有信的那幾列
--   `_G["MailItem"..i.."Button"]:Show()`、對其餘 `:Hide()`
--   （`MailItemTemplate` 的 `$parentButton` 在 XML 裡本來就是 `hidden="true"`）。
--   ⇒ 把列底 overlay 的 **parent 設成那顆按鈕**（錨點仍然錨在列上）：
--     按鈕被藏起來，我們的底跟著消失，按鈕顯示出來就跟著回來。
--     零讀取、零 hook、零判斷 —— 顯示與否完全由暴雪自己那一行決定。
--
-- 列與列之間改用一條髮絲線（`fillHover`，深底上的分隔線要比底**亮**才看得見，
-- 同 `Skin.SectionTitle`）。線畫在每一列的**上緣**、**第一列不畫** ⇒ 線只會出現
-- 在兩列之間，不會在最後一列底下留一條沒有下文的收尾線
-- （feedback-ui-visual-style：「一條線只能有一個語意」）。
-- 信是由上往下填的，所以第 n 列有線的時候第 n−1 列一定也有信。
------------------------------------------------------------
local function SkinInboxRows()
    for i = 1, INBOX_ROWS do
        local key = "MailItem" .. i
        local row = _G[key]
        local btn = _G[key .. "Button"]
        if not row then
            E.Missing(key)
        else
            -- 三張美術全部**無名無 parentKey**（MailFrame.xml:15,22,29）：
            -- 兩片 `MailItemBorder` 切片（左邊那塊棕色格子 ＋ 右邊那條棕框）
            -- 與列底那條 `0.33/0.16/0 a=.3` 的線。`GetRegions` 只掃 Texture，
            -- `$parentSender` / `$parentSubject` 是 FontString ⇒ 自動排除，
            -- 不用列「要留哪些」。
            E.NeutralizeRegions(row, key)

            -- parent ＝ 信件鈕（見上）。找不到那顆按鈕就退回掛在列上 ——
            -- 那是第四輪的行為，至少不會少一塊皮。
            local ov = E.Overlay(row, { key = key, noBorder = true, parent = btn })
            E.Paint(ov, T.fill)

            if i > 1 then
                local rule = E.Overlay(row, {
                    key = key .. ".rule",
                    slot = "rule",
                    parent = btn,
                    noBorder = true,
                    height = 1,
                    points = {
                        { "TOPLEFT", "TOPLEFT", 0, 0 },
                        { "TOPRIGHT", "TOPRIGHT", 0, 0 },
                    },
                })
                E.Paint(rule, T.fillHover)
            end

            -- 信件圖示鈕：手寫的 CheckButton，欄位是 `Icon`（大寫）
            if btn then
                -- `$parentSlot`（UI-EmptySlot-White）是那張 64x64 的空格雕花。
                -- ⚠ 一定要 alpha：`InboxFrame_Update` 每次都對它
                --   `SetVertexColor(1,0.82,0)` 或 `(0.5,0.5,0.5)`（.lua:255,261），
                --   換材質或換顏色都撐不過一次更新。
                E.Neutralize(_G[key .. "ButtonSlot"], key .. "ButtonSlot")
                Skin.ItemButton(btn, key .. "Button")
                -- 已讀／未讀不歸我們管（那是資訊），但「目前打開的是哪一封」
                -- 走 CheckedTexture（.lua:297），換成職業色才看得出選中。
                E.CheckedTexture(btn,
                    { T.AccentCheck(0.45) }, { T.AccentCheckDisabled(0.45) },
                    key .. "Button")
            else
                E.Missing(key .. "Button")
            end
        end
    end
end

-- ⚠ 這一支**一定要有**，而且不能只靠 Engine 那兩個 `SetItemButton*` 全域後置勾。
--
-- 「這一列沒有附件」那條路，`InboxFrame_Update` 是**直接**
-- `button.IconBorder:Hide()`（MailFrame.lua:237），不經過 `SetItemButtonBorder`
-- ⇒ 全域後置勾一次都不會觸發，我們的品質方框會留著上一封信的顏色。
-- 所以這裡逐列重跑一次轉交（順便重裁圖示，`buttonIcon:SetTexture` 在 .lua:245）。
--
-- 其餘的不用重申：列自己那三張美術暴雪不會再碰，`$parentSlot` 被重設的是
-- **vertex color**（.lua:255,261）而不是 alpha，中和撐得住。
local function ReapplyInbox()
    for i = 1, INBOX_ROWS do
        local key = "MailItem" .. i .. "Button"
        local btn = _G[key]
        if btn then Skin.ItemButtonRefresh(btn, key) end
    end
end

local function SkinInbox()
    local inbox = _G.InboxFrame
    if not inbox then
        E.Missing("InboxFrame")
        return
    end

    -- UI-MailFrameBG：鋪滿內容區的那張大底圖
    E.NeutralizeGlobals({ "InboxFrameBg" })

    SkinInboxRows()

    -- 翻頁鈕：32x32，但 `UI-SpellbookIcon-PrevPage-Up` 的箭頭只佔中間一小塊，
    -- 框畫成整顆按鈕會比箭頭大一圈（第二輪實測的症狀）⇒ 四邊各內縮 4。
    -- 「上頁」「繼續」是按鈕自己 region 裡的**無名** FontString（:388,:413），
    -- 暴雪不會重設它們的顏色（`InboxFrame_Update` 只動 `InboxCurrentPage`），
    -- 設一次就撐得住。
    -- ⚠ 第七輪：箭頭素材整組中和，改畫自己的 ‹ › 線條圖記；到頭時暴雪對按鈕
    --   `Disable()` ⇒ 圖記跟著變暗（`trackEnabled`，見 `Engine.TrackGlyph`）。
    for i, name in ipairs({ "InboxPrevPageButton", "InboxNextPageButton" }) do
        local btn = _G[name]
        if btn then
            Skin.IconButton(btn, name, {
                inset = 4, labelColor = T.text,
                glyph = (i == 1) and "chevronLeft" or "chevronRight",
                glyphColor = T.textDim,
                trackEnabled = true,
            })
        else
            E.Missing(name)
        end
    end

    -- ⚠ **不要因為「有插件會把它藏起來」就拿掉這一行。** 套組內建的郵件增強插件
    --   會藏掉暴雪這顆、換成它自己的 `PostalOpenAllButton`（皮在
    --   `ThirdParty/Postal.lua`）—— 但玩家可能沒裝那支，兩顆各自獨立上皮，
    --   誰也不問對方在不在（伴隨元件規則第 2、3 條）。
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
local SEND_ATTACHMENTS = 16

local function SkinSendMail()
    local frame = _G.SendMailFrame
    if not frame then
        E.Missing("SendMailFrame")
        return
    end

    Skin.EditBox(_G.SendMailNameEditBox, "SendMailNameEditBox",
        { globalPrefix = true, points = NAME_BOX_POINTS })
    Skin.EditBox(_G.SendMailSubjectEditBox, "SendMailSubjectEditBox",
        { globalPrefix = true, points = SUBJECT_BOX_POINTS })

    -- ⚠ **第七輪：欄位標籤降成次要灰**（STYLE.md ④ 的「文字層級」）。
    --
    -- 「收件人：」「主旨：」「寄送金額：」「郵資：」在暴雪那邊是 `GameFontNormal`／
    -- `GameFontNormalSmall`（暗金）。深底上的暗金既不像標題也不像內文，而且它跟
    -- 右邊那一格**玩家輸入的內容**搶注意力 —— 標籤是後設資訊，該比內容弱
    -- （`miliui-menu-design` 第一條）。
    --
    -- 三條標籤各自的取法不一樣（查證自 `MailFrame.xml`，12.1 live）：
    --   * `SendMailMoneyText`（:387，`SEND_MONEY`）有全域名字 ⇒ 直接指名。
    --   * 收件人（:345，`MAIL_TO_LABEL`）與主旨（:433，`MAIL_SUBJECT_LABEL`）是
    --     **EditBox 自己那一層的 FontString**，XML 沒給全域名字 ⇒ 只能
    --     `E.RecolorRegions` 掃那一層（EditBox 自己的輸入文字不是 region，掃不到）。
    --   * 郵資（:458，`SEND_MAIL_COST`）同理，掛在 `SendMailCostMoneyFrame` 上。
    -- 全部是靜態文字：`SendMailFrame_Update` 只 `SetText` 內容欄位，不碰這三條的
    -- 顏色 ⇒ 設一次就撐得住，不必掛任何勾。
    E.TextColor(_G.SendMailMoneyText, T.textDim, "SendMailMoneyText")
    E.RecolorRegions(_G.SendMailNameEditBox, T.textDim, "SendMailNameEditBox")
    E.RecolorRegions(_G.SendMailSubjectEditBox, T.textDim, "SendMailSubjectEditBox")
    E.RecolorRegions(_G.SendMailCostMoneyFrame, T.textDim, "SendMailCostMoneyFrame")

    -- 附件區上下那兩條雕花分隔線：每條都是「一張具名左半 ＋ 一張**無名無 parentKey**
    -- 的右半」（:463/:470 與 :477/:484）。第二輪因為右半指名不到而整組放棄，
    -- 這一輪改走 `GetRegions()` 掃 `SendMailFrame` 自己那一層 ——
    -- 那一層只有這四張 Texture 加兩張錯誤提示用的（`SendMailErrorCoin` 是 Texture，
    -- 但它本來就 hidden，中和掉沒有損失；`SendMailErrorText` 是 FontString，不會被掃到）。
    E.NeutralizeRegions(frame, "SendMailFrame")

    -- 內文區：信紙中和 ＋ 文字接管（見檔頭「信紙為什麼改成深色」）
    E.NeutralizeGlobals({ "SendStationeryBackgroundLeft", "SendStationeryBackgroundRight" })
    E.TextColor(_G.SendMailBodyEditBox, T.text, "SendMailBodyEditBox")

    local scroll = _G.SendMailScrollFrame
    if scroll then
        Skin.BorderOnly(scroll, "SendMailScrollFrame")
        local bar
        if pcall(function() bar = scroll.ScrollBar end) and bar then
            Skin.ScrollBar(bar, "SendMailScrollFrame.ScrollBar")
        else
            E.Missing("SendMailScrollFrame.ScrollBar")
        end
    else
        E.Missing("SendMailScrollFrame")
    end

    for i = 1, SEND_ATTACHMENTS do
        local name = "SendMailAttachment" .. i
        local btn = _G[name]
        if btn then
            Skin.ItemButton(btn, name)
            -- 那張格子底（`UI-Slot-Background`，:177）**無名也沒有 parentKey**
            -- ⇒ 只剩 GetRegions 一條路。掃的時候要把「不是裝飾」的留下來：
            -- `icon` 是內容、`IconBorder` 已經中和過（再掃一次無害但省得重複）、
            -- 兩張 `IconOverlay` 是艾澤萊／造型那種額外的圈，是資訊。
            E.NeutralizeRegions(btn, name, E.KeepSet(btn, ATTACHMENT_KEEP))
        else
            E.Missing(name)
        end
    end

    SkinMoneyInput(_G.SendMailMoney, "SendMailMoney", "SendMailMoney")

    -- 送錢／貨到付款是 UIRadioButtonTemplate：只有 Normal / Highlight / Checked 三張。
    -- 圓鈕換成方框是刻意的（見 Skin.CheckBox 那一段）。
    -- ⚠ `boxSize = 16`：這個模板的按鈕本身就是 16x16
    --   （CheckButtonTemplates.xml:4），預設的 18 會比按鈕還大一圈 ——
    --   方框超出點擊區看起來就像對不準。
    -- ⚠ 已選的長相：`UIRadioButtonTemplate` 的 Checked 是 `UI-RadioButton` 的
    --   第二格（一顆置中的小圓點，整顆 16x16 的 TexCoord 切片）。
    --   第六輪起它跟勾選框走同一支（`Engine.CheckedGlyph`：去飽和 ＋ 染職業色）
    --   ⇒ 結果正好是「深色小方框裡一個置中的職業色圓點」，
    --   跟「單選不該是打勾」那條期待對得上，而且一行特例都不用寫。
    for _, name in ipairs({ "SendMailSendMoneyButton", "SendMailCODButton" }) do
        local btn = _G[name]
        if btn then
            Skin.CheckBox(btn, name, { boxSize = 16, radio = true })
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
    E.NeutralizeGlobals({ "SendMailMoneyBgLeft", "SendMailMoneyBgMiddle", "SendMailMoneyBgRight" })

    for _, name in ipairs({ "SendMailMailButton", "SendMailCancelButton" }) do
        local btn = _G[name]
        if btn then
            Skin.Button(btn, name)
        else
            E.Missing(name)
        end
    end
end

-- `SendMailFrame_Update`（.lua:1065-1070）每次都重設信紙的材質／TexCoord／高度。
-- alpha 跟它們是獨立的屬性 ⇒ 中和撐得住；這裡只重申「附件格有沒有新的」。
local function ReapplySendMail()
    for i = 1, SEND_ATTACHMENTS do
        local btn = _G["SendMailAttachment" .. i]
        if btn then Skin.ItemButtonRefresh(btn, "SendMailAttachment" .. i) end
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

local OPEN_MAIL_ITEM_BUTTONS = { "OpenMailLetterButton", "OpenMailMoneyButton" }
local OPEN_ATTACHMENTS = 16

-- 發票上那九條具名的 `InvoiceTextFontNormal`（深棕，為信紙設計的）
local INVOICE_FONTSTRINGS = {
    "OpenMailInvoiceItemLabel",
    "OpenMailInvoicePurchaser",
    "OpenMailInvoiceSalePrice",
    "OpenMailInvoiceDeposit",
    "OpenMailInvoiceHouseCut",
    "OpenMailInvoiceAmountReceived",
    "OpenMailInvoiceNotYetSent",
    "OpenMailInvoiceMoneyDelay",
}

-- 訂單收據（`ConsortiumMailFrame`）的五條 parentKey FontString
local CONSORTIUM_FONTSTRINGS = {
    "OpeningText", "CrafterText", "CommissionReceived", "CrafterNote", "ConsortiumNote",
}

-- 信紙上那幾個金錢框：字色本身不用動（走白／紅／綠的字型物件），但框裡
-- 藏著無名的 `+` `-` 與數量 FontString，那幾條要接管。
local INVOICE_MONEY_FRAMES = {
    "OpenMailTransactionAmountMoneyFrame",   -- MailFrame.xml:1147
    "OpenMailDepositMoneyFrame",             -- 同檔 :1158
    "OpenMailHouseCutMoneyFrame",            -- 同檔 :1178
    "OpenMailSalePriceMoneyFrame",           -- 同檔 :1198
}

-- 信紙上所有文字的接管。`OpenMail_Update` 每次都 `SetText` ⇒ 放在後置勾裡重申。
local function RecolourOpenMailContents()
    E.TextColor(_G.OpenMailBodyText, T.text, "OpenMailBodyText")

    -- 發票中間那條算式分隔線（`UI-MailFrame-InvoiceLine`，MailFrame.xml:1123）是
    -- 一張**深色**的線畫，而 `SetVertexColor` 是乘法 —— 深底上乘不出比底亮的線，
    -- 只會變成一塊看不見的暗斑。跟關閉鈕的 × 同一個坑，這裡的解法是直接中和：
    -- 那條線只是排版輔助，拿掉之後上下兩塊金額靠間距一樣分得開。
    E.Neutralize(_G.OpenMailArithmeticLine, "OpenMailArithmeticLine")

    for _, name in ipairs(INVOICE_FONTSTRINGS) do
        local fs = _G[name]
        if fs then E.TextColor(fs, T.text, name) end
    end
    for _, name in ipairs(INVOICE_MONEY_FRAMES) do
        E.RecolorRegions(_G[name], T.text, name)
    end

    local cm = _G.ConsortiumMailFrame
    if cm then
        for _, k in ipairs(CONSORTIUM_FONTSTRINGS) do
            local fs
            if pcall(function() fs = cm[k] end) and fs then
                E.TextColor(fs, T.text, "ConsortiumMailFrame." .. k)
            end
        end
        local paid
        if pcall(function() paid = cm.CommissionPaidDisplay end) and paid then
            local fs, sep
            if pcall(function() fs = paid.CommissionPaidText end) and fs then
                E.TextColor(fs, T.text, "ConsortiumMailFrame.CommissionPaidText")
            end
            -- 分隔線是 `DEFAULT_MATERIAL_TEXT_COLOR a=0.5`（深色，為信紙設計）
            -- ⇒ 深底上要比底亮才看得見，同小節標題的髮絲線
            if pcall(function() sep = paid.Separator end) and sep then
                E.VertexColor(sep, T.fillHover, "ConsortiumMailFrame.Separator")
            end
            E.RecolorRegions(paid.MoneyDisplayFrame, T.text,
                "ConsortiumMailFrame.CommissionPaidDisplay.MoneyDisplayFrame")
        end
        E.RecolorRegions(cm.CommissionReceivedDisplay, T.text,
            "ConsortiumMailFrame.CommissionReceivedDisplay")
    end
end

local function SkinOpenMail()
    local f = _G.OpenMailFrame
    if not f then
        E.Missing("OpenMailFrame")
        return
    end

    Skin.PortraitChrome(f, "OpenMailFrame")
    Skin.Panel(f, "OpenMailFrame")

    -- 那條 `UI-ClassTrainer-HorizontalBar` 分隔線（具名左半 ＋ 無名右半，:904/:911）
    E.NeutralizeRegions(f, "OpenMailFrame")

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

    -- 信紙中和 ＋ 上面所有文字接管
    E.NeutralizeGlobals({ "OpenStationeryBackgroundLeft", "OpenStationeryBackgroundRight" })
    RecolourOpenMailContents()

    local scroll = _G.OpenMailScrollFrame
    if scroll then
        Skin.BorderOnly(scroll, "OpenMailScrollFrame")
        local bar
        if pcall(function() bar = scroll.ScrollBar end) and bar then
            Skin.ScrollBar(bar, "OpenMailScrollFrame.ScrollBar")
        else
            E.Missing("OpenMailScrollFrame.ScrollBar")
        end
    else
        E.Missing("OpenMailScrollFrame")
    end

    for _, name in ipairs(OPEN_MAIL_ITEM_BUTTONS) do
        local btn = _G[name]
        if btn then
            Skin.ItemButton(btn, name)
        else
            E.Missing(name)
        end
    end
    for i = 1, OPEN_ATTACHMENTS do
        local name = "OpenMailAttachmentButton" .. i
        local btn = _G[name]
        if btn then
            Skin.ItemButton(btn, name)
        else
            E.Missing(name)
        end
    end
end

local function ReapplyOpenMail()
    RecolourOpenMailContents()
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local function InstallHooks()
    -- ⚠ 這一段**不過戰鬥閘**（Engine 的 RunUnit 在戰鬥閘之前跑它）。
    --   `hooksecurefunc` 不寫任何暴雪欄位，戰鬥中完全安全；被戰鬥閘擋的是「畫」。
    local function Hook(name, fn)
        if type(_G[name]) == "function" then
            hooksecurefunc(name, fn)
        else
            E.Missing(name)
        end
    end
    Hook("InboxFrame_Update", ReapplyInbox)
    Hook("OpenMail_Update", ReapplyOpenMail)
    Hook("SendMailFrame_Update", ReapplySendMail)
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
    -- ⚠ 走 `Skin.TabGroup`：第一顆的右緣錨在第二顆的左緣，接縫只留一條 1px 黑線
    --   （第四輪的「往右多畫 7」在收件匣那一顆右邊畫出兩條，實機擷圖 21）。
    local tabs = {}
    for i = 1, 2 do
        local key = "MailFrameTab" .. i
        local tab = _G[key]
        if tab then
            tabs[#tabs + 1] = { tab = tab, key = key }
        else
            E.Missing(key)
        end
    end
    Skin.TabGroup(tabs, { kind = "panel", joined = "TOP" })

    SkinInbox()
    SkinSendMail()
    SkinOpenMail()
end

E.Register{
    key   = "mail",
    addon = nil,                       -- Blizzard_MailFrame 的 TOC 是 DefaultState: enabled、非 LoD
    title = L["Mail"],
    hooks = InstallHooks,
    apply = Apply,
    -- ⚠ 伴隨元件（套組內建的郵件增強插件）**不寫在這裡**：它住在
    --   `ThirdParty/Postal.lua`，用 `Engine.AddCompanion("mail", …)` 自己掛上來
    --   （TOC 裡排在所有 `Skins\*.lua` 之後）。
}
