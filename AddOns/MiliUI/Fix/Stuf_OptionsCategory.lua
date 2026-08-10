------------------------------------------------------------
-- MiliUI: 讓 Stuf 出現在設定選單裡
--
-- Stuf_Options 是 LoadOnDemand，只有 /stuf 才會載入 —— 沒載入就沒有東西去
-- 註冊設定分類，所以遊戲設定選單裡永遠找不到 Stuf，只能靠斜線指令。
--
-- Stuf 原本的設計是先註冊一個佔位面板（core.lua 的 "AceConfig hack to be LOD
-- friendly"），點它才載入真正的選項；但那行註冊用的是 InterfaceOptions_AddCategory，
-- 在 WoW 10.0 被移除後就只剩註解，沒有補上替代品。
--
-- 這裡直接在登入後載入 Stuf_Options，讓它自己註冊（配合 Stuf_Options 那邊補的
-- 載入時 CreateOptionFrame()）。比復活佔位面板乾淨：不會出現兩個同名分類。
--
-- 代價是 Stuf_Options 會常駐記憶體，換來選單項目一直存在。
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

EventUtil.ContinueOnAddOnLoaded("Stuf", function()
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()

        -- 已經載入過就不用再來一次（例如玩家在登入前就打了 /stuf）
        if C_AddOns.IsAddOnLoaded("Stuf_Options") then return end

        local loaded, reason = C_AddOns.LoadAddOn("Stuf_Options")
        if not loaded then
            print("|cffffe00a[MiliUI]|r 載入 Stuf_Options 失敗：" .. tostring(reason))
        end
    end)

    ------------------------------------------------------------
    -- /stufopt：診斷「分類出得來但面板空白」
    ------------------------------------------------------------
    -- 面板內容是 AceConfigDialog 在 OnShow 時餵進去的，那條路上的錯誤很容易
    -- 被吞掉（看起來就只是一片空白）。這裡把每一步各自 pcall 起來，錯在哪一步
    -- 就印哪一步。
    SLASH_MILIUISTUFOPT1 = "/stufopt"
    SlashCmdList["MILIUISTUFOPT"] = function()
        local function line(k, v) print("|cffffe00a[MiliUI]|r " .. k .. "：" .. tostring(v)) end

        line("Stuf_Options 已載入", C_AddOns.IsAddOnLoaded("Stuf_Options"))

        -- 1. 選項表本身
        if type(Stuf.GetOptionsTable) ~= "function" then
            line("選項表", "Stuf:GetOptionsTable 不存在")
            return
        end
        local ok, options = pcall(Stuf.GetOptionsTable, Stuf)
        if not ok then
            line("選項表", "取得時出錯：" .. tostring(options))
            return
        end
        local argCount = 0
        if type(options) == "table" and type(options.args) == "table" then
            for _ in pairs(options.args) do argCount = argCount + 1 end
        end
        line("選項表 args 數量", argCount)

        -- 2. 驗證（AceConfigRegistry 22 比舊版嚴格，不合格會讓面板整個空白）
        local registry = LibStub and LibStub("AceConfigRegistry-3.0", true)
        if registry and registry.ValidateOptionsTable then
            local vok, verr = pcall(registry.ValidateOptionsTable, registry, options, "Stuf")
            line("選項表驗證", vok and "通過" or ("失敗：" .. tostring(verr)))
        end

        -- 3. 實際開啟（真正會出錯的那一步）
        local dialog = LibStub and LibStub("AceConfigDialog-3.0", true)
        if not dialog then
            line("AceConfigDialog", "取不到")
            return
        end
        local dok, derr = pcall(dialog.Open, dialog, "Stuf")
        line("AceConfigDialog:Open", dok and "成功（獨立視窗）" or ("失敗：" .. tostring(derr)))
    end
end)
