------------------------------------------------------------
-- 修裝：滑過耐久方塊彈出來的面板
--
-- 皮、開關節奏、定位、列層與所有版面常數都在 Core/HoverPanel.lua，這支只負責
-- 「這張面板有哪些列」＋那排 secure 圖示按鈕。
--
-- ⚠⚠ 這張面板跟另外兩張有一個**根本差別**：它裡面有 SecureActionButtonTemplate
--   的按鈕（道具與玩具只能由 secure 按鈕的硬體點擊觸發），所以整張面板是
--   **隱式保護框** —— 戰鬥中 Show/Hide/SetPoint 全部會被封鎖。開面板時
--   `secure = true`，控制器就會改用 state driver 收面板、每個入口先問
--   InCombatLockdown、OnHide 的收尾延一幀（理由寫在 HoverPanel.lua 的檔頭）。
--
-- ⚠⚠ secure 按鈕上**絕對不掛** PreClick／OnMouseDown／OnMouseUp／OnClick 的 Lua：
--   那些處理器跟 secure 動作在同一次點擊派送裡，執行流程會整條被染成資訊列的
--   （Core/Bar.lua 的 CreateTile 有完整說明，2026-09-07 taint.log 實測）。
--   OnEnter／OnLeave 不在點擊派送裡，可以掛。控制器與列層都碰不到這幾顆按鈕
--   ——它們由這支自己建、自己池化，擺在列層的 custom 項目裡。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local P = ns.P
local HP = ns.HoverPanel
local Repair = ns.Repair
local AR = ns.AutoRepair

ns.RepairPopup = {}
local Popup = ns.RepairPopup

local WHITE = "Interface\\Buttons\\WHITE8X8"

------------------------------------------------------------
-- 這張面板私有的東西：只有那排圖示按鈕
--
-- 按鈕刻意比列高再大一點，一排圖示才不會看起來像壓扁的文字列。
-- 邊長的基準仍然來自共用的列高——列高調整時這排會跟著走。
------------------------------------------------------------
local ICON_BTN  = HP.ROW_H + 6
local ICON_GAP  = 4
local EDGE_IDLE = 0.30       -- 閒置的 1px 邊（HUD 皮：狀態只換明暗）

local panel                  -- 檔尾建立
local pools = { item = {}, toy = {}, mount = {} }
local used  = { item = 0, toy = 0, mount = 0 }

------------------------------------------------------------
-- 圖示按鈕（每個 kind 一個池）
--
-- 道具與玩具是 SecureActionButtonTemplate，坐騎是普通 Button
-- （C_MountJournal.SummonByID 從插件 Lua 直呼合法，見 Core/Mounts.lua）。
------------------------------------------------------------
local function TooltipAnchor()
    -- 提示錨在**面板**上下而不是按鈕上下：錨在按鈕會直接蓋住面板上半的耐久列表，
    -- 而 GameTooltip 在 TOOLTIP strata、壓得過任何自訂面板
    -- （.claude/notes/project-miliui-hud-skin.md 最後那條）
    local _, cy = panel.frame:GetCenter()
    return (cy and cy > UIParent:GetHeight() / 2) and "ANCHOR_BOTTOM" or "ANCHOR_TOP"
end

local function ButtonEnter(self)
    Popup.CancelClose()
    for _, e in ipairs(self.edges) do e:SetVertexColor(W.Accent(1)) end
    if not self.entryID then return end
    GameTooltip:SetOwner(panel.frame, TooltipAnchor())
    if self.entryKind == "toy" then
        GameTooltip:SetToyByItemID(self.entryID)
    elseif self.entryKind == "mount" then
        GameTooltip:SetMountBySpellID(self.entryID)
    else
        GameTooltip:SetItemByID(self.entryID)
    end
    GameTooltip:Show()
end

local function ButtonLeave(self)
    for _, e in ipairs(self.edges) do e:SetVertexColor(EDGE_IDLE, EDGE_IDLE, EDGE_IDLE, 1) end
    GameTooltip:Hide()
    Popup.ScheduleClose()
end

local function MountClick(self)
    if not self.entryID then return end
    Popup.Hide()
    ns.Mounts.Summon(self.entryID)
end

local function GetButton(kind, index)
    local pool = pools[kind]
    local btn = pool[index]
    if btn then return btn end

    if kind == "mount" then
        btn = CreateFrame("Button", nil, panel.frame)
        btn:SetScript("OnClick", MountClick)
    else
        btn = CreateFrame("Button", nil, panel.frame, "SecureActionButtonTemplate")
        -- useOnKeyDown=false —— 沒有這行，ActionButtonUseKeyDown 這個 CVar 會讓
        -- secure handler 只認 key-down，把我們的 AnyUp 點擊整個丟掉
        -- （Core/MicroMenu.lua 踩過同一個）
        btn:SetAttribute("useOnKeyDown", false)
    end
    btn:RegisterForClicks("AnyUp")
    btn:SetSize(ICON_BTN, ICON_BTN)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(WHITE)
    bg:SetVertexColor(0, 0, 0, 0.45)

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", 1, -1)
    btn.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    -- 圖示邊緣那圈留白裁掉，方形圖示才貼得住 1px 的視覺語彙（同列層的圖示欄）
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- 1px 邊：閒置灰、滑過職業色（HUD 皮：狀態只換明暗，身分色在邊上）
    local edges = {}
    for i = 1, 4 do
        local e = btn:CreateTexture(nil, "OVERLAY")
        e:SetTexture(WHITE)
        edges[i] = e
    end
    edges[1]:SetPoint("TOPLEFT");    edges[1]:SetPoint("TOPRIGHT")
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT")
    edges[3]:SetPoint("TOPLEFT");    edges[3]:SetPoint("BOTTOMLEFT")
    edges[4]:SetPoint("TOPRIGHT");   edges[4]:SetPoint("BOTTOMRIGHT")
    local px = P.Scale(1)
    edges[1]:SetHeight(px); edges[2]:SetHeight(px)
    edges[3]:SetWidth(px);  edges[4]:SetWidth(px)
    for _, e in ipairs(edges) do e:SetVertexColor(EDGE_IDLE, EDGE_IDLE, EDGE_IDLE, 1) end
    btn.edges = edges

    -- 冷卻扇形是 insecure 的子框，戰鬥中更新它是合法的
    btn.cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cd:SetAllPoints(btn.icon)
    btn.cd:SetDrawEdge(false)

    btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    btn.count:SetPoint("BOTTOMRIGHT", -2, 2)

    btn:SetHighlightTexture(WHITE)
    btn:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.12)

    -- ⚠ 只有 OnEnter／OnLeave。OnClick 這條路上一行我們的 Lua 都不能有（見檔頭）
    btn:SetScript("OnEnter", ButtonEnter)
    btn:SetScript("OnLeave", ButtonLeave)

    pool[index] = btn
    return btn
end

-- secure 屬性**值沒變就不重寫**：SetAttribute 是會被戰鬥封鎖的動作，而且每寫一次
-- 都是一次 restricted 環境的往返，重畫很頻繁（包包一動就重畫）
local function ApplySecureAction(btn, kind, id)
    local atype = (kind == "toy") and "toy" or "item"
    -- 道具用 "item:ID" 而不是包包格：格子空了之後屬性會指向一個不存在的東西，
    -- 而同一疊的另一落還在包包裡卻按不出來
    local ref = (kind == "toy") and id or ("item:" .. id)
    if btn._atype ~= atype then
        btn:SetAttribute("*type1", atype)
        btn._atype = atype
    end
    local key = (kind == "toy") and "*toy1" or "*item1"
    if btn._ref ~= ref then
        btn:SetAttribute(key, ref)
        btn._ref = ref
    end
end

-- 直接用 Cooldown 的 setter，不走 CooldownFrame_Set：那支是暴雪的 Lua 包裝，
-- 簽章（尤其 enable 是 bool 還是 number）改過不只一次
local function SetButtonCooldown(cd, start, duration, enable)
    if start and duration and duration > 0 and enable and enable ~= 0 then
        cd:SetCooldown(start, duration)
        cd:Show()
    else
        cd:Clear()
        cd:Hide()
    end
end

local function FillButton(btn, entry)
    btn.entryKind = entry.kind
    btn.entryID   = entry.id
    btn.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

    -- 不可用：去飽和＋變暗，但**仍然可點** —— 讓遊戲自己講原因，比我們猜錯好
    if entry.usable then
        btn.icon:SetDesaturated(false)
        btn.icon:SetAlpha(1)
    else
        btn.icon:SetDesaturated(true)
        btn.icon:SetAlpha(0.5)
    end

    if entry.kind == "item" and (entry.count or 0) > 1 then
        btn.count:SetText(entry.count)
        btn.count:Show()
    else
        btn.count:Hide()
    end

    SetButtonCooldown(btn.cd, Repair.Cooldown(entry.kind, entry.id))

    if entry.kind ~= "mount" then ApplySecureAction(btn, entry.kind, entry.id) end
end

------------------------------------------------------------
-- 一個分類的圖示排＝列層的一個 custom 項目
--
-- 第一趟 measure 回「整排放同一行要多寬」（夾在 MAX_W：再寬就是一塊擋畫面的板子，
-- 塞不下的換行就好）；第二趟 layout 拿到最終寬度才算得出一行放得下幾顆。
-- 上下各留 G：文字列的字垂直置中、離髮絲線天生有幾 px，圖示按鈕是實心方塊，
-- 不留的話會直接貼在線上。
------------------------------------------------------------
local function IconSection(kind, list)
    local n = #list
    return {
        kind = "custom",
        measure = function()
            local need = HP.PAD_X * 2 + n * ICON_BTN + (n - 1) * ICON_GAP
            return math.min(need, HP.MAX_W)
        end,
        layout = function(frame, y, width)
            local perRow = math.max(1,
                math.floor((width - HP.PAD_X * 2 + ICON_GAP) / (ICON_BTN + ICON_GAP)))
            local lines = math.ceil(n / perRow)
            local top = y + HP.G
            for i, entry in ipairs(list) do
                used[kind] = used[kind] + 1
                local btn = GetButton(kind, used[kind])
                FillButton(btn, entry)
                local col = (i - 1) % perRow
                local line = math.floor((i - 1) / perRow)
                btn:ClearAllPoints()
                -- +1 ＝ 讓出邊框那一格。文字列是錨在 frame 內縮 1px 的位置再加 PAD_X，
                -- 圖示少算這 1px 的話整排會比上面的字往左一格
                btn:SetPoint("TOPLEFT", frame, "TOPLEFT",
                    1 + HP.PAD_X + col * (ICON_BTN + ICON_GAP),
                    -(top + line * (ICON_BTN + ICON_GAP)))
                btn:Show()
            end
            return HP.G + lines * ICON_BTN + (lines - 1) * ICON_GAP + HP.G
        end,
    }
end

------------------------------------------------------------
-- 內容
------------------------------------------------------------
local function BuildModel()
    local model = {}

    -- 自動修裝排最上面：它是這張面板裡唯一「會自己發生」的東西，其餘都是
    -- 讀數與按鈕。開關型項目按下去**原地重畫**（同 Core/ReadyCheckPopup.lua 的
    -- 標記工具列），不關面板——按一下就要重新滑過來才看得到打勾是很煩的。
    --
    -- ⚠ 這是 secure 面板，但 onClick 跑在列層那顆普通 Button 上、不在 secure
    --   按鈕的點擊派送裡，寫 db ＋ Refresh 都合法；戰鬥中 Refresh 本來就被
    --   控制器的 Locked 擋掉，不必另外加閘。
    model[#model + 1] = { kind = "title", text = L["SECTION_AUTO_REPAIR"] }
    model[#model + 1] = {
        kind    = "item",
        check   = AR.IsEnabled(),
        text    = L["MENU_AUTO_REPAIR"],
        onClick = function()
            AR.SetEnabled(not AR.IsEnabled())
            panel:Refresh()
        end,
    }
    model[#model + 1] = {
        kind    = "item",
        check   = AR.IsGuild(),
        text    = L["MENU_GUILD_REPAIR"],
        onClick = function()
            AR.SetGuild(not AR.IsGuild())
            panel:Refresh()
        end,
    }
    -- 撞車警告只在真的會撞的時候出現（Leatrix 沒裝／沒開就不佔位置）
    if AR.IsEnabled() and AR.LeatrixConflict() then
        model[#model + 1] = { kind = "note", text = L["MENU_LEATRIX_CONFLICT"] }
    end

    -- ⚠ 小節之間**不放 sep**：標題自己底下就有一條髮絲線、前面也有留白，再補一條
    --   收尾線就變成兩條線夾一行灰字，像多了一個框（坐騎面板的小節也是這樣接的）。
    --   sep 只留給最底下的說明與設定入口——那兩段沒有標題。
    model[#model + 1] = { kind = "title", text = L["BLOCK_DURABILITY"] }

    local any = false
    for _, slot in ipairs(Repair.SLOTS) do
        local pct = Repair.SlotDurability(slot[1])
        if pct then
            any = true
            model[#model + 1] = {
                kind     = "item",
                text     = slot[2],
                tag      = string.format("%d%%", math.floor(pct)),
                -- 百分比是這張面板唯一「顏色帶資訊」的地方（快爆了要看得出來），
                -- 所以它不用右側標預設的灰
                tagColor = { Repair.DurabilityColor(pct) },
            }
        end
    end
    if not any then
        model[#model + 1] = { kind = "note", text = L["DURABILITY_NONE"] }
    end

    -- 三個分類：只畫有至少一筆「擁有且未隱藏」的
    local entries = Repair.Entries()
    for _, kind in ipairs(Repair.CATEGORIES) do
        local list = Repair.VisibleIn(entries[kind])
        if #list > 0 then
            model[#model + 1] = { kind = "title", text = L["REPAIR_CAT_" .. kind:upper()] }
            model[#model + 1] = IconSection(kind, list)
        end
    end

    -- 按鍵說明：一行一條，不用「|」串成一長條
    model[#model + 1] = { kind = "sep" }
    model[#model + 1] = { kind = "note", text = L["HINT_LEFT_CHARACTER"] }
    model[#model + 1] = { kind = "note", text = L["HINT_RIGHT_REPAIR"] }
    -- Shift 那條只在自動修裝開著時才成立：關著的時候沒有「那一次」可以略過
    if AR.IsEnabled() then
        model[#model + 1] = { kind = "note", text = L["HINT_SHIFT_SKIP"] }
    end

    -- 設定入口永遠在最底下
    model[#model + 1] = { kind = "sep" }
    model[#model + 1] = { kind = "settings", text = L["REPAIR_POPUP_SETTINGS"], tab = "repair" }

    return model
end

------------------------------------------------------------
-- 面板
------------------------------------------------------------
panel = HP.New({
    name   = "MiliUIInfoBar_RepairPopup",
    secure = true,
    populate = function(rows)
        -- 按鈕的用量每次重畫從頭算；沒用到的收起來（池子不銷毀，frame 刪不掉）
        used.item, used.toy, used.mount = 0, 0, 0
        rows:Render(BuildModel())
        for kind, pool in pairs(pools) do
            for i = used[kind] + 1, #pool do pool[i]:Hide() end
        end
    end,
    onOpen = function()
        Repair.Watch("popup", true)
        Repair.AddListener("popup", function() panel:Refresh() end)
    end,
    onHide = function()
        GameTooltip:Hide()
        Repair.RemoveListener("popup")
        Repair.Watch("popup", false)
    end,
})

------------------------------------------------------------
-- 對外（名字保留給 Core/Blocks.lua）
------------------------------------------------------------
function Popup.CancelClose()   panel:CancelClose() end
function Popup.CancelOpen()    panel:CancelOpen() end
function Popup.Hide()          panel:Hide() end
function Popup.ScheduleClose() panel:ScheduleClose() end
function Popup.Open(tile)         panel:Open(tile) end
function Popup.ScheduleOpen(tile) panel:ScheduleOpen(tile) end
function Popup.IsOpenFor(tile)    return panel:IsOpenFor(tile) end
