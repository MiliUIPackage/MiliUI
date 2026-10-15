------------------------------------------------------------
-- 設定宿主：向本體註冊「便利功能」分頁，或用自己的獨立視窗
--
-- 兩種宿主呼叫的是同一支 ns.BuildBody（Options/Controls.lua），長相一模一樣。
-- 登入時（不是檔案載入時）決定：
--   * 本體在、有 MiliUI.RegisterOptionsTab、而且不是舊本體 → 註冊分頁 id "qol"
--   * 否則 → 自己的視窗（Options/Panel.lua）
--
-- 其他檔案要碰「目前的設定視窗」一律走這裡（ns.Host.Frame／Close／Open），
-- 不准直接摸本體的框。
------------------------------------------------------------
local _, ns = ...

ns.Host = {}
local Host = ns.Host

local mode            -- "core"＝本體分頁、"own"＝自己的視窗
local coreContainer   -- 本體交給 build 的分頁框

local function RegisterWithCore()
    local api = type(_G.MiliUI) == "table" and _G.MiliUI
    if ns.legacyCore or not (api and type(api.RegisterOptionsTab) == "function") then
        return false
    end
    local ok = api.RegisterOptionsTab({
        id = "qol", label = "便利功能", order = 20,
        readOnly = false,
        build = function(container, width)
            coreContainer = container
            return ns.BuildBody(container, width)
        end,
        onShow = function() end,
        -- 本體的 W.CloseDropdowns() 關不到我們這份 vendor 的下拉，切走時自己關
        onHide = function() ns.W.CloseDropdowns() end,
    })
    return ok == true
end

function Host.Init()
    if mode then return end
    mode = RegisterWithCore() and "core" or "own"
end

function Host.Mode()
    return mode
end

-- 目前的宿主視窗（確認彈窗的父層）。本體宿主時是本體交給我們的分頁框
function Host.Frame()
    if mode == "core" then return coreContainer end
    return ns.Options and ns.Options.panel
end

-- 開設定：斜線指令、選單項目、插件收納選單、暴雪設定分類的按鈕全部走這一支
function Host.Open()
    if not ns.db then return end
    Host.Init()
    if mode == "core" then
        _G.MiliUI.OpenOptions("qol")
    else
        ns.Options.Open()
    end
end

-- 關掉目前的設定視窗（要開別家面板前先讓路用）
function Host.Close()
    if mode == "core" then
        local panel = coreContainer and coreContainer:GetParent()
        if panel then panel:Hide() end
    elseif ns.Options and ns.Options.panel then
        ns.Options.panel:Hide()
    end
end

ns.RegisterCallback("Init", "Host", Host.Init)
