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
        table.wipe(self.queue)

        if self.NotifySpecChangeComplete then
            self:NotifySpecChangeComplete()
        end

        C_Timer.After(0, function()
            if specChangeVersion ~= myVersion then return end
            self:QueueAllViewers(ShouldUseImmediateQueue())
        end)

        if wasFullSpecChange then
            C_Timer.After(0.3, function()
                if specChangeVersion ~= myVersion then return end
                self:QueueAllViewers(ShouldUseImmediateQueue())
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
                self:QueueAllViewers(ShouldUseImmediateQueue())
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

    local function HandleTalentDataChanged(event)
        if event == "SPELLS_CHANGED" then
            if self.pendingSpecChange or self.pendingTalentChange then
                ProcessSpecChange()
            end
            return
        end

        if event == "ACTIVE_TALENT_GROUP_CHANGED" then
            BatchTalentEvent(true)
            return
        end

        if event == "TRAIT_CONFIG_CREATED"
            or event == "TRAIT_CONFIG_UPDATED"
            or event == "PLAYER_TALENT_UPDATE"
            or event == "PLAYER_PVP_TALENT_UPDATE"
            or event == "WAR_MODE_STATUS_UPDATE"
        then
            BatchTalentEvent(false)
        end
    end

    local function HandleSpecStateChanged(unit, event)
        if unit and unit ~= "player" then
            return
        end
        if event and event ~= "PLAYER_SPECIALIZATION_CHANGED" then
            return
        end
        BatchTalentEvent(true)
    end

    self:RegisterInternalCallback("OnTalentDataChanged", HandleTalentDataChanged)
    self:RegisterInternalCallback("OnSpecStateChanged", HandleSpecStateChanged)

end
