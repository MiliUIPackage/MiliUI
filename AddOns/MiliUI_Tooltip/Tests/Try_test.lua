------------------------------------------------------------
-- Panel/Try.lua＋Native.lua＋ReadFallback.lua 的離線測試（不進 TOC）
--
--   lua AddOns/MiliUI_Tooltip/Tests/Try_test.lua
--
-- 覆蓋：開關關掉時對 tooltip 零寫入；reader 回 nil（秘密行、秘密的後加行）→ 不藏原生；
-- 秘密 GetPoint → 不對齊、整格退回；成功 → alpha 0、padding 撐到 panel 尺寸、輪詢登記；
-- 指紋相同不重畫；行數變了輪詢重跑；Release 同幀被認領不拆、沒被認領下一幀拆；
-- tooltip 根本沒顯示出來 → 下一幀退回；padding 只在還是我們設的時候寫回；
-- 別人後加的行進「其他」區；比價框的標籤；售價變錢幣字串。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local H = dofile(here .. "/helpers.lua")
H.here = here
local check, eq = H.check, H.eq
local SECRET = H.SECRET

local function Setup()
    local env = H.Env({ CURRENTLY_EQUIPPED = "Currently Equipped" })
    env.C_CurrencyInfo = { GetCoinTextureString = function(c) return c .. "c" end }
    env.C_Item = { GetItemIconByID = function(id) return 5000 + id end }
    local polls = {}
    local State = {}
    local ns = {
        L = setmetatable({}, { __index = function(_, k) return k end }),
        Media = { WHITE8X8 = "white", Font = function() return "default.ttf" end },
        playerClass = "MAGE",
        db = {
            general = { scale = 1, background = { r = 0.133, g = 0.133, b = 0.133, a = 1 },
                borderColor = { r = 0.18, g = 0.18, b = 0.18, a = 1 } },
            item = { panel = true }, spell = { panel = true },
            panel = { separators = true },
        },
        Skin = {
            State = State,
            Poll = function(key, interval, fn) polls[key] = fn end,
            Unpoll = function(key) polls[key] = nil end,
            Each = function(fn) for tip, st in pairs(State) do fn(tip, st) end end,
        },
    }
    for _, f in ipairs({ "Libs/MiliUIWidgets/Secret.lua", "Panel/Patterns.lua", "Panel/Frame.lua",
        "Panel/Render.lua", "Panel/Native.lua", "Panel/ReadFallback.lua", "Panel/Try.lua" }) do
        H.Load(env, ns, f)
    end
    local P = ns.Panel
    local renders, reads = 0, 0
    local render = P.RenderView
    P.RenderView = function(...) renders = renders + 1; return render(...) end
    local read = P.ReadFallback
    P.ReadFallback = function(...) reads = reads + 1; return read(...) end
    local tip = H.Tip(env, "GameTooltip", {
        { left = "Thunderfury", color = { 1, 0.5, 0 } },
        { left = "Binds when picked up" },
        { left = "Item ID: 19019", color = { 1, 0.82, 0 } },    -- 我們自己的 ID 行（AddLine）
    })
    local state = {}
    State[tip] = state
    local data = {
        id = 19019,
        lines = {
            { type = 22, lineIndex = 1, leftText = "Thunderfury", leftColor = { r = 1, g = 0.5, b = 0 } },
            { type = 0, lineIndex = 2, leftText = "Binds when picked up", leftColor = { r = 1, g = 1, b = 1 } },
            { type = 11, leftText = "Sell Price:", price = 12345 },     -- 錢幣框：沒有 lineIndex
        },
    }
    return {
        env = env, ns = ns, P = P, tip = tip, state = state, data = data, polls = polls,
        renders = function() return renders end,
        reads = function() return reads end,
    }
end

local ITEM = 0

------------------------------------------------------------
-- 1. 開關關掉：對 tooltip 零寫入（跟以前逐位元一樣）
------------------------------------------------------------
do
    local t = Setup()
    t.ns.db.item.panel = false
    t.P.Try(t.tip, t.state, ITEM, t.data)
    t.env.FlushTimers()
    eq("開關關：沒畫", t.renders(), 0)
    eq("開關關：alpha 沒寫過", t.tip.alphaCalls, nil)
    eq("開關關：padding 沒寫過", t.tip.padCalls, nil)
    eq("開關關：沒建 panel", t.state.panel, nil)
    -- 沒畫過時的 Restore／Release 也不碰 tooltip
    t.P.Release(t.tip, t.state); t.P.Restore(t.tip, t.state); t.env.FlushTimers()
    eq("開關關：Release／Restore 也不寫", t.tip.alphaCalls, nil)
end

------------------------------------------------------------
-- 2. reader 回 nil ⇒ 不藏原生
------------------------------------------------------------
do
    local t = Setup()
    t.data.lines[2].leftText = SECRET
    t.P.Try(t.tip, t.state, ITEM, t.data)
    eq("秘密行：沒畫", t.renders(), 0)
    eq("秘密行：alpha 沒動", t.tip.alphaCalls, nil)

    local t2 = Setup()
    t2.env.GameTooltipTextLeft3.text = SECRET       -- 別人後加的行是秘密
    t2.P.Try(t2.tip, t2.state, ITEM, t2.data)
    eq("秘密的後加行：沒畫", t2.renders(), 0)
    eq("秘密的後加行：alpha 沒動", t2.tip.alphaCalls, nil)

    local t3 = Setup()
    t3.data.lines[1].leftColor = { r = SECRET, g = 0, b = 0 }
    t3.P.Try(t3.tip, t3.state, ITEM, t3.data)
    eq("秘密顏色：沒畫", t3.renders(), 0)

    local t4 = Setup()
    t4.data.lines = { { type = 0, lineIndex = 1, leftText = "" } }
    t4.tip:SetLines({ { left = "" } })
    t4.P.Try(t4.tip, t4.state, ITEM, t4.data)
    eq("沒有名字：沒畫", t4.renders(), 0)
end

------------------------------------------------------------
-- 3. 秘密 GetPoint ⇒ 不對齊、整格退回
------------------------------------------------------------
do
    local t = Setup()
    t.tip:ClearAllPoints()
    t.tip:SetPoint("TOPLEFT", SECRET, "TOPLEFT", 0, 0)
    t.P.Try(t.tip, t.state, ITEM, t.data)
    check("秘密錨點：panel 沒顯示", not t.state.panel.shown)
    eq("秘密錨點：panel 沒錨", #t.state.panel.points, 0)
    eq("秘密錨點：alpha 沒動", t.tip.alphaCalls, nil)
    eq("秘密錨點：沒登記輪詢", next(t.polls), nil)
end

------------------------------------------------------------
-- 4. 成功：藏原生、撐 padding、輪詢、讀到的內容
------------------------------------------------------------
local t = Setup()
do
    t.P.Try(t.tip, t.state, ITEM, t.data)
    local panel = t.state.panel
    eq("成功：畫了一次", t.renders(), 1)
    check("成功：panel 顯示", panel.shown)
    eq("成功：原生 alpha 0", t.tip.alpha, 0)
    eq("成功：panel 錨在 tooltip 上", panel.points[1][2], t.tip)
    eq("成功：寬撐到 panel 寬", t.tip.w, panel.width)
    -- 有別人加的行 ⇒ 附屬框；原生要撐到「主面板＋縫＋附屬框」
    check("成功：附屬框顯示", panel.extrasBox and panel.extrasBox.shown)
    eq("成功：totalHeight＝主高＋縫＋附高", panel.totalHeight, panel.height + 6 + panel.extrasBox.height)
    eq("成功：高撐到整組高", t.tip.h, panel.totalHeight)
    check("成功：登記輪詢", t.polls[t.state] ~= nil)

    local function has(text)
        for _, f in ipairs({ panel, panel.extrasBox }) do
            for i = 1, f.textsUsed do if f.texts[i].shown and f.texts[i].text == text then return f.texts[i] end end
        end
    end
    check("內容：名字", has("Thunderfury"))
    check("內容：後加的 ID 行一行都沒丟", has("Item ID: 19019"))
    local inBox
    for i = 1, panel.extrasBox.textsUsed do if panel.extrasBox.texts[i].text == "Item ID: 19019" then inBox = true end end
    check("內容：後加的行在附屬框裡", inBox)
    local price = has("12345c")
    check("內容：售價變錢幣字串", price ~= nil)
    check("內容：名字是品質色", has("Thunderfury").textColor[2] == 0.5)
    check("內容：圖示", panel.icon.shown and panel.icon.texture == 5000 + 19019)
end

------------------------------------------------------------
-- 5. 指紋相同不重畫（比價風暴：清空再填同一件）
------------------------------------------------------------
do
    local readsBefore = t.reads()
    t.P.Release(t.tip, t.state)          -- OnTooltipCleared
    t.P.Try(t.tip, t.state, ITEM, t.data) -- 同一幀 post-call 認領
    t.env.FlushTimers()
    eq("風暴：沒有重畫", t.renders(), 1)
    eq("風暴：連解析都沒跑", t.reads(), readsBefore)
    check("風暴：panel 還在", t.state.panel.shown)
    eq("風暴：原生還是 alpha 0", t.tip.alpha, 0)

    -- 同一件但文字變了：當幀不畫，下一幀 Reconcile 才重畫
    t.data.lines[2].leftText = "Soulbound"
    t.env.GameTooltipTextLeft2.text = "Soulbound"
    t.P.Try(t.tip, t.state, ITEM, t.data)
    eq("內容變：當幀不畫", t.renders(), 1)
    t.env.FlushTimers()
    eq("內容變（同行數）：下一幀還不畫，要穩定一陣子", t.renders(), 1)
    t.env.now = t.env.now + 0.35
    t.env.FlushTimers()
    eq("內容變（同行數）：穩定 0.3 秒後重畫", t.renders(), 2)
    t.env.FlushTimers()
end

------------------------------------------------------------
-- 6. 輪詢：別人後加行 → 重跑；alpha 被改回來 → 重壓
------------------------------------------------------------
do
    local lines = {
        { left = "Thunderfury", color = { 1, 0.5, 0 } }, { left = "Soulbound" },
        { left = "Item ID: 19019" }, { left = "Score: 123.4", color = { 0.5, 1, 0.5 } },
    }
    t.tip:SetLines(lines)
    t.tip.alpha = 1
    t.polls[t.state]()
    eq("輪詢：alpha 重壓 0", t.tip.alpha, 0)
    eq("輪詢：行數變了先排 Reconcile、不直接畫", t.renders(), 2)
    t.env.FlushTimers()
    eq("輪詢：下一幀重畫", t.renders(), 3)
    local found
    local panel = t.state.panel
    local box = panel.extrasBox
    for i = 1, box.textsUsed do if box.texts[i].text == "Score: 123.4" then found = box.texts[i] end end
    check("輪詢：新加的行進來了", found ~= nil)
    check("輪詢：顏色照它自己的", found and found.textColor[1] == 0.5 and found.textColor[2] == 1)
    t.polls[t.state]()
    t.env.FlushTimers()
    eq("輪詢：沒變就不重畫", t.renders(), 3)

    -- 點／拖 ItemRefTooltip 時暴雪抬它的 level：panel 要跟著，不然 alpha 0 的原生框吃掉 × 的點擊
    eq("層級：render 時 = tip + 5", t.state.panel.level, t.tip:GetFrameLevel() + 5)
    t.tip.level = 40
    t.polls[t.state]()
    eq("層級：tip 被抬高後輪詢跟上", t.state.panel.level, 45)
    eq("層級：跟上不算重畫", t.renders(), 3)
    t.tip.GetFrameLevel = function() return SECRET end
    t.polls[t.state]()
    eq("層級：秘密 level 不動", t.state.panel.level, 45)
    t.tip.GetFrameLevel = nil
end

------------------------------------------------------------
-- 7. Release 沒被認領 → 下一幀退回；padding 只在還是我們設的時候寫回
------------------------------------------------------------
do
    local padBefore = t.tip.padCalls
    t.P.Release(t.tip, t.state)
    check("Release：當下還沒拆", t.state.panel.shown)
    t.env.FlushTimers()
    check("Release：下一幀拆", not t.state.panel.shown)
    eq("Release：alpha 寫回 1", t.tip.alpha, 1)
    eq("Release：padding 寫回 0", t.tip.padding[1], 0)
    eq("Release：padding 寫一次", t.tip.padCalls, padBefore + 1)
    eq("Release：輪詢拿掉", t.polls[t.state], nil)

    -- 別人（暴雪的內嵌物品框）在我們之後改了 padding：不搶
    local t2 = Setup()
    t2.P.Try(t2.tip, t2.state, ITEM, t2.data)
    t2.tip.padding = { 77, 0, 0, 0 }
    local calls = t2.tip.padCalls
    t2.P.Restore(t2.tip, t2.state)
    eq("別人改過的 padding 不寫回", t2.tip.padCalls, calls)
    eq("別人改過的 padding 留著", t2.tip.padding[1], 77)

    -- tooltip 隱藏時（暴雪 OnHide 已經 ClearPadding）不寫 padding
    local t3 = Setup()
    t3.P.Try(t3.tip, t3.state, ITEM, t3.data)
    t3.tip.shown = false
    calls = t3.tip.padCalls
    t3.P.Restore(t3.tip, t3.state)
    eq("隱藏時不寫 padding", t3.tip.padCalls, calls)
    eq("隱藏時 alpha 照樣寫回", t3.tip.alpha, 1)
end

------------------------------------------------------------
-- 7b. skin OnHide 也延一幀：清單刷新時游標那一列先藏、下一幀 OnEnter 重設同一件 ⇒ 認領、不閃；沒人認領才拆
------------------------------------------------------------
do
    local t5 = Setup()
    t5.P.Try(t5.tip, t5.state, ITEM, t5.data)
    t5.env.FlushTimers()
    local rendersBefore = t5.renders()
    t5.P.OnSkinHide(t5.tip, t5.state)                  -- GameTooltip:Hide()（列被重新配置）
    check("OnHide：當下不拆", t5.state.panel.shown)
    eq("OnHide：原生 alpha 還是 0", t5.tip.alpha, 0)
    t5.P.Try(t5.tip, t5.state, ITEM, t5.data)          -- 下一幀 OnEnter 重設同一件
    t5.env.FlushTimers()
    check("OnHide：同一件回來 ⇒ 認領、面板還在", t5.state.panel.shown)
    eq("OnHide：認領不重畫", t5.renders(), rendersBefore)
    eq("OnHide：認領後 alpha 仍 0", t5.tip.alpha, 0)

    t5.P.OnSkinHide(t5.tip, t5.state)                  -- 真的收掉
    check("OnHide：當下還沒拆", t5.state.panel.shown)
    t5.env.FlushTimers()
    check("OnHide：下一幀沒人認領 ⇒ 拆", not t5.state.panel.shown)
    eq("OnHide：alpha 寫回 1", t5.tip.alpha, 1)
    eq("OnHide：輪詢拿掉", t5.polls[t5.state], nil)

    -- 藏了之後換一件：新件照畫、舊的排定拆除不會把新面板拆掉
    t5.P.Try(t5.tip, t5.state, ITEM, t5.data)
    t5.env.FlushTimers()
    t5.P.OnSkinHide(t5.tip, t5.state)
    local data2 = { id = 20000, lines = { { type = 22, lineIndex = 1, leftText = "Other", leftColor = { r = 1, g = 1, b = 1 } } } }
    t5.tip:SetLines({ { left = "Other" } })
    t5.P.Try(t5.tip, t5.state, ITEM, data2)
    t5.env.FlushTimers()
    check("OnHide 後換一件：新面板還在", t5.state.panel.shown)
    eq("OnHide 後換一件：原生 alpha 0", t5.tip.alpha, 0)
end

------------------------------------------------------------
-- 8. post-call 之後 tooltip 根本沒顯示 → 下一幀退回
------------------------------------------------------------
do
    local t4 = Setup()
    t4.tip.shown = false              -- post-call 在 Show 之前；這次 Show 沒來
    t4.P.Try(t4.tip, t4.state, ITEM, t4.data)
    check("沒顯示：當下 panel 先顯示", t4.state.panel.shown)
    eq("沒顯示：padding 等顯示後才撐", t4.tip.padCalls, nil)
    t4.env.FlushTimers()
    check("沒顯示：下一幀退回", not t4.state.panel.shown)
    eq("沒顯示：alpha 寫回", t4.tip.alpha, 1)

    -- 第一次顯示：OnShow 清掉 padding（暴雪），下一幀補回
    local t5 = Setup()
    t5.P.Try(t5.tip, t5.state, ITEM, t5.data)
    t5.tip:SetPadding(0, 0, 0, 0)     -- GameTooltip_OnShow → ClearPadding
    t5.env.FlushTimers()
    eq("OnShow 清掉後下一幀補回寬", t5.tip.w, t5.state.panel.width)
end

------------------------------------------------------------
-- 9. 比價框標籤、型別開關分開、不認得的型別
------------------------------------------------------------
do
    local t6 = Setup()
    local shop = H.Tip(t6.env, "ShoppingTooltip1", {
        { left = "Currently Equipped" }, { left = "Old Sword" },
    })
    H.CompareHeader(shop, "Equipped")
    local st = {}
    t6.ns.Skin.State[shop] = st
    t6.P.Try(shop, st, ITEM, { id = 1, lines = {
        { type = 0, lineIndex = 1, leftText = "Currently Equipped" },
        { type = 22, lineIndex = 2, leftText = "Old Sword" },
    } })
    check("比價框：標籤照抄原生標頭的字", st.panel.tag and st.panel.tag.shown and st.panel.tag.text.text == "Equipped")
    -- K1：第二顆（可一起裝備）是「Equipped With」；標頭沒顯示就不畫；標頭的字讀不到退 EQUIPPED
    local shop2 = H.Tip(t6.env, "ShoppingTooltip2", { { left = "Blade" } })
    local header2 = H.CompareHeader(shop2, "Equipped With")
    local st2 = {}
    t6.ns.Skin.State[shop2] = st2
    local d2 = { id = 2, lines = { { type = 22, lineIndex = 1, leftText = "Blade" } } }
    t6.P.Try(shop2, st2, ITEM, d2)
    eq("K1：第二顆標籤＝同時裝備", st2.panel.tag and st2.panel.tag.text.text, "Equipped With")
    eq("K1：CompareHeaderText", t6.P.CompareHeaderText(shop2), "Equipped With")
    header2.Label.text = SECRET
    t6.env.EQUIPPED = "Equipped"
    eq("K1：讀不到字（秘密）退 EQUIPPED", t6.P.CompareHeaderText(shop2), "Equipped")
    header2.shown = false
    eq("K1：標頭沒顯示 ⇒ 沒有標籤", t6.P.CompareHeaderText(shop2), nil)
    eq("K1：一般 tooltip 沒有標頭", t6.P.CompareHeaderText(t6.tip), nil)
    t6.P.Restore(shop2, st2)
    local nameShown
    for i = 1, st.panel.textsUsed do if st.panel.texts[i].text == "Old Sword" then nameShown = true end end
    check("比價框：名字跳過「目前裝備」那一行", nameShown)

    local r0 = t6.renders()
    t6.ns.db.spell.panel = false
    t6.P.Try(t6.tip, t6.state, 1, t6.data)
    eq("法術開關關：物品開著也不畫法術", t6.renders(), r0)
    t6.P.Try(t6.tip, t6.state, 2, t6.data)
    eq("不認得的型別：不畫", t6.renders(), r0)

    -- 設定一改（ApplyAll 會 +1）：同樣內容也重畫
    t6.P.Try(t6.tip, t6.state, ITEM, t6.data)
    t6.env.FlushTimers()                 -- 兩個 tooltip 排著的 Reconcile 先跑完
    local r = t6.renders()
    t6.P.settingsVersion = t6.P.settingsVersion + 1
    t6.P.Try(t6.tip, t6.state, ITEM, t6.data)
    t6.env.FlushTimers()
    eq("設定版本變：重畫", t6.renders(), r + 1)

    -- 內嵌物品框顯示中：暴雪在用 padding，不接
    t6.P.Restore(t6.tip, t6.state)
    t6.tip.ItemTooltip = H.Region("Frame"); t6.tip.ItemTooltip.shown = true
    t6.P.Try(t6.tip, t6.state, ITEM, t6.data)
    check("內嵌物品框：不接", not t6.state.panel.shown)
end

------------------------------------------------------------
-- 10. 比價重建的閃爍（2026-10-18 實機）：ClearLines → ProcessInfo（我們的 post-call 在這裡）→
--     同一幀暴雪補「若你更換此裝備…」、別家 post-call 補行。部分版不准蓋掉完整版
------------------------------------------------------------
do
    local t7 = Setup()
    local base = {
        { left = "Thunderfury", color = { 1, 0.5, 0 } }, { left = "Binds when picked up" },
        { left = "Item ID: 19019", color = { 1, 0.82, 0 } },
    }
    local full = {
        base[1], base[2], base[3], { left = " " },
        { left = "If you replace this item, the following stat changes will occur:" }, { left = "+20 Haste" },
    }
    -- 第一次顯示：當幀畫部分版、下一幀補齊（首次最多閃一次）
    t7.P.Try(t7.tip, t7.state, ITEM, t7.data)
    eq("首次：當幀就畫", t7.renders(), 1)
    t7.tip:SetLines(full)                       -- 同一幀暴雪補上比較行
    t7.env.FlushTimers()
    eq("首次：下一幀補齊重畫一次", t7.renders(), 2)
    eq("首次：完整行數記下來", t7.state.panelFullLines, 6)

    -- 之後每一輪重建：清空 → post-call（部分）→ 同一幀補齊 ⇒ 0 次重畫
    for round = 1, 5 do
        t7.P.Release(t7.tip, t7.state)
        t7.tip:SetLines(base)
        t7.P.Try(t7.tip, t7.state, ITEM, t7.data)
        t7.tip:SetLines(full)
        t7.env.FlushTimers()
    end
    eq("風暴五輪：0 次重畫", t7.renders(), 2)
    check("風暴五輪：panel 一直在", t7.state.panel.shown)

    -- 比較行晚一幀才來：部分版的那一幀不重畫
    t7.P.Release(t7.tip, t7.state)
    t7.tip:SetLines(base)
    t7.P.Try(t7.tip, t7.state, ITEM, t7.data)
    t7.env.FlushTimers()                        -- 這一幀還是部分版
    eq("晚一幀：部分版不蓋掉完整版", t7.renders(), 2)
    t7.tip:SetLines(full)
    t7.env.FlushTimers()                        -- 下一幀補齊
    eq("晚一幀：補齊後也不用重畫", t7.renders(), 2)

    -- 行數真的變少（修飾鍵放開、冷卻行消失）：連續 0.3 秒才接受
    t7.tip:SetLines(base)
    t7.env.now = 10
    t7.polls[t7.state]()
    t7.env.FlushTimers()
    eq("變少：0 秒不接受", t7.renders(), 2)
    t7.env.now = 10.2
    t7.env.FlushTimers()
    eq("變少：0.2 秒還不接受", t7.renders(), 2)
    t7.env.now = 10.35
    t7.env.FlushTimers()
    eq("變少：超過 0.3 秒接受並重畫", t7.renders(), 3)
    eq("變少：完整行數重設", t7.state.panelFullLines, 3)
    t7.env.FlushTimers()
    eq("變少：接受後不再排", #t7.env.timers, 0)

    -- 換一件（key 不同）：當幀立刻畫，完整行數歸零重算
    t7.P.Release(t7.tip, t7.state)
    t7.tip:SetLines({ { left = "Ashkandi" } })
    t7.P.Try(t7.tip, t7.state, ITEM, { id = 19364, lines = {
        { type = 22, lineIndex = 1, leftText = "Ashkandi", leftColor = { r = 0.64, g = 0.21, b = 0.93 } },
    } })
    eq("換一件：當幀立刻畫", t7.renders(), 4)
    eq("換一件：完整行數重算", t7.state.panelFullLines, 1)
    t7.env.FlushTimers()
    check("換一件：沒被下一幀拆掉", t7.state.panel.shown)

    -- 同一個 state 同時只排一個 Reconcile
    t7.P.Try(t7.tip, t7.state, ITEM, t7.state.panelData)
    t7.P.Try(t7.tip, t7.state, ITEM, t7.state.panelData)
    t7.polls[t7.state]()
    eq("Reconcile 合併：只排一個", #t7.env.timers, 1)
    t7.env.FlushTimers()

    -- 沒有明文 id 也沒有連結：每次都當不同件（立刻畫）
    eq("Key：秘密 id 沒連結 → nil", t7.P.Key("item", { id = SECRET }), nil)
    eq("Key：用連結", t7.P.Key("item", { id = SECRET, hyperlink = "item:1" }), "item:item:1")
    eq("Key：用 id", t7.P.Key("spell", { id = 133 }), "spell:133")
end

------------------------------------------------------------
-- 11. 暴雪的 Show／SetShown 把 alpha 改回 1（實機：比價框縫裡閃）→ 後掛勾同一幀壓回
------------------------------------------------------------
do
    local t8 = Setup()
    -- 模擬遊戲：Show／SetShown(true) 會把 alpha 重設成 1
    local tip = t8.tip
    function tip:Show() self.shown = true; self.alpha = 1 end
    function tip:SetShown(v) self.shown = v and true or false; if v then self.alpha = 1 end end
    t8.P.Try(tip, t8.state, ITEM, t8.data)
    eq("掛勾前提：面板生效、alpha 0", tip.alpha, 0)
    tip:Show()
    eq("Show 之後同一幀就壓回 0", tip.alpha, 0)
    tip:SetShown(true)
    eq("SetShown(true) 之後也壓回 0", tip.alpha, 0)
    -- 面板退回之後，掛勾什麼都不做
    t8.P.Restore(tip, t8.state)
    tip:Show()
    eq("面板沒在用：Show 之後照暴雪的 1", tip.alpha, 1)
    -- 同一個 tooltip 只掛一次
    local calls = 0
    local show = tip.Show
    tip.Show = function(self) calls = calls + 1; return show(self) end
    t8.P.Try(tip, t8.state, ITEM, t8.data)
    t8.P.Try(tip, t8.state, ITEM, { id = 99, lines = t8.data.lines })
    tip:Show()
    eq("只掛一次（沒有疊好幾層）", calls, 1)
end

------------------------------------------------------------
-- 12. padding 被暴雪清掉（SetOwner／ClearLines／OnShow）→ 當幀補回上次的值、不重算（G2）
------------------------------------------------------------
do
    local t9 = Setup()
    local tip = t9.tip
    t9.P.Try(tip, t9.state, ITEM, t9.data)
    t9.env.FlushTimers()
    local set = t9.state.paddingSet
    check("前提：設過 padding", set and set[2] > 0)
    local setR, setB = set[1], set[2]
    -- 暴雪清掉 padding；GetHeight 還是舊的（假框照 padding 縮回去，模擬「讀到的尺寸不可信」）
    tip.padding = { 0, 0, 0, 0 }
    tip.h = 999
    local calls = tip.padCalls
    t9.P.Release(tip, t9.state)
    t9.P.Try(tip, t9.state, ITEM, t9.data)       -- 同一件的 post-call
    eq("當幀補回上次的 padding（右）", tip.padding[1], setR)
    eq("當幀補回上次的 padding（下）", tip.padding[2], setB)
    eq("只 SetPadding 一次（沒有拿舊高度重算）", tip.padCalls, calls + 1)
    -- Show 後掛勾：OnShow（GameTooltip_CalculatePadding）又清一次 → 同一幀補回
    local t11 = Setup()
    local tip2 = t11.tip
    function tip2:Show() self.shown = true; self.alpha = 1; self.padding = { 0, 0, 0, 0 } end   -- 掛勾裝上之前就是這樣
    t11.P.Try(tip2, t11.state, ITEM, t11.data)
    t11.env.FlushTimers()
    local want = t11.state.paddingSet and t11.state.paddingSet[2]
    check("前提：Show 掛勾那顆設過 padding", want and want > 0)
    tip2:Show()
    eq("Show 清掉之後掛勾當幀補回", tip2.padding[2], want)
    eq("Show 之後 alpha 也壓回", tip2.alpha, 0)
    -- 我們沒設過（panel 比原生小、不用撐）：被清掉也不動
    local t10 = Setup()
    t10.P.Try(t10.tip, t10.state, ITEM, t10.data)
    t10.state.paddingSet = nil
    t10.tip.padding = { 0, 0, 0, 0 }
    check("沒設過就不補", not t10.P.Native.RestoreClearedPadding(t10.tip, t10.state))
end

------------------------------------------------------------
-- 13. /mtip panel 診斷：秘密值不讀、只標 <secret>
------------------------------------------------------------
do
    local t12 = Setup()
    local tip = t12.tip
    t12.ns.Skin.State[tip] = t12.state
    t12.P.Try(tip, t12.state, ITEM, t12.data)
    local lines = {}
    eq("診斷：印出一顆", t12.P.DebugDump(function(s) lines[#lines + 1] = s end), 1)
    check("診斷：原生的點", lines[1] and lines[1]:find("BOTTOMLEFT→UIParent:BOTTOMLEFT", 1, true), lines[1])
    check("診斷：padding 與我們設的值", lines[2] and lines[2]:find("我們設的=", 1, true))
    check("診斷：panel 貼在哪", lines[3] and lines[3]:find("貼在 BOTTOMLEFT→GameTooltip:BOTTOMLEFT", 1, true), lines[3])
    tip.GetTop = function() return SECRET end
    lines = {}
    t12.P.DebugDump(function(s) lines[#lines + 1] = s end)
    check("診斷：秘密值標 <secret>、不炸", lines[2] and lines[2]:find("top=<secret>", 1, true), lines[2])
    t12.P.Restore(tip, t12.state)
    lines = {}
    eq("診斷：沒有顯示中的面板", t12.P.DebugDump(function(s) lines[#lines + 1] = s end), 0)
end

------------------------------------------------------------
-- 14. 徹底的抖動規則（H1～H4）：同一件的幾何只長不縮；同行數的內容變化要持續才採用
------------------------------------------------------------
do
    local t13 = Setup()
    local tip, P, env = t13.tip, t13.P, t13.env
    local short = { { left = "Hammer", color = { 0.12, 1, 0 } }, { left = "Bind" } }
    local data = { id = 262452, lines = {
        { type = 22, lineIndex = 1, leftText = "Hammer", leftColor = { r = 0.12, g = 1, b = 0 } },
        { type = 0, lineIndex = 2, leftText = "Bind" },
    } }
    tip:SetLines(short)
    P.Try(tip, t13.state, ITEM, data)
    env.FlushTimers()
    local w0, total0 = t13.state.panel.width, t13.state.panel.totalHeight
    -- 別家加了一行很長的（附屬框）：長大、立刻重畫、寬度變大
    local long = { short[1], short[2], { left = string.rep("Bonus ID: 2, 40, 3125, 38, 4 ", 2) } }
    tip:SetLines(long)
    t13.polls[t13.state]()
    env.FlushTimers()
    eq("H4：行數變多立刻重畫", t13.renders(), 2)
    local w1, total1 = t13.state.panel.width, t13.state.panel.totalHeight
    check("前提：變寬變高", w1 > w0 and total1 > total0, ("%s>%s %s>%s"):format(w1, w0, total1, total0))
    -- 那行不見了（0.3 秒後才接受）：重畫成短版，但寬度不縮、原生高度不縮
    tip:SetLines(short)
    t13.polls[t13.state]()
    env.FlushTimers()
    env.now = env.now + 0.35
    env.FlushTimers()
    eq("變少：0.3 秒後接受", t13.renders(), 3)
    eq("H1：同一件寬度只長不縮", t13.state.panel.width, w1)
    check("H2：內容變矮了", t13.state.panel.totalHeight < total1)
    eq("H2：原生仍撐在最大總高", tip.h, total1)
    -- 換一件：歸零
    local other = { id = 1, lines = { { type = 22, lineIndex = 1, leftText = "X" } } }
    tip:SetLines({ { left = "X" } })
    P.Release(tip, t13.state)
    P.Try(tip, t13.state, ITEM, other)
    check("換一件：寬度重算（變回下限）", t13.state.panel.width < w1, t13.state.panel.width)
    eq("換一件：最大總高歸零重記", t13.state.panelMaxTotalHeight, t13.state.panel.totalHeight)
    env.FlushTimers()
end

do
    -- 同行數、A／B 每 0.2 秒交替 1 秒：一次都不重畫
    local t14 = Setup()
    local tip, P, env = t14.tip, t14.P, t14.env
    local A = { { left = "Hammer" }, { left = "Bind" }, { left = "Auction" } }
    local B = { { left = "Hammer" }, { left = "Bind" }, { left = "Auction x1" } }
    local data = { id = 7, lines = {
        { type = 22, lineIndex = 1, leftText = "Hammer" }, { type = 0, lineIndex = 2, leftText = "Bind" },
    } }
    tip:SetLines(A)
    P.Try(tip, t14.state, ITEM, data)
    env.FlushTimers()
    local base = t14.renders()
    for step = 1, 50 do                 -- 每幀 0.02 秒、共 1 秒；每 0.2 秒（10 幀）換一次
        env.now = env.now + 0.02
        if step % 10 == 0 then
            tip:SetLines((step / 10) % 2 == 1 and B or A)
            P.Release(tip, t14.state)
            P.Try(tip, t14.state, ITEM, data)     -- 背包每 0.2 秒重設一次提示
        end
        env.FlushTimers()
    end
    eq("H3：A／B 每 0.2 秒交替 1 秒 → 0 次重畫", t14.renders(), base)
    -- 同行數、持續 0.35 秒的變化：重畫一次
    tip:SetLines(B)
    P.Try(tip, t14.state, ITEM, data)
    for _ = 1, 18 do env.now = env.now + 0.02; env.FlushTimers() end
    eq("H3：同行數的新內容持續 0.36 秒 → 重畫一次", t14.renders(), base + 1)
    for _ = 1, 20 do env.now = env.now + 0.02; env.FlushTimers() end
    eq("H3：採用之後不再重畫", t14.renders(), base + 1)
    -- 設定改了：不等
    P.settingsVersion = P.settingsVersion + 1
    P.Try(tip, t14.state, ITEM, data)
    env.FlushTimers()
    eq("設定版本變：下一幀就重畫", t14.renders(), base + 2)
end

------------------------------------------------------------
-- 15. 鏡射錨點（I1）與原生不夾邊（I2）
------------------------------------------------------------
do
    local t15 = Setup()
    local env, P = t15.env, t15.P
    local main = t15.tip                         -- GameTooltip：BOTTOMLEFT→UIParent（從下緣錨定）
    main.clamped = true
    P.Try(main, t15.state, ITEM, t15.data)
    env.FlushTimers()
    local mainPanel = t15.state.panel
    eq("I2：接管時原生不夾邊", main.clamped, false)
    -- 主提示有別人加的行 ⇒ 附屬框；面板的夾邊範圍底邊多算縫＋附屬框
    local box = mainPanel.extrasBox
    check("前提：主面板有附屬框", box and box.shown)
    local M = mainPanel.clampMargin
    check("L2：邊緣呼吸換算過、大於 0", M and M > 0, M)
    eq("I2＋L2：夾邊範圍底邊 = −(縫＋附屬框＋呼吸)", mainPanel.clampInsets[4], -(6 + box.height + M))
    eq("L2：沒有標籤時上緣只有呼吸", mainPanel.clampInsets[3], M)
    eq("L2：左緣往外一圈呼吸", mainPanel.clampInsets[1], -M)
    eq("L2：右緣往外一圈呼吸", mainPanel.clampInsets[2], M)
    eq("L1：主面板沒有依附者時照自己夾", mainPanel.clamped, true)

    -- 比價框：TOP→GameTooltip:TOP、RIGHT→GameTooltip:LEFT
    local shop = H.Tip(env, "ShoppingTooltip1", { { left = "Old Sword" } })
    H.CompareHeader(shop, "Equipped")
    shop.clamped = true
    shop:ClearAllPoints()
    shop:SetPoint("TOP", main, "TOP", 0, 0)
    shop:SetPoint("RIGHT", main, "LEFT", 0, 0)
    local st = {}
    t15.ns.Skin.State[shop] = st
    local shopData = { id = 5, lines = { { type = 22, lineIndex = 1, leftText = "Old Sword" } } }
    P.Try(shop, st, ITEM, shopData)
    env.FlushTimers()
    local sp = st.panel
    eq("I1：比價面板的點數照原生", #sp.points, 2)
    eq("I1：TOP 貼到主面板", sp.points[1][2], mainPanel)
    eq("I1：TOP→TOP", sp.points[1][1] .. ">" .. sp.points[1][3], "TOP>TOP")
    eq("I1：RIGHT 貼到主面板的 LEFT", sp.points[2][2], mainPanel)
    eq("I1：RIGHT→LEFT", sp.points[2][1] .. ">" .. sp.points[2][3], "RIGHT>LEFT")
    eq("I1：記下鏡射對象", sp.mirrorOf, mainPanel)
    eq("N1：TOP→TOP 同邊對齊不推", sp.points[1][5], 0)
    eq("N1：RIGHT→LEFT 相鄰邊往外推 6", sp.points[2][4], -6)
    check("I1：比價面板自己記下標籤高", sp.clampOwnTop and sp.clampOwnTop > 0, sp.clampOwnTop)
    eq("L1：鏡射在主面板上的比價面板自己不夾", sp.clamped, false)
    eq("L1：主面板替帶標籤的依附者預留上緣（標籤高＋呼吸）", mainPanel.clampInsets[3], sp.clampOwnTop + M)
    eq("L1：主面板仍照自己夾", mainPanel.clamped, true)
    -- 依附者的附屬框比主面板的還長 ⇒ 底邊取大者
    local ownBottom = sp.clampOwnBottom
    sp.clampOwnBottom = 6 + box.height + 30
    P.UpdateClampInsets(sp)
    eq("L1：依附者附屬框更長 ⇒ 主面板底邊取大者", mainPanel.clampInsets[4], -(6 + box.height + 30 + M))
    sp.clampOwnBottom = ownBottom
    P.UpdateClampInsets(sp)
    eq("L1：依附者附屬框變回短的 ⇒ 底邊回到主面板自己的", mainPanel.clampInsets[4], -(6 + box.height + M))

    -- 串鏈：第二顆比價框貼第一顆 ⇒ 第二顆也不夾、預留收到根（主面板）
    local shopB = H.Tip(env, "ShoppingTooltip4", { { left = "Ring" } })
    H.CompareHeader(shopB, "Equipped together")
    shopB:ClearAllPoints()
    shopB:SetPoint("TOPRIGHT", shop, "TOPLEFT", 0, 0)
    local stB = {}
    t15.ns.Skin.State[shopB] = stB
    P.Try(shopB, stB, ITEM, { id = 7, lines = { { type = 22, lineIndex = 1, leftText = "Ring" } } })
    env.FlushTimers()
    eq("L1：第二顆鏡射在第一顆上", stB.panel.mirrorOf, sp)
    eq("N1：鏈的第二顆 TOPRIGHT→TOPLEFT 也往外推 6", ("%g,%g"):format(stB.panel.points[1][4], stB.panel.points[1][5]), "-6,0")
    eq("L1：第二顆也不夾", stB.panel.clamped, false)
    stB.panel.clampOwnTop = sp.clampOwnTop + 9      -- 假裝第二顆的標籤更高
    P.UpdateClampInsets(stB.panel)
    eq("L1：串鏈的預留收到根", mainPanel.clampInsets[3], sp.clampOwnTop + 9 + M)
    P.Restore(shopB, stB)
    eq("L1：第二顆退回 ⇒ 夾邊開回來", stB.panel.clamped, true)
    eq("L1：第二顆退回 ⇒ 根的預留回到第一顆的", mainPanel.clampInsets[3], sp.clampOwnTop + M)
    t15.ns.Skin.State[shopB] = nil

    -- 主提示的原生自然寬高變了（重設時短暫變）、主面板寬高不變 ⇒ 比價面板不動
    local before = {}
    for i, p in ipairs(sp.points) do before[i] = table.concat({ p[1], tostring(p[2]), p[3], p[4], p[5] }, ",") end
    main.h, main.w = main.h + 37, main.w + 23
    main.top = main.top + 37
    t15.polls[st]()
    env.FlushTimers()
    local same = true
    for i, p in ipairs(sp.points) do
        if table.concat({ p[1], tostring(p[2]), p[3], p[4], p[5] }, ",") ~= before[i] then same = false end
    end
    check("I1：對方原生寬高變了、對方面板沒變 ⇒ 比價面板的錨點一模一樣", same)

    -- 主面板退回 ⇒ 比價面板當場改回貼自己的原生
    P.Restore(main, t15.state)
    eq("I2：退回時原生的夾邊寫回原值", main.clamped, true)
    eq("I1：主面板沒了 ⇒ 比價面板貼自己的原生", sp.points[1][2], shop)
    eq("I1：照被錨定的那一角（TOP＋RIGHT）", sp.points[1][1], "TOPRIGHT")
    eq("I1：不再記鏡射對象", sp.mirrorOf, nil)
    eq("L1：改貼自己的原生 ⇒ 比價面板自己夾回來", sp.clamped, true)
    eq("L1：自己夾時上緣＝自己的標籤高＋呼吸", sp.clampInsets[3], sp.clampOwnTop + sp.clampMargin)

    -- 對方面板沒顯示時第一次對齊：貼自己的原生
    local shop2 = H.Tip(env, "ShoppingTooltip2", { { left = "Other" } })
    shop2:ClearAllPoints()
    shop2:SetPoint("TOPRIGHT", main, "TOPLEFT", 0, 0)
    local st2 = {}
    t15.ns.Skin.State[shop2] = st2
    P.Try(shop2, st2, ITEM, { id = 6, lines = { { type = 22, lineIndex = 1, leftText = "Other" } } })
    eq("I1：對方面板沒顯示 ⇒ 貼自己的原生", st2.panel.points[1][2], shop2)
    P.Restore(shop2, st2)
    P.Restore(shop, st)
    eq("I2：比價框退回也寫回夾邊", shop.clamped, true)

    -- 秘密錨點：整格退回（照舊）
    local shop3 = H.Tip(env, "ShoppingTooltip3", { { left = "S" } })
    shop3:ClearAllPoints()
    shop3:SetPoint("TOP", SECRET, "TOP", 0, 0)
    local st3 = {}
    t15.ns.Skin.State[shop3] = st3
    P.Try(shop3, st3, ITEM, { id = 7, lines = { { type = 22, lineIndex = 1, leftText = "S" } } })
    check("秘密錨點：不顯示", not (st3.panel and st3.panel.shown))
end

------------------------------------------------------------
-- 16. J3：原生暫時沒有點（暴雪 SetOwner(ANCHOR_NONE) 之後、post-call 之後才 SetPoint）⇒ 不改貼法
------------------------------------------------------------
do
    local t16 = Setup()
    local env, P = t16.env, t16.P
    local tip = t16.tip
    P.Try(tip, t16.state, ITEM, t16.data)
    env.FlushTimers()
    local panel = t16.state.panel
    local sets, clears = 0, 0
    local setPoint, clearAll = panel.SetPoint, panel.ClearAllPoints
    panel.SetPoint = function(...) sets = sets + 1; return setPoint(...) end
    panel.ClearAllPoints = function(...) clears = clears + 1; return clearAll(...) end
    local saved = tip.points
    -- 有點 → 無點 → 有點
    tip.points = {}
    check("J3：原生沒有點時對齊照樣成功", P.Align(panel, tip))
    tip.points = saved
    P.Align(panel, tip)
    eq("J3：有點→無點→有點：一次都沒重貼", sets + clears, 0)
    -- 沒有點、而且還沒排版（GetLeft 回 nil）
    local getLeft = tip.GetLeft
    tip.GetLeft = function() return nil end
    P.Align(panel, tip)
    tip.GetLeft = getLeft
    eq("J3：還沒排版也不重貼", sets + clears, 0)
    -- 重畫（RenderView 會 Detach 掉錨點）的那一刻原生剛好沒有點：照上次的貼法貼回去，不是暫貼
    local lastArgs = panel.anchorArgs[1]
    tip.points = {}
    P.RenderView(panel, tip, P.ViewFallback(P.ReadFallback(tip, t16.data, "item")), t16.state)
    P.Align(panel, tip)
    eq("J3：重畫時原生沒有點 ⇒ 照上次的貼回去", panel.points[1][1], lastArgs[1])
    eq("J3：貼回同一個對象", panel.points[1][2], lastArgs[2])
    tip.points = saved
    panel.SetPoint, panel.ClearAllPoints = setPoint, clearAll

    -- 第一次顯示就沒有點：暫貼、下一次有點就改成正式貼法
    local t17 = Setup()
    local tip2 = t17.tip
    tip2.points = {}
    t17.P.Try(tip2, t17.state, ITEM, t17.data)
    eq("J3：第一次就沒有點 ⇒ 暫貼", t17.state.panel.alignSig, "provisional")
    tip2:SetPoint("BOTTOMLEFT", t17.env.UIParent, "BOTTOMLEFT", 100, 100)
    t17.P.Align(t17.state.panel, tip2)
    eq("J3：之後有點 ⇒ 正式貼法（下緣）", t17.state.panel.points[1][1], "BOTTOMLEFT")
    eq("J3：正式貼法對象是自己的原生", t17.state.panel.points[1][2], tip2)
end

------------------------------------------------------------
-- 17. K2：原生自己的寬高也只長不縮（暴雪拿比價框原生的寬算推移量，原生寬一抖整條鏈就動）
------------------------------------------------------------
do
    local t18 = Setup()
    local tip, P, env = t18.tip, t18.P, t18.env
    P.Try(tip, t18.state, ITEM, t18.data)
    env.FlushTimers()
    -- 原生的自然寬比面板寬（不換行的比價說明）：600。
    -- （paddingSet 先清掉：「padding 被清掉當幀補回」那條在第 12 節測過，這裡只驗 K2）
    t18.state.paddingSet = nil
    tip.padding = { 0, 0, 0, 0 }
    tip.w = 600
    t18.polls[t18.state]()
    eq("前提：原生比面板寬時不撐", tip.padding[1], 0)
    -- 重設的那一刻自然寬短暫變 500（晚一幀補回的行還沒來）
    t18.state.paddingSet = nil
    tip.padding = { 0, tip.padding[2], 0, 0 }
    tip.w = 500
    t18.polls[t18.state]()
    eq("K2：原生寬撐回這件看過的最大值 600", tip.w, 600)
    eq("K2：靠 padding 撐（右 100）", tip.padding[1], 100)
    -- 換一件：歸零
    P.Release(tip, t18.state)
    tip.padding = { 0, 0, 0, 0 }
    tip.w = 200
    P.Try(tip, t18.state, ITEM, { id = 999, lines = t18.data.lines })
    check("K2：換一件之後不再撐到上一件的 600", tip.w < 600, tip.w)
end

------------------------------------------------------------
-- 18. /mtip panel watch：逐幀取樣、只印有變動的欄位
------------------------------------------------------------
do
    local t19 = Setup()
    local tip, P, env = t19.tip, t19.P, t19.env
    P.Try(tip, t19.state, ITEM, t19.data)
    env.FlushTimers()
    local lines = {}
    P.Watch(1, function(s) lines[#lines + 1] = s end)
    local w = P.watcher
    check("watch：取樣期間掛 OnUpdate", w.scripts.OnUpdate ~= nil)
    for i = 1, 6 do
        tip.left = (i % 2 == 0) and 100.4 or 100.6        -- 原生左緣在兩個值之間跳
        w.scripts.OnUpdate(w, 0.02)
    end
    w.scripts.OnUpdate(w, 1)                              -- 時間到：最後一幀（值沒變）
    check("watch：結束後拆掉 OnUpdate", w.scripts.OnUpdate == nil)
    local found
    for _, s in ipairs(lines) do if s:find("GameTooltip.原生.Left：", 1, true) then found = s end end
    check("watch：印出在跳的欄位", found ~= nil, table.concat(lines, " | "))
    check("watch：列出兩個值與次數", found and found:find("100.60", 1, true) and found:find("100.40", 1, true) and found:find("變 5 次", 1, true), found)
    local stableLine
    for _, s in ipairs(lines) do if s:find("面板.width(記)", 1, true) then stableLine = s end end
    check("watch：沒變的欄位不印", stableLine == nil)

    lines = {}
    P.Watch(0.05, function(s) lines[#lines + 1] = s end)
    for _ = 1, 4 do if w.scripts.OnUpdate then w.scripts.OnUpdate(w, 0.02) end end
    check("watch：全部穩定時印一行", lines[#lines]:find("幀全部穩定", 1, true), lines[#lines])

    P.Restore(tip, t19.state)
    lines = {}
    P.Watch(0.02, function(s) lines[#lines + 1] = s end)
    w.scripts.OnUpdate(w, 0.03)
    check("watch：沒有面板時說一聲", lines[#lines]:find("沒有顯示中的面板", 1, true), lines[#lines])
end

H.finish("Try_test")
