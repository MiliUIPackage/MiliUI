-------------------------
-- Stagger, by Siweia
-------------------------
local _, ns = ...
local cfg = ns.cfg
if cfg.MyClass ~= "MONK" then return end
local cr, cg, cb = cfg.cc.r, cfg.cc.g, cfg.cc.b

-- APIs
local CreateBD = function(f, a, s)
	f:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = cfg.glowTex, edgeSize = s or 3,
		insets = {left = s or 3, right = s or 3, top = s or 3, bottom = s or 3},
	})
	f:SetBackdropColor(0, 0, 0, a or .5)
	f:SetBackdropBorderColor(0, 0, 0)
end

local CreateSD = function(f, m, s, n)
	if f.Shadow then return end
	f.Shadow = CreateFrame("Frame", nil, f)
	f.Shadow:SetPoint("TOPLEFT", f, -m, m)
	f.Shadow:SetPoint("BOTTOMRIGHT", f, m, -m)
	f.Shadow:SetBackdrop({
		edgeFile = cfg.glowTex, edgeSize = s })
	f.Shadow:SetBackdropBorderColor(0, 0, 0, 1)
	f.Shadow:SetFrameLevel(n or f:GetFrameLevel())
	return f.Shadow
end

local CreateIF = function(f)
	CreateSD(f, 3, 3)
	f.Icon = f:CreateTexture(nil, "ARTWORK")
	f.Icon:SetAllPoints()
	f.Icon:SetTexCoord(unpack(cfg.TexCoord))
	f.CD = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
	f.CD:SetAllPoints()
	f.CD:SetReverse(true)
end

local CreateSB = function(f, spark)
	f:SetStatusBarTexture(cfg.normTex)
	f:SetStatusBarColor(cr, cg, cb)
	CreateSD(f, 3, 3)
	f.BG = f:CreateTexture(nil, "BACKGROUND")
	f.BG:SetAllPoints()
	f.BG:SetTexture(cfg.normTex)
	f.BG:SetVertexColor(cr, cg, cb, .2)
	if spark then
		f.Spark = f:CreateTexture(nil, "OVERLAY")
		f.Spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
		f.Spark:SetBlendMode("ADD")
		f.Spark:SetAlpha(.8)
		f.Spark:SetPoint("TOPLEFT", f:GetStatusBarTexture(), "TOPRIGHT", -10, 10)
		f.Spark:SetPoint("BOTTOMRIGHT", f:GetStatusBarTexture(), "BOTTOMRIGHT", 10, -10)
	end
end

local SetMover = function(Frame, Text, key, Pos, w, h)
	if not MoverDB[key] then MoverDB[key] = {} end
	local Mover = CreateFrame("Frame", nil, UIParent)
	Mover:SetWidth(w or Frame:GetWidth())
	Mover:SetHeight(h or Frame:GetHeight())
	CreateBD(Mover)
	Mover.Text = Mover:CreateFontString(nil, "OVERLAY")
	Mover.Text:SetFont(unpack(cfg.Font))
	Mover.Text:SetPoint("CENTER")
	Mover.Text:SetText(Text)
	if not MoverDB[key]["Mover"] then 
		Mover:SetPoint(unpack(Pos))
	else
		Mover:SetPoint(unpack(MoverDB[key]["Mover"]))
	end
	Mover:EnableMouse(true)
	Mover:SetMovable(true)
	Mover:SetClampedToScreen(true)
	Mover:SetFrameStrata("HIGH")
	Mover:RegisterForDrag("LeftButton")
	Mover:SetScript("OnDragStart", function(self) Mover:StartMoving() end)
	Mover:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local AnchorF, _, AnchorT, X, Y = self:GetPoint()
		MoverDB[key]["Mover"] = {AnchorF, "UIParent", AnchorT, X, Y}
	end)
	Mover:Hide()
	Frame:SetPoint("TOPLEFT", Mover)
	return Mover
end

local Numb = function(n)
	if (n >= 1e6) then
		return ("%.1fm"):format(n / 1e6)
	elseif (n >= 1e3) then
		return ("%.1fk"):format(n / 1e3)
	else
		return ("%.0f"):format(n)
	end
end

local CreateFS = function(f, size, text, classcolor, anchor, x, y)
	local fs = f:CreateFontString(nil, "OVERLAY")
	fs:SetFont(cfg.Font[1], size, cfg.Font[3])
	fs:SetText(text)
	fs:SetWordWrap(false)
	if classcolor then
		fs:SetTextColor(cr, cg, cb)
	end
	if (anchor and x and y) then
		fs:SetPoint(anchor, x, y)
	else
		fs:SetPoint("CENTER", 1, 0)
	end
	return fs
end

-- Style
local IconSize = cfg.IconSize
local bu, bar = {}
local function StaggerGo()
	if bar then bar:Show() return end

	bar = CreateFrame("StatusBar", "NDui_Stagger", UIParent)
	bar:SetSize(IconSize*4 + 15, cfg.BarHeight)
	bar:SetPoint("CENTER", 0, -200)
	bar:SetFrameStrata("HIGH")
	CreateSB(bar, true)
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)
	bar.Count = CreateFS(bar, 16, "", false, "TOPRIGHT", 0, -7)

	local spells = {115069, 115072, 115308, 124275}
	for i = 1, 4 do
		bu[i] = CreateFrame("Frame", nil, UIParent)
		bu[i]:SetSize(IconSize, IconSize)
		bu[i]:SetFrameStrata("HIGH")
		CreateIF(bu[i])
		bu[i].Icon:SetTexture(GetSpellTexture(spells[i]))
		bu[i].Count = CreateFS(bu[i], 16, "")
		bu[i].Count:SetPoint("BOTTOMRIGHT", 4, -2)
		if i == 1 then
			bu[i]:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 5)
		else
			bu[i]:SetPoint("LEFT", bu[i-1], "RIGHT", 5, 0)
		end
	end
	bu[1].Count:SetAllPoints()

	local Mover = SetMover(bar, NPE_MOVE, "Stagger", cfg.StaggerPos, bar:GetWidth(), 20)
	SlashCmdList["STAGGER"] = function(msg)
		if InCombatLockdown() then return end
		if msg:lower() == "reset" then
			wipe(MoverDB["Stagger"])
			ReloadUI()
		else
			if Mover:IsVisible() then
				Mover:Hide()
			else
				Mover:Show()
			end
		end
	end
	SLASH_STAGGER1 = "/stg"
end

local function lookingForAura(spell, filter)
	for index = 1, 32 do
		local name, texture, _, _, dur, exp, _, _, _, spellID = UnitAura("player", index, filter)
		if name and spellID == spell then
			return name, dur, exp, texture
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_TALENT_UPDATE")
f:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" or event == "PLAYER_TALENT_UPDATE" then
		if GetSpecializationInfo(GetSpecialization()) == 268 then
			StaggerGo()
			bar:SetAlpha(cfg.FadeAlpha)
			for i = 1, 4 do
				bu[i]:Show()
				bu[i]:SetAlpha(cfg.FadeAlpha)
			end

			f:RegisterUnitEvent("UNIT_AURA", "player")
			f:RegisterEvent("UNIT_MAXHEALTH")
			f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
			f:RegisterEvent("SPELL_UPDATE_CHARGES")
		else
			if bar then bar:Hide() end
			for i = 1, 4 do
				if bu[i] then bu[i]:Hide() end
			end

			f:UnregisterEvent("UNIT_AURA")
			f:UnregisterEvent("UNIT_MAXHEALTH")
			f:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
			f:UnregisterEvent("SPELL_UPDATE_CHARGES")
		end
	else
		-- Stagger percentage
		local stagger, staggerAgainstTarget = C_PaperDollInfo.GetStaggerPercentage("player")
		local amount = staggerAgainstTarget or stagger
		if amount > 0 then
			bu[1].Count:SetText(floor(amount))
			bu[1]:SetAlpha(1)
		else
			bu[1].Count:SetText("")
			bu[1]:SetAlpha(.5)
		end

		-- Expel Harm
		do
			local count = GetSpellCount(115072)
			bu[2].Count:SetText(count)
			if count > 0 then
				bu[2]:SetAlpha(1)
			else
				bu[2]:SetAlpha(cfg.FadeAlpha)
			end
		end

		-- Ironskin Brew
		do
			local name, dur, exp = lookingForAura(215479, "HELPFUL")
			local charges, maxCharges, chargeStart, chargeDuration = GetSpellCharges(115308)
			local start, duration = GetSpellCooldown(115308)
			bu[3].Count:SetText(charges)
			if name then
				bu[3].Count:ClearAllPoints()
				bu[3].Count:SetPoint("TOP", 0, 18)
				bu[3]:SetAlpha(1)
				ClearChargeCooldown(bu[3])
				bu[3].CD:SetReverse(true)
				bu[3].CD:SetCooldown(exp - dur, dur)
				ActionButton_ShowOverlayGlow(bu[3])
			else
				bu[3].Count:ClearAllPoints()
				bu[3].Count:SetPoint("BOTTOMRIGHT", 4, -2)
				bu[3].CD:SetReverse(false)
				if charges < maxCharges and charges > 0 then
					StartChargeCooldown(bu[3], chargeStart, chargeDuration)
					bu[3].CD:SetCooldown(0, 0)
				elseif start and duration > 1.5 then
					ClearChargeCooldown(bu[3])
					bu[3].CD:SetCooldown(start, duration)
				elseif charges == maxCharges then
					bu[3]:SetAlpha(cfg.FadeAlpha)
					ClearChargeCooldown(bu[3])
					bu[3].CD:SetCooldown(0, 0)
				end
				ActionButton_HideOverlayGlow(bu[3])
			end
		end

		-- Stagger
		do
			local cur = UnitStagger("player") or 0
			local max = UnitHealthMax("player")
			local perc = cur / max
			local name, dur, exp, texture = lookingForAura(124275, "HARMFUL")
			if not name then name, dur, exp, texture = lookingForAura(124274, "HARMFUL") end
			if not name then name, dur, exp, texture = lookingForAura(124273, "HARMFUL") end

			if name and cur > 0 and dur > 0 then
				bar:SetAlpha(1)
				bu[4]:SetAlpha(1)
				bu[4].CD:SetCooldown(exp - dur, dur)
				bu[4].CD:Show()
			else
				bar:SetAlpha(.5)
				bu[4]:SetAlpha(.5)
				bu[4].CD:Hide()
			end
			bar:SetValue(perc * 100)
			bar.Count:SetText(cfg.InfoColor..Numb(cur).." "..cfg.MyColor..Numb(perc * 100).."%")
			bu[4].Icon:SetTexture(texture or 463281)

			if bu[4].Icon:GetTexture() == GetSpellTexture(124273) then
				ActionButton_ShowOverlayGlow(bu[4])
			else
				ActionButton_HideOverlayGlow(bu[4])
			end
		end
	end

	if not InCombatLockdown() then
		if bar then bar:SetAlpha(cfg.OOCAlpha) end
		for i = 1, 4 do
			if bu[i] then bu[i]:SetAlpha(cfg.OOCAlpha) end
		end
	end
end)