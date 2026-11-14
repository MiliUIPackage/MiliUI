---@class addonTableBaganator
local addonTable = select(2, ...)

function addonTable.SingleViews.ComputeGamepadGrid(layouts, upButton, bottomLeftButtons, bottomRightCallback)
  local grid = {}
  local row = 0
  local maxCols = 0
  for _, l in ipairs(layouts) do
    if #l.buttons > 0 and l.visible ~= false then
      row = row + 1
      local lastRow = 1
      for _, b in ipairs(l.buttons) do
        local p = b.position
        if p.y ~= lastRow then
          row = row + 1
          lastRow = p.y
        end
        maxCols = math.max(maxCols, p.x)
        grid[row] = grid[row] or {}
        grid[row][p.x] = b
      end
    end
  end

  addonTable.ItemViewCommon.LinkGamepadGrid(grid, row, maxCols, upButton, bottomLeftButtons, bottomRightCallback)
end
