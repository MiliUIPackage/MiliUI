------------------------------------------------------------
-- 微型選單區塊：secure 點擊轉發 ＋ 暴雪那排的 secure hider
--
-- 做法照 EllesmereUI DataBars 的 micromenu 區塊（tmp/ 裡研究過的那份）：
--
-- 1. 每顆自製按鈕是 SecureActionButtonTemplate，*type1 = "macro"、
--    *macrotext1 = "/click <暴雪 MicroButton 的名字>"。點我們的按鈕＝secure 的巨集
--    處理器去按暴雪按鈕，戰鬥中的行為跟原廠一模一樣（天賦、角色資訊照樣打得開）。
--    ⚠ 12.1 起天賦／法術書**必須**走 secure 轉發：addon Lua 直接開視窗會污染框架，
--    之後 SetCooldown 吃到秘密值就崩。
--    ⚠⚠ 而且**不能用 `*clickbutton1 = 框`**（第一版就是這樣寫的）：框參照型的屬性
--    引擎沒辦法像字串那樣複製成乾淨的值，讀回來就是髒的，轉發出去的點擊整段帶
--    InfoBar 的 taint —— 效果跟 addon Lua 直接開視窗一樣糟，只是堆疊上看不到我們。
--    2026-09-07 taint.log 抓到的，見方塊建立處的說明。
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
local W = ns.W

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
-- 通知鏡射：暴雪原鈕的閃爍搬到我們的方塊上
--
-- 原鈕被藏起來之後，暴雪畫在它身上的提示（有人申請入隊、法術書有新東西、
-- 公會有未讀）玩家就看不到了。
--
-- 掛的是**全域函式** MicroButtonPulse / MicroButtonPulseStop
-- （Blizzard_MicroMenu/Mainline/MainMenuBarMicroButtons.lua），不是逐一去接
-- 「哪些情境會閃」——那份清單散在十幾支暴雪檔案裡，列舉一定會漏，而且改版
-- 就過期。掛在源頭上，誰呼叫都算數。
--
-- 聲音不用管：PlaySound 跟框的顯示狀態無關，照樣會響（唯一的例外是排隊眼睛，
-- 它的音效綁在自己的動畫上，所以上面的 hider 不碰它）。
------------------------------------------------------------
local refToTile = {}          -- 暴雪原鈕 → 我們的方塊
local ourTiles = {}           -- 我們的方塊（集合），診斷時用來認出「已經重錨過了」
local pulseHooked = false

local function EnsurePulseTexture(tile)
    if tile.pulseTex then return tile.pulseTex end
    local t = tile:CreateTexture(nil, "OVERLAY", nil, 7)
    t:SetAllPoints()
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetAlpha(0)
    t:Hide()
    local ag = t:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(0)
    a:SetToAlpha(0.4)
    a:SetDuration(0.6)
    t.anim = ag
    tile.pulseTex = t
    return t
end

local function SetTilePulsing(tile, on)
    if not tile then return end
    if on then
        local t = EnsurePulseTexture(tile)
        t:SetVertexColor(ns.W.Accent(1))
        t:Show()
        t.anim:Play()
    elseif tile.pulseTex then
        tile.pulseTex.anim:Stop()
        tile.pulseTex:SetAlpha(0)
        tile.pulseTex:Hide()
    end
end

local function EnsurePulseHooks()
    if pulseHooked then return end
    if not (_G.MicroButtonPulse and _G.MicroButtonPulseStop) then return end
    pulseHooked = true
    hooksecurefunc("MicroButtonPulse", function(btn)
        local t0 = ns.Perf.Begin()
        SetTilePulsing(refToTile[btn], true)
        ns.Perf.End("hook MicroButtonPulse", t0)
    end)
    hooksecurefunc("MicroButtonPulseStop", function(btn)
        local t0 = ns.Perf.Begin()
        SetTilePulsing(refToTile[btn], false)
        ns.Perf.End("hook MicroButtonPulseStop", t0)
    end)
end

------------------------------------------------------------
-- 教學提示鏡射（「你還有尚未選用的天賦」那種黃色泡泡）
--
-- 暴雪把提示錨在**原鈕**上：MainMenuMicroButton_ShowAlert 裡是
-- `HelpTip:Show(UIParent, info, microButton)`（MainMenuBarMicroButtons.lua）。
-- 原鈕被藏起來但位置還在畫面右下角，提示就飛到那裡，跟資訊列完全對不上。
--
-- ⚠⚠ 第一版（2026-08-29 ~ 09-07）是把暴雪那顆提示的 `relativeRegion`／
-- `info.targetPoint` 改成指向我們的方塊，再讓它自己重錨。**這就是整個套組
-- 「快捷列 SetCooldown 秘密值／戰鬥中 SetShown 被擋、全記在 InfoBar 頭上」的根**：
--
--   Blizzard_PlayerSpells/Blizzard_PlayerSpellsFrame.lua:41
--     OnShow → PlayerSpellsMicroButton:EvaluateAlertVisibility()   收掉那顆提示
--   Blizzard_SharedXML/HelpTip.lua:408
--     OnHide → local relativeRegion = self.relativeRegion            ← 我們寫的欄位
--
-- 天賦視窗一開，暴雪在同一條執行流程裡讀到我們寫的欄位，從那一行起整條都是
-- InfoBar 的：SetTab 的 SetShown（戰鬥中打不開）、之後 ESC 關窗把所有快捷列的
-- 格子收起來、每顆按鈕永久染髒。只在「有未用天賦點、提示正顯示」時發生 ⇒ 隨機。
-- 2026-09-07 taint.log ＋ /cdprobe scan 抓到的。
--
-- 所以現在的規則：**對暴雪的提示框只讀不寫，也不呼叫 HelpTip 的任何 API**
-- （Show／Hide／Acknowledge 都會在我們的執行流程裡寫它的 pool 與 FrameWatcher）。
--   · 文字從 `frame.info.text` 讀出來，畫在自己的泡泡上、錨在自己的方塊上
--   · 暴雪那顆用 SetAlpha(0) ＋ EnableMouse(false) 讓它隱形——純 C 端的 widget
--     狀態，taint 不追蹤；Release 掛勾把它還原，pool 重用時才不會看不見
--   · 泡泡的叉叉走 SetCVarBitfield 直接記「已看過」（HelpTip 自己的
--     HandleAcknowledge 也是這一行），暴雪那顆留給它自己的生命週期收
-- 掛勾全是 hooksecurefunc 的後置勾，本體只做讀取、自己的框、C 端呼叫。
------------------------------------------------------------
local helpTipHooked = false
local dimmed = setmetatable({}, { __mode = "k" })   -- 被我們隱形的暴雪提示框
local acked = {}                                    -- 已按過叉叉的提示文字（本場）
-- 自己的泡泡：每顆方塊各一顆（暴雪的微型按鈕提示本來一次只顯示一顆，但判準是
-- 「錨在哪顆原鈕」，不是列舉提示種類——專業／天賦／PvP 點數／成就／收藏／公會／地城
-- 都走同一支 MainMenuMicroButton_ShowAlert，兩顆同時在也各自接得住）
local bubbles = {}                                  -- tile → 泡泡框

-- 這顆暴雪提示對應到我們哪一顆方塊（只讀）
local function TileForTip(frame)
    local rr = frame.relativeRegion
    return rr and refToTile[rr] or nil
end

local function Dim(frame)
    if dimmed[frame] then return end
    dimmed[frame] = true
    frame:SetAlpha(0)
    frame:EnableMouse(false)
    if frame.CloseButton then frame.CloseButton:EnableMouse(false) end
end

local function Undim(frame)
    if not dimmed[frame] then return end
    dimmed[frame] = nil
    frame:SetAlpha(1)
    frame:EnableMouse(true)
    if frame.CloseButton then frame.CloseButton:EnableMouse(true) end
end

local function AcknowledgeInfo(info)
    if info and info.cvarBitfield and info.bitfieldFlag then
        SetCVarBitfield(info.cvarBitfield, info.bitfieldFlag, true)
    end
end

local BUBBLE_W, BUBBLE_PAD = 260, 8

local function EnsureBubble(tile)
    local b = bubbles[tile]
    if b then return b end
    b = W.CreateFrame(nil, UIParent)
    b:SetFrameStrata("DIALOG")
    b:SetClampedToScreen(true)
    W.Stylize(b, { 0, 0, 0, 0.85 }, { W.Accent(1) })

    local text = b:CreateFontString(nil, "OVERLAY")
    text:SetFont(ns.LOCALE_FONT, 12, "")
    text:SetTextColor(1, 1, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    text:SetWidth(BUBBLE_W - BUBBLE_PAD * 2 - 18)
    text:SetPoint("TOPLEFT", b, "TOPLEFT", BUBBLE_PAD, -BUBBLE_PAD)
    b.text = text

    local close = CreateFrame("Button", nil, b)
    close:SetSize(16, 16)
    close:SetPoint("TOPRIGHT", b, "TOPRIGHT", -4, -4)
    local x = close:CreateFontString(nil, "OVERLAY")
    x:SetFont(ns.LOCALE_FONT, 14, "")
    x:SetPoint("CENTER")
    x:SetText("×")
    x:SetTextColor(1, 0.82, 0)
    close:SetScript("OnEnter", function() x:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() x:SetTextColor(1, 0.82, 0) end)
    close:SetScript("OnClick", function()
        if b.info then
            AcknowledgeInfo(b.info)
            if b.info.text then acked[b.info.text] = true end
        end
        b:Hide()
    end)
    b.close = close
    b:Hide()
    bubbles[tile] = b
    return b
end

local function ShowBubbleFor(tile, info)
    local b = EnsureBubble(tile)
    b.info = info
    b.text:SetText(info.text or "")
    b:SetSize(BUBBLE_W, math.ceil(b.text:GetStringHeight() + BUBBLE_PAD * 2))
    b:ClearAllPoints()
    local _, cy = tile:GetCenter()
    if cy and cy > UIParent:GetHeight() / 2 then
        b:SetPoint("TOP", tile, "BOTTOM", 0, -6)
    else
        b:SetPoint("BOTTOM", tile, "TOP", 0, 6)
    end
    b:Show()
end

local function HideAllBubbles()
    for _, b in pairs(bubbles) do b:Hide() end
end

-- 把現況對齊。只讀暴雪的 pool，不寫它任何東西。
--   · 不藏原廠那排：全部還原、泡泡收掉
--   · 藏著：每一顆錨在「我們有顯示的方塊」對應原鈕上的暴雪提示 → 原泡泡隱形、
--     方塊上開自己的泡泡。方塊被使用者藏掉的那顆**不動**：留著暴雪的原泡泡
--     （位置會對不上，但總比整顆提示消失好），也不隱形它。
local function SyncBubble()
    local pool = HelpTip and HelpTip.framePool
    if not (pool and pool.EnumerateActive) then return end
    if not ns.GetDB().hideBlizzard then
        for frame in pairs(dimmed) do Undim(frame) end
        HideAllBubbles()
        return
    end
    local shown = {}                       -- tile → 這一輪有鏡射到
    for frame in pool:EnumerateActive() do
        local tile = TileForTip(frame)
        if tile then
            local info = frame.info
            if tile:IsShown() and info and info.text then
                Dim(frame)
                if not acked[info.text] and not shown[tile] then
                    ShowBubbleFor(tile, info)
                    shown[tile] = true
                end
            else
                Undim(frame)               -- 方塊藏著就把原泡泡還給暴雪
            end
        end
    end
    for tile, b in pairs(bubbles) do
        if not shown[tile] then b:Hide() end
    end
end
MM.SyncHelpBubble = SyncBubble

local function EnsureHelpTipHook()
    if helpTipHooked then return end
    local pool = HelpTip and HelpTip.framePool
    if not (HelpTip and HelpTip.Show and pool and pool.EnumerateActive) then return end
    helpTipHooked = true
    -- 後置勾：暴雪做完、taint 已還原，我們的本體丟到下一幀再同步
    -- （方塊排完位置錨點才有效；也順便完全脫離觸發那次 Show 的暴雪堆疊）
    local function Resync() ns.NextFrame("helptip-sync", SyncBubble) end
    hooksecurefunc(HelpTip, "Show", Resync)
    hooksecurefunc(HelpTip, "Hide", Resync)
    hooksecurefunc(HelpTip, "HideAllSystem", Resync)
    hooksecurefunc(HelpTip, "Acknowledge", Resync)
    hooksecurefunc(HelpTip, "AcknowledgeSystem", Resync)
    -- 回 pool 前立刻還原隱形：同一幀就可能被別的系統 Acquire 回去用
    hooksecurefunc(HelpTip, "Release", function(_, frame)
        if frame then Undim(frame) end
        Resync()
    end)
end

------------------------------------------------------------
-- /mib debug 用的現場報告
------------------------------------------------------------
local function FrameName(f)
    if not f then return "nil" end
    if f.GetName and f:GetName() then return f:GetName() end
    return "(無名框)"
end

function MM.DebugInfo()
    print("  hideBlizzard：" .. tostring(ns.GetDB().hideBlizzard)
        .. "　HelpTip 掛勾：" .. (helpTipHooked and "已掛" or "沒掛"))
    local n = 0
    for _ in pairs(refToTile) do n = n + 1 end
    print("  refToTile 登記了 " .. n .. " 顆原鈕")
    local pool = HelpTip and HelpTip.framePool
    if not (pool and pool.EnumerateActive) then
        print("  HelpTip.framePool：讀不到（這就是掛勾失敗的原因）")
        return
    end
    local function Pos(f)
        if not (f and f.GetLeft and f:IsRectValid()) then return "座標讀不到" end
        return string.format("x=%d y=%d 顯示=%s",
            math.floor(f:GetLeft() or 0), math.floor(f:GetTop() or 0), tostring(f:IsShown()))
    end

    local any = false
    for frame in pool:EnumerateActive() do
        any = true
        local rr = frame.relativeRegion
        local state
        if rr and refToTile[rr] then
            state = dimmed[frame] and "|cff33ff66已鏡射到資訊列（原泡泡隱形）|r"
                                   or "|cffff9900錨在暴雪原鈕上，尚未鏡射|r"
        else
            state = "跟資訊列無關，不動它"
        end
        local text = frame.info and frame.info.text or frame.lastInfoText or "?"
        if #text > 18 then text = text:sub(1, 18) .. "…" end
        print("  提示「" .. text .. "」" .. state)
        print("      錨在 " .. FrameName(rr) .. "（" .. Pos(rr) .. "）")
        print("      暴雪泡泡 " .. Pos(frame))
    end
    if not any then print("  現役提示：沒有") end
    local shownBubbles = 0
    for tile, b in pairs(bubbles) do
        if b:IsShown() then
            shownBubbles = shownBubbles + 1
            print("  自己的泡泡（" .. FrameName(tile) .. "）" .. Pos(b))
        end
    end
    if shownBubbles == 0 then print("  自己的泡泡：沒顯示") end
end

------------------------------------------------------------
-- 右鍵選單（共用層 W.Menu）：進設定的捷徑＋隱藏這一顆。
-- 「隱藏」跟一般項目用分隔線隔開、不放第一個（選單設計標準）；
-- 藏掉之後的救回路徑就是上面那條「開啟設定」。
------------------------------------------------------------
local function ShowButtonMenu(tile)
    GameTooltip:Hide()
    local def = tile.def
    W.Menu.Show({
        { isTitle = true, text = L["ADDON_NAME"] },
        {
            text = L["MENU_OPEN_SETTINGS"],
            onClick = function() ns.OpenSettings("micro") end,
        },
        { isSeparator = true },
        {
            text = L["MENU_HIDE_BUTTON"]:format(def.label or def.key),
            onClick = function()
                ns.GetDB().micro[def.key] = false
                ns.ApplyAll()
            end,
        },
    }, tile)
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
                -- secure 點擊轉發：走 **macrotext 的 /click <名字>**，不是 clickbutton。
                --
                -- ⚠⚠ 2026-09-07 taint.log 實測：`*clickbutton1 = 框` 這條轉發出來的點擊
                -- 是**髒的**（SecureTemplates.lua:565 handler → clickbutton:Click() 整段
                -- 帶 MiliUI_InfoBar 的 taint，天賦視窗在裡面開啟就整個染髒，之後 ESC 關窗
                -- 那趟把所有快捷列格子收起來，每顆按鈕永久帶 taint ⇒ 戰鬥中 SetShown 被擋、
                -- UpdateCooldown 的 SetCooldown 吃秘密值就炸）。原因：字串型屬性引擎會複製成
                -- 乾淨的值，**框物件參照沒辦法複製**，插件端 SetAttribute 寫進去的參照讀回來
                -- 就是髒的。/click 吃的是名字字串，屬性乾淨、由 secure 的巨集處理器去按。
                -- MiliUI_UnitFrames 的右鍵選單 proxy 同一招（Core/UnitFrame.lua，12.1 實測）。
                -- useOnKeyDown=false —— 沒有這行，ActionButtonUseKeyDown 這個 CVar
                -- 會讓 secure handler 只認 key-down，把我們的 AnyUp 點擊丟掉
                tile:SetAttribute("*type1", "macro")
                tile:SetAttribute("*macrotext1", "/click " .. ref:GetName())
                tile:SetAttribute("useOnKeyDown", false)
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

            -- 右鍵＝選單。secure 方塊不能在 OnClick 上直接掛 Lua（會把左鍵的 secure 轉發
            -- 一起染髒），走 Core/Bar.lua 的 ns.SecureRightClick（WrapScript ＋ CallMethod）；
            -- 遊戲選單那顆是 plain 按鈕，OnClick 本來就是我們的，直接 hook 即可
            if def.plain then
                tile:HookScript("OnClick", function(self, button)
                    if button == "RightButton" then ShowButtonMenu(self) end
                end)
            else
                ns.SecureRightClick(tile, ShowButtonMenu)
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

            refToTile[ref] = tile
            ourTiles[tile] = true
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
        -- 方塊排完位置才有效的錨點：延到下一幀同步鏡射的泡泡
        -- （登入當下就掛著的提示不會再有 Show 呼叫，也靠這一趟接住）
        ns.NextFrame("helptip-sync", SyncBubble)
    end

    function inst:Enable()
        EnsurePulseHooks()
        EnsureHelpTipHook()
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
        -- ⚠ 藏的是 MicroMenu（按鈕格），**不是** MicroMenuContainer。
        -- QueueStatusButton（排隊中的綠色眼睛）的父層就是那個容器，跟按鈕格是
        -- 兄弟——藏容器會把眼睛一起帶走，而那顆眼睛不只是顯示排隊狀態：
        -- 「有人申請入隊」的音效是掛在它的 EyeHighlightAnim 動畫迴圈的 OnLoop 上
        -- （Blizzard_QueueStatusFrame/Mainline/QueueStatusFrame.xml），動畫不跑
        -- 就連聲音都沒了。所以只藏按鈕格，眼睛留給暴雪自己管。
        if _G.MicroMenu then targets[#targets + 1] = _G.MicroMenu end
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
