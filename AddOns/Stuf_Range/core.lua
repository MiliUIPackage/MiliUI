local Stuf = Stuf
if not Stuf then return end

local function module()
local su = Stuf.units

local RC = LibStub:GetLibrary("LibRangeCheck-2.0", true)
if not RC then return end

local a = CreateFrame("Frame", "Stuf_RangeCheck", Stuf)
local self = a
local sdb


local function UpdateRangeText(unit, uf, f, a4, a5, config)
	uf = uf or su[unit]
	f = f or (uf and not uf.hidden and uf.rangetext)
	if not f or f.db.hide then return end
	if config then
		f.fontstring:SetText("30~36")
		f:Show()
	else
		local low, high = RC:getRange(unit)
		if low or high then
			f.fontstring:SetFormattedText("%d~%d", low or 0, high or 100)
			f:Show()
		else
			f:Hide()
		end
	end
end
local function CreateRangeText(unit, uf, name, db, a5, config)
	local f = uf[name]
	if db.hide then
		if f then f:Hide() end
		return
	end
	if not f then
		f = Stuf:CreateBase(unit, uf, name, db)
		f.fontstring = f:CreateFontString(nil, "ARTWORK")
		f.fontstring:SetAllPoints()
		f.p = uf
		f:Hide()
		
		uf.refreshfuncs[name] = UpdateRangeText
		Stuf:RegisterElementRefresh(uf, name, "metroelements", true)
	end
	
	Stuf:UpdateBaseLook(uf, f, db)
	f:SetFrameLevel(db.framelevel or 4)
	
	local t = f.fontstring
	t:SetFont(Stuf:GetMedia("font", db.font), db.fontsize or 10, db.fontflags ~= "None" and db.fontflags)

	local c = db.fontcolor or Stuf.whitecolor
	local sc = sdb.global.shadowcolor or Stuf.hidecolor
	t:SetTextColor(c.r, c.g, c.b, c.a)
	t:SetShadowColor(sc.r, sc.g, sc.b, sc.a)
	t:SetShadowOffset(db.shadowx or 0, db.shadowy or 0)
	t:SetJustifyH(db.justifyH or "CENTER")
	t:SetJustifyV(db.justifyV or "CENTER")
	
	UpdateRangeText(unit, uf, f, nil, nil, config)
end
Stuf:AddBuilder("rangetext", CreateRangeText)
sdb = (StufDB == "perchar" and StufCharDB) or StufDB
local function SetUnitDefault(unit, hide, x, y, fs, justifyH)
	local uf, dbu = su[unit], sdb[unit]
	dbu.rangetext = dbu.rangetext or { hide=hide, x=x, y=y, w=dbu.frame.w/2, h=fs, fontsize=fs, justifyH=justifyH, }
	if uf and not uf.rangetext then
		CreateRangeText(unit, uf, "rangetext", dbu.rangetext)
	end
end
SetUnitDefault("target", nil, 0, 10, 10, "CENTER")
SetUnitDefault("focus", nil, 0, 10, 10, "CENTER")
SetUnitDefault = nil
local function OnOptions()
	local o, textoptions = Stuf:GetOptionsTable()
	local rco = { name="距離文字", type="group", args=textoptions, order=50, }
	o.args.target.args.rangetext = rco
	o.args.focus.args.rangetext = rco
	a:UnregisterEvent("ADDON_LOADED")
end
if Stuf.GetOptionsTable then
	OnOptions()
	OnOptions = nil
else
	a:RegisterEvent("ADDON_LOADED")
	a:SetScript("OnEvent", function(this, event, a1)
		if a1 == "Stuf_Options" then
			OnOptions()
			OnOptions = nil
		end
	end)
end

end -- end function module

if Stuf.modules then
	tinsert(Stuf.modules, module)
else
	module()
end
