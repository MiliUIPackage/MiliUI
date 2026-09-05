---------------------------------------------------------------
-- MiliUI Fix: MasqueBlizzBars 對冷卻管理器只套皮、不碰 Ayije_CDM 管的東西
-- Author: Mili
--
-- 背景：MasqueBlizzBars 12.1.0.0 把「Cooldown Manager」一個群組拆成四個
--   （BuffBar／BuffIcon／Essential／Utility），並改成每次 RefreshLayout 都重跑
--   PreHook_CooldownViewer ＋ Core:Skin。群組 ID 換了，舊設定不沿用，四個新群組
--   預設全部啟用。Ayije_CDM 有載入時要處理兩件事：
--
-- 一、增益長條（BuffBarCooldownViewer）整個不套皮
--   症狀：長條左邊的圖示外面多一圈偏移的細框，有的條有、有的條沒有，戰鬥中最明顯。
--   成因：這版第一次把長條的圖示（frame.Icon，那是一個 Frame）交給 Masque。
--   Masque 一套皮就改圖示貼圖的錨點／texcoord／遮罩，沒有 NormalTexture 的框還會
--   自己 CreateTexture 補一張皮的 Normal（Masque/Core/Regions/Normal.lua），尺寸照
--   「套皮當下」的圖示。Ayije_CDM 之後把圖示縮成長條高度、內縮 1px；MasqueBlizzBars
--   掛在 SetSize 上的 ReSkin 在戰鬥中直接 return（CooldownViewerItem_SetSize 開頭的
--   InCombatLockdown 閘），皮就留在舊的尺寸與位置 → 一個比圖示大、往左上偏的方框。
--   到 Masque 把群組關掉不是解法：PreHook 每次 RefreshLayout 都做
--   IconOverlay:SetShown(groupDisabled)——群組關掉反而把暴雪的圓框秀回來；關群組時
--   Masque 也會把已套皮的圖示「還原」成暴雪預設錨點，一樣蓋掉 Ayije_CDM 的內縮。
--   修法：項目框在 OnAcquireItemFrame 就先蓋上 MasqueBlizzBars 自己的「已套皮」印記。
--   Core:Skin 看到印記就跳過 AddButton，PreHook 也不會再掛 SetSize 的 ReSkin。
--   長條的皮是套在 frame.Icon 那一層，印記也要蓋在那一層（MasqueBlizzBars 自己判斷
--   「是長條」的方式就是 frame.Icon.Icon 存在，這裡照抄）。
--
-- 二、三個圖示檢視器照樣套皮，但層數／充能數字不交給 Masque
--   症狀：增益圖示的層數數字一下在頂端一下在底部，字的上下被裁掉；設定裡的
--   「層數 Y 偏移」拉了沒反應。
--   成因：PreHook 把 frame.Count 對到 Applications.Applications（增益）或
--   ChargeCount.Current（冷卻），Masque 的 Skin_Text 就對那個 FontString 重新
--   SetPoint（照皮的定義，Raeli 是 BOTTOM）、SetSize（36×10，12 號字塞不下）、
--   SetDrawLayer。Ayije_CDM 每次套樣式再把錨點拉回自己的設定，但不會把 SetSize
--   還原；兩邊輪流蓋，Masque 每次 RefreshLayout 與 ReSkin 都會再來一次。
--   修法：PreHook 是 `if ... and not frame.Count then frame.Count = ...`，所以在它
--   之前先塞一個藏起來的假 FontString 進 frame.Count，Masque 就對假的做事，真的
--   數字從此只有 Ayije_CDM 在管。皮的邊框／圖示 texcoord／遮罩照舊由 Masque 套。
--   暴雪的冷卻管理器程式碼沒有讀過項目框的 .Count（用的是 ChargeCount／Applications），
--   這個欄位只有 MasqueBlizzBars 讀。
--
-- 共通：OnAcquireItemFrame 在 RefreshLayout 裡面被叫，早於 MasqueBlizzBars 掛在
--   RefreshLayout 後面的 SkinByHook，所以第一輪就攔得到；池子回收再取出時欄位還在
--   框上，重做一次沒成本。只有 MasqueBlizzBars 讀這些欄位，暴雪不讀，沒有污染問題
--   （規則見 wow-121-secret-values：暴雪會讀的欄位才不能寫）。
--
-- ⚠ 印記的名字照 MasqueBlizzBars 的 SkinnedKey（"_"..AddonName.."Skinned"），
--   Count 的擋法靠它 PreHook 裡的 `not frame.Count` 判斷；上游改了這兩處這支就
--   靜默失效——症狀是方框回來、數字又開始跳。更新後看一眼 Core.lua 開頭與
--   PreHook_CooldownViewer。
---------------------------------------------------------------

local SKINNED_KEY = "_MasqueBlizzBarsSkinned"

-- 整個不套皮
local BLOCK_VIEWERS = { "BuffBarCooldownViewer" }
-- 套皮，但數字不給 Masque
local KEEP_COUNT_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }

local function MarkAsSkinned(itemFrame)
    itemFrame[SKINNED_KEY] = true
    -- 增益長條：Masque 拿到的是 frame.Icon（一個 Frame，裡面才是 Icon 貼圖）
    local icon = itemFrame.Icon
    if type(icon) == "table" and icon.Icon then
        icon[SKINNED_KEY] = true
    end
end

local function InstallDummyCount(itemFrame)
    if itemFrame.Count then return end
    local dummy = itemFrame:CreateFontString(nil, "OVERLAY")
    dummy:SetFontObject("NumberFontNormal")
    dummy:Hide()
    itemFrame.Count = dummy
end

local function Hook(names, handler)
    for _, name in ipairs(names) do
        local viewer = _G[name]
        if viewer and viewer.OnAcquireItemFrame then
            hooksecurefunc(viewer, "OnAcquireItemFrame", function(_, itemFrame)
                -- 沒有 Ayije_CDM 的人要的就是 Masque 皮，這裡什麼都不做
                if not itemFrame or not C_AddOns.IsAddOnLoaded("Ayije_CDM") then return end
                handler(itemFrame)
            end)
        end
    end
end

Hook(BLOCK_VIEWERS, MarkAsSkinned)
Hook(KEEP_COUNT_VIEWERS, InstallDummyCount)
