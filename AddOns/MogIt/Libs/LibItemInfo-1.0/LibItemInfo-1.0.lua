local MAJOR, MINOR = "LibItemInfo-1.0", 6
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

local GetItemInfo = GetItemInfo
local type = type
local tonumber = tonumber
local strmatch = strmatch

lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)

lib.cache = lib.cache or {}
lib.queue = lib.queue or {}

setmetatable(lib, {__index = lib.cache})

local function onUpdate(self)
	for itemID in pairs(lib.queue) do
		if lib.cache[itemID] then
			-- lib.callbacks:Fire("OnItemInfoReceived", itemID)
			lib.queue[itemID] = nil
		end
	end
	lib.callbacks:Fire("OnItemInfoReceivedBatch")
	if not next(lib.queue) then
		self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
	end
	-- always hide after an update to prevent endless reattempting of items that for whatever reason never returns data
	self:Hide()
end

lib.frame = lib.frame or CreateFrame("Frame")
lib.frame:SetScript("OnEvent", lib.frame.Show)
lib.frame:SetScript("OnUpdate", onUpdate)
lib.frame:Hide()

setmetatable(lib.cache, {
	__index = function(self, item)
		local itemID = item
		if type(item) == "string" then
			itemID = strmatch(item, "item:(%d+)")
			if not itemID then return end
			itemID = tonumber(itemID)
		end
		local name, link, quality, itemLevel, reqLevel, class, subClass, maxStack, equipSlot, icon, sellPrice, classID, subClassID, bindType, expansion, itemSetID, isReagent = GetItemInfo(item)
		if not name then
			lib.queue[itemID] = true
			lib.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
			return
		end
		if type(item) == "string" then
			local baseItem = self[itemID]
			-- apparently cases exist where a query using the item ID won't return any results even though a query with full link did immediately before
			if not baseItem then return end
			-- if the properties are equal to that of the base item, just point this entry at that
			if quality == baseItem.quality and itemLevel == baseItem.itemLevel then
				self[item] = baseItem
				return baseItem
			end
		end
		local itemInfo = {
			name = name,
			quality = quality,
			itemLevel = itemLevel,
			reqLevel = reqLevel,
			type = class,
			subType = subClass,
			invType = equipSlot,
			stackSize = maxStack,
			bindType = bindType,
		}
		self[item] = itemInfo
		return itemInfo
	end,
})

