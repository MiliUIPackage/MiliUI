------------------------------------------------------------
-- 「資源」分頁
--
-- 資源清單是**跟著專精走的**（Ayije_CDM 的做法），所以控制項不能像其他分頁那樣
-- 在 Init 時建一次就算了 —— 換專精之後可選項目會整個換掉。用 specSig 比對，
-- 變了就把內容框整個丟掉重建。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, Controls = ns.W, ns.Controls

-- ⚠ ctx 與 Rebuild 都要**前置宣告**：BuildControls 的「還原預設」按鈕要呼叫 ctx.apply，
-- 而 ctx.apply 要呼叫 Rebuild —— 兩邊都是「用在定義之前」。不先宣告成 local 的話，
-- 那兩個名字在函式體裡會編成全域查表、執行時抓到 nil 而靜默失效
-- （這個 repo 已經踩過兩次，見 Elements/ClassPower.lua 的 LayoutMatches 那段）。
local tab, scroll, content, refreshers, specSig, rows, ctx, Rebuild
-- 上一次建表時「跟隨 Ayije」是不是生效中。切換之後控件清單會整個換掉 ⇒ 要重建
local builtFollow

local function EDB()
    local u = ns.db.units.player
    return u and u.elements and u.elements.classpower
end

-- 回傳 控件清單, 專精ID, 這次是不是「跟隨 Ayije」
local function BuildControls()
    local cand, specID = ns.ResourceCandidates()
    local followActive, ayijeAvail = ns.ResourceFollowsAyije(EDB())
    local list = {
        { type = "toggle", key = "enabled", label = L["Show resource bars"] },
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

    ---------------------------------------------------------
    -- 顏色與條件
    --
    -- 兩個插件都裝的人本來就希望兩邊長得一致，所以 Ayije_CDM 在的時候給一個
    -- 「跟它一樣」的開關；勾著就不列色塊也不列條件編輯器（列了也沒用，畫面上
    -- 不會照它走），改放一行說明 ＋ 一行唯讀摘要講清楚現在由誰決定。
    --
    -- ⚠ **顏色與條件共用同一個開關**，不拆成兩個：條件的覆寫色跟基底色是一套的，
    -- 拆開就會出現「自己的底色＋別人的條件色」這種沒人要的組合。
    ---------------------------------------------------------
    if ayijeAvail or #cand > 0 then
        list[#list + 1] = { type = "header", label = L["Colors and conditions"] }
    end
    if ayijeAvail then
        list[#list + 1] = { type = "toggle", key = "followAyije", label = L["Same as Ayije_CDM"] }
    end
    if followActive then
        list[#list + 1] = { type = "text",
            label = L["Colors and condition rules both come from Ayije_CDM's own resource bar settings. Uncheck this to set your own here."] }
        -- 條件沒成立時畫面跟「沒設條件」長得一模一樣 ⇒ 光看框看不出有沒有吃到。
        -- 列一行「那邊各有幾條」讓玩家確認得了（那一列每次開分頁都會自己重算，
        -- 玩家在關著這一頁的時候去 Ayije_CDM 改規則也不會停在舊數字）
        local summary = ns.ResourceConditions.SummarySpec(cand)
        if summary then list[#list + 1] = summary end
    else
        if ayijeAvail then
            list[#list + 1] = { type = "button", label = L["Copy"], text = L["Copy from Ayije_CDM"],
                width = 180,
                confirm = L["Replace the resource colors and condition rules here with Ayije_CDM's current ones?"],
                onClick = function()
                    local edb = EDB()
                    if not edb then return end
                    -- 深複製（見 ClassPower.lua 的 ResourceCopyFromAyije）：絕對不能
                    -- 持有它的表，色票是原地改寫的，會改壞別人的存檔
                    ns.ResourceCopyFromAyije(edb)
                    ns.ResourceConditions.MarkRebuild()
                    ctx.apply()
                end }
            list[#list + 1] = { type = "text",
                label = L["Takes a one-off snapshot of Ayije_CDM's colors and rules. After that the two are independent — changes there no longer show up here."] }
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

    if #cand == 0 then
        list[#list + 1] = { type = "text",
            label = L["This specialization has no extra resource to show, so the whole row collapses. Mana is deliberately not listed here: the unit frame's own power bar already shows it."] }
    else
        for _, key in ipairs(cand) do
            local info = ns.ResourceInfo(key)
            list[#list + 1] = { type = "toggle", sub = "resources", key = key,
                                label = info and info.name or key, default = true }
        end
        list[#list + 1] = { type = "text",
            label = L["Absorb-style resources (Stagger, Ironfur, Ignore Pain) are secret values in 12.1 — addons can't read the numbers, so they aren't listed."] }
    end

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
            -- （Ayije_CDM 有載入就等於重新跟隨）⇒ 色塊那幾列要跟著消失，
            -- 而「該不該重建控件」的判斷在 apply 裡。
            -- 條件規則也被清光了，列數一定變 ⇒ 直接舉手要重建（Ayije 沒載入時
            -- followAyije 前後都是 false，光靠它比不出來）
            ns.ResourceConditions.MarkRebuild()
            ctx.apply()
        end }

    return list, specID, followActive
end

ctx = {
    get = function(spec)
        local edb = EDB()
        if not edb then return nil end
        -- ⚠ followAyije 是三態，nil ＝「玩家沒碰過 ⇒ Ayije 有載入就跟隨」。
        -- 把原始的 nil 交給勾選框會顯示成「沒勾」，但畫面上其實正在跟隨 ⇒
        -- 玩家看到的跟顏色對不起來。所以這個鍵回**生效值**。
        if spec.key == "followAyije" and not spec.sub then
            return (ns.ResourceFollowsAyije(edb))
        end
        -- ⚠⚠ 色塊的寫入是「ctx.get 拿到 table 就**原地改**」（見共用層
        -- Controls.lua 的 color 分支）⇒ 這裡絕對不能回傳共用的預設表或 Ayije 的表，
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
        -- 資源清單／格數可能一起變 → 逼引擎重排，不只是重畫
        if ns.ResourceReevaluate then ns.ResourceReevaluate() end
        ns.ApplySettings("player")
        -- 「跟隨 Ayije」切掉之後控件清單整個換掉（色塊與條件編輯器出現／消失）⇒ 要重建。
        -- ⚠ 不能在 toggle 自己的 OnClick 裡當場重建 —— 那是在按鈕的處理器裡把它的
        -- 父框丟掉。延一幀讓這一輪點擊跑完再換。
        -- ⚠ 共用層（Libs/MiliUIWidgets）沒有 onChange 也沒有 disabled 機制，
        -- **不要為了這一個需求去改共用層** —— 那是十個插件共用的 vendor 複製。
        -- 比對「上次建表時的跟隨狀態」就夠了。
        --
        -- 條件編輯器的列數也會變（增刪規則／檢查、上移、換編輯對象、換目標），
        -- 那邊自己舉手（MarkRebuild）。⚠ 一定要無條件 Consume，不然旗標會留到下一次
        -- 改滑桿時才被讀到，變成「拖個透明度整頁突然重建」。
        local structural = ns.ResourceConditions.ConsumeRebuild()
        local followNow = ns.ResourceFollowsAyije(EDB())
        if tab and (structural or builtFollow ~= followNow) then
            C_Timer.After(0, function()
                Rebuild(true)
                for _, fn in ipairs(refreshers) do fn() end
            end)
        end
    end,
}

-- ⚠ 一定要放在卷軸裡：這一頁的長度跟著專精走（資源多的專精會多好幾列開關），
-- 直接鋪在 tab 上的話，內容一長就會整段掉出面板外面
--
-- keepScroll：重建之後把捲動位置放回去。「跟隨 Ayije」那個勾選框在頁面中段，
-- 每按一次就被彈回頂端的話等於把使用者踢走。
function Rebuild(keepScroll)
    local offset = (keepScroll and scroll) and scroll:GetVerticalScroll() or 0
    local controls, specID, followActive = BuildControls()
    -- 舊的內容框留著（frame 刪不掉），藏起來就好
    if content then content:Hide() end
    content, rows, refreshers = ns.Options.BuildScrollBody(scroll, controls, ctx, 620)
    scroll:SetVerticalScroll(0)
    specSig = specID or 0
    builtFollow = followActive
    -- ⚠ 要延一幀才設得準：內容高度剛換過，這一幀 GetVerticalScrollRange 還是舊值，
    -- 直接設會被舊的上限夾掉（新內容比較短時就會夾出一個看起來隨機的位置）
    if offset > 0 then
        C_Timer.After(0, function()
            scroll:SetVerticalScroll(math.min(offset, scroll:GetVerticalScrollRange() or 0))
        end)
    end
end

local function Init()
    if tab then return end
    tab, scroll = ns.Options.MakeFormTab(L["Resource bars"])
    Rebuild()
end

-- 換設定檔時，正開著的這一頁要重整。
-- ⚠ ctx 是現查 ns.db 所以**寫入**一直都正確，錯的是**控件顯示值** —— 那是 refresher
-- 推上去的，而 refresher 只在 ShowOptionsTab 跑。原本只有「單位」分頁訂了這個事件，
-- 所以停在這一頁換設定檔會看到顏色與滑桿全停在舊值，切走再切回來才對。
ns.RegisterCallback("ProfileChanged", "resourceTabProfile", function()
    if tab and tab:IsShown() then
        -- ⚠ 一律重建，不是只在 followAyije 變了的時候：別份設定檔的**條件規則**
        -- 條數也不一樣，而規則的列數決定整頁的長相，只推值推不出來。
        -- 換設定檔很罕見，一次重建的孤兒 frame 換掉「換檔之後這一頁是錯的」划算
        Rebuild()
        for _, fn in ipairs(refreshers) do fn() end
    elseif tab then
        -- 這一頁關著的時候換設定檔：規則列數一樣可能不同，但現在重建沒人看。
        -- 把專精簽章作廢，下次 ShowOptionsTab 比對不上就會重建
        specSig = nil
    end
end)

ns.RegisterCallback("ShowOptionsTab", "resourceTab", function(id)
    if id ~= "resource" then
        if tab then tab:Hide() end
        return
    end
    Init()
    local _, specID = ns.ResourceCandidates()
    -- 跟隨狀態也要比：玩家可能在關著這一頁的時候才啟用／停用 Ayije_CDM
    if specSig ~= (specID or 0) or builtFollow ~= ns.ResourceFollowsAyije(EDB()) then
        Rebuild()
    end
    for _, fn in ipairs(refreshers) do fn() end
    tab:Show()
end)

------------------------------------------------------------
-- 設定搜尋（Options/Search.lua）
--
-- ⚠ 這一頁的內容跟著目前專精走（資源清單不一樣），所以列舉時**現算**一次，
-- 不快取。索引本身會在 SettingsApplied／ProfileChanged 時失效重建。
------------------------------------------------------------
ns.Search.Register("resource", {
    label = L["Resources"],
    enumerate = function(add) add((BuildControls()), L["Resources"]) end,
    jump = function(_, spec)
        Init()
        ns.Search.Reveal(scroll, content, rows, spec)
    end,
})
