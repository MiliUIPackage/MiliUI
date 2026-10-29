------------------------------------------------------------
-- 「單位 → 玩家 → 資源條」面板的內容
--
-- 資源條是玩家框的元件（classpower），表單掛在單位分頁的 chip 列裡
-- （Options/Tab_Unit.lua），不再是頂層分頁。這一支只負責**內容**；面板本身
-- （content frame、捲軸、快取、重建、捲動位置）歸 Tab_Unit 管。分工：
--
--   ResourceForm.Controls()   現算的控件清單（Tab_Unit 的 SpecsFor 與設定搜尋都走這支）
--   ResourceForm.ctx          這個面板專用的 ctx（三件 Tab_Unit 通用 ctx 沒有的語意，見下）
--   ResourceForm.Signature()  控件清單「長相」的簽章；Tab_Unit 建表時記下、顯示前比對，
--                             不同就丟掉重建
--
-- 資源清單是**跟著專精（德魯伊是型態）走的**（Ayije_CDM 的做法），所以控件不能像其他
-- 元件那樣建一次就一直重用 —— 換專精之後可選項目會整個換掉。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local Controls = ns.Controls

-- ⚠ ctx 要**前置宣告**：BuildControls 的「還原預設」「從冷卻管理器複製」按鈕要呼叫
-- ctx.apply，而 ctx 定義在它下面 —— 不先宣告成 local 的話，那個名字在函式體裡會編成
-- 全域查表、執行時抓到 nil 而靜默失效（這個 repo 已經踩過兩次，見
-- Elements/ClassPower.lua 的 LayoutMatches 那段）。
local ctx

local function EDB()
    local u = ns.db.units.player
    return u and u.elements and u.elements.classpower
end

-- 目前專精的在地化名稱（GetSpecializationInfo 的第二個回傳值）。拿不到回 nil
local function SpecName()
    local getSpec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
    local getInfo = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo) or GetSpecializationInfo
    if not (getSpec and getInfo) then return nil end
    local ok, idx = pcall(getSpec)
    if not ok or not idx then return nil end
    local ok2, _, name = pcall(getInfo, idx)
    if not ok2 then return nil end
    name = ns.Desecret(name, nil)
    if type(name) ~= "string" or name == "" then return nil end
    return name
end

-- 主資源的 token（"INSANITY"、"RAGE"…，UnitPowerType 的第二個回傳值）。
-- UnitPowerType 對玩家自己是明文，但照 ClassPower.lua 的慣例一律過 pcall／Desecret
-- （進載具、被控時來源會變）。拿不到回 nil
local function PrimaryToken()
    local ok, _, token = pcall(UnitPowerType, "player")
    if not ok then return nil end
    token = ns.Desecret(token, nil)
    if type(token) ~= "string" or token == "" then return nil end
    return token
end

-- 主資源的在地化名稱：暴雪全域字串（_G.INSANITY ＝「瘋狂值」之類，官方譯名）。拿不到回 nil
local function PrimaryName()
    local token = PrimaryToken()
    local name = token and _G[token]
    if type(name) ~= "string" or name == "" then return nil end
    return name
end

-- 回傳控件清單（每次現算：清單跟著專精／型態／跟隨狀態走）
local function BuildControls()
    local cand = ns.ResourceCandidates()
    local followActive, cdmAvail = ns.ResourceFollowsCDM(EDB())
    local list = {
        { type = "toggle", key = "enabled", label = L["Show resource bars"] },
    }

    -- 頁首：這個專精（型態）顯示的是哪些資源、主資源在哪裡設定。
    -- 資源名用暴雪的官方譯名（ResourceInfo.name，見 ClassPower.lua 的 PowerName）。
    -- ⚠ text 是建表當下定死的字串 ⇒ 會讓這兩行變的東西（專精、候選、主資源）都在
    -- Signature 裡，換專精／型態之後 Tab_Unit 會重建，不會停在舊的
    local names = {}
    for _, key in ipairs(cand) do
        local info = ns.ResourceInfo(key)
        names[#names + 1] = (info and info.name) or key
    end
    local specName = SpecName()
    if specName and #names > 0 then
        list[#list + 1] = { type = "text",
            label = L["Current specialization %s: shows %s"]:format(specName,
                table.concat(names, LIST_DELIMITER or ", ")) }
    end
    local primary = PrimaryName()
    if primary then
        list[#list + 1] = { type = "text",
            label = L["The main resource (%s) is shown by the player frame's \"%s\"; set it up there."]
                :format(primary, L["Power bar"]) }
    end

    local layout = {
        { type = "text",   label = L["Anchored below the player frame, stacking downward. Which resources appear follows your specialization and switches automatically."] },
        { type = "header", label = L["Position and size"] },
        { type = "numbers", label = L["Position"], fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } },
        { type = "text",   label = L["Offset from the bottom-left corner of the player frame (negative goes down)."] },
        { type = "slider", key = "totalw",     label = L["Total width"],   min = 40, max = 400, step = 2 },
        { type = "slider", key = "h",          label = L["Row height"], min = 2,  max = 30,  step = 1 },
        { type = "slider", key = "rowSpacing", label = L["Row spacing"],   min = 0,  max = 12,  step = 1 },
        { type = "slider", key = "spacing",    label = L["Segment spacing"], min = 0, max = 8,  step = 1 },
        { type = "text",   label = L["Segment spacing only affects point-style resources (Holy Power, combo points and the like)."] },
        { type = "dropdown", key = "fillDirection", label = L["Fill direction"], items = ns.Specs.FILL_DIRECTION_ITEMS },
        { type = "text",   label = L["Right to left also lights point-style resources from the right: the first point is the rightmost segment."] },
        { type = "slider", key = "level",      label = L["Layer"],   min = 0,  max = 15,  step = 1 },
        { type = "header", label = L["Appearance"] },
        { type = "slider", key = "barAlpha", label = L["Fill opacity"], min = 0.1, max = 1, step = 0.05 },
        { type = "toggle", key = "showText", label = L["Show value on the bar"] },
    }
    for _, spec in ipairs(layout) do list[#list + 1] = spec end

    if ns.playerClass == "DEATHKNIGHT" then
        list[#list + 1] = { type = "dropdown", key = "runeText", label = L["Numbers on runes"], items = {
            { text = L["Seconds left on each rune"], value = "countdown" },
            { text = L["Ready runes count"],         value = "count" },
        } }
        list[#list + 1] = { type = "text", label = L["Ready runes always line up on the left and recharging ones fill up on the right. With \"Show value on the bar\" on, pick one number: the seconds left on each recharging rune, or how many runes are ready in the middle."] }
        list[#list + 1] = { type = "toggle", key = "runeQueued", label = L["Count waiting runes"] }
        list[#list + 1] = { type = "text", label = L["Only three runes recharge at a time; the rest wait their turn. With this on, waiting runes also show the seconds until they're ready and fill up across the whole wait."] }
    end

    ---------------------------------------------------------
    -- 顏色與條件
    --
    -- 兩個插件都裝的人本來就希望兩邊長得一致，所以有冷卻管理器插件在的時候給一個
    -- 「跟它一樣」的開關；勾著就不列色塊也不列條件編輯器（列了也沒用，畫面上
    -- 不會照它走），改放一行說明 ＋ 一行唯讀摘要講清楚現在由誰決定。
    --
    -- ⚠ **顏色與條件共用同一個開關**，不拆成兩個：條件的覆寫色跟基底色是一套的，
    -- 拆開就會出現「自己的底色＋別人的條件色」這種沒人要的組合。
    ---------------------------------------------------------
    if cdmAvail or #cand > 0 then
        list[#list + 1] = { type = "header", label = L["Colors and conditions"] }
    end
    if cdmAvail then
        list[#list + 1] = { type = "toggle", key = "followAyije", label = L["Follow the cooldown manager's colors"] }
    end
    if followActive then
        list[#list + 1] = { type = "text",
            label = L["Colors and condition rules both come from the cooldown manager addon's resource bar settings. Uncheck this to set your own here."] }
        -- 條件沒成立時畫面跟「沒設條件」長得一模一樣 ⇒ 光看框看不出有沒有吃到。
        -- 列一行「那邊各有幾條」讓玩家確認得了（那一列每次顯示面板都會自己重算，
        -- 玩家在關著這一頁的時候去冷卻管理器改規則也不會停在舊數字）
        local summary = ns.ResourceConditions.SummarySpec(cand)
        if summary then list[#list + 1] = summary end
    else
        if cdmAvail then
            list[#list + 1] = { type = "button", label = L["Copy"], text = L["Copy from the cooldown manager"],
                width = 180,
                confirm = L["Replace the resource colors and condition rules here with the cooldown manager's current ones?"],
                onClick = function()
                    local edb = EDB()
                    if not edb then return end
                    -- 深複製（見 ClassPower.lua 的 ResourceCopyFromCDM）：絕對不能
                    -- 持有它的表，色票是原地改寫的，會改壞別人的存檔
                    ns.ResourceCopyFromCDM(edb)
                    ns.ResourceConditions.MarkRebuild()
                    ctx.apply()
                end }
            list[#list + 1] = { type = "text",
                label = L["Takes a one-off snapshot of the cooldown manager's colors and rules. After that the two are independent — changes there no longer show up here."] }
        end
        for _, key in ipairs(cand) do
            local info = ns.ResourceInfo(key)
            -- 色塊的標籤直接用資源名（暴雪的官方譯名，見 ClassPower.lua 的 PowerName）
            list[#list + 1] = { type = "color", sub = "colors", sub2 = key, key = "color",
                                label = info and info.name or key, hasAlpha = false }
            if key == "ComboPoints" then
                list[#list + 1] = { type = "color", sub = "colors", sub2 = key, key = "chargedColor",
                                    label = L["Charged color"], hasAlpha = false }
                list[#list + 1] = { type = "color", sub = "colors", sub2 = key, key = "chargedEmptyColor",
                                    label = L["Charged (empty)"], hasAlpha = false }
                list[#list + 1] = { type = "text",
                    label = L["Some combo points become charged (the Rogue's Supercharger, the Feral druid's Overflowing Power). The dim shade marks a charged point you haven't filled yet."] }
            end
        end
        -- 條件編輯器（Options/ResourceConditions.lua）
        if #cand > 0 then
            ns.ResourceConditions.Append(list, cand, ctx)
        end
    end

    list[#list + 1] = { type = "header", label = L["Show for this specialization"] }
    -- 候選是空的時候這個面板根本不會出現（Tab_Unit 的 chip 會藏起來），
    -- 所以不再留「這個專精沒有資源」那個分支
    for _, key in ipairs(cand) do
        local info = ns.ResourceInfo(key)
        list[#list + 1] = { type = "toggle", sub = "resources", key = key,
                            label = info and info.name or key, default = true }
    end
    list[#list + 1] = { type = "text",
        label = L["Absorb-style resources (Stagger, Ironfur, Ignore Pain) are secret values in 12.1 — addons can't read the numbers, so they aren't listed."] }

    list[#list + 1] = { type = "header", label = L["Reset"] }
    list[#list + 1] = { type = "button", label = L["Restore defaults"], text = L["Restore resource defaults"], color = "red",
        confirm = L["Restore the resource bar settings to their defaults?"],
        onClick = function()
            local edb = EDB()
            if not edb then return end
            local def = ns.DB.BuildDefaults().units.player.elements.classpower
            for k in pairs(edb) do edb[k] = nil end
            for k, v in pairs(def) do edb[k] = v end
            -- ⚠ 走 ctx.apply 不是直接 ApplySettings：還原之後 followAyije 回到 nil
            -- （冷卻管理器有載入就等於重新跟隨）⇒ 色塊那幾列要跟著消失，
            -- 而「該不該重建控件」的判斷在 apply（與 Tab_Unit 的簽章比對）裡。
            -- 條件規則也被清光了，列數一定變 ⇒ 直接舉手要重建（冷卻管理器沒載入時
            -- followAyije 前後都是 false，光靠簽章比不出來）
            ns.ResourceConditions.MarkRebuild()
            ctx.apply()
        end }

    return list
end

------------------------------------------------------------
-- ctx：Tab_Unit 的通用 ctx 沒有的三件事，缺一不可
--   1. followAyije 是三態，get 回**生效值**
--   2. 色塊（sub = "colors", sub2 = key）的 get 在 edb 裡自動建自己的表，
--      絕不回共用預設表或冷卻管理器的表
--   3. apply 先 Reevaluate 再 ApplySettings，並處理條件編輯器舉手的結構性重建
------------------------------------------------------------
ctx = {
    get = function(spec)
        local edb = EDB()
        if not edb then return nil end
        -- ⚠ followAyije 是三態，nil ＝「玩家沒碰過 ⇒ 冷卻管理器有載入就跟隨」。
        -- 把原始的 nil 交給勾選框會顯示成「沒勾」，但畫面上其實正在跟隨 ⇒
        -- 玩家看到的跟顏色對不起來。所以這個鍵回**生效值**。
        if spec.key == "followAyije" and not spec.sub then
            return (ns.ResourceFollowsCDM(edb))
        end
        -- ⚠⚠ 色塊的寫入是「ctx.get 拿到 table 就**原地改**」（見共用層
        -- Controls.lua 的 color 分支）⇒ 這裡絕對不能回傳共用的預設表或冷卻管理器的表，
        -- 否則調一次顏色就默默改壞別人的資料。DB 預設已經保證
        -- edb.colors[key][field] 存在；萬一不在（匯入了更舊的字串之類）
        -- 就先在 edb 裡建一張自己的再回。
        if spec.sub == "colors" and spec.sub2 then
            local root = edb.colors
            if not root then root = {}; edb.colors = root end
            local t = root[spec.sub2]
            if not t then t = {}; root[spec.sub2] = t end
            local c = t[spec.key]
            if type(c) ~= "table" then
                local d = ns.ResourceDefaultColor and ns.ResourceDefaultColor(spec.sub2, spec.key)
                c = { r = (d and d.r) or 1, g = (d and d.g) or 1, b = (d and d.b) or 1 }
                t[spec.key] = c
            end
            return c
        end
        local t = Controls.Resolve(edb, spec)
        if not t then return spec.default end
        local v = t[spec.key]
        if v == nil then return spec.default end
        return v
    end,
    set = function(spec, v)
        local edb = EDB()
        if not edb then return end
        if spec.sub and not edb[spec.sub] then edb[spec.sub] = {} end
        if spec.sub and spec.sub2 and not edb[spec.sub][spec.sub2] then
            edb[spec.sub][spec.sub2] = {}
        end
        local t = Controls.Resolve(edb, spec)
        if t then t[spec.key] = v end
    end,
    apply = function()
        -- 資源清單／格數可能一起變 → 逼引擎重排，不只是重畫。
        -- Reevaluate 尾端會 Fire("ResourceCandidatesChanged")，Tab_Unit 收到後延一幀比對
        -- Signature —— 「跟隨冷卻管理器」切換（跟隨狀態在簽章裡）造成的控件清單變動
        -- 走那一條重建，這裡不必再比一次。
        if ns.ResourceReevaluate then ns.ResourceReevaluate() end
        ns.ApplySettings("player")
        -- 條件編輯器的列數也會變（增刪規則／檢查、上移、換編輯對象、換目標），但簽章
        -- 看不出來 ⇒ 那邊自己舉手（MarkRebuild）。⚠ 一定要無條件 Consume，不然旗標會留到
        -- 下一次改滑桿時才被讀到，變成「拖個透明度整頁突然重建」。
        -- ⚠ 不能在按鈕自己的 OnClick 裡當場重建 —— 那是在處理器裡把它的父框丟掉。
        -- RebuildUnitPanel 自己延一幀，同一幀的多次請求（含簽章那條）合併成一次重建。
        -- keepScroll：「跟隨」勾選框與條件編輯器都在頁面中段，每按一次就被彈回頂端
        -- 等於把使用者踢走。
        -- ⚠ 共用層（Libs/MiliUIWidgets）沒有 onChange 也沒有 disabled 機制，
        -- **不要為了這個需求去改共用層** —— 那是十幾個插件共用的 vendor 複製。
        local structural = ns.ResourceConditions.ConsumeRebuild()
        if structural and ns.Options.RebuildUnitPanel then
            ns.Options.RebuildUnitPanel("player", "classpower", true)
        end
    end,
}

-- 控件清單長相的簽章。會改變 BuildControls 結果的東西都要在這裡：
--   專精          頁首的專精名、候選清單
--   候選清單      德魯伊換型態時專精不變、清單會變；天賦也會讓某些資源出現／消失
--   主資源 token  頁首「主資源由能量條顯示」那一行
--   跟隨狀態      色塊與條件編輯器整段出現／消失（玩家可能在關著這一頁時才啟用／停用
--                 冷卻管理器插件）
-- 條件規則的條數不在這裡 —— 那邊走 MarkRebuild 舉手；換設定檔由 Tab_Unit 整批丟掉重建。
local function Signature()
    local cand, specID = ns.ResourceCandidates()
    local follow = ns.ResourceFollowsCDM(EDB())
    return table.concat({
        tostring(specID or 0), table.concat(cand, ","), tostring(PrimaryToken()),
        follow and "follow" or "own",
    }, "|")
end

ns.Options.ResourceForm = {
    Controls  = BuildControls,
    ctx       = ctx,
    Signature = Signature,
}
