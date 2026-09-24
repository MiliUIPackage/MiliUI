------------------------------------------------------------
-- 配方：宏偉寶庫（WeeklyRewardsFrame，隨需載入 Blizzard_WeeklyRewards）
--
-- ⚠⚠ **這一份走第五輪那條特許**（STYLE.md ⑦「特許：確認彈窗與 ESC 選單」），
--   而且條件比那兩份更緊。理由：選取獎勵（`SelectActivity`）與領取獎勵
--   （`SelectReward` → 確認框 → `C_WeeklyRewards.ClaimReward`）是**受保護、
--   吃硬體事件**的路徑，一年只按一次而且按不下去就是整週的獎勵拿不到。
--   寫死的條件（合併前逐條檢查）：
--     1. **零 `HookScript`**，任何按鈕、任何框都不掛 —— 連 `OnEnter`/`OnLeave`
--        都不行。所以這一份**不呼叫 `Skin.Button` / `Skin.CloseButton`**
--        （它們第五輪起會經由 `Engine.TrackButtonHover` 掛 OnEnter/OnLeave），
--        改用本檔的 local 平面函式，只組合「中和 → `Engine.ButtonStates`
--        → `Engine.ButtonFonts` → overlay」四個不掛腳本的動作。
--     2. **零 `hooksecurefunc`**，整份 hook 數是 **0**（`hooks` 欄位不給）。
--        特別是 `WeeklyRewardsMixin:Refresh` / `:SelectActivity` / `:SelectReward`
--        與 `WeeklyRewardsActivityMixin:Refresh` 一支都不勾。
--        （就算想勾也勾不到：活動格是 `WeeklyRewardsMixin:OnLoad` 裡
--         `CreateFrame(..., "WeeklyRewardActivityTemplate")` 建的，mixin 在
--         建立那一行就被拷走了 —— 陷阱 4 的第三層。）
--     3. 不呼叫任何 `WeeklyRewards*` 的函式、不讀 `frame.type` / `.index` /
--        `.info` / `.unlocked` / `.Activities` 這些暴雪的**資料**欄位。
--        活動格一律走 `GetChildren()` ＋「有沒有這幾個 parentKey」認
--        （讀結構不是讀值，同 `Skin.TabSystemAll` 認分頁的作法）。
--     4. overlay 照舊：純貼圖、零腳本、不吃滑鼠、層級在目標之下。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source，
-- Interface/AddOns/Blizzard_WeeklyRewards/）：
--   Blizzard_WeeklyRewards.xml:567  `WeeklyRewardsFrame`（mixin WeeklyRewardsMixin，
--     parent=UIParent、toplevel、frameLevel 100、1165x657）
--     :571 `Background`（atlas evergreen-weeklyrewards-frame-back，內縮 10/8）
--     :578 `BorderShadow`（同內縮）
--     :584,589 `Divider1` / `Divider2`（atlas evergreen-weeklyrewards-divider）
--     :595 `PreviousRewardNotification`（SystemFont_Med3 ＋ HIGHLIGHT_FONT_COLOR）
--     :603 `BorderContainer`（frameLevel 1500）→ :606 `Border`
--          （atlas evergreen-weeklyrewards-frame）、:614 `TopDecor`
--     :622 `Blackout`（enableMouse、黑 a=.5，`UpdateOverlay` 開關）
--     :636 `HeaderFrame` → `Text`（SystemFont_Large ＋ HIGHLIGHT_FONT_COLOR）、
--          `HeaderDivider`（atlas evergreen-weeklyrewards-header）
--     :655,660,665,670 `RaidFrame` / `MythicFrame` / `PVPFrame` / `WorldFrame`
--          （都是 `WeeklyRewardActivityTypeTemplate`）
--     :675 `ModelScene`（ScriptAnimatedModelSceneTemplate）
--     :676 `ConcessionsFrame` → `HeaderText` ＋ `Rewards`（HorizontalLayoutFrame）
--          → `ConcessionFrame1` / `ConcessionFrame2`
--     :737 `SelectRewardButton`（**UIPanelButtonTemplate**，frameLevel 6000，
--          多一張 `Background`＝atlas evergreen-weeklyrewards-frame-selectbutton）
--     :753 `CloseButton`（UIPanelCloseButton，frameLevel 6000）
--   同檔 :45  `WeeklyRewardActivityTypeTemplate`：`Background`（分類大圖）、
--          `Border`、`Name`（Fancy24Font）
--   同檔 :73  `WeeklyRewardActivityTemplate`（mixin WeeklyRewardsActivityMixin，
--          219x126、frameLevel 200）：`Background`、`Border`、`ItemGlow`、
--          `Threshold`、`Progress`、`CompletedIcon`、`CompletedActivityFlipbook`、
--          `UncollectedGlow`、`SelectedTexture`、`RewardGenerated`、`ItemFrame`、
--          `UnselectedFrame`、`SelectionGlow`
--   同檔 :5   `WeeklyRewardActivityItemFrameTemplate`（Button，155x49）：
--          `Icon`（37x37）、**無名無 parentKey** 的 BORDER 貼圖
--          （atlas evergreen-weeklyrewards-reward-itemframe）、`Name`、`IconOverlay`
--   同檔 :496 `WeeklyRewardsConcessionTemplate`：`Background`（atlas
--          evergreen-weeklyrewards-reward-coin）、`SelectedTexture`、
--          `RewardsFrame`（HorizontalLayoutFrame）、`UnselectedFrame`
--   同檔 :448 `WeeklyRewardOverlayTemplate`（frameLevel 1250）：`Background`、
--          `Title`、`Text`、`NineSlice`、`ModelScene`、無名子框裡的 `Orb`
--   Blizzard_WeeklyRewards.lua:54  `WeeklyRewardsMixin:OnLoad`
--     → :137 `CreateFrame("FRAME", nil, self, "WeeklyRewardActivityTemplate")`
--       （**無名**，raid／dungeon／world 三排在 OnLoad 就建好）
--     :31  `SetUpConditionalActivities` —— PvP 那一排是**之後**才建的
--     :242 `UpdateOverlay` → :258 `GetOrCreateOverlay`（`self.Overlay` 延遲建立）
--     :411 `WeeklyRewardsActivityMixin:Refresh`
--       :437/:465 `Background:SetAtlas("…-reward-unlocked" / "…-reward-locked")`
--       :438-439/:466-467 `Threshold` / `Progress` 的 SetTextColor
--         （NORMAL/GREEN ↔ DISABLED）、:440/:468 `CompletedIcon:Show()/Hide()`
--     :949 `WeeklyRewardActivityItemMixin:SetDisplayedItem`
--       → `self.Icon:SetTexture(itemIcon)`（**會把 texCoord 打回 0,1,0,1**）
--
------------------------------------------------------------
-- ## 查證後跟計畫假設不一樣的四件事
--
-- 1. **九個活動格是無名的，而且不能靠 hook 找。**
--    它們在 `WeeklyRewardsMixin:OnLoad`（.lua:137）就 `CreateFrame` 好了 ——
--    那比我們的 `ADDON_LOADED` 早，mixin 後置勾追不上（陷阱 4 第三層），
--    而且它們沒有全域名字、只登記在暴雪自己的 `self.Activities` 表裡
--    （那是資料欄位，契約不准讀）。⇒ 走 `WeeklyRewardsFrame:GetChildren()`，
--    用「同時有 `Threshold`／`Progress`／`ItemFrame`／`UnselectedFrame`
--    這四個 parentKey」認。讀的是結構不是值（STYLE.md ③ 的讀取例外表）。
--
-- 2. **解鎖／未解鎖的差別是同一張貼圖換 atlas，零讀取做不到。**
--    `WeeklyRewardsActivityMixin:Refresh`（.lua:437,465）對**同一個**
--    `self.Background` 下 `SetAtlas("…-unlocked")` 或 `SetAtlas("…-locked")`
--    —— 不是兩張貼圖的 Show/Hide，所以沒有「C 端自己決定顯示與否」那條路
--    可以借（對照勾選框的 `GetCheckedTexture`）。要分出明暗就只能勾 `Refresh`，
--    而這一份的特許條件是零 hook。
--    ⇒ **九格同一個底**（`T.fillInset` ＋ 1px 黑邊）。明暗差沒有消失：
--    暴雪在同兩條分支裡把 `Threshold` / `Progress` 的字色在
--    NORMAL/GREEN ↔ DISABLED 之間切，並且 Show/Hide `CompletedIcon` 那個勾
--    —— 那兩樣我們一根手指都沒碰，所以「這格開了沒」照樣一眼看得出來。
--
-- 3. **物品圖示的裁邊撐不過一次更新，但補裁不需要 hook。**
--    `SetDisplayedItem`（.lua:955）對 `ItemFrame.Icon` 下 `SetTexture`
--    ⇒ texCoord 被打回 `0,1,0,1`（陷阱 4 的同一條）。補裁走**伴隨元件的時機**
--    （`companions` 的 `WEEKLY_REWARDS_UPDATE`，引擎收到事件後延一幀再跑），
--    不是 hook —— 延一幀正好排在暴雪那一輪 `Refresh` 後面。
--
-- 4. **分類大圖（`evergreen-weeklyrewards-category-*`）是內容不是裝飾。**
--    原本打算連它一起中和，查過之後留著：那四張是「團隊／地城／PvP／世界」
--    的識別插畫（`SetUpActivity`，.lua:128 照活動類型指定 atlas），
--    跟頭像、模型場景同一類 —— 中和掉會讓三排變成三段沒有標題的方塊。
--    依 STYLE.md ③ 的內容底材規則「預設保留」。只把 `Name` 的字改白。
--
------------------------------------------------------------
-- ## taint 接觸面清單
--
-- ### 視窗本體
--
-- | 物件 | 動作 |
-- |---|---|
-- | WeeklyRewardsFrame | `Engine.RegionBackdrop`（面板底＋1px 邊，建成它自己的貼圖） |
-- | 同上的 Background / BorderShadow | SetAlpha(0) |
-- | 同上的 Divider1 / Divider2 | SetDesaturated(true) ＋ SetVertexColor |
-- | WeeklyRewardsFrame.BorderContainer 的 Border | SetAlpha(0)（TopDecor 徽飾 2026-09-23 起保留） |
-- | WeeklyRewardsFrame.HeaderFrame.HeaderDivider | SetDesaturated(true) ＋ SetVertexColor |
-- | WeeklyRewardsFrame.CloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | 同上的 Highlight/Pushed 貼圖 | SetColorTexture（`Engine.ButtonStates`） |
-- | 同上 | `CreateFrame` 一個 overlay ＋ 兩條 CreateLine 畫的 ×（靜態） |
-- | WeeklyRewardsFrame.SelectRewardButton 的 Left/Right/Middle/Background | SetAlpha(0) |
-- | 同上的 Highlight 貼圖 | SetColorTexture |
-- | 同上 | SetNormalFontObject(GameFontHighlight) ＋ overlay |
-- | 同上 | `Engine.ShiftRoot`：BOTTOM y 3 → 20（脫戰；`db.relayout = false` 可關） |
--
-- ### 三（四）條分類標題（Raid/Mythic/PVP/World Frame）
--
-- | 物件 | 動作 |
-- |---|---|
-- | `<TypeFrame>.Border` | SetAlpha(0) |
-- | `<TypeFrame>.Name` | SetTextColor（不屬於按鈕的 FontString） |
--
-- ### 九（十二）個活動格（GetChildren 認出來的無名框）
--
-- | 物件 | 動作 |
-- |---|---|
-- | 活動格本身 | `CreateFrame` overlay（底 `fillInset` ＋ 1px 邊） |
-- | 活動格的 Background / Border | SetAlpha(0) |
-- | 活動格.ItemFrame 的無名 BORDER 貼圖 | SetAlpha(0)（GetRegions ＋ keep-set） |
-- | 活動格.ItemFrame | `CreateFrame` overlay（底 `fill` ＋ 1px 邊） |
-- | 活動格.ItemFrame | `Engine.ShiftRoot`：CENTER y −7 → −8.5（脫戰；`db.relayout = false` 可關） |
-- | 活動格.ItemFrame.Icon | SetTexCoord（apply ＋ 每次 WEEKLY_REWARDS_UPDATE 重裁） |
-- | 同上 | `CreateFrame` overlay（前景，只有 1px 黑邊） |
--
-- ### 兩個代幣格（ConcessionFrame1/2）與未開放時的覆蓋層
--
-- | 物件 | 動作 |
-- |---|---|
-- | ConcessionFrameN.Background | SetAlpha(0) |
-- | ConcessionFrameN | `CreateFrame` overlay（底 `fillInset` ＋ 1px 邊） |
-- | ConcessionFrameN | `CreateFrame` 一個只有 2px 黑邊的框，錨在 `RewardsFrame.Text` 的 LEFT（圍住內嵌的貨幣圖示） |
-- | Overlay（`WeeklyRewardOverlayTemplate`，延遲建立）的 Background / NineSlice | SetAlpha(0) |
-- | 同上 | `CreateFrame` overlay（底 `fill` ＋ 1px 邊） |
--
-- hook：**無**（`Engine.Register` 的 `hooks` 欄位不給）。
-- 事件：`companions` 的 `WEEKLY_REWARDS_UPDATE` 一支，引擎的共用事件框收，
--       延一幀之後重掃（冪等；`Engine.Overlay` 本來就只建一次）。
-- 寫入暴雪欄位：無。寫入暴雪全域：無。
--
-- 讀暴雪物件（契約的讀取例外）：
--   * `WeeklyRewardsFrame:GetChildren()` ＋ 子框有沒有那幾個 parentKey
--     —— **讀結構不是讀值**，同 `Skin.TabSystemAll` 認分頁的那一條。
--   * `GetRegions()`（ItemFrame 的無名 BORDER 貼圖）—— 同一條。
--   一個文字、尺寸、錨點都沒讀；`frame.type` / `.index` / `.info` / `.unlocked` /
--   `.Activities` 這些**資料**欄位一個都沒碰。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **`SelectRewardButton` 的點擊路徑、活動格與代幣格的 OnMouseDown/OnMouseUp**
--   —— 那是選取與領取。這一份一個腳本都沒掛，overlay 不吃滑鼠（Engine 保證）。
-- * **`Threshold` / `Progress` 的字色** —— 暴雪用 NORMAL/GREEN ↔ DISABLED 表示
--   「這格開了沒」（.lua:438,466），那是狀態不是裝飾。
-- * **`CompletedIcon`／`CompletedActivityFlipbook`／`ItemGlow`／`UncollectedGlow`／
--   `RewardGenerated`／`SelectionGlow`** —— 全部是狀態或特效。
-- * **`SelectedTexture` 與 `UnselectedFrame`**（活動格與代幣格各一組）——
--   那是「你正要拿的是哪一格」，領獎當下唯一的選取回饋。中和掉就等於把
--   資訊抹掉，比「這一塊沒換皮」嚴重得多。
-- * **`Blackout`** —— 未開放時那層黑 a=.5 的遮罩，本來就是深色，而且它是
--   `UpdateOverlay` 的狀態（.lua:251）。
-- * **`ModelScene`（視窗的與覆蓋層的兩個）與覆蓋層的 `Orb`** ——
--   STYLE.md ③「3D 模型場景不碰」。
-- * **`confirmSelectionFrame`（`WeeklyRewardConfirmSelectionTemplate`）** ——
--   那是「確定要拿這一件嗎」的確認面板，跟 `C_WeeklyRewards.ClaimReward`
--   同一條執行流（第七輪穩定性規則 (b)）。一根手指都不碰。
-- * **`WeeklyRewardExpirationWarningDialog`** —— 它的 `NineSlice.ExtraBG` 已經是
--   `BLACK_FONT_COLOR` 的 Tooltip 九宮格，本來就是深底白字，換皮沒有收益。
-- * **分類大圖 `<TypeFrame>.Background`** —— 見「查證後不一樣的第 4 件事」。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine
local T = ns.Tokens
local L = ns.L

------------------------------------------------------------
-- 本檔的 local 平面按鈕（特許條件 1：零 HookScript）
--
-- ⚠ **不用 `Skin.Button` / `Skin.CloseButton`。** 那兩支第五輪之後會經由
--   `Engine.TrackButtonHover` 掛 `HookScript("OnEnter"/"OnLeave")`，
--   跟這一份的特許條件衝突。這裡只組合四個不掛腳本的動作。
--
-- 三態：滑過交給引擎（Highlight 貼圖 → 白 8%，C 端自己顯示／隱藏）。
-- 第九輪：`opts.variant` 有給就改走 `Engine.ScriptlessButton`（同樣零腳本；
-- 「選擇獎勵」primary ⇒ Highlight 換成保護後的職業色 × 0.70，ADD）。
--
-- TODO(升格): 這一支跟 `Skins/Popup.lua` 的 `FlatButton` 是同一個形狀，只差
--   「要中和哪幾張貼圖」（那邊是 Normal/Pushed/Disabled，這邊還要加
--   `UIPanelButtonTemplate` 的 Left/Right/Middle 與 SelectRewardButton 自己那張
--   `Background`）。第三個用到的地方出現時就升格成 `Skin.Button` 的
--   `opts.noHover`，兩份配方一起改。
------------------------------------------------------------
-- 「選擇獎勵」離視窗底的距離（原值 3，見 Apply 裡的換算）
local SELECT_BUTTON_Y = 20

local FLAT_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }

-- opts:
--   keys    要中和的 parentKey 貼圖（`UIPanelButtonTemplate` 的三張切片…）
--   getters 要中和的 getter（預設 Normal/Pushed/Disabled；關閉鈕另外傳）
--   pushed  true ＝ Pushed 換成黑 18%（**不中和它**，二選一，註 ⓔ）
--   glyph   靜態圖記（關閉鈕的 ×）
--   inset   overlay 四邊內縮
--   font    換 NormalFontObject
--   variant 第九輪：`"primary"`／`"secondary"`，走 `Engine.ScriptlessButton`（零腳本）；
--           不給＝舊行為（關閉鈕走這條）
local function FlatButton(btn, key, opts)
    if not E.Usable(btn, key) then return nil end
    opts = opts or {}

    -- ⚠ **先建 overlay 再中和**（同 `Skins/Popup.lua` 的理由）：`Engine.Overlay`
    --   對顯式保護的框會回 nil，倒過來寫的話那顆按鈕會變成「美術被中和掉、
    --   又沒有東西補」的一顆隱形按鈕。寶庫這兩顆一顆是關閉、一顆是領獎。
    local ov = E.Overlay(btn, { key = key, inset = opts.inset, glyph = opts.glyph })
    if not ov then return nil end

    if opts.keys then E.NeutralizeKeys(btn, opts.keys, key) end

    for _, getter in ipairs(opts.getters or FLAT_GETTERS) do
        if type(btn[getter]) == "function" then
            local ok, tex = pcall(btn[getter], btn)
            if ok and tex then E.Neutralize(tex, key .. "." .. getter) end
        end
    end
    if opts.font then E.ButtonFonts(btn, opts.font, key) end

    if opts.variant then
        E.ScriptlessButton(btn, ov, opts.variant, key, { pushed = opts.pushed })
        return ov
    end

    E.ButtonStates(btn, key, opts.pushed)
    E.Paint(ov, T.fill, T.border)
    return ov
end

-- 關閉鈕：Normal/Disabled 中和、Pushed 留著換成黑 18%（`UIPanelCloseButton`
-- 三張狀態圖都是模板寫死的 atlas，暴雪不在執行期重設 —— 同 `Skin.CloseButton`
-- 的查證結果）。× 是 overlay 上兩條 `CreateLine()`（註 ⓖ）。
local CLOSE_GLYPH = { kind = "cross", size = 9, thickness = 1 }
local CLOSE_GETTERS = { "GetNormalTexture", "GetDisabledTexture" }

------------------------------------------------------------
-- 一條分類標題（`WeeklyRewardActivityTypeTemplate`）
--
-- `Background` 是分類插畫，留著（檔頭第 4 件事）。`Border` 在 XML 裡沒有指定
-- atlas、Lua 也沒有人設它，中和是保險用的。`Name` 是 Fancy24Font 的暗金花體，
-- 改成白字 —— 它不屬於任何按鈕，而且暴雪只在 `SetUpActivity` 裡 `SetText`
-- （.lua:126），不重設顏色 ⇒ 設一次就撐得住。
------------------------------------------------------------
local TYPE_FRAME_KEYS = { "RaidFrame", "MythicFrame", "PVPFrame", "WorldFrame" }

local function SkinTypeFrame(parent, key)
    local f
    if not (pcall(function() f = parent[key] end) and f) then
        E.Missing("WeeklyRewardsFrame." .. key)
        return
    end
    local label = "WeeklyRewardsFrame." .. key
    E.NeutralizeKeys(f, { "Border" }, label)

    local fs
    if pcall(function() fs = f.Name end) and fs then
        E.TextColor(fs, T.text, label .. ".Name")
    else
        E.Missing(label .. ".Name")
    end
end

------------------------------------------------------------
-- 活動格裡的物品牌（`WeeklyRewardActivityItemFrameTemplate`）
--
-- 那張 `evergreen-weeklyrewards-reward-itemframe` 的框是**無名也沒有 parentKey**
-- 的（.xml:17）⇒ 只剩 `GetRegions()` 一條路，所以改成「列出要留的」
-- （`Engine.KeepSet`，同商人的翻頁鈕）。
--
-- ⚠ keep-set 要把 `Icon`／`Name`／`IconOverlay` 全列進去，漏一個就被一起中和掉；
--   `IconOverlay` 是 `SetItemButtonOverlay`（.lua:955）畫的「戰隊綁定」那一圈，
--   是資訊不是裝飾。
local ITEM_KEEP_KEYS = { "Icon", "Name", "IconOverlay" }
local ITEM_CARD_POINTS = {
    { "TOPLEFT", "TOPLEFT", -1, 0 },
    { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 4 },
}
-- 物品牌整塊往下挪 1.5：原位（`CENTER x=2 y=-7`，.xml:255-258）牌子上緣貼著兩行的
-- 門檻文字（`Threshold`，TOPLEFT y=-16）；下方離物品等級（`Progress`，BOTTOMRIGHT
-- y=15）還有餘裕 ⇒ 挪過去之後上下的空隙差不多。暴雪 Lua 對 ItemFrame 只有
-- Show/Hide/SetRewards，零處重設或讀回位置（grep 過）。
local ITEM_FRAME_X, ITEM_FRAME_Y = 2, -8.5

local function SkinItemFrame(cell, key)
    local item
    if not (pcall(function() item = cell.ItemFrame end) and item) then
        E.Missing(key .. ".ItemFrame")
        return nil
    end
    local label = key .. ".ItemFrame"

    -- 先建 overlay 再中和（同 FlatButton 的理由）
    -- 牌子圍著圖示留一樣的邊（2026-09-24）：圖示 37x37 錨 `LEFT x=3 y=2`（.xml:9-12），
    -- 在 155x49 的框裡是左 3、上 4、下 8 —— 直接 SetAllPoints 就是「上下沒置中、
    -- 左邊太貼」。牌子往左推 1、下緣收 4 ⇒ 圖示三邊各 4（上緣不再往上推，
    -- 讓出跟門檻文字之間的空隙）。
    local ov = E.Overlay(item, {
        key = label,
        points = ITEM_CARD_POINTS,
    })
    if ov then
        E.NeutralizeRegions(item, label, E.KeepSet(item, ITEM_KEEP_KEYS, FLAT_GETTERS))
        E.ButtonStates(item, label)
        -- 物品牌比格子亮一階（面板 fill → 內嵌 fillInset → 這一片又回到 fill），
        -- 讀起來是「凹槽裡放了一張牌」。
        E.Paint(ov, T.fill, T.border)
    end

    E.ShiftRoot(item, "CENTER", cell, "CENTER", ITEM_FRAME_X, ITEM_FRAME_Y, label)

    local icon
    if pcall(function() icon = item.Icon end) and icon then
        Skin.Icon(icon, label .. ".Icon")
    else
        E.Missing(label .. ".Icon")
    end
    return item
end

-- 補裁圖示（`SetDisplayedItem` 的 `SetTexture` 會把 texCoord 打回去，
-- 檔頭第 3 件事）。走伴隨元件的時機，不是 hook。
local function RecropItemIcon(cell)
    local icon
    if pcall(function() icon = cell.ItemFrame and cell.ItemFrame.Icon end) and icon then
        E.CropIcon(icon, "WeeklyRewardsActivity.ItemFrame.Icon")
    end
end

------------------------------------------------------------
-- 認出一個活動格
--
-- 無名、沒有全域名字、只登記在暴雪自己的 `self.Activities` 裡（那是資料欄位）。
-- ⇒ 走 `GetChildren()`，用「同時有這四個 parentKey」認。
-- 讀的是**結構**不是值（STYLE.md ③ 的讀取例外表，同 `Skin.TabSystemAll`）。
--
-- ⚠ 四個一起查是有理由的：`ConcessionFrame1/2` 也有 `UnselectedFrame`、
--   視窗本身的 `HeaderFrame` 也是 Frame —— 只查一個會認錯。
--   `Threshold` ＋ `Progress` ＋ `ItemFrame` 三個湊在一起只有活動格有。
------------------------------------------------------------
local ACTIVITY_MARKERS = { "Threshold", "Progress", "ItemFrame", "UnselectedFrame" }

local function IsActivityCell(child)
    if type(child) ~= "table" then return false end
    for _, marker in ipairs(ACTIVITY_MARKERS) do
        local v
        if not (pcall(function() v = child[marker] end) and type(v) == "table") then
            return false
        end
    end
    return true
end

-- 認出未開放時的覆蓋層（`WeeklyRewardOverlayTemplate`，`GetOrCreateOverlay`
-- 延遲建立，.lua:263）。同樣用 parentKey 組合認，不讀 `frame.Overlay` 欄位。
local OVERLAY_MARKERS = { "Background", "Title", "Text", "NineSlice", "ModelScene" }

local function IsRewardOverlay(child)
    if type(child) ~= "table" then return false end
    for _, marker in ipairs(OVERLAY_MARKERS) do
        local v
        if not (pcall(function() v = child[marker] end) and type(v) == "table") then
            return false
        end
    end
    return true
end

------------------------------------------------------------
-- 掃一遍視窗的子框
--
-- 冪等：`Engine.Overlay` 同一個 target 只建一次，重掃只會重跑幾次
-- `SetAlpha(0)` 與 `SetTexCoord`。三個時機都走這一支：
--   * `apply`（ADDON_LOADED，raid／dungeon／world 三排已經在 OnLoad 建好了）
--   * `WEEKLY_REWARDS_UPDATE`（PvP 那一排是 `SetUpConditionalActivities` 才建的，
--     覆蓋層是第一次要顯示才建的，圖示的裁邊也要在這裡補）
------------------------------------------------------------
local cells = {}       -- 弱鍵表，記「這一格處理過了」；**不寫暴雪欄位**
setmetatable(cells, { __mode = "k" })

local function ScanChildren(frame)
    local ok, kids = pcall(function() return { frame:GetChildren() } end)
    if not ok then return end

    local n = 0
    for _, child in ipairs(kids) do
        if IsActivityCell(child) then
            n = n + 1
            local key = "WeeklyRewardsActivity" .. n
            if not cells[child] then
                cells[child] = true
                local ov = E.Overlay(child, { key = key })
                if ov then
                    E.NeutralizeKeys(child, { "Background", "Border" }, key)
                    E.Paint(ov, T.fillInset, T.border)
                end
                SkinItemFrame(child, key)
            end
            RecropItemIcon(child)
        elseif IsRewardOverlay(child) and not cells[child] then
            cells[child] = true
            local key = "WeeklyRewardsFrame.Overlay"
            local ov = E.Overlay(child, { key = key })
            if ov then
                E.NeutralizeKeys(child, { "Background", "NineSlice" }, key)
                E.Paint(ov, T.fill, T.border)
            end
        end
    end
end

------------------------------------------------------------
-- 兩個代幣格（「或者：拿一些貨幣」）
--
-- ⚠ 第七輪穩定性規則 (b) 講的是「跟受保護請求同一條執行流的**清單列**」。
--   這兩格不是池化列，而且我們對它做的事跟對活動格完全一樣：中和一張貼圖、
--   掛一個不吃滑鼠的子框。**選取狀態那兩樣（`SelectedTexture`／`UnselectedFrame`）
--   一根手指都沒碰**，所以領獎當下的回饋是暴雪自己的。
-- ⚠ overlay 的 parent 交給 `Engine.SafeParent`：代幣格本身不是 layout host，
--   但它的父框 `Rewards` 是 `HorizontalLayoutFrame` ——
--   overlay 是代幣格的子框、不是 `Rewards` 的子框，不會被算進版面（陷阱 2）。
------------------------------------------------------------
local CONCESSION_KEYS = { "ConcessionFrame1", "ConcessionFrame2" }

-- 貨幣圖示的黑框（2026-09-24）
--
-- 圖示不是貼圖，是 `RewardsFrame.Text` 字串裡的內嵌材質：
-- `WEEKLY_REWARDS_CONCESSION_FORMAT` ＝ `|T%1$d:24:24:0:-2|t x %2$d`（GlobalStrings，
-- 各語系同一條）⇒ 永遠排在 Text 的最左邊、24x24、往下 2。
-- ⇒ 框錨在 Text 的 LEFT 上畫一個 24x24，**不讀字串、不改字串**。
--   裁邊做不到（要改 `|T` 的 texCoord 就得重寫暴雪的字），所以只加框。
-- ⚠ 層級：`RewardsFrame` 是 frameLevel 1000 的絕對值，代幣格自己的層級比它低 ⇒
--   target 給 `RewardsFrame`（levelOffset +1 蓋在字上），parent 仍然是代幣格 ——
--   `RewardsFrame` 是 `HorizontalLayoutFrame`，掛成它的子框會被算進版面（陷阱 2）。
local CONCESSION_ICON = 24
local CONCESSION_ICON_DY = -2
local CONCESSION_ICON_DEBUG = { 1, 0.9, 0, 1 }   -- 暫時：亮黃對位框

local function ConcessionIconBorder(cf, label)
    local rf, text
    if not (pcall(function() rf = cf.RewardsFrame; text = rf and rf.Text end) and text) then
        E.Missing(label .. ".RewardsFrame.Text")
        return
    end
    local half = CONCESSION_ICON / 2
    local ov = E.Overlay(rf, {
        key = label .. ".iconBorder",
        parent = cf,
        anchorTo = text,
        levelOffset = 1,
        -- 2px：內嵌材質的像素對齊跟我們的框不一定落在同一格，1px 會露出圖示的毛邊
        --（2026-09-24 實機看到錯開），加厚一格把那一圈蓋掉。
        borderSize = 2,
        points = {
            { "TOPLEFT", "LEFT", 0, half + CONCESSION_ICON_DY },
            { "BOTTOMRIGHT", "LEFT", CONCESSION_ICON, -half + CONCESSION_ICON_DY },
        },
    })
    -- ⚠ 暫時亮黃（2026-09-24 對位用）：尺寸對不上，先讓框看得清楚再調 CONCESSION_ICON／_DY，
    --   對好之後改回 T.border。
    E.Paint(ov, { 0, 0, 0, 0 }, CONCESSION_ICON_DEBUG)
end

local function SkinConcessions(frame)
    local rewards
    if not (pcall(function() rewards = frame.ConcessionsFrame and frame.ConcessionsFrame.Rewards end)
        and rewards) then
        E.Missing("WeeklyRewardsFrame.ConcessionsFrame.Rewards")
        return
    end

    for _, key in ipairs(CONCESSION_KEYS) do
        local cf
        local label = "WeeklyRewardsFrame.ConcessionsFrame." .. key
        if pcall(function() cf = rewards[key] end) and cf then
            local ov = E.Overlay(cf, { key = label })
            if ov then
                E.NeutralizeKeys(cf, { "Background" }, label)
                E.Paint(ov, T.fillInset, T.border)
            end
            ConcessionIconBorder(cf, label)
        else
            E.Missing(label)
        end
    end
end

------------------------------------------------------------
-- 兩條分隔線與標題底下那一條
--
-- 那三張是暴雪的金色花邊（`evergreen-weeklyrewards-divider` /
-- `…-header`）。中和掉的話三排活動就黏成一片，所以留著幾何、只換顏色：
-- 先 `SetDesaturated(true)` 壓成灰階（`SetVertexColor` 是乘法，不壓就乘不出
-- 中性灰，同 `Engine.Desaturate` 的註解），再乘上 `fillHover` ——
-- 深底上的分隔線要比底**亮**才看得見（同 `Skin.SectionTitle` 的髮絲線）。
------------------------------------------------------------
local function DimRule(tex, label)
    if not E.Usable(tex, label) then return end
    E.Desaturate(tex, label)
    E.VertexColor(tex, T.fillHover, label)
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local function Apply()
    local f = _G.WeeklyRewardsFrame
    if not f then
        E.Missing("WeeklyRewardsFrame")
        return
    end

    -- 面板底與 1px 邊。`Skin.Panel` 預設走 `Engine.RegionBackdrop`
    -- （建成 WeeklyRewardsFrame 自己的 BACKGROUND 貼圖）⇒ 不必跟
    -- frameLevel 1500 的 `BorderContainer`、6000 的兩顆按鈕搶層級。
    Skin.Panel(f, "WeeklyRewardsFrame")

    E.NeutralizeKeys(f, { "Background", "BorderShadow" }, "WeeklyRewardsFrame")

    local border
    if pcall(function() border = f.BorderContainer end) and border then
        -- 2026-09-23 使用者要求：上緣正中央的寶庫徽飾（`TopDecor`，atlas
        -- evergreen-weeklyrewards-frame-topdecor 229x103，錨 TOP y=-16，OVERLAY 5）留著看效果 ——
        -- 它是這個視窗的識別，跟冒險指南的首領圖同一類。只中和雕花外框 `Border`。
        -- 要拿掉就把 "TopDecor" 加回這張表。
        E.NeutralizeKeys(border, { "Border" }, "WeeklyRewardsFrame.BorderContainer")
    else
        E.Missing("WeeklyRewardsFrame.BorderContainer")
    end

    for _, key in ipairs({ "Divider1", "Divider2" }) do
        local tex
        if pcall(function() tex = f[key] end) and tex then
            DimRule(tex, "WeeklyRewardsFrame." .. key)
        else
            E.Missing("WeeklyRewardsFrame." .. key)
        end
    end

    local header
    if pcall(function() header = f.HeaderFrame end) and header then
        local tex
        if pcall(function() tex = header.HeaderDivider end) and tex then
            DimRule(tex, "WeeklyRewardsFrame.HeaderFrame.HeaderDivider")
        else
            E.Missing("WeeklyRewardsFrame.HeaderFrame.HeaderDivider")
        end
    else
        E.Missing("WeeklyRewardsFrame.HeaderFrame")
    end

    -- 關閉鈕與「選擇獎勵」。兩顆都走本檔的 local 平面函式（零 HookScript）。
    local close
    if pcall(function() close = f.CloseButton end) and close then
        FlatButton(close, "WeeklyRewardsFrame.CloseButton", {
            inset   = 2,
            glyph   = CLOSE_GLYPH,
            getters = CLOSE_GETTERS,
            pushed  = true,
        })
    else
        E.Missing("WeeklyRewardsFrame.CloseButton")
    end

    local selectBtn
    if pcall(function() selectBtn = f.SelectRewardButton end) and selectBtn then
        -- `UIPanelButtonTemplate` 的三張切片 ＋ 它自己多的那張 `Background`
        -- （atlas evergreen-weeklyrewards-frame-selectbutton，.xml:743）。
        -- ⚠ 一定要 alpha：`UIPanelButton_OnShow`/`_OnMouseDown`… 每次都
        --   `SetTexture` 回去（同 `Skin.Button` 的查證）。
        -- 第九輪：視窗唯一的動作 ⇒ primary。它是 `UIPanelButtonTemplate`（沒有
        -- DisabledTexture）⇒ `ScriptlessButton` 只給得了「滑過＝職業色」，平時維持
        -- `fill` ＋ 黑邊（沒選獎勵之前它是停用的，不能畫得像能按）。
        FlatButton(selectBtn, "WeeklyRewardsFrame.SelectRewardButton", {
            keys = { "Left", "Right", "Middle", "Background" },
            font = GameFontHighlight,
            variant = "primary",
        })
        -- 按鈕往上抬到「代幣列底 ↔ 視窗底」的正中間（2026-09-24）。原值 `BOTTOM x=0 y=3`
        -- （.xml:731），貼著視窗底、上面空一大截；換皮後沒有底座美術撐著就顯得歪。
        -- 代幣列的可見底離視窗底約 62、按鈕高 23 ⇒ 上下各留 ~20。
        -- 暴雪 Lua 對這顆只有 SetShown／SetEnabled（.lua:193,293），零處重設或讀回位置；
        -- 視窗高度 657／737 兩種（.lua:223,225）都是從底往上量，同一個值兩邊都對。
        E.ShiftRoot(selectBtn, "BOTTOM", f, "BOTTOM", 0, SELECT_BUTTON_Y,
            "WeeklyRewardsFrame.SelectRewardButton")
    else
        E.Missing("WeeklyRewardsFrame.SelectRewardButton")
    end

    for _, key in ipairs(TYPE_FRAME_KEYS) do
        SkinTypeFrame(f, key)
    end

    SkinConcessions(f)
    ScanChildren(f)
end

-- 伴隨元件的時機（延一幀、冪等、過戰鬥閘）。三件事：PvP 那一排活動格、
-- 未開放時的覆蓋層、物品圖示的補裁。詳見 `ScanChildren` 的註解。
local function Rescan()
    local f = _G.WeeklyRewardsFrame
    if not f then return end
    ScanChildren(f)
end

E.Register{
    key   = "weeklyrewards",
    addon = "Blizzard_WeeklyRewards",
    title = L["Great Vault"],
    -- ⚠ `hooks` 刻意不給：這一份的 hook 數是 **0**（特許條件 2）。
    apply = Apply,
    companions = {
        { event = "WEEKLY_REWARDS_UPDATE", apply = Rescan },
    },
}
