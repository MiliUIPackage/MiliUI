------------------------------------------------------------
-- MBB 小地圖按鈕：滑過時展開米利UI選單
--
-- 跟 ESC 選單「米利UI設定」滑過展開的是同一張選單（項目來自
-- MiliUI_MenuEntries，選單本體在 Menu.lua）。
--
-- 開啟方向不能寫死：MBB 主按鈕可以沿小地圖拖、還能脫離小地圖任意擺。
-- 垂直方向 Menu.lua 的 OpenAt 每次開啟都會即時判斷（上面塞不下就往下開）；
-- 水平方向靠 SetClampedToScreen 夾回螢幕內。
------------------------------------------------------------
local AddonName, ns = ...
if AddonName ~= "MiliUI" then return end

local menu

local function EnsureMenu(anchor)
    if menu then return menu end
    if not (MiliUI and MiliUI.Menu and MiliUI.Menu.Create) then return nil end
    -- ⚠ 父層掛 UIParent，不要掛 MBB 按鈕：那顆是 Minimap 的子框（XML 還帶
    -- toplevel），小地圖那一支的渲染會把整個子樹拖著走 —— 選單自己設成 DIALOG
    -- 也照樣被 LOW 層的任務追蹤框架蓋住（framestack 實測）。
    -- 代價是失去 Menu.lua「父層一藏選單跟著消失」的便利，但這裡本來就靠
    -- 滑鼠移開自動收合，不影響。
    menu = MiliUI.Menu.Create(UIParent)
    menu.centerLabel = true
    -- 只列一項：小地圖鈕是隨手點的入口，開設定就好，不要把七個插件全攤開。
    -- 各插件的入口在設定視窗的「插件總覽」與 ESC 選單那份選單裡都找得到。
    menu.entriesProvider = function()
        return { {
            key  = "pack",
            text = "米利UI設定",
            rawLabel = true,   -- 不要被剝成「設定」
            icon = "Interface\\AddOns\\MiliUI\\icon",
            OnClick = function() ns.OpenOptions() end,
        } }
    end
    -- FULLSCREEN_DIALOG：壓得過任務追蹤與小地圖周邊，又低於 TOOLTIP，
    -- 不跟滑鼠提示／冷卻圖示那層互搶（在那層誰後建誰贏，行為不穩定）
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(100)
    menu:SetClampedToScreen(true)
    -- 滑鼠在選單／按鈕上的期間，收掉任何冒出來的 GameTooltip：
    -- 小地圖周邊按鈕的判定範圍常互相重疊，而 tooltip 在 TOOLTIP 層永遠壓過
    -- 選單，不收就會蓋在選單上。離開選單去摸別顆按鈕時不干涉。
    -- （HookScript：Menu.lua 自己的 OnUpdate 管收合判定，不能蓋掉）
    menu:HookScript("OnUpdate", function(self)
        if GameTooltip:IsShown()
                and (self:IsMouseOver() or (self.anchor and self.anchor:IsMouseOver())) then
            GameTooltip:Hide()
        end
    end)
    return menu
end

local function TryHook()
    local btn = MBB_MinimapButtonFrame
    if not btn then return end   -- MBB 沒裝或被停用：整個功能安靜缺席
    btn:HookScript("OnEnter", function(self)
        local m = EnsureMenu(self)
        if not m then return end
        m:OpenAt(self, "down")   -- 預設往下開，下緣塞不下 OpenAt 會自己翻上去
        -- MBB 自己的 OnEnter 會開 GameTooltip，跟選單疊在同一塊。
        -- Hook 在原 handler 之後跑，這裡收掉正好；只收自己按鈕擁有的，
        -- 不誤傷別人的 tooltip
        if GameTooltip:IsShown() and GameTooltip:GetOwner() == self then
            GameTooltip:Hide()
        end
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    TryHook()
end)
