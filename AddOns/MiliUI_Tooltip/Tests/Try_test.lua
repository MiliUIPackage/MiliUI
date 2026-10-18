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
    eq("成功：高撐到 panel 高", t.tip.h, panel.height)
    check("成功：登記輪詢", t.polls[t.state] ~= nil)

    local function has(text)
        for i = 1, panel.textsUsed do if panel.texts[i].shown and panel.texts[i].text == text then return panel.texts[i] end end
    end
    check("內容：名字", has("Thunderfury"))
    check("內容：後加的 ID 行一行都沒丟", has("Item ID: 19019"))
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

    -- 文字變了才重畫
    t.data.lines[2].leftText = "Soulbound"
    t.env.GameTooltipTextLeft2.text = "Soulbound"
    t.P.Try(t.tip, t.state, ITEM, t.data)
    eq("內容變：重畫", t.renders(), 2)
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
    eq("輪詢：行數變了重畫", t.renders(), 3)
    eq("輪詢：alpha 重壓 0", t.tip.alpha, 0)
    local found
    local panel = t.state.panel
    for i = 1, panel.textsUsed do if panel.texts[i].text == "Score: 123.4" then found = panel.texts[i] end end
    check("輪詢：新加的行進來了", found ~= nil)
    check("輪詢：顏色照它自己的", found and found.textColor[1] == 0.5 and found.textColor[2] == 1)
    t.polls[t.state]()
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
    local st = {}
    t6.ns.Skin.State[shop] = st
    t6.P.Try(shop, st, ITEM, { id = 1, lines = {
        { type = 0, lineIndex = 1, leftText = "Currently Equipped" },
        { type = 22, lineIndex = 2, leftText = "Old Sword" },
    } })
    check("比價框：標籤", st.panel.tag and st.panel.tag.shown and st.panel.tag.text.text == "Currently Equipped")
    local nameShown
    for i = 1, st.panel.textsUsed do if st.panel.texts[i].text == "Old Sword" then nameShown = true end end
    check("比價框：名字跳過「目前裝備」那一行", nameShown)

    t6.ns.db.spell.panel = false
    t6.P.Try(t6.tip, t6.state, 1, t6.data)
    eq("法術開關關：物品開著也不畫法術", t6.renders(), 1)
    t6.P.Try(t6.tip, t6.state, 2, t6.data)
    eq("不認得的型別：不畫", t6.renders(), 1)

    -- 設定一改（ApplyAll 會 +1）：同樣內容也重畫
    t6.P.Try(t6.tip, t6.state, ITEM, t6.data)
    local r = t6.renders()
    t6.P.settingsVersion = t6.P.settingsVersion + 1
    t6.P.Try(t6.tip, t6.state, ITEM, t6.data)
    eq("設定版本變：重畫", t6.renders(), r + 1)

    -- 內嵌物品框顯示中：暴雪在用 padding，不接
    t6.P.Restore(t6.tip, t6.state)
    t6.tip.ItemTooltip = H.Region("Frame"); t6.tip.ItemTooltip.shown = true
    t6.P.Try(t6.tip, t6.state, ITEM, t6.data)
    check("內嵌物品框：不接", not t6.state.panel.shown)
end

H.finish("Try_test")
