
-------------------------------------
-- InspectCore Author: M
-------------------------------------

local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local LibSchedule = LibStub:GetLibrary("LibSchedule.7000")
local LibItemInfo = LibStub:GetLibrary("LibItemInfo.7000")

local guids, inspecting = {}, false

-- fix from MiliUI: 12.1 對身分受限的單位，UnitGUID / UnitHealthMax 回傳 secret value。
-- secret 不能當 table 的 key，也不能拿來比較，取不到就當作沒有值處理。
local issecretvalue = issecretvalue or function() return false end
local function SafeUnitGUID(unit)
    local guid = unit and UnitGUID(unit)
    if (not guid or issecretvalue(guid)) then return nil end
    return guid
end

-- Global API
function GetInspectInfo(unit, timelimit, checkhp)
    local guid = SafeUnitGUID(unit)
    if (not guid or not guids[guid]) then return end
    if (checkhp) then
        -- fix from MiliUI: 讀不到血量上限時略過這道新鮮度檢查，不要整組資料丟掉
        local hp = UnitHealthMax(unit)
        if (not issecretvalue(hp) and not issecretvalue(guids[guid].hp) and hp ~= guids[guid].hp) then return end
    end
    if (not timelimit or timelimit == 0) then
        return guids[guid]
    end
    if (guids[guid].timer > time()-timelimit) then
        return guids[guid]
    end
end

-- Global API
function GetInspecting()
    if (InspectFrame and InspectFrame.unit) then
        local guid = SafeUnitGUID(InspectFrame.unit)
        return (guid and guids[guid]) or { inuse = true }
    end
    if (inspecting and inspecting.expired > time()) then
        return inspecting
    end
end

-- Global API @trigger UNIT_REINSPECT_READY
function ReInspect(unit)
    local guid = SafeUnitGUID(unit)
    if (not guid) then return end
    local data = guids[guid]
    if (not data) then return end
    LibSchedule:AddTask({
        identity  = guid,
        timer     = 0.5,
        elasped   = 0.5,
        expired   = GetTime() + 3,
        data      = data,
        unit      = unit,
        onExecute = function(self)
            local count, ilevel, _, weaponLevel, isArtifact, maxLevel = LibItemInfo:GetUnitItemLevel(self.unit)
            if (ilevel <= 0) then return true end
            if (count == 0 and ilevel > 0) then
                self.data.timer = time()
                self.data.ilevel = ilevel
                self.data.maxLevel = maxLevel
                self.data.weaponLevel = weaponLevel
                self.data.isArtifact = isArtifact
                LibEvent:trigger("UNIT_REINSPECT_READY", self.data)
                return true
            end
        end,
    })
end

-- Global API
function GetInspectSpec(unit)
    local specID, specName
    if (unit == "player") then
        specID = GetSpecialization()
        specName = select(2, GetSpecializationInfo(specID))
    else
        specID = GetInspectSpecialization(unit)
        if (specID and specID > 0) then
            specName = select(2, GetSpecializationInfoByID(specID))
        end
    end
    return specName or ""
end

-- Clear
hooksecurefunc("ClearInspectPlayer", function()
    inspecting = false
end)

-- @trigger UNIT_INSPECT_STARTED
hooksecurefunc("NotifyInspect", function(unit)
    local guid = SafeUnitGUID(unit)
    if (not guid) then return end
    local data = guids[guid]
    if (data) then
        data.unit = unit
        data.name, data.realm = UnitName(unit)
    else
        data = {
            unit   = unit,
            guid   = guid,
            class  = select(2, UnitClass(unit)),
            level  = UnitLevel(unit),
            ilevel = -1,
            spec   = nil,
            hp     = UnitHealthMax(unit),
            timer  = time(),
        }
        data.name, data.realm = UnitName(unit)
        guids[guid] = data
    end
    if (not data.realm) then
        data.realm = GetRealmName()
    end
    data.expired = time() + 3
    inspecting = data
    LibEvent:trigger("UNIT_INSPECT_STARTED", data)
end)

-- @trigger UNIT_INSPECT_READY
LibEvent:attachEvent("INSPECT_READY", function(this, guid)
    if (not guids[guid]) then return end
    LibSchedule:AddTask({
        identity  = guid,
        timer     = 0.1,
        elasped   = 0.15,
        expired   = GetTime() + 5,
        repeats   = 1,  -- 12.x优先首帧完成，缺数据时由任务循环重试
        data      = guids[guid],
        onTimeout = function(self) inspecting = false end,
        onExecute = function(self)
            local count, ilevel, _, weaponLevel, isArtifact, maxLevel = LibItemInfo:GetUnitItemLevel(self.data.unit)
            if (ilevel <= 0) then return true end
            if (count == 0 and ilevel > 0) then
                --if (UnitIsVisible(self.data.unit) or self.data.ilevel == ilevel) then
                    self.repeats = self.repeats - 1
                    if (self.repeats <= 0) then
                        self.data.timer = time()
                        self.data.name = UnitName(self.data.unit)
                        self.data.class = select(2, UnitClass(self.data.unit))
                        self.data.ilevel = ilevel
                        self.data.maxLevel = maxLevel
                        self.data.spec = GetInspectSpec(self.data.unit)
                        self.data.hp = UnitHealthMax(self.data.unit)
                        self.data.weaponLevel = weaponLevel
                        self.data.isArtifact = isArtifact
                        LibEvent:trigger("UNIT_INSPECT_READY", self.data)
                        inspecting = false
                        return true
                    end
                --else
                --    self.data.ilevel = ilevel
                --    self.data.maxLevel = maxLevel
                --end
            end
        end,
    })
end)
