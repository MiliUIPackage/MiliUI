------------------------------------------------------------
-- 除錯報告
--
-- /mdm debug 把這份全文放進設定視窗的「除錯」分頁，玩家按「全選」、Ctrl+C 貼給作者。
-- 內容是為「視窗位置／顯示」這類回報設計的：存檔裡的座標、框實際的錨點與矩形、
-- UIParent 的尺寸與縮放、暴雪內建統計視窗的位置、套組磁吸註冊表、最近的錯誤。
-- 之前要玩家貼 /run 巨集才拿得到這些，現在一個指令就全部有。
--
-- ⚠ 12.1 之後幾何值有可能是秘密值（內建統計視窗餵過秘密值），
--   一律先過 D.IsSecret 再 tostring，不做任何算術。
------------------------------------------------------------
local _, ns = ...

local D = ns.Data

local function Num(v)
    if v == nil then return "nil" end
    if D.IsSecret(v) then return "secret" end
    if type(v) == "number" then
        if v == math.floor(v) then return tostring(v) end
        return ("%.2f"):format(v)
    end
    return tostring(v)
end

local function Name(f)
    if not f then return "nil" end
    local ok, n = pcall(f.GetName, f)
    if ok and n then return n end
    return "<unnamed>"
end

-- 一個框的所有錨點，一行一個
local function Points(lines, indent, f)
    local n = f:GetNumPoints() or 0
    if n == 0 then
        lines[#lines + 1] = indent .. "points: (none)"
        return
    end
    for i = 1, n do
        local p, rel, rp, x, y = f:GetPoint(i)
        lines[#lines + 1] = ("%spoint %d: %s -> %s.%s (%s, %s)")
            :format(indent, i, tostring(p), Name(rel), tostring(rp), Num(x), Num(y))
    end
end

local function Rect(f)
    return ("L=%s T=%s R=%s B=%s w=%s h=%s scale=%s shown=%s")
        :format(Num(f:GetLeft()), Num(f:GetTop()), Num(f:GetRight()), Num(f:GetBottom()),
                Num(f:GetWidth()), Num(f:GetHeight()), Num(f:GetEffectiveScale()),
                tostring(f:IsShown()))
end

local function SnapToText(st)
    if type(st) ~= "table" then return "nil" end
    return ("%s / %s / %s%s"):format(tostring(st.target), tostring(st.side),
        tostring(st.align), st.offset and (" / " .. Num(st.offset)) or "")
end

function ns.DebugText()
    local L = {}
    local function add(s) L[#L + 1] = s end

    local charKey = ns.DB.CharKey and ns.DB.CharKey() or "?"
    add(("MiliUI Damage Meters v%s  profile=%s  char=%s  api=%s  combat=%s")
        :format(tostring(ns.VERSION), tostring(ns.profileName), charKey,
                tostring(ns.HAS_API), tostring(ns.Combat and ns.Combat.IsInCombat())))
    local build, _, _, toc = GetBuildInfo()
    add(("client: %s (%s)  locale=%s  time=%s")
        :format(tostring(build), tostring(toc), tostring(GetLocale()), date("%Y-%m-%d %H:%M:%S")))

    ------------------------------------------------------------
    -- 畫面與 UIParent
    ------------------------------------------------------------
    add("")
    add("[screen]")
    local pw, ph = GetPhysicalScreenSize()
    add(("physical=%sx%s  GetScreen=%sx%s  uiScale=%s useUiScale=%s")
        :format(Num(pw), Num(ph), Num(GetScreenWidth()), Num(GetScreenHeight()),
                tostring(GetCVar("uiScale")), tostring(GetCVar("useUiScale"))))
    add(("UIParent: %s"):format(Rect(UIParent)))
    Points(L, "  ", UIParent)

    ------------------------------------------------------------
    -- 我們的視窗：存檔 vs 實際
    ------------------------------------------------------------
    add("")
    add(("[windows] count=%s"):format(tostring(ns.DB.WindowCount())))
    if ns.Windows then
        ns.Windows.ForEach(function(W)
            local d = W.wdb or {}
            add(("#%d saved: x=%s y=%s w=%s h=%s autoPlaced=%s snapTo=%s locked=%s snapDisabled=%s reverse=%s visibility=%s")
                :format(W.idx, Num(d.x), Num(d.y), Num(d.width), Num(d.height),
                        tostring(d.autoPlaced), SnapToText(d.snapTo), tostring(d.locked),
                        tostring(d.snapDisabled), tostring(d.reverse), tostring(d.visibility)))
            local f = W.frame
            add(("   frame %s: %s userPlaced=%s drag=%s resize=%s")
                :format(Name(f), Rect(f), tostring(f:IsUserPlaced()),
                        tostring(W._drag ~= nil), tostring(W._resize ~= nil)))
            Points(L, "   ", f)
        end)
    else
        add("  (windows not built)")
    end

    ------------------------------------------------------------
    -- 暴雪內建統計：第一次擺放會接手它的位置，停用之後框還在（只是藏起來）
    ------------------------------------------------------------
    add("")
    local acc = ns.DB.Account()
    add(("[builtin] cvar %s=%s  builtinRestore=%s  disableBuiltinMeter=%s")
        :format(ns.Builtin.CVAR, tostring(ns.Builtin.IsEnabled()),
                tostring(acc and acc.builtinRestore),
                tostring(ns.DB.Style() and ns.DB.Style().disableBuiltinMeter)))
    for i = 1, ns.Builtin.MAX_WINDOWS do
        local f = _G[ns.Builtin.WINDOW_NAME .. i]
        if f then
            add(("  %s%d: %s"):format(ns.Builtin.WINDOW_NAME, i, Rect(f)))
            Points(L, "    ", f)
        else
            add(("  %s%d: (does not exist)"):format(ns.Builtin.WINDOW_NAME, i))
        end
    end
    local bx, by, bi = ns.Builtin.WindowOffset(1)
    add(("  WindowOffset(1) -> %s, %s (matched %s)"):format(Num(bx), Num(by), tostring(bi)))

    ------------------------------------------------------------
    -- 套組磁吸註冊表：誰在、誰吸在誰身上
    ------------------------------------------------------------
    add("")
    if ns.Snap and ns.Snap.bars then
        add(("[snap] lib v%s"):format(tostring(ns.Snap.version)))
        local keys = {}
        for k in pairs(ns.Snap.bars) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local info = ns.Snap.bars[k]
            local db = info.db and info.db()
            local f = info.frame
            add(("  %s: attach=%s group=%s snapTo=%s frame=%s %s")
                :format(k, tostring(info.attach), tostring(info.group),
                        SnapToText(db and db.snapTo), Name(f),
                        f and Rect(f) or "(no frame)"))
        end
    else
        add("[snap] (not loaded)")
    end

    ------------------------------------------------------------
    -- 圖示：每個視窗目前顯示的列，輸入（職業、專精圖示）→ 對到哪張圖 → 實際畫了什麼。
    -- 「有些列沒圖示」的回報看這段：class=nil 是 NPC／秘密值（照設計不畫），
    -- specIcon=secret 是戰鬥中拿不到（退暴雪圖示），mili=NO 是對照表沒對上。
    ------------------------------------------------------------
    add("")
    local st = ns.DB.Style() or {}
    add(("[icons] style=%s zoom=%s"):format(tostring(st.iconStyle), Num(st.iconZoom)))
    local function Str(v)
        if v == nil then return "nil" end
        if D.IsSecret(v) then return "secret" end
        return tostring(v)
    end
    local function BarLine(prefix, bar)
        local src = bar and bar._src
        if not src or not bar.row:IsShown() then return end
        local info = D.SpecInfo(src.specIconID)
        local tex = bar.icon:IsShown() and bar.icon:GetTexture()
        add(("%s %s class=%s specIcon=%s own=%s -> mili=%s | icon shown=%s tex=%s bg=%s")
            :format(prefix, Str(src.name), Str(src.classFilename), Str(src.specIconID),
                    tostring(D.IsOwnRow(src)),
                    info and (info.tex and info.tex:match("([^\\]+)%.png$") or "no tex") or "NO",
                    tostring(bar.icon:IsShown()), Str(tex),
                    tostring(bar.icon._miliBg and bar.icon._miliBg:IsShown() or false)))
    end
    if ns.Windows then
        ns.Windows.ForEach(function(W)
            add(("#%d type=%s"):format(W.idx, Str(W.curDMType)))
            ns.Window.ForEachPane(W, function(P)
                local tag = (P == W) and "  " or "  [split]"
                for i, bar in ipairs(P.rowPool or {}) do BarLine(tag .. " " .. i .. ".", bar) end
                if P.stickyBar then BarLine(tag .. " sticky", P.stickyBar) end
            end)
        end)
    end
    add("  spec map:")
    for _, line in ipairs(D.SpecMapLines()) do add("    " .. line) end

    ------------------------------------------------------------
    -- 錯誤
    ------------------------------------------------------------
    add("")
    add(("[errors] %d"):format(#ns.errors))
    for i, err in ipairs(ns.errors) do
        add(("  %d. %s"):format(i, tostring(err)))
    end

    -- 存檔裡不留色碼
    local text = table.concat(L, "\n")
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
