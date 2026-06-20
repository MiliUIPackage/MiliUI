local AddonName = "Ayije_CDM"
local CDM = _G[AddonName]

function CDM:InitializeSpecChangeSystem()
    local isFullSpecChange = false
    local backstopToken = 0

    local ProcessSpecChange

    local processingInProgress = false
    local specChangeVersion = 0

    local function ScheduleBackstop()
        backstopToken = backstopToken + 1
        local myToken = backstopToken
        C_Timer.After(3, function()
            if myToken ~= backstopToken then return end
            if self.pendingTalentChange or self.pendingSpecChange then
                ProcessSpecChange()
            end
        end)
    end

    ProcessSpecChange = function()
        if processingInProgress then return end

        local wasFullSpecChange = isFullSpecChange
        local specIndex = GetSpecialization()
        if not specIndex then
            ScheduleBackstop()
            return
        end

        processingInProgress = true

        local ok, processingErr = pcall(function()
            if wasFullSpecChange then
                self:InvalidateSpecIDCache()
                self:CheckSpecProfileSwitch(specIndex)
            end
            self:MarkSpecDataDirty()
            self:RefreshSpecData()
        end)

        self.pendingTalentChange = false
        self.pendingSpecChange = false
        isFullSpecChange = false
        processingInProgress = false
        backstopToken = backstopToken + 1

        if ok then
            self:Refresh()
        else
            local handler = geterrorhandler and geterrorhandler()
            if handler then handler(processingErr) end
        end

        specChangeVersion = specChangeVersion + 1
        local myVersion = specChangeVersion

        if self.NotifySpecChangeComplete then
            self:NotifySpecChangeComplete()
        end

        C_Timer.After(0, function()
            if specChangeVersion ~= myVersion then return end
            self:ForceReanchorAll()
        end)

        C_Timer.After(0.1, function()
            if specChangeVersion ~= myVersion then return end
            if self.InvalidateRacialsSpellbookCache then self:InvalidateRacialsSpellbookCache() end
            if self.RebuildGlowFilters then self:RebuildGlowFilters() end
            if self.UpdateDefensives then self:UpdateDefensives() end
            if self.UpdateRacials then self:UpdateRacials() end
            if self.UpdateResources then self:UpdateResources() end
            if self.UpdatePlayerCastBar then self:UpdatePlayerCastBar() end
        end)
    end

    function CDM:ProcessDeferredLogin()
        if self.loginDeferredFullChange ~= nil then
            local isFullChange = self.loginDeferredFullChange
            self.loginDeferredFullChange = nil
            self.pendingTalentChange = true
            if isFullChange then
                isFullSpecChange = true
                self.pendingSpecChange = true
                self:InvalidateSpecIDCache()
            end
            ScheduleBackstop()
        end
    end

    local function HandleTalentDataChanged(event)
        if event == "SPELLS_CHANGED" then
            if self.pendingSpecChange or self.pendingTalentChange then
                ProcessSpecChange()
            end
            return
        end

        if not self.loginFinished then
            self.loginDeferredFullChange = self.loginDeferredFullChange
                or (event == "ACTIVE_TALENT_GROUP_CHANGED")
            return
        end

        self.pendingTalentChange = true

        if event == "ACTIVE_TALENT_GROUP_CHANGED" then
            isFullSpecChange = true
            self.pendingSpecChange = true
            self:InvalidateSpecIDCache()
        end

        ScheduleBackstop()
    end

    local function HandleSpecStateChanged(unit, event)
        if not self.loginFinished then
            self.loginDeferredFullChange = true
            return
        end

        self.pendingTalentChange = true
        isFullSpecChange = true
        self.pendingSpecChange = true
        self:InvalidateSpecIDCache()
        ScheduleBackstop()
    end

    self:RegisterTalentDataHandler(HandleTalentDataChanged)
    self:RegisterSpecStateHandler(HandleSpecStateChanged)
end
