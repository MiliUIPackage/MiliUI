local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local _, YUI = ...
local Animation = YUI.Animation
if not Animation then return end

local Handle = Animation.Handle or {}
Handle.__index = Handle
Animation.Handle = Handle

local TARGET_DEFAULT_KEY = "__default"

local function CountTable(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do
        count = count + 1
    end
    return count
end

local function SafeCall(callback, ...)
    if type(callback) ~= "function" then
        return
    end

    local ok, err = pcall(callback, ...)
    if not ok and YUI and YUI.Debug then
        YUI:Debug("Animation callback error:", err)
    end
end

function Animation:_TargetKey(key)
    if key == nil or key == "" then
        return TARGET_DEFAULT_KEY
    end
    return key
end

function Animation:_RegisterHandle(handle)
    if type(handle) ~= "table" or handle.noop then
        return handle
    end

    self.handles[handle] = true
    self.activeCount = (self.activeCount or 0) + 1

    if handle.owner ~= nil then
        local ownerBucket = self.byOwner[handle.owner]
        if not ownerBucket then
            ownerBucket = {}
            self.byOwner[handle.owner] = ownerBucket
        end
        ownerBucket[handle] = true
    end

    if handle.target ~= nil then
        local targetBucket = self.byTarget[handle.target]
        if not targetBucket then
            targetBucket = {}
            self.byTarget[handle.target] = targetBucket
        end
        targetBucket[self:_TargetKey(handle.key)] = handle
    end

    if handle.sourceTarget ~= nil and handle.sourceTarget ~= handle.target then
        local sourceBucket = self.byTarget[handle.sourceTarget]
        if not sourceBucket then
            sourceBucket = {}
            self.byTarget[handle.sourceTarget] = sourceBucket
        end
        sourceBucket[self:_TargetKey(handle.key)] = handle
    end

    return handle
end

function Animation:_UnregisterHandle(handle)
    if type(handle) ~= "table" or handle.noop or not self.handles[handle] then
        return
    end

    self.handles[handle] = nil
    self.activeCount = math.max(0, (self.activeCount or 1) - 1)

    if handle.owner ~= nil then
        local ownerBucket = self.byOwner[handle.owner]
        if ownerBucket then
            ownerBucket[handle] = nil
            if next(ownerBucket) == nil then
                self.byOwner[handle.owner] = nil
            end
        end
    end

    if handle.target ~= nil then
        local targetBucket = self.byTarget[handle.target]
        if targetBucket then
            local key = self:_TargetKey(handle.key)
            if targetBucket[key] == handle then
                targetBucket[key] = nil
            end
            if next(targetBucket) == nil then
                self.byTarget[handle.target] = nil
            end
        end
    end

    if handle.sourceTarget ~= nil and handle.sourceTarget ~= handle.target then
        local sourceBucket = self.byTarget[handle.sourceTarget]
        if sourceBucket then
            local key = self:_TargetKey(handle.key)
            if sourceBucket[key] == handle then
                sourceBucket[key] = nil
            end
            if next(sourceBucket) == nil then
                self.byTarget[handle.sourceTarget] = nil
            end
        end
    end
end

function Animation:CreateHandle(driver, target, spec)
    spec = type(spec) == "table" and spec or {}
    self.nextId = (self.nextId or 0) + 1

    local handle = setmetatable({
        id = self.nextId,
        animation = self,
        driver = driver,
        target = target,
        sourceTarget = spec.sourceTarget,
        owner = spec.owner,
        key = spec.key,
        spec = spec,
        state = "idle",
        createdAt = self:Now(),
        onFinished = spec.onFinished,
        onStop = spec.onStop,
    }, Handle)

    return self:_RegisterHandle(handle)
end

function Animation:Noop(reason, target, spec)
    spec = type(spec) == "table" and spec or {}
    return setmetatable({
        animation = self,
        noop = true,
        reason = reason or "noop",
        target = target,
        owner = spec.owner,
        key = spec.key,
        spec = spec,
        state = "noop",
    }, Handle)
end

function Handle:Play()
    if self.noop then
        return self
    end
    if self.state == "playing" then
        return self
    end

    self.state = "playing"
    if self.driver and self.driver.Play then
        self.driver:Play(self)
    end
    return self
end

function Handle:Stop(finish)
    if self.noop or self._completed then
        return self
    end
    if finish then
        return self:Finish()
    end

    if self.driver and self.driver.Stop then
        self.driver:Stop(self, false)
    end
    self:_Complete("stopped", false)
    return self
end

function Handle:Finish()
    if self.noop or self._completed then
        return self
    end

    if self.driver and self.driver.Finish then
        self.driver:Finish(self)
    elseif self.driver and self.driver.Stop then
        self.driver:Stop(self, true)
    end
    self:_Complete("finished", true)
    return self
end

function Handle:Cancel()
    if self.noop or self._completed then
        return self
    end

    if self.driver and self.driver.Stop then
        self.driver:Stop(self, false)
    end
    self:_Complete("cancelled", false)
    return self
end

function Handle:Pause()
    if self.noop or self._completed or self.state ~= "playing" then
        return self
    end

    if self.driver and self.driver.Pause then
        self.driver:Pause(self)
    end
    self.state = "paused"
    return self
end

function Handle:Resume()
    if self.noop or self._completed or self.state ~= "paused" then
        return self
    end

    self.state = "playing"
    if self.driver and self.driver.Resume then
        self.driver:Resume(self)
    end
    return self
end

function Handle:IsPlaying()
    return self.state == "playing"
end

function Handle:_Complete(reason, finished)
    if self._completed then
        return self
    end

    self._completed = true
    self.state = reason or "finished"
    if self.animation and self.animation._UnregisterHandle then
        self.animation:_UnregisterHandle(self)
    end

    if finished then
        SafeCall(self.onFinished, self, reason or "finished", true)
    else
        SafeCall(self.onStop, self, reason or "stopped", false)
        SafeCall(self.onFinished, self, reason or "stopped", false)
    end
    if self.animation and self.animation.SettleTarget then
        self.animation:SettleTarget(self.target, true)
        if self.spec and self.spec.sourceTarget and self.spec.sourceTarget ~= self.target then
            self.animation:SettleTarget(self.spec.sourceTarget, true)
        end
    end
    return self
end

function Animation:StopTarget(target, key, finish)
    local targetBucket = self.byTarget[target]
    if not targetBucket then
        return 0
    end

    local stopped = 0
    if key ~= nil then
        local handle = targetBucket[self:_TargetKey(key)]
        if handle then
            handle:Stop(finish)
            stopped = stopped + 1
        end
        return stopped
    end

    local handles = {}
    for _, handle in pairs(targetBucket) do
        handles[#handles + 1] = handle
    end
    for _, handle in ipairs(handles) do
        if handle and not handle._completed then
            handle:Stop(finish)
            stopped = stopped + 1
        end
    end
    return stopped
end

function Animation:StopOwner(owner, finish)
    local ownerBucket = self.byOwner[owner]
    if not ownerBucket then
        return 0
    end

    local handles = {}
    for handle in pairs(ownerBucket) do
        handles[#handles + 1] = handle
    end

    local stopped = 0
    for _, handle in ipairs(handles) do
        if handle and not handle._completed then
            handle:Stop(finish)
            stopped = stopped + 1
        end
    end
    return stopped
end

function Animation:GetStats()
    local tweenDriver = self.TweenDriver
    local nativeDriver = self.NativeDriver
    return {
        active = self.activeCount or 0,
        owners = CountTable(self.byOwner),
        targets = CountTable(self.byTarget),
        tweens = tweenDriver and tweenDriver.GetActiveCount and tweenDriver:GetActiveCount() or 0,
        native = nativeDriver and nativeDriver.GetActiveCount and nativeDriver:GetActiveCount() or 0,
    }
end
