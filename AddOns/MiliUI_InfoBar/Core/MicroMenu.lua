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
        SetTilePulsing(refToTile[btn], true)
    end)
    hooksecurefunc("MicroButtonPulseStop", function(btn)
        SetTilePulsing(refToTile[btn], false)
    end)
end

------------------------------------------------------------
-- 教學提示重錨（「你有可用的 PvP 天賦欄位」那種黃色泡泡）
--
-- 暴雪把提示錨在**原鈕**上：MainMenuMicroButton_ShowAlert 裡是
-- `HelpTip:Show(UIParent, info, microButton)`（MainMenuBarMicroButtons.lua）。
-- 原鈕被藏起來但位置還在畫面右下角，提示就飛到那裡，跟資訊列完全對不上。
--
-- **不搬暴雪的按鈕**：它們是 GridLayoutFrame 的子物件，那個容器一重排就把我們
-- 的 SetPoint 蓋掉；而且按鈕顆數會隨設定變、尺寸也會變，硬對位置是撐不住的。
-- 改成提示**建出來之後**把它的 relativeRegion 換成對應的方塊、再讓暴雪自己重錨
-- 一次。查表走 refToTile，所以顆數與尺寸怎麼變都自動對得上。
--
-- `AnchorAndRotate()` 不帶參數就是 Init 收尾的那一下（HelpTip.lua:530），
-- 箭頭方向與偏移全部照暴雪自己的算法重算，我們不自己算座標。
------------------------------------------------------------
local helpTipHooked = false

-- 把一個還在顯示中的提示改錨到對應的方塊上。
-- 比對用 **relativeRegion**（錨定對象）而不是 info 表的參照：
-- `MainMenuMicroButton_ShowAlert` 每次呼叫都新建一張 helpTipInfo，而
-- `HelpTip:Show` 在「同樣的文字已經在顯示中」時會**提前 return、不重建 frame**
-- （HelpTip.lua:181）——那條路上舊 frame 的 info 跟這次傳進來的根本不是同一張表，
-- 拿 info 比對就永遠對不上。
-- 泡泡有沒有真的黏過來（只看水平距離就夠了：錯位時是整個飛到畫面另一邊）
local function TipFollowed(frame, tile)
    if not (frame.IsRectValid and frame:IsRectValid() and tile:IsRectValid()) then
        return false
    end
    local fx = frame:GetCenter()
    local tx = tile:GetCenter()
    if not (fx and tx) then return false end
    return math.abs(fx - tx) < 250
end

-- ⚠⚠ 只換 `relativeRegion` 再叫 `AnchorAndRotate()` **不會有任何反應**，而且不報錯。
-- 原因是那支開頭有一道快取閘（HelpTip.lua:552）：
--     if targetPoint == self.appliedTargetPoint and alignment == self.appliedAlignment then
--         return;
-- 我們動的是錨定「對象」，targetPoint／alignment 都沒變，所以它直接 return——
-- 連每幀跑的 OnUpdate 也是同一道閘擋掉。**清掉那兩個快取欄位**它才會真的重算。
--
-- 箭頭方向也在同一支裡處理（RotateArrow ＋ AnchorArrow），所以只要讓它重算，
-- 位置與箭頭會一起對；我們唯一要決定的是泡泡該在方塊的哪一側：
--   方塊在畫面下半 → 泡泡放上方 → targetPoint = TopEdgeCenter（箭頭朝下）
--   方塊在畫面上半 → 泡泡放下方 → targetPoint = BottomEdgeCenter（箭頭朝上）
-- 寫進 `info.targetPoint` 而不是用 AnchorAndRotate 的 override 參數：OnUpdate
-- 每幀都會拿 `info.targetPoint` 重算一次，只傳 override 的話下一幀就被翻回去。
local function ApplyAnchor(frame, tile)
    frame.relativeRegion = tile

    local _, cy = tile:GetCenter()
    if cy and cy > UIParent:GetHeight() / 2 then
        frame.info.targetPoint = HelpTip.Point.BottomEdgeCenter
    else
        frame.info.targetPoint = HelpTip.Point.TopEdgeCenter
    end

    frame.appliedTargetPoint = nil
    frame.appliedAlignment = nil
    pcall(frame.AnchorAndRotate, frame)
    if TipFollowed(frame, tile) then return "官方" end

    -- 保險絲：官方那條路萬一又變了，至少位置要對（箭頭方向就只能將就）。
    -- 自己接手時要把 OnUpdate 拿掉，不然 autoHorizontalSlide 每幀會跟我們搶。
    frame:SetScript("OnUpdate", nil)
    frame:ClearAllPoints()
    if cy and cy > UIParent:GetHeight() / 2 then
        frame:SetPoint("TOP", tile, "BOTTOM", 0, -14)
    else
        frame:SetPoint("BOTTOM", tile, "TOP", 0, 14)
    end
    return "自己接手"
end

local function ReanchorTo(relativeRegion)
    local tile = relativeRegion and refToTile[relativeRegion]
    if not (tile and tile:IsShown()) then return end
    local pool = HelpTip and HelpTip.framePool
    if not (pool and pool.EnumerateActive) then return end
    for frame in pool:EnumerateActive() do
        if frame.relativeRegion == relativeRegion then
            ApplyAnchor(frame, tile)
        end
    end
end

-- 補掃：掛勾只接得到「之後」的 Show。登入當下就已經掛著的提示（PvP 天賦欄位
-- 那種一直留到玩家按叉叉為止的）在我們掛勾之前就顯示完了，之後也不會再有
-- Show 呼叫，所以要主動掃一次現役的提示。
local function ReanchorExisting()
    if not ns.GetDB().hideBlizzard then return end
    local pool = HelpTip and HelpTip.framePool
    if not (pool and pool.EnumerateActive) then return end
    for frame in pool:EnumerateActive() do
        local rr = frame.relativeRegion
        -- 兩種都要補：還錨在暴雪原鈕上的，以及錨點換過來了但位置沒跟上的
        local tile = rr and (refToTile[rr] or (ourTiles[rr] and rr))
        if tile and tile:IsShown() and not TipFollowed(frame, tile) then
            ApplyAnchor(frame, tile)
        end
    end
end

local function EnsureHelpTipHook()
    if helpTipHooked then return end
    local pool = HelpTip and HelpTip.framePool
    if not (HelpTip and HelpTip.Show and pool and pool.EnumerateActive) then return end
    helpTipHooked = true
    hooksecurefunc(HelpTip, "Show", function(_, _, _, relativeRegion)
        -- 沒在藏原廠那排的話，提示本來就錨在看得見的原鈕上，不要多事
        if not ns.GetDB().hideBlizzard then return end
        ReanchorTo(relativeRegion)
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
        if rr and ourTiles[rr] then
            state = "|cff33ff66已重錨到資訊列|r"
        elseif rr and refToTile[rr] then
            state = "|cffff9900還錨在暴雪原鈕上（待重錨）|r"
        else
            state = "跟資訊列無關，不動它"
        end
        local text = frame.info and frame.info.text or frame.lastInfoText or "?"
        if #text > 18 then text = text:sub(1, 18) .. "…" end
        print("  提示「" .. text .. "」" .. state)
        print("      錨在 " .. FrameName(rr) .. "（" .. Pos(rr) .. "）")
        print("      泡泡本身 " .. Pos(frame))
    end
    if not any then print("  現役提示：沒有") end
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

            -- 右鍵＝選單（secure 只綁了 *type1，右鍵沒有 secure 動作，hook 接手）
            tile:HookScript("OnClick", function(self, button)
                if button == "RightButton" then ShowButtonMenu(self) end
            end)

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
        -- 方塊排完位置才有效的錨點：延到下一幀補掃現役提示
        C_Timer.After(0, ReanchorExisting)
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
