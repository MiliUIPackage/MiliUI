------------------------------------------------------------
-- 編輯模式整合（wow-editmode-draggable 技能配方）
-- 進編輯模式 → 用預覽孿生代替真實框（不動 secure frame），
-- 孿生蓋 EditModeSystemSelectionTemplate 藍色選取框可拖曳，
-- 位置寫回 db 的 CENTER 偏移。拖曳用游標差值累加（R4：全程不讀框架幾何，
-- 避免秘密值幾何污染的疑慮）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local isInEditMode = false

------------------------------------------------------------
-- 吸附到格線（C11 修正版）
--
-- ⚠⚠ **不要自己畫格線。** 暴雪的編輯模式本來就有一套，而且做得更完整：
--   Blizzard_EditMode/Shared/EditModeManager.lua 的 `EditModeGridMixin`
--   —— 同樣從螢幕中心往外畫，面板上有「顯示格線」勾選框與間距滑桿，
--   中心線還有自己的顏色。
-- 第一版在上面又疊了一層白格線，結果就是兩套格線交錯、畫面一團亂。
--
-- 這裡只補暴雪**沒有**做到的那一塊：`EditModeMagnetismManager` 只服務暴雪自己
-- 註冊的那些系統，我們的框是自訂的、拖曳是自己用游標差值算的，它管不到。
-- 所以吸附要自己做，但參數一律讀暴雪的設定，不另外開一組。
------------------------------------------------------------
local DEFAULT_SPACING = 32

local function GridSpacing()
    local mgr = EditModeManagerFrame
    if not mgr then return DEFAULT_SPACING end
    -- 帳號設定是權威來源（面板載入時就灌好了，不必等格線顯示過）
    local ok, v = pcall(function()
        return mgr:GetAccountSettingValue(Enum.EditModeAccountSetting.GridSpacing)
    end)
    if ok and type(v) == "number" and v > 0 then return v end
    local grid = mgr.Grid
    if grid and type(grid.gridSpacing) == "number" and grid.gridSpacing > 0 then
        return grid.gridSpacing
    end
    return DEFAULT_SPACING
end

-- 吸附的開關是**我們自己的**，預設關。
--
-- ⚠ 不要拿暴雪的 `IsSnapEnabled()` 當閘門：那個開關是給暴雪自己的框用的，
-- 使用者可能為了別的目的打開它，結果我們的框莫名其妙跟著跳格 —— 沒開過任何
-- 相關設定卻看到「怪怪的」行為，是最難回報也最難查的那種問題。
-- 間距倒是照讀暴雪的，那是格線畫在哪裡的事實來源，另開一個只會對不上。
local function Snap(v)
    local on = ns.db and ns.db.global.snapToGrid or false
    if IsShiftKeyDown() then on = not on end     -- 暫時反轉：微調一兩格時好用
    if not on then return v end
    local step = GridSpacing()
    return math.floor(v / step + 0.5) * step
end

------------------------------------------------------------
-- 游標差值拖曳
--
-- 拖曳全程不讀框架幾何（R4：避開秘密值幾何污染的疑慮），只累加游標位移。
--   handle     實際吃滑鼠的框。編輯模式是藍色選取框，設定面板是孿生自己
--   frame      要跟著動的那個框
--   applyPoint 這個系統自己的定位方式（不給就是 CENTER 對 UIParent CENTER）。
--              召喚物錨在玩家框左下角，用預設那套會把 CENTER 偏移寫進 TOPLEFT 語意的欄位
--
-- ⚠⚠ getFDB 是 **getter 不是表**。掛勾只建一次就長期留在框上、永遠不重建，所以任何
-- 在這裡被 closure 抓住的設定表都會過期：DB.Activate 換設定檔時會重建 ns.db，profile
-- 的子表是不同物件，而 RebindProfile 只重指 uf.db、管不到這個 closure。症狀是「框在
-- 畫面上動了，但 ApplySettings 重套後又彈回原位」＝看起來像拖不動，實際上座標寫進了
-- 上一份設定檔。
------------------------------------------------------------
function ns.AttachDrag(handle, frame, getFDB, onMoved, applyPoint)
    if handle.__miliDragHooked then return end
    handle.__miliDragHooked = true
    handle:RegisterForDrag("LeftButton")

    local baseX, baseY, startCX, startCY

    -- nx/ny 是「畫面上（UIParent 單位）的位移」，而 SetPoint 的位移量是**被錨定的框
    -- 自己的**單位，會被它的 scale 乘一次 ⇒ 縮放 150% 的框不除回去的話，游標移 100
    -- 像素框會跑 150 像素（拖曳時框一路跑在游標前面，放手才彈回正確位置）。
    local function Place(nx, ny)
        if applyPoint then
            applyPoint(nx, ny)
            return
        end
        local s = frame:GetScale()
        if not s or s <= 0 then s = 1 end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", nx / s, ny / s)
    end

    handle:SetScript("OnDragStart", function(self)
        local fdb = getFDB()
        baseX, baseY = (fdb and fdb.x) or 0, (fdb and fdb.y) or 0
        startCX, startCY = GetCursorPosition()
        self:SetScript("OnUpdate", function()
            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            -- 拖曳過程就吸附，放手才吸的話手感會「跳一下」
            Place(Snap(baseX + (cx - startCX) / scale), Snap(baseY + (cy - startCY) / scale))
        end)
    end)
    handle:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if not baseX then return end        -- 沒有進行中的拖曳（見下面的 OnHide）
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local fdb = getFDB()
        if fdb then
            -- 寫回的值必須跟拖曳時看到的位置一致，所以這裡也要過同一個 Snap
            fdb.x = math.floor(Snap(baseX + (cx - startCX) / scale) + 0.5)
            fdb.y = math.floor(Snap(baseY + (cy - startCY) / scale) + 0.5)
        end
        baseX, baseY, startCX, startCY = nil, nil, nil, nil
        self.__miliDragEnd = GetTime()
        if onMoved then onMoved() end
    end)

    -- 拖到一半離開編輯模式／關掉設定面板時只會 Hide，OnDragStop 不會來 ⇒ OnUpdate
    -- 留著、baseX/startCX 也留著。下次再拖就會拿上一輪的基準算，框瞬間跳位。
    -- ⚠ 用 HookScript：EditModeSystemSelectionTemplate 自己可能有 OnHide，SetScript 會蓋掉。
    handle:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        baseX, baseY, startCX, startCY = nil, nil, nil, nil
    end)
end

-- 剛剛放開的那一下是拖曳嗎？
-- 拖完放手時 OnClick / OnMouseUp 照樣會來（暴雪不會因為拖過就吃掉點擊），
-- 不擋的話「把框拖到新位置」會順便觸發「跳到這個元件的分頁」。
function ns.WasDragging(handle)
    local t = handle and handle.__miliDragEnd
    return t ~= nil and (GetTime() - t) < 0.15
end

------------------------------------------------------------
-- 選取框（編輯模式專用的藍色外框 ＋ 系統名稱）
------------------------------------------------------------
local function AttachSelection(frame, label, getFDB, onMoved, applyPoint)
    if frame.editSelection then return frame.editSelection end

    local sel = CreateFrame("Frame", nil, frame, "EditModeSystemSelectionTemplate")
    sel:SetAllPoints()
    sel:Hide()
    sel.system = {
        GetSystemName = function() return label end,
    }
    ns.AttachDrag(sel, frame, getFDB, onMoved, applyPoint)

    frame.editSelection = sel
    return sel
end

------------------------------------------------------------
-- 進出編輯模式
------------------------------------------------------------
local function UpdateEditModeState()
    if not ns.db then return end

    if isInEditMode then
        ns.Preview.Open("editmode")
        -- 孿生蓋選取框（boss 只有第一格可拖，拖了整組跟著走）
        ns.Preview.EachTwin(function(uf, unitKey)
            if uf.bossIndex and uf.bossIndex > 1 then return end
            if not uf.db.enabled then return end
            local label = ns.UNIT_LABELS[unitKey] or unitKey
            local sel = AttachSelection(uf, L["MiliUI UF: "] .. label,
                function() return uf.db.frame end, function()
                ns.ApplySettings(unitKey)     -- 同步 boss2-5 與孿生
            end)
            uf:EnableMouse(true)
            sel:ShowHighlighted()
        end)
        -- 圖騰（真實框本身就不是 secure，可直接拖；顯示假內容供瞄準）
        local totem = ns.totemFrame
        if totem and ns.db.units.totem.enabled then
            local sel = AttachSelection(totem, L["MiliUI UF: Summons"],
                function() return ns.db.units.totem.frame end, function()
                if ns.TotemsApplySettings then ns.TotemsApplySettings() end
            end, ns.TotemsAnchorTo)
            totem:Show()      -- 框本身固定四格寬，選取框直接蓋得準
            sel:ShowHighlighted()
        end
    else
        ns.Preview.EachTwin(function(uf)
            if uf.editSelection then uf.editSelection:Hide() end
            uf:EnableMouse(false)
        end)
        -- 設定面板可能還開著（兩邊共用同一批孿生）：上面那圈把滑鼠一律關掉了，
        -- 收尾時讓 Preview 依它自己的狀態決定要不要再打開。
        -- ⚠ 要放在 Preview.Close 之後——Close 會重算那個狀態。
        local totem = ns.totemFrame
        if totem and totem.editSelection then
            totem.editSelection:Hide()
            -- ⚠ 不能只 Hide 就走。註解原本寫「有圖騰在場的話 Poll 會再拉起來」，但 Poll
            -- 只由 PLAYER_TOTEM_UPDATE / PLAYER_ENTERING_WORLD / PLAYER_REGEN_ENABLED 推
            -- ⇒ 地上已經有圖騰時進出編輯模式，框會消失到下次重放圖騰或進副本才回來。
            -- TotemsApplySettings 結尾會 Poll()，讓它自己決定該顯示還是隱藏。
            if ns.TotemsApplySettings then
                ns.TotemsApplySettings()
            else
                totem:Hide()
            end
        end
        ns.Preview.Close("editmode")
        ns.Preview.ApplyInteractive()
    end
end

------------------------------------------------------------
-- 三層 hook（防載入順序）
------------------------------------------------------------
local editModeHooked = false
local function HookEditMode()
    if editModeHooked then return end
    if not EditModeManagerFrame then return end
    editModeHooked = true
    EditModeManagerFrame:HookScript("OnShow", function()
        isInEditMode = true
        UpdateEditModeState()
    end)
    EditModeManagerFrame:HookScript("OnHide", function()
        isInEditMode = false
        UpdateEditModeState()
    end)
    if EditModeManagerFrame:IsShown() then
        isInEditMode = true
        UpdateEditModeState()
    end
end

HookEditMode()                                       -- Tier 1：檔案層
if not editModeHooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookEditMode)   -- Tier 2
end
ns.RegisterCallback("Loaded", "editmode", HookEditMode)                  -- Tier 3
