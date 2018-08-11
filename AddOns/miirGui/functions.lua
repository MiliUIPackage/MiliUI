local function miirgui_functions()

	-- Icon function

		function m_icon(arg1, arg2, arg3, arg4, arg5)
			local f = CreateFrame("Frame",nil,arg1)
			f:SetFrameStrata(arg5)
			f:SetSize(64,64)
			local t = f:CreateTexture("MiirGui Icon","BACKGROUND")
			t:SetTexture("Interface\\AddOns\\miirGui\\gfx\\"..arg2)
			t:SetAllPoints(f)
			f.texture = t
			f:SetPoint("TOPLEFT",arg3,arg4)
			f:Show()
		end

		-- Border Function

		function m_border(arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8)
			local FrameName
			if arg1:GetName() and _G["m_border_"..arg1:GetName()] then
				--print(arg1:GetName().." already exists")
			else
				if arg1:GetName() then
					 FrameName = "m_border_"..arg1:GetName()
				else
					FrameName = "border_has_no_name"
				end
				local Border = CreateFrame("Frame", FrameName or "border_has_no_name", arg1)
				Border:SetSize(arg2, arg3)
				Border:SetPoint(arg4,arg5,arg6)
				Border:SetBackdrop({
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border_blue.blp",
				edgeSize = arg7})
				Border:SetBackdropBorderColor(1, 1, 1)
				Border:SetFrameStrata(arg8)
			end
		end

		function m_cursorfix(arg1)
			if miirguiDB["outline"] == true then
				arg1:HookScript("OnCursorChanged",function(self)
					local kids = { self:GetRegions() }
					local point, relativeTo, relativePoint, xOfs, yOfs = kids[2]:GetPoint()
					if xOfs == kids[1]:GetStringWidth() then
						local offset = floor((kids[1]:GetStringHeight()/3.5)+0.5)
						kids[2]:SetPoint(point, relativeTo, relativePoint, kids[1]:GetStringWidth()-offset, yOfs)
					end
				end)
			end
		end

		-- Font Coloring Function

		function m_fontify(arg1,arg2)
			-- arg 1 is the stringname, arg2 is the color
			if miirguiDB["outline"] == true then
				arg1:SetShadowOffset(0,0)
				arg1:SetShadowColor(0,0,0,0)
			end
			if arg2 == "color" then
				arg1:SetTextColor(miirguiDB.color.r,miirguiDB.color.g,miirguiDB.color.b,1)
			elseif arg2 == "highlight" then
				arg1:SetTextColor(miirguiDB.color.hr,miirguiDB.color.hg,miirguiDB.color.hb,1)
			elseif arg2 == "white" then
				arg1:SetTextColor(1,1,1,1)
			elseif arg2 == "green" then
				arg1:SetTextColor(0, 1, 0.5, 1)
			elseif arg2 == "grey" then
				arg1:SetTextColor(0.5, 0.5, 0.5, 1)
			else
				arg1:SetTextColor(arg2.r,arg2.g,arg2.b,arg2.a)
			end
		end

		-- This function checks if the texture we are trying to set it
		--	already set so we do not set it again

		function m_SetTexture(arg1,arg2)
			if arg1:GetTexture() ~= arg2 then
				arg1:SetTexture(arg2)
			end
		end

		-- This function sets an outline to every font we can find,
		--		so we do not have to set it again.

		local function SetFont(obj, optSize)
			if miirguiDB["outline"] == true then
				local fontName, fontHeight = obj:GetFont()
				if optSize then
					fontHeight = optSize
				end
				obj:SetFont(fontName,fontHeight,"OUTLINE")
				obj:SetShadowOffset(0,0)
				obj:SetShadowColor(0,0,0,0)
			end
		end

		-- Change / add fonts-size by adding it:
		--e.g: SetFont(AchievementFont_Small,20)

		SetFont(ChatFontNormal)
		SetFont(NumberFont_Shadow_Med)
		SetFont(AchievementFont_Small)
		SetFont(NumberFont_OutlineThick_Mono_Small)
		SetFont(NumberFont_Outline_Huge)
		SetFont(NumberFont_Outline_Large)
		SetFont(NumberFont_Outline_Med)
		SetFont(NumberFont_Shadow_Small)
		SetFont(SystemFont_InverseShadow_Small)
		SetFont(SystemFont_Large)
		SetFont(SystemFont_Med1)
		SetFont(SystemFont_Med2)
		SetFont(SystemFont_Med3)
		SetFont(SystemFont_OutlineThick_Huge2)
		SetFont(SystemFont_OutlineThick_Huge4)
		SetFont(SystemFont_OutlineThick_WTF)
		SetFont(SystemFont_Outline_Small)
		SetFont(SystemFont_Shadow_Huge1)
		SetFont(SystemFont_Shadow_Huge3)
		SetFont(SystemFont_Shadow_Large)
		SetFont(SystemFont_Shadow_Med1)
		SetFont(SystemFont_Shadow_Med3)
		SetFont(SystemFont_Shadow_Outline_Huge2)
		SetFont(SystemFont_Shadow_Small)
		SetFont(SystemFont_Small)
		SetFont(SystemFont_Tiny)
		SetFont(ReputationDetailFont)
		SetFont(ItemTextFontNormal)
		SetFont(DialogButtonNormalText)
		SetFont(InvoiceTextFontNormal)
		SetFont(InvoiceTextFontSmall)
		SetFont(MailTextFontNormal)
		SetFont(GameFontHighlightSmall)
		SetFont(GameFontNormalSmall)
		SetFont(GameFontNormalSmall2)
		SetFont(GameFontDisableSmall)
		SetFont(GameFontNormalHuge)
		SetFont(GameFontNormalLarge)
		SetFont(GameFontHighlight)
		SetFont(GameFontDisable)
		SetFont(GameFontNormal)
		SetFont(GameFontBlackMedium)
		SetFont(GameFontHighlightMedium)
		SetFont(SubSpellFont)
		SetFont(NumberFontNormalSmall)
		SetFont(NumberFontNormal)
		SetFont(NumberFontNormalLarge)
		SetFont(NumberFontNormalHuge)
		SetFont(WorldMapTextFont)
		SetFont(MovieSubtitleFont)
		SetFont(AchievementPointsFont)
		SetFont(AchievementPointsFontSmall)
		SetFont(AchievementDateFont)
		SetFont(AchievementCriteriaFont)
		SetFont(AchievementDescriptionFont)
		SetFont(FriendsFont_Large)
		SetFont(FriendsFont_Normal)
		SetFont(FriendsFont_Small)
		SetFont(FriendsFont_UserText)
		SetFont(GameTooltipHeaderText)
		SetFont(GameTooltipText)
		SetFont(GameTooltipTextSmall)
		SetFont(ZoneTextString)
		SetFont(SubZoneTextString)
		SetFont(PVPInfoTextString)
		SetFont(PVPArenaTextString)
		SetFont(CombatTextFont)
		SetFont(BackpackTokenFrameToken1Count)
		SetFont(BackpackTokenFrameToken2Count)
		SetFont(BackpackTokenFrameToken3Count)
		SetFont(QuestFontHighlight)
		SetFont(QuestFontNormalSmall)
		SetFont(QuestTitleFont)
		SetFont(QuestFont)
		SetFont(QuestFont_Large)
		SetFont(QuestTitleFontBlackShadow)
		SetFont(QuestFont_Super_Huge)
		SetFont(HelpFrameKnowledgebaseNavBarHomeButtonText)
		SetFont(GameFont_Gigantic)
		SetFont(CoreAbilityFont)
		SetFont(DestinyFontHuge)
		SetFont(DestinyFontLarge)
		SetFont(InvoiceFont_Small)
		SetFont(InvoiceFont_Med)
		SetFont(MailFont_Large)
		SetFont(QuestFont_Shadow_Small)
		SetFont(QuestFont_Shadow_Huge)
		SetFont(QuestFont_Huge)
		SetFont(QuestFont_Enormous)
		SetFont(SpellFont_Small)
		SetFont(SystemFont_Huge1)
		SetFont(SystemFont_OutlineThick_WTF)
		SetFont(SystemFont_OutlineThick_Huge2)
		SetFont(SystemFont_OutlineThick_Huge4)
		SetFont(SystemFont_Outline)
		SetFont(SystemFont_Shadow_Large_Outline)
		SetFont(SystemFont_Shadow_Large2)
		SetFont(SystemFont_Shadow_Med2)
		SetFont(SystemFont_Shadow_Huge2)
		SetFont(SystemFont_Small2)
		SetFont(Tooltip_Med)
		SetFont(Tooltip_Small)
		SetFont(GameFontNormalMed3)
		SetFont(GameFontNormalHuge2)
		SetFont(GameFontNormalLarge2)
		SetFont(Game30Font)
		SetFont(Game24Font)
		SetFont(Game20Font)
		SetFont(Game18Font)
		SetFont(Game12Font)
		SetFont(Game16Font)
		SetFont(Fancy24Font)											--e.g. Weekly best @ ChallengesFrame
		SetFont(Fancy14Font)
		SetFont(Fancy16Font)
		SetFont(Fancy48Font)
		SetFont(Fancy22Font)											--e.g. TalkingHeadFrame TitleFont
		SetFont(Fancy32Font)
		SetFont(SystemFont_LargeNamePlate,11)				--The font of the nameplate seems to be dynamicly rendered, so we set a fixed size. Without a fixed size it will be huge.
		SetFont(SystemFont_NamePlate,11)
		SetFont(SystemFont_LargeNamePlateFixed,11)
		SetFont(SystemFont_NamePlateFixed,11)
		SetFont(WhiteNormalNumberFont)							--font shown at tradeskill skillbars
		SetFont(PVPInfoTextFont)
		SetFont(ChatFrame1EditBox)									--chateditbox input text
		SetFont(ChatFrame1EditBoxHeader)						--chateditbox say/whisper/guild text
		SetFont(GameTooltipHeader)									--dungeon journal suggestion font
		SetFont(Game48FontShadow)								--bonus text orderhall mission complete
		SetFont(Fancy20Font)
		for i=1, NUM_CHAT_WINDOWS do
				SetFont(_G["ChatFrame"..i])							--chat itself
		end
		m_cursorfix(ChatFrame1EditBox)
end

local m_catch = CreateFrame("Frame")
m_catch:RegisterEvent("PLAYER_LOGIN")
m_catch:SetScript("OnEvent", miirgui_functions)