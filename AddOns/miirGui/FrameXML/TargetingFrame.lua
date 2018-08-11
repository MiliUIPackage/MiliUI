local function skin_TargetingFrame()
	PlayerLevelText:SetPoint("CENTER", PlayerFrameTexture, "CENTER", -62, -15);

	local function miirgui_TargetFrame_CheckClassification(self, forceNormalTexture)
		local classification = UnitClassification(self.unit);
		m_SetTexture(self.threatIndicator,"Interface\\TargetingFrame\\UI-TargetingFrame-Flash")
		if ( forceNormalTexture ) then
			self.haveElite = nil;
			if ( classification == "minus" ) then
				self.Background:SetSize(119,12);
				self.Background:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 7, 47);
				else
				self.Background:SetSize(119,25);
				self.Background:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 7, 35);
			end
			if ( self.threatIndicator ) then
				if ( classification == "minus" ) then
					m_SetTexture(self.threatIndicator,"Interface\\TargetingFrame\\UI-TargetingFrame-Minus-Flash")
					self.threatIndicator:SetTexCoord(0, 1, 0, 1);
					self.threatIndicator:SetWidth(256);
					self.threatIndicator:SetHeight(128);
					self.threatIndicator:SetPoint("TOPLEFT", self, "TOPLEFT", -23, 0);
				else
					self.threatIndicator:SetTexCoord(0, 0.9453125, 0, 0.181640625);
					self.threatIndicator:SetWidth(242);
					self.threatIndicator:SetHeight(93);
					self.threatIndicator:SetPoint("TOPLEFT", self, "TOPLEFT", -23, 0);
				end
			end
		else
			self.haveElite = true;
			TargetFrameBackground:SetSize(119,41);
			if ( self.threatIndicator ) then
				self.threatIndicator:SetTexCoord(0, 0.9453125, 0, 0.181640625);
				self.threatIndicator:SetWidth(242);
				self.threatIndicator:SetHeight(93);
				self.threatIndicator:SetPoint("TOPLEFT", self, "TOPLEFT", -23, 0);
			end
		end
	end

	hooksecurefunc("TargetFrame_CheckClassification",miirgui_TargetFrame_CheckClassification)

	local function miirgui_TargetFrame_UpdateLevelTextAnchor(self, targetLevel)
		if ( targetLevel >= 100 ) then
			self.levelText:SetPoint("CENTER", 62, -15);
		else
			self.levelText:SetPoint("CENTER", 62, -15);
		end
	end

	hooksecurefunc("TargetFrame_UpdateLevelTextAnchor",miirgui_TargetFrame_UpdateLevelTextAnchor)

	local function miirgui_PlayerFrame_UpdateLevelTextAnchor(level)
		if ( level >= 100 ) then
			PlayerLevelText:SetPoint("CENTER", PlayerFrameTexture, "CENTER", -62, -15);
		else
			PlayerLevelText:SetPoint("CENTER", PlayerFrameTexture, "CENTER", -62, -15);
		end
	end

	hooksecurefunc("PlayerFrame_UpdateLevelTextAnchor",miirgui_PlayerFrame_UpdateLevelTextAnchor)

	local function miirgui_TargetFrame_CheckFaction(self)
		self.pvpIcon:ClearAllPoints()
		self.pvpIcon:SetPoint("CENTER", 81, -2);
	end

	hooksecurefunc("TargetFrame_CheckFaction",miirgui_TargetFrame_CheckFaction)

end

local m_catch = CreateFrame("Frame")
m_catch:RegisterEvent("PLAYER_LOGIN")
m_catch:SetScript("OnEvent", skin_TargetingFrame)