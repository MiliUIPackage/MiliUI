---@class addonTableBaganator
local addonTable = select(2, ...)

function addonTable.CategoryViews.ComputeGamepadGrid(layouts, upButton, bottomLeftButtons, bottomRightCallback)
  local iconPadding, iconSize = addonTable.ItemButtonUtil.GetPaddingAndSize()
  local iconSpace = iconSize + iconPadding
  local categorySpacing = addonTable.Config.Get(addonTable.Config.Options.CATEGORY_HORIZONTAL_SPACING) * iconSpace

  local grid = {}
  local inputRow = 0
  local row = 0
  local cols = {1}
  local rowEnd = 0
  local currentRowPadding = 0
  local index = 0
  for _, l in ipairs(layouts) do
    if not l.moveOffscreen and l.type and l.type ~= "divider" then
      if l.row ~= inputRow then
        row = rowEnd + 1
        inputRow = l.row
        grid[row] = {}
        cols[row] = 1
        rowEnd = row
        currentRowPadding = 0
      end
      if l.type == "section" then
        for i = 1, 1 do
          grid[row][i] = l
        end
        index = index + 1
        cols[row] = 2
      elseif l.type == "category" then
        local categoryExtraRows = 0
        local lastCategoryRow = 1
        local offset = cols[row]
        local maxCol = 1
        for _, b in ipairs(l.buttons) do
          if b.position.y ~= lastCategoryRow then
            lastCategoryRow = lastCategoryRow + 1
            categoryExtraRows = categoryExtraRows + 1
            rowEnd = categoryExtraRows + row
            local newRow = row + categoryExtraRows
            grid[newRow] = grid[newRow] or {}
            cols[newRow] = offset
          end
          local currentRow = row + categoryExtraRows
          grid[currentRow][cols[currentRow]] = b
          cols[currentRow] = cols[currentRow] + 1
          maxCol = math.max(cols[currentRow], maxCol)
        end

        for r = row, rowEnd do
          cols[r] = maxCol
        end
      end
    end
  end

  addonTable.ItemViewCommon.LinkGamepadGrid(grid, rowEnd, math.max(unpack(cols)) - 1, upButton, bottomLeftButtons, bottomRightCallback)
end
