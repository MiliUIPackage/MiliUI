------------------------------------------------------------
-- 配方：傳奇鑰石（Blizzard_ChallengesUI）—— PVEFrame 的第三個分頁
--
-- 這一份**不是獨立的配方**：它是 `Skins/PVE.lua` 那一筆 `Engine.Register` 的
-- 一個 `part`（`addon = "Blizzard_ChallengesUI"`），共用 `pve` 設定開關。
--
-- 暴雪原始碼出處（12.1 live 分支，Gethe/wow-ui-source）：
--   Blizzard_ChallengesUI/Blizzard_ChallengesUI_Mainline.toc:2  `## LoadOnDemand: 1`
--   Blizzard_ChallengesUI/Mainline/Blizzard_ChallengesUI.xml:779
--       ChallengesFrame（setAllPoints，parent PVEFrame）
--   同檔 :781   $parentInset ＝ ChallengesFrameInset（InsetFrameTemplate）
--   同檔 :787   ChallengesFrame.WeeklyInfo（ScrollFrame，**沒有** ScrollFrameTemplate
--               ⇒ 沒有 ScrollBar 可以 skin）
--   同檔 :832-858  RuneBG／RunesLarge／RunesSmall／LargeRuneGlow／SmallRuneGlow
--               —— 符文底圖，內容底材
--   同檔 :744   ChallengesDungeonIconFrameTemplate（parentArray DungeonIcons）
--   同檔 :218   ChallengesKeystoneFrame（frameStrata HIGH、parent UIParent）
--   同檔 :225   整片 `ChallengeMode-KeystoneFrame` 的 atlas（**就是這個視窗的形狀**）
--   同檔 :420   CloseButton（UIPanelCloseButton）
--   同檔 :430   StartButton（UIPanelButtonTemplate）
--   同檔 :444   KeystoneSlot（物品互動：OnReceiveDrag／OnDragStart／OnClick）
--   Blizzard_GroupFinder/Mainline/PVEFrame.lua:10
--       `hideLeftInset = true` ⇒ 切到這一頁時暴雪自己把 PVEFrame 左半邊整組 Hide
--
-- 查證後跟計畫假設不一樣的三件事：
--   1. **鑰石插槽視窗沒有「chrome」可以換。** `ChallengesKeystoneFrame` 的整片背景
--      就是一張 `ChallengeMode-KeystoneFrame` 的 atlas（.xml:225）—— 它不是矩形邊框，
--      是這個視窗的**形狀本身**，上面的符文、鑰石孔、說明字全部貼著它排。
--      中和掉會剩下一堆浮在空中的字。⇒ 內容底材規則：保留，只做關閉鈕與開始鈕。
--   2. **地城圖示格這一輪不做。** `ChallengesFrame.DungeonIcons` 是
--      `ChallengesFrameMixin:Update` **動態建立**的（parentArray），要接管就得勾
--      `ChallengesFrame` 這個**實例**的 `Update` 方法 —— 而 `hooksecurefunc(frame, …)`
--      會在暴雪的框上寫一個欄位，契約禁止；勾 `ChallengesFrameMixin.Update` 又追不上
--      （mixin 在框建立時就被拷貝走了，STYLE.md ③ 的陷阱 4）。
--      而且那圈 `ChallengeMode-DungeonIconFrame` 是 M+ 介面的身分美術。列進回報 ⑦。
--   3. **`WeeklyInfo` 不是 `ScrollFrameTemplate`**（.xml:787 沒有 inherits）
--      ⇒ 沒有 `.ScrollBar`，這一頁一條捲軸都沒有。
--
------------------------------------------------------------
-- ## taint 接觸面清單（暴雪物件）
--
-- | 物件 | 動作 |
-- |---|---|
-- | ChallengesFrameInset 的 Bg / NineSlice | SetAlpha(0) |
-- | ChallengesKeystoneFrame.CloseButton 的 Normal/Disabled 貼圖 | SetAlpha(0) |
-- | ChallengesKeystoneFrame.CloseButton 的 Highlight/Pushed 貼圖 | SetColorTexture |
-- | ChallengesKeystoneFrame.StartButton 的 Left/Right/Middle | SetAlpha(0) |
-- | 同上 | SetNormalFontObject(GameFontHighlight) |
-- | 以上各框 | CreateFrame 掛自己的 overlay（不吃滑鼠、零腳本） |
--
-- hook：**一支都沒有**。
-- 寫入暴雪欄位：無。讀暴雪物件：只有 `Engine.Overlay` 內部的 `GetFrameLevel`。
--
------------------------------------------------------------
-- ## 刻意不碰的東西
--
-- * **`ChallengesKeystoneFrame` 的背景 atlas 與全部符文層** —— 見上面第 1 點。
-- * **`ChallengesKeystoneFrame.KeystoneSlot`** —— 物品互動（拖放鑰石），
--   腳本一個都不掛，貼圖也不碰。
-- * **`ChallengesFrame` 的符文底圖（RuneBG／RunesLarge／RunesSmall／兩張 Glow）**
--   —— 內容底材，而且「本週」「賽季最佳」那幾條字本來就是白色，深底讀得到。
-- * **`ChallengesFrame.DungeonIcons` 與 `WeeklyChest`／`DungeonScoreInfo`**
--   —— 動態建立 ＋ 身分美術，見上面第 2 點。
-- * **`ChallengesFrame.SeasonChangeNoticeFrame`**（`frameStrata="DIALOG"`）
--   —— 換季公告，一個賽季看一次。
-- * **套組內建掛在這個視窗上的四個自製功能** —— `ChallengesUI_Buttons`（鑰石視窗
--   下方的就位確認／倒數面板）、`ChallengesUI_LootTable`（右側裝等對照表）、
--   `PartyKeystone`（右下隊友鑰石）、`AutoSlotKeystone`（沒有 UI）。
--   前三個各自帶一套「深色半透明底 ＋ 金色邊框」的自畫樣式，跟這包的
--   「不透明灰底 ＋ 1px 純黑邊」不是同一套語彙 —— 但那是**它們自己檔案裡的事**，
--   這一輪不去改別的插件（列進回報 ⑤／⑦）。伴隨元件規則在這裡也用不上：
--   它們不是「暴雪視窗上的原生控件」，而是整塊自己畫的面板。
------------------------------------------------------------
local _, ns = ...

local Skin = ns.Skin
local E = ns.Engine

local X = ns.PVESkin
local Field = X.Field

local function ApplyChallenges()
    local inset = _G.ChallengesFrameInset
    if inset then
        Skin.Inset(inset, "ChallengesFrameInset")
    else
        E.Missing("ChallengesFrameInset")
    end

    -- 鑰石插槽視窗：只換 chrome 上那兩顆按鈕，背景那張 atlas 就是視窗本身。
    local keystone = _G.ChallengesKeystoneFrame
    if not keystone then
        E.Missing("ChallengesKeystoneFrame")
        return
    end

    local close = Field(keystone, "CloseButton")
    if close then
        Skin.CloseButton(close, "ChallengesKeystoneFrame.CloseButton")
    else
        E.Missing("ChallengesKeystoneFrame.CloseButton")
    end

    X.SkinKeyedButtons(keystone, "ChallengesKeystoneFrame", { "StartButton" })
end

ns.PVESkin.ApplyChallenges = ApplyChallenges
