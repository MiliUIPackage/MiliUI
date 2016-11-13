		local f = CreateFrame("Frame")
		f:RegisterEvent("PLAYER_LOGIN")
		f:SetScript("OnEvent", function()		

		local background
		local button_normal
		local button_hover
		
		if miirguiDB.blue == true then
			background = "Interface\\Addons\\miirgui\\gfx\\rolls\\background_b"
			button_normal = "Interface\\Addons\\miirgui\\gfx\\rolls\\button_normal_b"
			button_hover = "Interface\\Addons\\miirgui\\gfx\\rolls\\buttonhover_b"
		elseif miirguiDB.grey == true then
			background = "Interface\\Addons\\miirgui\\gfx\\rolls\\background_g"
			button_normal = "Interface\\Addons\\miirgui\\gfx\\rolls\\button_normal_g"
			button_hover = "Interface\\Addons\\miirgui\\gfx\\rolls\\buttonhover_g"
		elseif miirguiDB.green == true then
			background = "Interface\\Addons\\miirgui\\gfx\\rolls\\background_g2"
			button_normal = "Interface\\Addons\\miirgui\\gfx\\rolls\\button_normal_g2"
			button_hover = "Interface\\Addons\\miirgui\\gfx\\rolls\\buttonhover_g2"
		end				
		
		-- handle the positioning of the Rollbars
		
		local function miirgui_GroupLootContainer_Update(self)
			for i=1, self.maxIndex do
					GroupLootContainer:SetHeight(i*40)
					local frame = self.rollFrames[i];
					if ( frame ) then
						frame:ClearAllPoints();
						frame:SetPoint("BOTTOM",AlertFrame,0,0+i*40)
					end
				end
		end

		-- skin the rollbars
		
		local function miirgui_GroupLootFrame_OpenNewFrame()
			for i=1, NUM_GROUP_LOOT_FRAMES do
				local frame = _G["GroupLootFrame"..i];
				frame.Background:Hide()
				frame.Border:Hide()			
				--Loot Drop Name
				frame.Name:ClearAllPoints()
				frame.Name:SetPoint("Left",frame.Timer)
				frame.Name:SetPoint("Right",frame.Timer)
				frame.Name:SetWordWrap(false)			
				--Loot Drop Icon
				frame.IconFrame:ClearAllPoints()
				frame.IconFrame:SetPoint("BOTTOMLEFT",frame.Timer,-40.5,-2);
				frame.IconFrame.Border:SetTexCoord(0,1,0,1)
				m_SetTexture(frame.IconFrame.Border,"Interface\\Addons\\miirgui\\gfx\\lootborder")
				frame.IconFrame.Border:SetPoint("CENTER",frame.IconFrame.Icon,0,0);
				frame.IconFrame.Border:SetSize(64,64)
				frame.IconFrame.Border:SetVertexColor(frame.Border:GetVertexColor())
				--Loot Drop Timer Bar
				frame.Timer:SetSize(248,12)	
				frame.Timer.Bar:SetVertexColor(1,1,1,1)
				m_SetTexture(frame.Timer.Bar,"Interface\\Addons\\miirgui\\gfx\\rolls\\bar")
				frame.Timer.Background:ClearAllPoints()
				frame.Timer.Background:SetPoint("CENTER",frame.Timer,-0.5,0)
				m_SetTexture(frame.Timer.Background,background)
				frame.Timer.Background:SetSize(256,64)
				--Pass Button
				frame.PassButton:ClearAllPoints()
				frame.PassButton:SetPoint("CENTER",frame.Timer)
				frame.PassButton:SetSize(256,14)
				frame.PassButton:SetAlpha(0)
				frame.PassButton:RegisterForClicks("AnyDown","AnyUp");
				frame.PassButton:SetScript("OnClick",frame.IconFrame:GetScript("OnClick"))
				frame.PassButton:SetScript("OnEnter",frame.IconFrame:GetScript("OnEnter"))
				frame.PassButton:EnableKeyboard(true)
				frame.PassButton:SetPropagateKeyboardInput(true)
				frame.PassButton:SetScript("OnKeyUp",function(_,key)	
					if key == "LCTRL" then	
						SetCursor(NORMAL_CURSOR)
					end
				end)	
				frame.PassButton:SetScript("OnKeyDown",function(self, key)
					self:SetPropagateKeyboardInput(key~="LCTRL")
					if key == "LCTRL" then
						SetCursor("INSPECT_CURSOR")
					end
				end)
				frame.PassButton:HookScript("OnClick",function(self,button)
				if button == "RightButton" then
					RollOnLoot(self:GetParent().rollID, 0)
				end
				end)	
				--Need Button
				frame.NeedButton:SetSize(64,64)
				frame.NeedButton:SetNormalTexture(button_normal);
				frame.NeedButton:SetHighlightTexture(button_hover);
				frame.NeedButton:SetPushedTexture(button_hover);
				--frame.NeedButton:SetAlpha(1)
				frame.NeedButton:ClearAllPoints()
				frame.NeedButton:SetPoint("TOPLEFT",frame.Timer,"Right",0.5,32);	
				--Greed Button
				frame.GreedButton:SetSize(64,64)
				frame.GreedButton:SetNormalTexture(button_normal);
				frame.GreedButton:SetHighlightTexture(button_hover);
				frame.GreedButton:SetPushedTexture(button_hover);
				frame.GreedButton:ClearAllPoints()
				frame.GreedButton:SetPoint("LEFT",frame.NeedButton,"RIGHT",-16,0);
				--Dissenchant Button
				frame.DisenchantButton:SetSize(64,64)
				frame.DisenchantButton:SetNormalTexture(button_normal);
				frame.DisenchantButton:SetHighlightTexture(button_hover);
				frame.DisenchantButton:SetPushedTexture(button_hover);
				frame.DisenchantButton:ClearAllPoints()
				frame.DisenchantButton:SetPoint("LEFT",frame.GreedButton,"RIGHT",-16,0);
			end
		end
			
		-- skin the bonus rolls bars
		
		local function miirgui_BonusRollFrame_StartBonusRoll()
			local frame = BonusRollFrame;
			frame:ClearAllPoints();
			frame:SetPoint("CENTER",AlertFrame,0,0)
			local specID = GetLootSpecialization();
			if ( specID and specID > 0 ) then
				frame.SpecIcon:ClearAllPoints()
				frame.SpecIcon:SetPoint("BOTTOMLEFT",frame.PromptFrame.Timer,-31,-1);
				frame.SpecRing:ClearAllPoints()
				frame.SpecRing:SetPoint("BOTTOMLEFT",frame.PromptFrame.Timer,-38,-34);
			end

			frame.Background:Hide()	
			--Modify the different fontstrings
			frame.PromptFrame.InfoFrame.Cost:ClearAllPoints()
			frame.PromptFrame.InfoFrame.Cost:SetPoint("LEFT",frame.PromptFrame.Timer,0,18);
			m_fontify(frame.PromptFrame.InfoFrame.Cost,"white")
			frame.CurrentCountFrame.Text:ClearAllPoints()
			frame.CurrentCountFrame.Text:SetPoint("RIGHT",frame.PromptFrame.Timer,0,18);
			m_fontify(frame.CurrentCountFrame.Text,"white")
			
			frame.PromptFrame.InfoFrame.Label:ClearAllPoints()
			frame.PromptFrame.InfoFrame.Label:SetPoint("CENTER",frame.PromptFrame.Timer,0,1);
			m_fontify(frame.PromptFrame.InfoFrame.Label,"white",12)
				
			--Currency Icon
			BonusRollFrame.IconBorder:Hide()
			frame.PromptFrame.Icon:Hide()
			--Timer
			frame.PromptFrame.Timer:SetSize(248,12)	
			m_SetTexture(frame.PromptFrame.Timer.Bar,"Interface\\Addons\\miirgui\\gfx\\rolls\\bar")
			frame.PromptFrame.Timer.Bar:SetVertexColor(1,1,1,1)			
			frame.BlackBackgroundHoist.Background:ClearAllPoints()
			frame.BlackBackgroundHoist.Background:SetPoint("CENTER",frame.PromptFrame.Timer)
			m_SetTexture(frame.BlackBackgroundHoist.Background,background)
			frame.BlackBackgroundHoist.Background:SetSize(256,64)		
			--Need Button
			frame.PromptFrame.RollButton:SetNormalTexture(button_normal)
			frame.PromptFrame.RollButton:SetHighlightTexture(button_hover)
			frame.PromptFrame.RollButton:SetPushedTexture(button_hover)
			frame.PromptFrame.RollButton:SetSize(64,64)
			frame.PromptFrame.RollButton:ClearAllPoints()
			frame.PromptFrame.RollButton:SetPoint("TOPLEFT",frame.PromptFrame.Timer,"Right",0,32);	
			--Pass Button
			frame.PromptFrame.PassButton:SetNormalTexture(button_normal)
			frame.PromptFrame.PassButton:SetHighlightTexture(button_hover)
			frame.PromptFrame.PassButton:SetPushedTexture(button_hover)
			frame.PromptFrame.PassButton:SetSize(64,64)
			frame.PromptFrame.PassButton:ClearAllPoints()
			frame.PromptFrame.PassButton:SetPoint("LEFT",frame.PromptFrame.RollButton,"RIGHT",-16,0);
			--Get Rid of animations
			frame.RollingFrame.LootSpinner:Hide();
			frame.RollingFrame.LootSpinner:SetAlpha(0)
			frame.RollingFrame.LootSpinnerFinal:Hide();
			frame.RollingFrame.LootSpinnerFinal:SetAlpha(0)
			frame.RollingFrame.LootSpinnerFinalText:Hide()
			frame.RollingFrame.LootSpinnerFinalText:SetAlpha(0)
			frame.RollingFrame.DieIcon:Hide()
			frame.RollingFrame.DieIcon:SetAlpha(0)
			frame.WhiteFade:Hide()
			frame.WhiteFade:SetAlpha(0)		
		end
				
		-- bonus roll bar spec icon update
		
		local function miirgui_specIon(self, event)
			if ( event == "PLAYER_LOOT_SPEC_UPDATED" ) then
				local specID = GetLootSpecialization();
				if ( specID and specID > 0 ) then
					self.SpecIcon:ClearAllPoints()
					self.SpecIcon:SetPoint("BOTTOMLEFT",self.PromptFrame.Timer,-31,-1);
					self.SpecRing:ClearAllPoints()
					self.SpecRing:SetPoint("BOTTOMLEFT",self.PromptFrame.Timer,-38,-34);
				end
			elseif ( event == "BONUS_ROLL_STARTED" ) then
				self.CurrentCountFrame.Text:Hide()
				self.CurrentCountFrame.Text:SetAlpha(0)
				if ( self.rollSound ) then
					StopSound(self.rollSound);
				end
			elseif ( event == "BONUS_ROLL_RESULT" ) then
				if ( self.rollSound ) then
					StopSound(self.rollSound);
				end		
			end
		end
		
		if miirguiDB.rolls == true then
			hooksecurefunc("GroupLootContainer_Update",miirgui_GroupLootContainer_Update)
			hooksecurefunc("GroupLootFrame_OpenNewFrame",miirgui_GroupLootFrame_OpenNewFrame)
			hooksecurefunc("BonusRollFrame_StartBonusRoll",miirgui_BonusRollFrame_StartBonusRoll)
			BonusRollFrame:HookScript("OnEvent", miirgui_specIon)
		end		
			
		end) 