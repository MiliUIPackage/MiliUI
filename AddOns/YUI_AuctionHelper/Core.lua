-------------------------------------------------------------------------------
--- YUI 拍賣行購買助手
--- 用於快速搜索和購買拍賣行物品
-------------------------------------------------------------------------------

-- 如果 YUI 已加載，則不加載該插件
if C_AddOns.IsAddOnLoaded("YUI") then
    return
end

local _, ns = ...
local GUI = ns.GUI

-- 緩存全局函數
local GetItemIcon = GetItemIcon or C_Item.GetItemIconByID
local GetItemCount = GetItemCount
local GetItemInfo = GetItemInfo or C_Item.GetItemInfo
local C_AuctionHouse = C_AuctionHouse

-------------------------------------------------------------------------------
-- DB Abstraction
-------------------------------------------------------------------------------
local DB = {}

function DB:Get()
    if not YUI_AuctionHelperDB then YUI_AuctionHelperDB = {} end
    if not YUI_AuctionHelperDB.AuctionHelper then
        YUI_AuctionHelperDB.AuctionHelper = {
            defaultCollapsed = false,
            showTagText = true,
            categoryStyle = "background",
            themeStyle = "auto"
        }
    end
    if not YUI_AuctionHelperDB.AuctionHelper.themeStyle then
        YUI_AuctionHelperDB.AuctionHelper.themeStyle = "auto"
    end
    return YUI_AuctionHelperDB.AuctionHelper
end

function DB:IsEnabled()
    if YUI_AuctionHelperDB and YUI_AuctionHelperDB.AuctionHelper then
        return true
    end
    return false
end

local DATA = {
    {
        name = "增益",
        bgColor = "CC6600",
        rows = {
            {
                { id = {241320, 241321}, tag = "臨機" },
                { id = {241326, 241327}, tag = "致命" },
                { id = {241322, 241323}, tag = "精通" },
                { id = {241324, 241325}, tag = "加速" },
                { id = {259085}, tag = "符文" },                
            },
            {
                { id = {243735, 243736}, tag = "治療" },
                { id = {243733, 243734}, tag = "屬性" },
                { id = {243737, 243738}, tag = "傷害" },
                { id = {237367, 237369}, tag = "鈍器" },
                { id = {237370, 237371}, tag = "刀刃" },
                { id = {245879, 245880}, tag = "梵陀"  },
            }
        }
    },
    {
        name = "食物",
        bgColor = "339933",
        rows = {
            {
                { id = 255845, tag = "主屬" },
                { id = 255846, tag = "主屬" },
                { id = 242272, tag = "副屬" },
                { id = 242273, tag = "副屬" },
            },
            {
                { id = 242275, tag = "主屬" },
                { id = 255848, tag = "副屬" },
                { id = 242274, tag = "副屬" },
                { id = 242277, tag = "加速" },
                { id = 242286, tag = "加速" },
                { id = 242278, tag = "致命" },
                { id = 242283, tag = "致命" },
                { id = 242287, tag = "致命" },
            },
            {
                { id = 242276, tag = "臨機" },
                { id = 242280, tag = "臨機" },
                { id = 242284, tag = "臨機" },
                { id = 242281, tag = "精通" },
                { id = 242285, tag = "精通" },
                --{ id = 242291, tag = "精臨" },
                --{ id = 242293, tag = "速臨" },
                { id = 242299, tag = "速度" },
                { id = 242298, tag = "速度" },
                { id = 242289, tag = "肉片" },
            }
        }
    },
    {
        name = "藥水",
        bgColor = "8E44AD",
        rows = {
            {
                { id = { 241308, 241309 }, tag = "主屬" },
                { id = { 241288, 241289 }, tag = "副屬" },
                { id = { 241296, 241297 }, tag = "傷害" },
                { id = { 241286, 241287 }, tag = "護盾" },
                { id = { 241292, 241293 }, tag = "智力" },
                { id = { 241302, 241303 }, tag = "隱形" },
            },
            {
                { id = { 241304, 241305 }, tag = "生命"},
                { id = 241299, tag = "生命" },
                { id = { 241300, 241301 }, tag = "法力" },
                { id = { 241294, 241295 }, tag = "法力" },
                { id = { 241306, 241307 }, tag = "提神" },
                { id = { 241338, 241339 }, tag = "緩落" },
            }
        }
    },
    {
        name = "鑽石",
        bgColor = "2266AA",
        rows = {
            {
                { id = {240968, 240969}, tag = "法力" },
                { id = {240970, 240971}, tag = "護甲" },
                { id = {240966, 240967}, tag = "爆效" },
                { id = {240982, 240983}, tag = "主屬" },
            }
        }
    },
    {
        name = "血石",
        bgColor = "CC3333",
        rows = {
            {
                { id = 241142, tag = "堅定" },
                { id = 241143, tag = "認知" },
                { id = 241144, tag = "耐久" },
            }
        }
    },
    {
        name = "高級寶石",
        bgColor = "CC6600",
        rows = {
            { 
                { id = {240903,240904}, tag = "致命" },
                { id = {240907,240908}, tag = "致精" },
                { id = {240905,240906}, tag = "致速" },
                { id = {240909,240910}, tag = "致臨" },
                { id = {240895,240896}, tag = "精通" },
                { id = {240897,240898}, tag = "精致" },
                { id = {240899,240900}, tag = "精速" },
                { id = {240901,240902}, tag = "精臨" },
            },
            { 
                { id = {240887,240888}, tag = "加速" },
                { id = {240889,240890}, tag = "速致" },
                { id = {240891,240892}, tag = "速精" },
                { id = {240893,240894}, tag = "速臨" },
                { id = {240911,240912}, tag = "臨機" },
                { id = {240913,240914}, tag = "臨致" },
                { id = {240917,240918}, tag = "臨精" },
                { id = {240915,240916}, tag = "臨速" },
            },
        }
    },
    {
        name = "初級寶石",
        bgColor = "339933",
        rows = {
            { 
                { id = {240871,240872}, tag = "致命" },
                { id = {240875,240876}, tag = "致精" },
                { id = {240873,240874}, tag = "致速" },
                { id = {240877,240878}, tag = "致臨" },
                { id = {240863,240864}, tag = "精通" },
                { id = {240865,240866}, tag = "精致" },
                { id = {240867,240868}, tag = "精速" },
                { id = {240869,240870}, tag = "精臨" },
            },
            { 
                { id = {240855,240856}, tag = "加速" },
                { id = {240857,240858}, tag = "速致" },
                { id = {240859,240860}, tag = "速精" },
                { id = {240861,240862}, tag = "速臨" },
                { id = {240879,240880}, tag = "臨機" },
                { id = {240881,240882}, tag = "臨致" },
                { id = {240885,240886}, tag = "臨精" },
                { id = {240883,240884}, tag = "臨速" },
            },
        }
    },
    {
        name = "附魔 - 武器",
        bgColor = "9933CC",
        rows = {
            {
                { id = {244028, 244029}, tag = "主屬" },
                { id = {243970, 243971}, tag = "致命" },
                { id = {244030, 244031}, tag = "精通" },
                { id = {243972, 243973}, tag = "加速" },
                { id = {244001, 244000}, tag = "臨機" },
                { id = {243998, 243999}, tag = "承傷" },
                { id = {243996, 243997}, tag = "治療" },
                { id = {243968, 243969}, tag = "流血"  },
            },
            {
                { id = {244026, 244027}, tag = "烈焰" },
                { id = {257745, 257746}, tag = "鷹眼" },
                { id = {257747, 257748}, tag = "貓眼" },
                { id = {257749, 257750}, tag = "遠射" },
                { id = {257751, 257752}, tag = "轟爆" },
            }
        }
    },
    {
        name = "附魔 - 頭盔",
        bgColor = "9933CC",
        rows = {
            {
                { id = {243980, 243981}, tag = "速度" },
                { id = {243950, 243951}, tag = "汲取" },
                { id = {244006, 244007}, tag = "迴避" },
                { id = {243978, 243979}, tag = "速度" },
                { id = {243948, 243949}, tag = "汲取" },
                { id = {244004, 244005}, tag = "迴避" },
            }
        }
    },
    {
        name = "附魔 - 護肩",
        bgColor = "9933CC",
        rows = {
            {
                { id = {243962, 243963}, tag = "速度" },
                { id = {244020, 244021}, tag = "汲取" },
                { id = {243990, 243991}, tag = "迴避" },
                { id = {243960, 243961}, tag = "速度" },
                { id = {244018, 244019}, tag = "汲取" },
                { id = {243988, 243989}, tag = "迴避" },
            }
        }
    },
    {
        name = "附魔 - 胸甲",
        bgColor = "9933CC",
        rows = {
            {
                { id = {243976, 243977}, tag = "主屬" },
                { id = {243974, 243975}, tag = "敏捷" },
                { id = {243946, 243947}, tag = "力量" },
                { id = {244002, 244003}, tag = "智力" },
            }
        }
    },
    {
        name = "附魔 - 腿甲",
        bgColor = "9933CC",
        rows = {
            {
                { id = {244642, 244643}, tag = "護甲" },
                { id = {244640, 244641}, tag = "耐力" },
                { id = {244644, 244645}, tag = "斥候" },
                { id = {240154, 240155}, tag = "法力" },
                { id = {240094, 240095}, tag = "耐力" },
                { id = {240156, 240157}, tag = "鮮亮" },
            }
        }
    },
    {
        name = "附魔 - 靴子",
        bgColor = "9933CC",
        rows = {
            {
                { id = {244008, 244009}, tag = "速度" },
                { id = {243982, 243983}, tag = "汲取" },
                { id = {243952, 243953}, tag = "迴避" },
            }
        }
    },
    {
        name = "附魔 - 戒指",
        bgColor = "9933CC",
        rows = {
            {
                { id = {243986, 243987}, tag = "致命" },
                { id = {243958, 243959}, tag = "精通" },
                { id = {244014, 244015}, tag = "加速" },
                { id = {244016, 244017}, tag = "臨機" },
                { id = {243956, 243957}, tag = "爆效" },
            },
            {
                { id = {243984, 243985}, tag = "致命" },
                { id = {243954, 243955}, tag = "精通" },
                { id = {244010, 244011}, tag = "加速" },
                { id = {244012, 244013}, tag = "臨機" },
            }
        }
    },
    {
        name = "附魔 - 工具",
        bgColor = "9933CC",
        rows = {
            {
                { id = {244024, 244025}, tag = "精妙" },
                { id = {243966, 243967}, tag = "精明" },
                { id = {243994, 243995}, tag = "複數" },
                { id = {243964, 243965}, tag = "感知" },
                { id = {244022, 244023}, tag = "純熟" },
                { id = {243992, 243993}, tag = "技法" },
            }
        }
    },
    {
        name = "其他",
        bgColor = "607D8B",
        rows = {
            {
                { id = 219905, tag = "YY鼓" },
                { id = {248486, 269586}, tag = "戰復" },
                { id = 132514, tag = "修理" },
                { id = 260232, tag = "鑰匙"},
                { id = {245799, 245800}, tag = "銀月" },
                { id = {245793, 245794}, tag = "奇點"},
                { id = {245795, 245796}, tag = "哈提" },
                { id = {245797, 245798}, tag = "阿曼" },
            }
        }
    },
    {
        name = "書狀 - 武器護甲",
        bgColor = "339933",
        rows = {
            {
                { id = {245789, 245790}, tag = "致精" },
                { id = {245785, 245786}, tag = "致速" },
                { id = {245791, 245792}, tag = "致臨" },
                { id = {245783, 245784}, tag = "速精" },
                { id = {245781, 245782}, tag = "速臨" },
                { id = {245787, 245788}, tag = "精臨" },
            }
        }
    },
    {
        name = "書狀 - 專業工具",
        bgColor = "008B8B",
        rows = {
            {
                { id = {245820, 245821}, tag = "速度" },
                { id = {245818, 245819}, tag = "複數" },
                { id = {245814, 245815}, tag = "精妙" },
                { id = {245826, 245827}, tag = "純熟" },
                { id = {245816, 245817}, tag = "精明" },
                { id = {245824, 245825}, tag = "感知" },
                { id = {245822, 245823}, tag = "技法" },
            }
        }
    },
    {
        name = "裝飾材料",
        bgColor = "8E44AD",
        rows = {
            {
                { id = {244603, 244604}, tag = "穿山" },
                { id = {244607, 244608}, tag = "孢子" },
                { id = {244674, 244675}, tag = "吞噬" },
                { id = {240166, 240167}, tag = "奧紋" },
                { id = {240164, 240165}, tag = "日炎" },
                
            },
            {
                { id = {245871, 245872}, tag = "鮮血" },
                { id = {245875, 245876}, tag = "狩獵" },
                { id = {245877, 245878}, tag = "腐爛" },
                { id = {245873, 245874}, tag = "虛無" },
                { id = {248130}, tag = "清除" },
            }
        }
    },
    {
        name = "工程榫輪",
        bgColor = "2266AA",
        rows = {
            {
                { id = {244697, 244698}, tag = "致命" },
                { id = {244699, 244700}, tag = "加速" },
                { id = {244703, 244704}, tag = "臨機" },
                { id = {244701, 244702}, tag = "精通" },
            }
        }
    },
}

local TABS = {
    { name = "|A:Food:16:16:0:1|a 消耗品", categories = {"增益", "食物", "藥水", "其他"} },
    { name = "|A:keyflameon-32x32:14:14:0:1|a 寶石", categories = {"鑽石", "血石", "高級寶石", "初級寶石"} },
    { name = "|A:UpgradeItem-32x32:14:14:0:0|a 附魔", categories = {"附魔 - 武器", "附魔 - 頭盔", "附魔 - 護肩", "附魔 - 胸甲", "附魔 - 腿甲", "附魔 - 靴子", "附魔 - 戒指", "附魔 - 工具"} },
    { name = "|A:Professions-Crafting-Orders-Icon:16:16:0:1|a 製作", categories = {"書狀 - 武器護甲", "書狀 - 專業工具", "裝飾材料", "工程榫輪"} },
}

local function ParseHexColor(hex)
    if not hex then return 0.2, 0.4, 0.8, 0.8 end
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) or 51
    local g = tonumber(hex:sub(3, 4), 16) or 102
    local b = tonumber(hex:sub(5, 6), 16) or 204
    return r / 255, g / 255, b / 255, 0.8
end

local function CreateUI()
    if ns.AuctionHelperFrame then return end
    
    local parent = AuctionHouseFrame
    if not parent then return end
    
    -- Forward declarations to ensure visibility across closures
    local RebuildTabContents
    local CreateTabContent
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
    
    local f = CreateFrame("Frame", "YUI_AuctionHelperFrame", parent)
    f:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, 0)
    f:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 2, 0)
    f:SetWidth(360) 
    f:SetFrameLevel(parent:GetFrameLevel() + 20)
    
    if isSkinEnabled then
        GUI:CreateBackdrop(f, true)
    else
        local bgFrame = CreateFrame("Frame", nil, f, "NineSlicePanelTemplate")
        bgFrame:SetAllPoints(f)
        bgFrame:SetFrameLevel(f:GetFrameLevel() - 5)
        NineSliceUtil.ApplyLayoutByName(bgFrame, "ButtonFrameTemplateNoPortrait")
        
        local bgTexture = bgFrame:CreateTexture(nil, "BACKGROUND", nil, -7)
        bgTexture:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
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
    local expandBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    expandBtn:SetFrameLevel(parent:GetFrameLevel() + 20)
    expandBtn:SetSize(20, 40)
    expandBtn:SetPoint("TOPLEFT", parent, "TOPRIGHT", 0, 0)
    expandBtn:Hide()
    
    if isSkinEnabled then
        GUI:CreateBackdrop(expandBtn)
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
    
    local expandIcon = expandBtn:CreateTexture(nil, "ARTWORK")
    expandIcon:SetSize(iconSize, iconSize)
    expandIcon:SetPoint("CENTER")
    expandIcon:SetAtlas("uitools-icon-chevron-right")
    expandIcon:SetVertexColor(0.7, 0.7, 0.7)
    
    expandBtn:SetScript("OnEnter", function(self)
        expandIcon:SetVertexColor(1, 0.82, 0)
        if isSkinEnabled then
            GUI:SetBorderColor(self, unpack(GUI.Colors.border_highlight))
            self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        else
            self:SetBackdropBorderColor(1, 0.82, 0, 1)
            self:SetBackdropColor(0.2, 0.2, 0.2, 0.9)
        end
    end)
    expandBtn:SetScript("OnLeave", function(self)
        expandIcon:SetVertexColor(0.7, 0.7, 0.7)
        if isSkinEnabled then
            GUI:SetBorderColor(self, unpack(GUI.Colors.border))
            self:SetBackdropColor(unpack(GUI.Colors.bg))
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
    local closeBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    closeBtn:SetSize(btnSize, btnSize)
    closeBtn:SetPoint("TOPRIGHT", -4, -4)
    
    closeBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    closeBtn:SetBackdropColor(0, 0, 0, 0)
    
    local closeIcon = closeBtn:CreateTexture(nil, "ARTWORK")
    closeIcon:SetSize(iconSize, iconSize)
    closeIcon:SetPoint("CENTER")
    closeIcon:SetAtlas("uitools-icon-close")
    closeIcon:SetVertexColor(0.7, 0.7, 0.7)
    
    closeBtn:SetScript("OnEnter", function(self)
        closeIcon:SetVertexColor(1, 1, 1)
        self:SetBackdropColor(1, 0.2, 0.2, 0.5)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("關閉")
        GameTooltip:Show()
    end)
    closeBtn:SetScript("OnLeave", function(self)
        closeIcon:SetVertexColor(0.7, 0.7, 0.7)
        self:SetBackdropColor(0, 0, 0, 0)
        GameTooltip:Hide()
    end)
    
    closeBtn:SetScript("OnClick", function() 
        f:Hide() 
    end)
    
    -- Info/Settings Button
    local settingsBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    settingsBtn:SetSize(btnSize, btnSize)
    settingsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    
    settingsBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    settingsBtn:SetBackdropColor(0, 0, 0, 0)

    local settingsIcon = settingsBtn:CreateTexture(nil, "ARTWORK")
    settingsIcon:SetSize(iconSize+2, iconSize+2)
    settingsIcon:SetPoint("CENTER")
    settingsIcon:SetAtlas("Warfronts-BaseMapIcons-Empty-Workshop-Minimap")

    settingsBtn:SetScript("OnEnter", function(self)
        settingsIcon:SetVertexColor(1, 1, 1)
        self:SetBackdropColor(0.2, 0.2, 0.2, 0.5)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("設置")
        GameTooltip:Show()
    end)
    settingsBtn:SetScript("OnLeave", function(self)
        settingsIcon:SetVertexColor(0.7, 0.7, 0.7)
        self:SetBackdropColor(0, 0, 0, 0)
        GameTooltip:Hide()
    end)
    
    -- Info Button
    if not C_AddOns.IsAddOnLoaded("WYJJDB") and not C_AddOns.IsAddOnLoaded("YUI") then
        local infoBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        infoBtn:SetSize(btnSize, btnSize)
        infoBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -4, 0)
        
        infoBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
        infoBtn:SetBackdropColor(0, 0, 0, 0)
        
        local infoIcon = infoBtn:CreateTexture(nil, "ARTWORK")
        infoIcon:SetSize(iconSize + 2, iconSize + 2)
        infoIcon:SetPoint("CENTER")
        infoIcon:SetAtlas("Warfronts-BaseMapIcons-Empty-Armory-Minimap")
        infoIcon:SetVertexColor(0.7, 0.7, 0.7)
        
        infoBtn:SetScript("OnEnter", function(self) 
            infoIcon:SetVertexColor(1, 1, 1) 
            self:SetBackdropColor(0.2, 0.2, 0.2, 0.5) 
            GameTooltip:SetOwner(self, "ANCHOR_TOP") 
            GameTooltip:AddLine("完整版|cFFFF00FFY|r|cFFFF6666U|r|cFFFF9900I|r配置分享", 1, 0.82, 0) 
            GameTooltip:AddLine(" ") 
            GameTooltip:AddLine("網易DD: 385157", 1, 1, 1) 
            GameTooltip:AddLine("新手盒子: 76393925", 1, 1, 1) 
            GameTooltip:AddLine(" ") 
            GameTooltip:AddDoubleLine("Bilibili", "阿言同學AI", 0.6, 0.6, 0.6, 1, 0.6, 0.6) -- Pink 
            GameTooltip:AddDoubleLine("抖音", "阿言YUI", 0.6, 0.6, 0.6, 0.6, 0.6, 1) -- 紫色 
            GameTooltip:Show() 
        end)
        
        infoBtn:SetScript("OnLeave", function(self)
            infoIcon:SetVertexColor(0.7, 0.7, 0.7)
            self:SetBackdropColor(0, 0, 0, 0)
            GameTooltip:Hide()
        end)
    end
    
    -- Settings Frame
    local settingsFrame = CreateFrame("Frame", nil, f)
    settingsFrame:SetSize(200, 200)
    settingsFrame:SetPoint("TOPLEFT", f, "TOPRIGHT", 2, 0)
    settingsFrame:Hide()
    settingsFrame:SetFrameLevel(f:GetFrameLevel() + 5)
    
    if isSkinEnabled then
        GUI:CreateBackdrop(settingsFrame, true)
    else
        local sBgFrame = CreateFrame("Frame", nil, settingsFrame, "NineSlicePanelTemplate")
        sBgFrame:SetAllPoints(settingsFrame)
        sBgFrame:SetFrameLevel(settingsFrame:GetFrameLevel() - 5)
        NineSliceUtil.ApplyLayoutByName(sBgFrame, "ButtonFrameTemplateNoPortrait")
        
        local sBgTexture = sBgFrame:CreateTexture(nil, "BACKGROUND", nil, -7)
        sBgTexture:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
        sBgTexture:SetPoint("TOPLEFT", sBgFrame, "TOPLEFT", 6, -2)
        sBgTexture:SetPoint("BOTTOMRIGHT", sBgFrame, "BOTTOMRIGHT", -2, 3)
        sBgTexture:SetHorizTile(true)
        sBgTexture:SetVertTile(true)
    end

    -- Settings Close Button
    local sCloseBtn = CreateFrame("Button", nil, settingsFrame, "BackdropTemplate")
    sCloseBtn:SetSize(btnSize, btnSize)
    sCloseBtn:SetPoint("TOPRIGHT", -4, -4)
    
    sCloseBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    sCloseBtn:SetBackdropColor(0, 0, 0, 0)
    
    local sCloseIcon = sCloseBtn:CreateTexture(nil, "ARTWORK")
    sCloseIcon:SetSize(iconSize, iconSize)
    sCloseIcon:SetPoint("CENTER")
    sCloseIcon:SetAtlas("uitools-icon-close")
    sCloseIcon:SetVertexColor(0.7, 0.7, 0.7)
    
    sCloseBtn:SetScript("OnEnter", function(self)
        sCloseIcon:SetVertexColor(1, 1, 1)
        self:SetBackdropColor(1, 0.2, 0.2, 0.5) -- Red hover
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("關閉設置")
        GameTooltip:Show()
    end)
    sCloseBtn:SetScript("OnLeave", function(self)
        sCloseIcon:SetVertexColor(0.7, 0.7, 0.7)
        self:SetBackdropColor(0, 0, 0, 0)
        GameTooltip:Hide()
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
    local sTitle = GUI:CreateText(settingsFrame, "設置", 14)
    sTitle:SetPoint("TOP", 0, -5)
    sTitle:SetTextColor(unpack(GUI.Colors.text_highlight))
    
    local yPos = -40
    
    -- 1. Default Collapsed
    local collapseSwitch = GUI:CreateSwitch(settingsFrame, {
        label = "預設折疊",
        default = db.defaultCollapsed,
        onText = "是",
        offText = "否",
        onColor = {0.2, 0.6, 0.2},
        offColor = {0.5, 0.5, 0.5},
        width = 50,
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
        
        -- Trigger count update
        if f:GetScript("OnEvent") then
            f:GetScript("OnEvent")(f, "BAG_UPDATE")
        end
    end

    -- 2. Show Tag Text
    local tagSwitch = GUI:CreateSwitch(settingsFrame, {
        label = "顯示標簽",
        default = db.showTagText,
        onText = "是",
        offText = "否",
        onColor = {0.2, 0.6, 0.2},
        offColor = {0.5, 0.5, 0.5},
        width = 50,
        onChange = function(widget, value)
            db.showTagText = value
            RebuildTabContents()
        end
    })
    tagSwitch:SetPoint("TOPLEFT", 20, yPos)
    yPos = yPos - 35
    
    -- 3. Category Style
    local styleLabel = GUI:CreateText(settingsFrame, "分類風格", 14)
    styleLabel:SetPoint("TOPLEFT", 20, yPos)
    
    local styleDropdown = GUI:CreateDropdown(settingsFrame, {
        options = {
            { text = "純白文字", value = "text" },
            { text = "彩色背景", value = "background" }
        },
        default = db.categoryStyle,
        width = 100,
        onChange = function(widget, value)
            db.categoryStyle = value
            RebuildTabContents()
        end
    })
    styleDropdown:SetPoint("LEFT", styleLabel, "RIGHT", 10, 0)

    yPos = yPos - 35
    
    -- 4. Theme Style
    local themeLabel = GUI:CreateText(settingsFrame, "外觀風格", 14)
    themeLabel:SetPoint("TOPLEFT", 20, yPos)
    
    local themeDropdown = GUI:CreateDropdown(settingsFrame, {
        options = {
            { text = "自動", value = "auto" },
            { text = "原生", value = "native" },
            { text = "暗黑", value = "dark" }
        },
        default = db.themeStyle,
        width = 100,
        onChange = function(widget, value)
            if db.themeStyle ~= value then
                db.themeStyle = value
                
                if not StaticPopupDialogs["YUI_AUCTIONHELPER_RELOAD"] then
                    StaticPopupDialogs["YUI_AUCTIONHELPER_RELOAD"] = {
                        text = "更改外觀風格需要重載界面才能生效。\n是否立即重載？",
                        button1 = "是",
                        button2 = "否",
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
    local collapseBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    collapseBtn:SetSize(btnSize, btnSize)
    collapseBtn:SetPoint("TOPLEFT", 4, -4)
    
    collapseBtn:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    collapseBtn:SetBackdropColor(0, 0, 0, 0)
    
    local collapseIcon = collapseBtn:CreateTexture(nil, "ARTWORK")
    collapseIcon:SetSize(iconSize, iconSize)
    collapseIcon:SetPoint("CENTER")
    collapseIcon:SetAtlas("uitools-icon-chevron-left")
    collapseIcon:SetVertexColor(0.7, 0.7, 0.7)
    
    collapseBtn:SetScript("OnEnter", function(self)
        collapseIcon:SetVertexColor(1, 0.82, 0)
        self:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("折疊")
        GameTooltip:Show()
    end)
    collapseBtn:SetScript("OnLeave", function(self)
        collapseIcon:SetVertexColor(0.7, 0.7, 0.7)
        self:SetBackdropColor(0, 0, 0, 0)
        GameTooltip:Hide()
    end)
    
    collapseBtn:SetScript("OnClick", function()
        -- Force reset backdrop color before animation to avoid stuck color
        collapseIcon:SetVertexColor(0.7, 0.7, 0.7)
        collapseBtn:SetBackdropColor(0, 0, 0, 0)
        GameTooltip:Hide()

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
    
    local title 
    
    if not C_AddOns.IsAddOnLoaded("YUI") and C_AddOns.IsAddOnLoaded("WYJJDB") then
        title = GUI:CreateText(f, "購物助手", 14)
    else
        title = GUI:CreateText(f, "|cFFFF00FFY|r|cFFFF6666U|r|cFFFF9900I|r 購物助手", 14)
    end

    title:SetPoint("TOP", 0, -5)
    title:SetTextColor(unpack(GUI.Colors.text_highlight))
    
    -- Tab Container
    local tabContainer = CreateFrame("Frame", nil, f)
    tabContainer:SetPoint("TOPLEFT", 5, -35)
    tabContainer:SetPoint("TOPRIGHT", -5, -35)
    tabContainer:SetHeight(24)
    
    local scrollFrame = GUI:CreateScrollFrame(f)
    scrollFrame:SetPoint("TOPLEFT", 5, -65) -- Shift down for Tabs
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)
    
    -- Cache item buttons to update counts
    -- initialized at top
    -- allItemButtons = {}
    -- tabContentFrames = {} 

    CreateTabContent = function(tabIndex, tabData)
        local container = CreateFrame("Frame", nil, scrollFrame)
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
             for _, catName in ipairs(tabData.categories) do
                 for _, d in ipairs(DATA) do
                     if d.name == catName then
                         table.insert(sourceData, d)
                         break
                     end
                 end
             end
        end

        for _, cat in ipairs(sourceData) do
            local catTitle = GUI:CreateText(container, cat.name, 14)
            
            if db.categoryStyle == "background" then
                catTitle:SetTextColor(1, 1, 1)
                catTitle:SetPoint("TOPLEFT", 5, -yOffset - 2)
                catTitle:SetPoint("TOPRIGHT", -9, -yOffset - 2)
                catTitle:SetJustifyH("CENTER")
                
                local titleBg = container:CreateTexture(nil, "BACKGROUND")
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
    
                    local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
                    btn:SetSize(buttonSize, buttonSize)
                    btn:SetPoint("TOPLEFT", xOffset, -yOffset)
                    
                    GUI:CreateBorder(btn, 0, 0, 0, 1)
                    
                    local icon = btn:CreateTexture(nil, "ARTWORK")
                    icon:SetAllPoints()
                    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    btn.icon = icon
                    
                    if item.tag then
                        local tag = GUI:CreateText(btn, item.tag, 12)
                        tag:SetFont(GUI.Fonts.normal, 12, "OUTLINE")
                        tag:SetPoint("TOP", 0, -2) 
                        tag:SetShadowOffset(1, -1)
                        tag:SetTextColor(1, 0.82, 0)
                        btn.tagText = tag
                        
                        -- Apply Tag Text Visibility
                        if not db.showTagText then
                            tag:Hide()
                        end
                    end
                    
                    local count = GUI:CreateText(btn, "", 11)
                    count:SetFont(GUI.Fonts.normal, 11, "OUTLINE")
                    count:SetPoint("BOTTOMRIGHT", -1, 1)
                    count:SetJustifyH("RIGHT")
                    btn.count = count
                    
                    btn.itemIDs = itemIDs
                    btn.primaryID = primaryID
                    table.insert(allItemButtons, btn)
                    
                    local texture = GetItemIcon(primaryID)
                    icon:SetTexture(texture)
                    
                    btn:SetScript("OnEnter", function(self)
                        GUI:SetBorderColor(self, unpack(GUI.Colors.border_highlight))
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetItemByID(self.primaryID)
                        GameTooltip:Show()
                    end)
                    
                    btn:SetScript("OnLeave", function(self)
                        GUI:SetBorderColor(self, unpack(GUI.Colors.border))
                        GameTooltip:Hide()
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
            if isSelected then
                btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
                btn.text:SetTextColor(unpack(GUI.Colors.text_highlight))
                if btn.backdrop then
                    GUI:SetBorderColor(btn.backdrop, unpack(GUI.Colors.border_highlight))
                end
            else
                btn:SetBackdropColor(0.1, 0.1, 0.1, 1)
                btn.text:SetTextColor(1, 1, 1)
                if btn.backdrop then
                    GUI:SetBorderColor(btn.backdrop, unpack(GUI.Colors.border))
                end
            end
        else
            if isSelected then
                btn:SetBackdropColor(0.2, 0.2, 0.2, 1)
                btn:SetBackdropBorderColor(1, 0.82, 0, 1)
                btn.text:SetTextColor(unpack(GUI.Colors.text_highlight))
            else
                btn:SetBackdropColor(0.1, 0.1, 0.1, 1)
                btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                btn.text:SetTextColor(1, 1, 1)
            end
        end
    end

    for i, tabData in ipairs(TABS) do
        local tabBtn = CreateFrame("Button", nil, tabContainer, "BackdropTemplate")
        
        if isSkinEnabled then
            tabBtn:SetSize(tabWidth, 24)
            tabBtn:SetPoint("LEFT", (i-1)*tabWidth + tabLeft, 0)
            -- Use CreateBackdrop to ensure pixel-perfect border structure
            GUI:CreateBackdrop(tabBtn, false)
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
        
        local text = GUI:CreateText(tabBtn, tabData.name, 12)
        text:SetPoint("CENTER")
        tabBtn.text = text
        
        -- Generate Content for this Tab
        local content = CreateTabContent(i, tabData)
        content:Hide()
        tabContentFrames[i] = content

        tabBtn:SetScript("OnEnter", function(self)
             if self.isSelected then return end
             if isSkinEnabled then
                 self:SetBackdropColor(0.2, 0.2, 0.2, 1)
                 if self.backdrop then
                     GUI:SetBorderColor(self.backdrop, unpack(GUI.Colors.border_highlight))
                 end
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
    
    local function UpdateCounts()
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

    f:RegisterEvent("BAG_UPDATE")
    f:SetScript("OnEvent", UpdateCounts)
    f:SetScript("OnShow", UpdateCounts)
    
    UpdateCounts()
end

-- 插件加載事件
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
    if addon == ADDON_NAME then
        -- 初始化 DB
        DB:Get()
        -- 如果拍賣行已經加載，則創建 UI
        if C_AddOns.IsAddOnLoaded("Blizzard_AuctionHouseUI") then
            CreateUI()
        end
    elseif addon == "Blizzard_AuctionHouseUI" then
        CreateUI()
    end
end)
