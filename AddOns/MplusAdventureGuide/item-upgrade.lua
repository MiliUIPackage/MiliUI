local addonName, addon = ...

local db = {
    explorer = {
        enUS = "Explorer",
        esMX = "Expedicionario",
        ptBR = "Explorador",
        frFR = "Explorateur",
        deDE = "Forscher",
        esES = "Expedicionario",
        itIT = "Esploratore",
        ruRU = "Исследователь",
        koKR = "탐험가",
        zhTW = "探險者",
        zhCN = "探索者",
        seasons = {
            season2 = {
                lower = 376,
                upper = 398,
            },
            season3 = {
                lower = 415,
                upper = 437,
            },
            season4 = {
                lower = 454,
                upper = 476,
            },
            TWWseason1 = {
                lower = 558,
                upper = 580,
            },
            TWWseason2 = {
                lower = 597,
                upper = 619,
            },
        },
    },
    adventurer = {
        enUS = "Adventurer",
        esMX = "Aventurero",
        ptBR = "Aventureiro",
        frFR = "Aventurier",
        deDE = "Abenteurer",
        esES = "Aventurero",
        itIT = "Avventuriero",
        ruRU = "Искатель приключений",
        koKR = "모험가",
        zhTW = "冒險者",
        zhCN = "冒险者",
        seasons = {
            season2 = {
                lower = 389,
                upper = 411,
            },
            season3 = {
                lower = 428,
                upper = 450,
            },
            season4 = {
                lower = 467,
                upper = 489,
            },
            TWWseason1 = {
                lower = 571,
                upper = 593,
            },
            TWWseason2 = {
                lower = 610,
                upper = 632,
            },
        },
    },
    veteran = {
        enUS = "Veteran",
        esMX = "Veterano",
        ptBR = "Veterano",
        frFR = "Vétéran",
        deDE = "Veteran",
        esES = "Veterano",
        itIT = "Veterano",
        ruRU = "Ветеран",
        koKR = "노련가",
        zhTW = "精兵",
        zhCN = "老兵",
        seasons = {
            season2 = {
                lower = 402,
                upper = 424,
            },
            season3 = {
                lower = 441,
                upper = 463,
            },
            season4 = {
                lower = 480,
                upper = 502,
            },
            TWWseason1 = {
                lower = 584,
                upper = 606,
            },
            TWWseason2 = {
                lower = 623,
                upper = 645,
            }
        },
    },
    champion = {
        enUS = "Champion",
        esMX = "Campeón",
        ptBR = "Campeão",
        frFR = "Champion",
        deDE = "Champion",
        esES = "Campeón",
        itIT = "Campione",
        ruRU = "Защитник",
        koKR = "챔피언",
        zhTW = "勇士",
        zhCN = "勇士",
        seasons = {
            season2 = {
                lower = 415,
                upper = 437,
            },
            season3 = {
                lower = 454,
                upper = 476,
            },
            season4 = {
                lower = 493,
                upper = 515,
            },
            TWWseason1 = {
                lower = 597,
                upper = 619,
            },
            TWWseason2 = {
                lower = 636,
                upper = 658,
            },
        },
    },
    hero = {
        enUS = "Hero",
        zhTW = "英雄",
        zhCN = "英雄",
        seasons = {
            season2 = {
                lower = 428,
                upper = 441,
            },
            season3 = {
                lower = 467,
                upper = 483,
            },
            season4 = {
                lower = 506,
                upper = 522,
            },
            TWWseason1 = {
                lower = 610,
                upper = 626,
            },
            TWWseason2 = {
                lower = 649,
                upper = 671,
            },
        },
    },
    myth = {
        enUS = "Myth",
        zhTW = "神話",
        zhCN = "神话",
        seasons = {
            season2 = {
                lower = 441,
                upper = 447,
            },
            season3 = {
                lower = 480,
                upper = 489,
            },
            season4 = {
                lower = 519,
                upper = 528,
            },
            TWWseason1 = {
                lower = 623,
                upper = 639,
            },
            TWWseason2 = {
                lower = 662,
                upper = 684,
            },
        },
    },
    awakened12 = {
        enUS = "Awakened (%d+)/12",
        seasons = {
            season4 = {
                lower = 493,
                upper = 528,
            },
        },
    },
    awakened14 = {
        enUS = "Awakened (%d+)/14",
        seasons = {
            season4 = {
                lower = 493,
                upper = 535,
            },
        },
    },
}

function addon:initItemUpgradeOldSeasons()
    if not addon.db.profile.itemUpgradeOldSeasons then
        for _, block in pairs(db) do
            local highestUpper, highestName = 0, ""
            for seasonName, seasonData in pairs(block.seasons) do
                if seasonData.upper > highestUpper then
                    highestUpper = seasonData.upper
                    highestName = seasonName
                end
            end
            for seasonName, seasonData in pairs(block.seasons) do
                if seasonName ~= highestName then
                    block.seasons[seasonName] = nil
                end
            end
        end
    end
end

local itemLevelPattern = ITEM_LEVEL
itemLevelPattern = itemLevelPattern:gsub("%%d", "(%%d+)")

local upgradePattern = ITEM_UPGRADE_TOOLTIP_FORMAT_STRING
upgradePattern = upgradePattern:gsub("%%d", "%%s")
upgradePattern = upgradePattern:format("(.+)", "(%d+)", "(%d+)")

TooltipDataProcessor.AddTooltipPreCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if not addon.db then return end
    if not addon.db.profile then return end
    if not addon.db.profile.itemUpgrade then return end
    
    local found, foundLower, foundUpper, foundCurrent
    
    for k, v in pairs(data.lines) do
        if type(v) == "table" then
            local text = v.leftText
            local match, _, itemLevel = text:find(itemLevelPattern)
            if match then
                foundCurrent = tonumber(itemLevel)
                break
            end
        end
    end
    
    if not foundCurrent then return end
    for k, v in pairs(data.lines) do
        if type(v) == "table" then
            local text = v.leftText
            local match, _, rank, lower, upper = text:find(upgradePattern)
            if match then
                if lower ~= upper then
                    for _, data in pairs(db) do
                        if data[GetLocale()] and ((data[GetLocale()] == rank) or ((rank.." "..lower.."/"..upper):match(data[GetLocale()]))) then 
                            for seasonName, seasonData in pairs(data.seasons) do
                                if (foundCurrent >= seasonData.lower) and (foundCurrent <= seasonData.upper) then
                                    found, foundLower, foundUpper = true, seasonData.lower, seasonData.upper
                                end
                            end
                            break
                        end
                    end
                end
                break
            end
        end
    end
    
    if not found then return end
    for k, v in pairs(data.lines) do
        if type(v) == "table" then
            local text = v.leftText
            local match, _, itemLevel = text:find(itemLevelPattern)
            if match then
                v.leftText = text.." "..DISABLED_FONT_COLOR:GenerateHexColorMarkup().."("..foundLower.."-"..foundUpper..")|r"
            end
        end
    end
end)
