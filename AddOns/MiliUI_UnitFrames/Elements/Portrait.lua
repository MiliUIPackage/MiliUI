------------------------------------------------------------
-- 頭像：3D PlayerModel；拿不到就不畫（明確選 2D 模式才畫 2D）
--
-- 12.1 副本裡的敵人／首領是受限身分，SetUnit 拿不到模型。首領戰有合法後門：
-- Encounter Journal 的 EJ_GetCreatureInfo(index, encounterID) 回的 displayInfo 是明文
-- （暴雪冒險指南就是用它畫模型），ENCOUNTER_START 給 encounterID →
-- boss1..N 對應該戰第 1..N 隻生物；目標／專注若明文確定是 bossN 也套同一顆。
------------------------------------------------------------
local _, ns = ...

local Media = ns.Media

------------------------------------------------------------
-- 遭遇戰 displayID 表
------------------------------------------------------------
local encounterDisplays = {}      -- [index] = displayID（ENCOUNTER_START 建，ENCOUNTER_END 清）
local encounterActive = false

-- ENCOUNTER_START 給的是 DungeonEncounterID（DBM 那套），EJ 吃的是 JournalEncounterID，
-- 兩套 ID 空間不同 → 用玩家所在地圖找冒險指南 instance，列舉遭遇戰、比對第 7 個回傳值
-- dungeonEncounterID 來換算
local function JournalEncounterFromDungeon(dungeonEncounterID)
    if not (EJ_GetEncounterInfoByIndex and C_Map and C_Map.GetBestMapForUnit) then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local jInst
    if EJ_GetInstanceForMap then
        local ok, id = pcall(EJ_GetInstanceForMap, mapID)
        if ok and id and id > 0 then jInst = id end
    end
    if not jInst and C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap then
        local ok, id = pcall(C_EncounterJournal.GetInstanceForGameMap, mapID)
        if ok and id and id > 0 then jInst = id end
    end
    if not jInst then return nil end
    if EJ_SelectInstance then pcall(EJ_SelectInstance, jInst) end
    for i = 1, 40 do
        local ok, name, _, jEnc, _, _, _, dungeonEnc = pcall(EJ_GetEncounterInfoByIndex, i, jInst)
        if not ok or not name then break end
        if dungeonEnc == dungeonEncounterID then return jEnc end
    end
    return nil
end

local lastEncounterDebug = ""
local function BuildEncounterDisplays(dungeonEncounterID)
    wipe(encounterDisplays)
    if not (EJ_GetCreatureInfo and dungeonEncounterID) then return end
    local jEnc = JournalEncounterFromDungeon(dungeonEncounterID)
    lastEncounterDebug = ("dungeonEnc=%s journalEnc=%s"):format(
        tostring(dungeonEncounterID), tostring(jEnc))
    if not jEnc then return end
    for i = 1, 9 do
        local ok, _, _, _, displayInfo = pcall(EJ_GetCreatureInfo, i, jEnc)
        if not ok then break end
        if displayInfo == nil then break end
        if type(displayInfo) == "number" and displayInfo > 0 then
            tinsert(encounterDisplays, displayInfo)
        end
    end
end

-- ⚠ 常數表放檔案層級：下面那個迴圈每次頭像更新都跑，現配 "boss"..i 等於
-- 每次五顆字串，而 UNIT_PORTRAIT_UPDATE 在戰鬥中會反覆來（同檔下方有註記）
local BOSS_TOKENS = { "boss1", "boss2", "boss3", "boss4", "boss5" }

-- 這個單位在遭遇戰裡對應到哪顆 displayID（nil = 沒有）
local function EncounterDisplayFor(uf)
    if not encounterActive or #encounterDisplays == 0 then return nil end
    local idx = uf.bossIndex
    if not idx then
        -- 目標／專注：明文確定是 bossN 才套（UnitIsUnit 可能回秘密值 → 跳過）
        for i = 1, #BOSS_TOKENS do
            local m = UnitIsUnit(uf.unit, BOSS_TOKENS[i])
            if not ns.IsSecret(m) and m then idx = i; break end
        end
    end
    if not idx then return nil end
    -- 生物數少於首領框數時（例如三個附加單位共用一種模型）退到第一隻
    return encounterDisplays[idx] or encounterDisplays[1]
end

local function RefreshEncounterFrames()
    for _, unit in ipairs({ "boss1", "boss2", "boss3", "boss4", "boss5", "target", "focus" }) do
        local uf = ns.frames[unit]
        if uf and uf:IsVisible() and uf.elements.portrait then
            local edb = uf.db.elements.portrait
            if edb and edb.enabled ~= false then
                ns.Elements.portrait.update(uf, edb, "unitchanged")
            end
        end
    end
end

-- 給 /muf debug 看
function ns.GetEncounterDisplays()
    return encounterActive, encounterDisplays, lastEncounterDebug
end

ns.Events.Register("ENCOUNTER_START", "portrait_ej", function(encounterID)
    encounterActive = true
    BuildEncounterDisplays(encounterID)
    RefreshEncounterFrames()
end)
ns.Events.Register("ENCOUNTER_END", "portrait_ej_end", function()
    encounterActive = false
    wipe(encounterDisplays)
    RefreshEncounterFrames()
end)
ns.Events.Register("PLAYER_ENTERING_WORLD", "portrait_ej_pew", function()
    encounterActive = false
    wipe(encounterDisplays)
end)

------------------------------------------------------------
-- 空白模型自我修復（EUI 追出來的兩個坑）
--   * 世界轉場（載入畫面）會把 PlayerModel 的狀態清掉，同一個 guid 也不會重畫
--   * Show 後的重畫可能早於模型串流完成 → SetUnit 落空、之後沒有任何事件跟進
-- PORTRAITS_UPDATED 是客戶端「頭像資源串流完成」的訊號，用它補畫**還是空的**模型
------------------------------------------------------------
local function HealBlankModels()
    for _, uf in pairs(ns.frames) do
        local f = uf.elements and uf.elements.portrait
        local edb = uf.db and uf.db.elements and uf.db.elements.portrait
        if f and f.model and edb and edb.enabled ~= false and edb.mode == "3d"
           and uf:IsVisible() then
            local fid = f.model.GetModelFileID and f.model:GetModelFileID()
            if fid == nil then    -- 還是空的才重畫，已載入的不動（避免串流時反覆重載）
                f.modelKey = nil  -- ⚠ 一定要清：不清的話 update 會被「來源沒變」擋板短路
                ns.Elements.portrait.update(uf, edb, "unitchanged")
            end
        end
    end
end

ns.Events.Register("PORTRAITS_UPDATED", "portrait_heal", HealBlankModels)
ns.Events.Register("PLAYER_ENTERING_WORLD", "portrait_heal_pew", function()
    C_Timer.After(1, HealBlankModels)
end)

local function Build(uf, edb)
    local f = uf.elements.portrait or ns.CreateElementBase(uf, "portrait", "Frame", "BackdropTemplate")
    ns.ApplyElementBase(uf, f, edb)
    f.modelKey = nil        -- 設定可能改了模式／示範 ID，下次 Update 一律重載

    if not f.bg then
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints(f)
    end
    f.bg:SetTexture(Media.BarTexture(ns.db.global.barTexture))
    local c = edb.bg or { r = 0.165, g = 0.165, b = 0.165, a = 1 }
    -- 底色 alpha 0 = 去背（3D 模型直接浮在畫面上，首領框的「突出」效果靠這個）
    f.bg:SetVertexColor(c.r, c.g, c.b, c.a or 1)
    f.bg:SetShown((c.a or 1) > 0)

    if not f.model then
        f.model = CreateFrame("PlayerModel", nil, f)
        f.model:SetAllPoints(f)
    end
    f.model:SetFrameLevel(edb.level or 2)
    f.zoom = edb.zoom or 1                    -- 1 = 特寫臉，0 = 全身
    -- 旋轉存「度」（設定面板直觀），套用時轉弧度。
    -- 0 = 正面朝鏡頭；±25 左右是側身 3/4 視角；180 會看到背面
    f.rotation = math.rad(edb.rotation or 0)
    -- 模型在框內的平移（側身之後常會偏一邊，用這個推回來）。
    -- 模型空間 x=前後、y=左右、z=上下。實測：**+y 在畫面上就是往右**（不用取負），
    -- 所以設定值直接對應直覺方向：正 = 往右／往上
    f.modelX = edb.modelOffsetX or 0
    f.modelY = edb.modelOffsetY or 0

    if not f.tex2d then
        f.tex2d = f:CreateTexture(nil, "ARTWORK")
        f.tex2d:SetAllPoints(f)
        f.tex2d:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    end
    f.tex2d:Hide()

    f:Show()
end

-- 印布林值：12.1 的 Unit API 可能回秘密值，tostring 出來會是 <secret boolean>
local function Probe(v)
    if ns.IsSecret(v) then return "secret" end
    return tostring(v)
end

local function Update(uf, edb, bucket)
    local f = uf.elements.portrait
    if not f then return end
    local unit = uf.isPreview and "player" or uf.unit
    -- ⚠ UNIT_MODEL_CHANGED **不是**「模型換了」的可靠訊號：實測增強薩滿在戰鬥中
    -- 每幾秒就來一次（武器附魔／光效那類純視覺變化也會推它）。而任何一次
    -- SetUnit 都會讓模型重新串流、空一兩幀 ⇒ 肉眼可見的閃爍。
    --   戰鬥外  照樣強制重載：換裝／幻化才吃得到，站著偶爾閃一下沒人在意
    --   戰鬥中  完全不碰模型，交給下面的 key 比對。玩家的變身有算進 key，
    --           所以變身照樣會換模型（那一次閃是應該的，模型真的變了）
    -- UNIT_PORTRAIT_UPDATE（portrait 桶）在 3D 模式下沒事要做，一律不清 key。
    if bucket == "model" and not InCombatLockdown() then f.modelKey = nil end

    if edb.mode == "3d" then
        -- ⚠ PlayerModel 在**隱藏時會丟掉模型**（EUI 實地追出來的：載入畫面隱藏框架後，
        -- 對隱藏的 model 呼叫 SetUnit 會落空、之後 Show 出來就是永久空白——這正是
        -- 「一個目標沒模型之後，所有目標都沒模型」的成因）。
        -- 對策：model 永遠保持 Show，拿不到就 ClearModel（清空＝看不見，效果等同隱藏）
        f.model:Show()
        f.tex2d:Hide()

        local ok
        -- 預覽：敵對示範單位（目標／專注／首領）用示範模型（預設薩拉塔斯 131474）
        local demoID = uf.isPreview and not uf.cache.pc and (ns.db.global.previewBossDisplayID or 131474)
        -- 真實遭遇戰：EJ 給的首領 displayID（受限身分下唯一拿得到 3D 的路）
        local ejID = not uf.isPreview and EncounterDisplayFor(uf)

        ------------------------------------------------------------
        -- 同一個來源就不要重載模型。
        -- ClearModel + SetUnit 會把模型整個重讀，是這個元件最貴的動作；而它掛在
        -- identity 全量刷新上，identity 又是被 UNIT_FLAGS / UNIT_FACTION /
        -- GROUP_ROSTER_UPDATE 這些跟「換人」無關的事件推動的（體檢報告 P2）——
        -- 不擋的話進出一次戰鬥就重載一次模型。
        -- 比不出來（GUID 是秘密或拿不到）就回 nil = 照舊重載，失敗方向朝正確。
        ------------------------------------------------------------
        local key
        if demoID and demoID > 0 then
            key = "d" .. demoID
        elseif ejID then
            key = "e" .. ejID
        else
            local guid = UnitGUID(unit)
            if guid ~= nil and not ns.IsSecret(guid) then
                key = guid
                -- 變身（德魯伊型態、幽魂之狼…）不換 GUID，但模型整個不一樣。
                -- 型態進 key，戰鬥中變身照樣重載，而武器光效那種不會。
                if uf.baseUnit == "player" and GetShapeshiftFormID then
                    key = key .. ":" .. tostring(GetShapeshiftFormID())
                end
            end
        end
        if key and key == f.modelKey then
            -- 模型已經在上面了，只重套鏡頭參數（設定可能剛改過）。
            -- ⚠ 這裡**絕對不要**再呼叫 SetUnit「順便刷新一下」。試過了：即使不做
            -- ClearModel，光是 SetUnit 到同一個單位也會讓模型重新串流、空一兩幀
            -- ⇒ 一樣閃。想避免閃就只有一條路：不要碰模型。
            pcall(f.model.SetPortraitZoom, f.model, f.zoom or 1)
            pcall(f.model.SetRotation, f.model, f.rotation or 0)
            pcall(f.model.SetPosition, f.model, 0, f.modelX or 0, f.modelY or 0)
            return
        end

        if demoID and demoID > 0 then
            pcall(f.model.ClearModel, f.model)
            ok = pcall(f.model.SetDisplayInfo, f.model, demoID)
        elseif ejID then
            pcall(f.model.ClearModel, f.model)
            ok = pcall(f.model.SetDisplayInfo, f.model, ejID)
        else
            -- 可用 = 已連線且可見（EUI 的 isAvailable）。SetUnit 對載不進來的單位不會清空，
            -- 而是留上一個模型或退回預設（widget 就叫 PlayerModel，預設是玩家自己）
            local avail = UnitIsConnected(unit) and UnitIsVisible(unit)
            if ns.IsSecret(avail) then avail = true end
            -- 12.1 受限身分單位（副本裡的敵人）拿不到模型；UnitName 是不是秘密 = 直接探針
            if avail and ns.IsSecret(UnitName(unit)) then avail = false end
            if avail then
                pcall(f.model.ClearModel, f.model)
                local pok, ret = pcall(f.model.SetUnit, f.model, unit)
                ok = pok and ret ~= false
                -- 失敗原因留給 /muf debug：「載不到」在受限身分以外還有別的可能
                -- （轉場中、模型還在串流），分不出來就只能猜
                if not ok then
                    f.modelFailWhy = pok and "SetUnit 回 false（還在串流？）" or "SetUnit 出錯"
                end
            else
                ok = false
                f.modelFailWhy = ("不可用（連線=%s 可見=%s 名字secret=%s）"):format(
                    Probe(UnitIsConnected(unit)), Probe(UnitIsVisible(unit)),
                    tostring(ns.IsSecret(UnitName(unit))))
            end
        end

        -- ⚠ 這個數字有兩種來源，查閃爍時一定要分開看（/muf debug 兩個都印）：
        --   載得到 → 真的重串流了一次模型，只有這種會在畫面上閃
        --   載不到 → 12.1 受限身分（副本裡的敵人）給不出模型，頭像本來就是空的；
        --            而且 key latch 不上，之後每次刷新都會再試一次 ⇒ 數字照樣一直跳，
        --            但畫面上什麼事都沒發生。副本裡數字衝高幾乎都是這一種。
        f.modelReloads = (f.modelReloads or 0) + 1
        f.modelLastBucket = bucket

        if ok then
            -- ⚠ 這裡**無條件**記 key，曾經加過「GetModelFileID 非 nil 才記」的閘，拿掉了。
            -- 理由不是那個 API 壞掉——實測 SetUnit 的模型回得出 fileID（/muf debug 看得到）
            -- ——而是：
            --   1. 多餘。「SetUnit 回成功但模型還在串流」那個情境（登入當下）本來就由
            --      HealBlankModels 收，它會先清 key 再重畫，PEW 後 1 秒的計時器夠可靠。
            --   2. 有反效果的風險。首領框走 SetDisplayInfo，那條路回不回得出 fileID
            --      沒驗證過；若回 nil，加了閘就永遠 latch 不上 → 每次刷新都重載。
            f.modelKey = key
            pcall(f.model.SetPortraitZoom, f.model, f.zoom or 1)
            pcall(f.model.SetRotation, f.model, f.rotation or 0)
            pcall(f.model.SetPosition, f.model, 0, f.modelX or 0, f.modelY or 0)
        else
            f.modelKey = nil        -- 沒載成功，下次要再試
            f.modelBlanks = (f.modelBlanks or 0) + 1
            f.modelFailBucket = bucket
            -- 拿不到就清空（不 Hide！）
            pcall(f.model.ClearModel, f.model)
            -- 副本小怪是受限身分，SetUnit 不會報錯也不會退回玩家，就是給不出東西
            -- （實測 ok=true / modelFileID=nil）。但 2D 是 C 端自己解單位的，
            -- 同一隻怪 SetPortraitTexture 拿得到（暴雪原生目標框走的就是這條）。
            -- 預設不開：使用者要的是「寧可空著也不要 2D」，想要時逐單位打開
            if edb.fallback2D then
                pcall(SetPortraitTexture, f.tex2d, unit)
                f.tex2d:SetShown(f.tex2d:GetTexture() ~= nil)
            end
        end
        return
    end

    -- 明確選 2D 模式才畫 2D。
    -- ⚠ 清空而不是 Hide：這個檔案上方立過規矩「model 永遠保持 Show，拿不到就
    -- ClearModel()，絕不 Hide」—— 對隱藏中的 model 呼叫 SetUnit 會落空，之後
    -- Show 出來就永久空白。清空的 model 不畫任何東西，視覺結果跟 Hide 一樣。
    pcall(f.model.ClearModel, f.model)
    f.modelKey = nil
    if pcall(SetPortraitTexture, f.tex2d, unit) then
        f.tex2d:Show()
    else
        f.tex2d:Hide()
    end
end

ns.RegisterElement{
    name = "portrait",
    order = 10,
    buckets = { "portrait", "model" },   -- 換人另走 unitchanged
    build = Build,
    update = Update,
}
