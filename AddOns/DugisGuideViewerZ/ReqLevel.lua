local DGV = DugisGuideViewer
if not DGV then return end
local ReqLevel = DGV:RegisterModule("ReqLevel")
function ReqLevel:ShouldLoad()
	return DGV:UserSetting(DGV_ENABLEQUESTLEVELDB)
		and ((DGV.chardb.EssentialsMode<1 and DugisGuideViewer:GuideOn())
		or not DGV:UserSetting(DGV_UNLOADMODULES))
end
function ReqLevel:Initialize()
	function ReqLevel:Load()
		DGV.ReqLevel = {
		}
	end

	function ReqLevel:Unload()
		wipe(DGV.ReqLevel)
	end

	function ReqLevel:OnModulesLoaded()
		ReqLevel.Initialize = nil
		ReqLevel.Load = nil
		ReqLevel.initialized = false
	end
end
