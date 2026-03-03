local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]
local CDM_C = CDM.CONST

function CDM:InitializeSpecChangeSystem()
    local VIEWERS = CDM_C.VIEWERS
    local isFullSpecChange = false

    local batchHasFullChange = false
    local batchToken = 0
    local talentBatchScheduled = false
    local talentRetryCount = 0
    local talentRetryToken = 0
    local specNilRetryCount = 0
    local specNilRetryToken = 0

    local ProcessSpecChange
    local ShouldUseImmediateQueue

    local function IsTalentDataReady()
        return C_ClassTalents and C_ClassTalents.GetActiveConfigID
            and C_ClassTalents.GetActiveConfigID() ~= nil
    end

    local function BatchTalentEvent(isFullChange)
        if not CDM.loginFinished then
            CDM.loginDeferredFullChange = CDM.loginDeferredFullChange or isFullChange
            return
        end

        talentRetryCount = 0
        talentRetryToken = talentRetryToken + 1
        specNilRetryCount = 0
        specNilRetryToken = specNilRetryToken + 1
        batchToken = batchToken + 1

        self.pendingTalentChange = true

        if isFullChange then
            isFullSpecChange = true
            batchHasFullChange = true
            self.pendingSpecChange = true
            self:InvalidateSpecIDCache()
        end

        if talentBatchScheduled then return end
        talentBatchScheduled = true

        C_Timer.After(0, function()
            if not self.pendingTalentChange then
                batchHasFullChange = false
                talentBatchScheduled = false
                return
            end

            if not batchHasFullChange then
                ProcessSpecChange()
            else
                local myBatchToken = batchToken
                C_Timer.After(0.5, function()
                    if myBatchToken ~= batchToken then return end
                    if self.pendingSpecChange or self.pendingTalentChange then
                        ProcessSpecChange()
                    end
                end)
            end

            batchHasFullChange = false
            talentBatchScheduled = false
        end)
    end

    function CDM:ProcessDeferredLogin()
        if self.loginDeferredFullChange ~= nil then
            local isFullChange = self.loginDeferredFullChange
            self.loginDeferredFullChange = nil
            BatchTalentEvent(isFullChange)
        end
    end

    local lastProcessedSpecID = nil
    local processingInProgress = false
    local specChangeVersion = 0

    ProcessSpecChange = function()
        if processingInProgress then
            return
        end

        local wasFullSpecChange = isFullSpecChange

        local specIndex = GetSpecialization()
        if not specIndex then
            specNilRetryCount = specNilRetryCount + 1
            if specNilRetryCount <= 10 then
                local myToken = specNilRetryToken
                C_Timer.After(0.1, function()
                    if myToken ~= specNilRetryToken then return end
                    if self.pendingTalentChange or self.pendingSpecChange then
                        ProcessSpecChange()
                    end
                end)
            end
            return
        end
        specNilRetryCount = 0
        local currentSpecID = GetSpecializationInfo(specIndex)

        local isSpecSwitch = currentSpecID ~= lastProcessedSpecID

        if not isSpecSwitch and not wasFullSpecChange and not IsTalentDataReady() then
            talentRetryCount = talentRetryCount + 1
            if talentRetryCount <= 20 then
                local myToken = talentRetryToken
                C_Timer.After(0.1, function()
                    if myToken ~= talentRetryToken then return end
                    if self.pendingTalentChange or self.pendingSpecChange then
                        ProcessSpecChange()
                    end
                end)
                return
            end
        end
        talentRetryCount = 0

        processingInProgress = true

        local ok, processingErr = pcall(function()
            if wasFullSpecChange then
                self:InvalidateSpecIDCache()
                self:CheckSpecProfileSwitch(specIndex)
            end
            self:RefreshSpecData()
        end)

        self.pendingTalentChange = false
        self.pendingSpecChange = false
        isFullSpecChange = false
        processingInProgress = false

        if ok then
            lastProcessedSpecID = currentSpecID
            self:RefreshConfig()
        else
            local handler = geterrorhandler and geterrorhandler()
            if handler then handler(processingErr) end
        end

        specChangeVersion = specChangeVersion + 1
        local myVersion = specChangeVersion
        self.queueVersion = myVersion
        table.wipe(self.queue)

        C_Timer.After(0, function()
            if specChangeVersion ~= myVersion then return end
            self:QueueAllViewers(ShouldUseImmediateQueue(), myVersion)
        end)

        if wasFullSpecChange then
            C_Timer.After(0.3, function()
                if specChangeVersion ~= myVersion then return end
                self:QueueAllViewers(ShouldUseImmediateQueue(), myVersion)
            end)
        end

        C_Timer.After(1, function()
            if specChangeVersion ~= myVersion then return end

            local total, populated = 0, 0
            for _, vName in ipairs({VIEWERS.ESSENTIAL, VIEWERS.UTILITY, VIEWERS.BUFF, VIEWERS.BUFF_BAR}) do
                local pop, tot = CDM.CountPopulatedFrames(_G[vName])
                populated = populated + pop
                total = total + tot
            end

            if total > 0 and populated < total then
                self:QueueAllViewers(ShouldUseImmediateQueue(), myVersion)
            end
        end)

        C_Timer.After(0.1, function()
            if specChangeVersion ~= myVersion then return end
            if self.UpdateDefensives then
                self:UpdateDefensives()
            end
            if self.UpdateResources then
                self:UpdateResources()
            end
            if self.UpdatePlayerCastBar then
                self:UpdatePlayerCastBar()
            end
        end)

    end

    function ShouldUseImmediateQueue()
        return self.loginFinished and not self.loadingScreenActive
    end

    local function RegisterTalentBatchEvent(eventName, isFullChange)
        self:RegisterEvent(eventName, function()
            BatchTalentEvent(isFullChange)
        end)
    end

    -- data-ready signal; bypasses batching intentionally
    self:RegisterEvent("SPELLS_CHANGED", function()
        if self.pendingSpecChange or self.pendingTalentChange then
            ProcessSpecChange()
        end
    end)

    self:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player", function()
        BatchTalentEvent(true)
    end)

    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", function()
        BatchTalentEvent(true)
    end)

    RegisterTalentBatchEvent("TRAIT_CONFIG_CREATED", false)
    RegisterTalentBatchEvent("TRAIT_CONFIG_UPDATED", false)
    RegisterTalentBatchEvent("PLAYER_TALENT_UPDATE", false)
    RegisterTalentBatchEvent("PLAYER_PVP_TALENT_UPDATE", false)

    local resourceUpdatePending = false

    local function QueueResourceUpdate()
        if not self.UpdateResourceValues or resourceUpdatePending then
            return
        end

        resourceUpdatePending = true
        C_Timer.After(0, function()
            resourceUpdatePending = false
            if self.UpdateResourceValues then
                self:UpdateResourceValues()
            end
        end)
    end

    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", function()
        if _G[VIEWERS.BUFF] then
            self:QueueViewer(VIEWERS.BUFF)
        end
        if _G[VIEWERS.BUFF_BAR] then
            self:QueueViewer(VIEWERS.BUFF_BAR)
        end
        QueueResourceUpdate()
    end)

end
