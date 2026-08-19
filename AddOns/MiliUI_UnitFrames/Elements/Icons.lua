------------------------------------------------------------
-- 小圖示：團隊標記 / 狀態（戰鬥/休息）/ 隊長 / PvP
-- 團隊標記 index 可能是秘密值 → SetRaidTargetIconTexture 吃秘密值（C 端）
------------------------------------------------------------
local _, ns = ...

local ToBool = ns.ToBool

-- PvP 圖示的陣營貼圖。只有這幾張，路徑寫死成常數不必每次串接。
-- ⚠ 中立（還沒選邊的熊貓人）UnitFactionGroup 回 "Neutral"，但暴雪沒有
-- UI-PVP-Neutral 這張圖 —— 自由混戰用的是 FFA。
local PVP_TEXTURE = {
    Alliance = "Interface\\TargetingFrame\\UI-PVP-Alliance",
    Horde    = "Interface\\TargetingFrame\\UI-PVP-Horde",
    FFA      = "Interface\\TargetingFrame\\UI-PVP-FFA",
    Neutral  = "Interface\\TargetingFrame\\UI-PVP-FFA",
}

local STATE_ICON = "Interface\\CharacterFrame\\UI-StateIcon"

------------------------------------------------------------
-- 休息 zzZ 用暴雪 PlayerFrame 的動畫（PlayerRestLoop）：
--   atlas UI-HUD-UnitFrame-Player-Rest-Flipbook，整張 360×420＝6 行 7 列、
--   每格 60×60 共 42 格，1.5 秒循環
-- 逐格動畫一律走 FlipBook 動畫型別。12.1 已經拿掉 AnimateTexCoords 全域，
-- 用它每幀報錯（見 LibCustomGlow 那次）
--
-- 戰鬥圖示兩種可選（設定 combatBlizzard）：
--   預設 UI-StateIcon 的交叉刀劍，形狀清楚，缺點是留白多 → 放大補回來
--   內建 UI-HUD-UnitFrame-Player-CombatIcon（PlayerFrame 的 AttackIcon）
--        只有 16×16，暴雪是 useAtlasSize 原尺寸貼、靠整數像素對齊才看得清楚；
--        縮到 14×14 這種非整數比例就糊成一塊藍方塊。所以這個模式一律畫原尺寸，
--        不吃小圖示的寬高設定
------------------------------------------------------------
local REST_ATLAS   = "UI-HUD-UnitFrame-Player-Rest-Flipbook"
local COMBAT_ATLAS = "UI-HUD-UnitFrame-Player-CombatIcon"
local REST_ROWS, REST_COLS, REST_FRAMES, REST_DURATION = 7, 6, 42, 1.5

-- 各張圖的留白不一樣，放大倍率分開給，目標是「看得到的圖案」一樣大：
--   zzZ 每格 60×60 但暴雪只畫 30×30，四周都是 z 飄出去的動作留白
--   UI-StateIcon 的刀劍在自己那格裡約留兩成白
local OVERSIZE = { restanim = 1.5, combat = 1.35 }

-- 預覽用的假團隊標記：每個單位給不同號碼，一眼分得出是哪一格
local PREVIEW_MARK = {
    player = 1, target = 8, targettarget = 2, focus = 7,
    focustarget = 3, pet = 6, boss = 8,
}

local atlasCache = {}
local function AtlasInfo(name)
    local v = atlasCache[name]
    if v == nil then
        v = (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)) or false
        atlasCache[name] = v
    end
    return v or nil
end

local function StopRestAnim(holder)
    if holder and holder.restAnim then holder.restAnim:Stop() end
end

local function EnsureRestAnim(holder)
    if holder.restAnim then return holder.restAnim end
    local ag = holder:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    local fb = ag:CreateAnimation("FlipBook")
    fb:SetChildKey("tex")          -- 對應 holder.tex，同暴雪的 childKey="RestTexture"
    fb:SetOrder(1)
    fb:SetSmoothing("NONE")
    fb:SetDuration(REST_DURATION)
    fb:SetFlipBookRows(REST_ROWS)
    fb:SetFlipBookColumns(REST_COLS)
    fb:SetFlipBookFrames(REST_FRAMES)
    fb:SetFlipBookFrameWidth(0)    -- 0 = 由列/行數自動推算
    fb:SetFlipBookFrameHeight(0)
    holder.restAnim = ag
    return ag
end

-- 狀態圖示三種畫法，切換時錨點／貼圖／texcoord 全部要重設：
-- flipbook 停下來會把 texcoord 留在最後一格，不重設就會殘留半個 zzZ
local function SetStatusMode(holder, idb, mode)
    if holder.statusMode == mode then return end
    holder.statusMode = mode

    local info = (mode == "combatblz") and AtlasInfo(COMBAT_ATLAS)
    local k = OVERSIZE[mode]
    holder.tex:ClearAllPoints()
    if info then
        holder.tex:SetPoint("CENTER")
        holder.tex:SetSize(info.width, info.height)   -- 原尺寸，不過 P.Scale
    elseif k then
        holder.tex:SetPoint("CENTER")
        holder.tex:SetSize(ns.P.Scale((idb.w or 16) * k), ns.P.Scale((idb.h or 16) * k))
    else
        holder.tex:SetAllPoints(holder)
    end

    if mode == "restanim" then
        holder.tex:SetAtlas(REST_ATLAS)
    elseif mode == "combatblz" then
        holder.tex:SetAtlas(COMBAT_ATLAS)
    elseif mode == "combat" then
        holder.tex:SetTexture(STATE_ICON)
        holder.tex:SetTexCoord(0.5, 1, 0, 0.484)
    else                                    -- "rest"：沒有 flipbook 時的靜態 zzZ
        holder.tex:SetTexture(STATE_ICON)
        holder.tex:SetTexCoord(0, 0.5, 0, 0.421875)
    end
end

local function EnsureIcon(uf, key, layer)
    uf.iconTextures = uf.iconTextures or {}
    local holder = uf.iconTextures[key]
    if not holder then
        holder = CreateFrame("Frame", nil, uf.elements.icons)
        holder.tex = holder:CreateTexture(nil, layer or "OVERLAY")
        holder.tex:SetAllPoints(holder)
        uf.iconTextures[key] = holder
    end
    return holder
end

local function PlaceIcon(uf, holder, idb)
    holder:SetSize(ns.P.Scale(idb.w or 16), ns.P.Scale(idb.h or 16))
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", uf, "TOPLEFT", ns.P.Scale(idb.x or 0), ns.P.Scale(idb.y or 0))
    holder:SetFrameLevel(idb.level or 10)
end

-- 每種小圖示：啟用 → 建立/定位；停用 → 既有 holder 一定要藏（不然取消勾選不會消失）
local function SetupIcon(uf, key, idb, texture, extraGate)
    local on = idb and idb.enabled and (extraGate ~= false)
    if on then
        local h = EnsureIcon(uf, key)
        PlaceIcon(uf, h, idb)
        if texture then h.tex:SetTexture(texture) end
        StopRestAnim(h)
        h.statusMode = nil   -- 尺寸／設定可能剛改過，強迫 Update 重套一次畫法
        h:Hide()      -- 先藏，Update 依狀態決定顯示
        h.disabled = nil
    elseif uf.iconTextures and uf.iconTextures[key] then
        StopRestAnim(uf.iconTextures[key])
        uf.iconTextures[key]:Hide()
        uf.iconTextures[key].disabled = true
    end
end

local function Build(uf, edb)
    -- ⚠ 登記 uf.elements.icons（Refresh 派發閘門），同 Texts 的教訓
    if not uf.elements.icons then
        local holder = CreateFrame("Frame", nil, uf)
        holder:SetAllPoints(uf)
        uf.elements.icons = holder
    end
    uf.elements.icons:Show()
    SetupIcon(uf, "raidtarget", edb.raidtarget, "Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    -- 貼圖不在這裡設：SetStatusMode 會依戰鬥／休息挑圖，先塞一張只會馬上被換掉
    SetupIcon(uf, "status", edb.status, nil, uf.unitKey == "player")
    SetupIcon(uf, "leader", edb.leader, "Interface\\GroupFrame\\UI-Group-LeaderIcon")
    SetupIcon(uf, "pvp", edb.pvp, nil)
end

local function Update(uf, edb, bucket)
    if not uf.iconTextures then return end
    local preview = uf.isPreview
    local unit = preview and "player" or uf.unit

    local rt = uf.iconTextures.raidtarget
    if rt and not rt.disabled and edb.raidtarget and edb.raidtarget.enabled then
        -- 預覽查的是玩家自己的狀態：沒被標記就什麼都不畫，等於對著空氣調位置
        -- → 有開就一律畫出來，團標每個單位給不同號碼比較好認
        local index = preview and (PREVIEW_MARK[uf.unitKey] or 1) or GetRaidTargetIndex(unit)
        if index ~= nil then                          -- nil-ness 對秘密值可讀
            SetRaidTargetIconTexture(rt.tex, index)   -- C 端吃秘密 index
            rt:Show()
        else
            rt:Hide()
        end
    end

    local st = uf.iconTextures.status
    if st and not st.disabled and edb.status and edb.status.enabled then
        if UnitAffectingCombat("player") then
            StopRestAnim(st)
            local blz = edb.status.combatBlizzard and AtlasInfo(COMBAT_ATLAS)
            SetStatusMode(st, edb.status, blz and "combatblz" or "combat")
            st:Show()
        elseif IsResting() or preview then           -- 預覽沒在戰鬥就畫 zzZ，總得看得到
            -- 動畫版：設定關掉、或這版遊戲沒這張 atlas 時退回靜態 zzZ
            local animate = edb.status.restAnimated ~= false and AtlasInfo(REST_ATLAS)
            SetStatusMode(st, edb.status, animate and "restanim" or "rest")
            st:Show()
            if animate then
                local ag = EnsureRestAnim(st)
                if not ag:IsPlaying() then ag:Play() end
            else
                StopRestAnim(st)
            end
        else
            StopRestAnim(st)
            st:Hide()
        end
    end

    local ld = uf.iconTextures.leader
    if ld and not ld.disabled and edb.leader and edb.leader.enabled then
        if preview or ToBool(UnitIsGroupLeader(unit)) then   -- 12.1 秘密 boolean → ToBool
            ld:Show()
        else
            ld:Hide()
        end
    end

    local pvp = uf.iconTextures.pvp
    if pvp and not pvp.disabled and edb.pvp and edb.pvp.enabled then
        local faction = ns.Desecret(UnitFactionGroup(unit), nil) or (preview and "Alliance")
        if faction and (preview or ToBool(UnitIsPVP(unit))) then
            -- 兩條完整路徑寫成常數：這條路徑每次 reaction 桶更新都會重建字串，
            -- 而 GROUP_ROSTER_UPDATE 會把全部 11 個框掃一遍。
            -- 中立（未選邊的熊貓人）沒有 UI-PVP-Neutral 這張圖，暴雪慣例是走 FFA。
            pvp.tex:SetTexture(PVP_TEXTURE[faction] or PVP_TEXTURE.FFA)
            pvp.tex:SetTexCoord(0, 0.62, 0, 0.62)
            pvp:Show()
        else
            pvp:Hide()
        end
    end
end

ns.RegisterElement{
    name = "icons",
    order = 70,
    -- reaction：隊長圖示吃 GROUP_ROSTER_UPDATE、PvP 圖示吃 UNIT_FACTION，
    -- 兩個都在 reaction 桶。其餘（團標／戰鬥休息）自己掛事件
    buckets = { "reaction" },
    build = Build,
    update = Update,
}

-- 團隊標記與玩家狀態的全域事件（只重畫 icons 元件，不做全量刷新）
local function UpdateIconsOnly(uf)
    if not (uf and uf.iconTextures and uf:IsVisible()) then return end
    local edb = uf.db.elements.icons
    if edb and edb.enabled ~= false then Update(uf, edb, "unitchanged") end
end

ns.Events.Register("RAID_TARGET_UPDATE", "icons", function()
    for _, uf in pairs(ns.frames) do
        UpdateIconsOnly(uf)
    end
end)
ns.Events.Register("PLAYER_REGEN_DISABLED", "icons_combat", function()
    UpdateIconsOnly(ns.frames.player)
end)
ns.Events.Register("PLAYER_REGEN_ENABLED", "icons_combat2", function()
    UpdateIconsOnly(ns.frames.player)
end)
ns.Events.Register("PLAYER_UPDATE_RESTING", "icons_rest", function()
    UpdateIconsOnly(ns.frames.player)
end)
