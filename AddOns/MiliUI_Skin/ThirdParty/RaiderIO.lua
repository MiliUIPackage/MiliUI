------------------------------------------------------------
-- 伴隨元件：套組內建的傳奇鑰石檔案插件自己建的兩顆 tooltip
--
-- ## 掛了哪些元件
--
-- | 全域名稱 | 是什麼 | 模板 | 建立時機 |
-- |---|---|---|---|
-- | `RaiderIO_ProfileTooltip` | 掛在搜尋器旁邊的玩家檔案提示 | `GameTooltipTemplate` | 它自己第一次要用到時 |
-- | `RaiderIO_SearchTooltip` | 它的搜尋視窗的結果提示 | `GameTooltipTemplate` | 同上 |
--
-- 這兩顆不是暴雪的 `GameTooltip`，是它自己
-- `CreateFrame("GameTooltip", …, "GameTooltipTemplate")` 出來的專用框 ⇒ 沒有人替它們
-- 換皮的話就是暴雪原樣（圓角邊框、深藍半透明底），跟已經換過皮的搜尋器視窗、
-- 以及套組其他提示框擺在一起很突兀。
--
-- ## 這一份**沒有 host**
--
-- 它不長在任何一個暴雪視窗上（`RaiderIO_SearchTooltip` 的 parent 甚至是 `UIParent`）
-- ⇒ `Engine.AddCompanion(nil, …)`：沒有視窗開關可以掛，只看總開關與
-- 設定頁「其他插件」那一節的 `raiderio`。
--
-- ## 觸發時機與理由
--
-- `atLogin` ＋ 登入後 **0／2／10 秒**各找一次（0 ＝ `atLogin` 那一輪本身，
-- 引擎已經延一幀）。理由：這兩顆什麼時候建**不一定**（一顆在它的模組載入時、
-- 一顆要等玩家第一次開搜尋視窗），沒有一個事件擺在對的時間點上。
-- 三次都沒找到就不再找 —— 不為了別人的 tooltip 留一個常駐 ticker。
--
-- ⚠ 兩顆各自獨立：找到一顆就接一顆，另一顆繼續等。
--
------------------------------------------------------------
-- ## 兩條路：有提示插件就委派，沒有才自己畫
--
-- **首選 `MiliUITip_API.Adopt(tip)`**（`MiliUI_Tooltip/Api.lua`）。
-- 那是內建 tooltip 走的同一條接管管線，所以外觀與玩家**自己的提示框設定**
-- 完全一致（底色、邊色、邊寬、縮放、頂部遮罩都跟著他調的走）。
-- 回 false ＝ 那支插件還沒初始化完 ⇒ 這一輪不算接到，留給下一次重試。
--
-- **退回路徑**（玩家沒裝 `MiliUI_Tooltip`）：自己畫一層**提示皮**。
-- ⚠ 是提示皮不是設定視窗皮：照 STYLE.md ① 的兩個問題判 —— 它浮在世界上方、
--   彈出來讀一眼 ⇒ 底 `T.tipFill`（0.133 不透明）＋ 1px **職業色**邊。
--   數值出處見 `.claude/notes/project-miliui-hud-skin.md` 的「提示皮」那一節。
--
-- ### 退回路徑的三個查證
--
-- 1. **`CreateTexture` 在它身上沒問題。** `GameTooltipTemplate`
--    （Blizzard_GameTooltip/Mainline/GameTooltip.xml，繼承 `SharedTooltipTemplate`
--    ＋ `GameTooltipDataMixin`）**不是 layout host**：`GameTooltip` 這個 UI 物件
--    沒有 `Layout` / `MarkDirty` / `GetLayoutChildren` / `GetScrollTarget` / `GetView`
--    （warcraft.wiki.gg `UIOBJECT_GameTooltip` 的方法表），tooltip 的排版整個在 C 端。
--    ⇒ `Engine.RegionBackdrop` 會走 region 那條路，底與邊是**這顆 tooltip 自己的
--    region**，顯示／隱藏、位置、尺寸全部自動跟著它，一個腳本都不用掛。
--    ⚠ 但這件事萬一哪天變了，`Engine.RegionBackdrop` 會退回子框那條路，而
--      `SafeParent` 會爬到 tooltip **外面** ⇒ 提示藏起來了我們的底還留在畫面上。
--      所以下面先自己問一次 `E.IsLayoutHost`，是的話整個不畫（靜默）。
--
-- 2. **NineSlice 的 alpha 不用重申。** 中和用的是 `SetAlpha`，跟材質／atlas／
--    backdrop style 是互相獨立的屬性（`Engine.Neutralize` 那一段），只有明確的
--    `SetAlpha` 會把它打回來 —— 而那支插件的 `core.lua` 從頭到尾沒有碰過這兩顆的
--    `NineSlice`（它對自己的搜尋**視窗**用 `SetBackdrop`，那是另一個框）。
--    ⚠ 對照組：`MiliUI_Tooltip/Core/Skin.lua` 確實有重申（`Skin.Attach` 建的
--      skin 子框的 `OnShow` 裡），但那是搭著 `LowerSkinLevel`（層級真的會變）
--      一起做的順手動作，掛的也是**它自己的框**的腳本。這裡沒有那樣一個框可以掛：
--      overlay 是純貼圖零腳本（陷阱 1），而 hook 第三方的框是伴隨元件規則明文禁止。
--    ⚠ 真的需要重申也還有一條不花成本的路：`atLogin` 的伴隨元件在戰鬥中被延後時
--      會由引擎在 `PLAYER_REGEN_ENABLED` 補跑一次，而這一份的每一步都是冪等的。
--
-- 3. **兩顆都只有純文字行**，不會經過 `TooltipDataProcessor` 的單位／物品後處理
--    ⇒ 不管走哪一條路，接管之後只有外觀變，內容一個字都不動。
--
------------------------------------------------------------
-- ## taint 接觸面清單（伴隨元件）
--
-- ⚠ 這一份**一個暴雪物件都沒有碰**。
--
-- | 物件 | 動作 |
-- |---|---|
-- | 兩顆 tooltip | `MiliUITip_API.Adopt`（有提示插件時）—— 動作記在那一支的接觸面清單 |
-- | 兩顆 tooltip 的 `NineSlice` | `SetAlpha(0)`（退回路徑） |
-- | 兩顆 tooltip 自己 | `CreateTexture`（底 ＋ 四條邊，經由 `Engine.RegionBackdrop`；退回路徑） |
--
-- hook：**零**。沒有 `hooksecurefunc`、沒有 `HookScript`、沒有 `SetScript`，
--   也沒有呼叫那支插件的任何函式。
-- 寫入它的欄位：無（「這顆接過了嗎」記在這一份自己的弱鍵表裡）。
-- 讀它的物件：只有 `_G[名字]` 在不在，以及 `tip.NineSlice` 這個 parentKey
--   —— 讀**結構**不是讀值。
--
-- ## 刻意不碰的東西
--
-- * **`RaiderIO_SearchFrame`（它的搜尋視窗本體）** —— 那是它自己用
--   `BackdropTemplate` ＋ 自己的 backdrop 畫的框，我們的底會壓在它的 backdrop
--   之下、畫了也看不見；要讓它看得見就得動它的腳本（伴隨元件規則明文禁止）。
--   同 `Skins/AuctionHouse.lua` 那顆「僅限當前資料片」按鈕的理由。
-- * **tooltip 裡的文字顏色** —— 那是它的資料（分數的顏色就是分數的意思）。
-- * **`GameTooltipTemplate` 自帶的 `StatusBar`** —— 這兩顆不是單位提示，
--   引擎不會把它顯示出來；沒有症狀就不多碰一個物件。
------------------------------------------------------------
local _, ns = ...

local E = ns.Engine
local T = ns.Tokens

------------------------------------------------------------
-- ⚠ 一律 `_G[...]` 判斷，**找不到就靜默跳過**，不走 `E.Missing`
--   （STYLE.md ③ 第 2 條：玩家沒裝那支插件不是暴雪改版事故）。
------------------------------------------------------------
local TIP_NAMES = {
    "RaiderIO_ProfileTooltip",
    "RaiderIO_SearchTooltip",
}

-- 哪幾顆已經處理好了。**弱鍵**，而且是我們自己的表 —— 第三方的框上零欄位寫入。
local done = setmetatable({}, { __mode = "k" })

------------------------------------------------------------
-- 退回路徑：自己畫一層提示皮（見檔頭「退回路徑的三個查證」）
------------------------------------------------------------
local function PaintTipSkin(tip, key)
    -- 查證 1 的保險絲：是 layout host 就整個不畫，不要做出一塊「提示藏起來了
    -- 還留在畫面上」的方塊。
    if E.IsLayoutHost(tip) then return false end

    -- ⚠ 先確認 parentKey 在，再呼叫 `E.Neutralize` —— 那一支對 nil 會寫進
    --   「找不到的區域」，而伴隨元件不准進那張清單（規則第 2 條）。
    local nine
    if pcall(function() nine = tip.NineSlice end) and nine then
        E.Neutralize(nine, key .. ".NineSlice")
    end

    local ov = E.RegionBackdrop(tip, { key = key })
    if not ov then return false end
    -- 底 0.133 不透明 ＋ 1px 職業色邊（提示皮；強調色的唯一來源是 `T.Accent`）
    E.Paint(ov, T.tipFill, { T.Accent() })
    return true
end

------------------------------------------------------------
-- 一顆 tooltip：有提示插件就委派，沒有才自己畫
------------------------------------------------------------
local function AdoptOne(tip, key)
    -- ⚠ 有 `MiliUITip_API` 就**一律**委派，即使它這次回 false（還沒初始化完）。
    --   那代表玩家有裝提示插件 ⇒ 外觀該跟他自己的提示框設定一致，
    --   不能因為早了一拍就退回我們自己畫的那一層。留著下一輪重試。
    if MiliUITip_API and type(MiliUITip_API.Adopt) == "function" then
        return MiliUITip_API.Adopt(tip) and true or false
    end
    return PaintTipSkin(tip, key)
end

-- 回傳「還有沒有沒處理到的」
local function Sweep()
    local pending = false
    for _, name in ipairs(TIP_NAMES) do
        local tip = _G[name]
        if not tip then
            pending = true
        elseif not done[tip] then
            if AdoptOne(tip, name) then
                done[tip] = true
            else
                pending = true
            end
        end
    end
    return pending
end

------------------------------------------------------------
-- 進入點
--
-- 第一次由引擎的伴隨元件輪跑（`atLogin` ＝ 配方全部套完之後、延一幀），
-- 之後 2 秒與 10 秒各補一次。`scheduled` 擋重複排程 —— `atLogin` 在戰鬥中被延後時
-- 引擎會在 `PLAYER_REGEN_ENABLED` 再跑一次這一支。
------------------------------------------------------------
local RETRY_DELAYS = { 2, 10 }
local scheduled = false

local function Apply()
    local pending = Sweep()
    if scheduled then return end
    scheduled = true
    if not pending then return end
    for _, delay in ipairs(RETRY_DELAYS) do
        C_Timer.After(delay, function()
            -- 補掃跑在 timer 堆疊裡、不在引擎的 xpcall 底下 ⇒ 自己包一層，
            -- 錯誤照樣進 `ns.errors` 與 BugSack。
            xpcall(Sweep, ns.ReportError)
        end)
    end
end

-- host ＝ nil：這兩顆不長在任何暴雪視窗上（見檔頭）。
E.AddCompanion(nil, {
    atLogin  = true,
    addonKey = "raiderio",
    apply    = Apply,
})
