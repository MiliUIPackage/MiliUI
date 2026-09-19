------------------------------------------------------------
-- 戰隊資訊：彈出面板（角色表格）＋寶庫提示＋列選單
--
-- ⚠ 它是**表格**不是「一列一個選項」的清單，所以走 Core/HoverPanel.lua 的
--   控制器（開關節奏、皮、定位）但**不走列層**——那套排版套在多欄表格上只會把
--   欄位擠壞。表格自己的列高／欄寬留在這支。
--   2026-09-19 從「左鍵點開」改成「滑過就開」：同一條資訊列上四顆方塊，三顆
--   滑過長面板、只有這顆要點，手會記錯。節奏（0.15 開／0.35 關）**只能有一份**，
--   所以走控制器，不在這裡再複製一套世代 token。
--
-- ⚠ 面板上所有吃滑鼠的子框都要接上節奏（表格列、寶庫欄、「全部發送」、寶庫欄
--   的表頭鈕）：游標進子框時父框收到的是 OnLeave，不接的話面板會在游標明明還在
--   上面的時候自己關掉（.claude/notes/wow-child-frame-steals-mouse-focus.md）。
--   已經有 OnEnter/OnLeave 的在原腳本裡加呼叫——**不要**用 HookScript 疊上去，
--   之後誰再 SetScript 就把它蓋掉了。
--
-- 皮走「提示皮」（.claude/notes/project-miliui-hud-skin.md 的第二種變體）：
-- 0.133 不透明底 ＋ 1px 職業色硬邊 ＋ 白字 ＋ 直角。它是「彈出來給人讀內容」的
-- 表面，底色承載的是「讓字讀得出來」，所以不能透。
--
-- ⚠ 面板掛 UIParent、**不掛 bar**：bar 是 secure 按鈕的祖先＝隱式保護框，
--   掛在它底下戰鬥中就 Show/Hide 不了。掛 UIParent 之後點方塊在戰鬥中照樣能開。
--
-- 位置（使用者點名的需求）：貼著方塊開，**先翻面再平移**，四張面板共用一支
-- HP.PlaceBelow（規則與理由寫在 Core/HoverPanel.lua）。
-- 寶庫提示的錨點是欄位不是方塊，翻面方向也不同（預設開在寶庫欄右邊，右邊塞不下
-- 就翻到左邊），所以那段留在這支自己算。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W
local HP = ns.HoverPanel
local Warband = ns.Warband

ns.WarbandPopup = {}
local Popup = ns.WarbandPopup

local WHITE = "Interface\\Buttons\\WHITE8X8"

------------------------------------------------------------
-- 視覺常數
--
-- 內距與文字色跟另外三張面板共用（Core/HoverPanel.lua）；表格自己的列高、欄距、
-- 表頭高留在這裡——那是這張表的排版，不是面板的節奏。
------------------------------------------------------------
local FONT_SZ   = 12
local TITLE_SZ  = 13
local PAD       = HP.PAD_X  -- 面板內距
local TITLE_H   = 24
local HEADER_H  = 22
local ROW_H     = 24
local FOOTER_H  = 18
local COL_GAP   = 6

local TEXT_MAIN = HP.TEXT_MAIN
local TEXT_DIM  = HP.TEXT_DIM
local LOCKED    = { 0.40, 0.40, 0.40 }
local GOLD      = { 1.00, 0.84, 0.00 }
local GREEN     = { 0.25, 0.75, 0.25 }

-- 欄位。label 是語系 key；width 是最小寬，實際寬取「最小寬」與「表頭文字寬＋內距」的大者，
-- 語系換了表頭比較長也不會擠爆。spark 那欄只在裝有 Syndicator 時出現。
local COL_DEFS = {
    { key = "name",   label = "WARBAND_COL_CHAR",   width = 88,  align = "LEFT" },
    { key = "key",    label = "WARBAND_COL_KEY",    width = 132, align = "CENTER" },
    { key = "vault",  label = "WARBAND_COL_VAULT",  width = 96,  align = "CENTER" },
    { key = "bounty", label = "WARBAND_COL_BOUNTY", width = 68,  align = "CENTER" },
    { key = "stash",  label = "WARBAND_COL_STASH",  width = 68,  align = "CENTER" },
    { key = "spark",  label = "WARBAND_COL_SPARK",  width = 64,  align = "CENTER", syndicator = true },
    { key = "date",   label = "WARBAND_COL_DATE",   width = 50,  align = "CENTER" },
}

local panel              -- 檔尾建立（Core/HoverPanel.lua 的控制器）
local frame, vaultTip
local cols = {}          -- 啟用中的欄位（含算好的 width / x）
local rows = {}
local menuRow            -- 列選單最後錨在哪一列（keepOpen 要問）

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function MakeText(parent, size, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(ns.LOCALE_FONT, size or FONT_SZ, "")
    fs:SetTextColor(TEXT_MAIN[1], TEXT_MAIN[2], TEXT_MAIN[3])
    fs:SetWordWrap(false)
    return fs
end

local function SetColor(fs, c)
    fs:SetTextColor(c[1], c[2], c[3])
end

-- 皮與扁平按鈕都走共用的那份（Core/HoverPanel.lua）：四張面板的邊框、底色、
-- 按鈕明暗要是同一句話，各自留一份就是下一次分岔的起點
local ApplyTipSkin   = HP.ApplyTipSkin
local MakeFlatButton = HP.MakeFlatButton

------------------------------------------------------------
-- 寶庫顯示規則（跟原本 MiliUI 本體那份一致）
------------------------------------------------------------
-- 對應寶庫物品稀有度：+10 以上=神話(傳說橘)，+2~+9=英雄(史詩紫)，+1=勇士(稀有藍)
local function VaultSlotQualityColor(level)
    local c
    if level >= 10 then
        c = ITEM_QUALITY_COLORS[5]
    elseif level >= 2 then
        c = ITEM_QUALITY_COLORS[4]
    elseif level >= 1 then
        c = ITEM_QUALITY_COLORS[3]
    end
    if c then return c.r, c.g, c.b end
    return LOCKED[1], LOCKED[2], LOCKED[3]
end

-- 寶庫格是否解鎖：**只看 progress >= threshold**，這是 Blizzard 自己的判準。
-- ⚠ 千萬不要再加「level > 0」的條件：M0 場次照樣計入寶庫，但 keystone 等級是 0，
-- 加了就會變成「打了 8 場 M0、三格 progress 都是 8、面板卻整排暗著」。
local function IsVaultSlotUnlocked(slot)
    if not slot then return false end
    local threshold = slot.threshold or 0
    if threshold <= 0 then return false end
    return (slot.progress or 0) >= threshold
end

-- M+ 軌道的格子內容：level 0 = M0（沒有鑰石等級），獎勵走勇士軌道
local function VaultMythicCell(level)
    level = level or 0
    if level > 0 then
        local r, g, b = VaultSlotQualityColor(level)
        return "+" .. level, r, g, b
    end
    local c = ITEM_QUALITY_COLORS[3]
    return "M0", c.r, c.g, c.b
end

-- 團本難度 ID → 難度名稱 ＋ 寶庫獎勵軌道對應的物品稀有度
-- 14=普通(勇士/藍), 15=英雄(英雄/紫), 16=傳奇(神話/橘), 17=團搜(精兵/綠)
local RAID_DIFFICULTY_INFO = {
    [17] = { label = "WARBAND_RAID_LFR",    quality = 2 },
    [14] = { label = "WARBAND_RAID_NORMAL", quality = 3 },
    [15] = { label = "WARBAND_RAID_HEROIC", quality = 4 },
    [16] = { label = "WARBAND_RAID_MYTHIC", quality = 5 },
}

-- 本週 M+ 計入寶庫的場次數（以寶庫進度為準，取各 slot progress 最大值）
-- GetRunHistory 的客戶端快取偶爾比寶庫進度慢一拍，用這個當「X/8」的權威來源
local function VaultMythicProgress(vault)
    local slots = vault and vault.mplus
    if not slots then return 0 end
    local maxP = 0
    for _, s in ipairs(slots) do
        if (s.progress or 0) > maxP then maxP = s.progress end
    end
    return maxP
end

-- 解鎖格的顯示文字與顏色。世界/競技軌道的 level 語義混亂（深淵 tier、世界任務、
-- PvP 評分各自不同編碼），完成與否更實用，直接打勾就好
local function VaultCellDisplay(trackKey, slot)
    local level = slot.level
    if trackKey == "mplus" then
        return VaultMythicCell(level)
    end
    if trackKey == "raid" then
        local info = RAID_DIFFICULTY_INFO[level]
        if info then
            local q = ITEM_QUALITY_COLORS[info.quality]
            return L[info.label], q.r, q.g, q.b
        end
    end
    -- 用 Blizzard atlas 的勾勾圖示，避免繁中字型缺 ✓ 字符變豆腐
    return "|A:common-icon-checkmark:14:14|a", TEXT_MAIN[1], TEXT_MAIN[2], TEXT_MAIN[3]
end

local VAULT_TRACK_LABELS = {
    mplus = "WARBAND_TRACK_MPLUS",
    raid  = "WARBAND_TRACK_RAID",
    world = "WARBAND_TRACK_WORLD",
    pvp   = "WARBAND_TRACK_PVP",
}

------------------------------------------------------------
-- 寶庫欄要看哪一軌：點表頭循環 總計 → 團本 → M+ → 世界 → 總計
--
-- 它是**設定**不是資料，所以放 db.warbandVaultMode（在 warband 那張表外面）——
-- 那張表 ResetDB 會整包留著，模式跟著它留就變成「還原預設值也還原不掉」。
-- 讀到不認得的值（舊存檔、手改壞了）一律當 "total"。
--
-- 「世界」軌在伺服器資料裡是 world 或 pvp **擇一**（跟寶庫提示同一個規則），
-- 所以模式只有一個 world，實際讀到哪一軌由資料決定。
------------------------------------------------------------
local VAULT_MODES = { "total", "raid", "mplus", "world" }

local function VaultMode()
    local mode = ns.GetDB().warbandVaultMode
    for _, m in ipairs(VAULT_MODES) do
        if m == mode then return m end
    end
    return "total"
end

local function VaultHeaderText(mode)
    if mode == "total" then return L["WARBAND_COL_VAULT"] end
    return L["WARBAND_COL_VAULT_FMT"]:format(
        L["WARBAND_COL_VAULT"], L[VAULT_TRACK_LABELS[mode]] or mode)
end

------------------------------------------------------------
-- 寶庫提示：絕對定位 ＋ 固定欄寬（不同寬度字元不會把欄位撐歪），高度依內容
------------------------------------------------------------
local TT = {
    PAD           = 10,
    TITLE_H       = 20,
    ROW_H         = 18,
    SPACE         = 8,
    RUNS_HEADER_H = 18,
    RUN_LINE_H    = 16,
    FOOTER_H      = 14,
    LABEL_W       = 44,
    CELL_W        = 50,
    ROW_COUNT     = 3,
}
TT.WIDTH = TT.PAD * 2 + TT.LABEL_W + TT.CELL_W * 3

-- 「+15  地城名」，等級依品質上色
local function FormatRunLine(run)
    local r, g, b = VaultSlotQualityColor(run.level or 0)
    local hex = string.format("%02x%02x%02x",
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
    return string.format("|cff%s+%d|r  %s", hex, run.level or 0, Warband.MapName(run.mapID))
end

local function BuildVaultTip()
    if vaultTip then return vaultTip end
    local f = CreateFrame("Frame", "MiliUIInfoBar_WarbandVaultTip", UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetSize(TT.WIDTH, 100)
    ApplyTipSkin(f)
    f:Hide()

    f.title = MakeText(f, TITLE_SZ)
    f.title:SetPoint("TOPLEFT", TT.PAD, -TT.PAD)
    SetColor(f.title, GOLD)

    f.rows = {}
    for i = 1, TT.ROW_COUNT do
        local yOff = -(TT.PAD + TT.TITLE_H + (i - 1) * TT.ROW_H)
        local row = { cells = {} }
        row.label = MakeText(f)
        row.label:SetPoint("TOPLEFT", TT.PAD, yOff)
        row.label:SetSize(TT.LABEL_W, TT.ROW_H)
        row.label:SetJustifyH("LEFT")
        row.label:SetJustifyV("MIDDLE")
        SetColor(row.label, GOLD)
        for j = 1, 3 do
            local fs = MakeText(f)
            fs:SetPoint("TOPLEFT", TT.PAD + TT.LABEL_W + (j - 1) * TT.CELL_W, yOff)
            fs:SetSize(TT.CELL_W, TT.ROW_H)
            fs:SetJustifyH("CENTER")
            fs:SetJustifyV("MIDDLE")
            row.cells[j] = fs
        end
        f.rows[i] = row
    end

    f.runsHeader = MakeText(f)
    f.runsHeader:SetSize(TT.WIDTH - TT.PAD * 2, TT.RUNS_HEADER_H)
    f.runsHeader:SetJustifyH("LEFT")
    f.runsHeader:SetJustifyV("MIDDLE")
    SetColor(f.runsHeader, GOLD)
    f.runsHeader:Hide()

    f.runLines = {}
    for i = 1, Warband.MPLUS_MAX_RUNS do
        local fs = MakeText(f)
        fs:SetSize(TT.WIDTH - TT.PAD * 2, TT.RUN_LINE_H)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("MIDDLE")
        fs:Hide()
        f.runLines[i] = fs
    end

    f.snapshot = MakeText(f, 11)
    SetColor(f.snapshot, TEXT_DIM)

    f.noDataMain = MakeText(f)
    f.noDataMain:SetPoint("TOPLEFT", TT.PAD, -(TT.PAD + TT.TITLE_H))
    SetColor(f.noDataMain, { 0.7, 0.7, 0.7 })
    f.noDataMain:SetText(L["WARBAND_VAULT_NONE"])
    f.noDataMain:Hide()

    f.noDataSub = MakeText(f, 11)
    f.noDataSub:SetPoint("TOPLEFT", f.noDataMain, "BOTTOMLEFT", 0, -4)
    f.noDataSub:SetPoint("RIGHT", f, "RIGHT", -TT.PAD, 0)
    f.noDataSub:SetJustifyH("LEFT")
    SetColor(f.noDataSub, { 0.5, 0.5, 0.5 })
    f.noDataSub:SetText(L["WARBAND_VAULT_NONE_SUB"])
    f.noDataSub:Hide()

    vaultTip = f
    return f
end

local function FillTipRow(row, trackKey, slots)
    row.label:SetText(L[VAULT_TRACK_LABELS[trackKey]] or trackKey)
    for j = 1, 3 do
        local slot = slots and slots[j]
        local cell = row.cells[j]
        if IsVaultSlotUnlocked(slot) then
            local text, r, g, b = VaultCellDisplay(trackKey, slot)
            cell:SetText(text)
            cell:SetTextColor(r, g, b)
        else
            cell:SetText("·")
            SetColor(cell, LOCKED)
        end
    end
end

-- 先填內容、量出高度，再定位：W.PlaceClamped 要的是「已經有正確尺寸並且 Show 著」的框
local function ShowVaultTip(owner, data)
    local tt = BuildVaultTip()
    tt.title:SetText(L["WARBAND_VAULT_TITLE"]:format(data and data.name or "?"))
    for i = 1, TT.ROW_COUNT do
        local row = tt.rows[i]
        row.label:SetText("")
        for j = 1, 3 do row.cells[j]:SetText("") end
    end
    tt.runsHeader:Hide()
    for i = 1, Warband.MPLUS_MAX_RUNS do tt.runLines[i]:Hide() end

    local vault = data and data.vault
    if not vault then
        tt.snapshot:Hide()
        tt.noDataMain:Show()
        tt.noDataSub:Show()
        tt:SetHeight(TT.PAD * 2 + TT.TITLE_H + 42)
    else
        tt.noDataMain:Hide()
        tt.noDataSub:Hide()
        tt.snapshot:Show()

        -- 固定順序：團本 → M+ → 世界/競技（兩者擇一，視伺服器資料而定）
        local sequence = { "raid", "mplus" }
        if vault.world then
            sequence[#sequence + 1] = "world"
        elseif vault.pvp then
            sequence[#sequence + 1] = "pvp"
        end
        for i, key in ipairs(sequence) do
            FillTipRow(tt.rows[i], key, vault[key])
        end

        local y = TT.PAD + TT.TITLE_H + #sequence * TT.ROW_H

        -- M+ 場次清單。場次數以寶庫進度為準（即時），清單行數來自 GetRunHistory。
        -- 條件是 count > 0 而不是 nRuns > 0：M0 場次計入寶庫進度，但 GetRunHistory 只回傳
        -- 有鑰石的場次，「進度 8/8、清單 0 行」是正常狀態，那時仍要把標題顯示出來。
        local runs = vault.mplusRuns
        local nRuns = runs and #runs or 0
        local count = math.min(VaultMythicProgress(vault), Warband.MPLUS_MAX_RUNS)
        if count == 0 then count = nRuns end
        if count > 0 then
            y = y + TT.SPACE
            tt.runsHeader:ClearAllPoints()
            tt.runsHeader:SetPoint("TOPLEFT", TT.PAD, -y)
            tt.runsHeader:SetText(L["WARBAND_RUNS_HEADER"]:format(count, Warband.MPLUS_MAX_RUNS))
            tt.runsHeader:Show()
            y = y + TT.RUNS_HEADER_H
            for i = 1, nRuns do
                local line = tt.runLines[i]
                line:ClearAllPoints()
                line:SetPoint("TOPLEFT", TT.PAD, -y)
                line:SetText(FormatRunLine(runs[i]))
                line:Show()
                y = y + TT.RUN_LINE_H
            end
        end

        y = y + TT.SPACE
        tt.snapshot:ClearAllPoints()
        tt.snapshot:SetPoint("TOPLEFT", TT.PAD, -y)
        tt.snapshot:SetText(vault.timestamp
            and L["WARBAND_SNAPSHOT"]:format(date("%m/%d %H:%M", vault.timestamp)) or "")
        y = y + TT.FOOTER_H + TT.PAD
        tt:SetHeight(y)
    end

    -- 定位：預設開在右邊，右緣塞不下就翻到左邊，翻完還出界才平移
    tt:Show()
    local pts = { "TOPLEFT", owner, "TOPRIGHT", 6, 0 }
    tt:ClearAllPoints()
    tt:SetPoint(unpack(pts))
    local right, pr = tt:GetRight(), UIParent:GetRight()
    if right and pr and right > pr - W.SCREEN_PAD then
        pts = { "TOPRIGHT", owner, "TOPLEFT", -6, 0 }
    end
    W.PlaceClamped(tt, pts)
end

local function HideVaultTip()
    if vaultTip then vaultTip:Hide() end
end

------------------------------------------------------------
-- 列選單（共用層 W.Menu，自己會翻面／貼齊畫面）
--
-- ⚠ 選單開著的期間游標在面板**外面**（選單是另一個框），面板的關閉排程照樣會
--   到期。記住錨在哪一列，控制器的 keepOpen 才問得出「現在不能關」。
------------------------------------------------------------
local function ShowRowMenu(row)
    if not (row.data and row.key) then return end
    menuRow = row
    HideVaultTip()
    local items = { { isTitle = true, text = row.data.name or row.key } }
    if Warband.PartyChannel() and (row.data.level or 0) > 0 then
        items[#items + 1] = {
            text = L["MENU_WARBAND_SEND"],
            onClick = function()
                local ch = Warband.PartyChannel()
                if ch then SendChatMessage(Warband.FormatKeystoneMessage(row.data), ch) end
            end,
        }
        items[#items + 1] = { isSeparator = true }
    end
    items[#items + 1] = {
        text = L["MENU_WARBAND_DELETE"],
        onClick = function() Warband.Delete(row.key) end,
    }
    W.Menu.Show(items, row)
end

------------------------------------------------------------
-- 表格列（池化：frame 刪不掉，一律重用）
------------------------------------------------------------
local function ColByKey(key)
    for _, c in ipairs(cols) do
        if c.key == key then return c end
    end
end

local function PlaceCell(fs, col)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", col.x, 0)
    fs:SetWidth(col.width)
    fs:SetJustifyH(col.align)
end

local function GetOrCreateRow(index)
    local row = rows[index]
    if row then return row end

    row = CreateFrame("Button", nil, frame)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("AnyUp")

    row.altBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.altBg:SetTexture(WHITE)
    row.altBg:SetVertexColor(1, 1, 1, 0.03)
    row.altBg:SetAllPoints()

    -- 滑過：白薄膜（明暗），跟資訊列方塊同一句話
    row:SetHighlightTexture(WHITE)
    row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)

    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then ShowRowMenu(self) end
    end)
    -- 列吃滑鼠（有滑過反白、有右鍵選單），所以它得自己接回面板的開關節奏
    row:SetScript("OnEnter", function() panel:CancelClose() end)
    row:SetScript("OnLeave", function() panel:ScheduleClose() end)

    row.cells = {}
    for _, col in ipairs(cols) do
        if col.key == "vault" then
            -- 寶庫欄：一個 sub-frame 含 3 個 cell 字串，整塊 hover 出提示
            local area = CreateFrame("Frame", nil, row)
            area:SetSize(col.width, ROW_H)
            area:SetPoint("LEFT", col.x, 0)
            area:EnableMouse(true)
            area:SetPropagateMouseClicks(true)
            area.cells = {}
            local cellW = col.width / 3
            for i = 1, 3 do
                local fs = MakeText(area)
                fs:SetPoint("LEFT", (i - 1) * cellW, 0)
                fs:SetWidth(cellW)
                fs:SetJustifyH("CENTER")
                area.cells[i] = fs
            end
            -- 「總計」模式用的單一字串：橫跨整欄置中（三格會擠成 5 / 9 三段，
            -- 讀起來像三個獨立的數字）
            area.total = MakeText(area)
            area.total:SetPoint("LEFT", 0, 0)
            area.total:SetWidth(col.width)
            area.total:SetJustifyH("CENTER")
            area.total:Hide()
            area:SetScript("OnEnter", function()
                panel:CancelClose()
                ShowVaultTip(area, row.data)
            end)
            area:SetScript("OnLeave", function()
                HideVaultTip()
                panel:ScheduleClose()
            end)
            row.vaultArea = area
        else
            local fs = MakeText(row)
            PlaceCell(fs, col)
            row.cells[col.key] = fs
        end
    end

    rows[index] = row
    return row
end

------------------------------------------------------------
-- 寶庫欄的格子
--
-- raid／mplus／world 三種模式都是三格，解鎖判準一律 IsVaultSlotUnlocked、
-- 顯示一律走 VaultCellDisplay（M+ 出 +15／M0、團本出難度名＋品質色、世界出勾）。
--
-- total 是**整欄一個** `已解鎖/總格數`：總格數不寫死 9，而是把有資料的軌道各自的
-- 格數加起來——某一軌還沒有資料時（新角色、伺服器還沒回），寫死 9 會讓分母看起來
-- 像「有三格永遠拿不到」。
--
-- 顏色只有兩階：0 格＝灰、≥1＝白。**不要**再加綠／金之類的分級——這張表上
-- 顏色已經被「品質軌道」與「拿了沒」用掉了，狀態只換明暗。
------------------------------------------------------------
local function VaultTotals(vault)
    -- 世界與競技擇一，跟寶庫提示的 sequence 同一個規則
    local tracks = { "raid", "mplus", vault.world and "world" or (vault.pvp and "pvp" or nil) }
    local unlocked, total = 0, 0
    for _, key in ipairs(tracks) do
        for _, slot in ipairs(vault[key] or {}) do
            total = total + 1
            if IsVaultSlotUnlocked(slot) then unlocked = unlocked + 1 end
        end
    end
    return unlocked, total
end

local function FillVaultCells(area, vault, mode)
    if mode == "total" then
        for i = 1, 3 do area.cells[i]:Hide() end
        area.total:Show()
        local unlocked, total = 0, 0
        if vault then unlocked, total = VaultTotals(vault) end
        if total <= 0 then
            -- 沒資料跟其他欄講同一句話（灰點）
            area.total:SetText("·")
            SetColor(area.total, LOCKED)
        else
            area.total:SetText(unlocked .. "/" .. total)
            SetColor(area.total, unlocked > 0 and TEXT_MAIN or LOCKED)
        end
        return
    end

    area.total:Hide()
    local trackKey, slots = mode, vault and vault[mode]
    if mode == "world" then
        -- world 與 pvp 互斥，實際拿到哪一軌決定顯示要用哪一個 trackKey
        trackKey = (vault and vault.world) and "world" or "pvp"
        slots = vault and (vault.world or vault.pvp)
    end
    for i = 1, 3 do
        local slot = slots and slots[i]
        local cell = area.cells[i]
        cell:Show()
        if IsVaultSlotUnlocked(slot) then
            local text, r, g, b = VaultCellDisplay(trackKey, slot)
            cell:SetText(text)
            cell:SetTextColor(r, g, b)
        else
            cell:SetText("·")
            SetColor(cell, LOCKED)
        end
    end
end

------------------------------------------------------------
-- 填表
------------------------------------------------------------
local function FillRow(row, entry, idx, sparkLookup, vaultMode)
    local data = entry.data
    row.key = entry.key
    row.data = data
    row.altBg:SetShown(idx % 2 == 0)

    local c = row.cells
    local classColor = data.class and RAID_CLASS_COLORS[data.class]
    if classColor then
        c.name:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        SetColor(c.name, TEXT_MAIN)
    end
    c.name:SetText(data.name or entry.key)

    if data.mapID and data.mapID > 0 and (data.level or 0) > 0 then
        SetColor(c.key, TEXT_MAIN)
        c.key:SetText(Warband.MapName(data.mapID) .. " +" .. data.level)
    else
        SetColor(c.key, LOCKED)
        c.key:SetText("—")
    end

    -- 寶庫欄：畫哪一軌由表頭上選的模式決定（點表頭循環）
    FillVaultCells(row.vaultArea, data.vault, vaultMode)

    -- 懸賞圖欄三態：本週沒掉＝灰點、掉了還沒用＝金色地圖提醒、用掉了＝勾
    local bounty = data.vault and data.vault.bounty
    if bounty and bounty.got then
        if (bounty.count or 0) > 0 then
            c.bounty:SetText("|T" .. Warband.BOUNTY_ICON .. ":14:14|t " .. L["WARBAND_BOUNTY_UNUSED"])
            SetColor(c.bounty, GOLD)
        else
            c.bounty:SetText("|A:common-icon-checkmark:12:12|a " .. L["WARBAND_BOUNTY_USED"])
            SetColor(c.bounty, TEXT_MAIN)
        end
    else
        c.bounty:SetText("·")
        SetColor(c.bounty, LOCKED)
    end

    -- 儲物箱欄：沒資料＝灰點、進行中＝金色 x/y、拿滿＝綠色 x/y
    local stash = data.vault and data.vault.stash
    if stash and stash.max then
        c.stash:SetText(stash.cur .. "/" .. stash.max)
        if stash.cur >= stash.max then
            SetColor(c.stash, GREEN)
        elseif stash.cur > 0 then
            SetColor(c.stash, GOLD)
        else
            SetColor(c.stash, TEXT_MAIN)
        end
    else
        c.stash:SetText("·")
        SetColor(c.stash, LOCKED)
    end

    if c.spark then
        local count = sparkLookup and sparkLookup[Warband.SparkKey(data)] or 0
        if count > 0 then
            c.spark:SetText(tostring(count))
            SetColor(c.spark, GOLD)
        else
            c.spark:SetText("·")
            SetColor(c.spark, LOCKED)
        end
    end

    SetColor(c.date, TEXT_MAIN)
    c.date:SetText(date("%m/%d", Warband.LastSeen(data)))
end

local function Populate()
    local list = Warband.SortedRecords()
    local sparkLookup = ColByKey("spark") and Warband.SparkLookup() or nil
    local vaultMode = VaultMode()

    frame.sendAll:SetShown(IsInGroup())

    local rowTop = PAD + TITLE_H + HEADER_H
    for idx, entry in ipairs(list) do
        local row = GetOrCreateRow(idx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(rowTop + (idx - 1) * ROW_H))
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(rowTop + (idx - 1) * ROW_H))
        FillRow(row, entry, idx, sparkLookup, vaultMode)
        row:Show()
    end
    for i = #list + 1, #rows do rows[i]:Hide() end

    local bodyH
    if #list == 0 then
        frame.noData:Show()
        bodyH = 30
    else
        frame.noData:Hide()
        bodyH = #list * ROW_H
    end
    frame:SetHeight(rowTop + bodyH + 6 + FOOTER_H + PAD)
end

------------------------------------------------------------
-- 建框（控制器的 spec.build：框本身、皮、strata、ESC 都已經由它處理好了，
-- 這裡只放這張表自己的東西）
------------------------------------------------------------
local function BuildTable(f)
    frame = f

    frame.title = MakeText(frame, TITLE_SZ)
    frame.title:SetPoint("TOPLEFT", PAD, -PAD)
    frame.title:SetText(L["BLOCK_WARBAND"])
    SetColor(frame.title, GOLD)

    frame.sendAll = MakeFlatButton(frame, L["WARBAND_SEND_ALL"], function()
        local ch = Warband.PartyChannel()
        if ch then Warband.SendReport(ch) end
    end)
    -- 按鈕高度由共用的扁平鈕決定，這裡讀回來對齊標題列的垂直中線
    frame.sendAll:SetPoint("TOPRIGHT", -PAD, -(PAD + (TITLE_H - frame.sendAll:GetHeight()) / 2))
    frame.sendAll:SetScript("OnEnter", function(self)
        panel:CancelClose()
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["WARBAND_SEND_ALL"], 1, 1, 1)
        GameTooltip:AddLine(L["WARBAND_SEND_ALL_DESC"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    frame.sendAll:SetScript("OnLeave", function()
        GameTooltip:Hide()
        panel:ScheduleClose()
    end)

    local hasSpark = Warband.HasSyndicator()
    local x = 0
    for _, def in ipairs(COL_DEFS) do
        if not def.syndicator or hasSpark then
            -- 寶庫那欄的表頭是可以點的（切換軌道），其餘是純文字
            local isVault = (def.key == "vault")
            local host = isVault and CreateFrame("Button", nil, frame) or frame
            local fs = MakeText(host)
            SetColor(fs, GOLD)

            local width = def.width
            if isVault then
                -- ⚠ 欄的 x 是建框時定死的，切換模式時**不能**變寬 ⇒ 欄寬一次用
                --   四種標題的最大值算出來，之後換誰都塞得下
                for _, mode in ipairs(VAULT_MODES) do
                    fs:SetText(VaultHeaderText(mode))
                    width = math.max(width, math.ceil(fs:GetStringWidth()) + 6)
                end
                fs:SetText(VaultHeaderText(VaultMode()))
            else
                fs:SetText(L[def.label])
                width = math.max(width, math.ceil(fs:GetStringWidth()) + 6)
            end

            local col = { key = def.key, align = def.align, width = width, x = x, header = fs }
            if isVault then
                host:SetPoint("TOPLEFT", PAD + x, -(PAD + TITLE_H))
                host:SetSize(width, HEADER_H)
                host:RegisterForClicks("LeftButtonUp")
                fs:SetAllPoints(host)
                frame.vaultHeader = host
            else
                fs:SetPoint("TOPLEFT", PAD + x, -(PAD + TITLE_H))
                fs:SetSize(width, HEADER_H)
            end
            fs:SetJustifyH(def.align)
            fs:SetJustifyV("MIDDLE")
            cols[#cols + 1] = col
            x = x + width + COL_GAP
        end
    end

    local tableW = x - COL_GAP
    frame:SetWidth(PAD * 2 + tableW)

    -- 表頭鈕的行為（欄位都建好、cols 齊了才掛）：滑過換白字＋一行說明，
    -- 左鍵循環。狀態只換明暗、不換色——金色在這張表上的語意是「這是表頭」。
    if frame.vaultHeader then
        local btn = frame.vaultHeader
        local fs = ColByKey("vault").header
        btn:SetScript("OnEnter", function(self)
            panel:CancelClose()
            fs:SetTextColor(1, 1, 1)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(L["WARBAND_VAULT_HEADER_TIP"], 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            SetColor(fs, GOLD)
            GameTooltip:Hide()
            panel:ScheduleClose()
        end)
        btn:SetScript("OnClick", function()
            local mode, idx = VaultMode(), 1
            for i, m in ipairs(VAULT_MODES) do
                if m == mode then idx = i end
            end
            ns.GetDB().warbandVaultMode = VAULT_MODES[idx % #VAULT_MODES + 1]
            fs:SetText(VaultHeaderText(VaultMode()))
            -- 只重填格子：欄寬（四種標題取最大）與列高都沒變，不必重新定位
            panel:Populate()
        end)
    end

    -- 表頭底下的髮絲線：標題與內容之間要一條結構性的分隔
    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetTexture(WHITE)
    rule:SetVertexColor(1, 1, 1, 0.12)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", PAD, -(PAD + TITLE_H + HEADER_H - 1))
    rule:SetPoint("TOPRIGHT", -PAD, -(PAD + TITLE_H + HEADER_H - 1))

    frame.noData = MakeText(frame)
    frame.noData:SetPoint("TOP", 0, -(PAD + TITLE_H + HEADER_H + 8))
    SetColor(frame.noData, TEXT_DIM)
    frame.noData:SetText(L["WARBAND_NO_RECORDS"])
    frame.noData:Hide()

    -- 底部的操作說明：灰字、排最後
    frame.footer = MakeText(frame, 11)
    frame.footer:SetPoint("BOTTOMLEFT", PAD, PAD)
    frame.footer:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    frame.footer:SetJustifyH("LEFT")
    SetColor(frame.footer, TEXT_DIM)
    frame.footer:SetText(L["WARBAND_TIP"]:format(Warband.Keyword()))
end

------------------------------------------------------------
-- 面板
--
-- allowCombat：這張表是純讀的資料（鑰石、寶庫進度），戰鬥中看它沒有壞處；
-- 它掛 UIParent、不是保護框，Show/Hide 都合法。
------------------------------------------------------------
local perfT0

panel = HP.New({
    name        = "MiliUIInfoBar_WarbandPopup",
    allowCombat = true,
    build       = BuildTable,
    -- 自己這筆記錄在開面板時刷一次。⚠ 放進 populate 的話，開著期間每次 listener
    -- 重畫都會再刷一次，而刷新自己又會發通知——那就是一圈回來了
    beforeOpen  = function()
        perfT0 = ns.Perf.Begin()
        Warband.RefreshOwn("popup open")
    end,
    -- 表格不用列層，第一個參數（rows）用不到
    populate    = function() Populate() end,
    onOpen      = function()
        ns.Perf.End("warband popup open", perfT0)
        -- 開著的期間：資料變了就重畫（高度會變，翻面結果可能不同 ⇒ 走 Refresh
        -- 讓它連定位一起重來），組隊狀態變了刷「全部發送」
        Warband.AddListener("popup", function() panel:Refresh() end)
        ns.Events.Register("GROUP_ROSTER_UPDATE", "warband-popup", function()
            if frame:IsShown() then frame.sendAll:SetShown(IsInGroup()) end
        end)
    end,
    onHide      = function()
        HideVaultTip()
        ns.Events.Unregister("GROUP_ROSTER_UPDATE", "warband-popup")
        Warband.RemoveListener("popup")
    end,
    -- 列選單開著時游標在面板外，關閉排程照樣會到期 ⇒ 這時不能關（見 ShowRowMenu）
    keepOpen    = function()
        return (menuRow and W.Menu.IsOpenFor(menuRow)) and true or false
    end,
})

------------------------------------------------------------
-- 對外（名字跟另外三張面板一致，Core/Blocks.lua 只要記一套）
------------------------------------------------------------
function Popup.CancelClose()   panel:CancelClose() end
function Popup.CancelOpen()    panel:CancelOpen() end
function Popup.Hide()          panel:Hide() end
function Popup.ScheduleClose() panel:ScheduleClose() end
function Popup.Open(tile)         panel:Open(tile) end
function Popup.ScheduleOpen(tile) panel:ScheduleOpen(tile) end
function Popup.IsOpenFor(tile)    return panel:IsOpenFor(tile) end
