------------------------------------------------------------
-- Skin 引擎：中和、overlay、登記表、戰鬥閘、debug 紀錄
--
-- 這支是**唯一**可以對 overlay 呼叫定位類 API（SetPoint／SetFrameLevel／SetSize）
-- 的檔案。Primitives 與 Skins 一律透過這裡的函式操作 overlay ——
-- `.claude/scripts/check_skin.py` 就是照這條線掃的（Engine.lua 不在掃描範圍）。
--
-- 三個設計要點（為什麼長這樣，完整版在 STYLE.md ③）：
--
-- 1. **overlay 不是 BackdropTemplate，也不掛任何腳本。** BackdropTemplate 自帶
--    OnSizeChanged 的 Lua（Blizzard_SharedXML/Backdrop.lua 的
--    `BackdropTemplateMixin:OnBackdropSizeChanged` → `SetupTextureCoordinates`）；
--    暴雪改視窗大小時那段會跑在**暴雪的執行堆疊裡**，而它是我們掛上去的
--    ⇒ 整條流程染成我們的。overlay 一律是「純 Frame ＋ 1 張底色貼圖 ＋ 4 條邊貼圖
--    （＋選用的一張靜態圖記）」，位置全部用錨點跟著目標跑，建立之後執行期零 Lua。
--
-- 2. **overlay 不 parent 到會走訪 children 的框**（LayoutFrame／ResizeLayoutFrame／
--    ScrollBox 的 ScrollTarget／物件池容器）。那些框會 `GetLayoutChildren()` 然後讀
--    每個 child 的 layoutIndex／尺寸；多一個我們的 child 就多一次我們沒預期的讀取。
--    `SafeParent` 會往上爬到最近的非 layout 祖先，錨點照樣錨在目標身上。
--
-- 3. **狀態優先交給引擎。** 按鈕 hover 走 `GetHighlightTexture():SetColorTexture(...)`
--    讓 C 端自己畫；做不到才掛 hook。每種模板走哪條路記在 STYLE.md ⑤ 的配方表。
--
-- 4. **池化列（ScrollBox 的 element）走 mixin 後置勾**（`Engine.HookRows`）。
--    Mixin 是在 frame **建立時**把函式複製到 frame 上的，所以 hook 只對之後建立的
--    frame 生效 ⇒ 一定要在「配方登記／ADDON_LOADED 當下」就裝，不能等戰鬥結束；
--    已經先被建立的列用 `Engine.SweepRows`（ScrollBox:ForEachFrame，唯讀走訪）補掃。
--    完整規則在 STYLE.md ③ 的陷阱 4。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local P = ns.P
local T = ns.Tokens

ns.Engine = {}
local Engine = ns.Engine

local WHITE = "Interface\\BUTTONS\\WHITE8X8"

-- overlay 四條邊的順序：1 上、2 下、3 左、4 右（Engine.Overlay 建立時的順序）
local EDGE_INDEX = { TOP = 1, BOTTOM = 2, LEFT = 3, RIGHT = 4 }

------------------------------------------------------------
-- 弱鍵 side table
--
-- ⚠⚠ **暴雪物件上一個欄位都不准寫**（連 `frame.isSkinned` 都不行）。
--   12.1 的規則是「暴雪會讀的欄位一個都不能寫」，而「暴雪會不會讀」這件事
--   我們判斷不了 —— 寫了一個明碼數字，暴雪排版讀它、那次執行帶污染、污染流到
--   任何讀秘密值的地方就炸，錯誤會指向跟我們隔了兩個系統的檔案
--   （見 .claude/notes/wow-121-secret-values.md 的實測案例）。
--   所以狀態全部放這裡，frame 當 key、弱參照，暴雪回收了我們跟著消失。
------------------------------------------------------------
local State = setmetatable({}, { __mode = "k" })
Engine.State = State

------------------------------------------------------------
-- debug 紀錄
--
-- 配方裡找不到的區域**只記錄不報錯**：暴雪改版會改名，一個名字對不上不應該讓
-- 整份配方掛掉。`/mskin debug` 把這兩張清單印出來，就是下次改版的待辦。
------------------------------------------------------------
Engine.log = {
    neutralized = 0,      -- 成功中和幾個區域
    overlays    = 0,      -- 建了幾個 overlay
    missing     = {},     -- 配方指名、但物件不存在的區域
    protected   = {},     -- IsProtected 為真、刻意跳過的框
    forbidden   = {},     -- 動態 forbidden、跳過的框
}

local function Note(list, label)
    if not label then return end
    for _, v in ipairs(list) do
        if v == label then return end
    end
    list[#list + 1] = label
end

function Engine.Missing(label)
    Note(Engine.log.missing, label)
end

------------------------------------------------------------
-- 動得了嗎？
--
-- `IsForbidden` 是**動態**狀態（12.1 之後某些物件會被系統借走），每個入口都要
-- 重問；IsForbidden 本身在 forbidden object 上永遠可以呼叫。
------------------------------------------------------------
local function Usable(obj, label)
    if obj == nil then
        Engine.Missing(label)
        return false
    end
    if S.IsForbiddenObject(obj) then
        Note(Engine.log.forbidden, label or "?")
        return false
    end
    return true
end
Engine.Usable = Usable

-- 保護框：我們不在上面掛 overlay。記進清單而不是靜默跳過 —— 「這個視窗沒有變」
-- 跟「這個視窗被擋掉了」在畫面上長得一模一樣。
local function IsProtectedFrame(obj)
    if type(obj) ~= "table" or type(obj.IsProtected) ~= "function" then return false end
    local ok, protected = pcall(obj.IsProtected, obj)
    if not ok then return true end            -- 問不到就當成有
    return S.ToBool(protected) == true
end
Engine.IsProtectedFrame = IsProtectedFrame

------------------------------------------------------------
-- 中和：純 SetAlpha(0)
--
-- ⚠ **中和一律用 alpha，不要用 SetTexture/SetAtlas 換掉。** alpha 與材質是兩個
--   獨立的屬性，所以暴雪之後再 `SetAtlas` 一次（滑過換圖、換主題、OnShow 重設）
--   也不會把中和弄掉；反過來把材質換成純色，暴雪下一次 SetTexture 就蓋回去了。
--   更糟的情況是有程式會**讀回**材質名字 ——
--   `MinimalScrollBarThumbScriptsMixin:OnSizeChanged` 就是
--   `C_Texture.GetAtlasInfo(self.Middle:GetAtlas())` 然後讀 `info.height`，
--   我們把 Middle 換成純色貼圖，它每次捲動都會拿到 nil 然後炸，而且算在我們頭上。
--
-- ⚠ 也不要 Hide()：Hide 會被暴雪自己的 Show 打回來（分頁的選中態就是靠
--   Show/Hide 兩組貼圖在切），而且對「Edit Mode 管的框」Hide 等於跟它打架。
------------------------------------------------------------
function Engine.Neutralize(obj, label)
    if not Usable(obj, label) then return false end
    if type(obj.SetAlpha) ~= "function" then
        Engine.Missing(label)
        return false
    end
    local ok = pcall(obj.SetAlpha, obj, 0)
    if ok then
        Engine.log.neutralized = Engine.log.neutralized + 1
        local st = State[obj] or {}
        st.neutralized = true
        State[obj] = st
    end
    return ok
end

-- owner 底下的一票 parentKey 區域一次中和。label 前綴讓 debug 清單看得出是誰。
function Engine.NeutralizeKeys(owner, keys, prefix)
    if not Usable(owner, prefix) then return end
    for _, key in ipairs(keys) do
        local region
        local ok = pcall(function() region = owner[key] end)
        Engine.Neutralize(ok and region or nil, (prefix or "?") .. "." .. key)
    end
end

-- 全域名稱的一票區域（舊式視窗大量用 `$parent...` 具名貼圖）
function Engine.NeutralizeGlobals(names)
    for _, name in ipairs(names) do
        Engine.Neutralize(_G[name], name)
    end
end

-- 走訪自己的 region，把貼圖全部中和掉（FontString 不動）。
--
-- 給「沒有名字也沒有 parentKey」的區域用：物件池 Acquire 出來的框是**無名**的，
-- 模板裡的 `$parentBG` / `$parentBorderLeft` 那幾張因此連全域名字都沒有，
-- 只剩 GetRegions 一條路（契約允許的讀取例外，只用來找美術區域）。
-- `exclude` 用來把「不是裝飾」的那張排除掉（StatusBar 的填充貼圖）。
function Engine.NeutralizeRegions(owner, prefix, exclude)
    if not Usable(owner, prefix) then return end
    if type(owner.GetRegions) ~= "function" then return end
    local ok, regions = pcall(function() return { owner:GetRegions() } end)
    if not ok then return end
    for i, region in ipairs(regions) do
        if type(region) == "table" and region ~= exclude
            and type(region.GetObjectType) == "function" then
            local ok2, kind = pcall(region.GetObjectType, region)
            if ok2 and kind == "Texture" then
                Engine.Neutralize(region, (prefix or "?") .. ".region" .. i)
            end
        end
    end
end

-- 走訪 children，把帶 NineSlice 的那些中和掉。
-- 舊視窗裡有不少「沒名字也沒 parentKey、只是 setAllPoints 的一層金邊」
-- （成就視窗就有三個），沒有名字可以指名，只能從 children 裡認。
-- ⚠ 這是**讀結構不是讀值**：只問「有沒有 NineSlice 這個子框」，不讀它的尺寸／文字。
function Engine.NeutralizeChildNineSlices(owner, prefix)
    if not Usable(owner, prefix) then return end
    if type(owner.GetChildren) ~= "function" then return end
    local ok, children = pcall(function() return { owner:GetChildren() } end)
    if not ok then return end
    for i, child in ipairs(children) do
        local nine
        if type(child) == "table" and pcall(function() nine = child.NineSlice end) and nine then
            -- 找不到就不記進 missing：這是「掃到什麼算什麼」，沒有 NineSlice 的 child 是常態
            Engine.Neutralize(nine, (prefix or "?") .. ".child" .. i .. ".NineSlice")
        end
    end
end

------------------------------------------------------------
-- 文字上色
------------------------------------------------------------
function Engine.TextColor(fs, color, label)
    if not Usable(fs, label) then return end
    if type(fs.SetTextColor) ~= "function" then
        Engine.Missing(label)
        return
    end
    pcall(fs.SetTextColor, fs, color[1], color[2], color[3], color[4] or 1)
end

function Engine.VertexColor(tex, color, label)
    if not Usable(tex, label) then return end
    if type(tex.SetVertexColor) ~= "function" then
        Engine.Missing(label)
        return
    end
    pcall(tex.SetVertexColor, tex, color[1], color[2], color[3], color[4] or 1)
end

-- 圖示裁邊：把暴雪圖示四周那圈暗邊切掉，才對得上 1px 硬邊的直角語彙
function Engine.CropIcon(tex, label)
    if not Usable(tex, label) then return end
    if type(tex.SetTexCoord) ~= "function" then return end
    local c = T.iconCrop
    pcall(tex.SetTexCoord, tex, c, 1 - c, c, 1 - c)
end

------------------------------------------------------------
-- 按鈕的三態交給引擎自己畫
--
-- Highlight／Pushed 是 C 端在滑鼠狀態改變時自己顯示／隱藏的貼圖，我們只要把
-- 「長什麼樣」換掉就好 —— 不必掛 OnEnter/OnLeave，也就不會有我們的 Lua 跑在
-- 暴雪的點擊派送裡。SetColorTexture 在這兩張貼圖上是白名單動作。
--
-- ⚠ 暴雪的 Highlight 多半是 alphaMode="ADD"，換成白色純色之後就是一層很淡的
--   提亮，正好是我們要的「狀態只換明暗」。
------------------------------------------------------------
function Engine.ButtonStates(btn, label, withPushed)
    if not Usable(btn, label) then return end

    if type(btn.GetHighlightTexture) == "function" then
        local ok, hl = pcall(btn.GetHighlightTexture, btn)
        if ok and hl and type(hl.SetColorTexture) == "function" then
            pcall(hl.SetColorTexture, hl, 1, 1, 1, T.highlightAlpha)
        end
    end

    -- ⚠ Pushed 二選一：**要嘛中和（alpha 0）、要嘛換成黑色疊加，不能兩個都做** ——
    --   SetColorTexture 的 alpha 是顏色的，Neutralize 的 alpha 是區域的，兩個相乘，
    --   中和過的 Pushed 再怎麼上色都看不見。只有「Pushed 是模板寫死、暴雪不會在
    --   執行期重設材質」的按鈕（關閉鈕）才走上色；其他模板一律中和，接受按下沒有視覺。
    if withPushed and type(btn.GetPushedTexture) == "function" then
        local ok, pushed = pcall(btn.GetPushedTexture, btn)
        if ok and pushed and type(pushed.SetColorTexture) == "function" then
            pcall(pushed.SetColorTexture, pushed, 0, 0, 0, T.pushedAlpha)
        end
    end
end

------------------------------------------------------------
-- HIGHLIGHT 層的區域（不是 GetHighlightTexture 拿得到的那張）
--
-- 有些模板把滑過態做成「HIGHLIGHT 層的三張 atlas 貼圖」而不是 HighlightTexture
-- （`ListHeaderThreeSliceTemplate` 就是：HighlightLeft/Middle/Right）。C 端一樣
-- 會在滑鼠進出時自己顯示／隱藏整層，所以只要把「長什麼樣」換掉就好，不用掛腳本。
--
-- ⚠ 一定要連 `SetAlpha(1)` 一起做：那幾張在模板裡是 `alpha="0.4"`，
--   區域 alpha 會跟顏色 alpha 相乘，不重設的話白 8% 會被壓成 3%，等於沒有滑過。
------------------------------------------------------------
function Engine.HighlightTexture(tex, label)
    if not Usable(tex, label) then return end
    if type(tex.SetColorTexture) ~= "function" then
        Engine.Missing(label)
        return
    end
    pcall(tex.SetAlpha, tex, 1)
    pcall(tex.SetColorTexture, tex, 1, 1, 1, T.highlightAlpha)
end

------------------------------------------------------------
-- 按鈕文字的三態也交給引擎：換字型物件，不要 SetTextColor
--
-- 按鈕的文字顏色跟著「目前狀態的字型物件」走 —— 滑過時 C 端換成 HighlightFont、
-- 離開時換回 NormalFont，每換一次文字顏色就被字型物件的顏色蓋掉。所以對
-- `btn.Text` 做 SetTextColor 只撐得到第一次滑過，之後就變回暴雪的暗金色。
-- 把 NormalFont 換成暴雪自己的白字字型物件，三態就全部由引擎處理，執行期零 Lua。
--
-- ⚠ 傳進來的一律是**暴雪自己的**字型物件（GameFontHighlight 系）：字型檔與字級
--   跟原本同一家族，只差顏色，不會有「換字型物件吃掉最後一個字」的度量差。
-- ⚠ Disabled 不動：停用灰字本來就是我們要的；分頁的選中態也是靠暴雪自己在
--   `PanelTemplates_SelectTab` 設的 DisabledFont（白）。
------------------------------------------------------------
function Engine.ButtonFonts(btn, normalFont, label)
    if not Usable(btn, label) then return end
    if not normalFont then return end
    if type(btn.SetNormalFontObject) == "function" then
        pcall(btn.SetNormalFontObject, btn, normalFont)
    end
end

------------------------------------------------------------
-- overlay 掛哪裡（陷阱 2）
--
-- 會走訪 children 並讀它們欄位的框一律不當 parent。判斷用「有沒有這些方法」——
-- 讀的是結構不是值，安全。
------------------------------------------------------------
local LAYOUT_MARKERS = { "Layout", "MarkDirty", "GetLayoutChildren", "GetScrollTarget", "GetView" }

local function IsLayoutHost(frame)
    if type(frame) ~= "table" then return false end
    for _, m in ipairs(LAYOUT_MARKERS) do
        if type(rawget(frame, m)) == "function" or type(frame[m]) == "function" then
            return true
        end
    end
    -- 物件池容器：pool 會把 child 逐一 Release／Reset，多一個我們的 child 很難說會發生什麼
    if frame.framePool or frame.FramePool or frame.pools then return true end
    return false
end
Engine.IsLayoutHost = IsLayoutHost

-- 從 target 往上爬到第一個「可以安全當 parent」的框。爬不到就回 UIParent。
--
-- ⚠ target 可能是 **Texture**（圖示的 1px 邊就是直接錨在貼圖上的）。貼圖不能當
--   parent，所以第一道判斷是「這是不是一個 frame」—— 用有沒有 CreateTexture 認，
--   讀的是結構不是值。
local function SafeParent(target)
    local node = target
    local guard = 0
    while node and guard < 12 do
        guard = guard + 1
        if type(node.CreateTexture) == "function"
            and not IsLayoutHost(node) and not IsProtectedFrame(node) then
            return node
        end
        local ok, parent = pcall(node.GetParent, node)
        if not ok then break end
        node = parent
    end
    return UIParent
end
Engine.SafeParent = SafeParent

------------------------------------------------------------
-- frameLevel：照 MiliUI_Tooltip 的 LowerSkinLevel 寫法
--
-- 三道守衛缺一不可：pcall（forbidden object 上呼叫方法會拋錯）、型別檢查、
-- 秘密值檢查（帶秘密錨點的框連 GetFrameLevel 都可能回秘密數字，拿去做算術當場炸）。
------------------------------------------------------------
local function TargetLevel(target)
    if not target or type(target.GetFrameLevel) ~= "function" then return nil end
    local ok, level = pcall(target.GetFrameLevel, target)
    if not ok or type(level) ~= "number" or S.IsSecret(level) then return nil end
    return level
end
Engine.TargetLevel = TargetLevel

------------------------------------------------------------
-- Engine.Overlay(target, opts) → overlay 或 nil
--
-- opts:
--   key          debug 用的名字
--   parent       指定 parent（配方知道得比 SafeParent 清楚時用）
--   inset        SetAllPoints 之後四邊各內縮這麼多框架單位
--   points       { {point, relativePoint, x, y}, ... } 改成自訂錨點（仍錨在 target 上）
--   width/height 只錨了一邊的時候自己給尺寸（髮絲線就是這樣畫的）
--   levelOffset  相對 target 的層級差，預設 -1（壓在目標自己的區域之下）
--   noBorder     不要四條邊
--   skipEdges    { "TOP", ... } 這幾條邊不畫 —— 「跟內容相連的那一邊不畫」
--                （分頁掛在視窗下緣 ⇒ 相連的是分頁的上邊）
--   glyph        靜態圖記，建立時定好、執行期不動，兩種：
--                  { kind = "cross", size, thickness, color }  兩條 CreateLine 畫的 ×
--                  { texture = 路徑, size, color }             一張貼圖
--
-- **冪等**：同一個 target 只建一次，之後呼叫直接回上次那個。配方重跑（例如
-- 隨需載入的視窗被套兩次）不會長出第二層。
------------------------------------------------------------
function Engine.Overlay(target, opts)
    opts = opts or {}
    local label = opts.key

    if not Usable(target, label) then return nil end

    -- 同一個目標可以有不只一層（例如圖示：一層底、一層畫在圖上的邊），
    -- 用 slot 分。沒指定就是 "main"。
    local slot = opts.slot or (opts.levelOffset and opts.levelOffset > 0 and "front") or "main"

    local st = State[target]
    if st and st.overlays and st.overlays[slot] then return st.overlays[slot] end

    -- 保護框上不掛 overlay。記下來，`/mskin debug` 看得到。
    if IsProtectedFrame(target) then
        Note(Engine.log.protected, label or "?")
        return nil
    end

    local parent = opts.parent or SafeParent(target)
    if IsProtectedFrame(parent) then
        Note(Engine.log.protected, (label or "?") .. " (parent)")
        return nil
    end

    -- ⚠ 純 Frame、不繼承任何模板。EnableMouse 維持預設的 false ——
    --   overlay 一旦吃滑鼠就會把暴雪按鈕的 OnEnter/OnClick 整個攔掉
    --   （見 .claude/notes/wow-child-frame-steals-mouse-focus.md）。
    local ov = CreateFrame("Frame", nil, parent)

    if opts.points then
        for _, pt in ipairs(opts.points) do
            ov:SetPoint(pt[1], target, pt[2] or pt[1], P.Scale(pt[3] or 0), P.Scale(pt[4] or 0))
        end
    elseif opts.inset then
        local n = P.Scale(opts.inset)
        ov:SetPoint("TOPLEFT", target, "TOPLEFT", n, -n)
        ov:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -n, n)
    else
        ov:SetAllPoints(target)
    end

    -- 只錨了一邊（例如標題下的髮絲線只錨 BOTTOMLEFT/BOTTOMRIGHT）的時候要自己給尺寸
    if opts.width then ov:SetWidth(P.Scale(opts.width)) end
    if opts.height then ov:SetHeight(P.Scale(opts.height)) end

    local level = TargetLevel(target)
    if level then
        ov:SetFrameLevel(math.max(0, level + (opts.levelOffset or -1)))
    end

    -- 底色。四條邊蓋在它外圈，所以底色整塊鋪滿就好。
    local bg = ov:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(WHITE)
    bg:SetAllPoints(ov)
    ov.bg = bg

    if not opts.noBorder then
        local w = T.BorderSize()
        local e = {}
        for i = 1, 4 do
            e[i] = ov:CreateTexture(nil, "BORDER")
            e[i]:SetTexture(WHITE)
        end
        e[1]:SetPoint("TOPLEFT");     e[1]:SetPoint("TOPRIGHT");     e[1]:SetHeight(w)
        e[2]:SetPoint("BOTTOMLEFT");  e[2]:SetPoint("BOTTOMRIGHT");  e[2]:SetHeight(w)
        e[3]:SetPoint("TOPLEFT", 0, -w);  e[3]:SetPoint("BOTTOMLEFT", 0, w);  e[3]:SetWidth(w)
        e[4]:SetPoint("TOPRIGHT", 0, -w); e[4]:SetPoint("BOTTOMRIGHT", 0, w); e[4]:SetWidth(w)
        ov.edges = e

        -- 跟內容相連的那一邊不畫（feedback-ui-visual-style）。索引對照見 EDGE_INDEX。
        if opts.skipEdges then
            local skip = {}
            for _, side in ipairs(opts.skipEdges) do
                local idx = EDGE_INDEX[side]
                if idx then skip[idx] = true end
            end
            ov.skipEdges = skip
        end
    end

    -- 靜態圖記（關閉鈕的 ×）。建立時定好，執行期不動。
    if opts.glyph then
        local g = opts.glyph
        local c = g.color or T.text
        if g.kind == "cross" then
            -- ⚠ 不要用 `Interface\Buttons\UI-StopButton`：那張圖本身是暗金色的，
            --   SetVertexColor 是乘法，乘不白。自己用兩條線畫才拿得到純白的 ×。
            --   建立時定好、執行期零 Lua；粗細走 P.Scale（不同 UI 縮放下的 1 像素
            --   不是 1 個框架單位，見 project-miliui-pixel-snapping）。
            local half = P.Scale((g.size or 8) / 2)
            local th = P.Scale(g.thickness or 1)
            local lines = {}
            for i, dir in ipairs({ 1, -1 }) do
                local line = ov:CreateLine(nil, "ARTWORK")
                line:SetThickness(th)
                line:SetTexture(WHITE)
                line:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
                line:SetStartPoint("CENTER", ov, -half, -half * dir)
                line:SetEndPoint("CENTER", ov, half, half * dir)
                lines[i] = line
            end
            ov.glyphLines = lines
        else
            local tex = ov:CreateTexture(nil, "ARTWORK")
            tex:SetTexture(g.texture)
            tex:SetSize(P.Scale(g.size or 10), P.Scale(g.size or 10))
            tex:SetPoint("CENTER")
            tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
            ov.glyph = tex
        end
    end

    st = st or {}
    st.overlays = st.overlays or {}
    st.overlays[slot] = ov
    State[target] = st
    Engine.log.overlays = Engine.log.overlays + 1
    return ov
end

-- 取回某個目標身上已經建好的 overlay（沒有就 nil）。debug 與重畫用。
function Engine.GetOverlay(target, slot)
    local st = target and State[target]
    return st and st.overlays and st.overlays[slot or "main"] or nil
end

------------------------------------------------------------
-- Engine.Paint(overlay, fill, border)
--
-- 底色與四條邊一次上完。border 傳 false 表示「這次不要邊」（分頁與內容相連的
-- 那條底邊就不畫，見 feedback-ui-visual-style）。
------------------------------------------------------------
function Engine.Paint(ov, fill, border)
    if not ov then return end
    fill = fill or T.fill
    ov.bg:SetColorTexture(fill[1], fill[2], fill[3], fill[4] or 1)
    if not ov.edges then return end
    if border == false then
        for i = 1, 4 do ov.edges[i]:SetAlpha(0) end
        return
    end
    border = border or T.border
    for i = 1, 4 do
        if ov.skipEdges and ov.skipEdges[i] then
            ov.edges[i]:SetAlpha(0)
        else
            ov.edges[i]:SetAlpha(1)
            ov.edges[i]:SetColorTexture(border[1], border[2], border[3], border[4] or 1)
        end
    end
end

-- 只換底色（三態切換用，邊維持原樣）
function Engine.Fill(ov, fill)
    if not ov then return end
    ov.bg:SetColorTexture(fill[1], fill[2], fill[3], fill[4] or 1)
end

------------------------------------------------------------
-- 分頁的選中態
--
-- 暴雪兩種分頁模板（`PanelTabButtonTemplate` 與成就視窗自己的
-- `AchievementFrameTabButtonTemplate`）都是靠**兩組貼圖的 Show/Hide** 在切狀態：
-- `PanelTemplates_SelectTab` 把 Left/Middle/Right 藏起來、把 LeftActive/
-- MiddleActive/RightActive 顯示出來（Blizzard_SharedXML/Mainline/
-- SharedUIPanelTemplates.lua）。
--
-- 「讓引擎自己畫」那條路在這裡走不通：那六張貼圖是 `useAtlasSize` 的，橫向會超出
-- 分頁矩形（Left 錨在 TOPLEFT x=-3、Right 錨在 TOPRIGHT x=+7），要修就得對暴雪
-- 區域 SetPoint/SetSize —— 契約禁止。所以分頁是**整包唯一走 hook 的原語**：
-- 九張貼圖 alpha 0，選中態由這三個 hook 重畫我們自己的 overlay。
--
-- ⚠ hooksecurefunc 是後置勾，taint 不會漏回呼叫端（notes/project-charframe-taint
--   明列 hooksecurefunc 不會汙染 CharacterFrame）；hook 裡只碰我們自己的 overlay。
-- ⚠ 這三支是全遊戲共用的，每個視窗的分頁都會進來 —— 第一行就查 side table，
--   不是我們接管的分頁立刻返回。
------------------------------------------------------------
local tabState = setmetatable({}, { __mode = "k" })
local tabHooksInstalled = false

local function PaintTab(tab, mode)
    local rec = tabState[tab]
    if not rec then return end
    rec.mode = mode
    if mode == "selected" then
        local r, g, b, a = T.AccentFill(1)
        rec.accent = rec.accent or {}
        rec.accent[1], rec.accent[2], rec.accent[3], rec.accent[4] = r, g, b, a
        Engine.Fill(rec.overlay, rec.accent)
    elseif mode == "disabled" then
        Engine.Fill(rec.overlay, T.fillInset)
    elseif mode == "hover" then
        Engine.Fill(rec.overlay, T.fillHover)
    else
        Engine.Fill(rec.overlay, T.fill)
    end
end

local function InstallTabHooks()
    if tabHooksInstalled then return end
    tabHooksInstalled = true
    hooksecurefunc("PanelTemplates_SelectTab", function(tab) PaintTab(tab, "selected") end)
    hooksecurefunc("PanelTemplates_DeselectTab", function(tab) PaintTab(tab, "idle") end)
    hooksecurefunc("PanelTemplates_SetDisabledTabState", function(tab) PaintTab(tab, "disabled") end)
end

-- Primitives.Tab 建完 overlay 之後把分頁交給這裡管。
function Engine.TrackTab(tab, overlay, key)
    if not tab or not overlay then return end
    InstallTabHooks()
    tabState[tab] = { overlay = overlay, key = key, mode = "idle" }

    -- 滑過：分頁模板的 HIGHLIGHT 層是三張 useAtlasSize 的貼圖（同樣會超出矩形），
    -- 所以這裡沒有「交給引擎畫」的選項，只能掛腳本。
    -- ⚠ 用 HookScript 不是 SetScript：模板自己在 OnEnter 裡做截字提示，
    --   SetScript 會把它整個蓋掉（見 notes/wow-setscript-clobbers-hookscript）。
    if type(tab.HookScript) == "function" then
        pcall(tab.HookScript, tab, "OnEnter", function(self)
            local rec = tabState[self]
            if rec and rec.mode ~= "selected" and rec.mode ~= "disabled" then
                Engine.Fill(rec.overlay, T.fillHover)
            end
        end)
        pcall(tab.HookScript, tab, "OnLeave", function(self)
            local rec = tabState[self]
            if rec and rec.mode ~= "selected" and rec.mode ~= "disabled" then
                Engine.Fill(rec.overlay, T.fill)
            end
        end)
    end

    -- 初始同步。
    --
    -- 暴雪只有在**切換**分頁時才呼叫那三支 —— 成就視窗是在自己的 OnLoad
    -- （Blizzard_AchievementUI.lua:258-260）就把分頁 1 設成選中，而那比我們的
    -- ADDON_LOADED 更早，所以不同步的話第一次開視窗會看到「一個選中的分頁畫成閒置」。
    --
    -- ⚠ 這裡讀了一次 `LeftActive:IsShown()`。那是暴雪自己判斷選中態的**同一個**
    --   依據（SelectTab 把它 Show、DeselectTab 把它 Hide），而且 IsShown 是
    --   純 C 端的布林查詢：不是文字、不是尺寸、不是錨點，也不會回秘密值。
    --   契約允許的讀取就多這一條，而且只在建立時讀一次。
    local active
    pcall(function() active = tab.LeftActive end)
    local shown
    if active and type(active.IsShown) == "function" then
        local ok, v = pcall(active.IsShown, active)
        if ok then shown = S.ToBool(v) end
    end
    PaintTab(tab, shown == true and "selected" or "idle")
end

------------------------------------------------------------
-- 池化列（ScrollBox 的 element）—— STYLE.md ③ 的陷阱 4
--
-- ScrollBox 的列是物件池借還的：同一個 frame 這一秒是「奧術之塵」、捲兩下之後
-- 變成「虛空碎片」。所以不能「開視窗的時候套一次」，只能掛在暴雪每次重用列時
-- 一定會跑的那支上（`Init` / `Initialize` / `Saturate`…）。
--
-- ⚠⚠ **mixin hook 只對之後建立的 frame 生效。** `mixin="XxxMixin"` 是在 frame
--   **建立時**把 mixin 表裡的函式一個個複製到 frame 身上的，之後 `row:Init(...)`
--   走的是 frame 自己那份副本 —— hook 裝晚了，先建好的列永遠不會進來。
--   所以 `HookRows` 必須在「配方登記／ADDON_LOADED 當下」就裝，**不能過戰鬥閘**
--   （`hooksecurefunc` 本身在戰鬥中完全安全，它不寫任何暴雪欄位）。
--   先被建立的列另外用 `SweepRows` 補掃。
--
-- ⚠ hook 裡的紀律（這幾支在捲動時每一列都會進來，要便宜）：
--   * 第一行查弱鍵 side table，已經處理過的列只跑 `reapply`。
--   * `reapply` 只重申「暴雪每次都會重設的東西」（文字顏色、被 SetAlpha 打回的
--     區域），其餘一律放在只跑一次的 `apply`。
--   * **不讀傳進來的資料**（elementData）去做邏輯，只拿 frame 參照 ——
--     那些欄位有可能是秘密值，而且暴雪隨時會改欄位名。
--   * 動作全是非保護操作（SetAlpha／SetTextColor／SetVertexColor／建自己的框），
--     戰鬥中照做；但 `IsProtectedFrame(row)` 為真照樣跳過並記進 debug 清單。
--   * 出錯一次就把這支 hook 標成壞掉、之後直接返回 —— 捲動一次就報一百發的
--     錯誤洗版比「少一塊皮」嚴重得多。
------------------------------------------------------------
local rowState = setmetatable({}, { __mode = "k" })
Engine.RowState = rowState

local SKIP = {}   -- 保護框：記一次，之後直接返回

-- spec:
--   key           debug 用的名字
--   mixin         mixin 表（TokenEntryMixin、AchievementTemplateMixin…）
--   method        要後置勾的方法名
--   apply         function(row) 第一次見到這一列時跑（中和、建 overlay）
--   reapply       function(row) 每次都跑（暴雪會重設的東西）
--   requireKnown  true ＝ 只對 apply 過的列跑 reapply（給「只負責重申」的那種 hook，
--                 例如共用的 ListHeaderThreeSliceMixin:CheckHighlightTitle）
--   match         function(row) SweepRows 補掃時用來認「這一列是不是這個模板」
--
-- `reapply` 會收到被勾函式的**第一個額外參數**（`UpdateSelectionState(selected)` 的
-- 那顆布林）。⚠ 那是參數不是 elementData 的欄位，而且一律要過 `Secret.ToBool`
-- 才能拿來做判斷 —— 規則與理由寫在 STYLE.md ③ 的讀取例外清單。
--
-- `mixin` 傳 `_G` 就是勾一支**全域函式**（成就視窗的 `AchievementComparisonPlayer
-- Button_Saturate` 是全域不是 mixin），其餘紀律完全一樣。
--
-- 回傳一個 sweeper(row)，交給 `Engine.SweepRows`。
function Engine.HookRows(spec)
    local key = spec.key or "?"
    local mixin = spec.mixin
    if type(mixin) ~= "table" or type(mixin[spec.method]) ~= "function" then
        Engine.Missing(key .. ":" .. tostring(spec.method))
        return function() end
    end

    local function Handle(row, arg1)
        if type(row) ~= "table" then return end
        local st = rowState[row]
        if st == SKIP then return end
        if not st then
            if spec.requireKnown then return end
            if IsProtectedFrame(row) then
                Note(Engine.log.protected, key)
                rowState[row] = SKIP
                return
            end
            rowState[row] = true
            if spec.apply then spec.apply(row) end
        end
        if spec.reapply then spec.reapply(row, arg1) end
    end

    local broken = false
    local function Guarded(row, arg1)
        if broken then return end
        local ok, err = pcall(Handle, row, arg1)
        if not ok then
            broken = true
            Note(Engine.log.missing, key .. " (hook 已停用)")
            ns.ReportError(err)
        end
    end

    hooksecurefunc(mixin, spec.method, Guarded)

    return function(row)
        if broken then return end
        if spec.match then
            local ok, matched = pcall(spec.match, row)
            if not ok or not matched then return end
        end
        Guarded(row)
    end
end

-- 一次性補掃：把**已經建立**的列交給 sweeper 跑一遍。
--
-- `ScrollBox:ForEachFrame`（Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua:594）
-- 是唯讀走訪，不寫暴雪欄位。整段 pcall：視窗還沒開過的時候 view 可能還不存在。
function Engine.SweepRows(scrollBox, key, ...)
    if not Usable(scrollBox, key) then return end
    if type(scrollBox.ForEachFrame) ~= "function" then
        Engine.Missing((key or "?") .. ".ForEachFrame")
        return
    end
    -- 配方可能把「沒裝成功的 hook」傳進來（mixin 被暴雪改名 ⇒ HookRows 回 nil 之外
    -- 的那條路），所以一律過型別檢查而不是假設有值
    local fns = {}
    for i = 1, select("#", ...) do
        local fn = select(i, ...)
        if type(fn) == "function" then fns[#fns + 1] = fn end
    end
    local n = #fns
    if n == 0 then return end
    pcall(scrollBox.ForEachFrame, scrollBox, function(row)
        for i = 1, n do fns[i](row) end
    end)
end

------------------------------------------------------------
-- 登記表 ＋ 戰鬥閘
--
-- 每份配方一筆。`addon` 是暴雪的隨需載入插件名（nil 表示常駐）。
-- 狀態：pending / waiting-addon / waiting-combat / applied / disabled / error
--
-- 一筆配方有三個欄位是「要做的事」：
--   hooks  裝 mixin 後置勾。**不過戰鬥閘** —— hook 裝晚了，先建好的列就漏了
--          （陷阱 4），而 hooksecurefunc 本身在戰鬥中是安全的。只跑一次。
--   apply  中和暴雪美術、建 overlay。過戰鬥閘。
--   parts  同一個視窗裡「另一個隨需載入插件」的那一塊（角色面板的兌換通貨頁住在
--          `Blizzard_TokenUI`）。每個 part 自己一組 addon/hooks/apply，共用外層的
--          設定開關 —— 玩家看到的是一個視窗，設定裡就不該多一個勾選框。
------------------------------------------------------------
local recipes = {}
Engine.recipes = recipes

function Engine.Register(spec)
    spec.status = "pending"
    if spec.parts then
        for _, part in ipairs(spec.parts) do part.status = "pending" end
    end
    recipes[#recipes + 1] = spec
    return spec
end

local pendingCombat = false

-- 一個「單元」＝配方本身或它的一個 part。兩者的欄位長得一樣。
local function RunUnit(unit)
    if unit.status == "applied" then return end

    if unit.addon and not C_AddOns.IsAddOnLoaded(unit.addon) then
        unit.status = "waiting-addon"
        return
    end

    -- ⚠ hook 先裝，而且**在戰鬥閘前面**。理由見上面那段與陷阱 4。
    if unit.hooks and not unit.hooksDone then
        unit.hooksDone = true
        xpcall(unit.hooks, ns.ReportError)
    end

    -- 戰鬥閘。我們碰的視窗都帶著保護子物件（角色面板的裝備格、UIPanel 管理），
    -- 戰鬥中動它們最好的下場是被擋。
    if InCombatLockdown() then
        unit.status = "waiting-combat"
        pendingCombat = true
        return
    end

    if not unit.apply then
        unit.status = "applied"
        return
    end

    -- ⚠ 每份配方各自 xpcall：一份壞掉不能拖垮其他份，錯誤照常進 ns.errors 與 BugSack。
    local ok = xpcall(unit.apply, ns.ReportError)
    unit.status = ok and "applied" or "error"
end

local function RunRecipe(rec)
    if not ns.DB.IsWindowEnabled(rec.key) then
        rec.status = "disabled"
        return
    end
    RunUnit(rec)
    if rec.parts then
        for _, part in ipairs(rec.parts) do RunUnit(part) end
    end
end

function Engine.ApplyAll()
    for _, rec in ipairs(recipes) do
        RunRecipe(rec)
    end
end

local watcher
function Engine.Boot()
    Engine.ApplyAll()

    watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    watcher:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
            local name = S.PlainText(arg1)
            if not name then return end
            for _, rec in ipairs(recipes) do
                if rec.addon == name then
                    RunRecipe(rec)
                elseif rec.parts then
                    for _, part in ipairs(rec.parts) do
                        if part.addon == name then RunRecipe(rec) break end
                    end
                end
            end
        else
            if not pendingCombat then return end
            pendingCombat = false
            Engine.ApplyAll()
        end
    end)
end

------------------------------------------------------------
-- /mskin debug
------------------------------------------------------------
local L = ns.L

local function StatusText(status)
    if status == "applied" then return L["Applied"] end
    if status == "waiting-addon" then return L["Waiting for the Blizzard addon to load"] end
    if status == "waiting-combat" then return L["Waiting to leave combat"] end
    if status == "disabled" then return L["Disabled"] end
    if status == "error" then return L["Error"] end
    return L["Not applied yet"]
end

function Engine.Report()
    ns.Print(("v%s  enabled=%s"):format(ns.VERSION, tostring(ns.db and ns.db.enabled)))
    for _, rec in ipairs(recipes) do
        print(("  %s: %s"):format(rec.title or rec.key, StatusText(rec.status)))
        -- part 的名字用暴雪的插件名，那本來就不在地化
        if rec.parts then
            for _, part in ipairs(rec.parts) do
                print(("    · %s: %s"):format(part.addon or "?", StatusText(part.status)))
            end
        end
    end
    print(("  %s %d / %s %d"):format(
        L["Regions neutralized:"], Engine.log.neutralized,
        L["Overlays:"], Engine.log.overlays))

    if #Engine.log.missing > 0 then
        print("  " .. L["Regions not found (Blizzard may have renamed them):"])
        for _, v in ipairs(Engine.log.missing) do print("    " .. v) end
    end
    if #Engine.log.protected > 0 then
        print("  " .. L["Skipped because the frame is protected:"])
        for _, v in ipairs(Engine.log.protected) do print("    " .. v) end
    end
    if #Engine.log.forbidden > 0 then
        print("  " .. L["Skipped because the object is forbidden:"])
        for _, v in ipairs(Engine.log.forbidden) do print("    " .. v) end
    end
    if #ns.errors == 0 then
        print("  " .. L["No errors recorded"])
    else
        for i, err in ipairs(ns.errors) do
            print(("  %d. %s"):format(i, err))
        end
    end
end
