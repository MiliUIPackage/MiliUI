------------------------------------------------------------
-- 圖騰框架（獨立框，樣式 A「圖示膠囊列」；樣式欄位保留切換空間）
--
-- 12.1：GetTotemInfo 回傳全秘密，只有 icon 是明文字串 →
--   icon 當「有圖騰」的 proxy；剩餘時間用 pcall 抽 start+duration-GetTime()
--   （抽不到就滿條顯示）
------------------------------------------------------------
local _, ns = ...

local Media = ns.Media
local CLASS = ns.playerClass

-- 會放東西進圖騰欄位的職業：薩滿（圖騰）、德魯伊（生命綻放）、武僧（玉蛟／玄牛雕像）。
-- 暴雪的 TotemFrame 自己不看職業（欄位有東西就畫），死騎／聖騎留著當保險。
-- 設定面板的「召喚物」分頁也吃這張表（Options/Panel.lua）→ 這裡是唯一來源
ns.TOTEM_CLASSES = {
    SHAMAN = true, DRUID = true, MONK = true, DEATHKNIGHT = true, PALADIN = true,
}

if not ns.TOTEM_CLASSES[CLASS] then
    return
end

local NUM_SLOTS = MAX_TOTEMS or 4

-- 實際欄位：1=火 2=土 3=水 4=風（現代化元素色）
local ELEMENT_COLORS = {
    [1] = { r = 1, g = 0.42, b = 0.29 },     -- 火 #ff6b4a
    [2] = { r = 0.85, g = 0.70, b = 0.39 },  -- 土 #d8b263
    [3] = { r = 0.29, g = 0.76, b = 1 },     -- 水 #4ac3ff
    [4] = { r = 0.73, g = 0.66, b = 1 },     -- 風 #b9a8ff
}

local frame          -- MiliUIUF_Totem
local slots = {}     -- [i] = { btn, icon, bar, cd, duo, active }

------------------------------------------------------------
-- 倒數：整條路交給引擎，插件一次都不讀值
--
-- ⚠⚠ **戰鬥中 GetTotemInfo 的 start/duration 是秘密值**，Lua 算不動
-- （`start + dur - GetTime()` 直接拋錯）—— 這就是「戰鬥中召喚物沒有時間」的成因。
-- 暴雪自己的 TotemFrame 是在 Lua 裡算的（`math.ceil(GetTotemTimeLeft(slot))`），
-- 但那是 untainted 程式，讀得到秘密值；插件走不了那條路。
--
-- 正解是 **duration 物件**：
--   1. `C_DurationUtil.CreateDuration()` 建一顆（每格一顆，重複使用）
--   2. `duo:SetTimeFromStart(start, duration, modRate)` **寫進去** —— C 端 setter，吃秘密值
--   3. 交給 `StatusBar:SetTimerDuration` 與 `Cooldown:SetCooldownFromDurationObject`，
--      進度條與倒數數字全部由引擎驅動
-- 本機 Ayije_CDM 的飾品／自訂 buff 就是這一套。
--
-- ⚠ **絕對不要把它讀回來**：`duo:IsZero()`、`GetTotalDuration()` 這類 getter 回的是
-- 秘密值，一做布林測試就炸。Plumber 的 CooldownUtil 把這整段註解掉並標
-- 「Unusable in combat」，踩到的正是 `IsZero()` 那一下，**不是** SetTimeFromStart。
--
-- 因為值不再由我們推算，「時間到了」也改吃引擎的 OnCooldownDone，
-- 不需要自己輪詢（原本 0.25 秒的 ticker 整個拿掉了）。
------------------------------------------------------------
local TIMER_DIR = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime

-- ⚠ 前置宣告。這兩個在 CreateSlot 的 OnCooldownDone 裡用得到，而它們的實體排在更下面
-- ——宣告寫在下面的話那個 closure 會抓到同名的**全域 nil**，倒數一結束就靜默什麼都不做。
-- （這個檔案為了 previewOn 已經踩過一次同樣的坑，見下面預覽區塊的註解。）
local previewOn = false
local OnSlotExpired

local function GetDB()
    return ns.db.units.totem
end

local function SlotColor(i)
    local db = GetDB()
    if db.colors == "element" then
        return ELEMENT_COLORS[i] or ELEMENT_COLORS[1]
    end
    return RAID_CLASS_COLORS[CLASS] or { r = 0.7, g = 0.7, b = 0.7 }
end

local function CreateSlot(i)
    local db = GetDB()
    local size = db.frame.iconSize or 28

    local btn = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    btn:SetSize(size, size)
    Media.ApplyBorder(btn, nil, 1)
    -- 內縮要用邊框「實際畫出來」的厚度，直接寫 1 會在 Retina 上露出次像素縫
    local inset = Media.BorderInset(1)
    local barH = ns.P.Scale(3)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset + barH)   -- 底部留給時間條
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local barBG = btn:CreateTexture(nil, "BACKGROUND")
    barBG:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", inset, inset)
    barBG:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
    barBG:SetHeight(barH)
    barBG:SetTexture(Media.WHITE8X8)
    barBG:SetVertexColor(0, 0, 0, 0.6)

    local bar = CreateFrame("StatusBar", nil, btn)
    bar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", inset, inset)
    bar:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
    bar:SetHeight(barH)
    bar:SetStatusBarTexture(Media.WHITE8X8)
    bar:SetFrameLevel(btn:GetFrameLevel() + 1)

    -- 倒數數字由 Cooldown widget（引擎）畫在圖示上。只要數字不要扇形 ——
    -- 進度已經由底下那條時間條表示，再蓋一層扇形會把圖示糊掉。
    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
    cd:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    cd:SetFrameLevel(btn:GetFrameLevel() + 2)
    cd:SetDrawSwipe(false)
    cd:SetDrawEdge(false)
    cd:SetDrawBling(false)
    cd.noCooldownCount = true      -- 別讓 OmniCC 那類插件再疊一份數字

    -- 滑鼠提示（不做點擊取消：12.1 的 DestroyTotem 受保護限制多，先不碰）
    btn:EnableMouse(true)
    local slotIndex = i
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        pcall(GameTooltip.SetTotem, GameTooltip, slotIndex)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:Hide()

    local slot = { btn = btn, icon = icon, bar = bar, cd = cd }
    -- 每格一顆 duration 物件，重複使用（只寫不讀，見檔案上方的說明）
    if C_DurationUtil and C_DurationUtil.CreateDuration then
        local ok, duo = pcall(C_DurationUtil.CreateDuration)
        if ok then slot.duo = duo end
    end
    -- 時間到：引擎通知，不必自己算（實體在下面，見檔案上方的前置宣告）
    cd:SetScript("OnCooldownDone", function()
        if OnSlotExpired then OnSlotExpired(slotIndex) end
    end)
    return slot
end

-- 顯示順序：土/火對調（沿用使用者原本的習慣）
local function DisplayOrder()
    local db = GetDB()
    local order = {}
    for i = 1, NUM_SLOTS do order[i] = i end
    if db.swapEarthFire then
        order[1], order[2] = 2, 1
    end
    return order
end

-- 框固定四格寬、圖騰從左往右緊排：數量增減時位置不會飄
local function FrameSize()
    local db = GetDB()
    local size = db.frame.iconSize or 28
    local spacing = db.frame.spacing or 4
    return NUM_SLOTS * size + (NUM_SLOTS - 1) * spacing, size
end

local function Relayout()
    local db = GetDB()
    local spacing = db.frame.spacing or 4
    local prev
    for _, i in ipairs(DisplayOrder()) do
        local slot = slots[i]
        if slot and slot.active then
            slot.btn:ClearAllPoints()
            if not prev then
                slot.btn:SetPoint("LEFT", frame, "LEFT", 0, 0)
            else
                slot.btn:SetPoint("LEFT", prev, "RIGHT", spacing, 0)
            end
            prev = slot.btn
        end
    end
    frame:SetSize(FrameSize())
end

-- 把這一格的倒數交給引擎。start/duration 可能是秘密值 —— 全程只寫不讀。
--
-- ⚠ modRate 是 GetTotemInfo 的**第 6 個回傳**，以前整支程式都忽略它。
-- 有些召喚物的計時會被急速之類的東西加速，漏掉的話倒數會跟實際走鐘。
local function ArmTimer(slot, startTime, duration, modRate)
    local duo = slot.duo
    if not (duo and duo.SetTimeFromStart) then
        -- 沒有 duration 物件（理論上 12.1 一定有）：退回滿條、無數字，
        -- 靠 PLAYER_TOTEM_UPDATE 收。這是舊行為，不會更糟。
        slot.bar:SetMinMaxValues(0, 1)
        slot.bar:SetValue(1)
        if slot.cd then slot.cd:Clear() end
        return
    end
    -- C 端 setter，吃秘密值。⚠ 寫完不要再問它任何事（IsZero/GetTotalDuration 會炸）
    pcall(duo.SetTimeFromStart, duo, startTime, duration, modRate)
    if slot.bar.SetTimerDuration and TIMER_DIR then
        slot.bar:SetMinMaxValues(0, 1)
        slot.bar:SetTimerDuration(duo, nil, TIMER_DIR)
    end
    if slot.cd then
        slot.cd:SetCooldownFromDurationObject(duo)
        slot.cd:SetHideCountdownNumbers(GetDB().showTimeText == false)
    end
end

------------------------------------------------------------
-- 設定用的示範內容
--
-- 沒放召喚物時這個框是空的，開設定調位置／大小等於在對著空氣調。
-- 打開「召喚物」分頁時填四格假資料（含會跑的時間條與倒數），關掉就回真實狀態。
------------------------------------------------------------
local DEMO = {
    { icon = "Interface\\Icons\\spell_nature_stoneskintotem",  dur = 60 },
    { icon = "Interface\\Icons\\spell_fire_searingtotem",      dur = 40 },
    { icon = "Interface\\Icons\\spell_nature_manaregentotem",  dur = 25 },
    { icon = "Interface\\Icons\\spell_nature_windfury",        dur = 12 },
}

local function Poll()
    local db = GetDB()
    if not db.enabled then
        if frame then frame:Hide() end
        return
    end
    local anyActive = false
    for i = 1, NUM_SLOTS do
        local slot = slots[i]
        if not slot then
            slots[i] = CreateSlot(i)
            slot = slots[i]
        end
        local startTime, duration, icon, modRate
        if previewOn then
            local d = DEMO[i]
            icon, duration = d.icon, d.dur
            startTime = GetTime()          -- 跑完由 OnCooldownDone 續下一輪
        else
            local _
            _, _, startTime, duration, icon, modRate = GetTotemInfo(i)
        end
        -- icon 是明文（字串路徑或數字 fileID），當存在 proxy——haveTotem 是秘密
        -- boolean 不能測。判斷式用 truthiness + ~= ""（數字 fileID 也成立）
        if icon and icon ~= "" then
            slot.active = true
            slot.icon:SetTexture(icon)
            local c = SlotColor(i)
            slot.bar:SetStatusBarColor(c.r, c.g, c.b, 1)
            ArmTimer(slot, startTime, duration, modRate)
            slot.btn:Show()
            anyActive = true
        else
            slot.active = false
            slot.btn:Hide()
        end
    end
    Relayout()
    -- 沒有 ticker：進度條與數字都是引擎在跑，過期由 OnCooldownDone 通知
    frame:SetShown(anyActive)
end

------------------------------------------------------------
-- 倒數結束（引擎通知）
------------------------------------------------------------
function OnSlotExpired(i)
    local slot = slots[i]
    if not slot then return end
    if previewOn then
        -- 預覽：續下一輪，讓時間條與數字一直看得到在動
        local d = DEMO[i]
        if d then ArmTimer(slot, GetTime(), d.dur) end
        return
    end
    if slot.active then
        slot.active = false
        slot.btn:Hide()
        Relayout()
        -- 全空了就收框（原本靠 Poll 的 anyActive 判斷，現在這裡也要顧到）
        for _, s2 in pairs(slots) do
            if s2.active then return end
        end
        if frame then frame:Hide() end
    end
end

-- 錨點語意與資源條同一組：TOPLEFT 對玩家框 BOTTOMLEFT（往下是負的）。
-- 這樣玩家框一搬家召喚物就自己跟著走，不必再把玩家框座標算進預設值裡。
local function AnchorTo(x, y)
    if not frame then return end
    local anchor = ns.frames and ns.frames.player
    frame:ClearAllPoints()
    if anchor then
        frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", ns.P.Scale(x or 0), ns.P.Scale(y or 0))
    else
        -- 玩家框還沒生出來時沒有基準點，先掛畫面中心，之後 ApplyPosition 會再校正
        frame:SetPoint("CENTER", UIParent, "CENTER", ns.P.Scale(x or 0), ns.P.Scale(y or 0))
    end
end
ns.TotemsAnchorTo = AnchorTo     -- 編輯模式拖曳中即時定位用

local function ApplyPosition()
    local db = GetDB()
    AnchorTo(db.frame.x, db.frame.y)
    -- 層級跟著全域設定走（Init 只設一次，改了設定要在這裡重套，不然要 /reload 才生效）
    if frame then frame:SetFrameStrata(ns.db.global.strata or "LOW") end
end

local function Init()
    if frame then return end
    local db = GetDB()
    if not db or not db.enabled then return end

    frame = CreateFrame("Frame", "MiliUIUF_Totem", UIParent)
    frame:SetSize(FrameSize())
    frame:SetFrameStrata(ns.db.global.strata or "LOW")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    ApplyPosition()

    ns.totemFrame = frame
    ns.Events.Register("PLAYER_TOTEM_UPDATE", "totems", Poll)
    ns.Events.Register("PLAYER_ENTERING_WORLD", "totems_pew", Poll)
    Poll()
end

-- 設定面板的「召喚物」分頁進出時呼叫
function ns.TotemsSetPreview(on)
    on = on and true or false
    if previewOn == on then return end
    previewOn = on
    if not frame then Init() end
    if frame then Poll() end
end

ns.RegisterCallback("Loaded", "totems", Init)
ns.TotemsApplySettings = function()
    if not frame then Init(); return end
    ApplyPosition()
    for i = 1, NUM_SLOTS do
        if slots[i] then
            slots[i].btn:Hide()
            slots[i] = nil
        end
    end
    Poll()
end
