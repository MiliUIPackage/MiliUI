------------------------------------------------------------
-- 戰利品擷取（實驗性）
--
-- ⚠⚠ **這條路能不能拿到隊友的尾箱，是未驗證的。** 事件本身帶著 playerName 與
--   classFileName，看起來就是為「誰拿到什麼」設計的，但鑰石結束的箱子走的是不是
--   同一條路，只有實機才知道。所以：
--     * 拿不到就是面板上那一欄空著，其餘功能不受影響（沒有任何地方等它）；
--     * 探針（Debug/Probe.lua）另外把完賽後 180 秒內所有相關事件都記一遍，
--       實機跑一趟就知道該改聽哪一個。
--
-- 為什麼要一個「窗口」而不是一直聽：這支要記的是**鑰石的尾箱**。一直聽的話，
-- 之後在任何地方撿到的裝備都會被貼到上一場鑰石的記錄裡。
--
-- ⚠ **場次記錄存檔之後仍然要能被追加。** 戰利品一定晚於統計快照（箱子在結算畫面
--   之後才開），所以這裡拿的是 db.runs 裡那張表本人，改它就是改存檔。
------------------------------------------------------------
local _, ns = ...

ns.Loot = {}
local Loot = ns.Loot

local S = ns.Secret

-- 完賽後開多久。120 秒足夠走完結算畫面開箱；再長就會開始收到副本外的東西
local WINDOW_SEC = 120

local frame
local target          -- 正在收集的那一筆 run（db.runs 裡的表本人）
local expiresAt
local generation = 0  -- 世代 token：連打兩把時，上一把的關窗排程不能關掉新的

------------------------------------------------------------
-- 只記裝備
--
-- 鑰石結束前後會收到一堆貨幣、材料、任務物品 —— 那些放進「戰利品」欄只是噪音。
-- classID 走 GetItemInfoInstant：那支是本地快取，不必等伺服器回應。
------------------------------------------------------------
local function IsEquipment(itemID)
    if not (C_Item and C_Item.GetItemInfoInstant) then return false end
    local _, _, _, _, _, classID = S.SafeCall(C_Item.GetItemInfoInstant, itemID)
    classID = S.PlainNumber(classID)
    if classID == nil then return false end
    local IC = Enum and Enum.ItemClass
    local weapon = IC and IC.Weapon or 2
    local armor  = IC and IC.Armor  or 4
    return classID == weapon or classID == armor
end

-- 事件給的名字可能帶伺服器；場次記錄裡存的是拆過的短名
local function ShortName(name)
    local short = name:match("^([^%-]+)%-")
    return short or name
end

local function RowFor(run, playerName)
    if type(run.players) ~= "table" then return nil end
    local want = ShortName(playerName)
    for _, p in ipairs(run.players) do
        if p.name == want or p.name == playerName then return p end
    end
    return nil
end

------------------------------------------------------------
-- 開窗／關窗
------------------------------------------------------------
function Loot.Open(run)
    if type(run) ~= "table" then return end
    target = run
    expiresAt = GetTime() + WINDOW_SEC
    generation = generation + 1
    local gen = generation
    C_Timer.After(WINDOW_SEC + 1, function()
        if gen ~= generation then return end
        Loot.Close()
    end)
end

function Loot.Close()
    target = nil
    expiresAt = nil
    generation = generation + 1
end

function Loot.IsOpen()
    return target ~= nil
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local function OnLootReceived(_, itemID, itemLink, quantity, playerName, _classFileName)
    if not target then return end
    if expiresAt and GetTime() > expiresAt then Loot.Close(); return end

    -- 每一個參數過守衛：秘密的一律當作沒拿到（存不進 SavedVariables）
    local link = S.PlainText(itemLink)
    local who  = S.PlainText(playerName)
    local id   = S.PlainNumber(itemID)
    if not link or not who then return end
    if id and not IsEquipment(id) then return end

    local row = RowFor(target, who)
    if not row then return end

    row.loot = row.loot or {}
    -- 同一件不重複記：事件偶爾會重送，而且數量對「一件裝備」沒有意義
    for _, existing in ipairs(row.loot) do
        if existing == link then return end
    end
    row.loot[#row.loot + 1] = link

    if ns.Panel then ns.Panel.OnLootAdded(target) end
end

function Loot.Init()
    if frame then return end
    frame = CreateFrame("Frame")

    -- ⚠ RegisterEvent 對不存在的事件會拋錯，而且是硬錯 —— 包起來，失敗記進錯誤表
    ns.SafeRegister(frame, "ENCOUNTER_LOOT_RECEIVED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "ENCOUNTER_LOOT_RECEIVED" then
            ns.Guard(OnLootReceived, ...)
        else
            -- 離開副本就收工：窗口的用意是「鑰石的尾箱」，換地圖之後收到的不算
            Loot.Close()
        end
    end)
end
