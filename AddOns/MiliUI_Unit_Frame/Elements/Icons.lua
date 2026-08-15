------------------------------------------------------------
-- 小圖示：團隊標記 / 狀態（戰鬥/休息）/ 隊長 / PvP
-- 團隊標記 index 可能是秘密值 → SetRaidTargetIconTexture 吃秘密值（C 端）
------------------------------------------------------------
local _, ns = ...

local ToBool = ns.ToBool

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
    holder:SetSize(idb.w or 16, idb.h or 16)
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", uf, "TOPLEFT", idb.x or 0, idb.y or 0)
    holder:SetFrameLevel(idb.level or 10)
end

-- 每種小圖示：啟用 → 建立/定位；停用 → 既有 holder 一定要藏（不然取消勾選不會消失）
local function SetupIcon(uf, key, idb, texture, extraGate)
    local on = idb and idb.enabled and (extraGate ~= false)
    if on then
        local h = EnsureIcon(uf, key)
        PlaceIcon(uf, h, idb)
        if texture then h.tex:SetTexture(texture) end
        h:Hide()      -- 先藏，Update 依狀態決定顯示
        h.disabled = nil
    elseif uf.iconTextures and uf.iconTextures[key] then
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
    SetupIcon(uf, "status", edb.status, "Interface\\CharacterFrame\\UI-StateIcon", uf.unitKey == "player")
    SetupIcon(uf, "leader", edb.leader, "Interface\\GroupFrame\\UI-Group-LeaderIcon")
    SetupIcon(uf, "pvp", edb.pvp, nil)
end

local function Update(uf, edb, bucket)
    if not uf.iconTextures then return end
    local unit = uf.isPreview and "player" or uf.unit

    local rt = uf.iconTextures.raidtarget
    if rt and not rt.disabled and edb.raidtarget and edb.raidtarget.enabled then
        local index = GetRaidTargetIndex(unit)
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
            st.tex:SetTexCoord(0.5, 1, 0, 0.484)
            st:Show()
        elseif IsResting() then
            st.tex:SetTexCoord(0, 0.5, 0, 0.421875)
            st:Show()
        else
            st:Hide()
        end
    end

    local ld = uf.iconTextures.leader
    if ld and not ld.disabled and edb.leader and edb.leader.enabled then
        if ToBool(UnitIsGroupLeader(unit)) then       -- 12.1 秘密 boolean → ToBool
            ld:Show()
        else
            ld:Hide()
        end
    end

    local pvp = uf.iconTextures.pvp
    if pvp and not pvp.disabled and edb.pvp and edb.pvp.enabled then
        local faction = ns.Desecret(UnitFactionGroup(unit), nil)
        if faction and ToBool(UnitIsPVP(unit)) then
            pvp.tex:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. faction)
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
    buckets = {},
    build = Build,
    update = Update,
}

-- 團隊標記與玩家狀態的全域事件（只重畫 icons 元件，不做全量刷新）
local function UpdateIconsOnly(uf)
    if not (uf and uf.iconTextures and uf:IsVisible()) then return end
    local edb = uf.db.elements.icons
    if edb and edb.enabled ~= false then Update(uf, edb, "identity") end
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
