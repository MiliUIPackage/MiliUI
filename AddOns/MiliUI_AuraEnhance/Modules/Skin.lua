------------------------------------------------------------
-- 光環圖示的外觀樣式
--
-- 把暴雪的增益／減益圖示交給外觀樣式引擎畫，玩家就能替光環套用跟快捷列同一款
-- 按鈕樣式。引擎沒裝就整支裝死，不影響其他功能。
--
-- 三個一定要照做的地方，不照做會撞牆：
--
-- 1. **不要把光環按鈕本身交出去。** 那顆按鈕是「圖示 ＋ 底下一行時間文字」的長方形，
--    樣式會被拉成長方形，邊框糊掉。要另外包一層跟圖示等大的方框交出去。
--    ⚠ 那層方框的尺寸要**自己寫死**、錨點掛在按鈕上，不要 SetAllPoints 到暴雪那張
--    圖示——理由見下面 SyncGeometry。
-- 2. **不要讓引擎去畫暴雪那張圖示。** 暴雪每次更新都會重設它的位置，兩邊搶著擺會
--    一直跳。改成自己畫一張同內容的、把原本那張藏起來，位置就穩定了。
-- 3. **層數／減益外框那些區塊要搬進包裝框。** 子框的貼圖永遠蓋過父層的區塊，
--    留在原地會被樣式的邊框蓋住。
------------------------------------------------------------
local _, ns = ...

ns.Skin = {}
local Skin = ns.Skin

-- 武器附魔外框染成紫色。這是套組原本那支光環樣式插件的行為，接手就得照搬，
-- 不然玩家更新完會發現顏色莫名其妙變了。原始貼圖是橘金色，跟增益的邊框太像。
local ENCHANT_BORDER_COLOR = { 0.75, 0, 1 }

-- 這個字串會變成引擎設定裡的群組 ID（ID = 這個 .. "_" .. staticID），
-- **刻意不在地化**：跟著客戶端語言變的話，玩家換個語言就會拿到一組全新的預設樣式。
local GROUP_ADDON = "MiliUI Aura Enhance"

local db                                              -- ns.db.skin
local engine                                          -- false = 沒裝
local groups = {}                                     -- kind → group
local wrappers = setmetatable({}, { __mode = "k" })   -- 光環按鈕 → 包裝框

------------------------------------------------------------
-- 引擎與群組
------------------------------------------------------------
local function Engine()
    if engine ~= nil then return engine end
    engine = (LibStub and LibStub("Masque", true)) or false
    return engine
end

Skin.Engine = Engine

-- 三種按鈕分開成群組，玩家可以只換減益的樣式
local function GroupLabel(kind)
    local L = ns.L
    if kind == "Debuff" then return L["Debuffs"] end
    if kind == "Enchant" then return L["Weapon enchants"] end
    return L["Buffs"]
end

local function Group(kind)
    local lib = Engine()
    if not lib then return nil end
    local g = groups[kind]
    if g then return g end
    -- 第三個參數是固定 ID：顯示名稱在地化，ID 不跟著變
    g = lib:Group(GROUP_ADDON, GroupLabel(kind), kind:lower())
    groups[kind] = g
    return g
end

-- 暫時附魔那幾顆混在增益容器裡，靠它自己的外框認
local function KindOf(btn, isDebuff)
    if btn.TempEnchantBorder then return "Enchant" end
    local t = btn.auraType
    if t == "TempEnchant" then return "Enchant" end
    if t == "Debuff" or t == "DeadlyDebuff" then return "Debuff" end
    if t == "Buff" then return "Buff" end
    return isDebuff and "Debuff" or "Buff"
end

------------------------------------------------------------
-- 包裝框
--
-- ⚠ 一顆按鈕只建一次、之後重複使用：貼圖鏡射是掛 hook 的，重建會愈疊愈多層。
-- 停用時只是還原並隱藏，不丟掉（暴雪的 frame 本來就刪不掉）。
------------------------------------------------------------
-- 圖示在按鈕樣板裡就是 30x30；按鈕縮放走 SetScale，尺寸本身不會變
local ICON_SIZE = 30

------------------------------------------------------------
-- 包裝框的幾何
--
-- ⚠⚠ **不要 SetAllPoints 到暴雪那張圖示上。** 踩過，症狀是畫面上多出一個位置與
-- 大小都不對的方框（樣式的貼圖跟著框走，框歪了就整個歪）。原因是那張圖示的錨點
-- 不是穩定的東西：
--   * 容器每次重排都先 ClearAllPoints 再重下；
--   * 減益容器還多設了「停用中的按鈕不排版」，所以沒在用的那些按鈕，它們的圖示
--     **從頭到尾沒有錨點**。把自己的矩形接上去，等於押在一個隨時不存在的東西上。
--   （只有減益容器有那個設定，所以壞的永遠是減益那排。）
--
-- 改成：尺寸自己寫死，錨點直接掛在按鈕上、每次重排跟著同步一次。最壞情況也只是
-- 一個 30x30 的框跑錯位置，而且它是按鈕的子框，按鈕一藏它就跟著不見。
------------------------------------------------------------
local function SyncGeometry(btn, w)
    local iw, ih = btn.Icon:GetSize()
    if not iw or iw <= 0 then iw = ICON_SIZE end
    if not ih or ih <= 0 then ih = ICON_SIZE end
    w:SetSize(iw, ih)

    -- 圖示錨在按鈕的哪一邊會隨排列方向變（往上長／往下長／直排），照抄它現在那一筆，
    -- 但 relativeTo 一律換成按鈕自己
    local point, rel, relPoint, x, y = btn.Icon:GetPoint(1)
    w:ClearAllPoints()
    if point and rel == btn then
        w:SetPoint(point, btn, relPoint, x or 0, y or 0)
    else
        w:SetPoint("TOP", btn, "TOP")
    end
end

local function EnsureWrapper(btn, kind)
    local w = wrappers[btn]
    if w then return w end
    if not (btn.Icon and btn.Icon.GetTexture) then return nil end

    w = CreateFrame("Frame", nil, btn)
    w.kind = kind
    SyncGeometry(btn, w)

    local icon = w:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints(w)
    icon:SetTexture(btn.Icon:GetTexture())
    -- 這個 hook 每次光環更新都會跑，順手把原圖示再壓一次：
    -- 按鈕是回收再用的，暴雪重新指派時會把它叫回來，兩張圖示疊在一起很明顯。
    hooksecurefunc(btn.Icon, "SetTexture", function(self, tex)
        icon:SetTexture(tex)
        if w.attached and self:IsShown() then self:Hide() end
    end)
    w.icon = icon

    wrappers[btn] = w
    btn.MiliUIAura_Skin = w
    return w
end

-- 借過來畫在包裝框上的區塊。停用時要一個一個還回去，
-- 不然它們會跟著隱藏的包裝框一起消失。
local function MoveRegions(btn, parent)
    if btn.Count then btn.Count:SetParent(parent) end
    if btn.DebuffBorder then btn.DebuffBorder:SetParent(parent) end
    if btn.TempEnchantBorder then btn.TempEnchantBorder:SetParent(parent) end
    if btn.Symbol then btn.Symbol:SetParent(parent) end
end

local function Attach(btn, isDebuff)
    local kind = KindOf(btn, isDebuff)
    local group = Group(kind)
    if not group then return end

    local w = EnsureWrapper(btn, kind)
    if not w then return end

    -- 暴雪每次重排都會重新錨圖示，所以每次都跟著同步一次（見 SyncGeometry）
    SyncGeometry(btn, w)

    -- 按鈕是回收再用的：同一顆這次是減益、下次可能是暫時附魔。種類換了要重掛到
    -- 對應的群組（AddButton 會自己把它從舊群組移走），沒換就什麼都不用做。
    if w.attached and w.kind == kind then return end
    w.kind = kind

    btn.Icon:Hide()
    MoveRegions(btn, w)

    local eb = btn.TempEnchantBorder
    if eb then
        -- 原本的顏色記一份，停用時還得回去
        if not w.enchantColor then w.enchantColor = { eb:GetVertexColor() } end
        eb:SetVertexColor(ENCHANT_BORDER_COLOR[1], ENCHANT_BORDER_COLOR[2], ENCHANT_BORDER_COLOR[3])
    end

    w:Show()
    w.attached = true

    -- 交出去的是包裝框（Frame 而不是 Button），引擎因此只會動我們列出來的區塊，
    -- 不會自己去按鈕上翻別的東西
    group:AddButton(w, {
        Icon         = w.icon,
        Count        = btn.Count,
        DebuffBorder = btn.DebuffBorder,
        EnchantBorder = btn.TempEnchantBorder,
    }, kind)
end

local function Detach(btn)
    local w = wrappers[btn]
    if not w or not w.attached then return end

    local group = groups[w.kind]
    if group then group:RemoveButton(w) end

    MoveRegions(btn, btn)

    local eb, ec = btn.TempEnchantBorder, w.enchantColor
    if eb and ec then eb:SetVertexColor(ec[1] or 1, ec[2] or 1, ec[3] or 1, ec[4]) end

    w:Hide()
    w.attached = false
    if btn.Icon then btn.Icon:Show() end
end

------------------------------------------------------------
-- 對外
------------------------------------------------------------
-- 逐顆處理（AuraStyle 掃到按鈕時順手叫）
function Skin.OnButton(btn, isDebuff)
    if not db then return end
    if db.enabled then
        Attach(btn, isDebuff)
    else
        Detach(btn)
    end
end

-- 設定改完重跑一遍
function Skin.Apply()
    if not db or not ns.AuraStyle then return end
    ns.AuraStyle.ForEach(Skin.OnButton)
end

-- 有沒有東西可以套（設定頁要據此決定顯示什麼）
function Skin.IsAvailable()
    return Engine() and true or false
end

-- 開啟引擎自己的設定介面。它沒有公開的開窗 API，只有斜線指令。
function Skin.OpenEngineOptions()
    local handler = SlashCmdList and SlashCmdList["MASQUE"]
    if handler then handler("") end
end

ns.RegisterCallback("Init", "skin", function()
    db = ns.db.skin

    -- 三個群組先建起來，不要等「第一次遇到那種光環」才建。兩個理由：
    -- 1. 玩家要先在引擎的清單裡看得到它，才有得挑樣式；武器附魔那組尤其
    --    ——身上沒附魔的話它永遠不會出現。
    -- 2. 子群組**只在建立的那一刻**從母群組抄一次設定（抄完就各走各的）。
    --    三組同時建，拿到的起點才一致；分批建的話晚建的那組會抄到不同時間點
    --    的母群組設定。
    if Engine() then
        Group("Buff")
        Group("Debuff")
        Group("Enchant")
    end
end)
