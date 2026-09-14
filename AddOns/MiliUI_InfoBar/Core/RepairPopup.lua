------------------------------------------------------------
-- 修裝：滑過耐久方塊彈出來的面板
--
-- 皮走「提示皮」（.claude/notes/project-miliui-hud-skin.md 的第二種變體）：
-- 0.133 不透明底 ＋ 1px 職業色硬邊 ＋ 白字 ＋ 直角。開關的節奏（滑過開／排程關／
-- 世代 token／先翻面再平移）整套照 Core/MountPopup.lua，那邊的註解不重抄。
--
-- ⚠⚠ 這張面板跟坐騎面板有一個**根本差別**：它裡面有 SecureActionButtonTemplate
--   的按鈕（道具與玩具只能由 secure 按鈕的硬體點擊觸發），所以整張面板是
--   **隱式保護框** —— 戰鬥中 Show/Hide/SetPoint 全部會被封鎖。
--
--   收面板不能靠 ns.Events 的 PLAYER_REGEN_DISABLED（那是延一幀派送，輪到我們
--   的時候已經鎖上了，Hide 當場被擋）。正解是讓 secure 環境自己收：
--   SecureHandlerStateTemplate ＋ RegisterStateDriver("[combat] 1; 0") ＋
--   `_onstate-combat` snippet 裡 self:Hide()。snippet 跑在引擎那一側，不受封鎖。
--
--   同理，Lua 這邊每一個會動到框的入口都要先問 InCombatLockdown()。
--
-- ⚠ 掛 UIParent、不掛 bar（bar 也是保護框，掛底下等於多一層限制）。
--
-- ⚠⚠ secure 按鈕上**絕對不掛** PreClick／OnMouseDown／OnMouseUp／OnClick 的 Lua：
--   那些處理器跟 secure 動作在同一次點擊派送裡，執行流程會整條被染成資訊列的
--   （Core/Bar.lua 的 CreateTile 有完整說明，2026-09-07 taint.log 實測）。
--   OnEnter／OnLeave 不在點擊派送裡，可以掛。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local P = ns.P
local Repair = ns.Repair

ns.RepairPopup = {}
local Popup = ns.RepairPopup

local WHITE = "Interface\\Buttons\\WHITE8X8"

------------------------------------------------------------
-- 版面常數
--
-- 這張面板是「一排數字 ＋ 幾顆圖示」，不是坐騎面板那種一列一隻的清單，
-- 所以列高比它矮一階（22 對 28）。圖示按鈕刻意比列高再大一點（ROW_H + 6），
-- 一排圖示才不會看起來像壓扁的文字列。
------------------------------------------------------------
local TIP_BG      = 0.133
local ROW_H       = 22
local TITLE_H     = 24
local SEP_H       = 8
local PAD         = 10
local TAG_GAP     = 16       -- 部位名與百分比之間的最小間距
local ICON_BTN    = ROW_H + 6
local ICON_GAP    = 4
-- 圖示排與分類標題髮絲線之間要留呼吸：文字列的字是垂直置中、離線天生有 3px，
-- 圖示按鈕是實心方塊，不留的話會直接貼在線上（實測截圖就是這樣）
local ICON_TOP    = 6
local CAT_GAP     = 6        -- 圖示排結束到下一段之間
local MIN_W       = 200
local MAX_W       = 380      -- 再寬就變成一塊擋畫面的板子了；超過就換行
local CLOSE_DELAY = 0.35
local OPEN_DELAY  = 0.15

-- 字級相對 db.fontSize。內容比條上大一級，標題仍然比內容小一級（標題要退後）。
-- ⚠ 相對值只寫在這裡，Populate 裡不要再出現任何字級數字。
local SZ_TEXT  = 1
local SZ_TITLE = 0
local SZ_HINT  = 0

local TEXT_MAIN = { 0.92, 0.92, 0.92 }
local TEXT_DIM  = { 0.58, 0.58, 0.58 }
local EDGE_IDLE = 0.30       -- 圖示按鈕閒置的 1px 邊（HUD 皮：狀態只換明暗）

local frame
local rows = {}
local settingsRow           -- 最底下那列「設定修裝按鈕…」，只有一顆所以不進池
local pools = { item = {}, toy = {}, mount = {} }
local anchorTile
local closeGen = 0
local openGen = 0

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function FontSize()
    return ns.GetDB().fontSize or 12
end

local function MakeText(parent, delta)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(ns.LOCALE_FONT, FontSize() + (delta or 0), "")
    fs:SetWordWrap(false)
    fs.sizeDelta = delta or 0
    return fs
end

local function ApplyTipSkin(f)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = P.Scale(1) })
    f:SetBackdropColor(TIP_BG, TIP_BG, TIP_BG, 1)
    f:SetBackdropBorderColor(W.Accent(1))
end

------------------------------------------------------------
-- 開關（排程 ＋ 世代 token，同 Core/MountPopup.lua）
--
-- ⚠ 每一個 Hide 都要過 InCombatLockdown：戰鬥中 state driver 已經把它收掉了，
--   這裡再叫一次只會換來一則 ADDON_ACTION_BLOCKED。
------------------------------------------------------------
function Popup.CancelClose()
    closeGen = closeGen + 1
end

function Popup.CancelOpen()
    openGen = openGen + 1
end

function Popup.Hide()
    Popup.CancelClose()
    if frame and frame:IsShown() and not InCombatLockdown() then frame:Hide() end
end

function Popup.ScheduleClose()
    closeGen = closeGen + 1
    local gen = closeGen
    C_Timer.After(CLOSE_DELAY, function()
        if gen ~= closeGen then return end                  -- 已被新的動作取代
        if not (frame and frame:IsShown()) then return end
        if InCombatLockdown() then return end
        -- 判斷放在**到期時**：游標中途繞進面板（或繞回方塊）也算數
        if frame:IsMouseOver() then return end
        if anchorTile and anchorTile:IsMouseOver() then return end
        frame:Hide()
    end)
end

function Popup.IsOpenFor(tile)
    return frame and frame:IsShown() and anchorTile == tile
end

------------------------------------------------------------
-- 文字列（池化：frame 刪不掉，一律重用）
--
-- 純顯示，不吃滑鼠 —— 面板本身的 OnEnter/OnLeave 就夠了，列再攔一次
-- 只會多一個會漏掉的路徑（子框搶走滑鼠焦點的老問題）。
------------------------------------------------------------
local function GetRow(index)
    local row = rows[index]
    if row then return row end

    row = CreateFrame("Frame", nil, frame)
    row:EnableMouse(false)

    row.text = MakeText(row, SZ_TEXT)
    row.text:SetPoint("LEFT", row, "LEFT", PAD, 0)
    row.text:SetJustifyH("LEFT")

    row.value = MakeText(row, SZ_TEXT)
    row.value:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
    row.value:SetJustifyH("RIGHT")

    -- 標題底下的髮絲線：標題與內容之間要一條**結構性**的分隔（同坐騎面板）
    row.rule = row:CreateTexture(nil, "ARTWORK")
    row.rule:SetHeight(1)
    row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", PAD, 0)
    row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -PAD, 0)
    row.rule:SetColorTexture(1, 1, 1, 0.10)

    row.sep = row:CreateTexture(nil, "ARTWORK")
    row.sep:SetHeight(1)
    row.sep:SetPoint("LEFT", row, "LEFT", PAD, 0)
    row.sep:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
    row.sep:SetColorTexture(1, 1, 1, 0.12)

    rows[index] = row
    return row
end

local function ApplyRowFont(row, delta)
    local size = FontSize()
    row.text:SetFont(ns.LOCALE_FONT, size + delta, "")
    row.value:SetFont(ns.LOCALE_FONT, size + delta, "")
end

------------------------------------------------------------
-- 設定入口列（同 Core/MountPopup.lua 的 settings 列：灰字、整列可點、
-- 滑過職業色底＋白字）。永遠在最底下——「按鈕要顯示哪些在哪裡改」是
-- 玩家第一天就會問的問題，用一行可點的列回答，不用一行讀完還要自己去找的提示。
------------------------------------------------------------
local function GetSettingsRow()
    if settingsRow then return settingsRow end
    local row = CreateFrame("Button", nil, frame)
    row:RegisterForClicks("AnyUp")

    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(W.Accent())
    row.hl:SetAlpha(0.25)
    row.hl:Hide()

    row.text = MakeText(row, SZ_TEXT)
    row.text:SetPoint("LEFT", row, "LEFT", PAD, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])

    row:SetScript("OnEnter", function(self)
        Popup.CancelClose()
        self.hl:Show()
        self.text:SetTextColor(1, 1, 1)
    end)
    row:SetScript("OnLeave", function(self)
        self.hl:Hide()
        self.text:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
        Popup.ScheduleClose()
    end)
    row:SetScript("OnClick", function()
        Popup.Hide()
        ns.OpenSettings("repair")
    end)

    settingsRow = row
    return row
end

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
    local _, cy = frame:GetCenter()
    return (cy and cy > UIParent:GetHeight() / 2) and "ANCHOR_BOTTOM" or "ANCHOR_TOP"
end

local function ButtonEnter(self)
    Popup.CancelClose()
    for _, e in ipairs(self.edges) do e:SetVertexColor(W.Accent(1)) end
    if not self.entryID then return end
    GameTooltip:SetOwner(frame, TooltipAnchor())
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
        btn = CreateFrame("Button", nil, frame)
        btn:SetScript("OnClick", MountClick)
    else
        btn = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
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
    -- 圖示邊緣那圈留白裁掉，方形圖示才貼得住 1px 的視覺語彙（同坐騎方塊）
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
    -- （同 MiliUI_BurstPotionHelper 的藥水按鈕）
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
    -- 而同一疊的另一落還在包包裡卻按不出來（MiliUI_BurstPotionHelper 實測過）
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
-- 內容
------------------------------------------------------------
local function BuildModel()
    local model = {}

    model[#model + 1] = { kind = "title", text = L["BLOCK_DURABILITY"] }

    local any = false
    for _, slot in ipairs(Repair.SLOTS) do
        local pct = Repair.SlotDurability(slot[1])
        if pct then
            any = true
            model[#model + 1] = {
                kind  = "slot",
                text  = slot[2],
                value = string.format("%d%%", math.floor(pct)),
                pct   = pct,
            }
        end
    end
    if not any then
        model[#model + 1] = { kind = "note", text = L["DURABILITY_NONE"] }
    end

    -- 三個分類：只畫有至少一筆「擁有且未隱藏」的。
    -- 分類與分類之間的空隙由**前一段圖示的尾巴**留（見 Populate 第二趟），
    -- 標題自己不帶 gap —— 兩邊都留就會變成雙倍間距。
    local entries = Repair.Entries()
    local anyCat = false
    for _, kind in ipairs(Repair.CATEGORIES) do
        local list = Repair.VisibleIn(entries[kind])
        if #list > 0 then
            if not anyCat then model[#model + 1] = { kind = "sep" } end
            anyCat = true
            model[#model + 1] = { kind = "title", text = L["REPAIR_CAT_" .. kind:upper()] }
            model[#model + 1] = { kind = "icons", iconKind = kind, list = list }
        end
    end

    -- 按鍵說明：一行一條，不用「|」串成一長條
    model[#model + 1] = { kind = "sep" }
    model[#model + 1] = { kind = "hint", text = L["HINT_LEFT_CHARACTER"] }
    if Repair.MerchantAPI() then
        model[#model + 1] = { kind = "hint", text = L["HINT_RIGHT_REPAIR"] }
        model[#model + 1] = { kind = "hint", text = L["HINT_SHIFT_SKIP"] }
    end

    -- 設定入口永遠在最底下（同坐騎面板）
    model[#model + 1] = { kind = "sep" }
    model[#model + 1] = { kind = "settings", text = L["REPAIR_POPUP_SETTINGS"] }

    return model
end

-- 一個分類的圖示要幾排、多高
local function IconRows(count, perRow)
    local lines = math.ceil(count / perRow)
    return lines, lines * ICON_BTN + (lines - 1) * ICON_GAP
end

local function Populate()
    -- 重畫會寫 secure 屬性，戰鬥中一律不跑（面板那時本來就已經被收掉了）
    if InCombatLockdown() then return end

    local model = BuildModel()
    local width = MIN_W
    local rowN = 0

    ------------------------------------------------------------
    -- 第一趟：填文字、量寬
    --
    -- 圖示的排法要先知道面板多寬才算得出來，所以分兩趟。
    ------------------------------------------------------------
    for _, item in ipairs(model) do
        if item.kind == "icons" then
            -- 「整排放在同一行」要多寬。夾在 MAX_W：再寬就是一塊擋畫面的板子，
            -- 塞不下的換行就好
            local n = #item.list
            local need = PAD * 2 + n * ICON_BTN + (n - 1) * ICON_GAP
            if need > MAX_W then need = MAX_W end
            if need > width then width = need end
        elseif item.kind == "settings" then
            local row = GetSettingsRow()
            item.h = ROW_H
            row.text:SetFont(ns.LOCALE_FONT, FontSize() + SZ_TEXT, "")
            row.text:SetText(item.text)
            local need = PAD + row.text:GetStringWidth() + PAD
            if need > width then width = math.ceil(need) end
        else
            rowN = rowN + 1
            local row = GetRow(rowN)
            item.row = row
            row.rule:Hide()
            row.sep:Hide()
            row.value:Hide()
            row.value:SetText("")
            row.text:Show()

            if item.kind == "sep" then
                item.h = SEP_H
                row.text:Hide()
                row.sep:Show()

            elseif item.kind == "title" then
                item.h = TITLE_H
                ApplyRowFont(row, SZ_TITLE)
                row.text:SetText(item.text)
                row.text:SetTextColor(TEXT_DIM[1], TEXT_DIM[2], TEXT_DIM[3])
                row.rule:Show()
                local need = PAD + row.text:GetStringWidth() + PAD
                if need > width then width = math.ceil(need) end

            elseif item.kind == "slot" then
                item.h = ROW_H
                ApplyRowFont(row, SZ_TEXT)
                row.text:SetText(item.text)
                row.text:SetTextColor(0.7, 0.7, 0.7)
                row.value:SetText(item.value)
                row.value:SetTextColor(Repair.DurabilityColor(item.pct))
                row.value:Show()
                local need = PAD + row.text:GetStringWidth() + TAG_GAP
                    + row.value:GetStringWidth() + PAD
                if need > width then width = math.ceil(need) end

            else   -- note / hint
                item.h = ROW_H
                ApplyRowFont(row, item.kind == "hint" and SZ_HINT or SZ_TEXT)
                row.text:SetText(item.text)
                if item.kind == "hint" then
                    row.text:SetTextColor(0.5, 0.5, 0.5)
                else
                    row.text:SetTextColor(TEXT_MAIN[1], TEXT_MAIN[2], TEXT_MAIN[3])
                end
                local need = PAD + row.text:GetStringWidth() + PAD
                if need > width then width = math.ceil(need) end
            end
        end
    end

    ------------------------------------------------------------
    -- 第二趟：定位
    ------------------------------------------------------------
    local perRow = math.max(1,
        math.floor((width - PAD * 2 + ICON_GAP) / (ICON_BTN + ICON_GAP)))
    local used = { item = 0, toy = 0, mount = 0 }
    local y = PAD

    for _, item in ipairs(model) do
        if item.kind == "settings" then
            local row = GetSettingsRow()
            row:SetHeight(item.h)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -y)
            row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -y)
            row:Show()
            y = y + item.h
        elseif item.kind == "icons" then
            y = y + ICON_TOP
            local _, h = IconRows(#item.list, perRow)
            for i, entry in ipairs(item.list) do
                used[item.iconKind] = used[item.iconKind] + 1
                local btn = GetButton(item.iconKind, used[item.iconKind])
                FillButton(btn, entry)
                local col = (i - 1) % perRow
                local line = math.floor((i - 1) / perRow)
                btn:ClearAllPoints()
                -- +1 ＝ 讓出邊框那一格。文字列是錨在 frame 內縮 1px 的位置再加 PAD，
                -- 圖示少算這 1px 的話整排會比上面的字往左一格
                btn:SetPoint("TOPLEFT", frame, "TOPLEFT",
                    1 + PAD + col * (ICON_BTN + ICON_GAP),
                    -(y + line * (ICON_BTN + ICON_GAP)))
                btn:Show()
            end
            y = y + h + CAT_GAP
        else
            local row = item.row
            row:SetHeight(item.h)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -y)
            row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -y)
            row:Show()
            y = y + item.h
        end
    end

    for i = rowN + 1, #rows do rows[i]:Hide() end
    for kind, pool in pairs(pools) do
        for i = used[kind] + 1, #pool do pool[i]:Hide() end
    end

    -- +2 ＝ 列左右各內縮 1px 讓出邊框的那兩格
    frame:SetSize(width + 2, y + PAD)
end

------------------------------------------------------------
-- 建框
------------------------------------------------------------
local function Build()
    if frame then return frame end
    frame = CreateFrame("Frame", "MiliUIInfoBar_RepairPopup", UIParent,
        "SecureHandlerStateTemplate,BackdropTemplate")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    ApplyTipSkin(frame)
    W.CloseOnEscape(frame)

    -- ⚠ 進戰鬥由 secure 環境自己收（檔頭說明）。屬性要在註冊 driver **之前**寫好，
    --   driver 一註冊就會立刻推一次目前的狀態。
    frame:SetAttribute("_onstate-combat", [[
        if newstate == "1" then
            self:Hide()
        end
    ]])
    RegisterStateDriver(frame, "combat", "[combat] 1; 0")

    frame:SetScript("OnEnter", function() Popup.CancelClose() end)
    frame:SetScript("OnLeave", function() Popup.ScheduleClose() end)
    frame:SetScript("OnHide", function()
        anchorTile = nil        -- 純 Lua 指派，沒有引擎呼叫，當場做沒問題
        -- ⚠⚠ 這支**有可能是上面那個 secure snippet 叫出來的**（戰鬥開始的那一刻）。
        --   那時整條執行流程是暴雪的 —— 在裡面碰 GameTooltip、退訂事件，等於把
        --   taint 注進那條流程，之後暴雪自己做的每件事都算在資訊列頭上。
        --   跟 RegisterUnitWatch 的 Show() 觸發我們的 OnShow 是同一類入口，
        --   解法也一樣：丟到下一幀。
        --   見 .claude/notes/wow-121-addon-code-in-secure-stack.md
        ns.NextFrame("repair-popup-hide", function()
            -- 同一幀內又被 Open 回來（Hide → 立刻重開）的話，這裡拆的就是
            -- 新開那次剛掛上的 listener，面板會變成開著卻不再跟資料
            if frame:IsShown() then return end
            GameTooltip:Hide()
            Repair.RemoveListener("popup")
            Repair.Watch("popup", false)
        end)
    end)
    frame:Hide()
    return frame
end

------------------------------------------------------------
-- 定位：先翻面、再平移（同 Core/MountPopup.lua）
------------------------------------------------------------
local function Place()
    local tile = anchorTile
    if not (frame and tile) then return end
    if InCombatLockdown() then return end       -- 保護框，戰鬥中 SetPoint 會被擋
    local cx = tile:GetCenter()
    local ux = UIParent:GetCenter()
    local leftAlign = (cx or 0) <= (ux or 0)

    local pts = leftAlign
        and { "TOPLEFT",  tile, "BOTTOMLEFT",  0, -2 }
        or  { "TOPRIGHT", tile, "BOTTOMRIGHT", 0, -2 }
    frame:ClearAllPoints()
    frame:SetPoint(unpack(pts))

    local b, pb = frame:GetBottom(), UIParent:GetBottom()
    if b and pb and b < pb + W.SCREEN_PAD then
        pts = leftAlign
            and { "BOTTOMLEFT",  tile, "TOPLEFT",  0, 2 }
            or  { "BOTTOMRIGHT", tile, "TOPRIGHT", 0, 2 }
    end
    W.PlaceClamped(frame, pts)
end

------------------------------------------------------------
-- 對外
------------------------------------------------------------
function Popup.Open(tile)
    if InCombatLockdown() then return end
    Build()
    Popup.CancelClose()
    anchorTile = tile
    Populate()
    frame:Show()
    Place()

    -- 開著的期間資料變了就重畫；高度變了翻面結果可能不同，所以要再定位一次
    Repair.Watch("popup", true)
    Repair.AddListener("popup", function()
        if not frame:IsShown() then return end
        if InCombatLockdown() then return end
        Populate()
        Place()
    end)
end

-- 方塊的 OnEnter 走這支：已經為這顆開著就只是取消關閉；否則等意圖延遲到期、
-- 游標還在方塊上才真的開
function Popup.ScheduleOpen(tile)
    if Popup.IsOpenFor(tile) then
        Popup.CancelClose()
        return
    end
    openGen = openGen + 1
    local gen = openGen
    C_Timer.After(OPEN_DELAY, function()
        if gen ~= openGen then return end
        if not tile:IsMouseOver() then return end
        Popup.Open(tile)
    end)
end
