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
-- 「這張貼圖是我們自己畫的」
--
-- `Engine.RegionBackdrop` 把底與邊建成**暴雪框自己的 region**，所以
-- `GetRegions()` 那一類的掃描（`NeutralizeRegions` / `TintRegions`）會掃到它們。
-- 同一個框被掃第二次（配方重跑、隨需載入的視窗被套兩次）就會把我們自己的底
-- 中和掉 —— 症狀是「第一次開有皮、第二次開沒有」，而且完全不報錯。
--
-- 所以每一張我們建的 region 都記在這裡，掃描時按物件識別跳過。
-- 弱鍵：暴雪回收了那個框，這裡跟著消失。
------------------------------------------------------------
local ownRegions = setmetatable({}, { __mode = "k" })
Engine.ownRegions = ownRegions

------------------------------------------------------------
-- debug 紀錄
--
-- 配方裡找不到的區域**只記錄不報錯**：暴雪改版會改名，一個名字對不上不應該讓
-- 整份配方掛掉。`/mskin debug` 把這幾張清單印出來，就是下次改版的待辦。
--
-- ⚠ **紀錄要記在「哪一份配方」身上。** 第三輪只有六份配方的時候，一張全域的
--   `missing` 清單印出來還讀得完；第四輪之後十幾份配方一起套，那張清單會變成
--   幾十行沒有主人的字串 —— 看得到但查不動。所以現在每一份配方自己帶一格
--   （`rec.log.missing` / `.protected` / `.forbidden`），只有**執行期**才發生的
--   紀錄（池化列的 hook、全域物品格後置勾）才落在下面這張共用的表上。
--   分流的開關是 `currentOwner`：只有在跑某份配方的 hooks／apply／companions
--   期間它才有值。
------------------------------------------------------------
Engine.log = {
    neutralized = 0,      -- 成功中和幾個區域（**只算第一次**，見 Engine.Neutralize）
    overlays    = 0,      -- 建了幾個 overlay（子框那條路）
    regions     = 0,      -- 建了幾個 region 背景（直接建在暴雪框上那條路）
    frameBackdrop = {},   -- 想走 region、但退回子框的（參考資料，不算問題）
    missing     = {},     -- 配方指名、但物件不存在的區域（執行期發生的那些）
    protected   = {},     -- **顯式**保護、刻意跳過的框
    implicit    = {},     -- **隱式**保護（有 secure 子孫／錨點）、照樣上皮的框
    deferred    = {},     -- 隱式保護 ＋ 正在戰鬥 ⇒ 這次不做，等下一次
    forbidden   = {},     -- 動態 forbidden、跳過的框
    brokenHooks = {},     -- 出過錯、已經被停用的 hook（`/mskin debug` 的第一節）
}

-- 目前正在跑哪一份配方。nil ＝ 執行期（hook 裡），紀錄落回 Engine.log。
local currentOwner

local function Note(list, label)
    if not list or not label then return end
    for _, v in ipairs(list) do
        if v == label then return end
    end
    list[#list + 1] = label
end

-- 這一筆紀錄該記在誰身上
local function Bucket(kind)
    local owner = currentOwner
    if not owner then return Engine.log[kind] end
    owner.log = owner.log or {}
    owner.log[kind] = owner.log[kind] or {}
    return owner.log[kind]
end

function Engine.Missing(label)
    Note(Bucket("missing"), label)
end

-- hook 出錯一次就停用（捲動一次報一百發比少一塊皮嚴重得多）。停用的 hook 是
-- **最要緊**的一種訊息 —— 它代表「這個視窗從某一刻起就不再上皮了」，所以獨立
-- 記一張表，`/mskin debug` 放在最上面。
function Engine.NoteBrokenHook(label)
    Note(Engine.log.brokenHooks, label)
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
        Note(Bucket("forbidden"), label or "?")
        return false
    end
    return true
end
Engine.Usable = Usable

------------------------------------------------------------
-- 保護框分兩種：**顯式**跳過、**隱式**照做
--
-- `IsProtected()` 回**兩個**值：`isProtected, isProtectedExplicitly`。
--   * 顯式（兩個都真）＝這個框自己就是 `SecureFrameTemplate` 系的
--     （玩具格 `CollectionsSpellButtonTemplate`、快捷列按鈕…）。
--   * 隱式（第一個真、第二個假）＝**它身上掛了／錨了一個保護框**，保護沿著
--     parent／anchor 鏈往上傳染（warcraft.wiki `Region:IsProtected`：
--     "Anchoring or parenting a protected frame to another frame makes that frame
--      implicitly protected as well… This applies recursively."）。
--
-- 第四輪只看第一個回傳值 ⇒ **整個收藏視窗與玩具箱的格子底都被跳過**：
-- 18 顆 secure 玩具格把 `ToyBox.iconsFrame` → `ToyBox` → `CollectionsJournal`
-- 一路染成隱式保護，結果玩家看到的是「一個沒有底的視窗」（實機擷圖 20）。
-- 分頁、搜尋框、進度條不在那條鏈上，所以它們有皮 —— 那個對比就是指紋。
--
-- 第五輪的規則：**只有顯式保護才跳過。**
-- 隱式保護的容器准許掛 overlay，理由是我們對它做的事只有兩件，兩件都不是
-- 保護操作：`CreateFrame` 一個**不受保護的**普通子框、然後把那個子框錨在它身上。
-- 我們從來不對它 Show／Hide／SetPoint／SetSize／SetAttribute ——
-- 那些才是戰鬥中會被擋下來的動作。
--
-- ⚠ 但「建立子框並設錨點」在戰鬥中對隱式保護的框仍然可能被擋
--   （`CreateFrame` 以它為 parent ＝ 動它的子框清單）。所以戰鬥中遇到隱式保護
--   就**這次不做、也不標記成已處理**，等脫戰後的補掃或下一次 Init 再做
--   （`Engine.Overlay` 與 `Engine.HookRows` 兩個入口都擋）。
--
-- 三種結果記進三張不同的清單，`/mskin debug` 分開印 —— 「跳過了」跟「照做了」
-- 是完全不同的訊息。
------------------------------------------------------------
local function ProtectionOf(obj)
    if type(obj) ~= "table" or type(obj.IsProtected) ~= "function" then return "none" end
    local ok, protected, explicitly = pcall(obj.IsProtected, obj)
    if not ok then return "explicit" end      -- 問不到就 fail 到最保守的那一邊
    if S.ToBool(protected) ~= true then return "none" end
    return S.ToBool(explicitly) == true and "explicit" or "implicit"
end
Engine.ProtectionOf = ProtectionOf

-- 舊名保留（只回答「顯式嗎」）：SafeParent 與物品格都只在意這一邊。
local function IsProtectedFrame(obj)
    return ProtectionOf(obj) == "explicit"
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
        local st = State[obj] or {}
        -- ⚠ 計數器只算**第一次**。很多區域是暴雪每次更新都會把 alpha 設回來的
        --   （成就列的標題帶、物品格的品質框），那些一律放在 reapply 裡重申 ——
        --   每次都加一次的話 `/mskin debug` 的「中和了幾個區域」會跟著捲動一路長到
        --   幾千，那個數字就不再是「這份配方認得幾塊美術」而是「跑了幾次」。
        if not st.neutralized then
            Engine.log.neutralized = Engine.log.neutralized + 1
            st.neutralized = true
        end
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
--
-- `exclude` 有兩種寫法：
--   * 單一 region —— 「不是裝飾」的那一張（StatusBar 的填充貼圖）。
--   * **一張 set**（`{ [region] = true, ... }`）—— 物品格那種「一顆按鈕上十幾張
--     貼圖，只有其中三張是裝飾」的情況。物品格的裝飾（`Char-LeftSlot` 那一圈雕花、
--     武器欄兩側的括號）是**無名無 parentKey** 的，指名不到；反過來「要留下的」
--     （icon／IconBorder／IconOverlay／NormalTexture…）全部有 parentKey 或 getter，
--     所以改成「列出要留的，其餘全掃」才是可寫的那一邊。
function Engine.NeutralizeRegions(owner, prefix, exclude)
    if not Usable(owner, prefix) then return end
    if type(owner.GetRegions) ~= "function" then return end
    local ok, regions = pcall(function() return { owner:GetRegions() } end)
    if not ok then return end

    -- 單一 region 與 set 兩種簽章：有 GetObjectType 就是「一張貼圖」，否則當成 set。
    local keep
    if type(exclude) == "table" then
        if type(exclude.GetObjectType) == "function" then
            keep = { [exclude] = true }
        else
            keep = exclude
        end
    end

    for i, region in ipairs(regions) do
        -- ⚠ 跳過我們自己畫的底與邊（`Engine.RegionBackdrop` 建的就是這個框的 region）
        if type(region) == "table" and not (keep and keep[region]) and not ownRegions[region]
            and type(region.GetObjectType) == "function" then
            local ok2, kind = pcall(region.GetObjectType, region)
            if ok2 and kind == "Texture" then
                Engine.Neutralize(region, (prefix or "?") .. ".region" .. i)
            end
        end
    end
end

------------------------------------------------------------
-- 「要留下的」set —— `NeutralizeRegions` 的 `exclude` 參數
--
-- 第四輪有三份配方各自寫了一支一模一樣的 local `KeepSet`（郵件、商人、試衣間），
-- 差別只在「有沒有順手把 getter 拿到的那幾張也留下」。升格進來。
--   keys    ＝ parentKey 清單（`Icon`、`IconBorder`…）
--   getters ＝ getter 名稱清單（`GetHighlightTexture`…）——
--             ⚠ Highlight 幾乎一定要留：中和過的貼圖再也上不了色
--             （區域 alpha 與顏色 alpha 相乘，見 `Engine.ButtonStates`）。
------------------------------------------------------------
function Engine.KeepSet(owner, keys, getters)
    local set = {}
    if type(owner) ~= "table" then return set end
    for _, k in ipairs(keys or {}) do
        local region
        if pcall(function() region = owner[k] end) and type(region) == "table" then
            set[region] = true
        end
    end
    for _, g in ipairs(getters or {}) do
        if type(owner[g]) == "function" then
            local ok, tex = pcall(owner[g], owner)
            if ok and tex then set[tex] = true end
        end
    end
    return set
end

-- 走訪自己的 region，把 **FontString** 全部重新上色（貼圖不動）。
--
-- 給「換掉了內容底材，上面的字卻是無名無 parentKey」的情況用（讀信視窗的發票／
-- 訂單收據裡有好幾條 `InvoiceTextFontNormal` 的 `+` `-` 與數量，只有位置沒有名字）。
-- 換底材就要**連同上面所有文字顏色一起接管**（STYLE.md ③ 的內容底材規則），
-- 指名不到的那幾條只剩這條路。
--
-- ⚠ 只掃 owner 自己的 region，不遞迴進子框：子框各自有自己的規則
--   （金錢框的數字走字型物件、不是 SetTextColor），一路掃下去會把值也染掉。
function Engine.RecolorRegions(owner, color, prefix)
    if not Usable(owner, prefix) then return end
    if type(owner.GetRegions) ~= "function" then return end
    local ok, regions = pcall(function() return { owner:GetRegions() } end)
    if not ok then return end
    for i, region in ipairs(regions) do
        if type(region) == "table" and type(region.GetObjectType) == "function" then
            local ok2, kind = pcall(region.GetObjectType, region)
            if ok2 and kind == "FontString" then
                Engine.TextColor(region, color, (prefix or "?") .. ".text" .. i)
            end
        end
    end
end

-- 走訪自己的 region，把 **Texture** 全部染成同一個顏色（FontString 不動）。
--
-- 給「這張圖是資訊、不能中和，但它連名字都沒有」的情況用。
-- 實例：好友名單線上／離線之間那條分隔線（`FriendsFrameFriendDividerTemplate`，
-- Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:50-56）——
-- 整個模板就是一張**無名**的 `UI-FriendsFrame-OnlineDivider`，中和掉等於把
-- 「以下是離線的」這條分界線整個拿掉，所以只能染暗一階。
--
-- ⚠ 跟 `NeutralizeRegions` 一樣只掃 owner 自己的 region，不遞迴進子框。
function Engine.TintRegions(owner, color, prefix)
    if not Usable(owner, prefix) then return end
    if type(owner.GetRegions) ~= "function" then return end
    local ok, regions = pcall(function() return { owner:GetRegions() } end)
    if not ok then return end
    for i, region in ipairs(regions) do
        -- ⚠ 同 NeutralizeRegions：我們自己畫的底與邊不進來（染了會把皮弄糊）
        if type(region) == "table" and not ownRegions[region]
            and type(region.GetObjectType) == "function" then
            local ok2, kind = pcall(region.GetObjectType, region)
            if ok2 and kind == "Texture" then
                Engine.VertexColor(region, color, (prefix or "?") .. ".region" .. i)
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

-- 一次性重錨「整條錨定鏈的根」—— 只重畫不重排的**唯一**例外（STYLE.md ③）
--
-- 有些暴雪視窗的版面是為原本的美術排的（專業技能書：內容為了讓出書脊，整批偏右），
-- 美術拿掉之後留白就不對稱了。內容若是「一條錨定鏈掛在同一個根框上」，把根框
-- 平移一次，整批就跟著移動，不必碰其他任何東西。
--
-- 條件（缺一不可，配方要在呼叫處寫明 XML 原值與出處）：
--   * 只准這一支呼叫 SetPoint；lint 照樣禁止配方直接寫。
--   * 只在脫戰時做（根框底下常有 secure 子孫 ⇒ 隱式保護，戰鬥中動它會被擋）。
--     戰鬥中回傳 false，呼叫端的 apply 本來就過戰鬥閘，這裡是第二道。
--   * 用**同一個錨點名稱**重設（同名的 SetPoint 是覆寫，不必 ClearAllPoints），
--     相對框、相對點、另一軸的位移照 XML 原值給，只改要調的那一軸。
--   * 暴雪的 Lua 不能有任何地方重設或讀回這個框的位置（先 grep 過）。
--   * 不寫任何 Lua 欄位；`MiliUI_Skin_DB.relayout == false` 可以整批關掉。
function Engine.ShiftRoot(frame, point, relativeTo, relativePoint, x, y, label)
    if ns.db and ns.db.relayout == false then return false end
    if not Usable(frame, label) or not relativeTo then return false end
    if type(frame.SetPoint) ~= "function" then return false end
    if InCombatLockdown() then
        Note(Bucket("deferred"), (label or "?") .. " (relayout)")
        return false
    end
    local ok = pcall(frame.SetPoint, frame, point, relativeTo, relativePoint, x, y)
    return ok and true or false
end

-- 拿掉圖示上的遮罩（圓形圖示 → 方形圖示）
--
-- ⚠ 契約例外（STYLE.md ③）：`RemoveMaskTexture` 是對暴雪區域的**結構性修改**，
--   只准用在「純裝飾的圓形遮罩」上、只准由這一支呼叫、只在脫戰時做：
--     * 它不寫任何 Lua 欄位；遮罩是 XML 寫死的，暴雪不會在執行期把它加回來，
--       也沒有程式讀它（大類按鈕的 `CircleMask` 在 .lua 裡零引用）。
--     * 理由是風格：整包的圖示一律是方形＋1px 硬邊，圓形遮罩切出來的邊是軟的，
--       不管外圈墊什麼，接在純色底上都是一圈毛邊／暗暈。
--   回傳 true 才代表真的拿掉了；呼叫端要用它決定要不要接著裁邊與畫方框
--   （遮罩還在就裁邊＋畫方框，會變成「方框裡一顆圓圖」）。
function Engine.UnmaskIcon(tex, mask, label)
    if not Usable(tex, label) then return false end
    if not mask then
        Engine.Missing((label or "?") .. ".mask")
        return false
    end
    if type(tex.RemoveMaskTexture) ~= "function" then return false end
    if InCombatLockdown() then return false end
    local ok = pcall(tex.RemoveMaskTexture, tex, mask)
    return ok and true or false
end

-- 圖示裁邊：把暴雪圖示四周那圈暗邊切掉，才對得上 1px 硬邊的直角語彙
function Engine.CropIcon(tex, label)
    if not Usable(tex, label) then return end
    if type(tex.SetTexCoord) ~= "function" then return end
    local c = T.iconCrop
    pcall(tex.SetTexCoord, tex, c, 1 - c, c, 1 - c)
end

------------------------------------------------------------
-- 去飽和：把「顏色烤在素材裡」的小圖示壓成灰階，才染得動
--
-- `SetVertexColor` 是**乘法**：素材本身是紅底金框的 ＋／− 鈕
-- （`campaign_headericon_closed`／`_open`），乘上 `textDim` 只會變成暗紅金，
-- 永遠乘不出中性灰。先 `SetDesaturated(true)` 把它壓成灰階、再乘就準了。
-- （關閉鈕的 × 當年踩的是同一個坑，那次的解法是「不要用那張圖、自己畫線」——
--   這裡的圖形本身（＋／−）是資訊，畫不出來，所以只能走去飽和。）
--
-- ⚠ 純視覺、只對 region，不是「補一張貼圖」也不是改結構。
-- ⚠ `SetDesaturated` 是貼圖自己的狀態，**跟 SetAtlas 互不干涉**，但
--   `ReputationSubHeaderToggleCollapseButtonMixin:RefreshIcon` 每次收合都重設 atlas，
--   為了不去賭「去飽和撐不撐得過」，配方一律把它放在 reapply。
function Engine.Desaturate(tex, label)
    if not Usable(tex, label) then return false end
    if type(tex.SetDesaturated) ~= "function" then
        Engine.Missing(label)
        return false
    end
    local ok = pcall(tex.SetDesaturated, tex, true)
    return ok
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
--
-- ⚠ `ownHover` ＝「這顆按鈕的滑過由我們自己畫」（職業色邊框，見 TrackButtonHover）
--   ⇒ 暴雪那張 Highlight 要**中和**而不是換成白 8%，否則兩層疊在一起：
--   一層我們的職業色邊 ＋ 一層引擎的白色提亮，亮度變成兩倍、而且色相被沖淡。
function Engine.ButtonStates(btn, label, withPushed, ownHover)
    if not Usable(btn, label) then return end

    if type(btn.GetHighlightTexture) == "function" then
        local ok, hl = pcall(btn.GetHighlightTexture, btn)
        if ok and hl then
            if ownHover then
                Engine.Neutralize(hl, (label or "?") .. ".GetHighlightTexture")
            elseif type(hl.SetColorTexture) == "function" then
                pcall(hl.SetColorTexture, hl, 1, 1, 1, T.highlightAlpha)
            end
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
-- 零腳本的按鈕變體（第九輪）
--
-- 確認彈窗、ESC 選單、寶庫、拍賣場／專業的「通往受保護請求」按鈕都不准掛任何
-- 腳本（STYLE.md ⑦ 的兩條特許），所以 `Engine.TrackButtonHover` 那一套
-- （HookScript OnEnter/OnLeave/OnEnable/OnDisable）用不上。primary 的三態只能
-- 交給**引擎自己依狀態顯示的貼圖**：
--
--   滑過 ＝ `GetHighlightTexture()` → `SetColorTexture(保護色, buttonHoverAddAlpha)`。
--          ⚠ **前提是那張 Highlight 是 `alphaMode="ADD"`**（HIGHLIGHT 層在文字之上；
--          ADD 只會把底下變亮，白字加任何東西還是白字；換成 BLEND 就會把字蓋掉）。
--          呼叫端要查證過模板再傳 primary：
--            `UIPanelButtonHighlightTexture`（SharedUIPanelTemplates.xml:3，ADD，無錨點＝鋪滿）
--            `StaticPopupButtonTemplate` 的 HighlightTexture（GameDialog.xml:43，ADD，無錨點）
--   停用 ＝ `GetDisabledTexture()` → `SetAlpha(1)` ＋ `SetColorTexture(fillInset)`。
--          引擎只在停用時畫它，而它是按鈕自己的 region ⇒ 蓋在我們的 overlay（層級 −1）
--          之上，整顆變成中性的暗底。⚠ 它跟按鈕同矩形 ⇒ 會連 overlay 的邊一起蓋掉，
--          所以停用色用 `fillInset`（0.08，「凹下去的槽」）而不是 `fill`：
--          沒有黑邊的 `fill` 擺在 0.133 的提示皮底上幾乎看不見。
--          ⚠ `SetAlpha(1)` 是必要的：它可能先被 `Neutralize` 過，區域 alpha 與
--          顏色 alpha 相乘（註 ⓔ 的二選一）。
--   按下 ＝ `opts.pushed` 有給、而且模板的 Pushed **沒有 Lua 重設**時才換成黑 `pushedAlpha`。
--
-- **沒有 DisabledTexture 的模板（`UIPanelButtonTemplate` 系）做不到停用態** ⇒
--   平時的 primary 底**不畫**（維持 `fill` ＋ 黑邊），只留滑過的職業色 —— 少一態，
--   而且少的是「平時」不是「停用」：停用的按鈕看起來像能按，比主按鈕不夠顯眼嚴重
--   （出價／直購／製作常常是停用的）。回傳值讓呼叫端知道走了哪一條：
--     "secondary" / "primary"（三態俱全）/ "hoverOnly"（沒有 DisabledTexture）
--
-- ⚠ 這一支**不掛任何腳本**，只對 C 端依狀態顯示的三張貼圖做白名單動作
--   （`SetColorTexture` 對 Highlight／Pushed／**Disabled**，第九輪把 Disabled 加進白名單）。
------------------------------------------------------------
function Engine.ScriptlessButton(btn, ov, variant, label, opts)
    if not ov or not Usable(btn, label) then return nil end
    opts = opts or {}

    if variant == "secondary" then
        Engine.ButtonStates(btn, label, opts.pushed)
        Engine.Paint(ov, T.fill, T.border)
        return "secondary"
    end

    local function State(getter)
        if type(btn[getter]) ~= "function" then return nil end
        local ok, tex = pcall(btn[getter], btn)
        if ok and tex and type(tex.SetColorTexture) == "function" then return tex end
        return nil
    end

    local hl = State("GetHighlightTexture")
    if hl then
        local r, g, b = T.AccentHover()
        pcall(hl.SetAlpha, hl, 1)
        pcall(hl.SetColorTexture, hl, r, g, b, T.buttonHoverAddAlpha)
    end

    if opts.pushed then
        local pushed = State("GetPushedTexture")
        if pushed then
            pcall(pushed.SetAlpha, pushed, 1)
            pcall(pushed.SetColorTexture, pushed, 0, 0, 0, T.pushedAlpha)
        end
    end

    local dis = State("GetDisabledTexture")
    if dis then
        local c = T.fillInset
        pcall(dis.SetAlpha, dis, 1)
        pcall(dis.SetColorTexture, dis, c[1], c[2], c[3], c[4] or 1)
        Engine.Paint(ov, { T.AccentButton() }, { T.AccentButtonBorder() })
        return "primary"
    end

    Engine.Paint(ov, T.fill, T.border)
    return "hoverOnly"
end

------------------------------------------------------------
-- 「已勾／已選」的那張貼圖 —— 跟 Highlight／Pushed 同一條理由
--
-- `GetCheckedTexture()` / `GetDisabledCheckedTexture()` 拿到的貼圖，跟
-- Highlight／Pushed 一樣是**C 端依自己的狀態顯示／隱藏**的：我們只換「長什麼樣」，
-- 沒有掛腳本、沒有寫欄位、沒有 `SetChecked`，勾沒勾照樣是暴雪說了算。
-- 所以 `SetColorTexture` 的白名單從「只准用在 Highlight／Pushed」擴成也含 Checked。
--
-- 為什麼要換：暴雪的已勾樣式有兩種，方框裡一個細勾（`UI-CheckBox-Check`）與
-- 圓鈕裡一顆小圓點（`UI-RadioButton` 的第二格）。兩種在 14~16 像素的深底方框上
-- 都幾乎看不出來（寄信頁的「寄送金錢／付款取信」實測就是這個症狀）。
-- 換成**整格填滿職業色**之後，「有沒有勾」變成「這格是不是亮的」，一眼就分得出來。
--
-- ⚠ Checked 貼圖的矩形通常**等於按鈕矩形**（`UICheckButtonTemplate` 的
--   `UI-CheckBox-Check` 沒有 Size 也沒有 Anchor ⇒ setAllPoints；
--   `UIRadioButtonTemplate` 的三張都是整顆 16x16 的 TexCoord 切片）
--   ⇒ 填滿之後會蓋掉 overlay 的 1px 黑邊。所以 `Skin.CheckBox` 的邊要另外畫在
--   **前景 slot**（levelOffset +1），跟 StatusBar 同一個作法。
function Engine.CheckedTexture(cb, color, disabledColor, label)
    if not Usable(cb, label) then return end

    local function Paint(getter, c)
        if type(cb[getter]) ~= "function" or not c then return end
        local ok, tex = pcall(cb[getter], cb)
        if ok and tex and type(tex.SetColorTexture) == "function" then
            -- 模板裡常常帶 alphaMode="ADD"（`CheckButtonHilight`）與 alpha < 1，
            -- 區域 alpha 會跟顏色 alpha 相乘 ⇒ 一定要連 SetAlpha(1) 一起下，
            -- 否則填色會被壓成半透明（同 Engine.HighlightTexture 的理由）。
            pcall(tex.SetAlpha, tex, 1)
            pcall(tex.SetColorTexture, tex, c[1], c[2], c[3], c[4] or 1)
        end
    end

    Paint("GetCheckedTexture", color)
    Paint("GetDisabledCheckedTexture", disabledColor or color)
end

------------------------------------------------------------
-- 「已勾」＝**保留勾的形狀**、只把它染成職業色（第六輪換掉上面那一支）
--
-- 上面的 `Engine.CheckedTexture` 把 Checked 貼圖整張塗成一塊純色
-- （`SetColorTexture`）。它的矩形等於按鈕矩形（setAllPoints），所以實機上看到的
-- 是**一整格職業色的大方塊**（使用者的原話：「方塊好醜」，實機擷圖 33）。
--
-- 套組自己的設定視窗（共用層 `Widgets.lua` 的 `W.CreateCheckButton`）是另一套：
-- 深色小方框 ＋ 一個職業色的**勾**，而且勾刻意比框大一圈往外溢。
-- 暴雪視窗這邊對齊它的方法是：
--   * 方框由 overlay 畫成固定邊長、置中（`T.checkBoxSize`，見 `Skin.CheckBox`）；
--   * 勾**不換形狀**，只 `SetDesaturated(true)` ＋ `SetVertexColor(職業色)`。
--     Checked 貼圖仍然是整顆按鈕大，比我們 18 的方框大 ⇒ 往外溢的效果自動成立。
--
-- ⚠ **為什麼不 `SetAtlas("checkmark-minimal")`**（那是被核准過的一條窄路）：
--   那張 atlas 不是正方形（共用層自己就要 `w = h * (width/height)` 去換算），
--   而 Checked 貼圖的矩形是 setAllPoints 的**正方形**按鈕 —— 換上去會被拉扁。
--   要修正比例就得對暴雪區域 `SetSize`／`SetPoint`，契約禁止。
--   所以維持暴雪自己的勾（`UI-CheckBox-Check` 本來就是正方形素材），只換顏色。
--
-- ⚠ 去飽和是**必要的**，不是順手：`SetVertexColor` 是乘法，
--   `UI-CheckBox-Check` 本身是暗金色的，直接乘職業色只會變成暗金偏色
--   （同 `Engine.Desaturate` 那一段的紅金 ＋／− 鈕）。
-- ⚠ 一律連 `SetAlpha(1)` 一起下：模板常常帶 `alphaMode="ADD"` 與 alpha < 1。
-- ⚠ 跟 `Engine.CheckedTexture` 一樣，這裡**沒有** `SetChecked`、沒有腳本 ——
--   勾沒勾仍然完全是 C 端說了算，我們只換那張圖長什麼樣。
------------------------------------------------------------
-- 已經替哪幾張 Checked 貼圖掛過我們的勾形遮罩（弱鍵；暴雪物件上零欄位寫入）
local checkMasks = setmetatable({}, { __mode = "k" })

-- 平面勾：純色 ＋ `checkmark-minimal` 的形狀。
--
-- 做法跟共用層 `W.CreateCheckButton` 一樣：**顏色與形狀分離** —— 貼圖鋪純色
-- （`SetColorTexture`，不是染一張有陰影高光的素材 ⇒ 完全平面，而且顏色就是職業色本身，
-- 不會被素材的灰階壓暗），形狀用那張 atlas 的 alpha 當遮罩摳出來。
--
-- ⚠ 這一支對暴雪的 **Checked／DisabledChecked 狀態貼圖** 做了三件契約例外（STYLE.md ③）：
--   1. `ClearAllPoints` ＋ `SetPoint("CENTER")` ＋ `SetSize`：那張貼圖預設鋪滿整顆按鈕（正方形），
--      而 `checkmark-minimal` 不是正方形 —— 不重設尺寸就會被拉扁（第六輪因此沒用它）。
--      暴雪不會重新定位狀態貼圖；會在執行期 `SetCheckedTexture(...)` 重設**材質**的模板
--      （指定地城清單）由呼叫端放進 reapply，錨點與遮罩都還在，只要重上顏色。
--   2. `CreateMaskTexture`（在按鈕上建一個我們的遮罩 region）＋ `AddMaskTexture`。
--      跟 `CreateTexture` 同一類：只建、不寫欄位、不碰 secure 屬性。
--      遮罩與貼圖同一個矩形 ⇒ 沒有「遮罩外面取樣到 atlas 鄰居」的問題。
--   3. 顯示與否仍然**完全由 C 端依勾選狀態決定**，我們沒有掛任何腳本。
--   任何一步失敗就退回 "tint"（保留暴雪的勾、去飽和染色）。
local function FlatCheck(cb, tex, c, boxSize)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("checkmark-minimal")
    if not info or not info.width or not info.height or info.height <= 0 then return false end
    if type(cb.CreateMaskTexture) ~= "function" or type(tex.AddMaskTexture) ~= "function" then
        return false
    end

    local h = T.checkGlyphHeight * ((boxSize or T.checkBoxSize) / T.checkBoxSize)
    local w = h * (info.width / info.height)

    local ok = pcall(function()
        tex:ClearAllPoints()
        tex:SetPoint("CENTER", cb, "CENTER", 0, 0)
        tex:SetSize(P.Scale(w), P.Scale(h))
        tex:SetAlpha(1)
        tex:SetDesaturated(false)
        tex:SetVertexColor(1, 1, 1, 1)
        tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end)
    if not ok then return false end

    if not checkMasks[tex] then
        local okMask, mask = pcall(cb.CreateMaskTexture, cb)
        if not okMask or not mask then return false end
        local okSet = pcall(function()
            mask:SetAtlas("checkmark-minimal")
            mask:SetAllPoints(tex)
            tex:AddMaskTexture(mask)
        end)
        if not okSet then return false end
        checkMasks[tex] = mask
    end
    return true
end

-- opts.boxSize  方框邊長（勾的大小跟著等比縮放）
-- opts.radio    單選鈕：不是打勾，而是框內一個置中的實心小方塊（約框的一半），同樣純色
function Engine.CheckedGlyph(cb, color, disabledColor, label, opts)
    if not Usable(cb, label) then return end
    opts = opts or {}

    local function Tint(tex, c)
        pcall(tex.SetAlpha, tex, 1)
        if type(tex.SetDesaturated) == "function" then
            pcall(tex.SetDesaturated, tex, true)
        end
        if type(tex.SetVertexColor) == "function" then
            pcall(tex.SetVertexColor, tex, c[1], c[2], c[3], c[4] or 1)
        end
    end

    local function Dot(tex, c)
        local size = (opts.boxSize or T.checkBoxSize) / 2
        return pcall(function()
            tex:ClearAllPoints()
            tex:SetPoint("CENTER", cb, "CENTER", 0, 0)
            tex:SetSize(P.Scale(size), P.Scale(size))
            tex:SetAlpha(1)
            tex:SetDesaturated(false)
            tex:SetVertexColor(1, 1, 1, 1)
            tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        end)
    end

    local function Paint(getter, c)
        if type(cb[getter]) ~= "function" or not c then return end
        local ok, tex = pcall(cb[getter], cb)
        if not ok or not tex then return end
        if opts.radio then
            if Dot(tex, c) then return end
        elseif T.checkStyle == "flat" then
            if FlatCheck(cb, tex, c, opts.boxSize) then return end
        end
        Tint(tex, c)
    end

    Paint("GetCheckedTexture", color)
    Paint("GetDisabledCheckedTexture", disabledColor or color)
end

------------------------------------------------------------
-- StatusBar 的填充材質
--
-- 暴雪那幾張填充圖（`UI-StatusBar`、`UI-Character-Skills-Bar`）自帶漸層與上緣高光，
-- 疊在 1px 硬邊的直角語彙上像是另一個時代的零件。換成套組自己的細橫紋。
--
-- ⚠ **換材質之前一定要先查「有沒有程式讀回那張圖」**（STYLE.md ⑥ 第 2 步的第三問）。
--   這三種條查過了：
--     `ReputationBarMixin`（ReputationFrame.lua:619）只 `SetStatusBarColor`，不讀圖；
--     `AchievementProgressBarTemplate` 的 OnLoad（Blizzard_AchievementUI.xml:1912）
--       與 `AchievementFrameSummaryCategoryTemplate` 的 OnLoad（同檔 :565）
--       各 `GetStatusBarTexture():SetDrawLayer("BORDER")` **一次**，是寫不是讀，
--       而且在 frame 建立當下就跑完了。
--   ⇒ 沒有 `GetAtlas()` / `GetTexture()` 讀回，換材質安全（對照註 ⓑ 的捲軸拇指，
--      那一個就是因為有讀回才只能 alpha）。
--
-- ⚠ 顏色**不從這裡走**。`SetStatusBarColor` 在契約裡是禁止的（12.1 顏色分量可能是
--   秘密數字），要染色一律走 `Skin.StatusBar` 的 `opts.color` → 貼圖的 SetVertexColor。
function Engine.BarTexture(bar, path, label)
    if not Usable(bar, label) then return end
    if type(bar.SetStatusBarTexture) ~= "function" then
        Engine.Missing((label or "?") .. ".SetStatusBarTexture")
        return
    end
    pcall(bar.SetStatusBarTexture, bar, path)
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
-- 篩選下拉的文字顏色（第四輪才解開的那一條）
--
-- `WowStyle1FilterDropdownTemplate` 的 `Text` 是 `GameFontNormal`（暗金），
-- 壓在我們的 `fillInset` 上偏灰。第二／三輪的結論是「改不了」——
-- 理由是它的字型物件由 `baseFontObject` **欄位**驅動，而契約禁止寫暴雪欄位。
--
-- 第四輪重查（12.1 live），結論改了。完整路徑只有三條，全部查證過：
--   Blizzard_Menu/MenuTemplates.lua:954  `WowStyle1FilterDropdownMixin:OnLoad`
--     :960-964 只有**設過** `baseFontObject` 才 `Text:SetFontObject(...)`；
--              沒設就走 else 把現況記起來 ⇒ 成就視窗那顆根本不會被 OnLoad 改
--              （Blizzard_AchievementUI.xml:1702-1707 沒有設 baseFontObject）。
--   同檔 :991  `:OnEnable`  → :994 `Text:SetFontObject(self.baseFontObject)`
--   同檔 :997  `:OnDisable` → :1000 `Text:SetFontObject(self.disableFontObject)`
--   同檔 :987  `:OnButtonStateChanged` → :988 **只動 Background 的 atlas**，不碰文字。
--
-- 關鍵是後兩條在模板裡是**frame script**，不是只能從 mixin 表走的方法：
--   Blizzard_Menu/Mainline/MenuTemplates.xml:113,114
--     `<OnEnable method="OnEnable"/>` / `<OnDisable method="OnDisable"/>`
-- ⇒ `HookScript` 就接得到，而且**對已經建好的那一顆也有效**
--   （mixin 後置勾對它沒用：frame 建立時就把函式拷走了，陷阱 4）。
--   接觸面也只有我們指名的那一顆，不像勾 mixin 表會讓全遊戲的篩選下拉都進來。
--
-- 所以這裡對「按鈕的 FontString」破例用 `SetTextColor`（註 ⓔ 的例外）：
-- 條件是**把所有會重設它的路徑都接住**，而上面那張表就是全部。
-- 停用態交回暴雪的語彙（`textDisabled`），維持「狀態只換明暗」。
------------------------------------------------------------
function Engine.DropdownText(dd, color, disabledColor, label)
    if not Usable(dd, label) then return end
    local fs
    if not (pcall(function() fs = dd.Text end) and fs) then
        Engine.Missing((label or "?") .. ".Text")
        return
    end

    Engine.TextColor(fs, color, (label or "?") .. ".Text")

    -- 重申：兩個 script 都是暴雪自己 SetFontObject 的地方，後掛在它後面就贏。
    -- ⚠ HookScript 不是 SetScript —— 模板自己的 OnEnable/OnDisable 還要跑
    --   （`ButtonStateBehaviorMixin.OnEnable` 會重算背景 atlas）。
    if type(dd.HookScript) ~= "function" then return end
    pcall(dd.HookScript, dd, "OnEnable", function(self)
        Engine.TextColor(self.Text, color, label)
    end)
    pcall(dd.HookScript, dd, "OnDisable", function(self)
        Engine.TextColor(self.Text, disabledColor or T.textDisabled, label)
    end)
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
-- 線條圖記（第七輪把 ＋／−／× 那三種擴成一整套）
--
-- **為什麼要有這一套。** 暴雪的小圖示（下拉的 ▼、翻頁的 ◀▶、捲軸的 ∧∨）全部是
-- 「立體、帶描邊、顏色烤在素材裡」的 atlas。中和不行（玩家會失去「這裡可以按」
-- 的線索），染色也救不回來 —— `SetVertexColor` 是乘法，金黃色的素材乘上 `textDim`
-- 只會變暗金（實機擷圖 16 的聲望頁那顆亮黃三角形就是這樣來的，第五輪只好再加一道
-- `SetDesaturated`）。去飽和之後仍然是一顆有厚度、有內描邊的小圖，擺在 1px 硬邊的
-- 直角語彙裡就是突兀。
--
-- 關閉鈕的 × 早就走這條路了（註 ⓖ），這一輪把同一招推廣到其餘四種圖形。
-- 規矩跟 × 完全一樣，所以陷阱 1（overlay 執行期零 Lua）沒有被放寬：
--   * 用 `CreateLine` 畫在**我們自己的 overlay** 上，暴雪物件一根手指都沒碰；
--   * **建立時就定好**位置與粗細，之後不會再算任何幾何；
--   * 粗細走 `P.Scale`（不同 UI 縮放下的 1 像素不是 1 個框架單位）；
--   * 唯一的執行期動作是 `Engine.GlyphColor` 換 vertex color —— 跟底色、邊框
--     三態走的是同一種動作，不是排版。
--
-- 為什麼是這幾個形狀：`CreateLine` 只畫得出直線，所以圖形一律「兩條線以內」。
-- 箭頭（三線一端點）在 9 像素見方的方塊裡會糊成一團，`>` 形的折線（chevron）
-- 反而是最清楚的 —— 它也正好是暴雪自己新式 UI 在用的語彙。
--
-- g（`opts.glyph`）：
--   kind       "cross" ／ "expand"（＋）／ "collapse"（−）／
--              "plus"／"minus"（＝上面兩個的別名，讀起來比較直白）／
--              "chevronUp" / "chevronDown" / "chevronLeft" / "chevronRight"
--              不認得的 kind ⇒ 退回 `g.texture` 那條舊路（一張貼圖）
--   size       圖形的外框邊長（會過 P.Scale）
--   thickness  線寬（會過 P.Scale）
--   color      顏色（之後可用 `Engine.GlyphColor` 換）
--   anchor     圖記錨在 overlay 的哪一點，預設 "CENTER"
--   x / y      相對那一點的偏移（會過 P.Scale）——
--              下拉的 ⌄ 要靠右（暴雪的 Arrow 錨在 `RIGHT x=1`）
------------------------------------------------------------
local CHEVRON = {
    -- kind = 兩條線的端點（單位：half），折點在中間
    --   { {x1,y1, x2,y2}, {x1,y1, x2,y2} }
    chevronUp    = { { -1,  -0.5,  0,  0.5 }, {  0,  0.5,  1, -0.5 } },
    chevronDown  = { { -1,   0.5,  0, -0.5 }, {  0, -0.5,  1,  0.5 } },
    chevronLeft  = { {  0.5, 1,   -0.5, 0  }, { -0.5, 0,   0.5, -1 } },
    chevronRight = { { -0.5, 1,    0.5, 0  }, {  0.5, 0,  -0.5, -1 } },
}

local GLYPH_ALIAS = { plus = "expand", minus = "collapse" }

local function BuildGlyph(ov, g)
    if not ov or not g then return end
    local kind = GLYPH_ALIAS[g.kind] or g.kind
    local c = g.color or T.text
    local half = P.Scale((g.size or 8) / 2)
    local th = P.Scale(g.thickness or 1)
    local anchor = g.anchor or "CENTER"
    local ox, oy = P.Scale(g.x or 0), P.Scale(g.y or 0)

    local lines = {}
    local function Line(x1, y1, x2, y2)
        local line = ov:CreateLine(nil, "ARTWORK")
        line:SetThickness(th)
        line:SetTexture(WHITE)
        line:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        line:SetStartPoint(anchor, ov, x1 + ox, y1 + oy)
        line:SetEndPoint(anchor, ov, x2 + ox, y2 + oy)
        lines[#lines + 1] = line
    end

    local chev = CHEVRON[kind]
    if chev then
        -- 折線的兩段。半高刻意比半寬小（±0.5 對 ±1），不然 45° 的 chevron
        -- 在小尺寸下看起來像箭頭的一半。
        for _, seg in ipairs(chev) do
            Line(seg[1] * half, seg[2] * half, seg[3] * half, seg[4] * half)
        end
    elseif kind == "expand" or kind == "collapse" then
        -- ＋／− 兩種線條圖記。
        --
        -- 為什麼是 ＋／− 而不是「兩支往外的箭頭」：`CreateLine` 畫得出來的只有
        -- 直線，箭頭要三條線一個端點、在 10 像素的方塊裡糊成一團。而套組裡
        -- 「展開／收合」本來就已經是 ＋／− 的語彙（聲望頁的子分類鈕用的
        -- 就是暴雪的 `campaign_headericon_open/closed`，也是 ＋／−）——
        -- 同一個套組裡一個意思只用一種圖形。
        Line(-half, 0, half, 0)
        if kind == "expand" then Line(0, -half, 0, half) end
    elseif kind == "cross" then
        -- ⚠ 不要用 `Interface\Buttons\UI-StopButton`：那張圖本身是暗金色的，
        --   SetVertexColor 是乘法，乘不白。自己用兩條線畫才拿得到純白的 ×。
        for _, dir in ipairs({ 1, -1 }) do
            Line(-half, -half * dir, half, half * dir)
        end
    else
        local tex = ov:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(g.texture)
        tex:SetSize(P.Scale(g.size or 10), P.Scale(g.size or 10))
        tex:SetPoint(anchor, ov, anchor, ox, oy)
        tex:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        ov.glyph = tex
        return
    end

    ov.glyphLines = lines
end

------------------------------------------------------------
-- 換圖記的顏色（三態用）
--
-- 這是圖記**唯一**的執行期動作，跟 `Engine.Fill`／`Engine.Border` 同一級：
-- 換顏色不是排版。沒有圖記的 overlay 進來就直接返回。
------------------------------------------------------------
function Engine.GlyphColor(ov, color)
    if not ov or not color then return end
    local lines = ov.glyphLines
    if lines then
        for i = 1, #lines do
            lines[i]:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        end
    end
    if ov.glyph then
        ov.glyph:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    end
end

------------------------------------------------------------
-- Engine.Overlay(target, opts) → overlay 或 nil
--
-- opts:
--   key          debug 用的名字
--   parent       指定 parent（配方知道得比 SafeParent 清楚時用）
--   anchorTo     **錨在這個物件上**，而不是 target。層級與 side table 仍然算 target 的。
--                給「要貼著某張貼圖畫，但層級要跟著那張貼圖的框」的情況用
--                （成就視窗的標題帽：錨在 `Header.PointBorder` 這張貼圖上，
--                 層級要相對 `Header` —— 貼圖沒有 GetFrameLevel，直接拿它當 target
--                 會讓 overlay 退回「parent 的層級 +1」，反而蓋住標題與點數）
--   inset        SetAllPoints 之後四邊各內縮這麼多框架單位
--   points       { {point, relativePoint, x, y}, ... } 改成自訂錨點（仍錨在 target 上）
--   width/height 只錨了一邊的時候自己給尺寸（髮絲線就是這樣畫的）
--   levelOffset  相對 target 的層級差，預設 -1（壓在目標自己的區域之下）
--   noBorder     不要四條邊
--   borderSize   邊寬（像素，會過 P.Scale）。不給就是 `T.BorderSize()` 的 1px
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

    -- 顯式保護的框不掛 overlay；隱式保護的照做，但戰鬥中要延後（見 ProtectionOf）。
    local parent = opts.parent or SafeParent(target)

    -- 回 true ＝ 可以繼續。⚠ 這一支在捲動時每一列都會跑到，所以不配置任何表。
    local function Allowed(obj, suffix)
        local prot = ProtectionOf(obj)
        if prot == "explicit" then
            Note(Bucket("protected"), (label or "?") .. suffix)
            return false
        elseif prot == "implicit" then
            if InCombatLockdown() then
                -- 不快取、不標記 ⇒ 下一次進來會重試
                Note(Bucket("deferred"), (label or "?") .. suffix)
                return false
            end
            Note(Bucket("implicit"), (label or "?") .. suffix)
        end
        return true
    end

    if not Allowed(target, "") then return nil end
    if not Allowed(parent, " (parent)") then return nil end

    -- ⚠ 純 Frame、不繼承任何模板。EnableMouse 維持預設的 false ——
    --   overlay 一旦吃滑鼠就會把暴雪按鈕的 OnEnter/OnClick 整個攔掉
    --   （見 .claude/notes/wow-child-frame-steals-mouse-focus.md）。
    local ov = CreateFrame("Frame", nil, parent)

    -- 錨定對象預設就是 target；`anchorTo` 只換「貼著誰」，層級與 side table 不變。
    local anchor = opts.anchorTo or target

    if opts.points then
        -- `pt.rel` ＝ 這一個錨點改錨到**別的**物件上（其餘照舊錨在 anchor 身上）。
        -- 給「一個矩形的兩端分別由兩個暴雪物件決定」的情況用：
        --   * 分頁的右緣錨到**下一顆分頁**的左緣（接縫只留一條線，見 Skin.TabGroup）
        --   * 寄信頁收件人框的右緣錨到**郵資標籤**的左緣（那條標籤的寬度隨語系變，
        --     算不出來，只有它自己知道自己在哪）
        -- 錨到暴雪物件是白名單動作（我們動的是自己的框），跟「讀它的錨點」不同。
        for _, pt in ipairs(opts.points) do
            ov:SetPoint(pt[1], pt.rel or anchor, pt[2] or pt[1],
                P.Scale(pt[3] or 0), P.Scale(pt[4] or 0))
        end
    elseif opts.inset then
        local n = P.Scale(opts.inset)
        ov:SetPoint("TOPLEFT", anchor, "TOPLEFT", n, -n)
        ov:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -n, n)
    else
        ov:SetAllPoints(anchor)
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
        -- 邊寬預設 1px；`borderSize` 讓「邊本身就是主角」的原語自己決定
        -- （物品格的品質方框走 `T.itemBorderSize`，改粗細只要改那一個 token）。
        local w = opts.borderSize and P.Scale(opts.borderSize) or T.BorderSize()
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

    -- 強調線：「選中」用的那一條。
    --   分頁 ＝ `"TOP"` / `"BOTTOM"`（朝外那一邊的橫線，第六輪）
    --   清單列 ＝ `"LEFT"` / `"RIGHT"`（第七輪：左緣一條直條，見 `Skin.Row`）
    --
    -- 建立時就定好位置與粗細，執行期只換 alpha 與顏色（同底色與邊框的作法）——
    -- 沒有腳本、沒有 OnUpdate，陷阱 1 的規則照舊。
    -- 畫在 `ARTWORK`：要蓋在底（BACKGROUND）與四條邊（BORDER）之上，
    -- 不然接縫那一顆的左邊線會把線頭切掉。
    if opts.accentSide then
        local bar = ov:CreateTexture(nil, "ARTWORK")
        bar:SetTexture(WHITE)
        local th = P.Scale(opts.accentSize or 2)
        local side = opts.accentSide
        if side == "LEFT" then
            bar:SetPoint("TOPLEFT");    bar:SetPoint("BOTTOMLEFT");  bar:SetWidth(th)
        elseif side == "RIGHT" then
            bar:SetPoint("TOPRIGHT");   bar:SetPoint("BOTTOMRIGHT"); bar:SetWidth(th)
        elseif side == "TOP" then
            bar:SetPoint("TOPLEFT");    bar:SetPoint("TOPRIGHT");    bar:SetHeight(th)
        else
            bar:SetPoint("BOTTOMLEFT"); bar:SetPoint("BOTTOMRIGHT"); bar:SetHeight(th)
        end
        bar:SetAlpha(0)
        ov.accentBar = bar
    end

    -- 靜態圖記（關閉鈕的 ×、翻頁的 ‹ ›、下拉的 ⌄、最大化／最小化的 ＋／−）。
    -- 建立時定好，執行期只會被 `Engine.GlyphColor` 換顏色（見那一支）。
    if opts.glyph then
        BuildGlyph(ov, opts.glyph)
    end

    st = st or {}
    st.overlays = st.overlays or {}
    st.overlays[slot] = ov
    State[target] = st
    Engine.log.overlays = Engine.log.overlays + 1
    return ov
end

------------------------------------------------------------
-- Engine.RegionBackdrop(target, opts) —— 底與邊**直接建在目標框自己身上**
--
-- 第六輪新增的第二條路。跟 `Engine.Overlay` 的差別只有一件事：不建子框，
-- 底與四條邊是 `target:CreateTexture(...)` 出來的 region。
--
-- 為什麼這條路更穩（`.claude/notes/wow-blizzard-window-skin-strategies.md` 第一節）：
--   * `CreateTexture` 不寫任何 Lua 欄位、不改 secure 屬性 ⇒ 不 taint；
--     **隱式保護的容器也能建**，不必特判「這個框身上掛了 secure 子孫嗎」。
--   * region 在 `BACKGROUND` 的最底 sublevel ⇒ 永遠在該框自己的內容之下，
--     **沒有 frame level／strata 問題**：`useParentLevel` 的 Inset、DIALOG strata
--     的彈窗、`toplevel` 提層的視窗都不用再各自想一次；
--     顯示／隱藏自動跟著目標走，連 parent 都不必挑。
--
-- ⚠⚠ **自動排版的框不准走這條路。** `LayoutFrame` / `ResizeLayoutFrame` 會把
--   region 算進版面（`GetLayoutChildren` 之外還有 region 的尺寸），多一張我們的
--   底圖就可能改變它算出來的大小。`IsLayoutHost` 為真一律退回子框那條路。
--
-- ⚠ 回傳的表**跟 overlay 同形狀**（`.bg` / `.edges` / `.skipEdges`），
--   所以 `Engine.Paint` / `Fill` / `Border` / `PassBorderColor` 一個字都不用改。
--   它不是 Frame，**沒有** `SetPoint` / `Hide` / `GetFrameLevel` ——
--   需要那些的原語（按鈕的滑過、分頁、物品格的前景邊）維持走 `Engine.Overlay`。
--
-- ⚠ 失敗一律**退回 `Engine.Overlay`**：目標不是 Frame、是 layout host、
--   `CreateTexture` 被擋（forbidden／保護）、或玩家把 `db.regionBackdrop` 關掉。
--   也就是說這一條在最壞的情況下等於第五輪的行為，不會少一塊皮。
--
-- opts（跟 `Engine.Overlay` 同名同義）：
--   key / inset / points / noBorder / borderSize / skipEdges / slot
--   layer, sublevel          底的繪製層，預設 BACKGROUND / -8
--   edgeLayer, edgeSublevel  邊的繪製層，預設 BACKGROUND / -7
------------------------------------------------------------
function Engine.RegionBackdrop(target, opts)
    opts = opts or {}
    local label = opts.key

    if not Usable(target, label) then return nil end

    local slot = opts.slot or "main"

    local st = State[target]
    if st and st.overlays and st.overlays[slot] then return st.overlays[slot] end

    -- 三道閘，任何一道不過就走子框那條路（記一筆，`/mskin debug` 看得到是誰退回去的）
    local function Fallback(why)
        Note(Bucket("frameBackdrop"), (label or "?") .. " (" .. why .. ")")
        return Engine.Overlay(target, opts)
    end

    if ns.db and ns.db.regionBackdrop == false then return Fallback("off") end
    if type(target.CreateTexture) ~= "function" then return Fallback("not a frame") end
    if IsLayoutHost(target) then return Fallback("layout") end

    local layer      = opts.layer or "BACKGROUND"
    local sublevel   = opts.sublevel or -8
    local edgeLayer  = opts.edgeLayer or "BACKGROUND"
    local edgeSub    = opts.edgeSublevel or -7

    local ok, bg = pcall(target.CreateTexture, target, nil, layer, nil, sublevel)
    if not ok or not bg then return Fallback("CreateTexture") end
    ownRegions[bg] = true

    local placed = pcall(function()
        bg:SetTexture(WHITE)
        if opts.points then
            for _, pt in ipairs(opts.points) do
                bg:SetPoint(pt[1], pt.rel or target, pt[2] or pt[1],
                    P.Scale(pt[3] or 0), P.Scale(pt[4] or 0))
            end
        elseif opts.inset then
            local n = P.Scale(opts.inset)
            bg:SetPoint("TOPLEFT", target, "TOPLEFT", n, -n)
            bg:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -n, n)
        else
            bg:SetAllPoints(target)
        end
        if opts.width then bg:SetWidth(P.Scale(opts.width)) end
        if opts.height then bg:SetHeight(P.Scale(opts.height)) end
    end)
    if not placed then
        pcall(bg.SetAlpha, bg, 0)     -- 建都建了，至少讓它看不見
        return Fallback("SetPoint")
    end

    local rec = { bg = bg, isRegion = true }

    if not opts.noBorder then
        local w = opts.borderSize and P.Scale(opts.borderSize) or T.BorderSize()
        local e = {}
        local madeAll = true
        for i = 1, 4 do
            local ok2, tex = pcall(target.CreateTexture, target, nil, edgeLayer, nil, edgeSub)
            if not ok2 or not tex then madeAll = false break end
            ownRegions[tex] = true
            tex:SetTexture(WHITE)
            e[i] = tex
        end
        if madeAll then
            -- 四條邊錨在底那張貼圖上（region 可以互相錨定），矩形與 overlay 版一致
            e[1]:SetPoint("TOPLEFT", bg, "TOPLEFT");        e[1]:SetPoint("TOPRIGHT", bg, "TOPRIGHT");        e[1]:SetHeight(w)
            e[2]:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT");  e[2]:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT");  e[2]:SetHeight(w)
            e[3]:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, -w); e[3]:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", 0, w); e[3]:SetWidth(w)
            e[4]:SetPoint("TOPRIGHT", bg, "TOPRIGHT", 0, -w); e[4]:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", 0, w); e[4]:SetWidth(w)
            rec.edges = e

            if opts.skipEdges then
                local skip = {}
                for _, side in ipairs(opts.skipEdges) do
                    local idx = EDGE_INDEX[side]
                    if idx then skip[idx] = true end
                end
                rec.skipEdges = skip
            end
        end
    end

    st = st or {}
    st.overlays = st.overlays or {}
    st.overlays[slot] = rec
    State[target] = st
    Engine.log.regions = Engine.log.regions + 1
    return rec
end

------------------------------------------------------------
-- 把一組 `points` 往外推 n 個框架單位（原表不動，回一份新的）
--
-- 給「邊框要畫在底之外一圈」的原語用（`Skin.StatusBar`）：每個錨點照它自己的
-- 方位往外移 —— 帶 LEFT 的往左、帶 RIGHT 的往右、帶 TOP 的往上、BOTTOM 的往下。
-- `rel`（改錨到別的物件）原樣帶過去。
------------------------------------------------------------
function Engine.ExpandPoints(points, n)
    if not points or n == 0 then return points end
    local out = {}
    for i, pt in ipairs(points) do
        local x, y = pt[3] or 0, pt[4] or 0
        local p = pt[1] or "CENTER"
        if p:find("LEFT") then x = x - n elseif p:find("RIGHT") then x = x + n end
        if p:find("TOP") then y = y + n elseif p:find("BOTTOM") then y = y - n end
        out[i] = { p, pt[2], x, y, rel = pt.rel }
    end
    return out
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
    Engine.Border(ov, border)
end

-- 只換四條邊的顏色（`false` ＝這次不要邊）。滑過時把邊換成職業色走這一支。
function Engine.Border(ov, border)
    if not ov or not ov.edges then return end
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
            -- ⚠ 一併把 vertex color 還原成白：`PassBorderColor` 轉交過品質色的邊
            --   帶著乘法顏色，不還原的話這裡下的顏色會被乘暗。
            ov.edges[i]:SetVertexColor(1, 1, 1, 1)
            ov.edges[i]:SetColorTexture(border[1], border[2], border[3], border[4] or 1)
        end
    end
end

-- 只換底色（三態切換用，邊維持原樣）
function Engine.Fill(ov, fill)
    if not ov then return end
    ov.bg:SetColorTexture(fill[1], fill[2], fill[3], fill[4] or 1)
end

-- 強調線（`Engine.Overlay` 的 `accentSide` 建出來的那一條）。
-- `color` 傳 `false` 或 nil ＝這次不要線。overlay 沒有那條線就什麼都不做。
function Engine.AccentLine(ov, color)
    local bar = ov and ov.accentBar
    if not bar then return end
    if not color then
        bar:SetAlpha(0)
        return
    end
    bar:SetAlpha(1)
    bar:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
end

------------------------------------------------------------
-- 「同一個字型、只換顏色」的字型物件
--
-- ⚠ 白名單本來寫的是「`SetNormalFontObject` 只准傳**暴雪自己的**字型物件」，
--   理由是「字型檔與字級跟原本同一家族，不會有換字型物件導致 FontString
--   重新配置的度量差」。這一支守住的是**同一條**理由，不是繞過它：
--   `SetFontObject(base)` 先把暴雪那一份的字型檔、字級、輪廓、陰影整份繼承過來，
--   然後**只**呼叫 `SetTextColor` —— 度量一個位元都沒動。
--
-- 為什麼需要：第六輪的分頁未選中態要「字降到次要色」。分頁的文字顏色跟著
-- 狀態字型物件走（註 ⓔ），`SetTextColor` 撐不過一次滑過 —— 唯一撐得住的路
-- 就是給它一個顏色不一樣的字型物件。
--
-- ⚠ `CreateFont` 需要一個名字（它會寫進 `_G`），所以這裡用自己的前綴，
--   而且**只建一次**（建第二次會拿到同一個物件並把它改掉）。
-- ⚠ 建不出來（介面限制、名字被佔用）就回 `base` —— 退回「白字」，也就是
--   第五輪的行為，不會變成沒有字型的 FontString。
------------------------------------------------------------
local dimFonts = {}

function Engine.DimFont(base, name, color)
    if not base or not name then return base end
    local cached = dimFonts[name]
    if cached then return cached end

    local ok, font = pcall(CreateFont, name)
    if not ok or not font then
        dimFonts[name] = base
        return base
    end
    if not pcall(font.SetFontObject, font, base) then
        dimFonts[name] = base
        return base
    end
    color = color or T.textDim
    pcall(font.SetTextColor, font, color[1], color[2], color[3], color[4] or 1)
    dimFonts[name] = font
    return font
end

------------------------------------------------------------
-- 把暴雪品質邊框的顏色**原封不動轉交**給我們自己的四條邊
--
-- 這是整包唯一一條「讀暴雪物件的顏色」的路，規則寫進 STYLE.md ③ 的讀取例外表。
-- 能這樣做的理由只有一條：**我們當傳遞者，不當讀取者**
-- （`.claude/notes/wow-121-secret-values.md` 的總則）。
--   * `IconBorder:GetVertexColor()` 的四個分量在 12.1 可能是秘密數字。
--   * 我們**不拿它們做任何判斷、不存進表、不做算術**，直接餵進
--     `SetColorTexture` —— 貼圖層的 setter 保證吃得下秘密值。
--   * 只要不讀，就不會有「執行污染流到讀秘密值的地方」那條爆炸路徑。
--
-- 顯示與否跟著 `IconBorder:IsShown()`：那是暴雪自己判斷「這格有沒有品質」的
-- **同一個**依據（`SetItemButtonBorder_Base` 的 `IconBorder:SetShown(asset ~= nil)`，
-- Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua:190），而且是純 C 端布林查詢。
-- 一律過 `Secret.ToBool`：問不到就 fail 到「沒有品質」那一邊，也就是 1px 黑邊 ——
-- 空格與普通物品本來就長那樣，失敗方向是安全的。
------------------------------------------------------------
function Engine.PassBorderColor(ov, src, fallback)
    if not ov or not ov.edges then return end

    -- 沒有品質（或問不到）：回到固定色。⚠ 要把 vertex color 還原成白 ——
    -- 上一次轉交留下的品質色是乘在貼圖上的，不還原的話黑邊會一直帶著舊顏色。
    local function Plain()
        local c = fallback or T.border
        for i = 1, 4 do
            ov.edges[i]:SetAlpha(1)
            ov.edges[i]:SetVertexColor(1, 1, 1, 1)
            ov.edges[i]:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        end
    end

    local shown = false
    if src and type(src.IsShown) == "function" then
        local ok, v = pcall(src.IsShown, src)
        if ok then shown = S.ToBool(v) == true end
    end
    if not shown or type(src.GetVertexColor) ~= "function" then
        return Plain()
    end

    -- ⚠ 這幾個值**只被轉交**，下面一行之後就不再出現。不要順手加
    --   「太暗就提亮」之類的邏輯 —— 那一比較就是在讀秘密值。
    local ok, r, g, b = pcall(src.GetVertexColor, src)
    if not ok then return Plain() end

    -- ⚠ 轉交走 **SetVertexColor**：貼圖鋪純白、顏色乘上去。實證吃得下秘密分量的是
    --   SetVertexColor（.claude/notes/wow-121-secret-values.md），SetColorTexture 沒驗過。
    for i = 1, 4 do
        local e = ov.edges[i]
        e:SetAlpha(1)
        e:SetColorTexture(1, 1, 1, 1)
        if not pcall(e.SetVertexColor, e, r, g, b, 1) then return Plain() end
    end
end

------------------------------------------------------------
-- 按鈕的滑過：底提亮 ＋ **1px 邊換成職業色**
--
-- 這是第五輪把暴雪視窗的按鈕語彙對齊套組自己的設定視窗：共用層的
-- `W.CreateButton`（`BTN_COLORS.normal` ＝ fill → fillHover）與套組本體的
-- `S.ApplyDarkButton`（`DarkEnter` ＝ 底 `fillHover` ＋ 邊 `S.Accent(1)`）
-- 都是這一套，暴雪視窗這邊原本只有「白 8% 疊加」，兩邊看起來像兩個插件。
--
-- 為什麼只能掛腳本、不能交給引擎（陷阱 3 的例外）：我們的 overlay **不吃滑鼠**
-- （吃了就把暴雪按鈕的 OnEnter/OnClick 攔掉），所以 C 端不會替我們切狀態；
-- 而「換 overlay 的邊框顏色」沒有對應的暴雪貼圖可以借。跟分頁與成就分類列
-- 走的是同一條退路（HookScript，不是 SetScript），代價一樣：兩個後掛腳本，
-- 裡面只碰我們自己的 overlay。
--
-- ⚠ 腳本只在**滑鼠進出**時跑，不在點擊路徑上 —— 不會有我們的 Lua 出現在
--   暴雪的 OnClick 派送堆疊裡（wow-121-addon-code-in-secure-stack 的入口 6）。
-- ⚠ **停用的按鈕不給滑過**：`IsEnabled()` 是純 C 端布林（讀取例外表新增的那一條），
--   一律過 `Secret.ToBool`；問不到就當成「可以按」——失敗方向只是多一次提亮。
-- ⚠ 底與邊可以在**兩個不同的 overlay** 上：勾選框的邊走前景 slot（已勾的滿色會
--   蓋掉背景層的邊），所以 fillOv 與 borderOv 分開傳。
------------------------------------------------------------
local hoverState = setmetatable({}, { __mode = "k" })

local function HoverEnabled(btn)
    if type(btn.IsEnabled) ~= "function" then return true end
    local ok, v = pcall(btn.IsEnabled, btn)
    if not ok then return true end
    return S.ToBool(v) ~= false
end

local function PaintHover(btn)
    local rec = hoverState[btn]
    if not rec then return end
    -- ⚠ `rec.enabled` 預設是 **nil**（＝沒有人在追這顆按鈕的啟用狀態）。
    --   只有 `Engine.TrackGlyph{ trackEnabled = true }` 才會把它設成布林 ——
    --   也就是說對第五／六輪那些呼叫者來說，下面這一行等同於原本的 `if rec.hover`。
    local on = rec.hover and rec.enabled ~= false
    if rec.enabled == false and rec.disabledFill then
        -- 第九輪：primary 停用時退回**中性**（停用的按鈕不能看起來像能按）。
        -- 只有給了 `disabledFill` 的按鈕會進來；secondary 維持「停用＝閒置」。
        Engine.Fill(rec.fillOv, rec.disabledFill)
        Engine.Border(rec.borderOv, rec.disabledBorder or T.border)
    elseif on then
        Engine.Fill(rec.fillOv, rec.hoverFill or T.fillHover)
        if rec.hoverBorder then
            Engine.Border(rec.borderOv, rec.hoverBorder)
        else
            rec.accent = rec.accent or {}
            rec.accent[1], rec.accent[2], rec.accent[3], rec.accent[4] = T.Accent(1)
            Engine.Border(rec.borderOv, rec.accent)
        end
    else
        Engine.Fill(rec.fillOv, rec.idle)
        Engine.Border(rec.borderOv, rec.idleBorder or T.border)
    end

    -- 線條圖記跟著三態走（第七輪）：停用最暗、滑過最亮、其餘次要色。
    -- 只改**我們自己畫的線**的顏色，暴雪的貼圖一張都沒碰。
    if rec.glyphOv then
        local c
        if rec.enabled == false then
            c = rec.glyphDisabled or T.textDisabled
        elseif on then
            c = rec.glyphHover or T.text
        else
            c = rec.glyphIdle or T.textDim
        end
        Engine.GlyphColor(rec.glyphOv, c)
    end
end

-- 進出腳本只掛一次（底色與圖記共用同一筆紀錄，所以也共用同一對腳本）。
local function InstallHoverScripts(btn, rec)
    if rec.hovHooked then return end
    if type(btn.HookScript) ~= "function" then return end
    rec.hovHooked = true
    -- ⚠ HookScript 不是 SetScript：模板自己的 OnEnter 多半在開提示
    --   （wow-setscript-clobbers-hookscript）。
    pcall(btn.HookScript, btn, "OnEnter", function(self)
        local r = hoverState[self]
        if not r or not HoverEnabled(self) then return end
        r.hover = true
        PaintHover(self)
    end)
    pcall(btn.HookScript, btn, "OnLeave", function(self)
        local r = hoverState[self]
        if not r then return end
        r.hover = false
        PaintHover(self)
    end)
end

-- 「能不能按」的兩支腳本也只掛一次（`TrackGlyph{ trackEnabled }` 與
-- 第九輪的 primary 按鈕共用同一對）。
--
-- ⚠ `OnEnable` / `OnDisable` 是**每個 Button 都有的 frame script**，`HookScript`
--   接得到（同 `Engine.DropdownText` 對篩選下拉的那兩支）。接觸面只有指名的那一顆，
--   而且腳本只在「啟用狀態改變」時跑，不在點擊派送路徑上；內容只換我們自己
--   overlay 的顏色。
-- ⚠ 初始值讀一次 `IsEnabled()`（讀取例外表上那一條，純 C 端布林、過 Secret.ToBool）。
local function InstallEnableScripts(btn, rec)
    rec.enabled = HoverEnabled(btn)
    if rec.enHooked then return end
    if type(btn.HookScript) ~= "function" then return end
    rec.enHooked = true
    -- ⚠ HookScript 不是 SetScript：模板自己的 OnEnable/OnDisable 還要跑
    --   （`UIPanelButton_OnEnable`／`_OnDisable` 會換 Left/Middle/Right 的材質）。
    pcall(btn.HookScript, btn, "OnEnable", function(self)
        local r = hoverState[self]
        if not r then return end
        r.enabled = true
        PaintHover(self)
    end)
    pcall(btn.HookScript, btn, "OnDisable", function(self)
        local r = hoverState[self]
        if not r then return end
        r.enabled = false
        r.hover = false      -- 停用的當下游標可能還停在上面
        PaintHover(self)
    end)
end

-- fillOv 是要換底色的那一層；borderOv 不給就跟 fillOv 同一層。
-- `hoverFill` 不給就是 `T.fillHover`；只有「閒置底色本來就比 fillHover 亮」的
-- 元件需要自己給（捲軸拇指閒置是 0.35，套 0.23 會變成滑過反而變暗）。
--
-- opts（第九輪，按鈕的 primary 變體用；**不給就是第五輪的行為**）：
--   idleBorder      閒置的邊色（預設 `T.border`）
--   hoverBorder     滑過的邊色（預設職業色 `T.Accent()`）
--   disabledFill    有給 ⇒ 追「能不能按」（掛 OnEnable/OnDisable），停用時換這個底
--   disabledBorder  停用時的邊色（預設 `T.border`）
-- ⚠ 顏色表是呼叫端的（`T.ButtonPalette` 每次給新表），這裡只存參照、不改內容。
function Engine.TrackButtonHover(btn, fillOv, idleFill, borderOv, hoverFill, opts)
    if not btn or not fillOv then return end
    opts = opts or {}
    local rec = hoverState[btn]
    -- ⚠ 第一次建紀錄、又沒有給變體顏色 ⇒ **不重畫**（第五～八輪的行為）：
    --   呼叫端已經自己 `Paint` 過閒置態，而有些呼叫端刻意把邊關掉
    --   （`Paint(ov, fill, false)`），這裡一重畫就會把那幾條邊畫回來。
    local repaint = rec ~= nil or opts.idleBorder ~= nil or opts.disabledFill ~= nil
    if rec then
        rec.fillOv, rec.borderOv, rec.idle = fillOv, borderOv or fillOv, idleFill or rec.idle
        rec.hoverFill = hoverFill or rec.hoverFill
    else
        rec = {
            fillOv = fillOv, borderOv = borderOv or fillOv,
            idle = idleFill or T.fill, hover = false,
            hoverFill = hoverFill,
        }
        hoverState[btn] = rec
    end
    rec.idleBorder     = opts.idleBorder or rec.idleBorder
    rec.hoverBorder    = opts.hoverBorder or rec.hoverBorder
    rec.disabledFill   = opts.disabledFill or rec.disabledFill
    rec.disabledBorder = opts.disabledBorder or rec.disabledBorder

    InstallHoverScripts(btn, rec)
    if rec.disabledFill then
        InstallEnableScripts(btn, rec)
    end
    if repaint then PaintHover(btn) end
end

------------------------------------------------------------
-- 把一個線條圖記交給三態管（第七輪）
--
-- `Engine.TrackButtonHover` 已經在管「底色 ＋ 邊框」，圖記只是同一顆按鈕上的第三
-- 個外觀元素 —— 所以不另起一套狀態機，直接掛進同一筆紀錄。
--
-- opts:
--   idle / hover / disabled   三態各自的顏色（預設 textDim / text / textDisabled）
--   trackHover                這顆按鈕沒有底色 overlay（捲軸的上下箭頭只有一個
--                             圖記），但滑過仍然要提亮 ⇒ 自己掛進出腳本。
--                             已經走過 `TrackButtonHover` 的按鈕不必給（腳本共用）。
--   trackEnabled              追「這顆能不能按」。**只有翻頁鈕這一類需要**：
--                             暴雪對到頭的翻頁鈕呼叫 `Disable()`，而它原本的
--                             `DisabledTexture`（那張灰掉的箭頭）已經被我們中和了
--                             ⇒ 不追的話「按不動」這個資訊就沒了。
--
-- ⚠ **為什麼不走「把 DisabledTexture 塗成暗色」那條零 hook 的路**（那是白名單裡
--   現成的動作）：那張貼圖的矩形是暴雪給的（翻頁鈕是整顆 32x32），而我們的
--   overlay 通常有 `inset`（翻頁鈕內縮 4）⇒ 塗出來的暗色方塊會比我們的框大一圈，
--   在面板上留下一圈看得見的暗色光暈。要對齊就得對暴雪區域 `SetSize`／`SetPoint`，
--   契約禁止。
--
-- ⚠ `OnEnable` / `OnDisable` 是**每個 Button 都有的 frame script**，`HookScript`
--   接得到（同 `Engine.DropdownText` 對篩選下拉的那兩支）。接觸面只有指名的那一顆，
--   而且腳本只在「啟用狀態改變」時跑，不在點擊派送路徑上。
-- ⚠ 初始值讀一次 `IsEnabled()`（讀取例外表上那一條，純 C 端布林、過 Secret.ToBool）。
--   問不到就當成「可以按」——失敗方向只是「到頭的翻頁鈕看起來還能按」，
--   而它本來就按不動，不會有功能性後果。
------------------------------------------------------------
function Engine.TrackGlyph(btn, glyphOv, opts)
    if not btn or not glyphOv then return end
    opts = opts or {}

    local rec = hoverState[btn]
    if not rec then
        -- 沒有 hover 紀錄（`noHover` 的特許視窗）也要能記顏色：`PaintHover` 對
        -- `fillOv` / `borderOv` 是 nil 的紀錄會自己跳過那兩段。
        rec = { hover = false }
        hoverState[btn] = rec
    end
    rec.glyphOv = glyphOv
    rec.glyphIdle = opts.idle
    rec.glyphHover = opts.hover
    rec.glyphDisabled = opts.disabled

    if opts.trackHover then
        InstallHoverScripts(btn, rec)
    end

    if opts.trackEnabled then
        -- 第九輪：跟 primary 按鈕共用同一對 OnEnable/OnDisable（`InstallEnableScripts`），
        -- 同一顆按鈕兩邊都要追也只掛一次。
        InstallEnableScripts(btn, rec)
    end

    PaintHover(btn)
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

------------------------------------------------------------
-- 分頁文字置中 —— STYLE.md ③ 白名單的**唯一一條 SetPoint 例外**（第五輪核准）
--
-- 暴雪把「選中」跟「未選中」的分頁文字放在**不同的高度**上：
--   `PanelTemplates_SelectTab`          `tab.Text:SetPoint("CENTER", tab, "CENTER", x, -3)`
--   `PanelTemplates_DeselectTab`        同上，但 `+2`
--   `PanelTemplates_SetDisabledTabState` 同上，`+2`
--   （`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua`，三支都在檔尾那一區；
--     `isTopTab` 的分頁另外換算成 `-offsetY - 7` / `-offsetY - 6`）
-- 那 5 個單位的落差是為了配合端帽貼圖「選中的分頁往上凸一截」的造型。
-- 九張貼圖一中和、換成我們矩形對齊的 overlay 之後，那個落差就只剩「選中的那一顆
-- 字特別低」——使用者實機擷圖（角色頁、成就頁）指的就是這個。
--
-- 例外的範圍寫死，三個條件缺一不可：
--   1. 只碰 **`tab.Text`**（一個 FontString 區域，不是框、更不是保護物件）。
--   2. 只在**我們接管過的分頁**上（第一行就查 side table）。
--   3. 只在暴雪那三支的**後置勾裡**跑 —— 緊接在它自己 SetPoint 的下一行，
--      沒有「誰蓋誰」的競態，也不會有第三方跟我們搶。
-- 不寫任何 Lua 欄位、不 ClearAllPoints（同一個 `CENTER` 點直接取代，跟暴雪一樣）。
------------------------------------------------------------
function Engine.CenterTabText(tab)
    local fs
    if not (pcall(function() fs = tab.Text end) and fs) then return end
    if type(fs.SetPoint) ~= "function" then return end
    pcall(fs.SetPoint, fs, "CENTER", tab, "CENTER", 0, 0)
end

------------------------------------------------------------
-- 分頁的三態（第六輪換了語彙，`T.tabStyle` 一行切得回去）
--
-- `"underline"`（預設）
--   閒置：底 `fill`、字 `textDim`（字型物件走 `Engine.DimFont`，見 `Skin.Tab`）
--   滑過：底 `fillHover`、字白（暴雪自己的 `HighlightFont` 就是白的，不必我們管）
--         **沒有邊框變化**
--   選中：底 `fillSelected`（比 `fill` 亮一階）、字白（暴雪的 `DisabledFont`）
--         ＋ 朝外那一邊一條 `T.tabAccentSize` 的職業色線
--   停用：底 `fillInset`，字交還暴雪
--
-- **為什麼分頁不再用「滑過換邊框」**（其他按鈕仍然用）：
-- 一排分頁的接縫是「共用下一顆的左邊線」（`Skin.TabGroup`），也就是說除了最後
-- 一顆以外每一顆**都沒有自己的右邊線**。滑過換邊色的結果就是「只亮三邊」——
-- 使用者實機擷圖 30~32 拍到的正是這個，而且它不是 bug 是那個設計的必然。
-- 換成「選中畫一條線、滑過只提亮底」之後，狀態不再依賴一個畫不完整的東西。
------------------------------------------------------------
local function PaintTab(tab, mode)
    local rec = tabState[tab]
    if not rec then return end
    if mode then rec.mode = mode end

    -- 暴雪剛剛才把文字移過位（見上），所以每一次重畫都要重申
    Engine.CenterTabText(tab)

    local m = rec.mode
    local ov = rec.overlay

    if T.tabStyle == "fill" then
        -- 第五輪的樣式（整塊職業色底 ＋ 滑過換邊框），留著當退路
        if m == "selected" then
            local r, g, b, a = T.AccentFill(1)
            rec.accent = rec.accent or {}
            rec.accent[1], rec.accent[2], rec.accent[3], rec.accent[4] = r, g, b, a
            Engine.Fill(ov, rec.accent)
        elseif m == "disabled" then
            Engine.Fill(ov, T.fillInset)
        elseif rec.hover then
            Engine.Fill(ov, T.fillHover)
        else
            Engine.Fill(ov, T.fill)
        end

        if rec.hover and m ~= "selected" and m ~= "disabled" then
            rec.hoverBorder = rec.hoverBorder or {}
            rec.hoverBorder[1], rec.hoverBorder[2], rec.hoverBorder[3], rec.hoverBorder[4] = T.Accent(1)
            Engine.Border(ov, rec.hoverBorder)
        else
            Engine.Border(ov, T.border)
        end
        Engine.AccentLine(ov, false)
        return
    end

    -- 預設樣式："underline"
    if m == "selected" then
        Engine.Fill(ov, T.fillSelected)
    elseif m == "disabled" then
        Engine.Fill(ov, T.fillInset)
    elseif rec.hover then
        Engine.Fill(ov, T.fillHover)
    else
        Engine.Fill(ov, T.fill)
    end

    -- 邊框永遠是黑的：分頁的狀態全部交給底色與那條線
    Engine.Border(ov, T.border)

    if m == "selected" then
        rec.accent = rec.accent or {}
        rec.accent[1], rec.accent[2], rec.accent[3], rec.accent[4] = T.Accent(1)
        Engine.AccentLine(ov, rec.accent)
    else
        Engine.AccentLine(ov, false)
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
    tabState[tab] = { overlay = overlay, key = key, mode = "idle", hover = false }

    -- 滑過：分頁模板的 HIGHLIGHT 層是三張 useAtlasSize 的貼圖（同樣會超出矩形），
    -- 所以這裡沒有「交給引擎畫」的選項，只能掛腳本。
    -- ⚠ 用 HookScript 不是 SetScript：模板自己在 OnEnter 裡做截字提示，
    --   SetScript 會把它整個蓋掉（見 notes/wow-setscript-clobbers-hookscript）。
    if type(tab.HookScript) == "function" then
        pcall(tab.HookScript, tab, "OnEnter", function(self)
            local rec = tabState[self]
            if not rec then return end
            rec.hover = true
            PaintTab(self)
        end)
        pcall(tab.HookScript, tab, "OnLeave", function(self)
            local rec = tabState[self]
            if not rec then return end
            rec.hover = false
            PaintTab(self)
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
-- 「選中 ＋ 滑過」兩態都由我們畫的清單列
--
-- 預設的作法是「滑過交給引擎（Highlight 貼圖換色）、選中另走 overlay 底色」
-- （STYLE.md ③ 的陷阱 3）。那條路在**成就分類列**上會留下一條灰帶：
--
--   `AchievementCategoryTemplate` 的 Button 是 158x24，但它的 HighlightTexture
--   錨的是 `TOPLEFT 0,0` → `BOTTOMRIGHT -1,-7`（Blizzard_AchievementUI.xml:650-654）
--   —— 也就是**比按鈕矩形往下多 7、往左少 1**。暴雪自己的美術大半透明，多出來
--   那 7 看不見；換成我們的純色之後，「選中」的 `LockHighlight`（.lua:604）就在
--   選中底色底下多畫出一條 7 像素的白 8% 灰帶。
--
-- 對齊那個矩形也不行：列與列之間**沒有間距**（每列 24 高、緊貼），overlay 往下
-- 長 7 就會壓到下一列，而同一批 overlay 層級相同、疊放順序只看建立先後 ——
-- 選中的那一塊會被下一列的底色蓋掉一角。
--
-- ⇒ 這一種列改成「兩態都自己畫」：暴雪的 Highlight 中和掉（連同 `LockHighlight`
--    一起失效），滑過走 `HookScript("OnEnter"/"OnLeave")`。這跟分頁走的是同一條
--    退路（註 ⓐ），成本也一樣：兩個後掛腳本，裡面只碰我們自己的 overlay。
--    ⚠ 一定要 `HookScript` 不是 `SetScript` —— 模板自己的 OnEnter 會開提示
--      （`AchievementCategoryTemplateButtonMixin:OnEnter`，.lua:612）。
------------------------------------------------------------
local selectState = setmetatable({}, { __mode = "k" })

-- `opts.selectedFill` ＋ `opts.accentLine`（第六輪）：新式分頁走的是「亮一階的底
-- ＋ 一條職業色線」，跟清單列的「整塊職業色底」不是同一套（分頁有地方畫線、
-- 清單列沒有）。不給就是原本的 `AccentFill`。
local function PaintSelectable(btn)
    local rec = selectState[btn]
    if not rec then return end
    if rec.selected then
        if rec.selectedFill then
            Engine.Fill(rec.overlay, rec.selectedFill)
        else
            local r, g, b, a = T.AccentFill(1)
            rec.accent = rec.accent or {}
            rec.accent[1], rec.accent[2], rec.accent[3], rec.accent[4] = r, g, b, a
            Engine.Fill(rec.overlay, rec.accent)
        end
    elseif rec.hover then
        Engine.Fill(rec.overlay, T.fillHover)
    else
        Engine.Fill(rec.overlay, rec.idle or T.fill)
    end

    if rec.accentLine then
        if rec.selected then
            rec.line = rec.line or {}
            rec.line[1], rec.line[2], rec.line[3], rec.line[4] = T.Accent(1)
            Engine.AccentLine(rec.overlay, rec.line)
        else
            Engine.AccentLine(rec.overlay, false)
        end
    end
end

-- 只在第一次見到這顆按鈕時掛腳本；之後重複呼叫只更新 overlay 參照。
function Engine.TrackSelectable(btn, overlay, idleFill, opts)
    if not btn or not overlay then return end
    opts = opts or {}
    local rec = selectState[btn]
    if rec then
        rec.overlay = overlay
        rec.idle = idleFill or rec.idle
        rec.selectedFill = opts.selectedFill or rec.selectedFill
        rec.accentLine = opts.accentLine or rec.accentLine
        PaintSelectable(btn)
        return
    end

    selectState[btn] = {
        overlay = overlay, idle = idleFill, selected = false, hover = false,
        selectedFill = opts.selectedFill, accentLine = opts.accentLine,
    }

    if type(btn.HookScript) == "function" then
        pcall(btn.HookScript, btn, "OnEnter", function(self)
            local r = selectState[self]
            if not r then return end
            r.hover = true
            PaintSelectable(self)
        end)
        pcall(btn.HookScript, btn, "OnLeave", function(self)
            local r = selectState[self]
            if not r then return end
            r.hover = false
            PaintSelectable(self)
        end)
    end
    PaintSelectable(btn)
end

-- 選中態。`selected` 一律是**後置勾的參數**過完 `Secret.ToBool` 的結果，
-- 不是從 elementData 讀來的欄位（STYLE.md ③ 的讀取例外清單）。
function Engine.SetSelected(btn, selected)
    local rec = selectState[btn]
    if not rec then return end
    rec.selected = selected and true or false
    PaintSelectable(btn)
end

------------------------------------------------------------
-- 新式頂部分頁（`TabSystemButtonTemplate` 系）
--
-- 出處（12.1 live）：
--   Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.xml:3
--     `TabSystemButtonArtTemplate`（mixin `TabSystemButtonArtMixin`）——
--     九張貼圖，parentKey 的名字跟 `PanelTabButtonTemplate` 一模一樣
--     （LeftActive/MiddleActive/RightActive、Left/Middle/Right、
--      LeftHighlight/MiddleHighlight/RightHighlight），但 parentArray 叫
--     **`RotatedTextures`** 不是 `TabTextures`（同檔 :27,32,37,43,48,53,61,66,72）。
--   同檔 :85,86　`<NormalFont style="GameFontNormalSmall"/>`
--     ＋ `<HighlightFont style="GameFontHighlightSmall"/>`，**沒有 DisabledFont**。
--   TabSystemTemplates.lua:41　`TabSystemButtonArtMixin:SetTabSelected(isSelected)`
--     → 六張 Show/Hide ＋ `SetNormalFontObject(isSelected and selectedFontObject
--       or unselectedFontObject)`（:51-53，預設 GameFontHighlightSmall／
--       GameFontNormalSmall）＋ `SetEnabled(not isSelected and …)`（:55）。
--   同檔 :117　`TabSystemButtonMixin:Init` 最後一行就呼叫 `SetTabSelected(false)`。
--   同檔 :209　`TabSystemMixin:OnLoad` → `CreateFramePool("BUTTON", self, tabTemplate)`。
--   同檔 :234　`TabSystemMixin:SetTabVisuallySelected` → 逐顆 `tab:SetTabSelected(...)`。
--
-- **為什麼不能走 `Engine.TrackTab` 那一套**：這種分頁完全不經過
-- `PanelTemplates_SelectTab`／`_DeselectTab`／`_SetDisabledTabState`，Engine 的
-- 那三個全域後置勾一次都不會觸發 —— 套下去會變成「每一顆都畫成閒置」。
--
-- **實際被拷貝到 frame 上的是哪一層 mixin**（陷阱 4 ＋ `CreateFromMixins` 那一條）：
--   `FriendsTabTemplate` → `TabSystemButtonTemplate` → `TabSystemButtonArtTemplate`，
--   三層各自帶一個 `mixin=`，frame 建立時**三張表都會被逐一拷貝**上去。
--   `SetTabSelected` 只定義在最底下那一層（`TabSystemButtonArtMixin`，
--   TabSystemTemplates.lua:41），所以要勾的是**它**。
--   ⚠ 不要勾 `TabSystemButtonMixin`：`FriendsTabMixin = CreateFromMixins(
--     TabSystemButtonMixin)`（Blizzard_FriendsFrame/Mainline/FriendsFrame.lua:690）
--     在**那一行執行時**就把整張表拷貝走了，勾來源追不上（同
--     `ListHeaderThreeSliceMixin` 那一條）。而 `TabSystemButtonArtMixin` 是
--     `TabSystemButtonArtMixin = {}`（TabSystemTemplates.lua:4），沒有中間層。
--
-- ⚠⚠ **mixin 後置勾對「已經建好的分頁」沒有用，而且這裡幾乎一定來不及。**
--   分頁是 `TabSystemMixin:AddTab` 從池子借出來的，而各視窗都在自己的 `OnLoad`
--   裡就把分頁建完（好友名單：`FriendsTabHeaderMixin:OnLoad` → `GenerateHeaderTabs`，
--   FriendsFrame.lua:554）—— OnLoad 跑在該插件的檔案執行期，比 `ADDON_LOADED`
--   還早，更別說我們的 `PLAYER_LOGIN`。
--   ⇒ 這一支提供**兩條**路，配方兩條都要接：
--     1. `Engine.TabSystemHooks()`：全域 mixin 後置勾，接住「之後才建的」分頁
--        （執行期 `AddTab`、隨需載入視窗裡比較晚建的分頁）。放 `hooks` 欄位。
--     2. `Engine.SyncTabSystem(tab)` / `SyncTabSystemAll()`：**重讀**
--        `tab.LeftActive:IsShown()` 再重畫。那是暴雪自己判斷選中態的同一個依據
--        （`SetTabSelected` 把它 `SetShown(isSelected)`，TabSystemTemplates.lua:47），
--        純 C 端布林、契約讀取例外表上已經有的那一條（`Engine.TrackTab` 的初始同步
--        用的就是它）。配方把它掛在該視窗「每次切頁都會跑的那支**全域**函式」的
--        後置勾上（好友名單是 `FriendsFrame_Update`，FriendsFrame.lua:450）。
--
-- 三態沿用 `Engine.TrackSelectable`（選中＝AccentFill／滑過＝fillHover／閒置＝fill），
-- 不另起一套狀態機。
--
-- **停用態不畫**：`SetTabEnabled` 住在 `TabSystemButtonMixin` 上，而那張表會被
-- `CreateFromMixins` 拷走（上面那條）⇒ 勾不到。不賭的作法是交還給暴雪 ——
-- 它自己在 `SetTabEnabled` 裡把分頁文字包進 `DISABLED_FONT_COLOR`
-- （TabSystemTemplates.lua:133），停用的分頁靠文字變灰就看得出來。
------------------------------------------------------------
local tabSystemButtons = setmetatable({}, { __mode = "k" })
local tabSystemHooksInstalled = false

-- 選中／未選中的文字都改成白的。
--
-- ⚠ 一定要**重申**：`SetTabSelected` 每次都 `SetNormalFontObject(...)`
--   （TabSystemTemplates.lua:53），未選中那一邊預設是 `GameFontNormalSmall`（暗金）。
-- ⚠ 選中的分頁會被 `SetEnabled(false)`（同檔 :55），但這個模板**沒有 DisabledFont**
--   （TabSystemTemplates.xml:85-86 只有 NormalFont／HighlightFont）⇒ 停用狀態照樣
--   吃 NormalFontObject，暴雪自己就是靠這一點把選中的分頁畫成白字的。
--
-- ⚠ 第六輪：`"underline"` 樣式下**未選中的分頁字降到 `textDim`**。這一種分頁沒有
--   DisabledFont，選中與未選中都吃 NormalFontObject ⇒ 兩態各給一個字型物件。
--   滑過仍然是暴雪自己的 `HighlightFont`（`TabSystemTemplates.xml:86`，白），
--   我們一個字都不用管。
local function TabSystemFont(tab, selected)
    if type(tab.SetNormalFontObject) ~= "function" then return end
    local font = GameFontHighlightSmall
    if T.tabStyle ~= "fill" and not selected then
        font = Engine.DimFont(GameFontHighlightSmall, "MiliUISkinFontTabDim")
    end
    pcall(tab.SetNormalFontObject, tab, font)
end

-- 讀一次「暴雪認為這顆選中了沒」。過 Secret.ToBool，問不到就 fail 到閒置。
local function TabSystemIsSelected(tab)
    local active
    pcall(function() active = tab.LeftActive end)
    if not active or type(active.IsShown) ~= "function" then return nil end
    local ok, v = pcall(active.IsShown, active)
    if not ok then return nil end
    return S.ToBool(v)
end

function Engine.SyncTabSystem(tab)
    if not tabSystemButtons[tab] then return end
    local selected = TabSystemIsSelected(tab) == true
    TabSystemFont(tab, selected)
    Engine.SetSelected(tab, selected)
end

-- 一次重掃所有登記過的新式分頁。配方掛在視窗的全域刷新函式後面就好，
-- 不必自己記住有哪幾顆。
function Engine.SyncTabSystemAll()
    for tab in pairs(tabSystemButtons) do
        pcall(Engine.SyncTabSystem, tab)
    end
end

-- 全域 mixin 後置勾。**放 `Engine.Register` 的 `hooks` 欄位**（戰鬥閘前面）。
-- 冪等；`TabSystemButtonArtMixin` 不存在就記一筆 missing，不報錯。
function Engine.TabSystemHooks()
    if tabSystemHooksInstalled then return end
    local mixin = _G.TabSystemButtonArtMixin
    if type(mixin) ~= "table" or type(mixin.SetTabSelected) ~= "function" then
        Engine.Missing("TabSystemButtonArtMixin:SetTabSelected")
        return
    end
    tabSystemHooksInstalled = true
    -- ⚠ 第一行就查弱鍵表：這一支是**全遊戲**的新式分頁都會進來的。
    hooksecurefunc(mixin, "SetTabSelected", function(tab, isSelected)
        if type(tab) ~= "table" or not tabSystemButtons[tab] then return end
        local selected = S.ToBool(isSelected) == true
        TabSystemFont(tab, selected)
        Engine.SetSelected(tab, selected)
    end)
end

-- `Skin.TabSystem` 建完 overlay 之後把分頁交給這裡管。
function Engine.TrackTabSystem(tab, overlay, key)
    if not tab or not overlay then return end
    Engine.TabSystemHooks()
    tabSystemButtons[tab] = key or true
    -- 滑過與選中兩態都自己畫：九張貼圖（含 HIGHLIGHT 層那三張）全部中和掉之後，
    -- 引擎沒有東西可以畫，跟成就分類列同一條退路。
    -- 選中態跟舊式分頁同一套語彙（`T.tabStyle`）：`"underline"` 用亮一階的底
    -- ＋ 一條職業色線；`"fill"` 退回第五輪的整塊職業色。
    if T.tabStyle == "fill" then
        Engine.TrackSelectable(tab, overlay, T.fill)
    else
        Engine.TrackSelectable(tab, overlay, T.fill,
            { selectedFill = T.fillSelected, accentLine = true })
    end
    local selected = TabSystemIsSelected(tab) == true
    TabSystemFont(tab, selected)
    Engine.SetSelected(tab, selected)
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
            local prot = ProtectionOf(row)
            if prot == "explicit" then
                Note(Bucket("protected"), key)
                rowState[row] = SKIP
                return
            end
            -- 隱式保護（列上掛了 secure 子物件）＋ 正在戰鬥 ⇒ 這次什麼都不做，
            -- **也不標記成已處理**，下一次重用這一列（或脫戰後的補掃）會重試。
            if prot == "implicit" and InCombatLockdown() then
                Note(Bucket("deferred"), key)
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
            Engine.NoteBrokenHook(key)
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
-- 物品格的「暴雪更新完了」後置勾
--
-- 物品格跟池化列是同一類問題：同一顆 frame 的內容隨時會換（換裝、收信、翻頁），
-- 而且兩件事每次都會被打回去 ——
--   * `IconBorder` 被 `SetShown(true)` ＋ 重新 SetAtlas／SetTexture
--     （`SetItemButtonBorder_Base`，Blizzard_ItemButton/Mainline/ItemButtonTemplate.lua:189）
--   * 圖示的 texCoord 被 `icon:SetTexture(...)` 打回 `0,1,0,1`（同檔 :76）
--
-- 掛哪兩支（查證後的結論，跟「勾 mixin」那條路不一樣）：
--   `SetItemButtonQuality`（同檔 :241）與 `SetItemButtonTexture`（:94）
--   這兩支**全域函式**是所有路徑的共同出口：
--     裝備欄  `PaperDollItemSlotButton_Update`（PaperDollFrame.lua:1699,1735）
--     寄信附件 `SendMailFrame_Update`（MailFrame.lua:972,973,990,991）
--     讀信附件 `OpenMail_Update`（MailFrame.lua:455,463,465,479-486）
--     收件匣   `InboxFrame_Update`（MailFrame.lua:233,235）
--   兩支都要勾：`OpenMailLetterButton` 只走 `SetItemButtonTexture`、
--   從來不走 `SetItemButtonQuality`（MailFrame.lua:455），只勾一支會漏掉裁邊。
--
--   ⚠ **不勾 `ItemButtonMixin` 的同名方法。** 那是 intrinsic 的 mixin，函式在
--     frame 建立時就被拷貝走了（陷阱 4 的同一條規則），而裝備欄是
--     `Blizzard_UIPanels_Game`（LoadFirst）建的，比我們早太多，勾了也追不上。
--     全域那兩支是**真的全域**，勾了立刻生效。
--
-- ⚠ 這兩支是**全遊戲**的物品格都會進來（背包、銀行、商人、拍賣……），
--   所以第一行就查弱鍵表，不是我們接管的立刻返回。
------------------------------------------------------------
local itemButtons = setmetatable({}, { __mode = "k" })
Engine.itemButtons = itemButtons

local itemHooksInstalled = false
local itemHookBroken = false

local function RefreshItemButton(btn)
    if itemHookBroken then return end
    if type(btn) ~= "table" then return end
    local key = itemButtons[btn]
    if not key then return end          -- 不是我們接管的格子
    local ok, err = pcall(ns.Skin.ItemButtonRefresh, btn, key)
    if not ok then
        itemHookBroken = true
        Engine.NoteBrokenHook("SetItemButtonQuality / SetItemButtonTexture")
        ns.ReportError(err)
    end
end

function Engine.TrackItemButton(btn, key)
    itemButtons[btn] = key
    if itemHooksInstalled then return end
    itemHooksInstalled = true
    for _, name in ipairs({ "SetItemButtonQuality", "SetItemButtonTexture" }) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, RefreshItemButton)
        else
            Engine.Missing(name)
        end
    end
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
--   companions
--          「伴隨元件」—— 套組內建、固定掛在暴雪視窗上的別家元件（STYLE.md ③）。
--          `{ event = "MAIL_SHOW", apply = fn }`：我們自己的事件框收到那個事件之後
--          **延一幀**（`C_Timer.After(0, …)`）再掃一次。延一幀是因為那些元件多半是
--          「視窗第一次顯示時才建」的，同一幀裡去找還不存在。
--
--          `{ atLogin = true, apply = fn }`（第八輪加的第二種觸發）：
--          有些伴隨元件是**檔案層／XML 就整組建好**的（`CreateFrame` 寫在插件自己的
--          `.lua` 檔案層，不是等視窗第一次顯示）。那種沒有「第一次顯示」這個掛點，
--          也就沒有一個暴雪事件擺在對的時間點上 —— 硬挑一個（搜尋結果回來、
--          隨從表可用…）只會讓第一次開視窗晚一拍才上皮，而且之後每次都白掃一遍。
--          `atLogin` 走**完全同一條路**（延一幀、戰鬥閘、脫戰補跑），只是觸發點
--          改成「`Engine.Boot` 把所有配方套完之後」。
--          ⚠ 那一刻所有非隨需載入的插件都載完了（`PLAYER_LOGIN` 在
--            `ADDON_LOADED` 全部派送完之後），所以**不是**在賭載入順序。
--
--          ⚠ 紀律（配方不准自己違反）：
--            * 用全域名稱判斷有沒有，**沒有就靜默跳過**，不記進「找不到的區域」——
--              玩家可能根本沒裝那支插件，那張清單是給「暴雪改版改了什麼」用的。
--            * 不呼叫它的任何函式、不 hook 它的函式、不依賴載入順序、
--              **不在它的框上寫欄位**（跟暴雪物件同一條線）。
--            * 能做的動作跟對暴雪物件一樣（白名單），原語直接重用。
--            * `Engine.Overlay` 本來就冪等 ⇒ 每次事件重掃一遍是安全的。
--
--          ⚠ **第三方那一邊的實作不寫在配方裡**（STYLE.md ③）：
--            一支插件一個檔，住在 `ThirdParty/`，用 `Engine.AddCompanion` 掛到
--            host 配方上。`companions = {…}` 這個欄位照舊有效 —— 它現在只剩
--            「同一個視窗裡、事件觸發的補掃」在用（商人的格數、宏偉寶庫的重掃），
--            那兩個掃的是**暴雪自己的**框，不是第三方。
------------------------------------------------------------
local recipes = {}
Engine.recipes = recipes

-- key → 配方。`Engine.AddCompanion` 要照 key 找 host —— 走訪 `recipes` 也行，
-- 但那是每登記一支就線性掃一次。
local recipesByKey = {}

------------------------------------------------------------
-- 還沒等到 host 的伴隨元件
--
-- `ThirdParty/*.lua` 在 TOC 裡排在所有 `Skins\*.lua` 之後，所以正常情況下
-- host 一定已經 `Register` 過了。這張表是**為了不依賴那個順序**：
-- 檔案被搬動、或哪天有人把某份配方改成隨需載入，這裡照樣接得上。
-- `Engine.Boot` 會做最後一次結算，那時候還沒有主人的才真的算錯。
------------------------------------------------------------
local pendingCompanions = {}     -- [hostKey] = { spec, ... }

-- 沒有 host 的伴隨元件（`hostKey = nil`）。
-- 不是每一支第三方元件都長在某個暴雪視窗上 —— 有的是它自己建的一整個框
-- （自建的 tooltip）。那種沒有「哪個視窗的開關」可以掛，只看總開關與它自己的
-- 第三方開關。**不進 `recipes`**：`/mskin debug` 那張表是「暴雪視窗的現況」，
-- 混進一列沒有視窗的東西只會讓那張表更難讀。
local hostlessCompanions = {}

local function AttachCompanion(rec, spec)
    rec.companions = rec.companions or {}
    rec.companions[#rec.companions + 1] = spec
end

function Engine.Register(spec)
    spec.status = "pending"
    if spec.parts then
        for _, part in ipairs(spec.parts) do part.status = "pending" end
    end
    recipes[#recipes + 1] = spec
    if spec.key then
        recipesByKey[spec.key] = spec
        -- 先到的伴隨元件現在補掛上去
        local waiting = pendingCompanions[spec.key]
        if waiting then
            for _, c in ipairs(waiting) do AttachCompanion(spec, c) end
            pendingCompanions[spec.key] = nil
        end
    end
    return spec
end

------------------------------------------------------------
-- Engine.AddCompanion(hostKey, spec) —— 從別的檔案把伴隨元件掛到某份配方上
--
-- `spec` 的形狀跟 `Engine.Register` 的 `companions` 條目**完全一樣**，多一個欄位：
--   event / atLogin   觸發方式，二選一（語意見上面那一段）
--   apply             要跑的函式
--   addonKey          `ns.DB.thirdparty` 裡的開關 key（`"postal"`…）。
--                     ⚠ 這是**第三方自己的**開關，跟 host 視窗的開關是「而且」的關係：
--                       host 關掉 ⇒ 不跑（現行行為，伴隨元件本來就跟著視窗走）；
--                       第三方關掉 ⇒ 也不跑，而且連事件都不註冊。
--                     不給就只看 host 的開關（`companions = {…}` 的舊寫法就是這樣）。
--
-- `hostKey` 傳 nil ＝ 這一支不屬於任何暴雪視窗（見 `hostlessCompanions`）。
--
-- 回傳 spec 本身（方便呼叫端在同一行看到自己登記了什麼）。
------------------------------------------------------------
function Engine.AddCompanion(hostKey, spec)
    if type(spec) ~= "table" or type(spec.apply) ~= "function" then return nil end

    if hostKey == nil then
        hostlessCompanions[#hostlessCompanions + 1] = spec
        return spec
    end

    local rec = recipesByKey[hostKey]
    if rec then
        AttachCompanion(rec, spec)
    else
        local list = pendingCompanions[hostKey]
        if not list then
            list = {}
            pendingCompanions[hostKey] = list
        end
        list[#list + 1] = spec
    end
    return spec
end

------------------------------------------------------------
-- 伴隨元件的「額外分頁」：`Engine.AddCompanionTabs` / `Engine.CompanionTabs`
--
-- **為什麼分頁不能走一般的 `AddCompanion`。** `Skin.TabGroup` 的接縫是
-- 「這一顆的右緣錨在下一顆的左緣」，而 overlay 的錨點**只在建立時定一次**
-- （陷阱 1：執行期零 Lua）⇒ 先畫暴雪那三顆、之後再補第三方那四顆，
-- 第三顆會永遠停在「我是最後一顆」的幾何上。整排一定要**同一次**畫完。
--
-- 所以第三方那一支只登記「我加了哪幾顆、全域名字是什麼」，host 配方在它自己的
-- 那一輪把清單取出來，跟暴雪那幾顆一起交給 `Skin.TabGroup`。
--
--   ThirdParty/Auctionator.lua:  Engine.AddCompanionTabs("auctionhouse", { …名字… }, "auctionator")
--   Skins/AuctionHouse.lua:      for _, name in ipairs(Engine.CompanionTabs("auctionhouse")) do …
--
-- ⚠ 登記的是**名字**不是框：取出來的那一刻才 `_G[name]`，沒有就靜默跳過
--   （伴隨元件規則第 2 條）。這裡不呼叫、不 hook 對方的任何東西。
-- ⚠ 第三方開關關掉 ⇒ `Engine.CompanionTabs` 回**空表**（不是 nil），
--   呼叫端的迴圈原樣跑過去就好，不用多寫一個判斷。
------------------------------------------------------------
local companionTabs = {}     -- [hostKey] = { { names = {…}, addonKey = … }, … }

function Engine.AddCompanionTabs(hostKey, names, addonKey)
    if not hostKey or type(names) ~= "table" then return end
    local list = companionTabs[hostKey]
    if not list then
        list = {}
        companionTabs[hostKey] = list
    end
    list[#list + 1] = { names = names, addonKey = addonKey }
end

function Engine.CompanionTabs(hostKey)
    local out = {}
    local list = hostKey and companionTabs[hostKey]
    if not list then return out end
    for _, group in ipairs(list) do
        if not group.addonKey or ns.DB.IsThirdPartyEnabled(group.addonKey) then
            for _, name in ipairs(group.names) do
                out[#out + 1] = name
            end
        end
    end
    return out
end

local pendingCombat = false

-- 一個「單元」＝配方本身或它的一個 part。兩者的欄位長得一樣。
-- `owner` 是紀錄要掛在誰身上（part 的 missing 併進外層配方那一格 ——
-- 玩家看到的是一個視窗，debug 輸出也就不該拆成兩列）。
local function RunUnit(unit, owner)
    if unit.status == "applied" then return end

    if unit.addon and not C_AddOns.IsAddOnLoaded(unit.addon) then
        unit.status = "waiting-addon"
        return
    end

    -- ⚠ hook 先裝，而且**在戰鬥閘前面**。理由見上面那段與陷阱 4。
    if unit.hooks and not unit.hooksDone then
        unit.hooksDone = true
        currentOwner = owner or unit
        xpcall(unit.hooks, ns.ReportError)
        currentOwner = nil
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
    currentOwner = owner or unit
    local ok = xpcall(unit.apply, ns.ReportError)
    currentOwner = nil
    unit.status = ok and "applied" or "error"
end

-- ⚠ **設定裡關掉的視窗，一個 hook 都不裝、一個事件都不註冊。**
--   這道閘擋在 `RunUnit` 之前，而 `RunUnit` 是 `hooks`（mixin 後置勾）、`apply`
--   （`Engine.TrackItemButton` 的兩個全域後置勾、`Engine.TabSystemHooks`、
--   `Engine.TrackTab` 的三個 `PanelTemplates_*` 後置勾都是從 apply 裡的原語裝的）
--   **唯一**的入口 —— 也就是說關掉的配方連接觸面都不會產生。
--   伴隨元件的事件框同理：`Engine.Boot` 只對啟用中的配方呼叫 `RegisterCompanions`，
--   而 `RunCompanions` 每次派送前還會再問一次（玩家有可能在同一次登入裡改設定，
--   雖然要 /reload 才完整生效）。
local function RunRecipe(rec)
    if not ns.DB.IsWindowEnabled(rec.key) then
        rec.status = "disabled"
        return
    end
    RunUnit(rec, rec)
    if rec.parts then
        for _, part in ipairs(rec.parts) do RunUnit(part, rec) end
    end
end

function Engine.ApplyAll()
    for _, rec in ipairs(recipes) do
        RunRecipe(rec)
    end
end

------------------------------------------------------------
-- 伴隨元件的事件框
--
-- 每個 event 只註冊一次，底下掛一串 `{ recipe, apply }`。事件進來之後
-- `C_Timer.After(0, …)` 延一幀再跑（元件是視窗顯示那一刻才建的）。
--
-- ⚠ 戰鬥閘照走：那些元件跟暴雪的框長在同一棵樹上，戰鬥中碰保護框一樣會被擋。
--   延到 PLAYER_REGEN_ENABLED 的路徑跟 `apply` 共用同一個 `pendingCombat`。
------------------------------------------------------------
local companionFrame
local companionJobs = {}      -- [event] = { {rec = 配方, apply = fn}, ... }
local companionPending = {}   -- [event] = true（戰鬥中收到事件，出戰再補跑）

-- `atLogin` 的保留鍵。**不是真的事件**，不會註冊到事件框上 —— 它只是借用同一張
-- 工作表與同一條戰鬥補跑路徑（`companionPending` 的走訪不在意鍵是不是事件名）。
local COMPANION_AT_LOGIN = "@login"

-- 這一份工作現在該不該跑。兩道閘是「而且」的關係（見 `Engine.AddCompanion`）：
--   * host 的視窗開關 —— 沒有 host（`job.rec == nil`）就只看總開關。
--   * 第三方自己的開關 —— 沒給 `addonKey` 就不問（`companions = {…}` 的舊寫法）。
local function CompanionEnabled(job)
    if job.rec then
        if not ns.DB.IsWindowEnabled(job.rec.key) then return false end
    elseif not (ns.db and ns.db.enabled) then
        return false
    end
    if job.addonKey and not ns.DB.IsThirdPartyEnabled(job.addonKey) then return false end
    return true
end

local function RunCompanions(event)
    local jobs = companionJobs[event]
    if not jobs then return end
    if InCombatLockdown() then
        companionPending[event] = true
        pendingCombat = true
        return
    end
    companionPending[event] = nil
    for _, job in ipairs(jobs) do
        if CompanionEnabled(job) then
            -- `job.rec` 是 nil（沒有 host）時 `currentOwner` 也是 nil ⇒
            -- 紀錄落回 `Engine.log` 那一格（`/mskin debug` 的 "hook:" 那一節），
            -- 不會憑空多出一列沒有主人的視窗。
            currentOwner = job.rec
            xpcall(job.apply, ns.ReportError)
            currentOwner = nil
        end
    end
end

-- `rec` 可以是 nil（沒有 host 的那一批），那時候 `list` 要自己給。
local function RegisterCompanions(rec, list)
    list = list or (rec and rec.companions)
    if not list then return end
    for _, c in ipairs(list) do
        -- 兩種觸發共用同一張工作表；`atLogin` 的鍵不是事件名，所以不註冊事件。
        local key = c.atLogin and COMPANION_AT_LOGIN or c.event
        -- ⚠ 第三方開關關掉 ⇒ 連事件都不註冊（同「關掉的視窗一個 hook 都不裝」
        --   那一條）。`RunCompanions` 每次派送前還會再問一次。
        local gated = c.addonKey and not ns.DB.IsThirdPartyEnabled(c.addonKey)
        if key and c.apply and not gated then
            if not companionJobs[key] then
                companionJobs[key] = {}
                if not c.atLogin then
                    if not companionFrame then
                        companionFrame = CreateFrame("Frame")
                        companionFrame:SetScript("OnEvent", function(_, event)
                            C_Timer.After(0, function() RunCompanions(event) end)
                        end)
                    end
                    companionFrame:RegisterEvent(key)
                end
            end
            local jobs = companionJobs[key]
            jobs[#jobs + 1] = { rec = rec, apply = c.apply, addonKey = c.addonKey }
        end
    end
end

local watcher
function Engine.Boot()
    Engine.ApplyAll()

    for _, rec in ipairs(recipes) do
        if ns.DB.IsWindowEnabled(rec.key) then RegisterCompanions(rec) end
    end

    -- 結算 `Engine.AddCompanion`：到這一刻還沒等到 host 的，就是 key 打錯了
    -- （`ThirdParty/*.lua` 排在所有 `Skins\*.lua` 之後，host 一定已經 Register 過）。
    -- 記進「找不到的區域」—— 這是**我們自己**的設定錯誤，不是「玩家沒裝那支插件」，
    -- 所以不受伴隨元件規則第 2 條的「靜默跳過」管。
    for hostKey in pairs(pendingCompanions) do
        Note(Engine.log.missing, "AddCompanion(" .. tostring(hostKey) .. ")")
    end

    -- 沒有 host 的那一批（第三方自己建的框，不長在任何暴雪視窗上）。
    -- 只看總開關 ＋ 它自己的第三方開關，兩道閘都在 `CompanionEnabled` 裡。
    if ns.db and ns.db.enabled then
        RegisterCompanions(nil, hostlessCompanions)
    end

    -- 「插件載入時就整組建好」的伴隨元件：跟事件那一條走同一條路（延一幀、戰鬥閘、
    -- 脫戰補跑），只是觸發點是「配方全部套完之後」。沒有人登記就什麼都不會發生。
    C_Timer.After(0, function() RunCompanions(COMPANION_AT_LOGIN) end)

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
            -- 戰鬥中收到過的伴隨元件事件，出戰補跑一次（信箱在戰鬥中開得起來）
            for event in pairs(companionPending) do
                RunCompanions(event)
            end
        end
    end)
end

------------------------------------------------------------
-- /mskin debug 的組字
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

-- 三張問題清單共用的印法：空的就整節不印。
--
-- ⚠ **有問題的才展開。** 十幾份配方一起套，把每一條 missing 都攤平印出來會是
--   幾十行沒有主人的字串；狀態列上先給一個數字，要看細節再往下讀那一節。
local PROBLEM_SECTIONS = {
    { key = "missing",   title = "Regions not found (Blizzard may have renamed them):" },
    { key = "protected", title = "Skipped because the frame is protected:" },
    { key = "implicit",  title = "Implicitly protected (skinned anyway):" },  -- L key，見 Locales
    { key = "deferred",  title = "Deferred until out of combat:" },
    { key = "forbidden", title = "Skipped because the object is forbidden:" },
    -- 參考資料：這幾塊背景走的是子框那條路而不是 region（見 INFORMATIONAL）
    { key = "frameBackdrop", title = "Backdrop drawn as a child frame:" },
}

-- ⚠ 「隱式保護但照樣上皮了」**不算問題**，所以不進這個數字 —— 它只是一張
--    「哪些容器坐在 secure 子孫上」的參考清單（下次有人懷疑保護規則時要看的）。
--    括號裡的數字要維持「這個視窗有幾個地方沒做到」的語意。
--    同理「這塊背景退回子框畫」也只是參考 —— 它是「哪個面板走了哪條路」的答案，
--    不是「這個視窗有幾個地方沒做到」。
local INFORMATIONAL = { implicit = true, frameBackdrop = true }

local function ProblemCount(log)
    if not log then return 0 end
    local n = 0
    for _, sec in ipairs(PROBLEM_SECTIONS) do
        local list = log[sec.key]
        if list and not INFORMATIONAL[sec.key] then n = n + #list end
    end
    return n
end

local function PrintProblems(out, log, indent)
    if not log then return end
    for _, sec in ipairs(PROBLEM_SECTIONS) do
        local list = log[sec.key]
        if list and #list > 0 then
            out[#out + 1] = indent .. L[sec.title]
            for _, v in ipairs(list) do out[#out + 1] = indent .. "  " .. v end
        end
    end
end

------------------------------------------------------------
-- /mskin debug
--
-- 版面（第四輪改的，理由見上面那段）：
--
--   [米利的介面外觀] v0.1.0  enabled=true
--     hook: 已停用                  ← 只有真的停用過才出現，而且排在最上面
--       AchievementCategory
--     對話: 已套用
--     角色資訊: 已套用  (3)         ← 括號是問題筆數，有才印
--       找不到的區域（暴雪可能改名了）:
--         TokenFramePopup.CloseButton
--     …
--     已中和的區域: 312 / 已建立的覆蓋層: 180
--     沒有記錄到錯誤
--
-- 「hook 已停用」排最上面是因為它跟別的紀錄不同級：missing 是「少中和一塊」，
-- hook 停用是「這個視窗從某一刻起整個不再上皮」。
------------------------------------------------------------
-- ⚠ **先組行、再印。** 第六輪把同一份內容也寫進 SavedVariables
--   （`MiliUI_Skin_DB.lastReport`，登出時存），這樣「請把 /mskin debug 的輸出貼給我」
--   就不再是驗收的必要步驟 —— 玩家只要正常登出，下一個人直接讀存檔。
--   兩邊共用同一支組字，不會出現「印出來的跟存起來的不一樣」。
function Engine.BuildReport()
    local out = {}
    out[#out + 1] = ("v%s  enabled=%s"):format(ns.VERSION, tostring(ns.db and ns.db.enabled))

    -- ① 停用掉的 hook（最要緊，排最前面）
    if #Engine.log.brokenHooks > 0 then
        out[#out + 1] = ("  hook: %s"):format(L["Disabled"])
        for _, v in ipairs(Engine.log.brokenHooks) do out[#out + 1] = "    " .. v end
    end

    -- ② 每份配方一行，有問題才展開
    for _, rec in ipairs(recipes) do
        local status = StatusText(rec.status)
        -- part 沒跟上外層的就在同一行點名（`· Blizzard_TokenUI: 等待暴雪插件載入`），
        -- 不再為了一句「已套用」多印一列
        if rec.parts then
            local lagging = {}
            for _, part in ipairs(rec.parts) do
                if part.status ~= rec.status then
                    -- 暴雪的插件名本來就不在地化
                    lagging[#lagging + 1] = ("%s: %s"):format(part.addon or "?", StatusText(part.status))
                end
            end
            if #lagging > 0 then
                status = ("%s  · %s"):format(status, table.concat(lagging, ", "))
            end
        end

        local n = ProblemCount(rec.log)
        if n > 0 then
            out[#out + 1] = ("  %s: %s  (%d)"):format(rec.title or rec.key, status, n)
        else
            out[#out + 1] = ("  %s: %s"):format(rec.title or rec.key, status)
        end
        -- 參考清單（隱式保護、退回子框的背景）沒有計入括號，但照樣要印得出來
        PrintProblems(out, rec.log, "    ")
    end

    -- ③ 執行期（hook 裡）發生的紀錄 —— 沒有主人，單獨一節
    if Engine.log.missing[1] or Engine.log.protected[1] or Engine.log.implicit[1]
        or Engine.log.deferred[1] or Engine.log.forbidden[1]
        or Engine.log.frameBackdrop[1] then
        out[#out + 1] = "  hook:"
        PrintProblems(out, Engine.log, "    ")
    end

    out[#out + 1] = ("  %s %d / %s %d / %s %d"):format(
        L["Regions neutralized:"], Engine.log.neutralized,
        L["Overlays:"], Engine.log.overlays,
        L["Region backdrops:"], Engine.log.regions)

    if #ns.errors == 0 then
        out[#out + 1] = "  " .. L["No errors recorded"]
    else
        for i, err in ipairs(ns.errors) do
            out[#out + 1] = ("  %d. %s"):format(i, err)
        end
    end
    return out
end

function Engine.Report()
    local ok, lines = pcall(Engine.BuildReport)
    if not ok or type(lines) ~= "table" then return end
    ns.Print(lines[1] or "")
    for i = 2, #lines do print(lines[i]) end
end

------------------------------------------------------------
-- 登出時把同一份報告存進 SavedVariables
--
-- 只留**最後一份**（不是歷史紀錄）：這是「上一次遊戲結束時 skin 的狀態」，
-- 不是一份要長期累積的日誌。上限 400 行 —— 正常情況二、三十行就印完，
-- 真的長到四百行表示有東西在暴衝，那時候多存的也沒有意義。
--
-- ⚠ 整段 pcall：登出路徑上報一發錯誤只會讓玩家看到一個關不掉的錯誤視窗。
-- ⚠ 不新增任何玩家可見的字串 —— 這是給維護者讀存檔用的。
------------------------------------------------------------
local REPORT_MAX_LINES = 400

function Engine.SaveReport()
    if type(MiliUI_Skin_DB) ~= "table" then return end
    local ok, lines = pcall(Engine.BuildReport)
    if not ok or type(lines) ~= "table" then return end
    local kept = {}
    for i = 1, math.min(#lines, REPORT_MAX_LINES) do
        kept[i] = tostring(lines[i])
    end
    MiliUI_Skin_DB.lastReport = {
        time    = date("%Y-%m-%d %H:%M:%S"),
        version = ns.VERSION,
        lines   = kept,
    }
end
