local CONFIG = ...
local ADDON, Addon = CONFIG:match('[^_]+'), _G[CONFIG:match('[^_]+')]
if not Addon.showAsmon then return end

local Sushi = LibStub('Sushi-3.1')
local Asmon = Addon:NewModule('AsmonLetter', Sushi.OptionsGroup:New(Addon.GeneralOptions, 'Asmongold |TInterface/Addons/BagBrother/Art/Cover:16:16|t'))
local Letter1 = [[|cff999999From: Jaliborc (author of Bagnon, BagBrother, Scrap, OmniCC, PetTracker, etc...)|r
Hi Asmongold! 

You can relax now, Bagnon is up and ready for 10.1, sorry for the delay! Friends always send me clips of your love story with Bagnon, and it's great to see you've been using it for such a long time.

Unfortunately, it also came to my attention that |cffcc9933you have been pronouncing Bagnon incorrectly for the past 15 years|r. After having a nightmare that included you pronouncing Bagnon |cffC41E3Alike a madman|r and Josh Strife Hayes really angry screaming "That is bad game design!"... I've decided to solve the problem with my own two hands. You can click on that button for a pronunciation example. I've also included a visual guide.]]

local Letter2 = [[One thing that could help mod developers having things ready on time of release is to give them access to the closed alphas/betas that streamers/media people sometimes do. I've gotten used at this point to start updating the mods on the day of release, 2 weeks before at best. Blizzard can also change a lot of stuff between open beta and actual release day, |cffcc9933which does us devs and players dirty, so you better wash your hands Asmon|r.

However, please also keep in mind that most addons are developed by one person and it isn't even a part-time job. So we shouldn't expect the same level of support as from a small indie game company like Blizzard. I myself started developing these mods on my free time when I was 10 and has been a one-man hobby since.
    
Anyway, happy gaming to you! Don't worry, I won't be sending ingame messages in the future, it was a one-time joke.
You can add me on discord |cffcc9933Jaliborc#1518|r if you ever wanna chat or have questions.]]

function Asmon:Go()
    local bg = CreateFrame('Frame', 'AsmonLetter', UIParent, BackdropTemplateMixin and 'BackdropTemplate')
    bg:SetFrameStrata('DIALOG')
    bg:SetPoint('CENTER', 20, 50)
    bg:EnableMouse(true)
    bg:SetSize(900, 350)
    bg:Hide()
    bg:SetBackdrop {
        bgFile = 'Interface/DialogFrame/UI-DialogBox-Background-Dark',
        edgeFile = 'Interface/DialogFrame/UI-DialogBox-Border',
        insets = {left = 11, right = 11, top = 11, bottom = 9},
        edgeSize = 32, tileSize = 32, tile = true,
        padding = 4
    }

    local cover = CreateFrame('Frame', nil, bg)
    cover:SetAllPoints(bg)

    local page = CreateFrame('Frame', nil, bg)
    page:SetAllPoints(bg)

    -- cover
    local function makeCover(parent, width, call)
        local face = parent:CreateTexture()
        face:SetTexture('Interface/Addons/BagBrother/Art/Cover')
        face:SetPoint('LEFT', 20, 0)
        face:SetSize(256, 256)

        local to = Sushi.Header(parent, 'To: Asmongold', GameFontNormalHuge4)
        to:SetPoint('LEFT', 200, 70)
        to:SetWidth(width)
        to:SetScale(1.5)
        
        local from = Sushi.Header(parent, 'From: Jaliborc', GameFontHighlightLarge)
        from:SetPoint('TOPLEFT', to, 'BOTTOMLEFT', 0, -10)
        from:SetScale(1.5)
        from:SetWidth(width)

        local who = Sushi.Header(parent, 'Author of Bagnon, BagBrother, Scrap, OmniCC, PetTracker, etc...', GameFontHighlightSmall)
        who:SetPoint('TOPLEFT', from, 'BOTTOMLEFT', 0, -10)
        who:SetScale(1.5)
        who:SetWidth(width)

        local open = Sushi.RedButton(parent, 'Open Letter')
        open:SetPoint('TOPLEFT', who, 'BOTTOMLEFT', 0, -20)
        open:SetCall('OnClick', call)
        open:SetScale(1.5)
    end

    local function nextPage() cover:Hide(); bg:SetSize(1000, 640); page:Show() end
    makeCover(cover, 400, nextPage)

    -- page 1
    local text1 = Sushi.Header(page, Letter1, GameFontHighlight)
    text1:SetPoint('TOP', 0, -20)
    text1:SetWidth(940)
    
    local guide = page:CreateTexture()
    guide:SetTexture('Interface/Addons/BagBrother/Art/Pronunciation')
    guide:SetPoint('TOP', text1, 'BOTTOM', 0, -10)
    guide:SetSize(350, 350)

    local sound = Sushi.GrayButton(page, 'Play')
    sound:SetPoint('LEFT', guide, 'RIGHT', 10, 0)
    sound:SetCall('OnClick', function() PlaySoundFile('Interface/Addons/BagBrother/Art/Pronunciation.mp3', 'Master') end)
    sound:SetScale(2)

    local text2 = Sushi.Header(page, Letter2, GameFontHighlight)
    text2:SetPoint('TOP', guide, 'BOTTOM', 0, -10)
    text2:SetWidth(940)

    local close = Sushi.RedButton(page, 'X')
    close:SetPoint('TOPRIGHT', page)
    close:SetCall('OnClick', function() bg:Hide() end)
    close:SetScale(0.6)

    bg:SetScript('OnShow', function()
        bg:SetSize(900, 350)
        cover:Show()
        page:Hide()
    end)

    -- fallback
    makeCover(self, 200, function() self:Initial(); nextPage() end)
    self.Populate = function() end
    self.bg = bg
end

function Asmon:Initial()
    self.bg:Show()
end

Asmon:Go()