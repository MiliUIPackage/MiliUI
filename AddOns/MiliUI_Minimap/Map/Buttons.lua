------------------------------------------------------------
-- 插件按鈕收納（取代 MBB）
--
-- 地圖旁那一圈第三方插件的圓鈕全部收走，分成兩個去處：
--
--   收納袋 (bag)   按一顆鈕才展開的格狀面板 —— 大多數按鈕都住這裡
--   常駐排 (pin)   永遠看得見的一條，貼著地圖某一邊 —— 玩家釘上去的那幾顆
--
-- 「釘出來」不是可有可無的裝飾：有些按鈕**本身就是讀數**（收件匣有沒有信、
-- 大秘境計時、拍賣掃描進度），把它們收進要點一下才看得到的袋子等於廢掉那顆按鈕。
-- 所以每顆按鈕都能單獨選「留在地圖上」。
--
-- ── 為什麼是「永久 reparent」而不是「藏起來再另外畫一份」 ──────────────
--
-- Ellesmere 走的是「把按鈕留在小地圖上、alpha 歸零、開面板時再借過去」，
-- 代價是要跟插件本身搶 Show/Hide：LibDBIcon 之類的函式庫會定時重新 Show 自己的
-- 圖示，所以那邊得掛 Show/Hide 掛勾、記錄「插件本來想不想顯示」、還要在面板開著
-- 的時候凍結那份紀錄。三段狀態機，每一段都有「面板開著時例外」。
--
-- 這裡選另一條：**搬進我們的容器就不還了**，只是容器有兩種。
-- 一旦不是 Minimap 的子框，插件再怎麼 Show 都只是「在我們的容器裡顯示」，
-- 完全不用搶 —— 而「留在地圖上」也不必走回頭路，換個容器就好。
--
-- ⚠ 戰鬥中不能 reparent／Hide 受保護的框，而且是**靜默**失敗（不丟 Lua 錯誤）。
--   所有掃描與搬移都閘在 InCombatLockdown 外面，戰鬥中排程等出戰鬥。
------------------------------------------------------------
local _, ns = ...

ns.Buttons = {}
local Buttons = ns.Buttons
local S = ns.Style
local P = ns.P
local W = ns.W

local bag, pin
local collected = {}          -- 陣列，依標籤排序；元素是 frame
local isCollected = {}        -- [frame] = true
local scanQueued = false
local layoutQueued = false

------------------------------------------------------------
-- 不收的東西
--
-- 判準是「這顆按鈕代表**一個插件**嗎」。不是的就別收：
--   * 暴雪自己的功能鈕已經在 Skin.lua 排進地圖四角了
--   * 插件隔間是「所有插件的選單」，不是某一個插件的按鈕
--   * 地圖圖釘（HandyNotes、TomTom…）數量可以上百，而且它們是**地圖內容**
------------------------------------------------------------
local BLACKLIST = {
    MinimapZoomIn = true, MinimapZoomOut = true,
    MinimapBackdrop = true, MinimapCluster = true,
    GameTimeFrame = true,
    ExpansionLandingPageMinimapButton = true,
    AddonCompartmentFrame = true,
    MiniMapMailFrame = true,
    MiniMapTracking = true,
    QueueStatusMinimapButton = true,
    MinimapZoneTextButton = true,
    TimeManagerClockButton = true,
}

local PIN_PATTERNS = {
    "^HandyNotes", "^TomTom", "^HereBeDragons", "^Questie",
    "^GatherMate", "^Routes", "^pin", "^Pin", "^POI",
}

local function IsMapPin(name)
    for _, pat in ipairs(PIN_PATTERNS) do
        if name:match(pat) then return true end
    end
    return false
end

------------------------------------------------------------
-- 圓框裝飾
--
-- 第三方按鈕多半是「方形圖示 ＋ 一圈暴雪的金色圓框」。圓框在方形格子裡看起來
-- 就是一顆一顆的貼紙，所以拆掉，只留圖示本身。
--
-- 用**貼圖本體**（fileID 與路徑兩種都比）認，不用欄位名 —— 各家把那張圖放在
-- `.border` / `.Border` / 匿名 region 都有，認欄位名一定會漏。
------------------------------------------------------------
local JUNK_ID = {
    [136430] = true,   -- MiniMap-TrackingBorder
    [136467] = true,   -- UI-Minimap-Background
    [136477] = true,   -- UI-Minimap-ZoomButton-Highlight
}
local JUNK_PATH = {
    "Minimap\\MiniMap%-TrackingBorder",
    "Minimap\\UI%-Minimap%-Background",
    "Minimap\\UI%-Minimap%-ZoomButton%-Highlight",
}

local function IsJunk(region)
    if not region or not region.IsObjectType or not region:IsObjectType("Texture") then
        return false
    end
    local id = region.GetTextureFileID and region:GetTextureFileID()
    if id and JUNK_ID[id] then return true end
    local path = region.GetTexture and region:GetTexture()
    if type(path) == "string" then
        for _, pat in ipairs(JUNK_PATH) do
            if path:match(pat) then return true end
        end
    end
    return false
end

------------------------------------------------------------
-- 把一顆按鈕整成方形圖示
--
-- ⚠ **不做快照、不寫還原路徑。** 搬進來就不還了（見檔頭），留一份還原資料只是
--   讓每顆按鈕多帶一張表，而且那條路永遠不會被走到。要還原請 /reload ——
--   插件重新載入時會自己把圖示建回小地圖上。
------------------------------------------------------------
local function Normalize(btn)
    for _, region in ipairs({ btn:GetRegions() }) do
        if IsJunk(region) then
            region:SetAlpha(0)
            region:Hide()
        end
    end
    local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
    if hl and IsJunk(hl) then hl:SetTexture(nil) end

    ------------------------------------------------------------
    -- 找出「哪一張才是圖示」
    --
    -- ⚠ **不能無條件退回 `GetNormalTexture()`。** 有一類按鈕的 normal texture
    --   就是那圈暴雪圓框本身，圖示則是另一張子貼圖 —— 把圓框當圖示拉滿整格再
    --   裁 8%，結果是一張灰色的環蓋在整顆按鈕上，而且我們還把它提到 OVERLAY。
    --   那正是「圖示好像被上了一個遮罩」的第二個來源。
    --   退回之前先確認它不是我們認得的裝飾。
    ------------------------------------------------------------
    local icon = btn.icon or btn.Icon
    if not icon and btn.GetNormalTexture then
        local nt = btn:GetNormalTexture()
        if nt and not IsJunk(nt) then icon = nt end
    end
    if icon and icon.SetTexCoord then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
        -- 裁掉 8%：多數插件的圖示是整張方圖再蓋一個圓框，直接鋪滿會看到四個角落
        -- 的雜訊。8% 是「圓框內切正方形」的近似，跟暴雪自己的圖示裁法一致。
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        -- ⚠ 往**上**提到 OVERLAY，不要壓到 ARTWORK。
        --   我們只拆得掉認得出來的暴雪圓框（JUNK_ID / JUNK_PATH）；自帶造型的
        --   插件會有一張我們不認識的裝飾貼圖留在 ARTWORK 上，把圖示壓下去等於
        --   讓那張貼圖蓋在圖示上面 —— 症狀就是「圖示像被上了一層遮罩」。
        --   提上來最壞情況只是裝飾被圖示蓋住，那正是我們要的結果。
        icon:SetDrawLayer("OVERLAY")
    end
end

------------------------------------------------------------
-- 名字與標籤
--
-- 名字是**設定的鍵**（存進 SavedVariables 的 pinned 表），所以一定要用 frame
-- 的名字而不是排序後的索引 —— 索引會隨著「今天載了哪些插件」變動。
------------------------------------------------------------
local function Label(btn)
    local name = btn:GetName() or ""
    return (name:gsub("^LibDBIcon1?0?_", "")
                :gsub("^Lib_GPI_Minimap_", "")
                :gsub("_?MinimapButton$", "")
                :gsub("_?MinimapFrame$", ""))
end
Buttons.Label = Label

local function IsPinned(btn)
    local name = btn:GetName()
    return name and ns.DB.Get().pinned[name] == true
end

------------------------------------------------------------
-- 掃描
------------------------------------------------------------
local function Qualifies(child)
    if isCollected[child] then return false end
    if child == bag or child == pin then return false end
    local name = child:GetName()
    if not name then return false end            -- 沒名字的多半是圖釘或內部框
    if BLACKLIST[name] then return false end
    if IsMapPin(name) then return false end
    if name:match("^MiliUIMinimap") then return false end

    -- LibDBIcon 的圖示有時是 Frame 不是 Button（函式庫版本差異）
    if child:IsObjectType("Button") then
        -- 尾巴是數字的多半是「同一個插件的第 N 個內部框」，不是主按鈕
        if name:match("%d+$") and not name:match("^LibDBIcon") then return false end
        return (child:GetWidth() or 0) >= 18
    end
    return name:match("^LibDBIcon") ~= nil
end

-- 插件自己開關圖示（LibDBIcon 的「隱藏小地圖按鈕」）時要重排，否則格子會留洞。
-- ⚠ 掛勾裡**只排程**，不要直接 Layout：Show/Hide 在戰鬥中也會被呼叫，
--   而且一次設定變更可能連續打十幾發。
local hooked = {}
local function HookVisibility(btn)
    if hooked[btn] then return end
    hooked[btn] = true
    hooksecurefunc(btn, "Show", function() Buttons.QueueLayout() end)
    hooksecurefunc(btn, "Hide", function() Buttons.QueueLayout() end)
end

function Buttons.Scan()
    if not bag then return end
    if InCombatLockdown() then Buttons.Queue(); return end

    local found = false
    for _, child in ipairs({ Minimap:GetChildren() }) do
        if Qualifies(child) then
            isCollected[child] = true
            collected[#collected + 1] = child
            child:ClearAllPoints()
            -- ⚠ 收下的當場就搬進容器，不要等 Layout。Layout 只排「顯示中」的那些，
            --   插件自己關掉的按鈕會一直留在 Minimap 底下、而且**已經沒有錨點**
            --   （上一行剛清掉）—— 那種框一旦被插件 Show 回來就會出現在畫面左下角
            --   的原點上。先安置好，Layout 再管排哪一格。
            child:SetParent(IsPinned(child) and pin or bag)
            -- 有些按鈕自己會拖曳（LibDBIcon 的 minimapPos）。在格子裡沒有意義，
            -- 而且會被拖到容器外面再也找不回來。
            if child.SetMovable then child:SetMovable(false) end
            if child.RegisterForDrag then child:RegisterForDrag() end
            Normalize(child)
            HookVisibility(child)
            found = true
        end
    end

    if found then
        table.sort(collected, function(a, b)
            return Label(a):lower() < Label(b):lower()
        end)
        ns.Fire("ButtonsChanged")
    end
    Buttons.Layout()
end

function Buttons.Queue()
    if scanQueued then return end
    scanQueued = true
    local f = ns.scanWaiter
    if not f then
        f = CreateFrame("Frame")
        f:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            scanQueued = false
            ns.Safe(Buttons.Scan)
        end)
        ns.scanWaiter = f
    end
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
end

function Buttons.QueueLayout()
    if layoutQueued then return end
    layoutQueued = true
    C_Timer.After(0, function()
        layoutQueued = false
        ns.Safe(Buttons.Layout)
    end)
end

-- 設定頁用：目前收到的按鈕清單
function Buttons.List()
    return collected
end

function Buttons.Counts()
    return (bag and bag.count) or 0, (pin and pin.count) or 0
end

------------------------------------------------------------
-- 排版
--
-- 兩個容器共用一支排版：差別只有「幾欄」與「錨在哪」。
------------------------------------------------------------
local PAD = 4

-- 常駐排貼哪一邊 → { 容器的錨點, 相對 holder 的哪一角, x, y, 橫向? }
local PIN_SIDES = {
    top    = { "BOTTOMLEFT",  "TOPLEFT",     0,  1, true  },
    bottom = { "TOPLEFT",     "BOTTOMLEFT",  0, -1, true  },
    left   = { "TOPRIGHT",    "TOPLEFT",    -1,  0, false },
    right  = { "TOPLEFT",     "TOPRIGHT",    1,  0, false },
}

-- 回傳「排進去幾顆」。cols = 0 代表不限欄（單排）。
local function LayoutInto(parent, list, cols, size, gap)
    local shown = 0
    for _, btn in ipairs(list) do
        -- ⚠ 用 IsShown 不是 IsVisible：收納袋關著的時候整組都不可見，
        --   IsVisible 會讓每顆都被判定成隱藏、格子全空。
        if btn:IsShown() then
            local col, row
            if cols > 0 then
                col = shown % cols
                row = math.floor(shown / cols)
            else
                col, row = shown, 0
            end
            -- 父層沒變就不要重設：SetParent 會重算整條繼承鏈，
            -- 而 Layout 是每次插件開關圖示都會跑的。
            if btn:GetParent() ~= parent then btn:SetParent(parent) end
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", parent, "TOPLEFT",
                PAD + col * (size + gap), -(PAD + row * (size + gap)))
            btn:SetSize(size, size)

            ------------------------------------------------------------
            -- ⚠⚠ **reparent 不會把 strata 帶過來。**
            --
            --   frame 只有在「自己沒設過 strata」時才跟著父層走。LibDBIcon 會把
            --   它建的每顆按鈕**明確**釘在 MEDIUM，所以搬進 HIGH 的收納袋之後，
            --   按鈕還留在 MEDIUM —— 而收納袋的**底色貼圖**在 HIGH，
            --   於是那張底整片畫在圖示上面。
            --
            --   使用者看到的症狀是「圖示好像被上了一層遮罩」，而那層遮罩
            --   **就是我們自己的面板底**。`/framestack` 一看就穿幫：
            --     HIGH   → MiliUIMinimapButtonBag / .Center
            --     MEDIUM → LibDBIcon10_XXX
            --   同一個袋子裡沒被蓋到的那幾顆，剛好是自己就設成 HIGH 的按鈕。
            --
            --   `SetFixedFrameStrata/Level` 要先解掉，不然上面兩行是靜默無效的。
            ------------------------------------------------------------
            if btn.SetFixedFrameStrata then btn:SetFixedFrameStrata(false) end
            if btn.SetFixedFrameLevel then btn:SetFixedFrameLevel(false) end
            btn:SetFrameStrata(parent:GetFrameStrata())
            btn:SetFrameLevel(parent:GetFrameLevel() + 2)
            shown = shown + 1
        end
    end
    return shown
end

local function SizeContainer(frame, count, cols, size, gap, horizontal)
    if count == 0 then
        frame:SetSize(1, 1)
        return
    end
    local c, r
    if cols > 0 then
        c = math.min(cols, count)
        r = math.ceil(count / cols)
    elseif horizontal then
        c, r = count, 1
    else
        c, r = 1, count
    end
    frame:SetSize(c * size + (c - 1) * gap + PAD * 2,
                  r * size + (r - 1) * gap + PAD * 2)
end

function Buttons.Layout()
    if not bag or not ns.holder then return end
    if InCombatLockdown() then return end        -- reparent 會被封鎖；出戰鬥時 Scan 會補
    local db = ns.DB.Get()
    local size = P.Scale(db.btnSize)
    local gap  = P.Scale(db.btnGap)

    -- 分兩堆。順序沿用 collected 的排序，所以兩邊都是 A-Z。
    local bagList, pinList = {}, {}
    for _, btn in ipairs(collected) do
        if IsPinned(btn) then pinList[#pinList + 1] = btn
        else bagList[#bagList + 1] = btn end
    end

    local cols = math.max(1, db.btnColumns)
    local nBag = LayoutInto(bag, bagList, cols, size, gap)
    SizeContainer(bag, nBag, cols, size, gap)
    bag.count = nBag
    ns.Fire("BagCountChanged")

    ------------------------------------------------------------
    -- 常駐排：單排（橫或直），不折行
    --
    -- 不折行是刻意的 —— 常駐排會**永遠佔著畫面**，讓它長成兩行等於默許玩家
    -- 把二十顆都釘出來，那就回到我們要解決的問題本身了。
    -- 釘太多就會超出地圖邊界，那個難看正是「你釘太多了」的訊號。
    ------------------------------------------------------------
    local side = PIN_SIDES[db.pinSide] or PIN_SIDES.top
    local horizontal = side[5]
    local nPin = LayoutInto(pin, pinList, horizontal and 0 or 1, size, gap)
    SizeContainer(pin, nPin, 0, size, gap, horizontal)
    pin:ClearAllPoints()
    if db.pinSide == "bottom" and ns.infoBar and ns.infoBar:IsShown() then
        -- ⚠ 地圖正下方是**資訊列**的位置，直接貼 holder 的底會疊在它上面。
        --   有資訊列就接在它下面，沒有才貼地圖。
        pin:SetPoint("TOPLEFT", ns.infoBar, "BOTTOMLEFT", 0, -P.Scale(3))
    else
        pin:SetPoint(side[1], ns.holder, side[2], P.Scale(side[3] * 3), P.Scale(side[4] * 3))
    end
    pin:SetShown(nPin > 0)
    pin.count = nPin
end

------------------------------------------------------------
-- 釘住／取消釘住
------------------------------------------------------------
function Buttons.SetPinned(name, pinned)
    if not name then return end
    ns.DB.Get().pinned[name] = pinned or nil
    ns.Safe(Buttons.Layout)
end

function Buttons.GetPinned(name)
    return name and ns.DB.Get().pinned[name] == true
end

------------------------------------------------------------
-- 收納袋的開啟方向
--
-- 小地圖預設在畫面右上角，面板往左下長才不會出畫面。但地圖是可以搬的，
-- 所以方向**每次開啟時算**：地圖在螢幕右半就往左開，左半就往右開。
-- 寫死方向的話，把地圖搬到左邊的人會看到面板一半在畫面外。
------------------------------------------------------------
-- anchor = 資訊列裡那一格（沒有的話退回整條資訊列，再退回地圖）
local function PlaceBag(anchor)
    anchor = anchor or ns.infoBar or ns.holder
    if not anchor then return end
    bag:ClearAllPoints()
    local cx = anchor:GetCenter()
    local mid = (GetScreenWidth() or 1920) / 2
    -- 往下開（資訊列在地圖下面，往上開會蓋住地圖），左右靠螢幕的哪一半決定：
    -- 寫死方向的話，把地圖搬到左邊的人會看到袋子一半在畫面外。
    if cx and cx > mid then
        bag:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -P.Scale(3))
    else
        bag:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -P.Scale(3))
    end
end

function Buttons.IsOpen()
    return bag and bag:IsShown() or false
end

function Buttons.Toggle(anchor)
    if not bag then return end
    if bag:IsShown() then bag:Hide(); return end
    Buttons.Scan()          -- 開的那一刻補掃一次：晚載入的插件才收得到
    PlaceBag(anchor)
    bag:Show()
    -- ⚠ 提示跟袋子**開在同一個位置**（都是從那一格的下緣往下長），而提示是
    --   TOOLTIP 層、袋子是 HIGH 層 ⇒ 提示的不透明底會整片蓋在圖示上，
    --   看起來就像那排圖示被上了一層灰紗。開袋子的當下先把提示收掉。
    ns.Tip.Close()
end

function Buttons.Close()
    if bag then bag:Hide() end
end

------------------------------------------------------------
-- 開關鈕的圖示：3×3 的小方塊
--
-- 零資產、跟著職業色走，而且它長得就像「一袋按鈕」—— 比任何一張暴雪內建圖示
-- 都更說得清楚這顆鈕是幹嘛的。用 9 張 texture 而不是一張 PNG 的理由是
-- **它要能染色**（SetVertexColor 吃職業色），而且尺寸改了不會糊。
------------------------------------------------------------
function Buttons.BuildIcon(btn, size)
    if not btn.dots then
        btn.dots = {}
        for i = 1, 9 do
            btn.dots[i] = btn:CreateTexture(nil, "ARTWORK")
        end
    end
    local d = math.max(1, P.Scale(math.floor(size / 6)))
    local gap = math.max(1, P.Scale(1))
    local span = d * 3 + gap * 2
    local x0 = (size - span) / 2
    for i = 1, 9 do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local t = btn.dots[i]
        t:SetSize(d, d)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", btn, "TOPLEFT", x0 + col * (d + gap), -(x0 + row * (d + gap)))
        t:SetColorTexture(1, 1, 1, 1)
    end
end

function Buttons.TintIcon(btn, alpha)
    if not btn.dots then return end
    local r, g, b = S.Accent()
    for _, t in ipairs(btn.dots) do t:SetVertexColor(r, g, b, alpha) end
end

------------------------------------------------------------
-- 右鍵選單
--
-- 只列入口，不列每顆按鈕的釘選開關 —— 那份清單住在設定頁的「插件按鈕」分頁，
-- 因為它會長到二三十列，而選單超過一螢幕就沒人點得動。
------------------------------------------------------------
local function ShowMenu(anchor)
    local items = {}
    if _G.MiliUI and _G.MiliUI.OpenOptions then
        items[#items + 1] = {
            text = ns.L["MiliUI settings"],
            onClick = function() _G.MiliUI.OpenOptions() end,
        }
        items[#items + 1] = { isSeparator = true }
    end
    items[#items + 1] = {
        text = ns.L["Pin buttons to the map"],
        onClick = function() ns.Options.Open("buttons") end,
    }
    items[#items + 1] = {
        text = ns.L["Minimap settings"],
        onClick = function() ns.Options.Open("map") end,
    }
    W.Menu.Show(items, anchor)
end

------------------------------------------------------------
-- 建框
------------------------------------------------------------
local function Build()
    if bag then return end

    bag = CreateFrame("Frame", "MiliUIMinimapButtonBag", UIParent, "BackdropTemplate")
    bag:SetFrameStrata("HIGH")
    bag:SetClampedToScreen(true)
    bag:Hide()
    -- ⚠ 收納袋用**提示皮**（不透明 0.133），不是 HUD 面板皮（半透明 0.8）。
    --   它是「彈出來給人看內容」的表面，判準跟滑過去的名單同一條
    --   （見 .claude/notes/project-miliui-hud-skin.md）。
    --   半透明的後果實測過：小地圖的地形從面板底下透上來，斜斜一道亮痕橫過整排
    --   圖示，看起來就像每顆圖示都被蓋了一層紗。
    S.ApplyTooltipSkin(bag)
    W.CloseOnEscape(bag)
    bag:SetScript("OnHide", function() W.Menu.Hide() end)
    ns.buttonBag = bag

    -- 常駐排是**透明的**：它貼在地圖邊上，再畫一層底跟框只會多出一個方塊，
    -- 而那些按鈕本來就各自有圖示，看得出來是一排東西。
    pin = CreateFrame("Frame", "MiliUIMinimapPinnedButtons", ns.overlay)
    -- ⚠ 明確設 strata。它掛在 overlay 底下（跟著小地圖走，LOW），但收進來的按鈕
    --   原本多半是 MEDIUM —— 底下那行會把它們統一拉成跟容器一樣，
    --   所以容器自己要先站在一個「在地圖之上」的層，不然釘出來的按鈕會被
    --   地圖上的其他東西壓住。
    pin:SetFrameStrata("MEDIUM")
    pin:Hide()
    ns.pinnedRow = pin

end

------------------------------------------------------------
-- 開關鈕住在**資訊列**（Panel/Bar.lua 的一格），不是這裡。
--
-- 理由是版面：這顆鈕本來擺在地圖上方外側，於是地圖上下各長出一條東西
-- —— 上面一顆孤零零的鈕、下面一條資訊列。收進資訊列之後地圖只有下方一條，
-- 而那條本來就是「地圖旁邊的一排小東西」該待的地方。
--
-- 這裡只負責把「怎麼畫那顆鈕」與「按下去要做什麼」開放出去：
--   Buttons.BuildIcon / Buttons.TintIcon / Buttons.Toggle / Buttons.ShowMenu
------------------------------------------------------------
Buttons.ShowMenu = ShowMenu

-- ⚠ 三格都沒選「插件按鈕」的話袋子就沒有入口了。逃生口是 `/mmap bag`
--   （設定頁那一行說明就是在講這件事）。刻意不做「沒入口就自動長一顆鈕回來」
--   —— 那會讓同一顆鈕有兩個可能的位置，玩家更找不到。

------------------------------------------------------------
-- 套用設定
------------------------------------------------------------
function Buttons.Apply()
    local db = ns.DB.Get()
    if not ns.overlay then return end       -- Skin 還沒建好，SkinApplied 會再叫一次

    if not db.buttonBag then
        -- ⚠ 關掉收納功能只是把**袋子**收起來，已經搬進來的按鈕不會回到地圖上
        --   （frame 搬過去就沒有還原路徑，見檔頭）。要完全交還請 /reload。
        if bag then bag:Hide() end
        if pin then pin:Hide() end
        return
    end

    Build()
    S.RefreshTooltipSkin(bag)
    Buttons.Scan()
end

------------------------------------------------------------
-- 事件
--
-- 插件是陸續載入的，而且不少是 LoadOnDemand（開背包、開拍賣才註冊圖示），
-- 所以掃描不能只做一次。ADDON_LOADED 收斂成一次延後掃描：
-- 登入時那一波有上百個事件，每一個都掃一遍 Minimap 的子框是純浪費。
------------------------------------------------------------
ns.RegisterCallback("SkinApplied", "Buttons", function() ns.Safe(Buttons.Apply) end)
ns.RegisterCallback("ConfigChanged", "Buttons", function() ns.Safe(Buttons.Apply) end)
ns.RegisterCallback("AccentChanged", "Buttons", function()
    if bag then S.RefreshTooltipSkin(bag) end
end)

ns.RegisterCallback("Init", "Buttons", function()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("ADDON_LOADED")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    local pending
    ev:SetScript("OnEvent", function()
        if pending then return end
        pending = true
        C_Timer.After(2, function()
            pending = false
            ns.Safe(Buttons.Scan)
        end)
    end)
end)
