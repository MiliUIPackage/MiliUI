local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.productEnabled then
    return
end
-------------------------------------------------------------------------------
--- YUI 拍卖行购买助手
--- 用于快速搜索和购买拍卖行物品
-------------------------------------------------------------------------------

local _, addonNs = ...
local ns = _G.YUI or addonNs
local YUI = ns
local GUI2 = ns.GUI2
local Components = ns.Components
local L = ns.Locale and ns.Locale:Get("AuctionHelper") or setmetatable({}, { __index = function(_, key) return tostring(key) end })

-- 缓存全局函数
local GetItemIcon = GetItemIcon or C_Item.GetItemIconByID
local GetItemCount = GetItemCount
local GetItemInfo = GetItemInfo or C_Item.GetItemInfo
local C_AuctionHouse = C_AuctionHouse

-------------------------------------------------------------------------------
-- DB Abstraction
-------------------------------------------------------------------------------
local DB = {}
local DEFAULT_DB = {
    defaultCollapsed = false,
    showTagText = true,
    categoryStyle = "background",
    themeStyle = "auto",
    browseResultsFontSizeEnabled = false,
    browseResultsMoneyFontSizeEnabled = false,
    browseResultsFontSize = 16,
}

local BROWSE_RESULTS_FONT_SIZE_MIN = 14
local BROWSE_RESULTS_FONT_SIZE_MAX = 16
local BROWSE_RESULTS_FONT_SIZE_DEFAULT = 16

local function ClampBrowseResultsFontSize(value)
    value = tonumber(value) or BROWSE_RESULTS_FONT_SIZE_DEFAULT
    value = math.floor(value + 0.5)
    if value < BROWSE_RESULTS_FONT_SIZE_MIN then return BROWSE_RESULTS_FONT_SIZE_MIN end
    if value > BROWSE_RESULTS_FONT_SIZE_MAX then return BROWSE_RESULTS_FONT_SIZE_MAX end
    return value
end

local function GetProfile()
    if ns.DB and ns.DB.GetProfile then
        local profile = ns.DB:GetProfile("auction_helper")
        if type(profile) == "table" then
            return profile
        end
    end
    return nil
end

function DB:Get()
    local profile = GetProfile()
    if type(profile) ~= "table" then
        return DEFAULT_DB
    end
    if type(profile.AuctionHelper) ~= "table" then
        profile.AuctionHelper = {}
    end
    for key, value in pairs(DEFAULT_DB) do
        if profile.AuctionHelper[key] == nil then
            profile.AuctionHelper[key] = value
        end
    end
    profile.AuctionHelper.browseResultsFontSize = ClampBrowseResultsFontSize(profile.AuctionHelper.browseResultsFontSize)
    profile.AuctionHelper.browseResultsFontSizeEnabled = profile.AuctionHelper.browseResultsFontSizeEnabled == true
    profile.AuctionHelper.browseResultsMoneyFontSizeEnabled = profile.AuctionHelper.browseResultsMoneyFontSizeEnabled == true
    return profile.AuctionHelper
end

function DB:IsEnabled()
    if Components and Components.GetStoreValue then
        local isEnabled = Components:GetStoreValue("AuctionHelper", nil, "auction_helper")
        if isEnabled ~= nil then return isEnabled == true end
    end
    if Components and Components.features and Components.features["AuctionHelper"] then
        return Components.features["AuctionHelper"].default == true
    end
    return false
end

local DATA = {
    {
        key = "buffs",
        nameKey = "category.buffs",
        bgColor = "CC6600",
        rows = {
            {
                { id = {241320, 241321}, tagKey = "tag.versatility" },
                { id = {241326, 241327}, tagKey = "tag.critical" },
                { id = {241322, 241323}, tagKey = "tag.mastery" },
                { id = {241324, 241325}, tagKey = "tag.haste" },
                { id = {259085}, tagKey = "tag.rune" },
            },
            {
                { id = {243735, 243736}, tagKey = "tag.healing" },
                { id = {243733, 243734}, tagKey = "tag.stats" },
                { id = {243737, 243738}, tagKey = "tag.damage" },
                { id = {237367, 237369}, tagKey = "tag.blunt" },
                { id = {237370, 237371}, tagKey = "tag.blade" },
                { id = {245879, 245880}, tagKey = "tag.raid"  },
            }
        }
    },
    {
        key = "food",
        nameKey = "category.food",
        bgColor = "339933",
        rows = {
            {
                { id = 255845, tagKey = "tag.primary" },
                { id = 255846, tagKey = "tag.primary" },
                { id = 242272, tagKey = "tag.secondary" },
                { id = 242273, tagKey = "tag.secondary" },
            },
            {
                { id = 242275, tagKey = "tag.primary" },
                { id = 255848, tagKey = "tag.secondary" },
                { id = 242274, tagKey = "tag.secondary" },
                { id = 242277, tagKey = "tag.haste" },
                { id = 242286, tagKey = "tag.haste" },
                { id = 242278, tagKey = "tag.critical" },
                { id = 242283, tagKey = "tag.critical" },
                { id = 242287, tagKey = "tag.critical" },
            },
            {
                { id = 242276, tagKey = "tag.versatility" },
                { id = 242280, tagKey = "tag.versatility" },
                { id = 242284, tagKey = "tag.versatility" },
                { id = 242281, tagKey = "tag.mastery" },
                { id = 242285, tagKey = "tag.mastery" },
                -- { id = 242291, tagKey = "tag.mastery_vers" },
                -- { id = 242293, tagKey = "tag.haste_vers" },
                { id = 242299, tagKey = "tag.speed" },
                { id = 242298, tagKey = "tag.speed" },
                { id = 242289, tagKey = "tag.meat" },
            }
        }
    },
    {
        key = "potions",
        nameKey = "category.potions",
        bgColor = "8E44AD",
        rows = {
            {
                { id = { 241308, 241309 }, tagKey = "tag.primary" },
                { id = { 241288, 241289 }, tagKey = "tag.secondary" },
                { id = { 241296, 241297 }, tagKey = "tag.damage" },
                { id = { 241286, 241287 }, tagKey = "tag.shield" },
                { id = { 241292, 241293 }, tagKey = "tag.primary" },
                { id = { 241302, 241303 }, tagKey = "tag.invisible" },
            },
            {
                { id = { 241304, 241305 }, tagKey = "tag.health"},
                { id = 241299, tagKey = "tag.health" },
                { id = { 241300, 241301 }, tagKey = "tag.mana" },
                { id = { 241294, 241295 }, tagKey = "tag.mana" },
                { id = { 241306, 241307 }, tagKey = "tag.serum" },
                { id = { 241338, 241339 }, tagKey = "tag.slow_fall" },
            }
        }
    },
    {
        key = "diamonds",
        nameKey = "category.diamonds",
        bgColor = "2266AA",
        rows = {
            {
                { id = {240968, 240969}, tagKey = "tag.mana" },
                { id = {240970, 240971}, tagKey = "tag.armor" },
                { id = {240966, 240967}, tagKey = "tag.crit_effect" },
                { id = {240982, 240983}, tagKey = "tag.primary" },
            }
        }
    },
    {
        key = "bloodstones",
        nameKey = "category.bloodstones",
        bgColor = "CC3333",
        rows = {
            {
                { id = 241142, tagKey = "tag.resolve" },
                { id = 241143, tagKey = "tag.perception" },
                { id = 241144, tagKey = "tag.tenacity" },
            }
        }
    },
    {
        key = "high_gems",
        nameKey = "category.high_gems",
        bgColor = "CC6600",
        rows = {
            { 
                { id = {240903,240904}, tagKey = "tag.critical", enUSShortTagKey = "tag.critical_short" },
                { id = {240907,240908}, tagKey = "tag.crit_mastery" },
                { id = {240905,240906}, tagKey = "tag.crit_haste" },
                { id = {240909,240910}, tagKey = "tag.crit_vers" },
                { id = {240895,240896}, tagKey = "tag.mastery", enUSShortTagKey = "tag.mastery_short" },
                { id = {240897,240898}, tagKey = "tag.mastery_crit" },
                { id = {240899,240900}, tagKey = "tag.mastery_haste" },
                { id = {240901,240902}, tagKey = "tag.mastery_vers" },
            },
            { 
                { id = {240887,240888}, tagKey = "tag.haste", enUSShortTagKey = "tag.haste_short" },
                { id = {240889,240890}, tagKey = "tag.haste_crit" },
                { id = {240891,240892}, tagKey = "tag.haste_mastery" },
                { id = {240893,240894}, tagKey = "tag.haste_vers" },
                { id = {240911,240912}, tagKey = "tag.versatility", enUSShortTagKey = "tag.versatility_short" },
                { id = {240913,240914}, tagKey = "tag.vers_crit" },
                { id = {240917,240918}, tagKey = "tag.vers_mastery" },
                { id = {240915,240916}, tagKey = "tag.vers_haste" },
            },
        }
    },
    {
        key = "low_gems",
        nameKey = "category.low_gems",
        bgColor = "339933",
        rows = {
            { 
                { id = {240871,240872}, tagKey = "tag.critical", enUSShortTagKey = "tag.critical_short" },
                { id = {240875,240876}, tagKey = "tag.crit_mastery" },
                { id = {240873,240874}, tagKey = "tag.crit_haste" },
                { id = {240877,240878}, tagKey = "tag.crit_vers" },
                { id = {240863,240864}, tagKey = "tag.mastery", enUSShortTagKey = "tag.mastery_short" },
                { id = {240865,240866}, tagKey = "tag.mastery_crit" },
                { id = {240867,240868}, tagKey = "tag.mastery_haste" },
                { id = {240869,240870}, tagKey = "tag.mastery_vers" },
            },
            { 
                { id = {240855,240856}, tagKey = "tag.haste", enUSShortTagKey = "tag.haste_short" },
                { id = {240857,240858}, tagKey = "tag.haste_crit" },
                { id = {240859,240860}, tagKey = "tag.haste_mastery" },
                { id = {240861,240862}, tagKey = "tag.haste_vers" },
                { id = {240879,240880}, tagKey = "tag.versatility", enUSShortTagKey = "tag.versatility_short" },
                { id = {240881,240882}, tagKey = "tag.vers_crit" },
                { id = {240885,240886}, tagKey = "tag.vers_mastery" },
                { id = {240883,240884}, tagKey = "tag.vers_haste" },
            },
        }
    },
    {
        key = "enchant_weapon",
        nameKey = "category.enchant_weapon",
        bgColor = "9933CC",
        rows = {
            {
                { id = {244028, 244029}, tagKey = "tag.primary" },
                { id = {243970, 243971}, tagKey = "tag.critical" },
                { id = {244030, 244031}, tagKey = "tag.mastery" },
                { id = {243972, 243973}, tagKey = "tag.haste" },
                { id = {244001, 244000}, tagKey = "tag.versatility" },
                { id = {243998, 243999}, tagKey = "tag.damage" },
                { id = {243996, 243997}, tagKey = "tag.healing" },
                { id = {243968, 243969}, tagKey = "tag.bleed"  },
            },
            {
                { id = {244026, 244027}, tagKey = "tag.flame" },
                { id = {257745, 257746}, tagKey = "tag.eagle_eye" },
                { id = {257747, 257748}, tagKey = "tag.cat_eye" },
                { id = {257749, 257750}, tagKey = "tag.poison" },
                { id = {257751, 257752}, tagKey = "tag.shock" },
            }
        }
    },
    {
        key = "enchant_helm",
        nameKey = "category.enchant_helm",
        bgColor = "9933CC",
        rows = {
            {
                { id = {243980, 243981}, tagKey = "tag.speed" },
                { id = {243950, 243951}, tagKey = "tag.leech" },
                { id = {244006, 244007}, tagKey = "tag.avoidance" },
                { id = {243978, 243979}, tagKey = "tag.speed" },
                { id = {243948, 243949}, tagKey = "tag.leech" },
                { id = {244004, 244005}, tagKey = "tag.avoidance" },
            }
        }
    },
    {
        key = "enchant_shoulder",
        nameKey = "category.enchant_shoulder",
        bgColor = "9933CC",
        rows = {
            {
                { id = {243962, 243963}, tagKey = "tag.speed" },
                { id = {244020, 244021}, tagKey = "tag.leech" },
                { id = {243990, 243991}, tagKey = "tag.avoidance" },
                { id = {243960, 243961}, tagKey = "tag.speed" },
                { id = {244018, 244019}, tagKey = "tag.leech" },
                { id = {243988, 243989}, tagKey = "tag.avoidance" },
            }
        }
    },
    {
        key = "enchant_chest",
        nameKey = "category.enchant_chest",
        bgColor = "9933CC",
        rows = {
            {
                { id = {243976, 243977}, tagKey = "tag.primary" },
                { id = {243974, 243975}, tagKey = "tag.agility" },
                { id = {243946, 243947}, tagKey = "tag.strength" },
                { id = {244002, 244003}, tagKey = "tag.intellect" },
            }
        }
    },
    {
        key = "enchant_legs",
        nameKey = "category.enchant_legs",
        bgColor = "9933CC",
        rows = {
            {
                { id = {244642, 244643}, tagKey = "tag.armor" },
                { id = {244640, 244641}, tagKey = "tag.stamina" },
                { id = {244644, 244645}, tagKey = "tag.lesser" },
                { id = {240154, 240155}, tagKey = "tag.mana" },
                { id = {240094, 240095}, tagKey = "tag.stamina" },
                { id = {240156, 240157}, tagKey = "tag.lesser" },
            }
        }
    },
    {
        key = "enchant_boots",
        nameKey = "category.enchant_boots",
        bgColor = "9933CC",
        rows = {
            {
                { id = {244008, 244009}, tagKey = "tag.speed" },
                { id = {243982, 243983}, tagKey = "tag.leech" },
                { id = {243952, 243953}, tagKey = "tag.avoidance" },
            }
        }
    },
    {
        key = "enchant_gloves",
        nameKey = "category.enchant_gloves",
        bgColor = "9933CC",
        rows = {
            {
                { id = 34330, tagKey = "tag.stamina" },
            }
        }
    },
    {
        key = "enchant_ring",
        nameKey = "category.enchant_ring",
        bgColor = "9933CC",
        rows = {
            {
                { id = {243986, 243987}, tagKey = "tag.critical" },
                { id = {243958, 243959}, tagKey = "tag.mastery" },
                { id = {244014, 244015}, tagKey = "tag.haste" },
                { id = {244016, 244017}, tagKey = "tag.versatility" },
                { id = {243956, 243957}, tagKey = "tag.crit_effect" },
            },
            {
                { id = {243984, 243985}, tagKey = "tag.critical" },
                { id = {243954, 243955}, tagKey = "tag.mastery" },
                { id = {244010, 244011}, tagKey = "tag.haste" },
                { id = {244012, 244013}, tagKey = "tag.versatility" },
            }
        }
    },
    {
        key = "enchant_tool",
        nameKey = "category.enchant_tool",
        bgColor = "9933CC",
        rows = {
            {
                { id = {244024, 244025}, tagKey = "tag.ingenuity" },
                { id = {243966, 243967}, tagKey = "tag.resourcefulness" },
                { id = {243994, 243995}, tagKey = "tag.multicraft" },
                { id = {243964, 243965}, tagKey = "tag.perception" },
                { id = {244022, 244023}, tagKey = "tag.skill" },
                { id = {243992, 243993}, tagKey = "tag.finesse" },
            }
        }
    },
    {
        key = "other",
        nameKey = "category.other",
        bgColor = "607D8B",
        rows = {
            {
                { id = 244639, tagKey = "tag.bloodlust" },
                -- { id = 219905, tagKey = "tag.bloodlust" },
                { id = {248486, 269586}, tagKey = "tag.battle_res" },
                { id = 132514, tagKey = "tag.repair" },
                { id = 260232, tagKey = "tag.key"},
                { id = {245799, 245800}, tagKey = "tag.silvermoon" },
                { id = {245793, 245794}, tagKey = "tag.singularity"},
                { id = {245795, 245796}, tagKey = "tag.harai" },
                { id = {245797, 245798}, tagKey = "tag.aman" },
            }
        }
    },
    {
        key = "missive_gear",
        nameKey = "category.missive_gear",
        bgColor = "339933",
        rows = {
            {
                { id = {245789, 245790}, tagKey = "tag.crit_mastery" },
                { id = {245785, 245786}, tagKey = "tag.crit_haste" },
                { id = {245791, 245792}, tagKey = "tag.crit_vers" },
                { id = {245783, 245784}, tagKey = "tag.haste_mastery" },
                { id = {245781, 245782}, tagKey = "tag.haste_vers" },
                { id = {245787, 245788}, tagKey = "tag.mastery_vers" },
            }
        }
    },
    {
        key = "missive_tool",
        nameKey = "category.missive_tool",
        bgColor = "008B8B",
        rows = {
            {
                { id = {245820, 245821}, tagKey = "tag.speed" },
                { id = {245818, 245819}, tagKey = "tag.multicraft" },
                { id = {245814, 245815}, tagKey = "tag.ingenuity" },
                { id = {245826, 245827}, tagKey = "tag.skill" },
                { id = {245816, 245817}, tagKey = "tag.resourcefulness" },
                { id = {245824, 245825}, tagKey = "tag.perception" },
                { id = {245822, 245823}, tagKey = "tag.finesse" },
            }
        }
    },
    {
        key = "embellishments",
        nameKey = "category.embellishments",
        bgColor = "8E44AD",
        rows = {
            {
                { id = {244603, 244604}, tagKey = "tag.mount" },
                { id = {244607, 244608}, tagKey = "tag.spore" },
                { id = {244674, 244675}, tagKey = "tag.devour" },
                { id = {240166, 240167}, tagKey = "tag.duskweave" },
                { id = {240164, 240165}, tagKey = "tag.dawnweave" },
                { id = {251489, 251490}, tagKey = "tag.jewel" },
                
            },
            {
                { id = {245871, 245872}, tagKey = "tag.blood" },
                { id = {245875, 245876}, tagKey = "tag.hunt" },
                { id = {245877, 245878}, tagKey = "tag.decay" },
                { id = {245873, 245874}, tagKey = "tag.void" },
                { id = {248130}, tagKey = "tag.clear" },
            }
        }
    },
    {
        key = "engineering_gears",
        nameKey = "category.engineering_gears",
        bgColor = "2266AA",
        rows = {
            {
                { id = {244697, 244698}, tagKey = "tag.critical" },
                { id = {244699, 244700}, tagKey = "tag.haste" },
                { id = {244703, 244704}, tagKey = "tag.versatility" },
                { id = {244701, 244702}, tagKey = "tag.mastery" },
            }
        }
    },
}

local TABS = {
    { nameKey = "tab.consumables", categories = {"buffs", "food", "potions", "other"} },
    { nameKey = "tab.gems", categories = {"diamonds", "bloodstones", "high_gems", "low_gems"} },
    { nameKey = "tab.enchants", categories = {"enchant_weapon", "enchant_helm", "enchant_shoulder", "enchant_chest", "enchant_legs", "enchant_boots", "enchant_gloves", "enchant_ring", "enchant_tool"} },
    { nameKey = "tab.crafting", categories = {"missive_gear", "missive_tool", "embellishments", "engineering_gears"} },
}

local function ParseHexColor(hex)
    if not hex then return 0.2, 0.4, 0.8, 0.8 end
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) or 51
    local g = tonumber(hex:sub(3, 4), 16) or 102
    local b = tonumber(hex:sub(5, 6), 16) or 204
    return r / 255, g / 255, b / 255, 0.8
end

local browseResultsFontHooksInstalled = false
local browseResultsFontRefreshScheduled = false
local auctionHelperFeatureActive = false
local browseResultsFontTargets = setmetatable({}, { __mode = "k" })

local function IsBrowseResultsFontFeatureEnabled()
    if not YUI.IsRetail or not auctionHelperFeatureActive or not DB:IsEnabled() then
        return false
    end

    return DB:Get().browseResultsFontSizeEnabled == true
end

local function GetBrowseResultsFontSize()
    return ClampBrowseResultsFontSize(DB:Get().browseResultsFontSize)
end

local function IsAuctionMoneyDisplayFrame(frame)
    return frame
        and frame.useAuctionHouseCopperValue == true
        and type(frame.SetAmount) == "function"
        and type(frame.GetAmount) == "function"
end

local function IsInsideAuctionMoneyDisplay(object)
    local parent = object and object.GetParent and object:GetParent()
    local depth = 0
    while parent and depth < 8 do
        if IsAuctionMoneyDisplayFrame(parent) then
            return true
        end

        parent = parent.GetParent and parent:GetParent()
        depth = depth + 1
    end

    return false
end

local function RememberOriginalFont(fontString, targetType)
    if fontString.yuiAuctionHelperOriginalFontSize ~= nil then
        if browseResultsFontTargets[fontString] == nil then
            browseResultsFontTargets[fontString] = targetType or "text"
        end
        return
    end

    local font, size, flags = fontString:GetFont()
    fontString.yuiAuctionHelperOriginalFont = font
    fontString.yuiAuctionHelperOriginalFontSize = tonumber(size) or BROWSE_RESULTS_FONT_SIZE_MIN
    fontString.yuiAuctionHelperOriginalFontFlags = flags
    browseResultsFontTargets[fontString] = targetType or "text"
end

local function SetFontStringSize(fontString, size, targetType)
    if not (fontString and fontString.GetFont and fontString.SetFont) then
        return
    end

    RememberOriginalFont(fontString, targetType)

    local font = fontString.yuiAuctionHelperOriginalFont
    local flags = fontString.yuiAuctionHelperOriginalFontFlags
    if not font then
        font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    end

    fontString:SetFont(font, size, flags)
end

local function RestoreBrowseResultsFontSize(targetType)
    local targets = {}
    for fontString, storedType in pairs(browseResultsFontTargets) do
        if not targetType or storedType == targetType then
            targets[#targets + 1] = fontString
        end
    end

    for i = 1, #targets do
        local fontString = targets[i]
        if fontString and fontString.SetFont then
            local font = fontString.yuiAuctionHelperOriginalFont or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
            local size = fontString.yuiAuctionHelperOriginalFontSize or BROWSE_RESULTS_FONT_SIZE_MIN
            local flags = fontString.yuiAuctionHelperOriginalFontFlags
            fontString:SetFont(font, size, flags)
            fontString.yuiAuctionHelperOriginalFont = nil
            fontString.yuiAuctionHelperOriginalFontSize = nil
            fontString.yuiAuctionHelperOriginalFontFlags = nil
        end
        browseResultsFontTargets[fontString] = nil
    end
end

local function ApplyBrowseResultsFontSizeToObject(object, size, seen, depth, includeMoneyDisplay)
    if not object or seen[object] or (depth and depth > 8) then
        return
    end
    seen[object] = true

    if object.IsObjectType and object:IsObjectType("FontString") then
        local isMoneyFontString = IsInsideAuctionMoneyDisplay(object)
        if includeMoneyDisplay or not isMoneyFontString then
            SetFontStringSize(object, size, isMoneyFontString and "money" or "text")
        end
        return
    end

    if object.GetNumRegions and object.GetRegions then
        for i = 1, object:GetNumRegions() do
            ApplyBrowseResultsFontSizeToObject(select(i, object:GetRegions()), size, seen, (depth or 0) + 1, includeMoneyDisplay)
        end
    end

    if object.GetNumChildren and object.GetChildren then
        for i = 1, object:GetNumChildren() do
            local child = select(i, object:GetChildren())
            if includeMoneyDisplay or not IsAuctionMoneyDisplayFrame(child) then
                ApplyBrowseResultsFontSizeToObject(child, size, seen, (depth or 0) + 1, includeMoneyDisplay)
            end
        end
    end
end

local function ApplyBrowseResultsFontSize()
    if not IsBrowseResultsFontFeatureEnabled() then
        RestoreBrowseResultsFontSize()
        return
    end

    local browseResultsFrame = AuctionHouseFrame and AuctionHouseFrame.BrowseResultsFrame
    local itemList = browseResultsFrame and browseResultsFrame.ItemList
    if not itemList then
        return
    end

    local size = GetBrowseResultsFontSize()
    local includeMoneyDisplay = DB:Get().browseResultsMoneyFontSizeEnabled == true
    local seen = {}

    if not includeMoneyDisplay then
        RestoreBrowseResultsFontSize("money")
    end

    if itemList.HeaderContainer then
        ApplyBrowseResultsFontSizeToObject(itemList.HeaderContainer, size, seen, 0, includeMoneyDisplay)
    end

    if itemList.ScrollBox and itemList.ScrollBox.ForEachFrame then
        itemList.ScrollBox:ForEachFrame(function(frame)
            ApplyBrowseResultsFontSizeToObject(frame, size, seen, 0, includeMoneyDisplay)
        end)
    end
end

local function RunScheduledBrowseResultsFontRefresh()
    browseResultsFontRefreshScheduled = false
    ApplyBrowseResultsFontSize()
end

local function ScheduleBrowseResultsFontRefresh()
    if browseResultsFontRefreshScheduled then
        return
    end

    browseResultsFontRefreshScheduled = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, RunScheduledBrowseResultsFontRefresh)
    else
        RunScheduledBrowseResultsFontRefresh()
    end
end

local function InstallBrowseResultsFontHooks()
    if browseResultsFontHooksInstalled or not YUI.IsRetail then
        return
    end

    local browseResultsFrame = AuctionHouseFrame and AuctionHouseFrame.BrowseResultsFrame
    local itemList = browseResultsFrame and browseResultsFrame.ItemList
    if not itemList then
        return
    end

    browseResultsFontHooksInstalled = true

    local scrollBox = itemList.ScrollBox
    local events = ScrollBoxListMixin and ScrollBoxListMixin.Event
    if scrollBox and scrollBox.RegisterCallback and events then
        if events.OnAcquiredFrame then
            scrollBox:RegisterCallback(events.OnAcquiredFrame, ScheduleBrowseResultsFontRefresh, itemList)
        end
        if events.OnInitializedFrame then
            scrollBox:RegisterCallback(events.OnInitializedFrame, ScheduleBrowseResultsFontRefresh, itemList)
        end
        if events.OnDataRangeChanged then
            scrollBox:RegisterCallback(events.OnDataRangeChanged, ScheduleBrowseResultsFontRefresh, itemList)
        end
    end

    if type(hooksecurefunc) == "function" then
        if itemList.RefreshScrollFrame then
            hooksecurefunc(itemList, "RefreshScrollFrame", ScheduleBrowseResultsFontRefresh)
        end
        if browseResultsFrame.UpdateBrowseResults then
            hooksecurefunc(browseResultsFrame, "UpdateBrowseResults", ScheduleBrowseResultsFontRefresh)
        end
        if browseResultsFrame.SetupTableBuilder then
            hooksecurefunc(browseResultsFrame, "SetupTableBuilder", ScheduleBrowseResultsFontRefresh)
        end
    end

    ScheduleBrowseResultsFontRefresh()
end

local function CreateUI()
    if ns.AuctionHelperFrame then return end
    
    local parent = AuctionHouseFrame
    if not parent then return end
    
    -- Forward declarations to ensure visibility across closures
    local RebuildTabContents
    local CreateTabContent
    local UpdateCounts
    local allItemButtons = {}
    local tabContentFrames = {}
    local tabs = {}
    
    local db = DB:Get()
    local isSkinEnabled = false
    if db.themeStyle == "native" then
        isSkinEnabled = false
    elseif db.themeStyle == "dark" then
        isSkinEnabled = true
    else
        isSkinEnabled = C_AddOns.IsAddOnLoaded("ElvUI") or C_AddOns.IsAddOnLoaded("NDui")
    end
    
    local f = GUI2:CreateFrame(parent, { name = "YUI_AuctionHelperFrame" })
    f:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, 0)
    f:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 2, 0)
    f:SetWidth(360) 
    f:SetFrameLevel(parent:GetFrameLevel() + 20)
    
    if isSkinEnabled then
        GUI2:CreateBackdrop(f, true)
    else
        -- Native system template: used only when the feature is set to Blizzard native style.
        local bgFrame = CreateFrame("Frame", nil, f, "NineSlicePanelTemplate")
        bgFrame:SetAllPoints(f)
        bgFrame:SetFrameLevel(f:GetFrameLevel() - 5)
        NineSliceUtil.ApplyLayoutByName(bgFrame, "ButtonFrameTemplateNoPortrait")
        
        local bgTexture = GUI2:CreateTexture(bgFrame, { layer = "BACKGROUND", subLevel = -7, texture = "Interface\\FrameGeneral\\UI-Background-Rock" })
        bgTexture:SetPoint("TOPLEFT", bgFrame, "TOPLEFT", 6, -2)
        bgTexture:SetPoint("BOTTOMRIGHT", bgFrame, "BOTTOMRIGHT", -2, 2)
        bgTexture:SetHorizTile(true)
        bgTexture:SetVertTile(true)
    end
    
    ns.AuctionHelperFrame = f
    
    -- Animation Group
    local iconSize = 14
    local btnSize = 16
    local animGroup = f:CreateAnimationGroup()
    local trans = animGroup:CreateAnimation("Translation")
    trans:SetDuration(0.2)
    trans:SetSmoothing("OUT")
    animGroup.trans = trans
    local alpha = animGroup:CreateAnimation("Alpha")
    alpha:SetDuration(0.2)
    alpha:SetSmoothing("OUT")
    animGroup.alpha = alpha
    f.animGroup = animGroup

    -- Expand Button (Attached to AuctionHouseFrame when collapsed)
    local expandBtn = GUI2:CreateButtonFrame(parent, { template = "BackdropTemplate" })
    expandBtn:SetFrameLevel(parent:GetFrameLevel() + 20)
    expandBtn:SetSize(20, 40)
    expandBtn:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
    expandBtn:Hide()
    
    if isSkinEnabled then
        GUI2:CreateBackdrop(expandBtn)
    else
        expandBtn:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        expandBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        expandBtn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end
    
    local expandIcon = GUI2:CreateTexture(expandBtn, { layer = "ARTWORK" })
    expandIcon:SetSize(iconSize, iconSize)
    expandIcon:SetPoint("CENTER")
    expandIcon:SetAtlas("uitools-icon-chevron-right")
    expandIcon:SetVertexColor(0.7, 0.7, 0.7)
    
    expandBtn:SetScript("OnEnter", function(self)
        expandIcon:SetVertexColor(1, 0.82, 0)
        if isSkinEnabled then
            local chrome = self.backdrop or self
            GUI2:SetBorderColor(chrome, "color.border.accent")
            chrome:SetBackdropColor(0.2, 0.2, 0.2, 1)
        else
            self:SetBackdropBorderColor(1, 0.82, 0, 1)
            self:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
        end
    end)
    expandBtn:SetScript("OnLeave", function(self)
        expandIcon:SetVertexColor(0.7, 0.7, 0.7)
        if isSkinEnabled then
            local chrome = self.backdrop or self
            GUI2:SetBorderColor(chrome, "color.border.default")
            chrome:SetBackdropColor(GUI2:GetColor("color.control.bg"))
        else
            self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
            self:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
        end
    end)
    
    expandBtn:SetScript("OnClick", function()
        expandBtn:Hide()
        f:Show()
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", parent, "TOPRIGHT", -48, 0)
        f:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", -48, 0)
        
        animGroup.trans:SetOffset(50, 0) 
        animGroup.alpha:SetFromAlpha(0)
        animGroup.alpha:SetToAlpha(1)
        animGroup:SetScript("OnFinished", function()
             f:ClearAllPoints()
             f:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, 0)
             f:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 2, 0)
        end)
        animGroup:Play()
    end)

    -- Close Button
    local closeBtn = GUI2:CreateButtonFrame(f, { template = "BackdropTemplate" })
    closeBtn:SetSize(btnSize, btnSize)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    
    closeBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    closeBtn:SetBackdropColor(0, 0, 0, 0)
    
    local closeIcon = GUI2:CreateTexture(closeBtn, { layer = "ARTWORK" })
    closeIcon:SetSize(iconSize, iconSize)
    closeIcon:SetPoint("CENTER")
    closeIcon:SetAtlas("uitools-icon-close")
    closeIcon:SetVertexColor(0.7, 0.7, 0.7)
    
    closeBtn:SetScript("OnEnter", function(self)
        closeIcon:SetVertexColor(1, 1, 1)
        self:SetBackdropColor(1, 0.2, 0.2, 0.5)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["tooltip.close"])
        GameTooltip:Show()
    end)
    closeBtn:SetScript("OnLeave", function(self)
        closeIcon:SetVertexColor(0.7, 0.7, 0.7)
        self:SetBackdropColor(0, 0, 0, 0)
        YUI.HideGameTooltip()
    end)
    
    closeBtn:SetScript("OnClick", function() 
        f:Hide() 
    end)
    
    -- Info/Settings Button
    local settingsBtn = GUI2:CreateButtonFrame(f, { template = "BackdropTemplate" })
    settingsBtn:SetSize(btnSize, btnSize)
    settingsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    
    settingsBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    settingsBtn:SetBackdropColor(0, 0, 0, 0)

    local settingsIcon = GUI2:CreateTexture(settingsBtn, { layer = "ARTWORK" })
    settingsIcon:SetSize(iconSize+2, iconSize+2)
    settingsIcon:SetPoint("CENTER")
    settingsIcon:SetAtlas("Warfronts-BaseMapIcons-Empty-Workshop-Minimap")

    settingsBtn:SetScript("OnEnter", function(self)
        settingsIcon:SetVertexColor(1, 1, 1)
        self:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["tooltip.settings"])
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function(self)
        settingsIcon:SetVertexColor(0.7, 0.7, 0.7)
        self:SetBackdropColor(0, 0, 0, 0)
        YUI.HideGameTooltip()
    end)
    
    -- Settings Frame
    local settingsFrame = GUI2:CreateFrame(f)
    settingsFrame:SetSize(260, 290)
    settingsFrame:SetPoint("TOPLEFT", f, "TOPRIGHT", 2, 0)
    settingsFrame:Hide()
    settingsFrame:SetFrameLevel(f:GetFrameLevel() + 5)
    
    if isSkinEnabled then
        GUI2:CreateBackdrop(settingsFrame, true)
    else
        -- Native system template: used only when the feature is set to Blizzard native style.
        local sBgFrame = CreateFrame("Frame", nil, settingsFrame, "NineSlicePanelTemplate")
        sBgFrame:SetAllPoints(settingsFrame)
        sBgFrame:SetFrameLevel(settingsFrame:GetFrameLevel() - 5)
        NineSliceUtil.ApplyLayoutByName(sBgFrame, "ButtonFrameTemplateNoPortrait")
        
        local sBgTexture = GUI2:CreateTexture(sBgFrame, { layer = "BACKGROUND", subLevel = -7, texture = "Interface\\FrameGeneral\\UI-Background-Rock" })
        sBgTexture:SetPoint("TOPLEFT", sBgFrame, "TOPLEFT", 6, -2)
        sBgTexture:SetPoint("BOTTOMRIGHT", sBgFrame, "BOTTOMRIGHT", -2, 3)
        sBgTexture:SetHorizTile(true)
        sBgTexture:SetVertTile(true)
    end

    -- Settings Close Button
    local sCloseBtn = GUI2:CreateButtonFrame(settingsFrame, { template = "BackdropTemplate" })
    sCloseBtn:SetSize(btnSize, btnSize)
    sCloseBtn:SetPoint("TOPRIGHT", -4, -4)
    
    sCloseBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    sCloseBtn:SetBackdropColor(0, 0, 0, 0)
    
    local sCloseIcon = GUI2:CreateTexture(sCloseBtn, { layer = "ARTWORK" })
    sCloseIcon:SetSize(iconSize, iconSize)
    sCloseIcon:SetPoint("CENTER")
    sCloseIcon:SetAtlas("uitools-icon-close")
    sCloseIcon:SetVertexColor(0.7, 0.7, 0.7)
    
    sCloseBtn:SetScript("OnEnter", function(self)
        sCloseIcon:SetVertexColor(1, 1, 1)
        self:SetBackdropColor(1, 0.2, 0.2, 0.5) -- Red hover
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["tooltip.close_settings"])
        GameTooltip:Show()
    end)
    sCloseBtn:SetScript("OnLeave", function(self)
        sCloseIcon:SetVertexColor(0.7, 0.7, 0.7)
        self:SetBackdropColor(0, 0, 0, 0)
        YUI.HideGameTooltip()
    end)
    
    sCloseBtn:SetScript("OnClick", function() 
        settingsFrame:Hide() 
    end)
    
    settingsBtn:SetScript("OnClick", function()
        if settingsFrame:IsShown() then
            settingsFrame:Hide()
        else
            settingsFrame:Show()
        end
    end)

    -- Initialize DB
    local db = DB:Get()

    -- Settings UI
    local sTitle = GUI2:CreateText(settingsFrame, L["settings.title"], 14)
    sTitle:SetPoint("TOP", 0, -5)
    GUI2:SetTextColorKey(sTitle, "color.text.accent")
    
    local yPos = -40

    local function SetTagTextVisibility(show)
        for _, btn in ipairs(allItemButtons) do
            if btn.tagText then
                if show then
                    btn.tagText:Show()
                else
                    btn.tagText:Hide()
                end
            end
        end
    end
    
    -- 1. Default Collapsed
    local collapseSwitch = GUI2:CreateSwitch(settingsFrame, {
        label = L["settings.default_collapsed"],
        default = db.defaultCollapsed,
        onText = L["settings.yes"],
        offText = L["settings.no"],
        onColor = {0.2, 0.6, 0.2},
        offColor = {0.5, 0.5, 0.5},
        width = 64,
        onChange = function(widget, value)
            db.defaultCollapsed = value
        end
    })
    collapseSwitch:SetPoint("TOPLEFT", 20, yPos)
    yPos = yPos - 30

    RebuildTabContents = function()
        if not tabContentFrames or not tabs then return end
        
        -- Clear old content
        for _, frame in pairs(tabContentFrames) do
            frame:Hide()
            frame:SetParent(nil)
        end
        wipe(tabContentFrames)
        if allItemButtons then
            wipe(allItemButtons)
        end
        
        -- Rebuild content for each tab
        for i, tabData in ipairs(TABS) do
            local content = CreateTabContent(i, tabData)
            content:Hide()
            tabContentFrames[i] = content
        end
        
        -- Restore current tab selection
        for _, btn in ipairs(tabs) do
            if btn.isSelected then
                btn:Click()
                break
            end
        end
        
        if UpdateCounts then
            UpdateCounts()
        end
    end

    -- 2. Show Tag Text
    local tagSwitch = GUI2:CreateSwitch(settingsFrame, {
        label = L["settings.show_tags"],
        default = db.showTagText,
        onText = L["settings.yes"],
        offText = L["settings.no"],
        onColor = {0.2, 0.6, 0.2},
        offColor = {0.5, 0.5, 0.5},
        width = 64,
        onChange = function(widget, value)
            db.showTagText = value
            SetTagTextVisibility(value)
        end
    })
    tagSwitch:SetPoint("TOPLEFT", 20, yPos)
    yPos = yPos - 35

    -- 3. Browse Results Font Size
    local browseFontSizeSlider
    local browseMoneyFontSizeSwitch
    local browseFontSizeSwitch = GUI2:CreateSwitch(settingsFrame, {
        label = L["settings.browse_results_font_size_enabled"],
        default = db.browseResultsFontSizeEnabled,
        onText = L["settings.yes"],
        offText = L["settings.no"],
        onColor = {0.2, 0.6, 0.2},
        offColor = {0.5, 0.5, 0.5},
        width = 64,
        onChange = function(widget, value)
            db.browseResultsFontSizeEnabled = value == true
            if browseFontSizeSlider and browseFontSizeSlider.SetDisabled then
                browseFontSizeSlider:SetDisabled(not db.browseResultsFontSizeEnabled)
            end
            if browseMoneyFontSizeSwitch and browseMoneyFontSizeSwitch.SetDisabled then
                browseMoneyFontSizeSwitch:SetDisabled(not db.browseResultsFontSizeEnabled)
            end
            if db.browseResultsFontSizeEnabled then
                InstallBrowseResultsFontHooks()
            end
            ApplyBrowseResultsFontSize()
        end
    })
    browseFontSizeSwitch:SetPoint("TOPLEFT", 20, yPos)
    yPos = yPos - 30

    browseMoneyFontSizeSwitch = GUI2:CreateSwitch(settingsFrame, {
        label = L["settings.browse_results_money_font_size_enabled"],
        default = db.browseResultsMoneyFontSizeEnabled,
        onText = L["settings.yes"],
        offText = L["settings.no"],
        onColor = {0.2, 0.6, 0.2},
        offColor = {0.5, 0.5, 0.5},
        width = 64,
        disabled = not db.browseResultsFontSizeEnabled,
        onChange = function(widget, value)
            db.browseResultsMoneyFontSizeEnabled = value == true
            if db.browseResultsFontSizeEnabled then
                ApplyBrowseResultsFontSize()
            else
                RestoreBrowseResultsFontSize("money")
            end
        end
    })
    browseMoneyFontSizeSwitch:SetPoint("TOPLEFT", 20, yPos)
    yPos = yPos - 30

    browseFontSizeSlider = GUI2:CreateSlider(settingsFrame, {
        label = L["settings.browse_results_font_size"],
        value = db.browseResultsFontSize,
        min = BROWSE_RESULTS_FONT_SIZE_MIN,
        max = BROWSE_RESULTS_FONT_SIZE_MAX,
        step = 1,
        width = 220,
        inputWidth = 36,
        labelWidth = 108,
        inline = true,
        disabled = not db.browseResultsFontSizeEnabled,
        onChange = function(widget, value)
            db.browseResultsFontSize = ClampBrowseResultsFontSize(value)
            if db.browseResultsFontSizeEnabled then
                ScheduleBrowseResultsFontRefresh()
            end
        end
    })
    browseFontSizeSlider:SetPoint("TOPLEFT", 20, yPos)
    yPos = yPos - 35
    
    -- 4. Category Style
    local styleLabel = GUI2:CreateText(settingsFrame, L["settings.category_style"], 14)
    styleLabel:SetPoint("TOPLEFT", 20, yPos)
    
    local styleDropdown = GUI2:CreateDropdown(settingsFrame, {
        options = {
            { text = L["settings.style.text"], value = "text" },
            { text = L["settings.style.background"], value = "background" }
        },
        default = db.categoryStyle,
        width = 120,
        onChange = function(widget, value)
            db.categoryStyle = value
            RebuildTabContents()
        end
    })
    styleDropdown:SetPoint("LEFT", styleLabel, "RIGHT", 10, 0)

    yPos = yPos - 35
    
    -- 5. Theme Style
    local themeLabel = GUI2:CreateText(settingsFrame, L["settings.theme_style"], 14)
    themeLabel:SetPoint("TOPLEFT", 20, yPos)
    
    local themeDropdown = GUI2:CreateDropdown(settingsFrame, {
        options = {
            { text = L["settings.theme.auto"], value = "auto" },
            { text = L["settings.theme.native"], value = "native" },
            { text = L["settings.theme.dark"], value = "dark" }
        },
        default = db.themeStyle,
        width = 120,
        onChange = function(widget, value)
            if db.themeStyle ~= value then
                db.themeStyle = value
                
                if not StaticPopupDialogs["YUI_AUCTIONHELPER_RELOAD"] then
                    StaticPopupDialogs["YUI_AUCTIONHELPER_RELOAD"] = {
                        text = L["settings.reload_prompt"],
                        button1 = L["settings.yes"],
                        button2 = L["settings.no"],
                        OnAccept = function()
                            ReloadUI()
                        end,
                        timeout = 0,
                        whileDead = true,
                        hideOnEscape = true,
                    }
                end
                StaticPopup_Show("YUI_AUCTIONHELPER_RELOAD")
            end
        end
    })
    themeDropdown:SetPoint("LEFT", themeLabel, "RIGHT", 10, 0)
    
    -- Collapse Button
    local collapseBtn = GUI2:CreateButtonFrame(f, { template = "BackdropTemplate" })
    collapseBtn:SetSize(btnSize, btnSize)
    collapseBtn:SetPoint("TOPLEFT", 4, -4)
    
    collapseBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    collapseBtn:SetBackdropColor(0, 0, 0, 0)
    
    local collapseIcon = GUI2:CreateTexture(collapseBtn, { layer = "ARTWORK" })
    collapseIcon:SetSize(iconSize, iconSize)
    collapseIcon:SetPoint("CENTER")
    collapseIcon:SetAtlas("uitools-icon-chevron-left")
    collapseIcon:SetVertexColor(0.7, 0.7, 0.7)
    
    collapseBtn:SetScript("OnEnter", function(self)
        collapseIcon:SetVertexColor(1, 0.82, 0)
        self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["tooltip.collapse"])
        GameTooltip:Show()
    end)
    collapseBtn:SetScript("OnLeave", function(self)
        collapseIcon:SetVertexColor(0.7, 0.7, 0.7)
        self:SetBackdropColor(0, 0, 0, 0)
        YUI.HideGameTooltip()
    end)
    
    collapseBtn:SetScript("OnClick", function()
        -- Force reset backdrop color before animation to avoid stuck color
        collapseIcon:SetVertexColor(0.7, 0.7, 0.7)
        collapseBtn:SetBackdropColor(0, 0, 0, 0)
        YUI.HideGameTooltip()

        animGroup.trans:SetOffset(-50, 0) -- Slide out to left
        animGroup.alpha:SetFromAlpha(1)
        animGroup.alpha:SetToAlpha(0)
        animGroup:SetScript("OnFinished", function()
            f:Hide()
            expandBtn:Show()
        end)
        animGroup:Play()
    end)
    
    -- Hook OnShow to ensure frame visibility on re-open
    parent:HookScript("OnShow", function()
        if DB:IsEnabled() then
            local db = DB:Get()
            if not f:IsShown() and not expandBtn:IsShown() then
                if db and db.defaultCollapsed then
                     expandBtn:Show()
                else
                     f:Show()
                     f:SetAlpha(1)
                end
                
                -- Reset position just in case
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, 0)
                f:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 2, 0)
            end
        end
    end)

    parent:HookScript("OnHide", function()
        f:Hide()
        settingsFrame:Hide()
        expandBtn:Hide()
    end)
    
    local title = GUI2:CreateText(f, L["title.short"], 14)

    title:SetPoint("TOP", 0, -5)
    GUI2:SetTextColorKey(title, "color.text.accent")
    
    -- Tab Container
    local tabContainer = GUI2:CreateFrame(f)
    tabContainer:SetPoint("TOPLEFT", 5, -35)
    tabContainer:SetPoint("TOPRIGHT", -5, -35)
    tabContainer:SetHeight(24)
    
    local scrollFrame = GUI2:CreateScrollFrame(f)
    scrollFrame:SetPoint("TOPLEFT", 5, -65) -- Shift down for Tabs
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)
    
    -- Cache item buttons to update counts
    -- initialized at top
    -- allItemButtons = {}
    -- tabContentFrames = {} 

    CreateTabContent = function(tabIndex, tabData)
        local container = GUI2:CreateFrame(scrollFrame)
        container:SetWidth(330)
        
        local yOffset = 5
        local xOffset_1st = 5
        local buttonSize = 36
        local spacing = 4
        local xRight = -9

        if not isSkinEnabled then
            xOffset_1st = 10
            xRight = -4
        end
        
        local db = DB:Get()
        
        local sourceData = {}
        if tabData.data then
             sourceData = tabData.data
        else
             for _, catKey in ipairs(tabData.categories) do
                 for _, d in ipairs(DATA) do
                     if d.key == catKey then
                         table.insert(sourceData, d)
                         break
                     end
                 end
             end
        end

        for _, cat in ipairs(sourceData) do
            local catTitle = GUI2:CreateText(container, L[cat.nameKey], 14)
            
            if db.categoryStyle == "background" then
                catTitle:SetTextColor(1, 1, 1)
                catTitle:SetPoint("TOPLEFT", 5, -yOffset - 2)
                catTitle:SetPoint("TOPRIGHT", -9, -yOffset - 2)
                catTitle:SetJustifyH("CENTER")
                
                local titleBg = GUI2:CreateTexture(container, { layer = "BACKGROUND" })
                titleBg:SetPoint("TOP", catTitle, "TOP", 0, 4)
                titleBg:SetPoint("BOTTOM", catTitle, "BOTTOM", 0, -4)
                titleBg:SetPoint("LEFT", xOffset_1st, 0)
                titleBg:SetPoint("RIGHT", xRight, 0)
                
                if cat.bgColor then
                    local r, g, b, a = ParseHexColor(cat.bgColor)
                    titleBg:SetColorTexture(r, g, b, a)
                else
                    titleBg:SetColorTexture(0.2, 0.4, 0.8, 0.8)
                end
                catTitle.bg = titleBg
            else
                catTitle:SetPoint("TOPLEFT", xOffset_1st, -yOffset)
                catTitle:SetTextColor(1, 1, 1)
            end
            
            yOffset = yOffset + 24
            
            for _, row in ipairs(cat.rows) do
                local xOffset = xOffset_1st
                for _, item in ipairs(row) do
                    local itemIDs = item.id
                    if type(itemIDs) ~= "table" then itemIDs = {itemIDs} end
                    local primaryID = itemIDs[1]
    
                    C_Item.RequestLoadItemDataByID(primaryID)
    
                    local btn = GUI2:CreateButtonFrame(container, { template = "BackdropTemplate" })
                    btn:SetSize(buttonSize, buttonSize)
                    btn:SetPoint("TOPLEFT", xOffset, -yOffset)
                    
                    GUI2:CreateBorder(btn, 0, 0, 0, 1)
                    
                    local icon = GUI2:CreateTexture(btn, { layer = "ARTWORK" })
                    icon:SetAllPoints()
                    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    btn.icon = icon
                    
                    if item.tagKey then
                        local tagKey = item.tagKey
                        if item.enUSShortTagKey and ns.Locale and ns.Locale.Current and ns.Locale:Current() == "enUS" then
                            tagKey = item.enUSShortTagKey
                        end

                        local tagText = L[tagKey]
                        if ns.Locale and ns.Locale.Current and ns.Locale:Current() == "enUS" and type(tagText) == "string" and tagText:len() > 6 then
                            tagText = tagText:sub(1, 6)
                        end

                        local tag = GUI2:CreateText(btn, tagText, 12)
                        tag:SetFont(GUI2.Fonts.normal, 12, "OUTLINE")
                        tag:SetPoint("TOP", 0, -2)
                        tag:SetJustifyH("CENTER")
                        if tag.SetWordWrap then
                            tag:SetWordWrap(false)
                        end
                        tag:SetShadowOffset(1, -1)
                        tag:SetTextColor(1, 0.82, 0)
                        btn.tagText = tag
                        
                        -- Apply Tag Text Visibility
                        if not db.showTagText then
                            tag:Hide()
                        end
                    end
                    
                    local count = GUI2:CreateText(btn, "", 11)
                    count:SetFont(GUI2.Fonts.normal, 11, "OUTLINE")
                    count:SetPoint("BOTTOMRIGHT", -1, 1)
                    count:SetJustifyH("RIGHT")
                    btn.count = count
                    
                    btn.itemIDs = itemIDs
                    btn.primaryID = primaryID
                    table.insert(allItemButtons, btn)
                    
                    local texture = GetItemIcon(primaryID)
                    icon:SetTexture(texture)
                    
                    btn:SetScript("OnEnter", function(self)
                        GUI2:SetBorderColor(self, "color.border.accent")
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetItemByID(self.primaryID)
                        GameTooltip:Show()
                    end)
                    
                    btn:SetScript("OnLeave", function(self)
                        GUI2:SetBorderColor(self, "color.border.default")
                        YUI.HideGameTooltip()
                    end)
                    
                    btn:SetScript("OnClick", function(self)
                        if AuctionHouseFrame and AuctionHouseFrame.SearchBar and AuctionHouseFrame.SearchBar.SearchBox then
                            if AuctionHouseFrame.SetDisplayMode then
                                 AuctionHouseFrame:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
                            end
                            
                            local name = GetItemInfo(self.primaryID)
                            if name then
                                AuctionHouseFrame.SearchBar.SearchBox:SetText(name)
                                AuctionHouseFrame.SearchBar.SearchButton:Click()
                            else
                                C_Item.RequestLoadItemDataByID(self.primaryID)
                                AuctionHouseFrame.SearchBar.SearchBox:SetText(self.primaryID) 
                                C_Timer.After(0.2, function()
                                    local loadedName = GetItemInfo(self.primaryID)
                                    if loadedName then
                                        AuctionHouseFrame.SearchBar.SearchBox:SetText(loadedName)
                                        AuctionHouseFrame.SearchBar.SearchButton:Click()
                                    else
                                        AuctionHouseFrame.SearchBar.SearchButton:Click()
                                    end
                                end)
                            end
                        end
                    end)
                    
                    xOffset = xOffset + buttonSize + spacing
                end
                yOffset = yOffset + buttonSize + spacing
            end
            yOffset = yOffset + 10
        end
        
        container:SetHeight(yOffset)
        return container
    end

    -- initialized at top
    -- local tabs = {}
    -- local tabContentFrames = {}
    local tabLeft = 5
    -- local tabWidth = (360 - 10 - tabLeft) / #TABS
    local tabWidth = (316) / #TABS

    if not isSkinEnabled then
        tabWidth = tabWidth - 1
    end

    -- Helper to set tab style based on state
    local function UpdateTabStyle(btn, isSelected)
        if isSkinEnabled then
            local chrome = btn.backdrop or btn
            if isSelected then
                chrome:SetBackdropColor(0.2, 0.2, 0.2, 1)
                GUI2:SetTextColorKey(btn.text, "color.text.accent")
                GUI2:SetBorderColor(chrome, "color.border.accent")
            else
                chrome:SetBackdropColor(0.1, 0.1, 0.1, 1)
                GUI2:SetTextColorKey(btn.text, "color.text.primary")
                GUI2:SetBorderColor(chrome, "color.border.default")
            end
        else
            if isSelected then
                btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
                btn:SetBackdropBorderColor(1, 0.82, 0, 1)
                GUI2:SetTextColorKey(btn.text, "color.text.accent")
            else
                btn:SetBackdropColor(0.1, 0.1, 0.1, 1)
                btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                btn.text:SetTextColor(1, 1, 1)
            end
        end
    end

    for i, tabData in ipairs(TABS) do
        local tabBtn = GUI2:CreateButtonFrame(tabContainer, { template = "BackdropTemplate" })
        
        if isSkinEnabled then
            tabBtn:SetSize(tabWidth, 24)
            tabBtn:SetPoint("LEFT", (i-1)*tabWidth + tabLeft, 0)
            -- Use CreateBackdrop to ensure pixel-perfect border structure
            GUI2:CreateBackdrop(tabBtn, false)
        else
            tabBtn:SetSize(tabWidth, 24)
            tabBtn:SetPoint("LEFT", (i-1)*tabWidth + tabLeft + 4, 0)
            tabBtn:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 16, edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            tabBtn:SetBackdropColor(0.1, 0.1, 0.1, 1)
            tabBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        end
        
        local text = GUI2:CreateText(tabBtn, L[tabData.nameKey], 12)
        text:SetPoint("CENTER")
        tabBtn.text = text
        
        -- Generate Content for this Tab
        local content = CreateTabContent(i, tabData)
        content:Hide()
        tabContentFrames[i] = content

        tabBtn:SetScript("OnEnter", function(self)
             if self.isSelected then return end
             if isSkinEnabled then
                 local chrome = self.backdrop or self
                 chrome:SetBackdropColor(0.2, 0.2, 0.2, 1)
                 GUI2:SetBorderColor(chrome, "color.border.accent")
             else
                 self:SetBackdropColor(0.2, 0.2, 0.2, 1)
                 self:SetBackdropBorderColor(1, 0.82, 0, 1)
             end
        end)

        tabBtn:SetScript("OnLeave", function(self)
             if self.isSelected then return end
             UpdateTabStyle(self, false)
        end)

        tabBtn:SetScript("OnClick", function()
             for j, btn in ipairs(tabs) do
                 if i == j then
                     btn.isSelected = true
                     UpdateTabStyle(btn, true)
                     tabContentFrames[j]:Show()
                     scrollFrame:SetScrollChild(tabContentFrames[j])
                     
                     -- Check if scrollbar is needed
                     local contentHeight = tabContentFrames[j]:GetHeight()
                     local scrollHeight = scrollFrame:GetHeight()
                     local scrollBar = scrollFrame.ScrollBar or _G[scrollFrame:GetName().."ScrollBar"]
                     
                     if contentHeight <= scrollHeight then
                         if scrollBar then
                             scrollBar:Hide()
                             scrollBar:SetAlpha(0)
                         end
                         scrollFrame:SetPoint("BOTTOMRIGHT", -5, 5)
                         scrollFrame:EnableMouseWheel(false)
                     else
                         if scrollBar then
                             scrollBar:Show()
                             scrollBar:SetAlpha(1)
                         end
                         scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)
                         scrollFrame:EnableMouseWheel(true)
                     end
                 else
                     btn.isSelected = false
                     UpdateTabStyle(btn, false)
                     tabContentFrames[j]:Hide()
                 end
             end
        end)
        
        table.insert(tabs, tabBtn)
    end
    
    -- Select First Tab
    tabs[1]:Click()
    
    UpdateCounts = function()
        for _, btn in ipairs(allItemButtons) do
            local total = 0
            for _, id in ipairs(btn.itemIDs) do
                total = total + GetItemCount(id, true)
            end
            
            if total > 0 then
                btn.count:SetText(total)
                btn.icon:SetDesaturated(false)
                btn.icon:SetVertexColor(1, 1, 1)
            else
                btn.count:SetText("")
                btn.icon:SetVertexColor(0.3, 0.3, 0.3)
            end
        end
    end
    
    -- Initial visibility based on defaultCollapsed setting
    if db.defaultCollapsed then
        f:Hide()
        expandBtn:Show()
    end

    function f:UpdateCounts()
        UpdateCounts()
    end
    YUI.Event:OffOwner(f)
    YUI.Event:On("BAG_UPDATE", "UpdateCounts", f)
    f:SetScript("OnShow", UpdateCounts)
    
    UpdateCounts()
    InstallBrowseResultsFontHooks()
end

ns.Components:RegisterFeature("AuctionHelper", {
    name = L["feature.name"],
    description = L["feature.description"],
    product = "auction_helper",
    default = true,
    callback = function(enable)
        auctionHelperFeatureActive = enable == true
        if enable then
            -- 如果已经创建了 Frame，则直接显示
            if ns.AuctionHelperFrame then
                ns.AuctionHelperFrame:Show()
                -- 重新注册事件（如果在禁用时注销了）
                YUI.Event:OffOwner(ns.AuctionHelperFrame)
                YUI.Event:On("BAG_UPDATE", "UpdateCounts", ns.AuctionHelperFrame)
                InstallBrowseResultsFontHooks()
                return
            end

            -- 否则注册事件监听加载
            if ns.AuctionHelperLoadHandle then
                YUI.Event:Off(ns.AuctionHelperLoadHandle)
            end
            ns.AuctionHelperLoadHandle = YUI.Event:On("ADDON_LOADED", function(_, addon)
                if addon == "Blizzard_AuctionHouseUI" then
                    CreateUI()
                    YUI.Event:Off(ns.AuctionHelperLoadHandle)
                    ns.AuctionHelperLoadHandle = nil
                end
            end)
            
            if C_AddOns.IsAddOnLoaded("Blizzard_AuctionHouseUI") then
                CreateUI()
                if ns.AuctionHelperLoadHandle then
                    YUI.Event:Off(ns.AuctionHelperLoadHandle)
                    ns.AuctionHelperLoadHandle = nil
                end
            end
        else
            auctionHelperFeatureActive = false
            RestoreBrowseResultsFontSize()
            if ns.AuctionHelperFrame then
                ns.AuctionHelperFrame:Hide()
                YUI.Event:OffOwner(ns.AuctionHelperFrame)
            end
            if ns.AuctionHelperLoadHandle then
                YUI.Event:Off(ns.AuctionHelperLoadHandle)
                ns.AuctionHelperLoadHandle = nil
            end
        end
    end
})
