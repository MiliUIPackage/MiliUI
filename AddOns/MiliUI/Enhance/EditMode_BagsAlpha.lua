------------------------------------------------------------
-- MiliUI: 編輯模式「背包」多一條透明度滑桿
--
-- 暴雪內建的背包列（編輯模式裡的「背包」系統）只有四個設定 —— 方向、方向、
-- 大小、背包間距（`Enum.EditModeBagsSetting` 就這四個，沒有透明度）。這支在
-- 同一個設定視窗底下多掛一條「透明度」，值存在 `MiliUI_DB.bagsAlpha`。
--
-- 為什麼是 SetAlpha 不是隱藏：
--   透明度 0 的框照樣吃滑鼠 —— 背包鈕看不見但按得到，這正是「藏起來、按鈕還在」
--   要的行為。而且 BagsBar 是保護框，戰鬥中 Hide 會被擋下來；SetAlpha 不是保護
--   函式，什麼時候改都有效。
--
-- 為什麼不真的去加一個暴雪設定：
--   `Enum.EditModeBagsSetting` 是 C 端列舉，版面也是暴雪自己存的
--   （`C_EditMode.SaveLayouts`）。塞一個它不認得的 setting id 進去，輕則被丟掉，
--   重則弄壞整份版面。所以**介面借它的、值自己存**，兩邊不相干。
--
-- ⚠ 選取框一定要 SetIgnoreParentAlpha：
--   透明度拉到 0 之後，暴雪的選取框（`BagsBar.Selection`）是子框，會跟著一起
--   透明 —— 下次進編輯模式看不到那條列，點不到就再也叫不出這個滑桿，等於把
--   設定鎖死。把選取框設成不吃父層透明度之後，列本身照設定值即時預覽（含全
--   透明），外框在編輯模式裡永遠看得見，隨時點得到、拖得動。
--
-- 對外：`MiliUI_BagsAlpha.Get()` / `.Set(0~1)`，不開編輯模式也能調
--   （例：`/run MiliUI_BagsAlpha.Set(0)`）。
------------------------------------------------------------

local DEFAULT_ALPHA = 1
local STEP_PERCENT  = 5     -- 滑桿一格 5%

-- 尺寸抄 `EditModeSettingSliderTemplate`（沒有 min/max 文字時的那組），
-- 這樣新增的這一列跟暴雪原本那幾列等寬等高，視窗寬度不會被撐開。
local ROW_WIDTH, ROW_HEIGHT = 343, 32
local LABEL_WIDTH, SLIDER_WIDTH = 100, 200

-- 暴雪自己那幾條是 1..N（`UpdateSettings` 裡用 ipairs 的 index），
-- 排在後面就好。⚠ layoutIndex 撞號會被 `LayoutIndexComparator` 拋 GMError。
local LAYOUT_INDEX = 100

local LABEL_TEXT = "透明度"

------------------------------------------------------------
-- 設定值
------------------------------------------------------------
local function GetAlpha()
    local a = MiliUI_DB and tonumber(MiliUI_DB.bagsAlpha)
    if not a then return DEFAULT_ALPHA end
    return math.max(0, math.min(1, a))
end

------------------------------------------------------------
-- 背包系統框
--
-- 不寫死 `BagsBar` 這個全域名字，跟編輯模式自己要 —— 暴雪改名的時候這裡才不會
-- 整支失效（拿不到就退回全域名，兩條路都斷了才放棄）。
------------------------------------------------------------
local bagsSystem
local function BagsSystem()
    if bagsSystem then return bagsSystem end
    if EditModeManagerFrame and EditModeManagerFrame.GetRegisteredSystemFrame
        and Enum and Enum.EditModeSystem and Enum.EditModeSystem.Bags then
        -- 背包沒有 systemIndex，查表是兩邊都拿 nil 去比，所以第二個參數不要傳
        bagsSystem = EditModeManagerFrame:GetRegisteredSystemFrame(Enum.EditModeSystem.Bags)
    end
    bagsSystem = bagsSystem or _G.BagsBar
    return bagsSystem
end

local function Apply()
    local frame = BagsSystem()
    if not frame then return end

    frame:SetAlpha(GetAlpha())

    -- 見檔頭：選取框不吃父層透明度，編輯模式裡才永遠找得到這條列
    local selection = frame.Selection
    if selection and selection.SetIgnoreParentAlpha then
        selection:SetIgnoreParentAlpha(true)
    end
end

local RefreshSlider   -- 下面才建得出來，先宣告

local function SetAlpha(alpha)
    alpha = math.max(0, math.min(1, tonumber(alpha) or DEFAULT_ALPHA))
    if not MiliUI_DB then MiliUI_DB = {} end
    MiliUI_DB.bagsAlpha = alpha
    Apply()
end

------------------------------------------------------------
-- 滑桿
--
-- 沒有直接用 `EditModeSettingSliderTemplate`：那個範本的 mixin 在 OnLoad 就把
-- 值變更接到 `EditModeSystemSettingsDialog:OnSettingValueChanged`，最後會走進
-- `EditModeManagerFrame:OnSystemSettingChange` 去存一個不存在的 setting。
-- 回呼是 OnLoad 當下綁死的，事後覆寫方法也攔不掉，所以自己拼一份一模一樣的
-- 外觀：`GameFontHighlightMedium` 標籤 ＋ `MinimalSliderWithSteppersTemplate`。
------------------------------------------------------------
local row, initInProgress

local function BuildRow(dialog)
    row = CreateFrame("Frame", nil, dialog.Settings)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    row:Hide()
    row.layoutIndex = LAYOUT_INDEX

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightMedium")
    label:SetJustifyH("LEFT")
    label:SetSize(LABEL_WIDTH, ROW_HEIGHT)
    label:SetPoint("LEFT")
    label:SetText(LABEL_TEXT)

    local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
    slider:SetSize(SLIDER_WIDTH, ROW_HEIGHT)
    slider:SetPoint("LEFT", label, "RIGHT", 5, 0)
    row.slider = slider

    row.formatters = {
        [MinimalSliderWithSteppersMixin.Label.Right] = function(value)
            return ("%d%%"):format(math.floor(value + 0.5))
        end,
    }

    -- CallbackRegistry 的 function 型回呼會被叫成 func(owner, ...)，
    -- 所以第一個參數是 owner（這裡就是 row），第二個才是值。
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged,
        function(_, value)
            if initInProgress then return end
            SetAlpha(value / 100)
        end, row)
end

-- ⚠ `Init` 裡的 `SetValue` 是在**舊的** OnValueChanged 腳本還掛著的時候跑的，
--   不擋一下會把上一次的值又寫回 DB（暴雪自己也用同一個 initInProgress 手法）。
function RefreshSlider()
    if not row then return end
    initInProgress = true
    row.slider:Init(GetAlpha() * 100, 0, 100, 100 / STEP_PERCENT, row.formatters)
    initInProgress = false
end

------------------------------------------------------------
-- 掛進編輯模式的設定視窗
------------------------------------------------------------
local installed

local function Install()
    if installed then return true end
    if not (EditModeSystemSettingsDialog and EditModeSystemSettingsDialog.Settings
        and EditModeManagerFrame and MinimalSliderWithSteppersMixin) then
        return false
    end
    installed = true

    BuildRow(EditModeSystemSettingsDialog)

    hooksecurefunc(EditModeSystemSettingsDialog, "UpdateSettings", function(dialog, systemFrame)
        -- 暴雪這支對「不是目前掛著的系統」整段跳過，我們跟著跳過
        if systemFrame ~= dialog.attachedToSystem then return end

        if systemFrame == BagsSystem() then
            RefreshSlider()
            row:Show()
        else
            row:Hide()
        end

        -- 暴雪在 UpdateSettings 中段就 Layout 過一次了 —— 那時我們這一列還沒
        -- Show，它自己那幾條的高度也還沒定案（高度是後面 SetupSetting 才設的）。
        -- 這裡補排一次，接在後面的 UpdateSizeAndAnchors 才量得到正確高度，
        -- 視窗不會少一列的高度。
        dialog.Settings:Layout()
    end)

    -- 「還原變更」只會還原暴雪自己的設定。進編輯模式時記一份，按下去的時候
    -- 把透明度也一起還原，免得那顆按鈕對這一列說謊。
    local revertAlpha
    if EditModeManagerFrame.EnterEditMode then
        hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
            revertAlpha = GetAlpha()
        end)
    end
    if EditModeManagerFrame.RevertSystemChanges then
        hooksecurefunc(EditModeManagerFrame, "RevertSystemChanges", function(_, systemFrame)
            if revertAlpha == nil or systemFrame ~= BagsSystem() then return end
            SetAlpha(revertAlpha)
            RefreshSlider()
        end)
    end

    return true
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
-- 切換版面／套用預設版面之後暴雪會重建整條列，透明度要再蓋回去
watcher:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
watcher:SetScript("OnEvent", function()
    Install()
    Apply()
end)

------------------------------------------------------------
-- 對外 API
------------------------------------------------------------
MiliUI_BagsAlpha = {
    Get = GetAlpha,
    Set = function(alpha)
        SetAlpha(alpha)
        RefreshSlider()
    end,
    Apply = Apply,
}
