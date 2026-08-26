------------------------------------------------------------
-- 分享筆記：聊天連結 ＋ 插件通訊
--
-- 流程（跟其他插件分享設定檔的做法同一套）：
--   1. 分享方把筆記序列化，切成小塊用插件通訊頻道送出去；
--   2. 收到的人先放在記憶體裡（**不寫進 SavedVariables**）；
--   3. 分享方接著在聊天視窗貼一則帶連結的訊息；
--   4. 對方點連結 → 開預覽視窗 → 按「儲存」才真的存下來。
--
-- 為什麼用 garrmission 這個連結型別：玩家送出的聊天訊息只有白名單裡的連結型別
-- 不會被伺服器剝掉，這是其中一個。沒裝這支插件的人看到的就是一段普通的
-- 連結文字，點下去不會有任何事，也不會看到一堆亂碼。
--
-- ⚠ 12.1：首領戰進行中／M+ 計時中／PvP 戰場中會封鎖插件通訊。這只擋「送」，
--   已經收到的資料照樣留著。
------------------------------------------------------------
local _, ns = ...

ns.Share = {}
local Share = ns.Share

local W, P, L = ns.W, ns.P, ns.L
local Notes, Comm = ns.Notes, ns.Comm

local LINK_TAG   = "milinote"
local STALE_SEC  = 900        -- 收到的分享放 15 分鐘

local pending  = {}   -- [token] = { note, info, sender, time, mine }
local NewToken  -- 前向宣告（Send 會用到，定義在後面）

------------------------------------------------------------
-- 連結文字
--
-- 標題裡的 `|` 會把連結切斷（那是控制字元），而且玩家自己打的色碼在連結裡也
-- 不合法 —— 一律剝掉再截短。
------------------------------------------------------------
local function LinkLabel(note, info)
    local title = tostring(note.title or ""):gsub("|", "")
    if info and info.context and info.context ~= "" then
        local ctx = tostring(info.context):gsub("|", "")
        title = ctx
    end
    title = strtrim(title)
    if title == "" then title = L["Untitled"] end
    if #title > 60 then title = title:sub(1, 60) .. "..." end
    return title
end

local function BuildLink(token, note, info)
    return ns.PREFIX_COLOR .. "|Hgarrmission:" .. LINK_TAG .. "-" .. token .. "|h["
        .. L["Note"] .. ": " .. LinkLabel(note, info) .. "]|h|r"
end

------------------------------------------------------------
-- 送出
------------------------------------------------------------
local CHANNELS = {
    party   = { chat = "PARTY" },
    raid    = { chat = "RAID" },
    guild   = { chat = "GUILD" },
    whisper = { chat = "WHISPER" },
}

-- channelKey: "party" / "raid" / "guild" / "whisper"
function Share.Send(note, info, channelKey, target)
    if not note then return end
    local ch = CHANNELS[channelKey]
    if not ch then return end

    if Comm.IsRestricted() then
        ns.Print("|cffff5555" .. L["Addon messages are blocked during a boss fight, a Mythic+ run or a battleground. Try again afterwards."] .. "|r")
        return
    end

    local payload = Notes.Serialize(note, info)
    if not payload then return end

    -- token 由這裡產（連結要用），Comm 那邊自己另有一個給切塊用的 —— 兩者無關
    local token = NewToken()
    local ok = Comm.Send("OFFER", token .. "\t" .. payload, ch.chat, target)
    if not ok then
        ns.Print("|cffff5555" .. L["This note is too long to share."] .. "|r")
        return
    end

    -- 自己也留一份：點自己貼的連結要看得到（也是唯一能自我驗證的方式）。
    -- 存的是**解回來的那份**而不是活的筆記本體 —— 對方收到的就是這個內容，
    -- 之後自己再改筆記也不該讓這個連結跟著變。
    local sentCopy = Notes.Deserialize(payload) or note
    pending[token] = {
        note = sentCopy, info = info, sender = UnitName("player"), time = GetTime(), mine = true,
    }

    -- 連結晚一點再貼：讓資料先到，對方一點就開得起來
    local msg = BuildLink(token, note, info)
    local chatType, whisperTo = ch.chat, target
    C_Timer.After(1.5, function()
        SendChatMessage(msg, chatType, nil, whisperTo)
    end)
end

-- 給連結產 token（英數，SetItemRef 的樣式吃 %w）
NewToken = function()
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local t = {}
    for i = 1, 6 do local n = math.random(#chars); t[i] = chars:sub(n, n) end
    return table.concat(t)
end

------------------------------------------------------------
-- 分享選單
------------------------------------------------------------
function Share.ShowShareMenu(anchor, note, info)
    if not note then return end
    info = info or { kind = "note" }

    local items = { { text = L["Share this note"], isTitle = true } }
    local any = false

    if IsInRaid() then
        any = true
        items[#items + 1] = { text = L["To raid"], onClick = function() Share.Send(note, info, "raid") end }
    elseif IsInGroup() then
        any = true
        items[#items + 1] = { text = L["To party"], onClick = function() Share.Send(note, info, "party") end }
    end

    if IsInGuild() then
        any = true
        items[#items + 1] = { text = L["To guild"], onClick = function() Share.Send(note, info, "guild") end }
    end

    -- 目標是玩家才給密語。名字可能是秘密值（12.1 的受限身分），那就不給這個選項
    local targetName = UnitIsPlayer("target") and UnitName("target")
    if targetName and not ns.issecret(targetName) then
        local realm = select(2, UnitName("target"))
        local full = (realm and realm ~= "") and (targetName .. "-" .. realm) or targetName
        any = true
        items[#items + 1] = {
            text = L["Whisper to %s"]:format(targetName),
            onClick = function() Share.Send(note, info, "whisper", full) end,
        }
    end

    if not any then
        items[#items + 1] = { text = "|cff808080" .. L["No one to share with right now"] .. "|r", onClick = function() end }
    end

    W.Menu.Show(items, anchor)
end

------------------------------------------------------------
-- 收件：Comm 把整包重組好交過來
------------------------------------------------------------
local function PrunePending()
    local now = GetTime()
    for k, v in pairs(pending) do
        if now - v.time > STALE_SEC then pending[k] = nil end
    end
end

local function OnOffer(sender, payload)
    if ns.db.settings.share.accept == "none" then return end
    PrunePending()

    -- payload = token .. "\t" .. 序列化筆記
    local token, body = payload:match("^([^\t]+)\t(.*)$")
    if not token then return end
    local note, info = Notes.Deserialize(body)
    if not note then return end

    pending[token] = { note = note, info = info, sender = sender, time = GetTime() }
    if ns.db.settings.share.autoOpen then
        Share.OpenPreview(token)
    end
end

------------------------------------------------------------
-- 預覽視窗
------------------------------------------------------------
local preview, previewViewer, previewTitle, previewFrom, previewTarget, confirmPopup
local previewData

local function DescribeTarget(info)
    if not info then return nil end
    if info.kind ~= "boss" and info.kind ~= "instance" then return nil end

    local instName = info.instanceID and ns.Journal.InstanceName(info.instanceID)
    instName = instName or info.context or "?"

    -- 難度也要講：對方存下去會落在那個難度的格子裡，不講的話他不知道自己收到的
    -- 是「傳奇的那一份」還是「全難度通用的那一份」
    local diff = Notes.NormalizeDiffKey(info.diff)
    local tag = ""
    if diff ~= Notes.DIFF_ALL then
        tag = " |cff808080[" .. ns.Journal.DifficultyName(diff) .. "]|r"
    end

    if info.kind == "boss" then
        local bossName = info.instanceID and info.encounterID
            and ns.Journal.EncounterName(info.instanceID, info.encounterID)
        return L["Boss note"] .. ": " .. instName .. " - "
            .. (bossName or info.context or "?") .. tag
    end
    return L["Dungeon note"] .. ": " .. instName .. tag
end

local function SaveIncoming()
    local data = previewData
    if not data then return end
    local info, note = data.info, data.note
    note.id = Notes.GenerateID()
    note.time = time()

    if info and (info.kind == "boss" or info.kind == "instance")
       and type(info.instanceID) == "number" then
        local encID = (info.kind == "boss") and info.encounterID or nil
        local meta = { name = ns.Journal.InstanceName(info.instanceID) or info.context }
        ns.Journal.StampDungeonID(note, info.instanceID, encID)
        Notes.SetInstanceNote(info.instanceID, encID, Notes.NormalizeDiffKey(info.diff), note)
        local e = Notes.InstanceEntry(info.instanceID, true)
        if meta.name then e.meta.name = meta.name end
        ns.Print(L["Saved to %s."]:format(DescribeTarget(info) or L["Dungeon note"]))
    else
        table.insert(Notes.AccountList(), 1, note)
        ns.Print(L["Saved to your shared notes."])
    end

    ns.Fire("NotesChanged")
    preview:Hide()
end

local function BuildPreview()
    if preview then return end
    preview = W.CreateFrame("MiliUINote_SharePreview", UIParent, 380, 420)
    preview:Hide()
    preview:SetFrameStrata("DIALOG")
    preview:SetFrameLevel(120)
    preview:SetClampedToScreen(true)
    preview:SetMovable(true)
    preview:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    preview:SetBackdropBorderColor(W.Accent(0.9))
    W.CloseOnEscape(preview)

    local header = W.CreateFrame(nil, preview)
    header:SetHeight(P.Scale(24))
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() preview:StartMoving() end)
    header:SetScript("OnDragStop", function() preview:StopMovingOrSizing() end)

    local h = header:CreateFontString(nil, "OVERLAY")
    h:SetFontObject(W.fontNormal)
    h:SetPoint("LEFT", 8, 0)
    h:SetText(L["A note someone shared"])
    h:SetTextColor(W.Accent(1))

    previewFrom = preview:CreateFontString(nil, "OVERLAY")
    previewFrom:SetFontObject(W.fontSmall)
    previewFrom:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 10, -8)
    previewFrom:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -10, -8)
    previewFrom:SetJustifyH("LEFT")

    previewTitle = preview:CreateFontString(nil, "OVERLAY")
    previewTitle:SetFontObject(ns.Media.fontHead)
    previewTitle:SetPoint("TOPLEFT", previewFrom, "BOTTOMLEFT", 0, -6)
    previewTitle:SetPoint("TOPRIGHT", previewFrom, "BOTTOMRIGHT", 0, -6)
    previewTitle:SetJustifyH("LEFT")
    previewTitle:SetWordWrap(false)

    previewTarget = preview:CreateFontString(nil, "OVERLAY")
    previewTarget:SetFontObject(W.fontSmall)
    previewTarget:SetTextColor(1, 0.82, 0)
    previewTarget:SetPoint("TOPLEFT", previewTitle, "BOTTOMLEFT", 0, -4)
    previewTarget:SetPoint("TOPRIGHT", previewTitle, "BOTTOMRIGHT", 0, -4)
    previewTarget:SetJustifyH("LEFT")

    local holder = CreateFrame("Frame", nil, preview)
    holder:SetPoint("TOPLEFT", previewTarget, "BOTTOMLEFT", 0, -8)
    holder:SetPoint("BOTTOMRIGHT", -8, 44)
    local scroll = W.CreateScrollFrame(holder)
    previewViewer = ns.Blocks.CreateViewer(scroll, { interactive = false })

    local save = W.CreateButton(preview, L["Save"], "green", 110, 22)
    save:SetPoint("BOTTOMLEFT", 24, 12)
    save:SetScript("OnClick", function()
        local data = previewData
        if not data then return end
        -- 副本／首領那一格已經有東西的話先問一次：那是**覆蓋**，不是新增
        local info = data.info
        if info and type(info.instanceID) == "number" then
            local encID = (info.kind == "boss") and info.encounterID or nil
            local existing = Notes.GetInstanceNote(info.instanceID, encID,
                                                   Notes.NormalizeDiffKey(info.diff))
            if existing and not Notes.IsEmpty(existing) then
                if not confirmPopup then
                    confirmPopup = W.CreateConfirmPopup(preview, 320, "", function() SaveIncoming() end)
                end
                confirmPopup.text:SetText(L["You already have a note there. Overwrite it?"])
                confirmPopup:Show()
                return
            end
        end
        SaveIncoming()
    end)

    local cancel = W.CreateButton(preview, L["Cancel"], "red", 110, 22)
    cancel:SetPoint("BOTTOMRIGHT", -24, 12)
    cancel:SetScript("OnClick", function() preview:Hide() end)
end

function Share.OpenPreview(token)
    local data = pending[token]
    if not data then
        ns.Print("|cffff5555" .. L["That shared note is no longer available — ask them to share it again."] .. "|r")
        return
    end
    BuildPreview()
    previewData = data

    local who = ns.Comm.ShortName(data.sender) or "?"
    previewFrom:SetText(data.mine and L["Shared by you"] or L["Shared by %s"]:format(who))
    previewTitle:SetText(data.note.title or L["Untitled"])
    local target = DescribeTarget(data.info)
    previewTarget:SetText(target or L["Will be saved to your shared notes."])
    previewViewer:SetNote(data.note)
    preview:Show()
    preview:Raise()
end

------------------------------------------------------------
-- 註冊
------------------------------------------------------------
ns.Comm.Register("OFFER", OnOffer)

-- 聊天連結：Blizzard 自己的 SetItemRef 先跑，認不得這個連結就什麼都不做，
-- 所以沒裝插件的人點下去不會有任何反應（也不會報錯）
hooksecurefunc("SetItemRef", function(link)
    if type(link) ~= "string" then return end
    local token = link:match("^garrmission:" .. LINK_TAG .. "%-(%w+)$")
    if token then Share.OpenPreview(token) end
end)
