------------------------------------------------------------
-- 「一般」分頁：全域樣式與顏色
------------------------------------------------------------
local _, ns = ...

local W, Controls = ns.W, ns.Controls

local tab, scroll
local refreshers

local function ApplyAll()
    for unitKey in pairs(ns.db.units) do
        if unitKey == "totem" then
            if ns.TotemsApplySettings then ns.TotemsApplySettings() end
        else
            ns.ApplySettings(unitKey)
        end
    end
end

local CONTROLS = {
    { type = "header", label = "邊框" },
    { type = "slider", key = "borderSize", label = "邊框粗細", min = 0, max = 3, step = 1 },
    { type = "text",   label = "0 = 不畫邊框。所有單位框、血條、能量條共用。" },
    { type = "color",  key = "borderColor", label = "邊框顏色" },

    { type = "header", label = "數字與動畫" },
    { type = "dropdown", key = "numberFormat", label = "數字縮寫", items = {
        { text = "依語系（中文萬／億，其他 K／M）", value = "auto" },
        { text = "萬／億", value = "wan" },
        { text = "K／M", value = "km" },
        { text = "不縮寫（千分位）", value = "raw" },
    } },
    { type = "text",   label = "血量／能量數字由遊戲端縮寫（12.1 秘密值不能在插件內做算術），只能在這幾種官方格式中選。" },
    { type = "dropdown", key = "percentDecimals", label = "百分比小數", items = {
        { text = "整數（85%）", value = 0 }, { text = "一位小數（85.3%）", value = 1 },
    } },
    { type = "toggle", key = "smoothBars", label = "血條／能量條平滑" },
    { type = "text",   label = "用遊戲引擎的內建插值（12.x 原生，秘密值也能用），數值變化時條會滑過去而不是跳。" },

    { type = "header", label = "血量顏色" },
    { type = "text",   label = "「血量漸層」上色法用這兩色內插；灰色給死亡／離線／超出距離文字。" },
    { type = "color", sub = "colors", key = "hpGreen", label = "健康" },
    { type = "color", sub = "colors", key = "hpRed",   label = "危險" },
    { type = "color", sub = "colors", key = "gray",    label = "灰色" },

    { type = "header", label = "施法條顏色" },
    { type = "text",   label = "所有單位的施法條共用這五色；每個單位可各自決定要不要套用「不可打斷」。" },
    { type = "color", sub = "colors", key = "cast",    label = "施法", hasAlpha = false },
    { type = "color", sub = "colors", key = "channel", label = "引導", hasAlpha = false },
    { type = "color", sub = "colors", key = "complete", label = "完成", hasAlpha = false },
    { type = "color", sub = "colors", key = "fail",    label = "失敗／被打斷", hasAlpha = false },
    { type = "color", sub = "colors", key = "notInterruptible", label = "不可打斷", hasAlpha = false },

    { type = "header", label = "滑鼠提示" },
    { type = "toggle", key = "showTooltip", label = "顯示單位提示" },
    { type = "toggle", key = "tooltipHideInCombat", label = "戰鬥中不顯示" },
    { type = "text",   label = "光環圖示的提示由遊戲端顯示（12.1 插件讀不到光環內容），跟著單位提示一起開關。" },

    { type = "header", label = "預覽" },
    { type = "number", key = "previewBossDisplayID", label = "示範模型 ID", step = 1 },
    { type = "text",   label = "預覽時敵對單位（目標／專注／首領）的 3D 模型 displayID。預設 131474 = 薩拉塔斯（12.x 形態），117121 = 她的 TWW 形態。填 0 就用你自己的角色。" },

    { type = "header", label = "小地圖" },
    { type = "toggle", root = "minimap", key = "show", label = "顯示小地圖按鈕" },

    { type = "header", label = "重置" },
    { type = "button", label = "全域樣式", text = "恢復全域樣式預設", color = "red",
      confirm = "把邊框、數字、顏色等全域樣式恢復成預設值？（各單位的設定不受影響）",
      onClick = function()
          ns.DB.ResetGlobal()
          for unitKey in pairs(ns.db.units) do
              if unitKey == "totem" then
                  if ns.TotemsApplySettings then ns.TotemsApplySettings() end
              else
                  ns.ApplySettings(unitKey)
              end
          end
      end },
    { type = "text", label = "單一單位的重置在「單位」分頁 → 框架 的最下方；全部恢復預設在「設定檔」分頁。" },
}

local function Init()
    if tab then return end
    tab = CreateFrame("Frame", nil, ns.Options.panel)
    tab:SetAllPoints(ns.Options.panel)
    tab:Hide()

    local title = W.CreateSectionTitle(tab, "全域樣式", 660)
    title:SetPoint("TOPLEFT", 16, -14)

    local scrollHolder = CreateFrame("Frame", nil, tab)
    scrollHolder:SetPoint("TOPLEFT", 16, -44)
    scrollHolder:SetPoint("BOTTOMRIGHT", -8, 10)
    scroll = W.CreateScrollFrame(scrollHolder)

    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT")
    content:SetSize(640, 1)

    local ctx = {
        get = function(spec)
            if spec.root == "minimap" then
                return not ns.db.minimap.hide
            end
            local t = Controls.Resolve(ns.db.global, spec)
            return t[spec.key]
        end,
        set = function(spec, v)
            if spec.root == "minimap" then
                ns.SetMinimapButtonShown(v)
                return
            end
            local t = Controls.Resolve(ns.db.global, spec)
            t[spec.key] = v
        end,
        apply = ApplyAll,
    }

    local height, r = Controls.Build(content, CONTROLS, ctx, 4, -4, 640)
    content:SetHeight(height + 20)
    scroll:SetContentHeight(height + 20)
    refreshers = r
end

ns.RegisterCallback("ShowOptionsTab", "generalTab", function(id)
    if id ~= "general" then
        if tab then tab:Hide() end
        return
    end
    Init()
    for _, fn in ipairs(refreshers) do fn() end
    tab:Show()
end)
