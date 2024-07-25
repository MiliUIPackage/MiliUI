if (GetLocale() ~= "zhCN") then
  return
end

local LPName, LPaddon = ...
local optionsPanel = CreateFrame("Frame", LPName.."OptionsPanel", InterfaceOptionsFramePanelContainer)
optionsPanel.name = LPName
optionsPanel:Hide()
local strangerGroupToggleButton = CreateFrame("CheckButton", LPName.."StrangerGroupToggleButton", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
strangerGroupToggleButton:SetPoint("TOPLEFT", 16, -317)
strangerGroupToggleButton.Text:SetText("拒绝所有组队邀请   (限邀公会、社群、好友、密语对象)")
strangerGroupToggleButton:SetScript("OnClick", function(self)
LPaddon.strangerGroupEnabled = self:GetChecked()
end)

--"聊天过滤功能和他的分隔线
local function CreateSeparator(parent, xOffset, yOffset, width, height)
    local separator = parent:CreateTexture(nil, "OVERLAY")
    separator:SetSize(width, height)
    separator:SetColorTexture(0.8, 0.8, 0.8, 1)
    separator:SetPoint("TOPLEFT", xOffset, -yOffset)
   return separator
end
local filterSeparator = CreateSeparator(optionsPanel, 600, 36, optionsPanel:GetWidth() - 200, 1)
local filterSeparator = CreateSeparator(optionsPanel, 221, 36, optionsPanel:GetWidth() - 200, 1)
local filterTitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
filterTitle:SetPoint("TOPLEFT", 258, -28)
filterTitle:SetText("聊天过滤功能")

local messageToggleButton = CreateFrame("CheckButton", LPName.."MessageToggleButton", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
messageToggleButton:SetPoint("TOPLEFT", 16, -44)
messageToggleButton.Text:SetText("隐藏任何包含简体字的讯息     (只有频道、说、大喊、耳语生效)")
messageToggleButton:SetScript("OnClick", function(self)
    LPaddon.checkMessage = self:GetChecked()
end)
messageToggleButton:Hide()

local senderToggleButton = CreateFrame("CheckButton", LPName.."SenderToggleButton", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
senderToggleButton:SetPoint("TOPLEFT", 16, -66)
senderToggleButton.Text:SetText("隐藏角色名称含有简体字的玩家讯息     (只有频道、说、大喊、耳语生效)")
senderToggleButton:SetScript("OnClick", function(self)
    LPaddon.checkSender = self:GetChecked()
end)
senderToggleButton:Hide()

local myButton = CreateFrame("Button", "MyAddonButton", Minimap)
myButton:SetSize(25, 25)
myButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
myButton:SetFrameStrata("LOW")
myButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
myButton:SetNormalTexture("Interface\\Icons\\inv_misc_bomb_04")
myButton:SetPushedTexture("Interface\\Icons\\inv_misc_bomb_04")
myButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
local toggleButton = CreateFrame("CheckButton", LPName.."ToggleButton", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
toggleButton:SetPoint("TOPLEFT", 16, -5)
toggleButton.Text:SetText("显示小地图按钮")
toggleButton:SetScript("OnClick", function(self)
    LPaddon.showButton = self:GetChecked()
    LP_DB.showButton = self:GetChecked()
    if self:GetChecked() then
        myButton:Show()
    else
        myButton:Hide()
    end
end)

local disableInInstanceToggleButton = CreateFrame("CheckButton", LPName.."DisableInInstanceToggleButton", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
disableInInstanceToggleButton:SetPoint("TOPLEFT", 16, -44)
disableInInstanceToggleButton.Text:SetText("当玩家处于副本、战场、竞技场时，自动关闭讯息过滤")
disableInInstanceToggleButton:SetScript("OnClick", function(self)
    LPaddon.disableInInstance = self:GetChecked()
    LP_DB.disableInInstance = self:GetChecked()
end)

local declineInviteToggleButton = CreateFrame("CheckButton", LPName.."DeclineInviteToggleButton", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
declineInviteToggleButton:SetPoint("TOPLEFT", 16, -337)
declineInviteToggleButton.Text:SetText("自订:   拒绝角色名称包含以下自订词的玩家邀请")
declineInviteToggleButton:SetScript("OnClick", function(self)
    LPaddon.declineInvite = self:GetChecked()
    LP_DB.declineInvite = self:GetChecked()
end)

local wordsScrollFrame = CreateFrame("ScrollFrame", nil, optionsPanel, "UIPanelScrollFrameTemplate")
wordsScrollFrame:SetSize(280, 110)
wordsScrollFrame:SetPoint("TOPLEFT", 40, -365)
local wordsBackground = optionsPanel:CreateTexture(nil, "BACKGROUND")
wordsBackground:SetColorTexture(0, 0, 0, 0.5)
wordsBackground:SetSize(304, 115)
wordsBackground:SetPoint("TOPLEFT", 40, -361)
local wordsEditBox = CreateFrame("EditBox", nil, wordsScrollFrame)
wordsEditBox:SetMultiLine(true)
wordsEditBox:SetSize(280, 110)
wordsEditBox:SetFontObject(ChatFontNormal)
wordsEditBox:SetAutoFocus(false)
wordsEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
wordsScrollFrame:SetScrollChild(wordsEditBox)
local function DisplayAdIds()
    local words = ""
    for _, adId in ipairs(LPaddon.adIdList) do
        words = words .. adId .. ", "
    end
    words = words:sub(1, -3) 
    wordsEditBox:SetText(words)
end
addAdIdEditBox = CreateFrame("EditBox", nil, optionsPanel)
addAdIdEditBox:SetSize(216, 20)
addAdIdEditBox:SetPoint("TOPLEFT", 40, -478)
addAdIdEditBox:SetFontObject(ChatFontNormal)
addAdIdEditBox:SetAutoFocus(false)
addAdIdEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
local addAdIdEditBoxBackground = addAdIdEditBox:CreateTexture(nil, "BACKGROUND")
addAdIdEditBoxBackground:SetAllPoints(addAdIdEditBox)
addAdIdEditBoxBackground:SetColorTexture(0, 0, 0, 0.5)
local addAdIdLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
addAdIdLabel:SetPoint("BOTTOMLEFT", addAdIdEditBox, "TOPLEFT", 0, 4)
local addButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
addButton:SetPoint("LEFT", addAdIdEditBox, "RIGHT", 3, 0)
addButton:SetSize(86, 25)
addButton:SetText("添加\\删除")
addButton:SetScript("OnClick", function(self)
    local newAdId = addAdIdEditBox:GetText()
    ToggleAdId(newAdId)
    addAdIdEditBox:SetText("")
end)
local function CreateSeparator(parent, xOffset, yOffset, width, height)
    local separator = parent:CreateTexture(nil, "OVERLAY")
    separator:SetSize(width, height)
    separator:SetColorTexture(0.8, 0.8, 0.8, 1)
    separator:SetPoint("TOPLEFT", xOffset, -yOffset)
   return separator
end

--组队邀请功能和他的分隔线
local filterSeparator = CreateSeparator(optionsPanel, 600, 310, optionsPanel:GetWidth() - 200, 1)
local filterSeparator = CreateSeparator(optionsPanel, 221, 310, optionsPanel:GetWidth() - 200, 1)
local filterTitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
filterTitle:SetPoint("TOPLEFT", 258, -302)
filterTitle:SetText("组队邀请功能")

local declineSimplifiedChineseToggleButton = CreateFrame("CheckButton", LPName.."DeclineSimplifiedChineseToggleButton", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
declineSimplifiedChineseToggleButton:SetPoint("TOPLEFT", 16, -317)
declineSimplifiedChineseToggleButton.Text:SetText("拒绝名称含简体字的玩家组队邀请")
declineSimplifiedChineseToggleButton:SetScript("OnClick", function(self)
    LPaddon.declineSimplifiedChinese = self:GetChecked()
    LP_DB.declineSimplifiedChinese = self:GetChecked()
end)
declineSimplifiedChineseToggleButton:Hide()

local declineBladeOfKrolToggleButton = CreateFrame("CheckButton", LPName.."DeclineBladeOfKrolToggleButton", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
declineBladeOfKrolToggleButton:SetPoint("TOPLEFT", 16, -339)
declineBladeOfKrolToggleButton.Text:SetText("拒绝所有克罗之刃的玩家组队邀请")
declineBladeOfKrolToggleButton:SetScript("OnClick", function(self)
    LPaddon.declineBladeOfKrol = self:GetChecked()
    LP_DB.declineBladeOfKrol = self:GetChecked()
end)
declineBladeOfKrolToggleButton:Hide()

local function toggleKeyword(keyword)
    if LPaddon.customFilterWords[keyword] then
        LPaddon.customFilterWords[keyword] = nil
    else
        LPaddon.customFilterWords[keyword] = true
    end
end
local customFilterToggleButton = CreateFrame("CheckButton", LPName.."CustomFilterToggleButton", optionsPanel, "InterfaceOptionsCheckButtonTemplate")
customFilterToggleButton:SetPoint("TOPLEFT", 16, -66)
customFilterToggleButton.Text:SetText("自订:   隐藏包含以下关键字的讯息     (会自动忽略空格和各种符号)")
customFilterToggleButton:SetScript("OnClick", function(self)
    LPaddon.customFilter = self:GetChecked()
    LP_DB.customFilter = self:GetChecked()
end)
local customKeywordsScrollFrame = CreateFrame("ScrollFrame", nil, optionsPanel, "UIPanelScrollFrameTemplate")
customKeywordsScrollFrame:SetSize(280, 110)
customKeywordsScrollFrame:SetPoint("TOPLEFT", 40, -93)
local customKeywordsBackground = optionsPanel:CreateTexture(nil, "BACKGROUND")
customKeywordsBackground:SetColorTexture(0, 0, 0, 0.5)
customKeywordsBackground:SetSize(304, 115)
customKeywordsBackground:SetPoint("TOPLEFT", 40, -90)
local customKeywordsEditBox = CreateFrame("EditBox", nil, customKeywordsScrollFrame)
customKeywordsEditBox:SetMultiLine(true)
customKeywordsEditBox:SetSize(280, 100)
customKeywordsEditBox:SetFontObject(ChatFontNormal)
customKeywordsEditBox:SetAutoFocus(false)
customKeywordsEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
customKeywordsScrollFrame:SetScrollChild(customKeywordsEditBox)
local function DisplayCustomKeywords()
    local keywords = ""
    for keyword in pairs(LPaddon.customFilterWords) do
        keywords = keywords .. keyword .. ", "
    end
    keywords = keywords:sub(1, -3)
    customKeywordsEditBox:SetText(keywords)
end
optionsPanel:SetScript("OnShow", function()
    DisplayCustomKeywords()
end)
local newKeywordEditBox = CreateFrame("EditBox", nil, optionsPanel)
newKeywordEditBox:SetSize(216, 20)
newKeywordEditBox:SetPoint("TOPLEFT", 40, -207)
newKeywordEditBox:SetFontObject(ChatFontNormal)
newKeywordEditBox:SetAutoFocus(false)
newKeywordEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
local addKeywordButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
addKeywordButton:SetSize(88	, 23)
addKeywordButton:SetPoint("LEFT", newKeywordEditBox, "RIGHT", 2, 0)
addKeywordButton:SetText("添加\\删除")
addKeywordButton:SetScript("OnClick", function()
    local newKeyword = newKeywordEditBox:GetText()
    if newKeyword and newKeyword ~= "" then
        toggleKeyWord(newKeyword)
        LP_DB.customFilterWords = LPaddon.customFilterWords
        newKeywordEditBox:SetText("")
        newKeywordEditBox:ClearFocus()
        DisplayCustomKeywords()
    end
end)
local editBoxBackground = newKeywordEditBox:CreateTexture(nil, "BACKGROUND")
editBoxBackground:SetAllPoints(newKeywordEditBox)
editBoxBackground:SetColorTexture(0, 0, 0, 0.5)
local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
category.ID = optionsPanel.name
Settings.RegisterAddOnCategory(category)
SlashCmdList[LPName] = function(msg)
    Settings.OpenToCategory(optionsPanel.name)
end
SLASH_BlockMessageTeamGuard1 = "/"..LPName
SLASH_BlockMessageTeamGuard2 = "/BSC"
SlashCmdList[LPName] = function(msg)
    Settings.OpenToCategory(optionsPanel.name)
end

local whisperWithKeyword = {}
local chatBubbleSenders = {}

-- 過濾掉特殊符號
local function filter_spec_chars(s)  
    local ss = {}  
    for k = 1, #s do  
        local c = string.byte(s,k)  
        if not c then break end  
        if (c>=48 and c<=57) or (c>= 65 and c<=90) or (c>=97 and c<=122) then  
            table.insert(ss, string.char(c))  
        elseif c>=228 and c<=233 then  
            local c1 = string.byte(s,k+1)  
            local c2 = string.byte(s,k+2)  
            if c1 and c2 then  
                local a1,a2,a3,a4 = 128,191,128,191  
                if c == 228 then a1 = 184  
                elseif c == 233 then a2,a4 = 190,c1 ~= 190 and 191 or 165  
                end  
                if c1>=a1 and c1<=a2 and c2>=a3 and c2<=a4 then  
                    k = k + 2  
                    table.insert(ss, string.char(c,c1,c2))  
                end  
            end  
        end  
    end  
    return table.concat(ss)  
end

local function filter(self, event, msg, sender)
    if not (LPaddon.checkMessage or LPaddon.checkSender or LPaddon.customFilter) then
        return
    end
    local inInstance, instanceType = IsInInstance()
    if LPaddon.disableInInstance and inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario" or instanceType == "arena" or instanceType == "pvp") then
        return
    end
    local lowercase_message = string.gsub(msg, "{(.-)}", "") -- 過濾圖案
	lowercase_message = filter_spec_chars(lowercase_message) -- 過濾符號和空格
	lowercase_message = lowercase_message:lower()
    local lowercase_name = sender:lower()

    local close_chat_frame = function()
        if strsub(event, 10) == 'WHISPER' then
            for frameIndex = 2, #CHAT_FRAMES do
                local currentChatFrame = _G[CHAT_FRAMES[frameIndex]]
                if currentChatFrame.name == sender then
                    FCF_Close(currentChatFrame)
                    break
                end
            end
        end
    end

    local isFiltered = false

    if LPaddon.checkMessage then
        for word in pairs(LPaddon.filterWords) do
            local lowercase_word = word:lower()
            if string.find(lowercase_message, lowercase_word) then
                isFiltered = true
                break
            end
        end
    end
    if not isFiltered and LPaddon.customFilter then
        for word in pairs(LPaddon.customFilterWords) do
            local lowercase_word = word:lower()
            if string.find(lowercase_message, lowercase_word) then
                isFiltered = true
                break
            end
        end
    end
    if not isFiltered and LPaddon.checkSender then
        for word in pairs(LPaddon.filterWords) do
            local lowercase_word = word:lower()
            if string.find(lowercase_name, lowercase_word) then
                isFiltered = true
                break
            end
        end
    end

    if isFiltered then
        if whisperWithKeyword[sender] == nil then
            whisperWithKeyword[sender] = true
            close_chat_frame()
        elseif whisperWithKeyword[sender] then
            close_chat_frame()
        end
    else
        whisperWithKeyword[sender] = false
    end

    return isFiltered
end

local function ShouldHideChatBubble(text, sender)
    local isFiltered = false
    local lowercase_text = text:lower()

    if LPaddon.checkMessage then
        for word in pairs(LPaddon.filterWords) do
            local lowercase_word = word:lower()
            if string.find(lowercase_text, lowercase_word) then
                isFiltered = true
                break
            end
        end
    end

    if not isFiltered and LPaddon.customFilter then
        for word in pairs(LPaddon.customFilterWords) do
            local lowercase_word = word:lower()
            if string.find(lowercase_text, lowercase_word) then
                isFiltered = true
                break
            end
        end
    end

    if not isFiltered and LPaddon.checkSender and sender then
        local lowercase_sender = sender:lower()
        for word in pairs(LPaddon.filterWords) do
            local lowercase_word = word:lower()
            if string.find(lowercase_sender, lowercase_word) then
                isFiltered = true
                break
            end
        end
    end

    return isFiltered
end

local function HideWChatBubbles(sender)
    for i, chatBubble in ipairs(C_ChatBubbles.GetAllChatBubbles()) do
        local frame = chatBubble:GetChildren()
        if frame then
            local fontString = frame:GetRegions()
            if fontString then
                local text = fontString:GetText()
                if sender then
                    chatBubbleSenders[fontString] = sender
                end
                if ShouldHideChatBubble(text, chatBubbleSenders[fontString]) then
                    frame:Hide()
                else
                    frame:Show()
                end
            end
        end
    end
end

local function OnEvent(self, event, ...)
    local msg, sender = ...
    if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" then
        C_Timer.After(0.01, function()
            HideWChatBubbles(sender)
        end)
    end
end

local chatBubbleFrame = CreateFrame("Frame")
chatBubbleFrame:RegisterEvent("CHAT_MSG_SAY")
chatBubbleFrame:RegisterEvent("CHAT_MSG_YELL")
chatBubbleFrame:SetScript("OnEvent", OnEvent)

local function InitializeButtonStatus()
    toggleButton:SetChecked(LP_DB.showButton)
    if LP_DB.showButton then
        myButton:Show()
    else
        myButton:Hide()
    end
end
local function OnLoad(self, event, ...)
    if not LP_DB then
        LP_DB = {}
        LP_DB.enabled = false
        LP_DB.checkSender = false
        LP_DB.showButton = true
        LP_DB.disableInInstance = false
        LP_DB.declineInvite = true
        LP_DB.customFilterWords = {}
    end
    if not LP_DB.adIdList or #LP_DB.adIdList == 0 then
        LP_DB.adIdList = LPaddon.defaultAdIdList
    end
    LPaddon.adIdList = LP_DB.adIdList
    DisplayAdIds()
    LPaddon.checkMessage = LP_DB.enabled
    LPaddon.checkSender = LP_DB.checkSender
    LPaddon.showButton = LP_DB.showButton
    LPaddon.disableInInstance = LP_DB.disableInInstance
    LPaddon.declineInvite = LP_DB.declineInvite or false
    LPaddon.declineSimplifiedChinese = LP_DB.declineSimplifiedChinese or false
    LPaddon.declineBladeOfKrol = LP_DB.declineBladeOfKrol or false
    LPaddon.customFilter = LP_DB.customFilter == nil and true or LP_DB.customFilter
    LPaddon.strangerGroupEnabled = LP_DB.strangerGroupEnabled == nil and true or LP_DB.strangerGroupEnabled
    if not LP_DB.customFilterWords or next(LP_DB.customFilterWords) == nil or not LP_DB.resetFilterWords or LP_DB.resetFilterWords < 1 then
    LP_DB.customFilterWords = {["wow1"] = true, ["wow2"] = true, ["wow3"] = true, ["wow4"] = true, ["wow5"] = true, ["wow6"] = true, ["wow7"] = true, ["wow8"] = true, ["wow9"] = true, ["wow0"] = true,  ["wlk"] = true, ["咸鱼"] = true, ["8wow"] = true,}
	LP_DB.resetFilterWords = 1
end
    LPaddon.customFilterWords = LP_DB.customFilterWords    
    customFilterToggleButton:SetChecked(LPaddon.customFilter)
    declineBladeOfKrolToggleButton:SetChecked(LPaddon.declineBladeOfKrol)
    declineSimplifiedChineseToggleButton:SetChecked(LPaddon.declineSimplifiedChinese)
    messageToggleButton:SetChecked(LPaddon.checkMessage)
    senderToggleButton:SetChecked(LPaddon.checkSender)
    strangerGroupToggleButton:SetChecked(LPaddon.strangerGroupEnabled)
    disableInInstanceToggleButton:SetChecked(LPaddon.disableInInstance)
    declineInviteToggleButton:SetChecked(LP_DB.declineInvite)
    InitializeButtonStatus()
    -- print("BlockMessageV1.4已载入,输入/BSC配置")
end
local function OnSave(self, event, ...)
    LP_DB.enabled = LPaddon.checkMessage
    LP_DB.checkSender = LPaddon.checkSender
    LP_DB.showButton = LPaddon.showButton  
    LP_DB.disableInInstance = LPaddon.disableInInstance
    LP_DB.declineSimplifiedChinese = LPaddon.declineSimplifiedChinese
    LP_DB.declineInvite = LPaddon.declineInvite
    LP_DB.customFilter = LPaddon.customFilter
    LP_DB.customFilterWords = LPaddon.customFilterWords
    LP_DB.adIdList = LPaddon.adIdList
    LP_DB.strangerGroupEnabled = LPaddon.strangerGroupEnabled
end
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PARTY_INVITE_REQUEST")
eventFrame:RegisterEvent("GROUP_INVITE_CONFIRMATION")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == LPName then
            OnLoad(self, event, ...)
        end
    elseif event == "PLAYER_LOGOUT" then
        OnSave(self, event, ...)
    elseif event == "PARTY_INVITE_REQUEST" then
        local sender = ...
        OnPartyInviteRequest(self, event, sender)
    elseif event == "GROUP_INVITE_CONFIRMATION" then
        local guid = GetNextPendingInviteConfirmation()
        local _, sender = GetInviteConfirmationInfo(guid)
        local declined = false
        local lowercase_sender = string.lower(sender)

if not declined and LPaddon.declineSimplifiedChinese then
    for word in pairs(LPaddon.filterWords) do
        if string.find(lowercase_sender, word) then
            RespondToInviteConfirmation(guid, false)
            StaticPopup_Hide("GROUP_INVITE_CONFIRMATION")
            declined = true
            break
        end
    end
end
        if not declined and LPaddon.declineBladeOfKrol then
            if string.find(lowercase_sender, "克罗之刃") then
                RespondToInviteConfirmation(guid, false)
                StaticPopup_Hide("GROUP_INVITE_CONFIRMATION")
                declined = true
            end
        end

        if not declined and LPaddon.declineInvite then
            for _, adId in ipairs(LPaddon.adIdList) do
                if string.find(lowercase_sender, adId) then
                    RespondToInviteConfirmation(guid, false)
                    StaticPopup_Hide("GROUP_INVITE_CONFIRMATION")
                    declined = true
                    break
                end
            end
        end

            if not declined then
        if isInviteAllowed(sender) then
            UnmuteSoundFile(567451)
            PlaySoundFile(567451)
            MuteSoundFile(567451)
        end
    end
    end
end)


LPaddon = {
    checkMessage = false,
    checkSender = true,
    showButton = true,
    strangerGroupEnabled = true,
    filterWords = {},
    filterNames = {},
    declineSimplifiedChinese = false,
    customFilter = true,
    customFilterWords = {},
    adIdList = {},
    defaultAdIdList = {"满级", "消费", "小时", "站桩", "微信", "来看看", "小莳", "毕业", "史诗", "有团", "装备", "提升", "找我", "到满", "升满", "马上", "开团", "喊我", "团本", "团队", "副本", "大米"},
}
function AddAdId(adId)
    if not LPaddon.adIdList then
        LPaddon.adIdList = {}
    end
    adId = adId:lower()
    local adIdExists = false
    for _, existingAdId in ipairs(LPaddon.adIdList) do
        if existingAdId == adId then
            adIdExists = true
            break
        end
    end
    if not adIdExists then
        table.insert(LPaddon.adIdList, adId)
        LP_DB.adIdList = LPaddon.adIdList
    end
end

addButton:SetScript("OnClick", function()
    local adId = addAdIdEditBox:GetText()
    AddAdId(adId)
    addAdIdEditBox:SetText("")
    DisplayAdIds()
end)

local function addWords(words)
    for word in string.gmatch(words, "[^%s,]+") do
        LPaddon.filterWords[word] = true
    end
end
addWords("装,册,伫,侣,伥,俪,俨,儿,兖,剀,匮,却,吕,嗳,噜,嘤,嗫,啭,呓,囱,垩,堕,圹,坜,奂,媪,娴,婵,袅,嫔,孪,宫,尴,巅,厨,彦,怅,惬,愠,忾,怆,怂,惮,懑,忏,惧,慑,扪,挞,据,掳,拧,擞,携,挛,昼,晖,暧,栀,桢,样,枞,椭,桧,槟,槛,柠,橱,椟,榈,橹,欤,殇,殡,氲,泾,温,渎,浏,潇,濑,滦,烟,炽,焖,烩,犊,狰,狞,犷,獭,猡,珏,瑶,玑,瑷,珑,瓮,叠,疠,癣,癫,睐,睁,眬,矶,碍,砺,禅,颖,稣,穑,窦,竞,篑,籁,纣,纥,纰,纭,绋,绌,绚,绥,缄,萦,缪,缧,缫,缮,绣,羁,芈,羡,胶,脍,膑,胪,刍,苎,诧,随,摇,岛,馊,鲑,鲔,鲛,骋,闱,阑,阕,锾,锺,锲,镁,殓,栉,婴,咛,鸭,鸪,骈,馄,饯,颐,颔,锱,锢,锟,铮,谖,谌,谙,谕,谘,谏,谛,觎,绉,缙,缜,缟,缣,缢,笃,窥,瓯,哝,侪,傧,俦,鸩,鱿,驸,驽,驷,馀,颌,颉,巩,闾,锂,钡,锑,辊,辋,辎,谀,谇,诤,谄,诿,缇,缈,缂,缍,缉,皑,怃,娆,妩,侩,侬,鸢,饷,阂,铵,铨,铬,铢,铰,诮,诳,诰,绶,缁,纶,绮,绫,绾,祯,疡,荦,涟,渍,掴,恸,帼,妪,奁,堑,哔,啧,喽,饴,顼,钿,铍,钜,铋,铉,铂,铀,钸,钹,钴,邹,轾,轼,赅,赂,赀,诟,诠,诛,诣,诙,诘,笕,禄,珲,炀,毁,啬,驭,饬,饨,饪,闳,闵,钣,钤,轶,轲,费,贲,贻,诃,诋,诏,诂,苌,绛,盗,痉,珐,氩,恻,帏,帧,岚,埚,尧,伧,钒,钏,钗,迳,轭,讷,苋,钵,绂,绁,双,玺,缚,烬,猪,鲜,猫,枭,脚,贴,厂,亏,与,万,亿,个,么,广,门,义,尸,卫,飞,习,马,乡,丰,开,无,专,艺,厅,区,历,车,冈,贝,见,气,长,币,仅,从,仓,风,乌,凤,为,忆,订,计,认,队,办,劝,书,击,节,术,厉,龙,灭,轧,东,业,旧,帅,归,叶,电,号,叹,们,仪,丛,乐,处,鸟,务,饥,闪,兰,汇,头,汉,宁,讨,写,让,礼,训,议,讯,记,辽,边,发,圣,对,纠,丝,动,执,扩,扫,扬,场,亚,机,权,过,协,压,厌,页,夺,达,夹,轨,迈,毕,贞,师,尘,当,吓,虫,团,吗,屿,岁,岂,刚,则,网,迁,乔,伟,传,优,伤,价,华,伪,会,杀,众,爷,伞,创,杂,负,壮,冲,庄,庆,刘,齐,产,决,闭,问,闯,并,关,汤,兴,讲,军,许,论,农,讽,设,访,寻,尽,导,异,孙,阵,阳,阶,阴,妇,妈,戏,观,欢,买,红,纤,级,约,纪,驰,寿,麦,进,远,违,运,抚,坛,坏,扰,坝,贡,抢,坟,护,壳,块,声,报,苍,严,芦,劳,苏,极,杨,两,丽,医,励,还,歼,来,连,坚,时,吴,县,园,旷,围,吨,邮,员,听,呜,岗,帐,财,针,钉,乱,体,彻,邻,肠,龟,犹,条,饭,饮,冻,状,库,疗,应,这,弃,闲,间,闷,灿,沟,怀,忧,穷,灾,证,启,评,补,识,诉,诊,词,译,灵,层,迟,张,际,陆,陈,劲,鸡,驱,纯,纱,纳,纲,驳,纵,纷,纸,纹,纺,驴,纽,环,责,现,规,拢,拣,担,顶,拥,势,拦,拨,择,苹,茎,柜,枪,构,丧,画,枣,卖,矿,码,厕,奋,态,欧,垄,轰,顷,转,斩,轮,软,齿,虏,肾,贤,国,畅,鸣,咏,罗,帜,岭,凯,败,贩,购,图,钓,侦,侧,凭,侨,货,质,径,贪,贫,肤,肿,胀,胁,鱼,备,饰,饱,饲,变,庙,剂,废,净,闸,闹,郑,单,炉,浅,泪,泻,泼,泽,怜,学,宝,审,帘,实,试,诗,诚,衬,视,话,诞,询,该,详,肃,录,隶,届,陕,驾,参,艰,线,练,组,细,驶,织,终,驻,驼,绍,经,贯,帮,挂,项,挠,赵,挡,垫,挤,挥,荐,带,茧,荡,荣,药,标,栋,栏,树,砖,牵,残,轻,鸦,战,点,临,览,竖,尝,显,哑,贵,虾,蚁,蚂,虽,骂,哗,响,峡,罚,贱,钞,钟,钢,钥,钩,选,适,种,复,俩,贷,顺,俭,须,剑,胆,胜,脉,狭,狮,独,狱,贸,饶,蚀,饺,饼,弯,将,奖,疮,疯,亲,闻,阀,阁,养,类,总,炼,烂,洁,洒,浇,浊,测,济,浑,浓,恼,举,觉,宪,窃,语,袄,误,诱,说,诵,垦,险,娇,贺,垒,绑,绒,结,绕,骄,绘,给,络,骆,绝,绞,统,艳,蚕,顽,捞,载,赶,盐,损,捡,换,热,壶,莲,获,恶,档,桥,础,顾,轿,较,顿,毙,虑,监,紧,党,晒,晓,晕,唤,罢,圆,贼,贿,钱,钳,钻,铁,铃,铅,牺,敌,积,称,笔,债,倾,舰,舱,爱,颂,脏,脑,皱,饿,恋,桨,浆,离,资,阅,烦,烧,烛,涛,涝,润,涨,烫,涌,宽,宾,请,诸,读,袜,课,谁,调,谅,谈,谊,剥,恳,剧,难,预,绢,验,继,职,萝,营,梦,检,聋,袭,辅,辆,虚,悬,崭,铜,铲,银,笼,偿,衔,盘,鸽,领,脸,猎,馅,馆,痒,盖,断,兽,渐,渔,渗,惭,惊,惨,惯,谋,谎,祸,谜,弹,隐,婶,颈,绩,绪,续,骑,绳,维,绵,绸,绿,趋,搁,搂,搅,联,确,暂,辈,辉,赏,喷,践,遗,赌,赔,铸,铺,链,销,锁,锄,锅,锈,锋,锐,筑,筛,储,惩,释,腊,鲁,馋,蛮,阔,粪,湿,湾,愤,窜,窝,裤,谢,谣,谦,属,屡,缎,缓,编,骗,缘,摄,摆,摊,鹊,蓝,献,楼,赖,雾,输,龄,鉴,错,锡,锣,锤,锦,键,锯,辞,筹,签,简,腾,触,酱,数,满,滤,滥,滚,滨,滩,誉,谨,缝,缠,墙,愿,颗,蜡,蝇,赚,锹,锻,稳,箩,馒,赛,谱,骡,缩,嘱,镇,颜,额,聪,樱,飘,瞒,题,颠,赠,镜,赞,篮,辩,懒,缴,辫,骤,镰,仑,讥,邓,卢,叽,尔,冯,吁,伦,凫,妆,讳,讶,讹,讼,诀,驮,驯,纫,玛,韧,抠,抡,坞,拟,芜,苇,轩,卤,呕,呛,岖,狈,鸠,庐,闰,沥,沦,沧,沪,诅,诈,坠,纬,枢,枫,矾,殴,昙,咙,账,贬,贮,侠,侥,刽,觅,庞,疟,泞,宠,诡,屉,弥,叁,绅,驹,绊,绎,贰,挟,荚,荞,荠,荤,荧,栈,砚,鸥,轴,勋,哟,钙,钝,钠,钦,钧,钮,氢,胧,饵,峦,飒,闺,闽,娄,烁,洼,诫,诬,诲,逊,陨,骇,挚,捣,聂,莱,莹,莺,栖,桦,桩,贾,砾,唠,鸯,赃,钾,铆,赁,耸,颁,脐,脓,鸵,鸳,馁,斋,涡,涣,涤,涧,涩,悯,窍,诺,诽,谆,骏,琐,麸,掷,掸,掺,萤,萧,萨,酝,硕,颅,啰,啸,逻,铐,铛,铝,铡,铣,铭,矫,秽,躯,敛,阎,阐,焕,鸿,渊,谍,谐,裆,祷,谒,谓,谚,颇,绰,绷,综,绽,缀,琼,揽,搀,蒋,韩,颊,雳,翘,凿,畴,鹃,赋,赎,赐,锉,锌,牍,惫,痪,滞,溃,溅,谤,缅,缆,缔,缕,骚,鹉,榄,辐,辑,频,跷,锚,锥,锨,锭,锰,颓,腻,鹏,雏,馍,馏,誊,寝,谬,缤,赘,蔼,辕,辖,蝉,镀,箫,舆,谭,缨,撵,镊,镐,篓,鲤,瘪,瘫,澜,谴,鹤,缭,辙,鹦,篱,鲸,濒,缰,赡,镣,鳄,嚣,鳍,癞,攒,鬓,躏,镶")
local function ToggleAdId(newAdId)
    if newAdId ~= "" then
        newAdId = newAdId:lower()
        local foundIndex = nil
        for index, adId in ipairs(LPaddon.adIdList) do
            if adId:lower() == newAdId:lower() then
                foundIndex = index
                break
            end
        end
        if foundIndex then
            table.remove(LPaddon.adIdList, foundIndex)
        else
            table.insert(LPaddon.adIdList, newAdId)
        end

        DisplayAdIds()
    end
end
addButton:SetScript("OnClick", function(self)
    local newAdId = addAdIdEditBox:GetText()
    ToggleAdId(newAdId)
    addAdIdEditBox:SetText("")
end)
local events = {
"CHAT_MSG_SAY",
"CHAT_MSG_YELL",
"CHAT_MSG_CHANNEL",
"CHAT_MSG_EMOTE",
"CHAT_MSG_WHISPER",
}
for _, v in pairs(events) do
ChatFrame_AddMessageEventFilter(v, filter)
end
myButton:SetMovable(true)
myButton:EnableMouse(true)
myButton:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        self:StartMoving()
    end
end)
myButton:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        self:StopMovingOrSizing()
    end
end)
myButton:SetScript("OnClick", function(self, button, down)
    if button == "LeftButton" then
        Settings.OpenToCategory(optionsPanel.name)
    elseif button == "RightButton" then
        Settings.OpenToCategory(optionsPanel.name)
    end
end)
myButton.tooltip = "BlockMessageTeamGuard"
myButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:AddLine(self.tooltip)
    GameTooltip:Show()
end)
myButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)
function OnPartyInviteRequest(self, event, sender)
    local declined = false
    local lowercase_sender = sender:lower()
    
    if not declined and LPaddon.declineSimplifiedChinese then
        for word in pairs(LPaddon.filterWords) do
            if string.find(lowercase_sender, word) then
                DeclineGroup()
                StaticPopup_Hide("PARTY_INVITE")
                declined = true
                break
            end
        end
    end
    if not declined and LPaddon.declineBladeOfKrol then
        if string.find(lowercase_sender, "克罗之刃") then
            DeclineGroup()
            StaticPopup_Hide("PARTY_INVITE")
            declined = true
        end
    end
    if not declined and LPaddon.declineInvite then
        for _, adId in ipairs(LPaddon.adIdList) do
            if string.find(lowercase_sender, adId) then
                DeclineGroup()
                StaticPopup_Hide("PARTY_INVITE")
                declined = true
                break
            end
        end
    end

        if not declined then
        if isInviteAllowed(sender) then
        UnmuteSoundFile(567451)
        PlaySoundFile(567451)
        MuteSoundFile(567451)
    end
    end
end

function toggleKeyWord(word)
    if LPaddon.customFilterWords[word] then
        LPaddon.customFilterWords[word] = nil
    else
        LPaddon.customFilterWords[word] = true
    end
end
local function addKeyWords(words)
    words = words or ""
    for word in string.gmatch(words, "[^%s,]+") do
        toggleKeyWord(word)
    end
end
addKeyWords()

local function MyAddon_OnEvent(self, event, ...)
    if event == "PLAYER_LOGIN" then
        MuteSoundFile(567464)
        MuteSoundFile(567490)
        MuteSoundFile(567451)
        MuteSoundFile(4758694)
        MuteSoundFile(4758694)
        MuteSoundFile(4758551)
        MuteSoundFile(4758408)
        MuteSoundFile(4758265)
        MuteSoundFile(1306400)
        MuteSoundFile(1304803)
        MuteSoundFile(1304506)
        MuteSoundFile(1284665)
        MuteSoundFile(636441)
        MuteSoundFile(630112)
        MuteSoundFile(543174)
        MuteSoundFile(543146)
        MuteSoundFile(542952)
        MuteSoundFile(542862)
        MuteSoundFile(542659)
        MuteSoundFile(542585)
        MuteSoundFile(542205)
        MuteSoundFile(542056)
        MuteSoundFile(541880)
        MuteSoundFile(541795)
        MuteSoundFile(541614)
        MuteSoundFile(541541)
        MuteSoundFile(541298)
        MuteSoundFile(541222)
        MuteSoundFile(540984)
        MuteSoundFile(540941)
        MuteSoundFile(540778)
        MuteSoundFile(540579)
        MuteSoundFile(540356)
        MuteSoundFile(540287)
        MuteSoundFile(539901)
        MuteSoundFile(539839)
        MuteSoundFile(539729)
        MuteSoundFile(539481)
        MuteSoundFile(539307)
        MuteSoundFile(539218)
    end
end

local MyAddon = CreateFrame("Frame")
MyAddon:RegisterEvent("PLAYER_LOGIN")
MyAddon:SetScript("OnEvent", MyAddon_OnEvent)
local function StrPartition(inputStr, delimiter)
local outcome = {}
local start = 1
local delimStart, delimEnd = string.find(inputStr, delimiter, start)
while delimStart do
table.insert(outcome, string.sub(inputStr, start, delimStart - 1))
start = delimEnd + 1
delimStart, delimEnd = string.find(inputStr, delimiter, start)
end
table.insert(outcome, string.sub(inputStr, start))
return outcome
end
local whisperedUsers = {}
local allowedUsers = {}
local function RefreshAllowedUsers()
    local userList = {}
    allowedUsers = userList
    for i = 1, BNGetNumFriends() do 
        local friendData = C_BattleNet.GetFriendAccountInfo(i)
        local friendName = friendData and friendData.gameAccountInfo and friendData.gameAccountInfo.characterName
        if friendName and #friendName > 0 then 
            userList[StrPartition(friendName, '-')[1]] = true 
        end
    end
    for i = 1, C_FriendList.GetNumFriends() do
        local userInfo = C_FriendList.GetFriendInfoByIndex(i)
        if userInfo.name and #userInfo.name > 0 then
            userList[StrPartition(userInfo.name, '-')[1]] = true
        end
    end
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if name then
            userList[StrPartition(name, '-')[1]] = true
        end
    end
    local clubs = C_Club.GetSubscribedClubs()
    if clubs then
        for _, club in pairs(clubs) do
            if club and club.clubId and club.clubType == 1 then
                local sortedMemberList = CommunitiesUtil.GetAndSortMemberInfo(club.clubId);
                for _, m in pairs(sortedMemberList) do
                    if m.name then
                        userList[StrPartition(m.name, '-')[1]] = true
                    end
                end
            end
        end
    end
end
local function RegisterWhisper(event, srcPlayer, destPlayer)
local playerName = StrPartition(event == "CHAT_MSG_WHISPER" and srcPlayer or destPlayer, '-')[1]
whisperedUsers[playerName] = true
end

local function RejectInvite(sender)
DeclineGroup()
StaticPopup_Hide("PARTY_INVITE")
end

local function RejectInviteConfirmation(guid)
RespondToInviteConfirmation(guid, false)
StaticPopup_Hide("GROUP_INVITE_CONFIRMATION")
end

local function MustRejectInvite(playerName)
if not LPaddon.strangerGroupEnabled then
return false
end

local senderName = StrPartition(playerName, '-')[1]
RefreshAllowedUsers()

if not allowedUsers[senderName] and not whisperedUsers[senderName] then
    return true
end

return false

end

local stranger = CreateFrame("Frame")
stranger:RegisterEvent("PARTY_INVITE_REQUEST")
stranger:RegisterEvent("CHAT_MSG_WHISPER")
stranger:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
stranger:RegisterEvent("GROUP_INVITE_CONFIRMATION")
stranger:SetScript("OnEvent", function(self, event, ...)
    if event == "PARTY_INVITE_REQUEST" then
        local sender = ...
        if MustRejectInvite(sender) then
            RejectInvite(sender)
        end
    elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
        local srcPlayer, destPlayer = ...
        RegisterWhisper(event, srcPlayer, destPlayer)
elseif event == "GROUP_INVITE_CONFIRMATION" then
    local guid = GetNextPendingInviteConfirmation()
    if guid and guid ~= "" then  -- 检查 guid 是否有效
        local _, sender = GetInviteConfirmationInfo(guid)
        local playerName = StrPartition(sender, '-')[1]
        if MustRejectInvite(playerName) then
            RejectInviteConfirmation(guid)
         end
      end
   end
end)

function isInviteAllowed(inviterName)
    if not inviterName then
        return true
    end
    local lowercase_sender = inviterName:lower()
    if LPaddon.declineSimplifiedChinese then
        for word in pairs(LPaddon.filterWords) do
            if string.find(lowercase_sender, word) then
                return false
            end
        end
    end
    if LPaddon.declineBladeOfKrol then
        if string.find(lowercase_sender, "克罗之刃") then
            return false
        end
    end
    if LPaddon.declineInvite then
        for _, adId in ipairs(LPaddon.adIdList) do
            if string.find(lowercase_sender, adId) then
                return false
            end
        end
    end
    if MustRejectInvite(inviterName) then
        return false
    end
    return true
end

local frame = CreateFrame("Frame", "ModifiedInviteDemo")
local event1 = false
local event2 = false

local function getFullName(name, server)
    return server and name .. "-" .. server or name
end

local function printDungeonDifficulty()
    local difficultyIndex = GetDungeonDifficultyID()
    local difficultyName = "普通"
    if difficultyIndex == 1 then
        difficultyName = "普通"
    elseif difficultyIndex == 2 then
        difficultyName = "英雄"
    elseif difficultyIndex == 23 then
        difficultyName = "史诗"
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff00地下城难度已设置为" .. difficultyName .. "。|r")
end

local inviterNameForConfirmation
local inviterServerForConfirmation

local function onEvent(self, event, ...)
    if event == "PARTY_INVITE_REQUEST" then
        event1 = true
        inviterNameForConfirmation, inviterServerForConfirmation = ...
        if isInviteAllowed(inviterNameForConfirmation) then
            local fullName = getFullName(inviterNameForConfirmation, inviterServerForConfirmation)
            local hyperlink = "|Hplayer:" .. fullName .. "|h[" .. fullName .. "]|h"
            local message = hyperlink .. "邀请你加入队伍。"
            DEFAULT_CHAT_FRAME:AddMessage(message, 1, 1, 0)
        end
    elseif event == "GROUP_JOINED" then
        event2 = true
    elseif event == "GROUP_LEFT" then
        event1 = false
        event2 = false
        confirmationEvent = false
    elseif event == "GROUP_INVITE_CONFIRMATION" then
        confirmationEvent = true
    end

    if event1 and event2 then
        C_Timer.After(0.5, function()
            if not confirmationEvent then
                printDungeonDifficulty()
            end
            event1 = false
            event2 = false
        end)
    end

    if event == "GROUP_INVITE_CONFIRMATION" then
        local guid = GetNextPendingInviteConfirmation()
        if guid then
            local _, name = GetInviteConfirmationInfo(guid)
            if name and not isInviteAllowed(name) then
            else
                local fullName = getFullName(name, inviterServerForConfirmation)
                local hyperlink = "|Hplayer:" .. fullName .. "|h[" .. fullName .. "]|h"
                local message = hyperlink .. "请求加入你的队伍。"
                DEFAULT_CHAT_FRAME:AddMessage(message, 1, 1, 0)
                printDungeonDifficulty()
            end
        end
    end
end
local function filterinvite(self, event, msg, ...)
    if string.match(msg, "邀请你加入队伍，但是你无法接受，因为你已经在一个队伍中了") then       
        local inviter = string.match(msg, "%[(.-)%]")        
        if inviter then
            for _, adId in ipairs(LPaddon.adIdList) do
                if string.find(string.lower(inviter), adId) then
                    
                    return true
                end
            end
        end
    end
    return false, msg, ...
end
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", filterinvite)
local function filterSystemMessage(_, _, message, ...)
    if message:find("邀请你加入队伍。") or message:find("请求加入你的队伍") or message:find("地下城难度已设置为") or message:find("邀请你加入其队伍") then
        return true
    end
    return false
end
frame:SetScript("OnEvent", onEvent)
frame:RegisterEvent("PARTY_INVITE_REQUEST")
frame:RegisterEvent("GROUP_JOINED")
frame:RegisterEvent("GROUP_INVITE_CONFIRMATION")
frame:RegisterEvent("GROUP_LEFT")
ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", filterSystemMessage)