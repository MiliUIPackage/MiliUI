local addonName, addon = ...

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local defaults = {
    global = {
        EMEOptions = {
            lfg = true,
            holyPower = false,
            totem = true,
            soulShards = false,
            achievementAlert = true,
            targetOfTarget = true,
            targetCast = true,
            focusTargetOfTarget = true,
            focusCast = true,
            compactRaidFrameContainer = true,
            talkingHead = true,
            minimap = false,
            minimapHeader = false,
            minimapResize = false,
            uiWidgetTopCenterContainerFrame = false,
            UIWidgetBelowMinimapContainerFrame = false,
            stanceBar = true,
            runes = false,
            arcaneCharges = false,
            chi = false,
            evokerEssences = false,
            showCoordinates = false,
            playerFrame = true,
            playerFrameResize = false,
			mainStatusTrackingBarContainer = true,
            secondaryStatusTrackingBarContainer = true,
            menu = true,
            bags = true,
            comboPoints = false,
            bonusRoll = true,
            actionBars = false,
            groupLootContainer = true,
            auctionMultisell = true,
            chatButtons = false,
            backpack = true,
            targetFrame = true,
            focusFrame = true,
            buffFrame = true,
            debuffFrame = true,
            objectiveTrackerFrame = true,
			targetFrameBuffs = false,
        },
        QueueStatusButton = {},
        TotemFrame = {},
        HolyPower = {},
        Achievements = {},
        SoulShards = {},
        ToT = {},
        TargetSpellBar = {},
        FocusToT = {},
        FocusSpellBar = {},
        UIWidgetTopCenterContainerFrame = {},
        UIWidgetBelowMinimapContainerFrame = {},
        ArenaEnemyFramesContainer = {},
        StanceBar = {},
        Runes = {},
        ArcaneCharges = {},
        Chi = {},
        EvokerEssences = {},
        PlayerFrame = {},
        MainStatusTrackingBarContainer = {},
        SecondaryStatusTrackingBarContainer = {},
        MicroMenu = {},
        ComboPoints = {},
        BonusRoll = {},
        MainMenuBar = {},
        MultiBarBottomLeft = {},
        MultiBarBottomRight = {},
        MultiBarRight = {},
        MultiBarLeft = {},
        MultiBar5 = {},
        MultiBar6 = {},
        MultiBar7 = {},
        CompactRaidFrameManager = {},
        ExpansionLandingPageMinimapButton = {},
        GroupLootContainer = {},
        AuctionHouseMultisellProgressFrame = {},
        QuickJoinToastButton = {},
        ChatFrameChannelButton = {},
        ChatFrameMenuButton = {},
        ContainerFrame1 = {},
        ContainerFrameCombinedBags = {},
        MinimapZoneName = {},
        MinimapSeparated = {},
		TargetDebuffs = {},
        TargetBuffs = {},
    }
}

local options = {
    type = "group",
    name = "編輯模式擴充包",
	set = function(info, value) addon.db.global.EMEOptions[info[#info]] = value end,
    get = function(info) return addon.db.global.EMEOptions[info[#info]] end,
    args = {
        description = {
            name = "所有變更都需要重新載入介面 /reload ! 如果你不想要插件動到某個框架，請取消勾選。",
            type = "description",
            fontSize = "medium",
            order = 0,
        },
        classResourceGroup = {
            name = "職業資源",
            type = "group",
            args = {
                holyPower = {
                    name = "聖能",
                    desc = "啟用/停用支援聖騎士的聖能",
                    type = "toggle",
                },
                soulShards = {
                    name = "靈魂裂片",
                    desc = "啟用/停用支援術士的靈魂裂片",
                    type = "toggle",
                },
                runes = {
                    name = "符文",
                    desc = "啟用/停用支援死亡騎士的符文",
                    type = "toggle",
                },
                arcaneCharges = {
                    name = "祕法充能",
                    desc = "啟用/停用支援法師的祕法充能",
                    type = "toggle",
                },
                chi = {
                    name = "真氣",
                    desc = "啟用/停用支援武僧的真氣",
                    type = "toggle",
                },
                evokerEssences = {
                    name = "龍能",
                    desc = "啟用/停用支援喚能師的龍能",
                    type = "toggle",
                },
                comboPoints = {
                    name = "連擊點數",
                    desc = "啟用/停用支援連擊點數",
                    type = "toggle",
                },
            },
        },
        targetGroup = {
            name = "目標和專注目標",
            type = "group",
            args = {
                targetOfTarget = {
                    name = "目標的目標",
                    desc = "啟用/停用支援目標的目標",
                    type = "toggle",
                },
                targetCast = {
                    name = "目標施法條",
                    desc = "啟用/停用支援目標施法條",
                    type = "toggle",
                },
                focusTargetOfTarget = {
                    name = "專注目標的目標",
                    desc = "啟用/停用支援專注目標的目標",
                    type = "toggle",
                },
                focusCast = {
                    name = "專注目標施法條",
                    desc = "啟用/停用支援專注目標施法條",
                    type = "toggle",
                },
                targetFrame = {
                    name = "目標",
                    desc = "啟用/停用目標框架的額外選項",
                    type = "toggle",
                },
                targetFrameBuffs = {
                    name = "目標增益",
                    desc = "啟用/停用支援目標增益和減益效果圖示",
                    type = "toggle",
                },
                focusFrame = {
                    name = "專注目標",
                    desc = "啟用/停用專注目標框架的額外選項",
                    type = "toggle",
                },
            },
        },
        totem = {
            name = "圖騰",
            desc = "啟用/停用支援圖騰",
            type = "toggle",
        },
        achievementAlert = {
            name = "成就通知",
            desc = "啟用/停用支援成就通知",
            type = "toggle",
        },
        
        compactRaidFrameContainer = {
            name = "團隊框架",
            desc = "啟用/停用團隊框架的額外選項",
            type = "toggle",
        },
        talkingHead = {
            name = "對話頭像",
            desc = "啟用/停用對話頭像的額外選項",
            type = "toggle",
        },
        minimapGroup = {
            name = "小地圖",
            type = "group",
            args = {
                minimap = {
                    name = "小地圖",
                    desc = "啟用/停用小地圖的額外選項",
                    type = "toggle",
                },
                minimapHeader = {
                    name = "小地圖標題列",
                    desc = "啟用/停用支援小地圖標題列。警告: 如果小地圖發生問題，請停用此選項。請確認沒有勾選 '標題顯示於下方'。",
                    type = "toggle",
                },
                minimapResize = {
                    name = "調整小地圖群組大小",
                    desc = "允許縮放整個小地圖群組，包含附加在上面的任何東西。注意: 同時使用兩種縮放大小滑桿可能會發生無法預期的結果。",
                    type = "toggle",
                },
            },
        },
        uiWidgetTopCenterContainerFrame = {
            name = "子區域資訊",
            desc = "啟用/停用支援畫面最頂端的子區域資訊，通常包含該區域的目標，例如戰歌峽谷的搶旗數目。請注意，如果所在的區域沒有任務目標，此處將不會顯示任何東西!",
            type = "toggle",
        },
        UIWidgetBelowMinimapContainerFrame = {
            name = "小地圖下方",
            desc = "啟用/停用支援小地圖下方的區域，通常包含 PvP 目標，像是戰歌峽谷的旗幟和基地佔領進度條。請注意，如果所在的地區沒有放任何東西在那裏，此處將不會顯示任何東西!",
            type = "toggle",
        },
        stanceBar = {
            name = "形態列",
            desc = "啟用/停用形態列的額外選項",
            type = "toggle",
        },
        showCoordinates = {
            name = "顯示座標",
            type = "toggle",
            desc = "顯示選取框架的視窗座標",
        },
        playerFrame = {
            name = "玩家框架",
            type = "toggle",
            desc = "啟用/停用玩家框架的額外選項",
        },
        playerFrameResize = {
            name = "調整玩家框架大小",
            desc = "允許玩家框架可以縮小到比內建介面預設的還小。注意: 同時使用兩種縮放大小滑桿可能會發生無法預期的結果。",
            type = "toggle",
															  
        },
		mainStatusTrackingBarContainer = {
            name = "經驗條",
            desc = "啟用/停用玩經驗條的額外選項",
            type = "toggle",
        },
        secondaryStatusTrackingBarContainer = {
            name = "聲望條",
            desc = "啟用/停用玩聲望條的額外選項",
            type = "toggle",
        },
        menuGroup = {
            name = "選單",
            type = "group",
            args = {
                menu = {
                    name = "微型選單",
                    desc = "啟用/停用玩微型選單的額外選項",
                    type = "toggle",
                },
                bags = {
                    name = "背包列",
                    desc = "啟用/停用背包列的額外選項",
                    type = "toggle",
                },
                lfg = {
                    name = "排隊資訊",
                    desc = "啟用/停用支援排隊資訊",
                    type = "toggle", 
                },
            },
        },
        
        buffFrame = {
            name = "增益效果",
            desc = "啟用/停用增益效果框架的額外選項",
            type = "toggle",
        },
        debuffFrame = {
            name = "減益效果",
            desc = "啟用/停用減益效果框架的額外選項",
            type = "toggle",
        },
        bonusRoll = {
            name = "骰子面板",
            desc = "啟用/停用支援骰子面板",
            type = "toggle",
        },
        actionBars = {
            name = "快捷列",
            desc = "允許快捷列的間距為零。警告: 所有快捷列都一定要至少移動過一次，並且停用 '自動貼齊'。不能完全不動，否則會發生錯誤。就算是移動後再移回原本的位置也可以!",
            type = "toggle",
        },
        groupLootContainer = {
            name = "獲得物品通知",
            desc = "啟用/停用獲得物品通知",
            type = "toggle",
        },
        auctionMultisell = {
            name = "拍賣場批次賣出",
            desc = "啟用/停用支援拍賣場批次賣出",
            type = "toggle",
        },
        chatButtons = {
            name = "聊天按鈕",
            desc = "啟用/停用支援聊天按鈕",
            type = "toggle",
        },
        backpack = {
            name = "背包",
            desc = "啟用/停用支援背包",
            type = "toggle",
        },
    },
}

function addon:initOptions()
    addon.db = LibStub("AceDB-3.0"):New("EditModeExpandedADB", defaults)
            
    AceConfigRegistry:RegisterOptionsTable(addonName, options)
    AceConfigDialog:AddToBlizOptions(addonName, "編輯模式")
end
