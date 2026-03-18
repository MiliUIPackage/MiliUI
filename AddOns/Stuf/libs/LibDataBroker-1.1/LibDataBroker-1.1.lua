assert(LibStub, "LibDataBroker-1.1 requires LibStub")

local lib, oldminor = LibStub:NewLibrary("LibDataBroker-1.1", 4)
if not lib then return end

local DataObjectMixin = {}

lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
lib.proxies = lib.proxies or {}
lib.domt = lib.domt or {
	__metatable = "LibDataBroker-1.1",
	__index = function(self, key)
		return rawget(DataObjectMixin, key)
	end,
}

function lib:NewDataObject(name, dataobj)
	if self.proxies[name] then return nil, "duplicate" end
	dataobj = dataobj or {}
	local proxy = setmetatable({}, lib.domt)
	for i, v in pairs(dataobj) do proxy[i] = v end
	self.proxies[name] = proxy
	self.callbacks:Fire("LibDataBroker_DataObjectCreated", name, proxy)
	return proxy
end

function lib:GetDataObjectByName(name)
	return self.proxies[name]
end

function lib:GetDataObjectForAddon(addonname)
	-- simple implementation: find the first proxy whose type suggests it's this addon's
	return self.proxies[addonname]
end

function lib:pairs()
	return pairs(self.proxies)
end
