------------------------------------------------------------
-- 伴隨元件：套組內建的外觀預覽插件自己建的模型預覽框
--
-- ## 掛了哪些元件
--
-- | 全域名稱 | 是什麼 | 模板 | 建立時機 |
-- |---|---|---|---|
-- | `AppearanceTooltipTooltip` | 滑過可塑形物品時顯示在提示旁邊的模型預覽 | `TooltipBorderedFrameTemplate` | 它的 `addon.lua` **檔案層**（不是隨需載入） |
--
-- 它是 `CreateFrame("Frame", …, UIParent, "TooltipBorderedFrameTemplate")`、strata
-- `TOOLTIP`、280x380。模板繼承 `TooltipBackdropTemplate`：底與圓角邊框全部在
-- `NineSlice` 這個子框上（`useParentLevel`，跟本體同一層）。沒人替它換皮的話就是暴雪
-- 原樣（圓角邊框、0.8 半透明藍黑底），擺在已經換成提示皮的滑鼠提示旁邊很突兀。
--
-- 每次顯示它會 `SetParent(那顆提示)`（`GameTooltip` 或它的內嵌物品提示），位置由它
-- 自己的 positioner 每幀錨在提示（或比價框）旁邊；**它從不 `SetScale` 自己**
-- （那段程式在它的原始碼裡是註解掉的）⇒ 它的有效縮放就是那顆提示的。
--
-- ## 這一份**沒有 host**
--
-- 它不長在任何一個暴雪視窗上 ⇒ `Engine.AddCompanion(nil, …)`：只看總開關與
-- 設定頁「其他插件」那一節的 `appearancetooltip`。
--
-- ## 觸發時機與理由
--
-- `atLogin`：框在它的檔案層就建好了，`Engine.Boot` 之後那一幀一定找得到。
-- 唯一會晚的是委派那一邊（提示插件 `ADDON_LOADED` 之前 `Adopt` 回 false），
-- 實際上它的 `ADDON_LOADED` 一定排在 `PLAYER_LOGIN` 之前 —— 保險起見 2 秒後補一次，
-- 之後就不再找。
--
------------------------------------------------------------
-- ## 兩條路：有提示插件就委派，沒有才自己畫
--
-- 跟 `ThirdParty/RaiderIO.lua` 同一套（STYLE.md ③ 特例二）。
--
-- **首選 `MiliUITip_API.Adopt(tip, { keepScale = true, ignoreParentAlpha = true, followPanel = true })`**：外觀跟旁邊那顆提示
-- 完全一致（底色、邊色、邊寬、頂部遮罩都跟著玩家的提示框設定走）。
-- ⚠ **`keepScale` 一定要帶。** `Adopt` 預設會對接管的框 `SetScale(玩家設的提示縮放)`，
--   而這顆每次顯示都掛在 `GameTooltip` 底下、有效縮放已經吃到那一份 ⇒ 不帶的話
--   縮放 ≠ 1 的玩家會看到預覽變成平方倍（1.2 → 1.44）。
-- ⚠ **`ignoreParentAlpha` 也一定要帶。** 提示插件的重繪面板會把 `GameTooltip` 壓 alpha 0（原生框當看不見的替身），
--   這顆掛在它底下就跟著透明：實機看到只剩 3D 模型浮在世界上（模型不吃父層 alpha），底、邊、兩行字全不見。
--   退回路徑不需要：沒有提示插件就沒人把 `GameTooltip` 壓 0。
-- ⚠ **`followPanel` 也帶。** 它的 positioner 每 0.2 秒貼到**原生**提示（或最外側的比價框）旁邊；
--   原生被錨定的另一邊會隨自然高度短暫變動，預覽就跟著上下跳。提示插件後掛勾它的 `SetPoint`，
--   對象有重繪面板顯示中時改貼面板（點與位移原樣）。
-- 接管後的層級：提示插件的 skin 子框壓在本體 −1，而它的模型框每次重設都
-- `SetFrameLevel(本體)` ⇒ 底在模型之下，模型與兩行字（`OVERLAY`）照常在上面。
--
-- **退回路徑**（玩家沒裝 `MiliUI_Tooltip`）：自己畫一層**提示皮**
-- （STYLE.md ①：浮在世界上方、彈出來讀一眼）：NineSlice `SetAlpha(0)` ＋
-- `Engine.RegionBackdrop`，底 `T.tipFill`（0.133 不透明）＋ 1px **職業色**邊。
-- 底與邊是這個框自己的 `BACKGROUND` region ⇒ 永遠在模型子框之下，顯示／隱藏、
-- 換 parent、位置全部自動跟著它，一個腳本都不用掛。縮放一個都不碰。
--
-- ### 查證
--
-- 1. **不是 layout host**：`TooltipBackdropTemplateMixin` 只有 backdrop 那幾支，
--    沒有 `Layout`／`MarkDirty`／… ⇒ `RegionBackdrop` 走 region 那條路。
--    保險絲照 RaiderIO 那一份：是的話整個不畫（子框路線的 `SafeParent` 會爬到它外面）。
-- 2. **NineSlice 的 alpha 不用重申**：那支插件從頭到尾沒碰過 `NineSlice`
--    （也沒有 `SetBackdrop*`），只有明確的 `SetAlpha` 會把它打回來。
-- 3. **秘密錨點**：它掛進秘密的提示鏈時自己會 `ClearAllPoints` ＋ `Hide`。這一份
--    **不讀它任何幾何**（寬高、錨點、縮放、層級都不問），所以那條鏈是不是秘密跟我們無關；
--    委派路徑上提示插件 skin 子框的 `OnShow` 讀的層級與名字都有秘密閘。
--
------------------------------------------------------------
-- ## taint 接觸面清單（伴隨元件）
--
-- ⚠ 這一份**一個暴雪物件都沒有碰**。
--
-- | 物件 | 動作 |
-- |---|---|
-- | `AppearanceTooltipTooltip` | `MiliUITip_API.Adopt`（有提示插件時）—— 動作記在那一支的接觸面清單；`keepScale` ⇒ 不寫 `SetScale` |
-- | 同一顆 | `SetIgnoreParentAlpha(true)`（經由 `Adopt` 的 `ignoreParentAlpha`；有提示插件時） |
-- | 同一顆 | `hooksecurefunc(frame, "SetPoint")`（經由 `Adopt` 的 `followPanel`；有提示插件時。對象是它自己的框，不是暴雪物件） |
-- | 它的 `NineSlice` | `SetAlpha(0)`（退回路徑） |
-- | 它自己 | `CreateTexture`（底 ＋ 四條邊，經由 `Engine.RegionBackdrop`；退回路徑） |
--
-- hook：這一份自己**零**（沒有 `hooksecurefunc`、`HookScript`、`SetScript`，也沒有呼叫那支插件的任何函式）；
--   唯一的掛勾是上表那一列，由提示插件經 `followPanel` 掛、記在它的接觸面清單。
-- 寫入它的欄位：無（「接過了嗎」記在這一份自己的旗標裡）。
-- 讀它的物件：只有 `_G[名字]` 在不在，以及 `NineSlice` 這個 parentKey —— 讀結構不是讀值。
--
-- ## 刻意不碰的東西
--
-- * **位置、尺寸、縮放、parent、strata** —— 全是它的 positioner 與 `ShowTooltip` 管的
--   （例外：有提示插件時 `followPanel` 把它要貼的對象從原生換成面板，點與位移不動）。
-- * **它的模型框**（`DressUpModel`／`ModelScene`）與滑鼠滾輪轉模型的那兩顆隱形按鈕。
-- * **兩行字的顏色**（下方的收藏狀態淡藍、上方的「職業無法塑形」紅字）—— 那是它的資料。
-- * **它的設定頁**（`config.lua`，自己的 `BackdropTemplate` 框）。
------------------------------------------------------------
local _, ns = ...

local E = ns.Engine
local T = ns.Tokens

-- ⚠ 一律 `_G[...]` 判斷，**找不到就靜默跳過**，不走 `E.Missing`
--   （STYLE.md ③ 第 2 條：玩家沒裝那支插件不是暴雪改版事故）。
local FRAME_NAME = "AppearanceTooltipTooltip"

local done = false

------------------------------------------------------------
-- 退回路徑：自己畫一層提示皮（見檔頭「查證」）
------------------------------------------------------------
local function PaintTipSkin(frame)
    if E.IsLayoutHost(frame) then return false end

    -- ⚠ 先確認 parentKey 在，再呼叫 `E.Neutralize` —— 那一支對 nil 會寫進
    --   「找不到的區域」，而伴隨元件不准進那張清單（規則第 7 條）。
    local nine
    if pcall(function() nine = frame.NineSlice end) and nine then
        E.Neutralize(nine, FRAME_NAME .. ".NineSlice")
    end

    local ov = E.RegionBackdrop(frame, { key = FRAME_NAME })
    if not ov then return false end
    -- 底 0.133 不透明 ＋ 1px 職業色邊（提示皮；強調色的唯一來源是 `T.Accent`）
    E.Paint(ov, T.tipFill, { T.Accent() })
    return true
end

-- 回傳「還要不要再試」
local function Sweep()
    if done then return false end
    local frame = _G[FRAME_NAME]
    if not frame then return false end     -- 沒裝 ⇒ 靜默，也不必再找（它是檔案層建的）
    -- ⚠ 有 `MiliUITip_API` 就**一律**委派，即使它這次回 false（還沒初始化完）——
    --   不能因為早了一拍就退回我們自己畫的那一層。
    local ok
    if MiliUITip_API and type(MiliUITip_API.Adopt) == "function" then
        ok = MiliUITip_API.Adopt(frame, { keepScale = true, ignoreParentAlpha = true, followPanel = true })
    else
        ok = PaintTipSkin(frame)
    end
    done = ok and true or false
    return not done
end

------------------------------------------------------------
-- 進入點：引擎的伴隨元件輪（`atLogin` ＝ 配方全部套完之後、延一幀）。
-- `scheduled` 擋重複排程 —— `atLogin` 在戰鬥中被延後時引擎會在
-- `PLAYER_REGEN_ENABLED` 再跑一次這一支。
------------------------------------------------------------
local RETRY_DELAY = 2
local scheduled = false

local function Apply()
    local pending = Sweep()
    if scheduled or not pending then return end
    scheduled = true
    C_Timer.After(RETRY_DELAY, function()
        -- 補掃跑在 timer 堆疊裡、不在引擎的 xpcall 底下 ⇒ 自己包一層
        xpcall(Sweep, ns.ReportError)
    end)
end

-- host ＝ nil：這顆不長在任何暴雪視窗上（見檔頭）。
E.AddCompanion(nil, {
    atLogin  = true,
    addonKey = "appearancetooltip",
    apply    = Apply,
})
