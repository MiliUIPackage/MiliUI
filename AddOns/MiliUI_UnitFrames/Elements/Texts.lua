------------------------------------------------------------
-- 文字元件：每條一個 fontstring，tag 引擎驅動
-- 更新依賴由 Tags.GetBuckets() 解析（不再 strmatch 猜）
--
-- 三個清單（v22 起，見 Core/DB.lua 的 PROFILE_MIGRATIONS[22]）：
--   texts  elements.texts         框層文字（名字／等級／狀態…），座標相對單位框 TOPLEFT
--   hpbar  elements.hpbar.texts   血條自己的文字，座標相對**血條元件框** TOPLEFT
--   mpbar  elements.mpbar.texts   能量條自己的文字，座標相對**能量條元件框** TOPLEFT
-- 條搬到哪，條的文字跟到哪；條停用（或元件框不存在）時那條的文字一起藏。
--
-- 三個清單的文字框**全部掛在同一個覆蓋層 holder（uf.elements.texts）底下**，只有錨點
-- 不同：層級一律走 ns.OverlayLevel（墊到滑鼠／選取／驅散邊框之上），也不吃條的 alpha。
-- 改 parent 的話這兩件事都會跟著條走，條的 level 0–6 會把文字壓到邊框底下。
--
-- 存放：框層 uf.textFrames[i]；條 uf.barTextFrames[清單名][i]。
-- 外部（施法條遮字、/muf debug）一律經 ns.TextFramesOf(uf, 清單名) 拿，不要自己猜表名。
------------------------------------------------------------
local _, ns = ...

local Media, Tags = ns.Media, ns.Tags

-- 走訪順序固定：施法條遮字、/muf debug 都照這個順序列
local LISTS = { "texts", "hpbar", "mpbar" }
ns.TEXT_LISTS = LISTS

-- 清單 → 條目陣列（沒有就 nil）、條的 edb（框層是 nil）
local function ListDB(edbs, list)
    if type(edbs) ~= "table" then return nil end
    if list == "texts" then
        return type(edbs.texts) == "table" and edbs.texts or nil, nil
    end
    local bar = edbs[list]
    if type(bar) ~= "table" then return nil end
    return type(bar.texts) == "table" and bar.texts or nil, bar
end
ns.TextListDB = ListDB

-- 清單的文字框存放表。create = true 時缺表就建。
local function FramesOf(uf, list, create)
    if list == "texts" then
        if create and not uf.textFrames then uf.textFrames = {} end
        return uf.textFrames
    end
    local all = uf.barTextFrames
    if not all then
        if not create then return nil end
        all = {}
        uf.barTextFrames = all
    end
    local t = all[list]
    if not t and create then
        t = {}
        all[list] = t
    end
    return t
end
function ns.TextFramesOf(uf, list) return FramesOf(uf, list, false) end

-- 清單目前有沒有在畫：框層永遠有；條要啟用而且元件框已經建出來
local function ListAnchor(uf, list, bar)
    if list == "texts" then return uf end
    if not bar or bar.enabled == false then return nil end
    return uf.elements[list]
end

local function BuildOne(uf, frames, anchor, entry, index)
    local f = frames[index]
    if not f then
        -- 掛在 holder 底下（holder 有登記進 uf.elements，Refresh 的派發閘門才看得到）。
        -- 條的文字也一樣掛這裡，只改錨點 —— 理由見檔頭
        f = CreateFrame("Frame", nil, uf.elements.texts)
        f.fontstring = f:CreateFontString(nil, "ARTWORK")
        f.fontstring:SetAllPoints(f)
        f.fontstring:SetNonSpaceWrap(true)
        frames[index] = f
    end
    f:SetSize(ns.P.Scale(entry.w or 100), ns.P.Scale(entry.h or 12))
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", anchor, "TOPLEFT", ns.P.Scale(entry.x or 0), ns.P.Scale(entry.y or 0))
    -- 覆蓋層：墊到滑鼠／選取／驅散邊框之上（見 Core/UnitFrame.lua 的 ns.OverlayLevel）
    f:SetFrameLevel(ns.OverlayLevel(entry.level or 10))

    -- 玩家框：含 [name] 的文字條目掛「名字接收器」——字形範圍內一般 ping、其餘資源 ping。
    -- 三個清單一律套用（玩家可能把 [name] 寫進血條的文字裡）。
    -- 條目改了 pattern 之後不再含 [name] 就把接收器藏起來（藏起來的框不在 frame stack 裡）。
    -- 層級每次 Build 都重設，接收器要跟著（它得在所有元件接收器之上才輪得到它答）。
    if uf.unitKey == "player" and not uf.isPreview then
        local isName = type(entry.pattern) == "string" and entry.pattern:find("[name]", 1, true) ~= nil
        if isName then ns.ArmPingReceiver(uf, f, "player-name") end
        if f.pingReceiver then
            f.pingReceiver:SetShown(isName)
            f.pingReceiver:SetFrameLevel(f:GetFrameLevel() + 1)
        end
    end

    local fs = f.fontstring
    Media.SetFont(fs, entry.size, entry.flags, ns.db.global.font)
    fs:SetJustifyH(entry.justifyH or "LEFT")
    fs:SetJustifyV(Media.JustifyV(entry.justifyV))
    local c = entry.color or { r = 1, g = 1, b = 1, a = 1 }
    fs:SetTextColor(c.r, c.g, c.b, c.a or 1)

    -- 解析依賴桶（build 時做一次）
    f.buckets = Tags.GetBuckets(entry.pattern)
    f:Show()
    -- 立刻重畫：字型／對齊／顏色改完若沒跟著一次 render，畫面不會更新
    -- （FontString 換 justify 後要重設文字才會重新排版）
    Tags.Render(uf, fs, entry.pattern, entry)
    return f
end

-- 建一個清單；回傳這個清單需不需要 metro 輪詢
local function BuildList(uf, edbs, list)
    local entries, bar = ListDB(edbs, list)
    local anchor = entries and ListAnchor(uf, list, bar)
    local frames = FramesOf(uf, list, anchor ~= nil)
    uf.textFrameMaxes = uf.textFrameMaxes or {}
    local max = uf.textFrameMaxes[list] or 0
    local needMetro = false
    local count = 0
    if anchor then
        count = #entries
        for i, entry in ipairs(entries) do
            if entry.enabled ~= false then
                local f = BuildOne(uf, frames, anchor, entry, i)
                if max < i then max = i end
                if f.buckets.metro then needMetro = true end
            elseif frames[i] then
                frames[i]:Hide()
            end
        end
        uf.textFrameMaxes[list] = max
    end
    -- 多出來的舊框（設定刪條目後）藏掉；條停用時整個清單都藏（count = 0）。
    -- ⚠ 不能用 #frames：BuildOne 只對啟用的條目建框，停用第 1 條時
    -- frames[1] 是 nil ⇒ 那張表有洞、`#` 的結果未定義，這個迴圈可能一格都不跑，
    -- 刪掉條目後的舊框就永遠藏不掉。每個清單自己記最大索引。
    if frames then
        for i = count + 1, max do
            local f = frames[i]
            if f then f:Hide() end
        end
    end
    return needMetro
end

local function Build(uf, edb)
    -- ⚠ 一定要登記 uf.elements.texts：Refresh 的派發閘門靠它判斷元件存在，
    -- 漏掉的話 build 會跑但 update 永遠不會被呼叫（實測踩過：文字全滅零錯誤）
    if not uf.elements.texts then
        local holder = CreateFrame("Frame", nil, uf)
        holder:SetAllPoints(uf)
        uf.elements.texts = holder
    end
    uf.elements.texts:Show()      -- 元件曾被停用（holder Hide）再啟用要拉回來
    -- edb 就是 elements.texts（框層清單）；條的清單從 uf.db.elements 拿。
    -- order 40 排在 hpbar(20)／mpbar(30) 之後，條的元件框此時已經建好、位置也套好了
    local edbs = uf.db.elements
    local needMetro = false
    for _, list in ipairs(LISTS) do
        if BuildList(uf, edbs, list) then needMetro = true end
    end

    -- 有 oor 這類 metro 依賴的文字（三個清單任一）→ 掛共用輪詢。
    -- 用 Bind 而不是 Add：項目跟著框架可見度上下，框藏起來就卸掉，
    -- 沒有任何框需要輪詢時整顆 ticker 才停得下來
    -- ⚠ 預覽孿生框的 uf.unit 一律是 "player"（安全 token），key 會撞到真實玩家框，
    -- 所以預覽完全不碰 metro——它本來就有自己的 ticker 在演
    if not uf.isPreview then
        -- key 用 baseUnit，理由同 Core/UnitFrame.lua 的 range key（載具會留孤兒項目）
        local metroKey = "texts_" .. (uf.baseUnit or uf.unit)
        if needMetro then
            -- Update 自己從 uf.db.elements 重拿三個清單，第二個參數只是派發閘門的慣例；
            -- 不能因為框層清單不在就跳過（oor 可能寫在條的文字裡）
            uf.metroTextsFn = uf.metroTextsFn or function()
                ns.Elements.texts.update(uf, uf.db.elements.texts, "metro")
            end
            ns.Metro.Bind(uf, metroKey, 0.5, uf.metroTextsFn)
        else
            ns.Metro.Unbind(uf, metroKey)
        end
    end
end

local function UpdateList(uf, edbs, list, bucket)
    local frames = FramesOf(uf, list, false)
    if not frames then return end
    local entries = ListDB(edbs, list)
    if not entries then return end
    for i, entry in ipairs(entries) do
        local f = frames[i]
        -- f:IsShown() 同時擋掉「條停用 ⇒ 整個清單藏起來」的情況
        if f and entry.enabled ~= false and f:IsShown() then
            if bucket == "unitchanged" or f.buckets[bucket] then
                Tags.Render(uf, f.fontstring, entry.pattern, entry)
                -- 追「別人的資料跑進這個框」用：記下這次渲染當下的單位與身分判定。
                -- 事後 /muf debug 比對「畫面上的字」與「畫它時看的是誰」，
                -- 就知道是渲染錯了還是根本沒重畫。兩個欄位賦值，成本可忽略。
                f.lastUnit = uf.unit
                f.lastIsPlayer = uf.cache.isPlayer
                f.lastBucket = bucket
                -- 跟 uf.lastUC（最後一次 unitchanged）與 evt 時間線對時用
                f.lastT = GetTime()
                f.lastGen = ns.PaintGen()
            end
        end
    end
end

-- edb（框層清單）只是派發閘門給的；三個清單一律從 uf.db.elements 重拿
local function Update(uf, edb, bucket)
    local edbs = uf.db.elements
    for _, list in ipairs(LISTS) do
        UpdateList(uf, edbs, list, bucket)
    end
end

ns.RegisterElement{
    name = "texts",
    order = 40,
    -- info：名字／等級／分類；reaction：條件上色與狀態文字
    buckets = { "health", "power", "powertype", "death", "metro", "info", "reaction" },
    build = Build,
    update = Update,
}
