local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

local function RemoveRogueBlackShadow(frame)
    if not frame or not frame.GetRegions then return end
    
    for _, r in ipairs({frame:GetRegions()}) do
        if r:GetObjectType() == "Texture" then
            local cr, cg, cb, ca = r:GetVertexColor()
            if cr and math.abs(cr - 0) < 0.05 and math.abs(cg - 0) < 0.05 and math.abs(cb - 0) < 0.05 and ca > 0.5 then
                local tex = r:GetTexture() or r:GetAtlas()
                if type(tex) == "number" or tex == "Interface\\Buttons\\WHITE8X8" then
                    -- This is exactly the black background shadow causing the thick border
                    -- We omit the GetSize() check because secure frames return 'secret numbers' which crash on arithmetic
                    if r:GetAlpha() > 0 or r:IsShown() then
                        r:SetAlpha(0)
                        r:Hide()
                        r:SetTexture(nil)
                        r:SetColorTexture(0, 0, 0, 0)
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function SweepAll()
    local count = 0
    -- Provide a strict list of viewers instead of pairs(_G) to avoid forbidden tables
    local viewers = {
        "EssentialCooldownViewer", "BuffIconCooldownViewer", "UtilityCooldownViewer",
        "DefensiveCooldownViewer", "ExternalCooldownViewer", "CDM_Trinkets", "BuffBarCooldownViewer"
    }

    for _, vName in ipairs(viewers) do
        local v = _G[vName]
        if type(v) == "table" and v.itemFramePool and type(v.itemFramePool) == "table" and v.itemFramePool.EnumerateActive then
            for frame in v.itemFramePool:EnumerateActive() do
                if RemoveRogueBlackShadow(frame) then count = count + 1 end
                if frame.IconFrame and RemoveRogueBlackShadow(frame.IconFrame) then count = count + 1 end
            end
        end
    end
    return count
end

local function InitStyleFix()
    if not Ayije_CDM then return end
    if MiliUI_DB and MiliUI_DB.cdmStyleFix == false then return end

    SLASH_MILIUI_CDMHIDE1 = "/cdmhide"
    SlashCmdList["MILIUI_CDMHIDE"] = function()
        local count = SweepAll()
        print("|cff00ff00[MiliUI]|r 已執行強制掃描移除異常黑底，共修復了", count, "個圖示框架！")
    end

    -- Hook into ApplyStyle, ApplyTrackerStyle, ApplyBarStyle
    if Ayije_CDM.ApplyStyle then
        hooksecurefunc(Ayije_CDM, "ApplyStyle", function(self, frame)
            RemoveRogueBlackShadow(frame)
        end)
    end

    if Ayije_CDM.ApplyTrackerStyle then
        hooksecurefunc(Ayije_CDM, "ApplyTrackerStyle", function(self, frame)
            RemoveRogueBlackShadow(frame)
        end)
    end

    if Ayije_CDM.ApplyBarStyle then
        hooksecurefunc(Ayije_CDM, "ApplyBarStyle", function(self, frame)
            RemoveRogueBlackShadow(frame)
            if frame.IconFrame then
                RemoveRogueBlackShadow(frame.IconFrame)
            end
        end)
    end
    
    -- Iterate active viewer pools immediately to catch already-created frames
    SweepAll()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    C_Timer.After(0.5, InitStyleFix)
end)
