------------------------------------------------------------
-- 微型選單區塊：secure 點擊轉發 ＋ 暴雪那排的 secure hider
--
-- 做法照 EllesmereUI DataBars 的 micromenu 區塊（tmp/ 裡研究過的那份）：
--
-- 1. 每顆自製按鈕是 SecureActionButtonTemplate，*clickbutton1 指向暴雪的
--    MicroButton、*type1 = "click"。點我們的按鈕＝在 secure 環境裡點暴雪按鈕，
--    戰鬥中的行為跟原廠一模一樣（天賦、角色資訊照樣打得開）。
--    ⚠ 12.1 起天賦／法術書**必須**走這條路：addon Lua 直接開視窗會污染框架，
--    之後 Blizzard_SpellBookItem 的 SetCooldown 吃到秘密值就崩。
--    跟 EUI 不同的刻意決定：不掛戰鬥鎖（他們戰鬥中把 *type1 卸掉），
--    因為「戰鬥中能點開天賦／換擲骰」正是這條資訊列要解的需求。
--
-- 2. 隱藏暴雪那排不能從 insecure 程式 :Hide()——MicroMenuContainer 是
--    Edit Mode 管理框，會污染 managed frame system（症狀：之後離開載具時
--    ActionBarController_UpdateAll 被封鎖）。用 SecureHandlerStateTemplate
--    的 _onstate-vis 在 secure 環境裡執行。driver 註冊的是**常數**狀態，
--    snippet 只跑一次不會重新求值，所以外力（載入畫面、編輯模式）把它
--    Show 回來時要靠呼叫端傳 force 重推修復。
--
-- ⚠ 區域變數不要叫 MicroMenu：暴雪在 DF 之後有一個全域框就叫這個名字，
--    遮蔽掉會讓 hider 的目標清單拿到我們自己的 table。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.MicroMenu = {}
local MM = ns.MicroMenu

local ICON_TINT_IDLE = 0.82   -- 單色風格的閒置圖示亮度（照 Chattynator 按鈕的灰階）

------------------------------------------------------------
-- 按鈕定義（順序即顯示順序）
--
-- label 走暴雪的全域字串（各語系免費），沒有合適全域的才用自己的語系 key。
-- globals 是候選清單，第一個存在的全域勝出；整串都不存在就跳過這顆
-- （例如某版本沒有 HousingMicroButton），跨版本才不會炸。
------------------------------------------------------------
local BUTTON_DEFS = {
    { key = "char",    label = CHARACTER_BUTTON,                 binding = "TOGGLECHARACTER0",       globals = { "CharacterMicroButton" }, portrait = true },
    { key = "prof",    label = TRADE_SKILLS,                     binding = "TOGGLEPROFESSIONBOOK",   globals = { "ProfessionMicroButton", "ProfessionsMicroButton" } },
    { key = "spell",   label = TALENTS_BUTTON,                   binding = "TOGGLESPELLBOOK",        globals = { "PlayerSpellsMicroButton", "SpellbookMicroButton", "TalentMicroButton" } },
    { key = "ach",     label = ACHIEVEMENTS,                     binding = "TOGGLEACHIEVEMENT",      globals = { "AchievementMicroButton" } },
    { key = "quest",   label = QUEST_LOG,                        binding = "TOGGLEQUESTLOG",         globals = { "QuestLogMicroButton" } },
    { key = "guild",   label = GUILD_AND_COMMUNITIES or GUILD,   binding = "TOGGLEGUILD",            globals = { "GuildMicroButton" } },
    { key = "lfg",     label = DUNGEONS_BUTTON,                  binding = "TOGGLEGROUPFINDER",      globals = { "LFDMicroButton" } },
    { key = "housing", label = HOUSING_MICRO_BUTTON,             binding = "TOGGLEHOUSINGDASHBOARD", globals = { "HousingMicroButton" } },
    { key = "pet",     label = COLLECTIONS,                      binding = "TOGGLECOLLECTIONS",      globals = { "CollectionsMicroButton" } },
    { key = "journal", label = ADVENTURE_JOURNAL,                binding = "TOGGLEENCOUNTERJOURNAL", globals = { "EJMicroButton" } },
    { key = "shop",    label = BLIZZARD_STORE,                   binding = nil,                      globals = { "StoreMicroButton" } },
    { key = "help",    label = HELP_BUTTON,                      binding = nil,                      globals = { "HelpMicroButton" } },
    -- menu 走 plain：MainMenuMicroButtonMixin:OnClick 第一行就是 IsMouseOver() 閘
    -- （Blizzard_MicroMenu/Mainline/MainMenuBarMicroButtons.lua），secure 轉發時
    -- 滑鼠不在被藏起來的原鈕身上，點擊被整顆吃掉。EUI 同一個結論。
    { key = "menu",    label = MAINMENU_BUTTON,                  binding = "TOGGLEGAMEMENU",         globals = { "MainMenuMicroButton" }, plain = true },
}

MM.BUTTON_DEFS = BUTTON_DEFS

local function ResolveMicroButton(def)
    for _, name in ipairs(def.globals) do
        local ref = _G[name]
        if ref then return ref end
    end
end

------------------------------------------------------------
-- 圖示：從暴雪按鈕身上「抄」而不是自備圖檔
--
-- 12.x 的微型按鈕每顆是一張 atlas，執行期讀 GetNormalTexture():GetAtlas()
-- 就拿得到，改版換圖也自動跟上。單色風格＝同一張圖 SetDesaturated(true)
-- 再上灰／職業色；官方彩色風格＝原圖直出。什麼都讀不到就退回字母。
------------------------------------------------------------
local function DiscoverIcon(def, ref)
    if def.portrait then return { mode = "portrait" } end
    local nt = ref.GetNormalTexture and ref:GetNormalTexture()
    local atlas = nt and nt.GetAtlas and nt:GetAtlas()
    if atlas and atlas ~= "" then return { mode = "atlas", atlas = atlas } end
    local file = nt and nt:GetTexture()
    if file then return { mode = "file", file = file } end
    return { mode = "letter" }
end

local function SizeIcon(tile)
    local h = ns.GetDB().height - 6
    local info = tile.iconInfo
    local w = h
    -- 微型按鈕的 atlas 是直式（約 32x41），塞正方形會壓扁；照原始比例縮
    if info and info.mode == "atlas" and C_Texture and C_Texture.GetAtlasInfo then
        local ai = C_Texture.GetAtlasInfo(info.atlas)
        if ai and ai.width and ai.height and ai.height > 0 then
            w = h * (ai.width / ai.height)
        end
    end
    tile.icon:SetSize(w, h)
end

local function ApplyIconStyle(tile)
    local style = ns.GetDB().iconStyle
    local info = tile.iconInfo
    local icon = tile.icon

    if info.mode == "letter" then
        icon:Hide()
        if tile.letter then tile.letter:Show() end
        return
    end
    if tile.letter then tile.letter:Hide() end
    icon:Show()

    if info.mode == "portrait" then
        SetPortraitTexture(icon, "player")
    elseif info.mode == "atlas" then
        icon:SetAtlas(info.atlas)
    else
        icon:SetTexture(info.file)
    end
    SizeIcon(tile)

    if style == "blizzard" then
        icon:SetDesaturated(false)
        icon:SetVertexColor(1, 1, 1, 1)
    else
        icon:SetDesaturated(true)
        if tile:IsMouseMotionFocus() then
            local r, g, b = ns.W.Accent(1)
            icon:SetVertexColor(r, g, b, 1)
        else
            icon:SetVertexColor(ICON_TINT_IDLE, ICON_TINT_IDLE, ICON_TINT_IDLE, 1)
        end
    end
end

------------------------------------------------------------
-- 工具提示：只寫我們自己的字串（名稱＋快捷鍵），沒有讀受限資料，
-- 所以戰鬥中照常顯示，不用像 EUI 那樣換成戰鬥告示
------------------------------------------------------------
local function ShowTooltip(tile)
    local def = tile.def
    local _, cy = tile:GetCenter()
    local anchor = "ANCHOR_TOP"
    if cy and cy > UIParent:GetHeight() / 2 then anchor = "ANCHOR_BOTTOM" end
    GameTooltip:SetOwner(tile, anchor)
    GameTooltip:SetText(def.label or def.key, 1, 1, 1)
    if def.binding then
        local k1, k2 = GetBindingKey(def.binding)
        local keys = {}
        if k1 and k1 ~= "" then keys[#keys + 1] = GetBindingText(k1) end
        if k2 and k2 ~= "" then keys[#keys + 1] = GetBindingText(k2) end
        if #keys > 0 then
            GameTooltip:AddLine(table.concat(keys, " / "), 1, 0.82, 0)
        end
    end
    GameTooltip:Show()
end

------------------------------------------------------------
-- 區塊實例
------------------------------------------------------------
ns.Blocks = ns.Blocks or {}

ns.Blocks.micromenu = {}
function ns.Blocks.micromenu.create()
    local inst = { tiles = {}, buttons = {} }

    for _, def in ipairs(BUTTON_DEFS) do
        local ref = ResolveMicroButton(def)
        if ref then
            local tile = ns.CreateTile("MiliUIInfoBar_Micro_" .. def.key, {
                clickable = true,
                template  = not def.plain and "SecureActionButtonTemplate" or nil,
            })
            tile.def = def

            if def.plain then
                -- 遊戲選單自己開（理由見上面 BUTTON_DEFS 的註解）。戰鬥中不動手：
                -- insecure 開關 GameMenuFrame 有污染風險，Esc 鍵本身照常能用
                tile:SetScript("OnClick", function(_, button)
                    if button == "LeftButton" and not InCombatLockdown() then
                        ToggleFrame(GameMenuFrame)
                    end
                end)
            else
                -- secure 點擊轉發（機制逐字照 EUI）：
                -- useOnKeyDown=false —— 沒有這行，ActionButtonUseKeyDown 這個 CVar
                -- 會讓 secure handler 只認 key-down，把我們的 AnyUp 點擊丟掉
                tile:SetAttribute("*clickbutton1", ref)
                tile:SetAttribute("useOnKeyDown", false)
                tile:SetAttribute("*type1", "click")
            end

            local icon = tile:CreateTexture(nil, "OVERLAY")
            icon:SetPoint("CENTER")
            tile.icon = icon
            tile.iconInfo = DiscoverIcon(def, ref)

            if tile.iconInfo.mode == "letter" then
                local fs = tile:CreateFontString(nil, "OVERLAY")
                fs:SetFont(ns.LOCALE_FONT, 12, "")
                fs:SetPoint("CENTER")
                local label = def.label or def.key
                fs:SetText(label:sub(1, (label:byte(1) or 0) > 127 and 3 or 1))
                tile.letter = fs
            end

            tile:HookScript("OnEnter", function(self)
                if ns.GetDB().iconStyle ~= "blizzard" and self.icon:IsShown() then
                    local r, g, b = ns.W.Accent(1)
                    self.icon:SetVertexColor(r, g, b, 1)
                end
                ShowTooltip(self)
            end)
            tile:HookScript("OnLeave", function(self)
                if ns.GetDB().iconStyle ~= "blizzard" and self.icon:IsShown() then
                    self.icon:SetVertexColor(ICON_TINT_IDLE, ICON_TINT_IDLE, ICON_TINT_IDLE, 1)
                end
                GameTooltip:Hide()
            end)

            inst.buttons[def.key] = tile
            inst.tiles[#inst.tiles + 1] = tile
        end
    end

    function inst:Update()
        local db = ns.GetDB()
        for key, tile in pairs(self.buttons) do
            tile._blockHidden = not db.micro[key]
            tile.desiredW = db.height          -- 正方形
            ApplyIconStyle(tile)
        end
    end

    function inst:Enable()
        -- 頭像要跟著換裝／換形象更新；別的圖示是 atlas，不會變
        ns.Events.Register("UNIT_PORTRAIT_UPDATE", "micromenu", function(unit)
            if unit ~= "player" then return end
            local tile = inst.buttons.char
            if tile and not tile._blockHidden then ApplyIconStyle(tile) end
        end)
        ns.Events.Register("PLAYER_ENTERING_WORLD", "micromenu", function()
            local tile = inst.buttons.char
            if tile and not tile._blockHidden then ApplyIconStyle(tile) end
        end)
    end

    function inst:Disable()
        ns.Events.Unregister("UNIT_PORTRAIT_UPDATE", "micromenu")
        ns.Events.Unregister("PLAYER_ENTERING_WORLD", "micromenu")
    end

    return inst
end

------------------------------------------------------------
-- 暴雪微型選單的 secure hider
------------------------------------------------------------
local hiders = {}
local lastApplied = nil    -- 上次推的狀態（"hide"/"show"）；nil = 從來沒動過

local function GetHider(target)
    local h = hiders[target]
    if h then return h end
    if InCombatLockdown() then return nil end
    h = CreateFrame("Frame", nil, nil, "SecureHandlerStateTemplate")
    h:SetFrameRef("target", target)
    h:SetAttribute("_onstate-vis", [[
        local target = self:GetFrameRef('target')
        if newstate == 'hide' then target:Hide() else target:Show() end
    ]])
    hiders[target] = h
    return h
end

-- force：想要的狀態沒變也重推。driver 註冊的是常數狀態、snippet 不會重新求值，
-- 外力（載入畫面重置、編輯模式把它 Show 回來）造成的偏移只有重推救得回來。
function MM.UpdateBlizzardHidden(force)
    local db = ns.GetDB()
    local blockCfg = db.blocks and db.blocks.micromenu
    local hide = (db.enabled and db.hideBlizzard and blockCfg and blockCfg.enabled) and true or false

    -- 玩家從沒開過隱藏就一根手指都不碰暴雪的框：不掛 hider、不推 "show"
    if not hide and lastApplied == nil then return end

    local want = hide and "hide" or "show"
    if not force and want == lastApplied then return end
    lastApplied = want

    ns.Defer("mm-blizzhider", function()
        local targets = {}
        if _G.MicroMenuContainer then targets[#targets + 1] = _G.MicroMenuContainer end
        if _G.MicroButtonAndBagsBar then targets[#targets + 1] = _G.MicroButtonAndBagsBar end
        for i = 1, #targets do
            local h = GetHider(targets[i])
            if h then
                UnregisterStateDriver(h, "vis")
                RegisterStateDriver(h, "vis", want)
            end
        end
    end)
end
