------------------------------------------------------------
-- MiliUI_Tooltip 命名空間與常數
--
-- 這是 TinyTooltip 的自製重寫版，taint 圍堵設計見 Core/Hooks.lua 檔頭的
-- 「接觸面清單」。任何要碰暴雪物件的新程式碼都必須先過那張清單。
------------------------------------------------------------
local ADDON, ns = ...

ns.ADDON_NAME = ADDON
ns.VERSION    = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
ns.DB_VERSION = 1            -- schemaVersion。尚未發佈、沒有遷移鏈；發佈後改預設值要配遷移

ns.playerClass = select(2, UnitClass("player"))   -- player token 不受 12.1 身分限制，安全

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截 —— 共用層 Libs/MiliUIWidgets/Errors.lua
--
--   ns.ReportError  xpcall 的訊息處理器（三道守衛：防遞迴、err 本身可能是秘密
--                   字串、下游 handler 包 pcall）。記進 ns.errors 供 /mtip debug 印出，
--                   同時照常轉給全域 errorhandler（有裝 BugSack 就進 BugSack）。
--   封鎖動作攔截    ADDON_ACTION_FORBIDDEN 不是 Lua error、pcall 攔不住，
--                   但事件會點名是哪個插件的哪個函式。
------------------------------------------------------------
ns.Errors.Install(function(line)
    print(ns.PREFIX_COLOR .. "[米利的滑鼠提示]|r |cffff5555" .. line .. "|r")
end)

------------------------------------------------------------
-- 診斷記錄器（/mtip log 開關、/mtip logdump 印出）
-- 抓「戰鬥中敵方提示顯示成上一個友方」這類要看時序的問題用。
-- 關閉時每個記錄點只付一次 boolean 檢查。
------------------------------------------------------------
ns.logEnabled = false
ns.logBuf = {}

-- 值的安全描述：秘密值不讀內容，只標型別
function ns.Describe(v)
    if v == nil then return "nil" end
    if issecretvalue and issecretvalue(v) then return "secret<" .. type(v) .. ">" end
    if type(v) == "string" then return '"' .. v .. '"' end
    return tostring(v)
end

function ns.Log(fmt, ...)
    if not ns.logEnabled then return end
    local ok, line = pcall(string.format, fmt, ...)
    tinsert(ns.logBuf, ("[%.2f] %s"):format(GetTime() % 1000, ok and line or fmt))
    -- 行狀態探針一次會吐十幾條，150 條大概只留得住兩次 Apply
    if #ns.logBuf > 400 then tremove(ns.logBuf, 1) end
end

------------------------------------------------------------
-- 行狀態探針（2026-09-08，追「職業有時候不顯示」）
--
-- 假設：**secret aspect**。把秘密字串餵給 `FontString:SetText` 會在物件上留下
-- Text aspect，之後 `GetText()` 一律回秘密值，只有 `SetToDefaults()` 清得掉
-- （見 .claude/notes/wow-121-secret-values.md）。而本插件整套「認行」機制
-- （Lines.Find／Hide／StripText／GetOriginalSpecLine／RemoveRightClickHint…）
-- 全靠 `GetText()`，加上 GameTooltip 的行物件是**重複使用**的 —— 一行被蓋章，
-- 之後每一份提示的那一行都認不出來。現成的污染源是 Modules/Target.lua 的
-- 目標行（`format` 進去的目標名字是秘密字串）。
--
-- 要回答兩個問題：
--   ① 行到底有沒有被蓋章                → 看 `aspect=`
--   ② ClearLines／暴雪重填清不清得掉    → 比對同一份提示 pre 與 post 的 `aspect=`，
--      以及下一份提示的 pre（暴雪已經重填過了，還是 true 就是清不掉）
--   鐵證：被 `Lines.HideRange` 清成 nil 的行，`GetText()` 仍回 secret。
--
-- ⚠ 這幾支 API 的簽章沒實測過，一律 pcall，問不到印 "?" —— 探針不可以自己
--    變成故障源。讀回來的文字只做 issecretvalue 判斷，絕不做字串運算。
------------------------------------------------------------
local function AspectOf(obj)
    if not obj or not obj.HasSecretAspect then return "?" end
    local ok, res = pcall(obj.HasSecretAspect, obj, "Text")   -- 可能吃 aspect 名
    if not ok then ok, res = pcall(obj.HasSecretAspect, obj) end  -- 也可能不吃
    if not ok then return "?" end
    return tostring(res)
end

local function HasSecretOf(obj)
    if not obj or not obj.HasSecretValues then return "?" end
    local ok, res = pcall(obj.HasSecretValues, obj)
    if not ok then return "?" end
    return tostring(res)
end

function ns.DescribeLine(line)
    if not line then return "nil" end
    local ok, text = pcall(line.GetText, line)
    local desc
    if not ok then
        desc = "?"
    elseif text == nil then
        desc = "nil"
    elseif issecretvalue and issecretvalue(text) then
        desc = "secret<" .. type(text) .. ">"
    elseif type(text) == "string" then
        -- 明文才可以做字串運算
        desc = '"' .. (#text > 50 and (text:sub(1, 50) .. "…") or text) .. '"'
    else
        desc = tostring(text)
    end
    return ("%s aspect=%s hsv=%s"):format(desc, AspectOf(line), HasSecretOf(line))
end

-- 掃一份提示的所有左欄行。tag 用來分辨插件動手前（pre）／後（post）。
function ns.LogLines(tag, tip)
    if not ns.logEnabled or not tip then return end
    local okN, n = pcall(tip.NumLines, tip)
    if not okN or type(n) ~= "number" then return end
    local okName, name = pcall(tip.GetName, tip)
    if not okName or type(name) ~= "string" then return end
    for i = 1, n do
        ns.Log("  %s L%d %s", tag, i, ns.DescribeLine(_G[name .. "TextLeft" .. i]))
    end
end

------------------------------------------------------------
-- 封鎖／禁止動作攔截（同 MiliUI_UnitFrames 的做法）
-- ADDON_ACTION_FORBIDDEN 不是 Lua error、pcall 攔不住；事件會點名插件與函式，
-- 抓下來直接印出，taint 傳染第一時間就看得到兇手。
------------------------------------------------------------
do
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
    watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
    local seen = {}
    watcher:SetScript("OnEvent", function(_, event, addonName, funcName)
        if addonName ~= ADDON then return end
        local line = ("%s：%s（戰鬥中=%s）"):format(
            event == "ADDON_ACTION_FORBIDDEN" and "禁止動作" or "封鎖動作",
            tostring(funcName), tostring(InCombatLockdown() and true or false))
        tinsert(ns.errors, line)
        if #ns.errors > 10 then tremove(ns.errors, 1) end
        local key = tostring(funcName)
        if not seen[key] then
            seen[key] = true
            print("|cff4DD2FF[米利的滑鼠提示]|r |cffff5555" .. line .. "|r")
        end
    end)
end

_G.MiliUITip = ns
