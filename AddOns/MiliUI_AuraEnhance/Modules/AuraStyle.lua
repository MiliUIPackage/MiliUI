------------------------------------------------------------
-- 光環時間文字／堆疊層數樣式
--
-- 調整暴雪增益／減益圖示的時間文字與層數文字的字型、大小、描邊與位置，
-- **不修改文字內容**。
--
-- 策略：hook 每個 FontString 的 SetPoint / SetFontObject / SetText。
-- 暴雪每次重設時 hook 立刻覆寫回我們的樣式，零延遲零抖動——比起用 OnUpdate
-- 每幀去校正，這樣既不會抖也幾乎沒有成本（只有暴雪真的動它時才跑）。
------------------------------------------------------------
local _, ns = ...

local Media = ns.Media

ns.AuraStyle = {}
local AuraStyle = ns.AuraStyle

-- ns.db.duration / ns.db.count。hook 是熱路徑，抓成 upvalue 少兩層查表。
-- ⚠ DB.ResetAll 只覆寫這兩張表的內容、不換表，就是為了這裡。
local DUR, CNT

------------------------------------------------------------
-- 字型
------------------------------------------------------------
-- 安全套用字型：路徑失效（例：LSM 字型被移除）時退回在地化預設字型，
-- 不然 SetFont 失敗會讓那行文字整個消失
local function SetFontSafe(fs, path, size, flags)
    if not path or path == "" then return false end
    if fs:SetFont(path, size, flags) then return true end
    return fs:SetFont(Media.DEFAULT_FONT, size, flags)
end

-- 時間文字的字型路徑：沒選自訂字型就沿用暴雪原本那支
local function DurationFontPath(dur)
    local custom = Media.OptionalFont(DUR.font)
    if custom then return custom end
    local orig = dur.MiliUIAura_origFont
    if orig and orig[1] then return orig[1] end
    return (dur:GetFont()) or Media.DEFAULT_FONT
end

-- 套用層數的自訂字型（保留暴雪原本的大小與旗標，只換字體）
local function ApplyCountFont(cnt)
    local path = Media.OptionalFont(CNT.font)
    if not path then return false end
    local _, size, flags = cnt:GetFont()
    SetFontSafe(cnt, path, size or 14, flags or "")
    return true
end

-- 還原成記下來的暴雪原字型
local function RestoreOrigFont(fs)
    if not fs.MiliUIAura_fontApplied then return end
    local orig = fs.MiliUIAura_origFont
    if orig and orig[1] then
        fs:SetFont(orig[1], orig[2] or 14, orig[3] or "")
    end
    fs.MiliUIAura_fontApplied = false
end

------------------------------------------------------------
-- 每個 FontString 的 reactive hook
------------------------------------------------------------
-- Weak keys：暴雪回收按鈕時 FontString 被 GC，這裡的 entry 自動消失
local hookedDurations = setmetatable({}, { __mode = "k" })
local hookedCounts    = setmetatable({}, { __mode = "k" })

-- 遞歸防護（WoW 單執行緒，單一 flag 即可）
local overriding = false

-- 文字要壓在圖示上方，但 FontString 的繪製層改不贏子框——所以掛一個 level 更高的
-- 空框當家（見 .claude/notes 的「frame 與貼圖的疊層」）
local function EnsureOverlay(btn)
    local ov = btn.MiliUIAura_Overlay
    if ov then return ov end
    ov = CreateFrame("Frame", nil, btn)
    ov:SetAllPoints(btn)
    ov:SetFrameLevel(btn:GetFrameLevel() + 5)
    btn.MiliUIAura_Overlay = ov
    return ov
end

local function HookDuration(btn)
    if btn.isAuraAnchor then return end
    local dur = btn.Duration
    if not dur or hookedDurations[dur] then return end

    -- 記下暴雪原本的字型，選「沿用暴雪字型」時才有東西可以還原
    dur.MiliUIAura_origFont = dur.MiliUIAura_origFont or { dur:GetFont() }

    -- SetPoint：暴雪每次重設位置時我們立刻覆寫
    hooksecurefunc(dur, "SetPoint", function(self)
        if overriding or not DUR or not DUR.enabled then return end

        overriding = true
        self:SetParent(EnsureOverlay(btn))
        self:ClearAllPoints()
        self:SetPoint("TOP", btn.Icon, "BOTTOM", 0, DUR.yOffset)
        overriding = false
    end)

    -- SetFontObject：暴雪切換字型物件時我們覆寫回自訂字型
    hooksecurefunc(dur, "SetFontObject", function(self)
        if overriding or not DUR or not DUR.enabled then return end

        overriding = true
        SetFontSafe(self, DurationFontPath(self), DUR.fontSize, DUR.outline and "OUTLINE" or "")
        self.MiliUIAura_fontApplied = true
        if DUR.outline then
            self:SetShadowOffset(1, -1)
            self:SetShadowColor(0, 0, 0, 0.6)
        else
            self:SetShadowOffset(0, 0)
        end
        overriding = false
    end)

    hookedDurations[dur] = true
end

local function HookCount(btn)
    if btn.isAuraAnchor then return end
    local cnt = btn.Count
    if not cnt or hookedCounts[cnt] then return end

    cnt.MiliUIAura_origFont = cnt.MiliUIAura_origFont or { cnt:GetFont() }

    -- SetPoint 與 SetText 做同一件事（層數變動時位置不能跑掉）——共用 closure
    local function reapply(self)
        if overriding or not CNT or not CNT.enabled then return end

        overriding = true
        self:SetParent(EnsureOverlay(btn))
        self:SetWidth(0)
        self:ClearAllPoints()
        self:SetPoint(CNT.anchor, btn.Icon, CNT.anchor, CNT.x, CNT.y)
        if ApplyCountFont(self) then self.MiliUIAura_fontApplied = true end
        overriding = false
    end

    hooksecurefunc(cnt, "SetPoint", reapply)
    hooksecurefunc(cnt, "SetText",  reapply)

    hooksecurefunc(cnt, "SetFontObject", function(self)
        if overriding or not CNT or not CNT.enabled then return end

        overriding = true
        if ApplyCountFont(self) then self.MiliUIAura_fontApplied = true end
        overriding = false
    end)

    hookedCounts[cnt] = true
end

------------------------------------------------------------
-- 主動套用 / 還原（給初始化和設定變更用）
------------------------------------------------------------
local function ApplyDurationStyle(btn)
    local dur = btn.Duration
    if not dur or not dur:IsShown() then return end

    overriding = true

    dur:SetParent(EnsureOverlay(btn))
    SetFontSafe(dur, DurationFontPath(dur), DUR.fontSize, DUR.outline and "OUTLINE" or "")
    dur.MiliUIAura_fontApplied = true

    if DUR.outline then
        dur:SetShadowOffset(1, -1)
        dur:SetShadowColor(0, 0, 0, 0.6)
    else
        dur:SetShadowOffset(0, 0)
    end

    dur:ClearAllPoints()
    dur:SetPoint("TOP", btn.Icon, "BOTTOM", 0, DUR.yOffset)

    overriding = false
end

local function RestoreDurationStyle(btn)
    local dur = btn.Duration
    if not dur then return end

    overriding = true

    -- 不 re-parent：overlay 與 btn 同區域，直接還原位置和字型即可。
    -- re-parent 回去會讓 WoW 的渲染出問題（踩過）。
    RestoreOrigFont(dur)
    if DEFAULT_AURA_DURATION_FONT then
        dur:SetFontObject(DEFAULT_AURA_DURATION_FONT)
    end

    dur:SetShadowOffset(0, 0)
    dur:SetShadowColor(0, 0, 0, 1)
    dur:ClearAllPoints()
    dur:SetPoint("TOP", btn, "BOTTOM", 0, -2)

    overriding = false
end

local function ApplyCountStyle(btn)
    local cnt = btn.Count
    if not cnt or not cnt:IsShown() then return end

    overriding = true
    cnt:SetParent(EnsureOverlay(btn))
    cnt:SetWidth(0)
    cnt:ClearAllPoints()
    cnt:SetPoint(CNT.anchor, btn.Icon, CNT.anchor, CNT.x, CNT.y)
    -- 字型：有自訂就套用，選回「沿用暴雪字型」則還原
    if ApplyCountFont(cnt) then
        cnt.MiliUIAura_fontApplied = true
    else
        RestoreOrigFont(cnt)
    end
    overriding = false
end

local function RestoreCountStyle(btn)
    local cnt = btn.Count
    if not cnt then return end

    overriding = true
    -- 同樣不 re-parent
    cnt:SetWidth(0)
    cnt:ClearAllPoints()
    cnt:SetPoint("BOTTOMRIGHT", btn.Icon, "BOTTOMRIGHT", -2, 2)
    RestoreOrigFont(cnt)
    overriding = false
end

-- { 容器, 是不是減益 }。外觀樣式那邊要分增益／減益兩個群組，所以這裡要把來源帶出去。
local function Containers()
    return { { BuffFrame, false }, { DebuffFrame, true } }
end

local function ForEachAuraButton(func)
    for _, entry in ipairs(Containers()) do
        local container, isDebuff = entry[1], entry[2]
        if container and container.AuraContainer then
            for _, btn in ipairs({ container.AuraContainer:GetChildren() }) do
                if btn.Icon and not btn.isAuraAnchor then
                    func(btn, isDebuff)
                end
            end
        end
    end
end

------------------------------------------------------------
-- 安裝 hooks
------------------------------------------------------------
local function InstallHooks()
    -- 先掛 UpdateGridLayout 攔截未來新建的按鈕
    for _, entry in ipairs(Containers()) do
        local container, isDebuff = entry[1], entry[2]
        if container and container.AuraContainer then
            hooksecurefunc(container.AuraContainer, "UpdateGridLayout", function(_, auras)
                if not auras then return end
                for _, aura in ipairs(auras) do
                    if aura and aura.Icon and not aura.isAuraAnchor then
                        ns.Skin.OnButton(aura, isDebuff)
                        if aura.Duration then HookDuration(aura) end
                        if aura.Count    then HookCount(aura) end
                    end
                end
            end)
        end
    end

    -- 現有按鈕：掛 hook ＋ 立刻套用（單次迭代）
    -- 停用時什麼都不做：這時候還沒動過任何東西，跑 Restore 反而是拿我們猜的
    -- 「暴雪預設」去蓋掉暴雪真正的預設。
    -- ⚠ 外觀樣式要排在文字樣式前面：它會把層數搬到自己的包裝框，
    --   文字樣式接著才把層數搬到覆蓋層（我們的位置設定要贏）。
    ForEachAuraButton(function(btn, isDebuff)
        ns.Skin.OnButton(btn, isDebuff)
        if btn.Duration then
            HookDuration(btn)
            if DUR.enabled then ApplyDurationStyle(btn) end
        end
        if btn.Count then
            HookCount(btn)
            if CNT.enabled then ApplyCountStyle(btn) end
        end
    end)
end

------------------------------------------------------------
-- 對外：設定改完一律叫這支（設定頁的 ctx.apply 就是它）
------------------------------------------------------------
-- 讓別的模組共用同一條列舉路徑（外觀樣式要用），不要各掃各的
AuraStyle.ForEach = ForEachAuraButton

function AuraStyle.Apply()
    if not DUR then return end
    ForEachAuraButton(function(btn)
        if DUR.enabled then ApplyDurationStyle(btn) else RestoreDurationStyle(btn) end
        if CNT.enabled then ApplyCountStyle(btn) else RestoreCountStyle(btn) end
    end)
end

------------------------------------------------------------
-- 啟動
-- Init（PLAYER_LOGIN）：接上設定
-- PLAYER_ENTERING_WORLD：暴雪的 BuffFrame 完成首輪佈局之後才掛 hook
------------------------------------------------------------
ns.RegisterCallback("Init", "auraStyle", function()
    DUR, CNT = ns.db.duration, ns.db.count

    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_ENTERING_WORLD")
    loader:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        InstallHooks()
    end)
end)
