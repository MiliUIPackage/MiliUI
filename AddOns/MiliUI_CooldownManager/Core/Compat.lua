------------------------------------------------------------
-- 相容：別支插件也想替冷卻管理器的圖示上皮時，請它跳過
--
-- 目前只有一支：MasqueBlizzBars（把暴雪的框交給 Masque 套皮）。它 12.1 起每次檢視器
-- RefreshLayout 都會把還沒套過的 item 交給 Masque：重設圖示的遮罩／texcoord、補一張皮的外框圖，
-- 尺寸照「套皮當下」的 item；之後 item 的尺寸一變它會重套，但**戰鬥中與插件限制生效時直接跳過**。
-- 我們的引擎也在同一批框上拔遮罩、設 texcoord、畫邊框、改尺寸——兩邊輪流蓋，誰後做誰贏：
-- 登入時那一批碰巧相安無事，但只要暴雪之後生出一顆新的框（進副本被換專精、天賦切換、編輯模式
-- 套版面都會整條重取出），那一顆就會是「Masque 的皮＋我們的格子」的混合體：圖示比格子大、
-- 外面多一圈深色框、數字是原生字型。
--
-- 圖示長什麼樣是本插件的主題在管，所以四條檢視器都請它跳過：item 一取出（OnAcquireItemFrame，
-- 早於它掛在 RefreshLayout 後面的套皮）就蓋上它自己的「已套皮」印記，它看到印記就不交給 Masque、
-- 也不掛尺寸變化的重套。增益長條交給 Masque 的是 item.Icon 那一層（一個 Frame），印記也蓋那一層。
--
-- ⚠ 這是引擎契約「暴雪框上一個欄位都不寫」的**唯一例外**：這個欄位只有 MasqueBlizzBars 讀，
--   暴雪的程式不讀（污染只跟著那一個 key），而且只有它載入時才寫。
-- ⚠ 印記的名字是它的 SkinnedKey（"_" .. 插件資料夾名 .. "Skinned"）；它改名這裡就靜默失效，
--   症狀是上面那種混合體回來。
--
-- 互斥偵測成立（另一支冷卻管理器插件在跑）或已經還給暴雪時不蓋：那時圖示不歸我們管。
------------------------------------------------------------
local _, ns = ...

ns.Compat = {}
local K = ns.Compat

local SKINNER     = "MasqueBlizzBars"
local SKINNED_KEY = "_" .. SKINNER .. "Skinned"
local VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local function Loaded(name)
    local api = C_AddOns and C_AddOns.IsAddOnLoaded
    if not api then return false end
    local ok, v = pcall(api, name)
    return ok and v and true or false
end

local function Mark(item)
    if not item or ns.conflict or ns.released then return end
    item[SKINNED_KEY] = true
    local icon = item.Icon
    if type(icon) == "table" and icon.Icon then icon[SKINNED_KEY] = true end
end

local hooked = {}
K.marked = 0
local function Install()
    local all = true
    for _, name in ipairs(VIEWERS) do
        local viewer = _G[name]
        if not hooked[name] then
            if viewer and viewer.OnAcquireItemFrame then
                hooked[name] = true
                hooksecurefunc(viewer, "OnAcquireItemFrame", ns.Guard(function(_, item)
                    Mark(item)
                    K.marked = K.marked + 1
                end))
                -- 掛勾當下已經取出的（通常沒有：暴雪第一次排版在所有插件載入之後）
                local pool = viewer.itemFramePool
                if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
                    for item in pool:EnumerateActive() do Mark(item) end
                end
            else
                all = false
            end
        end
    end
    return all
end

function K.Active() return next(hooked) ~= nil end

-- 它的資料夾名排在我們前面（TOC 的 OptionalDeps 也寫了），檔案層就判得出來；沒裝就什麼都不做。
-- 檢視器通常在檔案層就在（暴雪的冷卻管理器比第三方插件早載入）⇒ 趕在暴雪第一次排版之前掛好。
-- 萬一還沒建好：登入時再掛一次，Viewers 就緒時（退避重試）再補一次（K.Install 可重複叫）。
local wanted = Loaded(SKINNER) and not ns.conflict
function K.Install()
    if not wanted or ns.conflict then return end
    return Install()
end
if wanted and not Install() then
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        xpcall(K.Install, ns.ReportError)
    end)
end
