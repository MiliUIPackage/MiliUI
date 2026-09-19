------------------------------------------------------------
-- 修裝：資料層（不碰任何框）
--
-- 耐久方塊滑過的面板（Core/RepairPopup.lua）與設定分頁（Options/Tab_Repair.lua）
-- 共用這一支：逐部位耐久、三個分類（道具／玩具／坐騎）的清單、以及「哪幾筆被
-- 玩家關掉」。
--
-- ⚠ 逐部位耐久的表原本住在 Blocks.lua，搬到這裡是因為**面板與方塊都要用**。
--   兩邊各留一份的話，哪天多一個部位（或暴雪換了全域字串名）只會改到一邊。
--
-- ⚠ 遊戲沒有 API 能問「這件道具／這個玩具的使用效果是不是修裝」：
--   GetItemSpell 回的是法術名字、效果描述是純文字，各語系都不一樣。所以清單
--   只能硬編，而硬編一定會過期 —— 每次大改版要跟坐騎的功能型清單一起重驗
--   （同一個維護點，見 .claude/notes/project-miliui-infobar.md）。
--
-- 硬編的是 **itemID**（道具與玩具都是），坐騎不硬編：直接讀坐騎分頁裡 id 為
-- "repair" 的那個分類，玩家在那邊加的自動出現在這裡。名字與圖示一律執行期讀，
-- 各語系免費。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret

ns.Repair = {}
local R = ns.Repair

------------------------------------------------------------
-- 逐部位耐久
--
-- 部位名稱走暴雪的全域字串，各語系免費。
------------------------------------------------------------
R.SLOTS = {
    { 1,  HEADSLOT },      { 3,  SHOULDERSLOT }, { 5,  CHESTSLOT },
    { 6,  WAISTSLOT },     { 7,  LEGSSLOT },     { 8,  FEETSLOT },
    { 9,  WRISTSLOT },     { 10, HANDSSLOT },
    { 16, MAINHANDSLOT },  { 17, SECONDARYHANDSLOT },
}

-- 回 nil ＝ 這個部位沒有會損耗的裝備（或受限內容裡讀不到）
function R.SlotDurability(slotId)
    local cur, mx = GetInventoryItemDurability(slotId)
    cur, mx = S.SafeValue(cur, nil), S.SafeValue(mx, nil)
    if not (cur and mx) or mx <= 0 then return nil end
    return cur / mx * 100
end

-- 只有低耐久才上色：整排都白的時候，眼睛才會被剩下那幾個有顏色的抓住
function R.DurabilityColor(pct)
    if pct < 20 then return 1, 0.3, 0.3 end
    if pct < 50 then return 1, 0.82, 0 end
    return 1, 1, 1
end

-- 全身最低的那一件（方塊上顯示的數字）
function R.Lowest()
    local lowest = 100
    for _, slot in ipairs(R.SLOTS) do
        local pct = R.SlotDurability(slot[1])
        if pct and pct < lowest then lowest = pct end
    end
    return lowest
end

------------------------------------------------------------
-- 三個分類
--
-- 順序就是面板與設定頁的顯示順序。
------------------------------------------------------------
R.CATEGORIES = { "item", "toy", "mount" }

-- 坐騎清單從坐騎分頁的這個分類來（Core/Mounts.lua 的 FUNCTIONAL 種子同名）
R.MOUNT_CATEGORY = "repair"

------------------------------------------------------------
-- 硬編清單
--
-- 每一筆都在 wowhead 逐一查過「ID → 名字 → 使用效果真的會修裝」，查不實的
-- **不放**（排除的理由列在下面，免得下次又有人把同一個 ID 撿回來）。
--
-- ⚠ 道具與玩具的差別不是「東西不一樣」，是**判定與使用方式不一樣**：
--   道具看包包數量（C_Item.GetItemCount）、用 secure 的 type="item"；
--   玩具看收藏（PlayerHasToy）、用 secure 的 type="toy"。同一個 itemID 一旦
--   進了玩具箱就**不會**留在包包裡，放錯欄會變成「有這個東西但按鈕不出現」。
------------------------------------------------------------
-- 道具（吃包包數量）
--
-- 每一筆都對過 wowhead 的道具說明，效果文字裡真的有「維修／修理裝備」才放
-- （2026-09-14 查證，繁中名是 locale=10 的官方翻譯）。
-- ⚠ 除了自動鐵錘以外全部要工程學才用得出來——但我們只畫**包包裡有**的東西，
--   非工程師本來就不會帶著，不必另外擋。
R.ITEMS = {
    { id = 18232  },   -- 修理機器人74A型（Field Repair Bot 74A，工程 300）
    { id = 34113  },   -- 修理機器人110G型（Field Repair Bot 110G，外域工程 25）
    { id = 40769  },   -- 廢料機器人組裝包（Scrapbot Construction Kit，北裂境工程 50）
    { id = 49040  },   -- 吉福斯（Jeeves，北裂境工程 75）
    { id = 132514 },   -- 自動鐵錘（Auto-Hammer，**沒有職業需求**，誰都能按）
    { id = 221957 },   -- 阿爾加修理機器人11O（地心之戰，卡茲阿爾加工程 1）
    { id = 221956 },   -- 原型：阿爾加修復機器人11O（唯一(1)，同上）
}

-- 玩具（吃 PlayerHasToy）
--
-- ⚠ **是空的，而且是查證後的結論、不是還沒填。** 全部帶「玩具」標記又跟修裝
--   沾得上邊的候選逐一看過效果文字，沒有一個會修裝（排除清單在下面）。
--   表留著是因為分類本身要在（哪天暴雪出了一個玩具修裝機器人，補一行就好），
--   面板與設定頁都會把空分類整段跳過。
R.TOYS = {
}

------------------------------------------------------------
-- 查過但**排除**的候選（不要再撿回來，除非重新查證過）
--
-- 道具：
--   11590   ID 對不上名字。它是「機械修理包」——修**機械寵物**的生命值，
--           不修裝備。74A 的正確 ID 是 18232。（repo 裡有插件把 11590 當 74A，
--           那是錯的，別照抄。）
--   132523  劫福斯電池 / 144341 可充電式劫福斯電池：效果只有「召喚劫福斯」。
--           劫福斯**預設不修裝**，要先用 132525「劫福斯維修模組」教過才會進維修
--           模式，而且換上別的模組（蟲洞／戰鬥／閃亮亮）就會蓋掉。沒有 API 問得出
--           「這隻角色的劫福斯現在是哪個模組」⇒ 放進來會變成「按了沒有修裝視窗」。
--   166973  緊急修復包：修的是麥卡貢的**建造計畫**，不是裝備。
--
-- 玩具：
--   87214 / 111821 / 168667  布靈登 4000／5000／7000 型：只發每日禮物，不修裝。
--           （布靈登 6000 型沒有自己的道具，是劫福斯裝閃亮亮模組變出來的 NPC；
--             布靈登 8000 型只有任務名，遊戲裡沒有對應道具。）
--   132518  布靈登的電路設計導覽：小遊戲。
--   230850  探究機器人7001型：傳送到探究，不修裝。
--   264414  至暗之夜探究者的信號槍：效果文字完全沒提維修，只有玩家投稿的導覽
--           把它列在維修區；而且限探究內可用 ⇒ **不確定，排除**。
--   109644  沃特（Walter）：是要塞工程學作坊的擺設，效果是銀行／賣劣質食物，
--           不修裝。（原本以為它會帶修理機器人，查了不是。）
--
-- 其他不確定所以排除的：65361/65362 公會侍從、65363/65364 公會信使、
--   47541 銀白小馬韁轡 —— 三者的效果文字都沒有維修字樣，只有玩家導覽這樣說。
--
-- BfA／暗影之境／巨龍崛起／地心之戰／至暗之夜全掃過一輪：只有地心之戰新增了
-- 修裝道具（221957 ＋ 原型版 221956），12.x 到目前為止沒有新的。
--
-- ⚠ 沒查證過的 ID 一律不要放進上面兩張表。多一個不會修裝的按鈕，玩家按下去
--   什麼都沒發生，比少一個難查得多。
------------------------------------------------------------

------------------------------------------------------------
-- 設定：哪幾筆被玩家關掉
--
-- key 是字串 `kind .. ":" .. id`（例 "item:49040"、"mount:264058"）。
-- 存的是 **true ＝關掉**，預設全開 —— 新學到的東西自動出現，不必回設定頁按。
------------------------------------------------------------
local function Store()
    local db = ns.GetDB()
    if type(db.repair) ~= "table" then db.repair = {} end
    if type(db.repair.hidden) ~= "table" then db.repair.hidden = {} end
    return db.repair
end

function R.Key(kind, id)
    return kind .. ":" .. id
end

function R.IsHidden(kind, id)
    return Store().hidden[R.Key(kind, id)] == true
end

-- 關掉存 true、打開直接清掉那一格：預設全開，所以「打開」＝沒有記錄
function R.SetHidden(kind, id, hidden)
    Store().hidden[R.Key(kind, id)] = hidden and true or nil
    R.Fire()
end

------------------------------------------------------------
-- 監聽者（同 Core/Mounts.lua 的模式：逐個 xpcall，一支壞掉不連坐）
------------------------------------------------------------
local listeners = {}

function R.AddListener(key, fn)
    listeners[key] = fn
end

function R.RemoveListener(key)
    listeners[key] = nil
end

function R.Fire()
    for _, fn in pairs(listeners) do
        xpcall(fn, ns.ReportError)
    end
end

------------------------------------------------------------
-- 事件：**只在面板／設定頁開著的期間**註冊
--
-- 包包每動一次就重算三個分類，關著的時候是純浪費。全部走 ns.Events
-- （延一幀派送，理由見 Core/Bar.lua）。
------------------------------------------------------------
local WATCH_EVENTS = {
    "BAG_UPDATE_DELAYED",              -- 道具數量（買了／用完了）
    "BAG_UPDATE_COOLDOWN",             -- 冷卻開始／結束
    "TOYS_UPDATED",                    -- 學到新玩具
    "NEW_MOUNT_ADDED",                 -- 學到新坐騎
    "MOUNT_JOURNAL_USABILITY_CHANGED", -- 進副本／變形，坐騎變不能用
}

local watching = {}

-- key 讓兩個消費者（面板、設定頁）各自開關，最後一個關掉才真的退訂
function R.Watch(key, on)
    on = on and true or nil
    if watching[key] == on then return end
    watching[key] = on
    local any = next(watching) ~= nil
    for _, ev in ipairs(WATCH_EVENTS) do
        if any then
            ns.Events.Register(ev, "repair-watch", R.Fire)
        else
            ns.Events.Unregister(ev, "repair-watch")
        end
    end
end

------------------------------------------------------------
-- 讀資料
--
-- ⚠ 受限內容裡任何一個讀值回秘密值就當「沒有」（fail-closed）：面板上少一顆
--   按鈕只是不方便，秘密值溜進 SetText／算術／table key 是當場崩潰。
------------------------------------------------------------
-- 物品資料還沒到（沒進過包包、沒看過）時 GetItemNameByID 回 nil。要一顆
-- ItemMixin 去把它拉下來，載好再重畫一次。
--
-- ⚠ 回呼要丟到下一幀：ContinueOnItemLoad 是在暴雪的 GET_ITEM_INFO_RECEIVED
--   派送裡同步叫回來的，直接重畫等於把工作放進人家的執行流程
--   （.claude/notes/wow-121-addon-code-in-secure-stack.md）。
local itemObjects = {}

local function RequestItemData(id)
    if itemObjects[id] then return end
    if not (Item and Item.CreateFromItemID) then return end
    local ok, obj = pcall(Item.CreateFromItemID, Item, id)
    if not (ok and obj) then return end
    itemObjects[id] = obj
    pcall(obj.ContinueOnItemLoad, obj, function()
        ns.NextFrame("repair-itemdata", R.Fire)
    end)
end

local function ItemName(id)
    local name = S.PlainText(S.SafeCall(C_Item.GetItemNameByID, id))
    if not name then RequestItemData(id) end
    return name
end

local function ItemIcon(id)
    local icon = S.SafeCall(C_Item.GetItemIconByID, id)
    -- 圖示可能是 fileID（數字）也可能是路徑（字串），兩種都要接
    return S.PlainNumber(icon) or S.PlainText(icon)
end

-- 只算包包，不含銀行（銀行裡的東西按了也用不出來）
local function ItemCount(id)
    return S.PlainNumber(S.SafeCall(C_Item.GetItemCount, id)) or 0
end

local function ItemEntry(id)
    local count = ItemCount(id)
    return {
        kind   = "item",
        id     = id,
        name   = ItemName(id),
        icon   = ItemIcon(id),
        count  = count,
        owned  = count > 0,
        usable = true,          -- 包包裡有就是能按，能不能用交給遊戲自己講
        hidden = R.IsHidden("item", id),
    }
end

local function ToyEntry(id)
    local name, icon
    if C_ToyBox and C_ToyBox.GetToyInfo then
        local _, toyName, toyIcon = S.SafeCall(C_ToyBox.GetToyInfo, id)
        name = S.PlainText(toyName)
        icon = S.PlainNumber(toyIcon) or S.PlainText(toyIcon)
    end
    -- 秘密布林／問不到一律當「沒有」：玩具箱的資料不該是秘密的，這是防禦性的一道
    local owned = S.ToBool(S.SafeCall(PlayerHasToy, id)) == true
    -- 可用性相反，fail-open：讀不到就照畫（只影響變不變暗，按下去讓遊戲自己報錯，
    -- 比我們猜錯把按鈕藏起來好）。
    -- ⚠ `C_ToyBox.IsToyUsable` **是未文件化的函式**（不在 ToyBoxInfoDocumentation.lua、
    --   wiki 沒有頁面、暴雪自己的玩具箱也沒在用），所以它有沒有秘密值旗標查不到。
    --   既然查不到就當它哪天會變 —— SafeCall ＋ ToBool，問不到就當可用。
    local usable = true
    if C_ToyBox and C_ToyBox.IsToyUsable then
        usable = S.ToBool(S.SafeCall(C_ToyBox.IsToyUsable, id)) ~= false
    end
    return {
        kind   = "toy",
        id     = id,
        name   = name or ItemName(id),
        icon   = icon or ItemIcon(id),
        owned  = owned,
        usable = usable,
        hidden = R.IsHidden("toy", id),
    }
end

local function MountEntry(spellID)
    local info = ns.Mounts and ns.Mounts.Info(spellID) or nil
    return {
        kind   = "mount",
        id     = spellID,
        name   = info and info.name or nil,
        icon   = info and info.icon or nil,
        -- available ＝「這隻角色現在真的召喚得出來」（含陣營、含隱藏），
        -- 不是 collected —— 理由見 Core/Mounts.lua 的 ReadInfo
        owned  = (info and info.available) and true or false,
        usable = (not info) or (info.usable ~= false),
        hidden = R.IsHidden("mount", spellID),
    }
end

-- 坐騎清單的來源。第二個回傳 true ＝ 玩家的坐騎分頁裡沒有「修裝」分類
-- （刪掉了），這裡退回內建種子，設定頁要為此加一行說明。
function R.MountSpells()
    local M = ns.Mounts
    if M then
        for _, cat in ipairs(M.Categories()) do
            if cat.id == R.MOUNT_CATEGORY then return cat.spells or {}, false end
        end
        for _, def in ipairs(M.FUNCTIONAL) do
            if def.id == R.MOUNT_CATEGORY then return def.spells or {}, true end
        end
    end
    return {}, true
end

-- 回 { item = {…}, toy = {…}, mount = {…}, mountSeeded = bool }
function R.Entries()
    local out = { item = {}, toy = {}, mount = {} }

    for _, def in ipairs(R.ITEMS) do
        out.item[#out.item + 1] = ItemEntry(def.id)
    end
    for _, def in ipairs(R.TOYS) do
        out.toy[#out.toy + 1] = ToyEntry(def.id)
    end

    local spells, seeded = R.MountSpells()
    local seen = {}
    for _, spellID in ipairs(spells) do
        -- 去重：同一隻可能被玩家加了兩次；type 檢查擋掉存檔裡的髒資料
        if type(spellID) == "number" and not seen[spellID] then
            seen[spellID] = true
            out.mount[#out.mount + 1] = MountEntry(spellID)
        end
    end
    out.mountSeeded = seeded
    return out
end

-- 面板只畫「擁有而且沒被關掉」的
function R.VisibleIn(list)
    local out = {}
    for _, entry in ipairs(list or {}) do
        if entry.owned and not entry.hidden then out[#out + 1] = entry end
    end
    return out
end

------------------------------------------------------------
-- 冷卻
--
-- ⚠ **沒有**「回 duration 物件」的物品冷卻 API（2026-09-14 查過 wiki 的
--   DurationObject 清單、ItemDocumentation.lua／ContainerDocumentation.lua、
--   以及 12.0／12.1 的 API changes：duration 系列只加了 Spell／SpellBook／
--   ActionBar 三組，Item 那一組從來沒有）。暴雪自己的
--   Blizzard_ActionBar/Shared/ActionButton.lua 畫物品按鈕的冷卻走的也還是
--   `C_ActionBar.GetActionCooldown` ＋ `Cooldown:SetCooldown` 這種舊簽章。
--   唯一的 duration 物件路徑是 `C_ActionBar.GetActionCooldownDuration(actionID)`
--   —— 它吃的是快捷列**格子**，我們手上只有 itemID，用不上。
--
-- 好消息：`C_Item.GetItemCooldown` 的文件上**沒有** SecretReturns、也沒有
--   SecretWhenCooldownsRestricted（對照組 `C_Spell.GetSpellCooldown` 有），
--   所以回傳是明文。仍然逐個洗過 —— 旗標會改版，而秘密值進了 SetCooldown 是
--   當場被引擎擋下來（.claude/notes/wow-121-duration-objects.md）。
--
-- ⚠ 第三個回傳在 C_Item 這一支的文件上是 **bool**（C_Container 的同名函式才是
--   number）。所以不能用 PlainNumber 洗，會把 false 洗成 nil、變成「一直在冷卻」。
--
-- 坐騎不畫冷卻：召喚沒有共用冷卻可言，畫了只是一圈不會動的扇形。
------------------------------------------------------------
function R.Cooldown(kind, id)
    if kind == "mount" then return nil end
    if not (C_Item and C_Item.GetItemCooldown) then return nil end
    local start, duration, enable = S.SafeCall(C_Item.GetItemCooldown, id)
    start    = S.PlainNumber(start)
    duration = S.PlainNumber(duration)
    if not (start and duration) then return nil end
    return start, duration, S.SafeValue(enable, 1)
end
