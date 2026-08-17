------------------------------------------------------------
-- 文字元件：texts 陣列，每條一個 fontstring，tag 引擎驅動
-- 更新依賴由 Tags.GetBuckets() 解析（不再 strmatch 猜）
------------------------------------------------------------
local _, ns = ...

local Media, Tags = ns.Media, ns.Tags

local function BuildOne(uf, entry, index)
    uf.textFrames = uf.textFrames or {}
    local f = uf.textFrames[index]
    if not f then
        -- 掛在 holder 底下（holder 有登記進 uf.elements，Refresh 的派發閘門才看得到）
        f = CreateFrame("Frame", nil, uf.elements.texts)
        f.fontstring = f:CreateFontString(nil, "ARTWORK")
        f.fontstring:SetAllPoints(f)
        f.fontstring:SetNonSpaceWrap(true)
        uf.textFrames[index] = f
    end
    f:SetSize(ns.P.Scale(entry.w or 100), ns.P.Scale(entry.h or 12))
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", uf, "TOPLEFT", ns.P.Scale(entry.x or 0), ns.P.Scale(entry.y or 0))
    f:SetFrameLevel(entry.level or 5)

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

local function Build(uf, edb)
    -- ⚠ 一定要登記 uf.elements.texts：Refresh 的派發閘門靠它判斷元件存在，
    -- 漏掉的話 build 會跑但 update 永遠不會被呼叫（實測踩過：文字全滅零錯誤）
    if not uf.elements.texts then
        local holder = CreateFrame("Frame", nil, uf)
        holder:SetAllPoints(uf)
        uf.elements.texts = holder
    end
    uf.elements.texts:Show()      -- 元件曾被停用（holder Hide）再啟用要拉回來
    local needMetro = false
    for i, entry in ipairs(edb) do
        if entry.enabled ~= false then
            local f = BuildOne(uf, entry, i)
            if f.buckets.metro then needMetro = true end
        elseif uf.textFrames and uf.textFrames[i] then
            uf.textFrames[i]:Hide()
        end
    end
    -- 多出來的舊框（設定刪條目後）藏掉
    if uf.textFrames then
        for i = #edb + 1, #uf.textFrames do
            uf.textFrames[i]:Hide()
        end
    end

    -- 有 oor 這類 metro 依賴的文字 → 掛共用輪詢。
    -- 用 Bind 而不是 Add：項目跟著框架可見度上下，框藏起來就卸掉，
    -- 沒有任何框需要輪詢時整顆 ticker 才停得下來
    -- ⚠ 預覽孿生框的 uf.unit 一律是 "player"（安全 token），key 會撞到真實玩家框，
    -- 所以預覽完全不碰 metro——它本來就有自己的 ticker 在演
    if not uf.isPreview then
        local metroKey = "texts_" .. uf.unit
        if needMetro then
            uf.metroTextsFn = uf.metroTextsFn or function()
                local texts = uf.db.elements.texts
                if texts then
                    ns.Elements.texts.update(uf, texts, "metro")
                end
            end
            ns.Metro.Bind(uf, metroKey, 0.5, uf.metroTextsFn)
        else
            ns.Metro.Unbind(uf, metroKey)
        end
    end
end

local function Update(uf, edb, bucket)
    if not uf.textFrames then return end
    for i, entry in ipairs(edb) do
        local f = uf.textFrames[i]
        if f and entry.enabled ~= false and f:IsShown() then
            if bucket == "identity" or f.buckets[bucket] then
                Tags.Render(uf, f.fontstring, entry.pattern, entry)
            end
        end
    end
end

ns.RegisterElement{
    name = "texts",
    order = 40,
    buckets = { "health", "power", "powertype", "death", "metro" },
    build = Build,
    update = Update,
}
