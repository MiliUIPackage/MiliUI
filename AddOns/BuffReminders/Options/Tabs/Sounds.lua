local _, BR = ...

-- ============================================================================
-- SOUNDS TAB
-- ============================================================================
-- Per-buff sound alert assignment: icon + name + sound + preview/edit/remove.

local L = BR.L
local CreateButton = BR.CreateButton

local BUFF_TABLES = BR.BUFF_TABLES
local BuffGroups = BR.BuffGroups

local RaidBuffs = BUFF_TABLES.raid
local PresenceBuffs = BUFF_TABLES.presence
local TargetedBuffs = BUFF_TABLES.targeted
local SelfBuffs = BUFF_TABLES.self
local PetBuffs = BUFF_TABLES.pet
local Consumables = BUFF_TABLES.consumable

local GetBuffTexture = BR.Helpers.GetBuffTexture
local SetBuffSound = BR.Helpers.SetBuffSound

local TEXCOORD_INSET = BR.TEXCOORD_INSET
local LSM = BR.LSM

local PlaySoundFile = PlaySoundFile

local tinsert = table.insert
local tsort = table.sort

local function Build(ctx)
    local C = ctx.constants
    local PANEL_WIDTH = C.PANEL_WIDTH
    local COL_PADDING = C.COL_PADDING

    local soundsContent = ctx:CreateSimpleContent("sounds", 500)

    local SOUND_ROW_HEIGHT = 24
    local SOUND_ICON_SIZE = 20
    local soundRowPool = {}
    local soundRowCount = 0

    -- Build a lookup of all known buff keys to display names and icons.
    -- Static buff info is cached; custom buffs are merged on each call.
    local cachedStaticBuffInfo = nil
    local function GetAllBuffInfo()
        if not cachedStaticBuffInfo then
            cachedStaticBuffInfo = {}
            local seenGroups = {}
            local allBuffArrays = { RaidBuffs, PresenceBuffs, TargetedBuffs, SelfBuffs, PetBuffs, Consumables }
            for _, buffArray in ipairs(allBuffArrays) do
                for _, buff in ipairs(buffArray) do
                    if buff.groupId then
                        if not seenGroups[buff.groupId] then
                            seenGroups[buff.groupId] = true
                            local groupInfo = BuffGroups[buff.groupId]
                            local name = groupInfo and groupInfo.displayName or buff.name
                            cachedStaticBuffInfo[buff.groupId] = {
                                name = name,
                                spellID = buff.displaySpells or buff.spellID,
                            }
                        end
                    else
                        cachedStaticBuffInfo[buff.key] = {
                            name = buff.name,
                            spellID = buff.displaySpells or buff.spellID,
                        }
                    end
                end
            end
        end
        local info = {}
        for k, v in pairs(cachedStaticBuffInfo) do
            info[k] = v
        end
        local db = BR.profile
        if db.customBuffs then
            for key, customBuff in pairs(db.customBuffs) do
                info[key] = {
                    name = customBuff.name or (L["CustomBuff.Action.Spell"] .. " " .. tostring(customBuff.spellID)),
                    spellID = customBuff.spellID,
                }
            end
        end
        return info
    end

    local function AcquireSoundRow(index)
        local row = soundRowPool[index]
        if not row then
            row = CreateFrame("Frame", nil, soundsContent)
            row:SetSize(PANEL_WIDTH - COL_PADDING * 2, SOUND_ROW_HEIGHT)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(SOUND_ICON_SIZE, SOUND_ICON_SIZE)
            row.icon:SetPoint("LEFT", 0, 0)
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.soundText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.soundText:SetPoint("LEFT", row.nameText, "RIGHT", 8, 0)

            row.previewBtn = CreateFrame("Button", nil, row)
            row.previewBtn:SetSize(14, 14)
            row.previewBtn:SetPoint("RIGHT", row, "RIGHT", -48, 0)
            row.previewTex = row.previewBtn:CreateTexture(nil, "ARTWORK")
            row.previewTex:SetAllPoints()
            row.previewTex:SetAtlas("chatframe-button-icon-voicechat")
            row.previewBtn:SetScript("OnEnter", function()
                row.previewTex:SetVertexColor(1, 1, 1, 1)
            end)
            row.previewBtn:SetScript("OnLeave", function()
                row.previewTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
            end)

            row.editBtn = CreateFrame("Button", nil, row)
            row.editBtn:SetSize(14, 14)
            row.editBtn:SetPoint("RIGHT", row, "RIGHT", -24, 0)
            row.editTex = row.editBtn:CreateTexture(nil, "ARTWORK")
            row.editTex:SetAllPoints()
            row.editTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
            row.editBtn:SetScript("OnEnter", function()
                row.editTex:SetVertexColor(1, 1, 1, 1)
            end)
            row.editBtn:SetScript("OnLeave", function()
                row.editTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
            end)

            row.removeBtn = CreateFrame("Button", nil, row)
            row.removeBtn:SetSize(14, 14)
            row.removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            row.removeTex = row.removeBtn:CreateTexture(nil, "ARTWORK")
            row.removeTex:SetAllPoints()
            row.removeTex:SetAtlas("common-icon-redx")
            row.removeBtn:SetScript("OnEnter", function()
                row.removeTex:SetVertexColor(1, 0.3, 0.3, 1)
            end)
            row.removeBtn:SetScript("OnLeave", function()
                row.removeTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
            end)
            soundRowPool[index] = row
        end
        row.previewTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
        row.editTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
        row.removeTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
        row:Show()
        return row
    end

    local function RenderSoundAlertRows()
        for i = 1, soundRowCount do
            soundRowPool[i]:Hide()
        end
        soundRowCount = 0

        local db = BR.profile
        local buffSounds = db.buffSounds
        local allBuffInfo = GetAllBuffInfo()
        local y = -10

        if not buffSounds or not next(buffSounds) then
            if not soundsContent.emptyText then
                soundsContent.emptyText = soundsContent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
                soundsContent.emptyText:SetPoint("TOPLEFT", COL_PADDING, -10)
                soundsContent.emptyText:SetJustifyH("LEFT")
            end
            soundsContent.emptyText:SetText(L["Options.Sound.NoAlerts"])
            soundsContent.emptyText:Show()
            y = y - SOUND_ROW_HEIGHT
        else
            if soundsContent.emptyText then
                soundsContent.emptyText:Hide()
            end

            local sortedKeys = {}
            for key in pairs(buffSounds) do
                tinsert(sortedKeys, key)
            end
            tsort(sortedKeys, function(a, b)
                local infoA = allBuffInfo[a]
                local infoB = allBuffInfo[b]
                local nameA = infoA and infoA.name or a
                local nameB = infoB and infoB.name or b
                return nameA < nameB
            end)

            for _, key in ipairs(sortedKeys) do
                local soundName = buffSounds[key]
                local buffInfo = allBuffInfo[key]
                local displayName = buffInfo and buffInfo.name or key

                soundRowCount = soundRowCount + 1
                local row = AcquireSoundRow(soundRowCount)
                row:SetPoint("TOPLEFT", COL_PADDING, y)

                if buffInfo and buffInfo.spellID then
                    local texture = GetBuffTexture(buffInfo.spellID)
                    if texture then
                        row.icon:SetTexture(texture)
                        row.icon:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)
                    else
                        row.icon:SetTexture(134400)
                        row.icon:SetTexCoord(0, 1, 0, 1)
                    end
                else
                    row.icon:SetTexture(134400)
                    row.icon:SetTexCoord(0, 1, 0, 1)
                end

                row.nameText:SetText(displayName)
                row.soundText:SetText("|cff888888" .. soundName .. "|r")

                row.previewBtn:SetScript("OnClick", function()
                    local soundFile = LSM:Fetch("sound", soundName)
                    if soundFile then
                        PlaySoundFile(soundFile, "Master")
                    end
                end)
                row.editBtn:SetScript("OnClick", function()
                    BR.Options.Modals.SoundAlert.Show(RenderSoundAlertRows, key, soundName, displayName)
                end)
                row.removeBtn:SetScript("OnClick", function()
                    SetBuffSound(key, nil)
                    RenderSoundAlertRows()
                end)

                y = y - SOUND_ROW_HEIGHT
            end
        end

        if not soundsContent.addBtn then
            soundsContent.addBtn = CreateButton(soundsContent, L["Options.Sound.AddAlert"], function()
                BR.Options.Modals.SoundAlert.Show(RenderSoundAlertRows)
            end)
            soundsContent.addBtn:SetSize(160, 22)
        end
        soundsContent.addBtn:SetPoint("TOPLEFT", COL_PADDING, y - 10)
    end

    soundsContent:SetScript("OnShow", function()
        RenderSoundAlertRows()
    end)
end

BR.Options.Tabs.Sounds = { Build = Build }
