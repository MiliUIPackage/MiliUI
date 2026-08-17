------------------------------------------------------------
-- MiliUI: Ayije_CDM ← 米利頭像框架錨定
-- CDM 內建的 PLAYER_FRAME_CANDIDATES 只認得幾個常見的頭像插件，
-- 不包含 MiliUI_UnitFrames，導致飾品/防禦/種族技能永遠錨定在
-- Blizzard 內建頭像。此腳本 hook CDM.AnchorToPlayerFrame，
-- 使其優先使用米利頭像框架的玩家框 "MiliUIUF_Player"。
------------------------------------------------------------

local PLAYER_FRAME_NAME = "MiliUIUF_Player"
local EXTRA_GAP = 10  -- 額外間距（像素），避免飾品圖標黏在頭像上

local INVERTED_ANCHORS = {
    TOPLEFT     = "BOTTOMLEFT",
    TOPRIGHT    = "BOTTOMRIGHT",
    BOTTOMLEFT  = "TOPLEFT",
    BOTTOMRIGHT = "TOPRIGHT",
}

local function GetPlayerFrame()
    local frame = _G[PLAYER_FRAME_NAME]
    if frame and frame.IsShown and frame:IsShown() then
        return frame
    end
end

EventUtil.ContinueOnAddOnLoaded("Ayije_CDM", function()
    local CDM = _G["Ayije_CDM"]
    if not CDM then return end

    -- CDM 重構後改用 CDM.Pixel 統一像素完美 API
    local Pixel = CDM.Pixel
    if not (Pixel and Pixel.SetPoint) then return end

    -- 保存原始函式
    local origAnchorToPlayerFrame = CDM.AnchorToPlayerFrame

    -- 替換 AnchorToPlayerFrame：米利頭像可見時直接錨定過去
    CDM.AnchorToPlayerFrame = function(container, anchorPoint, offsetX, offsetY, moduleName, forceRefresh, containerAnchor)
        if not container then return end

        local playerFrame = GetPlayerFrame()
        if not playerFrame then
            -- 米利頭像不可見，走 CDM 原始邏輯（fallback 到 Blizzard 頭像等）
            return origAnchorToPlayerFrame(container, anchorPoint, offsetX, offsetY, moduleName, forceRefresh, containerAnchor)
        end

        -- 使用 CDM 的像素完美定位，與原始邏輯一致
        -- 根據錨定方向加上額外間距
        local gapX, gapY = 0, 0
        if anchorPoint == "TOPLEFT" or anchorPoint == "BOTTOMLEFT" then
            gapX = -EXTRA_GAP   -- 向左推
        elseif anchorPoint == "TOPRIGHT" or anchorPoint == "BOTTOMRIGHT" then
            gapX = EXTRA_GAP    -- 向右推
        end
        if anchorPoint == "TOPLEFT" or anchorPoint == "TOPRIGHT" then
            gapY = EXTRA_GAP    -- 向上推
        elseif anchorPoint == "BOTTOMLEFT" or anchorPoint == "BOTTOMRIGHT" then
            gapY = -EXTRA_GAP   -- 向下推
        end

        container:ClearAllPoints()
        local cAnchor = containerAnchor or INVERTED_ANCHORS[anchorPoint] or anchorPoint
        Pixel.SetPoint(container, cAnchor, playerFrame, anchorPoint, offsetX + gapX, offsetY + gapY)

        if not container:IsShown() then
            container:Show()
        end
    end
end)
