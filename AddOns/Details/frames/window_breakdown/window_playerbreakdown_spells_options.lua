
local Details = Details
local DF = DetailsFramework

--create the main frame for the options panel

local createOptionsPanel = function()
    local startX = 5
    local startY = -32
    local heightSize = 540

    local DetailsSpellBreakdownTab = DetailsSpellBreakdownTab
    local UIParent = UIParent

    local options_text_template = DF:GetTemplate("font", "OPTIONS_FONT_TEMPLATE")
    local options_dropdown_template = DF:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
    local options_switch_template = DF:GetTemplate("switch", "OPTIONS_CHECKBOX_TEMPLATE")
    local options_slider_template = DF:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE")
    local options_button_template = DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE")

    local optionsFrame = DF:CreateSimplePanel(UIParent, 550, 500, "Details! Breakdown Options", "DetailsSpellBreakdownOptionsPanel")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetPoint("topleft", UIParent, "topleft", 2, -40)
    optionsFrame:Show()

    local bUseSolidColor = true
    DF:ApplyStandardBackdrop(optionsFrame, bUseSolidColor)

    local resetSettings = function()
        for key, value in pairs (Details.default_global_data.breakdown_spell_tab) do
            if (type(value) == "table") then
                local t = DF.table.copy({}, value)
                Details.breakdown_spell_tab[key] = t
            else
                Details.breakdown_spell_tab[key] = value
            end
        end

        local instanceObject = Details:GetActiveWindowFromBreakdownWindow()
        local actorObject = Details:GetActorObjectFromBreakdownWindow()
        local bFromAttributeChange = true
        local bIsRefresh = true
        local bIsShiftKeyDown = false
        local bIsControlKeyDown = false

        Details:CloseBreakdownWindow()
        Details:OpenBreakdownWindow(instanceObject, actorObject, bFromAttributeChange, bIsRefresh, bIsShiftKeyDown, bIsControlKeyDown)
        DetailsSpellBreakdownTab.GetSpellBlockFrame():UpdateBlocks()
        DetailsSpellBreakdownTab.UpdateShownSpellBlock()
        DetailsSpellBreakdownTab.UpdateHeadersSettings("spells")
        DetailsSpellBreakdownOptionsPanel:RefreshOptions()

        Details:Msg("設置恢復回預設。")
    end

    local resetSettingsButton = DF:CreateButton(optionsFrame, resetSettings, 130, 20, "Reset Settings")
    resetSettingsButton:SetPoint("bottomleft", optionsFrame, "bottomleft", 5, 5)
    resetSettingsButton:SetTemplate(options_button_template)

    local subSectionTitleTextTemplate = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE")

    local optionsTable = {
        {type = "label", get = function() return "Spell Details Block" end, text_template = subSectionTitleTextTemplate},
            {--block height
                type = "range",
                get = function() return Details.breakdown_spell_tab.blockspell_height end,
                set = function(self, fixedparam, value)
                    Details.breakdown_spell_tab.blockspell_height = value
                    DetailsSpellBreakdownTab.GetSpellBlockFrame():UpdateBlocks()
                end,
                min = 50,
                max = 80,
                step = 1,
                name = "區塊高度",
                desc = "Block Height",
            },

        {type = "blank"},
        {type = "blank"},

        {type = "label", get = function() return "Spell Header Options" end, text_template = subSectionTitleTextTemplate},
            { --per second
                type = "toggle",
                get = function() return Details.breakdown_spell_tab.spellcontainer_headers["persecond"].enabled end,
                set = function(self, fixedparam, value)
                    Details.breakdown_spell_tab.spellcontainer_headers["persecond"].enabled = value
                    DetailsSpellBreakdownTab.UpdateHeadersSettings("spells")
                end,
                name = "每秒",
                desc = "Per Second",
            },

            { --amount of casts
                type = "toggle",
                get = function() return Details.breakdown_spell_tab.spellcontainer_headers["casts"].enabled end,
                set = function(self, fixedparam, value)
                    Details.breakdown_spell_tab.spellcontainer_headers["casts"].enabled = value
                    DetailsSpellBreakdownTab.UpdateHeadersSettings("spells")
                end,
                name = "施放",
                desc = "Casts",
            },

            { --critical hits percent
                type = "toggle",
                get = function() return Details.breakdown_spell_tab.spellcontainer_headers["critpercent"].enabled end,
                set = function(self, fixedparam, value)
                    Details.breakdown_spell_tab.spellcontainer_headers["critpercent"].enabled = value
                    DetailsSpellBreakdownTab.UpdateHeadersSettings("spells")
                end,
                name = "致命命中百分比",
                desc = "Critical Hits Percent",
            },

            { --amount of hits
                type = "toggle",
                get = function() return Details.breakdown_spell_tab.spellcontainer_headers["hits"].enabled end,
                set = function(self, fixedparam, value)
                    Details.breakdown_spell_tab.spellcontainer_headers["hits"].enabled = value
                    DetailsSpellBreakdownTab.UpdateHeadersSettings("spells")
                end,
                name = "命中次數",
                desc = "Hits Amount",
            },

            { --average damage of healing per cast amount
                type = "toggle",
                get = function() return Details.breakdown_spell_tab.spellcontainer_headers["castavg"].enabled end,
                set = function(self, fixedparam, value)
                    Details.breakdown_spell_tab.spellcontainer_headers["castavg"].enabled = value
                    DetailsSpellBreakdownTab.UpdateHeadersSettings("spells")
                end,
                name = "施放平均",
                desc = "Cast Average",
            },

            { --debuff uptime
                type = "toggle",
                get = function() return Details.breakdown_spell_tab.spellcontainer_headers["uptime"].enabled end,
                set = function(self, fixedparam, value)
                    Details.breakdown_spell_tab.spellcontainer_headers["uptime"].enabled = value
                    DetailsSpellBreakdownTab.UpdateHeadersSettings("spells")
                end,
                name = "覆蓋時間",
                desc = "Uptime",
            },

            { --overheal
                type = "toggle",
                get = function() return Details.breakdown_spell_tab.spellcontainer_headers["overheal"].enabled end,
                set = function(self, fixedparam, value)
                    Details.breakdown_spell_tab.spellcontainer_headers["overheal"].enabled = value
                    DetailsSpellBreakdownTab.UpdateHeadersSettings("spells")
                end,
                name = "整體治療",
                desc = "Overheal",
            },

            { --absorbed
                type = "toggle",
                get = function() return Details.breakdown_spell_tab.spellcontainer_headers["absorbed"].enabled end,
                set = function(self, fixedparam, value)
                    Details.breakdown_spell_tab.spellcontainer_headers["absorbed"].enabled = value
                    DetailsSpellBreakdownTab.UpdateHeadersSettings("spells")
                end,
                name = "治療吸收",
                desc = "Heal Absorbed",
            },

        {type = "breakline"},
        {type = "label", get = function() return "Scroll Options" end, text_template = subSectionTitleTextTemplate},

            { --locked
                type = "toggle",
                get = function() return Details.breakdown_spell_tab.spellcontainer_islocked end,
                set = function(self, fixedparam, value)
                    ---@type df_framecontainer
                    local container = DetailsSpellBreakdownTab.GetSpellScrollContainer()
                    container:SetResizeLocked(value)

                    local container = DetailsSpellBreakdownTab.GetTargetScrollContainer()
                    container:SetResizeLocked(value)
                end,
                name = "已鎖定",
                desc = "Is Locked",
            },

            {--background alpha
                type = "range",
                get = function() return Details.breakdown_spell_tab.spellbar_background_alpha end,
                set = function(self, fixedparam, value)
                    Details.breakdown_spell_tab.spellbar_background_alpha = value
                    DetailsSpellBreakdownTab.GetSpellScrollFrame():Refresh()
                end,
                min = 0,
                max = 1,
                step = 0.1,
                usedecimals = true,
                name = "背景透明度",
                desc = "Background Alpha",
            },

        {type = "blank"},
        {type = "label", get = function() return "Group Player Spells:" end, text_template = subSectionTitleTextTemplate},
            { --nest player spells | merge player spells
                type = "toggle",
                get = function() return Details.breakdown_spell_tab.nest_players_spells_with_same_name end,
                set = function(self, fixedparam, value)
                    Details.breakdown_spell_tab.nest_players_spells_with_same_name = value
                end,
                name = "相同名稱的團隊玩家法術",
                desc = "Group spells casted by players which has the same name",
            },

        {type = "blank"},
        {type = "label", get = function() return "Group Pet Spells:" end, text_template = subSectionTitleTextTemplate},

            { --nest pet spells with the same name
                type = "toggle",
                get = function() return Details.breakdown_spell_tab.nest_pet_spells_by_name end,
                set = function(self, fixedparam, value)
                    Details.breakdown_spell_tab.nest_pet_spells_by_name = value
                end,
                name = "隊伍寵物名稱在寵物法術條下",
                desc = "Group Pets By Name",
                hooks = {["OnSwitch"] = function()
                    if (Details.breakdown_spell_tab.nest_pet_spells_by_name) then
                        Details.breakdown_spell_tab.nest_pet_spells_by_caster = false
                        DetailsSpellBreakdownOptionsPanel:RefreshOptions()
                    end
                end}
            },

            { --nest pet spells with the same name
                type = "toggle",
                get = function() return Details.breakdown_spell_tab.nest_pet_spells_by_caster end,
                set = function(self, fixedparam, value)
                    Details.breakdown_spell_tab.nest_pet_spells_by_caster = value

                end,
                name = "隊伍寵物法術在寵物名稱條下",
                desc = "Group Pets By Spell",
                hooks = {["OnSwitch"] = function()
                    if (Details.breakdown_spell_tab.nest_pet_spells_by_caster) then
                        Details.breakdown_spell_tab.nest_pet_spells_by_name = false
                        DetailsSpellBreakdownOptionsPanel:RefreshOptions()
                    end
                end}
            },
    }

    --build the menu
    optionsTable.always_boxfirst = true
    DF:BuildMenu(optionsFrame, optionsTable, startX, startY, heightSize, false, options_text_template, options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template)
end


function Details.OpenSpellBreakdownOptions()
    if (DetailsSpellBreakdownOptionsPanel) then
        DetailsSpellBreakdownOptionsPanel:RefreshOptions()
        DetailsSpellBreakdownOptionsPanel:Show()
        return
    end

    createOptionsPanel()
end