------------------------------------------------------------
-- 藏起暴雪內建的時間軸畫面
--
-- 只藏畫面、不關功能：資料（C_EncounterTimeline）、暴雪自己的音效、別的插件掛在上面的
-- 倒數音效（DBM 用 C_EncounterEvents.SetEventSound）都要靠時間軸開著才會跑。所以：
--   * 不動 CVar encounterTimelineEnabled
--   * 不用 C_EncounterTimeline.SetViewType(None) —— 暴雪每次套編輯模式設定都會照
--     編輯模式的選項把它設回去（EncounterTimeline.lua 的 UpdateSystemSettingViewType）
--   * 把兩個 view 的透明度壓成 0（DBM 的「隱藏暴雪時間軸」也是這樣做）
--
-- ⚠ 暴雪會自己設 view 的透明度（編輯模式「透明度」選項：UpdateSystemSettingTransparency），
--   只設一次會被蓋回去。所以在 view 的 SetAlpha 上掛 post-hook：被設成非 0 就再壓回 0。
--   SetAlpha 是 C 端狀態、不是 Lua 欄位，不會把污染寫進暴雪的框。
--
-- 藏起來的 view 圖示仍然吃得到滑鼠（暴雪的 pip 有工具提示）；這是已知取捨，
-- 要完全不擋滑鼠得逐個子框 EnableMouse(false)，那會碰到暴雪自己建的框，不值得。
------------------------------------------------------------
local _, ns = ...

ns.BlizzardView = {}
local BV = ns.BlizzardView

local hiding = false
local hooked = {}

local function Views()
    local tl = _G.EncounterTimeline
    if not tl then return end
    return tl.TrackView, tl.TimerView
end

local function Enforce(view, alpha)
    if hiding and alpha and alpha > 0 then
        view:SetAlpha(0)     -- 這一次會再進 hook 一次，但 alpha = 0 就停了
    end
end

local function HookView(view)
    if not view or hooked[view] then return end
    hooked[view] = true
    hooksecurefunc(view, "SetAlpha", Enforce)
end

function BV.Apply()
    local d = ns.db and ns.db.display
    hiding = (d and d.enabled and d.hideBlizzard) and true or false
    local track, timer = Views()
    for _, view in ipairs({ track or false, timer or false }) do
        if view then
            HookView(view)
            if hiding then
                view:SetAlpha(0)
            elseif view:GetAlpha() == 0 then
                -- 交還給暴雪：直接回 1。不去呼叫暴雪的 UpdateSystemSettingTransparency 重算 ——
                -- 從插件程式呼叫編輯模式系統框的方法，那條路徑就帶著本插件的污染；
                -- 玩家在編輯模式設過的透明度，下次暴雪套設定（進出編輯模式、重載）就會回來
                view:SetAlpha(1)
            end
        end
    end
end

function BV.IsHiding()
    return hiding
end

-- 暴雪的時間軸可能是隨需載入的：載入時再套一次
if EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EncounterTimeline", function()
        if ns.db then BV.Apply() end
    end)
end

ns.RegisterCallback("Init", "blizzardView", BV.Apply)
