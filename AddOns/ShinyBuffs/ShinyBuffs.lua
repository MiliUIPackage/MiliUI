local SB = CreateFrame("Frame")
local numBuffsSkinned = 0
local numDebuffsSkinned = 0
local LSM = LibStub("LibSharedMedia-3.0")
local fonts = AceGUIWidgetLSMlists.font
local sbars = AceGUIWidgetLSMlists.statusbar
local bgs = AceGUIWidgetLSMlists.background
local borders = AceGUIWidgetLSMlists.border
local fontFlags = {"None", "Outline", "Monochrome Outline", "Monochrome"}
local fontFlagsLoc = {"無", "外框", "無消除鋸齒外框", "無消除鋸齒"}
local _, class = UnitClass("player")
local classColor, SBmover, moverShown, db
local BuffFrame = BuffFrame

local defaults = {
	font = "Friz Quadrata TT",
	fstyle = "Outline",
	allWhiteText = false,
	whoCast = false,
	buffs = {
		dfsize = 14,
		cfsize = 14,
		size = 36,
	},
	debuffs = {	
		dfsize = 16,
		cfsize = 14,
		size = 48,
	},
	bg = "Solid",
	bgColor = {r = .32, g = .32, b = .32},
	classbg = false,
	border = "SB border",
	borColor = {r = .5, g = .5, b = .5},
	classbor = false,
	debuffTypeBor = false,
	borderWidth = 16,
	debuffOverlayAlpha = .3,
	sbar = "Solid",
	sbarColor = {r = 0, g = 1, b = 0},
	classbar = false,
	posX = -205,
	posY = -13,
	anchor1 = "TOPRIGHT",
	anchor2 = "TOPRIGHT",
	bprow = 8,
}


local function SkinningMachine(svtable, btn, dur, c, icon, bor, firstTime)
	btn:SetSize(db[svtable].size, db[svtable].size)
	icon:SetSize(db[svtable].size-8, db[svtable].size-8)
	if firstTime then
		btn.bg = CreateFrame("Frame", nil, btn)
		btn.bg:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
		dur:SetJustifyH("RIGHT")
		dur:ClearAllPoints()
		dur:SetPoint("BOTTOMRIGHT", 1, 1)
		c:SetJustifyH("LEFT")
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", 2, -2)
		icon:ClearAllPoints()
		icon:SetPoint("CENTER", btn, "CENTER")
		icon:SetTexCoord(.07, .93, .07, .93)
		if bor then
			bor:SetParent(btn.bg)
			bor:SetDrawLayer("OVERLAY", 1)
		end
		--
		btn.bar = CreateFrame("StatusBar", nil, btn.bg)
		btn.bar:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -1.5)
		btn.bar:SetPoint("TOPRIGHT", icon, "BOTTOMRIGHT", 0, -1.5)
		btn.bar:SetPoint("BOTTOM", btn.bg, "BOTTOM", 0, 5.5)
		btn.bar:SetMinMaxValues(0, 1)	-- 0%-100%
		--keep these on top ><
		icon:SetParent(btn.bg)
		icon:SetDrawLayer("OVERLAY", 0)
		dur:SetParent(btn.bar)
		dur:SetDrawLayer("OVERLAY", 3)
		c:SetParent(btn.bg)
		c:SetDrawLayer("OVERLAY", 3)
	end
	if bor then
		bor:SetAlpha(db.debuffOverlayAlpha)
		bor:ClearAllPoints()
		if db.debuffTypeBor then
			bor:SetAllPoints(btn.bg)
			bor:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
			bor:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
			bor:SetAlpha(1)
		else
			bor:SetAllPoints(icon)
			bor:SetColorTexture(1,1,1,0.8)
		end	
	end
	dur:SetFont(LSM:Fetch("font", db.font), db[svtable].dfsize, db.fstyle)
	c:SetFont(LSM:Fetch("font", db.font), db[svtable].cfsize, db.fstyle)
	btn.bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -max(db[svtable].size*.2, 5))
	btn.bg:SetBackdrop({	bgFile = LSM:Fetch("background", db.bg),
						edgeFile = LSM:Fetch("border", db.border),
						edgeSize = db.borderWidth,
						insets = {left=3,right=3,top=3,bottom=3}
					})
	btn.bar:SetStatusBarTexture(LSM:Fetch("statusbar", db.sbar))
	if db.classbg then
		btn.bg:SetBackdropColor(classColor.r, classColor.g, classColor.b)
	else
		btn.bg:SetBackdropColor(db.bgColor.r, db.bgColor.g, db.bgColor.b)
	end
	if db.classbor then
		btn.bg:SetBackdropBorderColor(classColor.r, classColor.g, classColor.b)
	else
		btn.bg:SetBackdropBorderColor(db.borColor.r, db.borColor.g, db.borColor.b)
	end
	-- 減益的計時條改為紅色
	if svtable == "debuffs" then
		btn.bar:SetStatusBarColor(1, 0, 0)
	elseif db.classbar then
		btn.bar:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
	else
		btn.bar:SetStatusBarColor(db.sbarColor.r, db.sbarColor.g, db.sbarColor.b)
	end
end

local function SkinBuffs(i, firstTime)
	local b = _G["BuffButton"..i]
	local dur = b.duration
	local c = b.count
	local icon = _G["BuffButton"..i.."Icon"]
	
	SkinningMachine("buffs", b, dur, c, icon, nil, firstTime)
	
	--only setscript and increment count if we're skinning for the first time
	if firstTime then
		local timer = 0
		local dur, exps, _, val
		b.bar:SetScript("OnUpdate", function(self, elapsed)
				timer = timer + elapsed
				if timer >= .1 then
					_,_,_,_,dur,exps = UnitBuff("player",i)
					if dur == 0 then
						self:SetValue(1)
					else
						if exps then
							val = exps-GetTime()
							self:SetValue(val/dur)
						end
					end
					timer = 0
				end
			end)
			
		numBuffsSkinned = i
	end
end

local function SkinDebuffs(i, firstTime)
	local d = _G["DebuffButton"..i]
	local dur = d.duration
	local c = d.count
	local icon = _G["DebuffButton"..i.."Icon"]
	local bor = _G["DebuffButton"..i.."Border"]
	
	SkinningMachine("debuffs", d, dur, c, icon, bor, firstTime)
	
	--only setscript and increment count if we're skinning for the first time
	if firstTime then
		local timer = 0
		local dur, exps, _, val
		d.bar:SetScript("OnUpdate", function(self, elapsed)
				timer = timer + elapsed
				if timer >= .1 then
					_,_,_,_,dur,exps = UnitDebuff("player",i)
					if dur == 0 then
						self:SetValue(1)
					else
						if exps then
							val = exps-GetTime()
							self:SetValue(val/dur)
						end
					end
					timer = 0
				end
			end)
		
		numDebuffsSkinned = i
	end
end

local function SkinTench(firstTime)
	for i = 1, NUM_TEMP_ENCHANT_FRAMES do
		local t = _G["TempEnchant"..i]
		local dur = t.duration
		local c = t.count
		local icon = _G["TempEnchant"..i.."Icon"]
		local bor = _G["TempEnchant"..i.."Border"]
		
		SkinningMachine("buffs", t, dur, c, icon, bor, firstTime)
		
		if firstTime then
			bor:SetVertexColor(.9, 0, .9)
			t.bar:SetValue(1)
			--keep the buffs spaced correctly from Tench
			local TenchWidth = TemporaryEnchantFrame.SetWidth
			local tench1, tench2, tench3, num
			hooksecurefunc(TemporaryEnchantFrame, "SetWidth", function(self,width)
					tench1,_,_,tench2,_,_,tench3 = GetWeaponEnchantInfo()
					num = (tench3 and 3) or (tench2 and 2) or 1
					TenchWidth(self, (num * db.buffs.size) + ((num-1) * 5))
				end)
		end
	end
end

local OLD_SetUnitAura, NEW_SetUnitAura, caster, casterName = GameTooltip.SetUnitAura
local function WhoCast()
	if db.whoCast then
		if not NEW_SetUnitAura then
			NEW_SetUnitAura = function(self, unit, id, filter)
				OLD_SetUnitAura(self, unit, id, filter)
				if filter == "HELPFUL" then
					_,_,_,_,_,_,caster = UnitAura("player", id)	--7th return
					casterName = caster==nil and "未知" or caster=="player" and "你" or caster=="pet" and "你的寵物" or UnitName(caster)
					GameTooltip:AddLine("施法者："..casterName, .5, .9, 1)
					GameTooltip:Show()
				end
			end
		end
		GameTooltip.SetUnitAura = NEW_SetUnitAura
	else
		GameTooltip.SetUnitAura = OLD_SetUnitAura
	end
end

local function Position()
	BuffFrame:ClearAllPoints()
	BuffFrame:NewSetPoint(db.anchor1, UIParent, db.anchor2, db.posX, db.posY)
end

local function ShowMover()
	if not SBmover then
		SBmover = CreateFrame("Frame", nil, UIParent)
		SBmover:SetBackdrop({bgFile = "Interface\\AddOns\\ShinyBuffs\\media\\mover.blp"})
		SBmover:SetBackdropColor(1,1,1,.5)
		SBmover:SetPoint("TOPRIGHT", BuffFrame, "TOPRIGHT", 5, 5)
		SBmover:SetSize(200, 150)
		SBmover:SetFrameStrata("TOOLTIP")
		SBmover:EnableMouse(true)
		BuffFrame:SetMovable(true)
		BuffFrame:SetClampedToScreen(true)
		SBmover:SetScript("OnMouseDown", function(self) 
				BuffFrame:StartMoving()
			end)
		SBmover:SetScript("OnMouseUp", function(self)
				BuffFrame:StopMovingOrSizing()
				db.anchor1, _, db.anchor2, db.posX, db.posY = BuffFrame:GetPoint()
				--Position()
				if SB.optionsFrame:IsShown() then
					InterfaceOptionsFrame_OpenToCategory("ShinyBuffs")
				end
			end)
	end
	SBmover:SetAlpha(moverShown and 1 or 0)
	SBmover:EnableMouse(moverShown)
end

local function SkinAuras()
	if BUFF_ACTUAL_DISPLAY > numBuffsSkinned then
		for i = numBuffsSkinned+1, BUFF_ACTUAL_DISPLAY do
			SkinBuffs(i, true)
		end
	end
	if DEBUFF_ACTUAL_DISPLAY > numDebuffsSkinned then
		for i = numDebuffsSkinned+1, DEBUFF_ACTUAL_DISPLAY do
			SkinDebuffs(i, true)
		end
	end
end

local options = {
	name = "我的增益與減益效果",
	type = "group",
	args = {
		header1 = {
			name = "文字設定",
			type = "header",
			order = 1,
		},
		font = {
			name = "字體",
			type = "select",
			desc = "選擇要使用的字體。",
			dialogControl = "LSM30_Font",
			values = fonts,
			get = function() return db.font end,
			set = function(_,font)
						db.font = font
						for i=1,numBuffsSkinned do
							SkinBuffs(i,false)
						end
						for i=1,numDebuffsSkinned do
							SkinDebuffs(i,false)
						end
						SkinTench(false)
					end,
			order = 2,
		},
		fontFlag = {
			name = "字體樣式",
			desc = "設定如何更改顯示的字體。",
			type = "select",
			values = fontFlagsLoc,
			get = function()
						for k, v in pairs(fontFlags) do
							if db.fstyle == v then
								return k
							end
						end
					end,
			set = function(_,key)
						db.fstyle = fontFlags[key]
						for i=1,numBuffsSkinned do
							SkinBuffs(i,false)
						end
						for i=1,numDebuffsSkinned do
							SkinDebuffs(i,false)
						end
						SkinTench(false)
					end,
			order = 3,
		},
		allwhite = {
			name = "白色時間文字",
			desc = "持續時間文字永遠顯示為白色。(遊戲預設的顏色黃色，低於 60 秒的提醒效果才是白色。這個選項會加大提醒的時間，永遠顯示為白色。)",
			type = "toggle",
			get = function() return db.allWhiteText end,
			set = function()
					db.allWhiteText = not db.allWhiteText
					if db.allWhiteText then
						BUFF_DURATION_WARNING_TIME = 7200
					else
						BUFF_DURATION_WARNING_TIME = 60
					end
				end,
			order = 4,
		},
		buffFonts = {
			name = "增益效果文字大小",
			type = "group",
			inline = true,
			order = 5,
			args = {
				durSize = {
					name = "時間",
					type = "range",
					min = 6,
					max = 24,
					step = 1,
					get = function() return db.buffs.dfsize end,
					set = function(_,size) 
							db.buffs.dfsize = size
							for i=1,numBuffsSkinned do
								SkinBuffs(i,false)
							end
							SkinTench(false)
						end,
					order = 1,
				},
				countSize = {
					name = "次數",
					type = "range",
					min = 6,
					max = 24,
					step = 1,
					get = function() return db.buffs.cfsize end,
					set = function(_,size) 
							db.buffs.cfsize = size
							for i=1,numBuffsSkinned do
								SkinBuffs(i,false)
							end
							SkinTench(false)
						end,
					order = 2,
				},
				whoCast = {
					name = "顯示施法者",
					desc = "在你的增益效果滑鼠提示中顯示是誰施放的法術。\n\n注意：需要重新載入介面後才會生效，可輸入 /reload 來重新載入。",
					type = "toggle",
					get = function() return db.whoCast end,
					set = function() db.whoCast = not db.whoCast WhoCast() end,
					order = 3,
				},
			},
		},
		debuffFonts = {
			name = "減益效果文字大小",
			type = "group",
			inline = true,
			order = 6,
			args = {
				durSize = {
					name = "時間",
					type = "range",
					min = 6,
					max = 24,
					step = 1,
					get = function() return db.debuffs.dfsize end,
					set = function(_,size) 
							db.debuffs.dfsize = size
							for i=1,numDebuffsSkinned do
								SkinDebuffs(i,false)
							end
						end,
					order = 1,
				},
				countSize = {
					name = "次數",
					type = "range",
					min = 6,
					max = 24,
					step = 1,
					get = function() return db.debuffs.cfsize end,
					set = function(_,size) 
							db.debuffs.cfsize = size
							for i=1,numDebuffsSkinned do
								SkinDebuffs(i,false)
							end
						end,
					order = 2,
				},
			},
		},
		spacer1 = {
			name = " ",
			type = "description",
			width = "full",
			order = 7,
		},
		header2 = {
			name = "外觀設定",
			type = "header",
			order = 8,
		},
		border = {
			name = "邊框",
			type = "group",
			inline = true,
			order = 9,
			args = {
				texture = {
					name = "材質",
					type = "select",
					desc = "選擇邊框材質。",
					dialogControl = "LSM30_Border",
					values = borders,
					get = function() return db.border end,
					set = function(_,border)
								db.border = border
								for i=1,numBuffsSkinned do
									SkinBuffs(i,false)
								end
								for i=1,numDebuffsSkinned do
									SkinDebuffs(i,false)
								end
								SkinTench(false)
							end,
					order = 1,
				},
				borderWidth = {
					name = "邊框寬度",
					desc = "邊框的寬度。",
					type = "range",
					min = 1,
					max = 24,
					step = .5,
					get = function() return db.borderWidth end,
					set = function(_,size)
							db.borderWidth = size
							for i=1,numBuffsSkinned do
								SkinBuffs(i,false)
							end
							for i=1,numDebuffsSkinned do
								SkinDebuffs(i,false)
							end
							SkinTench(false)
						end,
					order = 2,
				},
				borColor = {
					name = "顏色",
					desc = "選擇邊框材質的顏色。",
					type = "color",
					width = "half",
					disabled = function() return db.classbor end,
					get = function() return db.borColor.r, db.borColor.g, db.borColor.b end,
					set = function(_,r,g,b)
								db.borColor.r,db.borColor.g,db.borColor.b = r,g,b
								for i=1,numBuffsSkinned do
									SkinBuffs(i,false)
								end
								for i=1,numDebuffsSkinned do
									SkinDebuffs(i,false)
								end
								SkinTench(false)
							end,
					order = 3,
				},
				classbor = {
					name = "職業",
					desc = "使用我的職業顏色。",
					type = "toggle",
					width = "half",
					get = function() return db.classbor end,
					set = function()
								db.classbor = not db.classbor
								for i=1,numBuffsSkinned do
									SkinBuffs(i,false)
								end
								for i=1,numDebuffsSkinned do
									SkinDebuffs(i,false)
								end
								SkinTench(false)
							end,
					order = 4,
				},
				debuffTypeBor = {
					name = "類型",
					desc = "邊框顯示減益效果的驅散類型，而不是與圖示重疊。",
					type = "toggle",
					get = function() return db.debuffTypeBor end,
					set = function()
								db.debuffTypeBor = not db.debuffTypeBor
								for i=1,numDebuffsSkinned do
									SkinDebuffs(i,false)
								end
							end,
					order = 5,
				},
				debuffOverlayAlpha = {
					name = "減益效果類型透明度",
					desc = "減益效果驅散類型與圖示重疊時的透明度。",
					type = "range",
					disabled = function() return db.debuffTypeBor end,
					min = .25,
					max = 1,
					step = .05,
					get = function() return db.debuffOverlayAlpha end,
					set = function(_,alpha)
							db.debuffOverlayAlpha = alpha
							for i=1,numDebuffsSkinned do
								SkinDebuffs(i,false)
							end
						end,
					order = 6,
				},
			},
		},
		sbar = {
			name = "狀態列",
			type = "group",
			inline = true,
			order = 10,
			args = {
				texture = {
					name = "材質",
					type = "select",
					desc = "選擇計時條材質。",
					dialogControl = "LSM30_Statusbar",
					values = sbars,
					get = function() return db.sbar end,
					set = function(_,sbar)
								db.sbar = sbar
								for i=1,numBuffsSkinned do
									SkinBuffs(i,false)
								end
								for i=1,numDebuffsSkinned do
									SkinDebuffs(i,false)
								end
								SkinTench(false)
							end,
					order = 1,
				},
				sbarColor = {
					name = "顏色",
					desc = "選擇計時條材質的顏色。",
					type = "color",
					width = "half",
					disabled = function() return db.classbar end,
					get = function() return db.sbarColor.r, db.sbarColor.g, db.sbarColor.b end,
					set = function(_,r,g,b)
								db.sbarColor.r,db.sbarColor.g,db.sbarColor.b = r,g,b
								for i=1,numBuffsSkinned do
									SkinBuffs(i,false)
								end
								for i=1,numDebuffsSkinned do
									SkinDebuffs(i,false)
								end
								SkinTench(false)
							end,
					order = 2,
				},
				classbar = {
					name = "職業",
					desc = "使用我的職業顏色。",
					type = "toggle",
					width = "half",
					get = function() return db.classbar end,
					set = function()
								db.classbar = not db.classbar
								for i=1,numBuffsSkinned do
									SkinBuffs(i,false)
								end
								for i=1,numDebuffsSkinned do
									SkinDebuffs(i,false)
								end
								SkinTench(false)
							end,
					order = 3,
				},
			},
		},
		bg = {
			name = "背景",
			type = "group",
			inline = true,
			order = 11,
			args = {
				texture = {
					name = "材質",
					type = "select",
					desc = "選擇背景材質。",
					dialogControl = "LSM30_Background",
					values = bgs,
					get = function() return db.bg end,
					set = function(_,bg)
								db.bg = bg
								for i=1,numBuffsSkinned do
									SkinBuffs(i,false)
								end
								for i=1,numDebuffsSkinned do
									SkinDebuffs(i,false)
								end
								SkinTench(false)
							end,
					order = 1,
				},
				bgColor = {
					name = "顏色",
					desc = "選擇背景材質的顏色。",
					type = "color",
					width = "half",
					disabled = function() return db.classbg end,
					get = function() return db.bgColor.r, db.bgColor.g, db.bgColor.b end,
					set = function(_,r,g,b)
								db.bgColor.r,db.bgColor.g,db.bgColor.b = r,g,b
								for i=1,numBuffsSkinned do
									SkinBuffs(i,false)
								end
								for i=1,numDebuffsSkinned do
									SkinDebuffs(i,false)
								end
								SkinTench(false)
							end,
					order = 2,
				},
				classbg = {
					name = "職業",
					desc = "使用我的職業顏色。",
					type = "toggle",
					width = "half",
					get = function() return db.classbg end,
					set = function()
								db.classbg = not db.classbg
								for i=1,numBuffsSkinned do
									SkinBuffs(i,false)
								end
								for i=1,numDebuffsSkinned do
									SkinDebuffs(i,false)
								end
								SkinTench(false)
							end,
					order = 3,
				},
			},
		},
		spacer2 = {
			name = " ",
			type = "description",
			width = "full",
			order = 12,
		},
		header3 = {
			name = "版面配置",
			type = "header",
			order = 13,
		},
		posX = {
			name = "水平位置",
			desc = "與畫面右上角的水平距離，應為負的數值。",
			type = "input",
			width = "half",
			get = function() return tostring(db.posX) end,
			set = function(_,x)
					db.posX = tonumber(x)
					Position()
				end,
			order = 14,
		},
		posY = {
			name = "垂直位置",
			desc = "與畫面右上角的垂直距離，應為負的數值。",
			type = "input",
			width = "half",
			get = function() return tostring(db.posY) end,
			set = function(_,y)
					db.posY = tonumber(y)
					Position()
				end,
			order = 15,
		},
		mover = {
			name = "顯示位置區塊",
			type = "toggle",
			get = function() return moverShown end,
			set = function()
					moverShown = not moverShown
					ShowMover()
				end,
			order = 16,
		},
		bprow = {
			name = "每列數量",
			desc = "每個橫列要顯示多少個增益/減益效果，超過會換到下一列。",
			type = "range",
			min = 2,
			max = BUFF_MAX_DISPLAY,
			step = 1,
			get = function() return db.bprow end,
			set = function(_,bprow)
					db.bprow = bprow
					BUFFS_PER_ROW = bprow
				end,
			order = 17,
		},
		sizes = {
			name = "圖示大小",
			type = "group",
			inline = true,
			order = 17.5,
			args = {
				buffSize = {
					name = "增益效果",
					desc = "增益效果圖示的大小。",
					type = "range",
					min = 20,
					max = 60,
					step = 1,
					get = function() return db.buffs.size end,
					set = function(_,size)
							db.buffs.size = size
							for i=1,numBuffsSkinned do
								SkinBuffs(i,false)
							end
							SkinTench(false)
						end,
					order = 1,
				},
				debuffSize = {
					name = "減益效果",
					desc = "減益效果圖示的大小。",
					type = "range",
					min = 20,
					max = 60,
					step = 1,
					get = function() return db.debuffs.size end,
					set = function(_,size)
							db.debuffs.size = size
							for i=1,numDebuffsSkinned do
								SkinDebuffs(i,false)
							end
						end,
					order = 2,
				},
			},
		},
		spacer3 = {
			name = " ",
			type = "description",
			width = "full",
			order = 18,
		},
		header4 = {
			name = "設定檔",
			type = "header",
			order = 19,
		},
		charSpec = {
			name = "角色專用設定",
			desc = "這個角色使用自己獨立的設定檔。勾選時，任何調整都不會影響其他角色。\n\n|c00E30016警告：|r將會重新載入介面！",
			type = "toggle",
			width = "full",
			confirm = true,
			get = function() return ShinyBuffsDB.charSpec end,
			set = function()
						ShinyBuffsPCDB.charSpec = not ShinyBuffsPCDB.charSpec
						ReloadUI()
					end,
			order = 20,
		},
		copyProfile = {
			name = "複製預設值",
			desc = "將整體設定檔的預設值複製設定到這個角色的設定檔，不會影響其他角色的專用設定檔。\n\n|c00E30016警告：|r將會重新載入介面！",
			type = "execute",
			confirm = true,
			disabled = function() return not ShinyBuffsPCDB.charSpec end,
			func = function()
						ShinyBuffsPCDB = ShinyBuffsDB
						ShinyBuffsPCDB.charSpec = true
						ReloadUI()
					end,
			order = 21,
		},
		resetProfile = {
			name = "重置設定檔",
			desc = "將這個設定檔重置為最初的設定。重置角色專用設定檔時，整體設定檔不會受到影響，反之亦然。不會影響其他角色的專用設定檔。\n\n|c00E30016警告：|r將會重新載入介面！",
			type = "execute",
			confirm = true,
			func = function()
						if ShinyBuffsPCDB.charSpec then
							ShinyBuffsPCDB = {charSpec = true}
						else
							ShinyBuffsDB = {}
						end
						ReloadUI()
					end,
			order = 22,
		},
	},
}


local function SetUpDB()
	if ShinyBuffsPCDB.charSpec then
		--set defaults if new charSpec DB
		for k,v in pairs(defaults) do
			if type(ShinyBuffsPCDB[k]) == "nil" then
				ShinyBuffsPCDB[k] = v
			end
		end
		db = ShinyBuffsPCDB
	else
		db = ShinyBuffsDB
	end
end

local function PEW()
	ShinyBuffsDB = ShinyBuffsDB or {}
	ShinyBuffsPCDB = ShinyBuffsPCDB or {}
		if ShinyBuffsPCDB.charSpec == nil then
			ShinyBuffsPCDB.charSpec = false
		end
	for k,v in pairs(defaults) do
	    if type(ShinyBuffsDB[k]) == "nil" then
	        ShinyBuffsDB[k] = v
	    end
	end
	SetUpDB()
	
	classColor = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class] or RAID_CLASS_COLORS[class]
	
	if CUSTOM_CLASS_COLORS then
		CUSTOM_CLASS_COLORS:RegisterCallback(function()
				if db.classbor or db.classbg or db.classbar then
					for i=1,numBuffsSkinned do
						SkinBuffs(i,false)
					end
					for i=1,numDebuffsSkinned do
						SkinDebuffs(i,false)
					end
					SkinTench(false)
				end
			end)
	end
	
	LibStub("AceConfig-3.0"):RegisterOptionsTable("ShinyBuffs", options)
	SB.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ShinyBuffs", "增益效果")
	SlashCmdList["SHINYBUFFS"] = function()
			InterfaceOptionsFrame_OpenToCategory("增益效果")
			InterfaceOptionsFrame_OpenToCategory("增益效果")
		end
	SLASH_SHINYBUFFS1 = "/shinybuffs"
	SLASH_SHINYBUFFS2 = "/sb"

	if db.allWhiteText then
		BUFF_DURATION_WARNING_TIME = 7200
	end
	BUFF_ROW_SPACING = 15
	BUFFS_PER_ROW = db.bprow
	
	C_Timer.After(.25, SkinAuras)
	SkinTench(true)

	--keep other stuff (like ticket frame) from moving buffs
	BuffFrame.NewSetPoint = BuffFrame.SetPoint
	BuffFrame.SetPoint = Position	
	Position()

	WhoCast()
	
	SB:UnregisterEvent("PLAYER_ENTERING_WORLD")
	SB:RegisterUnitEvent("UNIT_AURA", "player") 
	SB:SetScript("OnEvent", function(s,e,unit)
			SkinAuras()
			--don't bother checking if they're all skinned
			if numBuffsSkinned == BUFF_MAX_DISPLAY and numDebuffsSkinned == DEBUFF_MAX_DISPLAY then
				SB:UnregisterEvent("UNIT_AURA")
				SB:SetScript("OnEvent", nil)
			end
		end)
	PEW = nil
end

LSM:Register("border", "SB border", "Interface\\AddOns\\ShinyBuffs\\media\\5.tga")
LSM:Register("statusbar", "Solid", "Interface\\AddOns\\ShinyBuffs\\media\\Solid.tga")
LSM:Register("background", "Solid", "Interface\\AddOns\\ShinyBuffs\\media\\Solid.tga")

SB:SetScript("OnEvent", PEW)

SB:RegisterEvent("PLAYER_ENTERING_WORLD")