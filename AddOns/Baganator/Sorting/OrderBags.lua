local _, addonTable = ...

local function ConvertToOneList(bags, indexesToUse)
  -- Get one long list of the items involved
  local newBags = CopyTable(bags)
  local list = {}
  for bagIndex, bagContents in ipairs(newBags) do
    if indexesToUse[bagIndex] then
      for slotIndex, item in ipairs(bagContents) do
        item.from = { bagIndex = bagIndex, slot = slotIndex}
        table.insert(list, item)
      end
    end
  end

  return list
end

local function RemoveIgnoredSlotsFromOneList(list, bagIDs, bagChecks, isEnd, left)
  local offset = 0

  if isEnd then
    while left > 0 and #list > offset do
      local item = list[#list - offset]
      if bagChecks.checks[bagIDs[item.from.bagIndex]] then
        offset = offset + 1
      else
        table.remove(list, #list - offset)
        left = left - 1
      end
    end
  else
    while left > 0 and #list > offset do
      local item = list[1 + offset]
      if bagChecks.checks[bagIDs[item.from.bagIndex]] then
        offset = offset + 1
      else
        table.remove(list, 1 + offset)
        left = left - 1
      end
    end
  end
end

-- We keep an index so that the order is consistent after sort application and
-- resorting of the bag items.
local function SetIndexes(list, bagIDs)
  for index, item in ipairs(list) do
    if item.itemLink then
      local location = ItemLocation:CreateFromBagAndSlot(bagIDs[item.from.bagIndex], item.from.slot)
      item.index = C_Item.DoesItemExist(location) and C_Item.GetItemGUID(location) or "-1"
    end
  end
end

local function GetUsableBags(bagIDs, indexesToUse, bagChecks, isReverse)
  local sortedBagIndexes = {}
  -- Arrange bag ids order so the sort applies in the right order
  for i = 1, #bagIDs do
    table.insert(sortedBagIndexes, i)
  end

  table.sort(sortedBagIndexes, function(a, b)
    local aOrder = bagChecks.sortOrder[bagIDs[a]]
    local bOrder = bagChecks.sortOrder[bagIDs[b]]
    if aOrder == bOrder then
      if isReverse then
        return a > b
      else
        return a < b
      end
    else
      return aOrder < bOrder
    end
  end)

  local bagIDsAvailable = {}
  local bagSizes = {}

  for _, index in ipairs(sortedBagIndexes) do
    if indexesToUse[index] then
      local bagID = bagIDs[index]
      local size = C_Container.GetContainerNumSlots(bagID)
      if size > 0 then
        bagSizes[bagID] = size
        table.insert(bagIDsAvailable, bagID)
      end
    end
  end

  return bagIDsAvailable, bagSizes
end

local function GetPositionStores(bagIDsAvailable, bagSizes)
  local stores = {}
  for _, bagID in ipairs(bagIDsAvailable) do
    stores[bagID] = {first = 1, last = bagSizes[bagID]}
  end

  return stores
end

local function RemoveIgnoredSlotsFromStores(bagStores, bagSizes, bagChecks, bagIDsAvailable, isEnd, left)
  local regularBags = tFilter(bagIDsAvailable, function(bagID) return not bagChecks.checks[bagID] end, true)

  if isEnd then
    for index = #regularBags, 1, -1 do
      local bagID = regularBags[index]
      if bagSizes[bagID] > left then
        bagStores[bagID].last = bagStores[bagID].last - left
        left = 0
        break
      elseif bagSizes[bagID] == left then
        bagStores[bagID] = nil
        left = 0
        break
      else
        left = left - bagSizes[bagID]
        bagStores[bagID] = nil
      end
    end
  else
    for _, bagID in ipairs(regularBags) do
      if bagSizes[bagID] > left then
        bagStores[bagID].first = bagStores[bagID].first + left
        left = 0
        break
      elseif bagSizes[bagID] == left then
        bagStores[bagID] = nil
        left = 0
        break
      else
        left = left - bagSizes[bagID]
        bagStores[bagID] = nil
      end
    end
  end
end

local function QueueSwap(item, bagID, slotID, bagIDs, moveQueue0, moveQueue1)
  local target = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
  local fromBag, fromSlot = bagIDs[item.from.bagIndex], item.from.slot
  local source = ItemLocation:CreateFromBagAndSlot(fromBag, fromSlot)
  if fromBag ~= bagID or fromSlot ~= slotID then
    if C_Item.DoesItemExist(source) then
      if not C_Item.DoesItemExist(target) then
        table.insert(moveQueue0, {source, target, item.itemLink})
      else
        table.insert(moveQueue1, {source, target, item.itemLink})
      end
    end
  end
end

-- Runs one step of the sort into order operation. Returns a value indicating if
-- this needs to be run again on a later frame.
-- bags: Scanned bag contents
-- bagIDs: Corresponding bag IDs for the bag contents
-- indexesToUse: Select specific bags
-- bagChecks: Any special bag requirements for placing items in a specific bag
-- isReverse: Should the item order be reversed
-- ignoreAtEnd: Should the slots (if any) that are skipped for sorting be at the
-- end of the regular bags.
-- ignoreCount: Number of slots to ignore in the regular bag (start or end
-- depending on ignoreAtEnd)
function Baganator.Sorting.ApplyBagOrdering(bags, bagIDs, indexesToUse, bagChecks, isReverse, ignoreAtEnd, ignoreCount)
  if InCombatLockdown() then -- Sorting breaks during combat due to Blizzard restrictions
    return Baganator.Constants.SortStatus.Complete
  end

  if Syndicator.API.IsBagEventPending() then
    return Baganator.Constants.SortStatus.WaitingMove
  end

  if ignoreCount == nil then
    ignoreCount = 0
  end

  if Baganator.Config.Get(Baganator.Config.Options.SORT_START_AT_BOTTOM) then
    isReverse = not isReverse
  end

  local showTimers = Baganator.Config.Get(Baganator.Config.Options.DEBUG_TIMERS)
  local start = debugprofilestop()

  local bagIDsAvailable, bagSizes = GetUsableBags(bagIDs, indexesToUse, bagChecks, false)
  local bagIDsInverted = GetUsableBags(bagIDs, indexesToUse, bagChecks, true)

  local numBagsAffected = #bagIDsAvailable

  local oneList = ConvertToOneList(bags, indexesToUse)

  if ignoreCount > 0 then
    RemoveIgnoredSlotsFromOneList(oneList, bagIDs, bagChecks, ignoreAtEnd, ignoreCount)
  end

  Baganator.Sorting.AddSortKeys(oneList)

   -- Change the indexes as sorting into all the different bag types affects the
   -- final order
  SetIndexes(oneList, bagIDs)

  local sortedItems, incomplete = Baganator.Sorting.OrderOneListOffline(oneList)

  if showTimers then
    print("sort initial", debugprofilestop() - start)
    start = debugprofilestop()
  end

  local moveQueue0 = {}
  local moveQueue1 = {}

  local bagStores = GetPositionStores(bagIDsAvailable, bagSizes)

  if ignoreCount > 0 then
    RemoveIgnoredSlotsFromStores(bagStores, bagSizes, bagChecks, bagIDsAvailable, ignoreAtEnd, ignoreCount)

    bagIDsAvailable = tFilter(bagIDsAvailable, function(a) return bagStores[a] ~= nil end, true)
    bagIDsInverted = tFilter(bagIDsInverted, function(a) return bagStores[a] ~= nil end, true)
  end

  if showTimers then
    print("sort gens", debugprofilestop() - start)
    start = debugprofilestop()
  end

  -- Detect how few (if any) specialised bags an item can fit in. This is used
  -- to prioritise putting the item in the bags it can fit in over other items
  -- that can also fit, but that fit in other specialised bags too.
  for _, item in ipairs(sortedItems) do
    item.specialisedBags = 0
    for bagID, check in pairs(bagChecks.checks) do
      if check(item) then
        item.specialisedBags = item.specialisedBags + 1
      end
    end
  end

  -- Split junk items for placing them at the opposite end of the bags compared
  -- to the other items
  local junkPlugin = addonTable.JunkPlugins[Baganator.Config.Get("junk_plugin")]
  local groupA, groupB
  if junkPlugin then
    groupA, groupB = {}, {}
    for _, item in ipairs(sortedItems) do
      if junkPlugin.callback(bagIDs[item.from.bagIndex], item.from.slot, item.itemID, item.itemLink) then
        table.insert(groupB, item)
      else
        table.insert(groupA, item)
      end
    end
  else
    groupA = tFilter(sortedItems, function(item) return item.hasNoValue or item.quality ~= Enum.ItemQuality.Poor end, true)
    groupB = tFilter(sortedItems, function(item) return not item.hasNoValue and item.quality == Enum.ItemQuality.Poor end, true)
  end

  if isReverse then
    local tmp = groupA
    groupA = groupB
    groupB = tmp
  end

  if showTimers then
    print("reverse applied", debugprofilestop() - start)
    start = debugprofilestop()
  end

  -- For processing groupB
  local function SweepBackwards(group, specialsOnly)
    for index, item in ipairs(group) do
      for bagIndex, bagID in ipairs(bagIDsInverted) do
        if (not specialsOnly and not bagChecks.checks[bagID]) or (bagChecks.checks[bagID] and bagChecks.checks[bagID](item)) then
          item.processed = true
          local slot = bagStores[bagID].last
          QueueSwap(item, bagID, slot, bagIDs, moveQueue0, moveQueue1)
          bagStores[bagID].last = slot - 1
          if bagStores[bagID].first == slot then
            table.remove(bagIDsInverted, bagIndex)
          end
          break
        end
      end
    end
  end

  -- For processing groupA
  local function SweepForwards(group, specialsOnly)
    for index, item in ipairs(group) do
      for bagIndex, bagID in ipairs(bagIDsAvailable) do
        if (not specialsOnly and not bagChecks.checks[bagID]) or (bagChecks.checks[bagID] and bagChecks.checks[bagID](item)) then
          item.processed = true
          local slot = bagStores[bagID].first
          QueueSwap(item, bagID, slot, bagIDs, moveQueue0, moveQueue1)
          bagStores[bagID].first = slot + 1
          if bagStores[bagID].last == slot then
            table.remove(bagIDsAvailable, bagIndex)
          end
          break
        end
      end
    end
  end

  -- Prioritise special bags for items that can fit in them, placing items that
  -- fit in more specialised specialised bags in the most specialised location.
  for i = 1, numBagsAffected do
    local group = tFilter(groupB, function(item) return item.specialisedBags == i end, true)
    SweepBackwards(group, true)
  end

  SweepBackwards(tFilter(groupB, function(item) return not item.processed end, true), false)

  bagIDsAvailable = tFilter(bagIDsAvailable, function(bagID) return tIndexOf(bagIDsInverted, bagID) ~= nil end, true)

  -- See comment above
  for i = 1, numBagsAffected do
    local group = tFilter(groupA, function(item) return item.specialisedBags == i end, true)
    SweepForwards(group, true)
  end

  SweepForwards(tFilter(groupA, function(item) return not item.processed end, true))

  if showTimers then
    print("sort queues ready", debugprofilestop() - start)
    start = debugprofilestop()
  end

  local locked, moved = false, false

  -- Move items that have a blank slot as the target
  for _, move in ipairs(moveQueue0) do
    if not C_Item.IsLocked(move[1]) then
      C_Container.PickupContainerItem(move[1]:GetBagAndSlot())
      C_Container.PickupContainerItem(move[2]:GetBagAndSlot())
      ClearCursor()
      moved = true
    else
      locked = true
    end
  end

  -- Move items that will replace existing items
  for _, move in ipairs(moveQueue1) do
    if not C_Item.IsLocked(move[1]) and not C_Item.IsLocked(move[2]) then
      C_Container.PickupContainerItem(move[1]:GetBagAndSlot())
      C_Container.PickupContainerItem(move[2]:GetBagAndSlot())
      ClearCursor()
      moved = true
    else
      locked = true
    end
  end

  local pending
  if incomplete then
    pending = Baganator.Constants.SortStatus.WaitingItemData
  elseif moved then
    pending = Baganator.Constants.SortStatus.WaitingMove
  elseif locked then
    pending = Baganator.Constants.SortStatus.WaitingUnlock
  else
    pending = Baganator.Constants.SortStatus.Complete
  end

  if showTimers then
    print("sort items moved", debugprofilestop() - start)
  end

  return pending
end
