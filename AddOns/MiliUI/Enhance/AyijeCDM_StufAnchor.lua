------------------------------------------------------------
-- MiliUI: Ayije_CDM ← Stuf 玩家頭像錨定
-- CDM 內建的 PLAYER_FRAME_CANDIDATES 未包含 Stuf，
-- 導致飾品/防禦/種族技能永遠錨定在 Blizzard 內建頭像。
-- 此腳本 hook CDM.AnchorToPlayerFrame，使其優先使用
-- Stuf 的玩家頭像框架 "Stuf.units.player"。
------------------------------------------------------------

local STUF_PLAYER_FRAME_NAME = "Stuf.units.player"
local STUF_EXTRA_GAP = 10  -- 額外間距（像素），避免飾品圖標黏在頭像上

local INVERTED_ANCHORS = {
    TOPLEFT     = "BOTTOMLEFT",
    TOPRIGHT    = "BOTTOMRIGHT",
    BOTTOMLEFT  = "TOPLEFT",
    BOTTOMRIGHT = "TOPRIGHT",
}

local function GetStufPlayerFrame()
    local frame = _G[STUF_PLAYER_FRAME_NAME]
    if frame and frame.IsShown and frame:IsShown() then
        return frame
    end
end

EventUtil.ContinueOnAddOnLoaded("Ayije_CDM", function()
    local CDM = _G["Ayije_CDM"]
    if not CDM then return end

    local SetPixelPerfectPoint = CDM.CONST and CDM.CONST.SetPixelPerfectPoint
    if not SetPixelPerfectPoint then return end

    -- 保存原始函式
    local origAnchorToPlayerFrame = CDM.AnchorToPlayerFrame

    -- 替換 AnchorToPlayerFrame：Stuf 可見時直接錨定到 Stuf
    CDM.AnchorToPlayerFrame = function(container, anchorPoint, offsetX, offsetY, moduleName, forceRefresh, containerAnchor)
        if not container then return end

        local stufFrame = GetStufPlayerFrame()
        if not stufFrame then
            -- Stuf 不可見，走 CDM 原始邏輯（fallback 到 Blizzard 頭像等）
            return origAnchorToPlayerFrame(container, anchorPoint, offsetX, offsetY, moduleName, forceRefresh, containerAnchor)
        end

        -- 使用 CDM 的像素完美定位，與原始邏輯一致
        -- 根據錨定方向加上額外間距
        local gapX, gapY = 0, 0
        if anchorPoint == "TOPLEFT" or anchorPoint == "BOTTOMLEFT" then
            gapX = -STUF_EXTRA_GAP   -- 向左推
        elseif anchorPoint == "TOPRIGHT" or anchorPoint == "BOTTOMRIGHT" then
            gapX = STUF_EXTRA_GAP    -- 向右推
        end
        if anchorPoint == "TOPLEFT" or anchorPoint == "TOPRIGHT" then
            gapY = STUF_EXTRA_GAP    -- 向上推
        elseif anchorPoint == "BOTTOMLEFT" or anchorPoint == "BOTTOMRIGHT" then
            gapY = -STUF_EXTRA_GAP   -- 向下推
        end

        container:ClearAllPoints()
        local cAnchor = containerAnchor or INVERTED_ANCHORS[anchorPoint] or anchorPoint
        SetPixelPerfectPoint(container, cAnchor, stufFrame, anchorPoint, offsetX + gapX, offsetY + gapY)

        if not container:IsShown() then
            container:Show()
        end
    end
end)
