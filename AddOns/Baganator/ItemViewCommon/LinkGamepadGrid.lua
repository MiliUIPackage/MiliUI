---@class addonTableBaganator
local addonTable = select(2, ...)

function addonTable.ItemViewCommon.LinkGamepadGrid(grid, row, maxCols, upButton, bottomLeftButtons, bottomRightCallback)
  for y = 1, row do
    for x = 1, maxCols do
      if grid[y][x] then
        if grid[y+1] and grid[y+1][x] then
          addonTable.Gamepad.LinkButtons(grid[y][x], "Down", grid[y+1][x])
        elseif y == row then
          if bottomLeftButtons[x] then
            addonTable.Gamepad.LinkButtons(grid[y][x], "Down", bottomLeftButtons[x])
          elseif bottomRightCallback then
            bottomRightCallback(grid[y][x])
          end
        else
          local found = false
          for y2 = y + 1, row do
            if grid[y2][x] then
              found = true
              addonTable.Gamepad.LinkButtons(grid[y][x], "Down", grid[y2][x])
              break
            end
          end
          if not found then
            if bottomLeftButtons[x] then
              addonTable.Gamepad.LinkButtons(grid[y][x], "Down", bottomLeftButtons[x])
            elseif bottomRightCallback then
              bottomRightCallback(grid[y][x])
            end
          end
        end
        if y == 1 then
          addonTable.Gamepad.OneWayLink(grid[y][x], "Up", upButton)
        elseif grid[y-1][x] == nil then
          local found = false
          for y2 = 1, y - 1 do
            if grid[y][y2] then
              found = true
              addonTable.Gamepad.LinkButtons(grid[y][x], "Right", grid[y][y2])
              break
            end
          end
          if not found then
            addonTable.Gamepad.OneWayLink(grid[y][x], "Up", upButton)
          end
        end
        if grid[y][x+1] then
          addonTable.Gamepad.LinkButtons(grid[y][x], "Right", grid[y][x+1])
        elseif x > 1 then
          for x2 = 1, x - 1 do
            if grid[y][x2] then
              addonTable.Gamepad.LinkButtons(grid[y][x], "Right", grid[y][x2])
              break
            end
          end
        end
      end
    end
  end

  for x = 1, maxCols do
    if grid[1][x] then
      addonTable.Gamepad.LinkButtons(grid[1][x], "Up", upButton)
      break
    end
  end
end
