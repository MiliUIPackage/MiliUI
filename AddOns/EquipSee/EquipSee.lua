
local addonName, addonTable = ...;
local zc = addonTable.zc;
local zz = zc.md;

local ItemUpgradeInfo = LibStub("LibItemUpgradeInfo-1.0")

local gContainerFramesNeedUpdate = true;
local gOneBagFound = false

-----------------------------------------

function Eqx_OnLoad(self)

	self:RegisterEvent("VARIABLES_LOADED");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
	self:RegisterEvent("EQUIPMENT_SETS_CHANGED");
	self:RegisterEvent("BAG_UPDATE");
	self:RegisterEvent("BAG_OPEN");
	self:RegisterEvent("BANKFRAME_OPENED");
	self:RegisterEvent("ADDON_LOADED");


	self.TimeSinceLastUpdate = 0;
end

-----------------------------------------

function Eqx_EventHandler(self, event, ...)

	if (event == "VARIABLES_LOADED") 			then		Eqx_OnVariablesLoaded();			end
	if (event == "PLAYER_ENTERING_WORLD")		then		Eqx_PlayerEnteringWorld();			end
	if (event == "EQUIPMENT_SETS_CHANGED")		then		Eqx_BagsSetNeedsUpdate();			end
	if (event == "BAG_UPDATE")					then		Eqx_BagsSetNeedsUpdate();			end
	if (event == "BAG_OPEN")					then		Eqx_BagsSetNeedsUpdate();			end
	if (event == "BANKFRAME_OPENED")			then		Eqx_BagsSetNeedsUpdate();			end
	if (event == "ADDON_LOADED")				then		Eqx_OnAddonLoaded(...);				end


end

-----------------------------------------

function Eqx_OnAddonLoaded(addonName)
	if (zc.StringStartsWith (addonName, "OneBag")) then
		gOneBagFound = true
	end
end

-----------------------------------------

local function Eqx_SlashCmdFunction(msg)

	local cmd, param1u, param2u, param3u = zc.words (msg)

	if (cmd == nil or type (cmd) ~= "string") then
		return;
	end

		  cmd    = cmd     and cmd:lower()     or nil;
	local param1 = param1u and param1u:lower() or nil;
	local param2 = param2u and param2u:lower() or nil;
	local param3 = param3u and param3u:lower() or nil;

	zc.msg_anm ("unrecognized command")

end

-----------------------------------------

function Eqx_OnVariablesLoaded()

--  PaperDollEquipmentManagerPane:HookScript ("OnHide", Eqx_HideAllMasks);
--	PaperDollEquipmentManagerPane:HookScript ("OnShow", Eqx_GearManagerDialog_OnShow);
--  hooksecurefunc ("GearSetButton_OnClick", Eqx_GearSetBut_OnClick);

	hooksecurefunc ("ToggleBackpack", Eqx_BagsSetNeedsUpdate);
	hooksecurefunc ("OpenBackpack", Eqx_BagsSetNeedsUpdate);
	hooksecurefunc ("OpenAllBags", Eqx_BagsSetNeedsUpdate);
	hooksecurefunc ("OpenBag", Eqx_BagsSetNeedsUpdate);
	hooksecurefunc ("ToggleAllBags", Eqx_BagsSetNeedsUpdate);
	hooksecurefunc ("ToggleBag", Eqx_BagsSetNeedsUpdate);

	SlashCmdList["Equipsee"] = Eqx_SlashCmdFunction;

	SLASH_Equipsee1 = "/equipsee";
	SLASH_Equipsee2 = "/eqx";

	if (ArkInventory) then
		local oArk_Frame_Main_Toggle = ArkInventory.Frame_Main_Toggle;
		ArkInventory.Frame_Main_Toggle = function(...)
			Eqx_BagsSetNeedsUpdate()
			oArk_Frame_Main_Toggle(...)
		end
		local oArk_Frame_Main_Show = ArkInventory.Frame_Main_Show;
		ArkInventory.Frame_Main_Show = function(...)
			Eqx_BagsSetNeedsUpdate()
			oArk_Frame_Main_Show(...)
		end
	end
end

-----------------------------------------

function Eqx_PlayerEnteringWorld ()

	if (Combuctor) then
		local oToggleBag = ToggleBag;
		ToggleBag = function(...)
			Eqx_BagsSetNeedsUpdate()
			oToggleBag(...)
		end

		local oOpenAllBags = OpenAllBags;
		OpenAllBags = function(...)
			Eqx_BagsSetNeedsUpdate()
			oOpenAllBags(...)
		end
	end

end

-----------------------------------------

local sinfo;

-----------------------------------------

function Eqx_Init()

	Eqx_Init_Sinfo();

end

-----------------------------------------

function Eqx_Init_Sinfo()

	if (sinfo) then
		return;
	end

	local but;

	sinfo = {
			{ but = CharacterHeadSlot			},
			{ but = CharacterNeckSlot			},
			{ but = CharacterShoulderSlot		},
			{ but = CharacterShirtSlot			, isCosmetic = true},
			{ but = CharacterChestSlot			},
			{ but = CharacterWaistSlot			},
			{ but = CharacterLegsSlot			},
			{ but = CharacterFeetSlot			},
			{ but = CharacterWristSlot			},
			{ but = CharacterHandsSlot			},
			{ but = CharacterFinger0Slot		},
			{ but = CharacterFinger1Slot		},
			{ but = CharacterTrinket0Slot		},
			{ but = CharacterTrinket1Slot		},
			{ but = CharacterBackSlot			},
			{ but = CharacterMainHandSlot		},
			{ but = CharacterSecondaryHandSlot	},
			nil,
			{ but = CharacterTabardSlot			, isCosmetic = true}
		};

	for _, slot in pairs(sinfo) do

		local but = slot.but;
		slot.tex = but:CreateTexture(nil, "OVERLAY");
		slot.tex:SetColorTexture(1,0,0, 0.4);
		slot.tex:SetAllPoints(but);
		slot.tex:Hide();

		slot.text = but:CreateFontString (nil, "OVERLAY");
		slot.text:SetFontObject ("Eqx_Ilevel_Font");
		slot.text:SetAllPoints(but);
		slot.text:Hide();

	end

end

-----------------------------------------

local function Eqx_SlotTag (bagID, slotID)

	if (bagID == nil) then
		return "-1_"..slotID
	end

	return bagID.."_"..slotID
end

-----------------------------------------

local gEquipmentMap_BySlotID
local gItemArray

-----------------------------------------

function Eqx_BuildEquipmentMap_BySlotID()

    --zc.printstack()

    local num = C_EquipmentSet.GetNumEquipmentSets()
    local n;
    
    gItemArray = {};
    gEquipmentMap_BySlotID = {};
    
    local player, bank, bags, slot, bag, slotTag
    local esIDs = C_EquipmentSet.GetEquipmentSetIDs();
    
    for n = 1,num do
        local name = C_EquipmentSet.GetEquipmentSetInfo(esIDs[n])
        gItemArray = C_EquipmentSet.GetItemLocations(esIDs[n]) or {}
                
        if (gItemArray) then
            for _, location in pairs(gItemArray) do
                if (location ~= -1 and location ~= 0 and location ~= 1 ) then
                    player, bank, bags, voidstorage, slot, bag = EquipmentManager_UnpackLocation(location)
                    if (bags or bank) then
                        if (bank and not bags) then
                            bag  = -1
                            slot = slot - BANK_CONTAINER_INVENTORY_OFFSET
                        end
                    
                        slotTag = Eqx_SlotTag (bag, slot)
                        if (gEquipmentMap_BySlotID[slotTag] == nil) then
                            gEquipmentMap_BySlotID[slotTag] = {};
                        end
                        table.insert (gEquipmentMap_BySlotID[slotTag], name)
                        --zz (slotTag, name)
                    end
                end
            end
        end
        
    end
    
end


-----------------------------------------

local function Eqx_GetEquipSetName_BySlot (bagID, slotID)

	if (gEquipmentMap_BySlotID == nil) then
		Eqx_BuildEquipmentMap_BySlotID();
	end

	if (bagID == nil or slotID == nil) then
		return ""
	end

	local slotTag = Eqx_SlotTag (bagID, slotID)

	local slotNames = gEquipmentMap_BySlotID[slotTag]

	if (slotNames) then
		local s = "";
		local x;

		for x = 1, #slotNames do
			local sname = slotNames[x];
			if (string.len (sname) > 6) then
				sname = string.sub (sname, 1, 6);
			end
			s = s..sname.."\n";
		end

		return s;
	end

	return "";

end



-----------------------------------------
-- bag addon developers: this is the function to call whenever the something happens that requires the labels to be refreshed
-- I already call this in response to bag update events, etc.

function Eqx_BagsSetNeedsUpdate()

	gContainerFramesNeedUpdate = true

	gEquipmentMap_BySlotID = nil		-- force rebuild next time there's an update
end


-----------------------------------------

function Eqx_UpdateContainerFrames()

	if (gContainerFramesNeedUpdate) then

		gContainerFramesNeedUpdate = false;

		if (ArkInventory and ArkInventory.ContainerItemNameGet) then
			Eqx_UpdateContainerFrames_1(1)
			Eqx_UpdateContainerFrames_1(3)
		elseif (Baggins) then
			Baggins:UpdateBags()
		else
			Eqx_UpdateContainerFrames_1()
		end
	end

end

-----------------------------------------

function Eqx_UpdateContainerFrames_1(arkloc)		-- arkloc (special ad hoc parameter for ArkInventory

	local b, s;

--zz ("Updating container frames", NUM_CONTAINER_FRAMES);

	for b= 0, NUM_CONTAINER_FRAMES do

		local numslots = 40;

		for s = 1, numslots do

			local sname = "";

			if (ArkInventory and ArkInventory.ContainerItemNameGet) then
				sname = ArkInventory.ContainerItemNameGet( arkloc, b, s );
			elseif (gOneBagFound) then
				sname = "OneBagFrameBag"..b.."Item"..s;
			else
				sname = "ContainerFrame"..b.."Item"..s;
			end

			Eqx_UpdateContainerFrames_Core (sname)
		end
	end

	for s = 1, 40 do
		Eqx_UpdateContainerFrames_Core ("BankFrameItem"..s, true)
	end

end

-----------------------------------------

function Eqx_UpdateContainerSlot (sframe)

	local bagID  = sframe:GetParent():GetID()
	local slotID = sframe:GetID()

	-- I'm sure there's a better way to figure out whether it's the bank inventory

	if (bagID == 0 and zc.StringContains (sframe:GetName(), "bank")) then
		bagID = -1
	end

	local setnames = Eqx_GetEquipSetName_BySlot (bagID, slotID)

	--zz (sframe:GetName(), bagID, slotID, setnames)

	if (sframe.eqx_info == nil and setname ~= "") then
		sframe.eqx_info = {}
		sframe.eqx_info.text = sframe:CreateFontString (nil, "OVERLAY")
		sframe.eqx_info.text:SetFontObject ("Eqx_Ilevel_Font")
	end

	if (sframe.eqx_info) then
		sframe.eqx_info.text:SetAllPoints(sframe);
		sframe.eqx_info.text:SetText(setnames)
	end

end

-----------------------------------------

function Eqx_UpdateContainerFrames_Core(sname, isBankFrame)

	local b, s;
	local sframe = _G[sname];
	if (sframe and sframe:IsShown() and sframe:IsVisible()) then
		local slot = sframe:GetID();
		if (slot and slot > 0) then
			Eqx_UpdateContainerSlot (sframe)
		end
	end
end

-----------------------------------------

function Eqx_OnUpdate (self, elapsed)

	self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;

	if (self.TimeSinceLastUpdate > 0.4) then

		self.TimeSinceLastUpdate = 0;

		Eqx_UpdateContainerFrames();

		-- if (PaperDollEquipmentManagerPane:IsShown()) then
		-- 	Eqx_UpdateMasks ({ showItemLevel = true });
		-- end
	end

end

-----------------------------------------

function Eqx_GearSetBut_OnClick ()

	Eqx_UpdateMasks ({ showItemLevel = true });

end

-----------------------------------------

function Eqx_UpdateMasks (options)

	local showItemLevel =  (options and options.showItemLevel) and true or false;

	Eqx_Init();

	-- analyze item levels

	local high = 0;
	local low  = 100000;
	local hasMid  = false;

	for x, slot in pairs(sinfo) do
		local equippedItemLink = GetInventoryItemLink("player",x);
		if (equippedItemLink and not slot.isCosmetic) then
			local iLevel = ItemUpgradeInfo:GetUpgradedItemLevel(equippedItemLink);

			if iLevel and iLevel > high then
				if (high > low) then
					hasMid = true;
				end
				high = iLevel;
			end

			if iLevel and iLevel < low then
				if (low < high) then
					hasMid = true;
				end
				low = iLevel;
			end
		end
	end

	local selectedSetID = PaperDollEquipmentManagerPane.selectedSetID

	local items, ignoreSlots;

	if (selectedSetID) then
		local selectedSetName = C_EquipmentSet.GetEquipmentSetInfo(selectedSetID)
		items = GetEquipmentSetItemIDs(selectedSetName)
		ignoreSlots = GetEquipmentSetIgnoreSlots(selectedSetName)
	end

	-- hide/show the overlays

	for x, slot in pairs(sinfo) do
		local equippedItemLink = GetInventoryItemLink("player",x);
		local equippedItemID   = zc.ItemIDfromLink (equippedItemLink);

		if (items == nil or (ignoreSlots and ignoreSlots[x]) or items[x] == 1 or items[x] == tonumber(equippedItemID)) then
			slot.tex:Hide();
		else
			slot.tex:Show();
		end

		if (showItemLevel and equippedItemLink) then
			local iLevel = ItemUpgradeInfo:GetUpgradedItemLevel(equippedItemLink);

			if (iLevel == high) then
				slot.text:SetTextColor(.5, 1, 0);
			elseif (iLevel == low and hasMid) then
				slot.text:SetTextColor(1, 0.5, 0.5);
			else
				slot.text:SetTextColor(1, 1, 1);
			end

			slot.text:SetText(iLevel);
			slot.text:Show();
		else
			slot.text:Hide();
		end
	end
end

-----------------------------------------

function Eqx_HideAllMasks ()

	Eqx_Init();

	local x;
	for _, slot in pairs(sinfo) do
		slot.tex:Hide();
		slot.text:Hide();
	end
end

-----------------------------------------

function Eqx_GearManagerDialog_OnShow()

	local numSets = GetNumEquipmentSets();
	local x, items, n, setname, i;

	local mm = {};

	for x = 1, numSets do
		setname = GetEquipmentSetInfo (x)
		items = GetEquipmentSetItemIDs (setname);

		mm[x] = {setid=x, mismatches=0, matches=0};

		for n = 1, #items do
			local equippedItemLink = GetInventoryItemLink("player",n);
			local equippedItemID   = zc.ItemIDfromLink (equippedItemLink);

			if (items[n] == 1) then
				-- do nothing
			elseif (items[n] == tonumber(equippedItemID)) then
				mm[x].matches = mm[x].matches + 1;
			else
				mm[x].mismatches = mm[x].mismatches + 1;
			end
		end
	end

	local best;

	for i = 1, #mm do

		if (best == nil) then
			best = i;
		else
			if (mm[i].mismatches < mm[best].mismatches) then
				best = i;
			elseif (mm[i].mismatches == mm[best].mismatches and mm[i].matches > mm[best].matches) then
				best = i;
			end
		end
	end

	if (best) then
		local dialog = PaperDollEquipmentManagerPane;
		dialog.selectedSetID = mm[best].setid;
		GearManagerDialog_Update();
	end

end


-----------------------------------------

function Eqx_Option_OnClick (elem)

end

-----------------------------------------

function Eqx_Refresh_Options (frame)


end

-----------------------------------------

function Eqx_Save_Options (frame)


	Eqx_BagsSetNeedsUpdate();

	--zz ("Equipsee options saved");
end

-----------------------------------------

function Eqx_ShowOptionTooltip (elem)

	local name = elem:GetName();
	local text;

	if (zc.StringContains (name, "Always_Show")) then
		text = "If this option is disabled, equipment set names will only be displayed in your bags and in the bank, when the character panel is open.";
	end

	if (text) then
		local titleFrame = _G[name.."_CB_Text"] or _G[name.."_Text"];

		local titleText = titleFrame and titleFrame:GetText() or "???";

		GameTooltip:SetOwner(elem, "ANCHOR_LEFT");
		GameTooltip:SetText(titleText, 0.9, 1.0, 1.0);
		GameTooltip:AddLine(text, 0.5, 0.5, 1.0, 1);
		GameTooltip:Show();
	end

end

-----------------------------------------

local gItemClasses;

-----------------------------------------

function Atr_GetAuctionClasses()

	if (gItemClasses == nil) then
		gItemClasses = { GetAuctionItemClasses() };
	end

	return gItemClasses;
end


-----------------------------------------

function Atr_ItemType2AuctionClass(itemType)

	local itemClasses = Atr_GetAuctionClasses();

	if #itemClasses > 0 then
	local itemClass;
		for x, itemClass in pairs(itemClasses) do
			if (zc.StringSame (itemClass, itemType)) then
				return x;
			end
		end
	end

	return 0;
end

--[[ Combuctor Support ]]--

local CombuctorItemSlot = Combuctor and Combuctor.ItemSlot
if CombuctorItemSlot then
	hooksecurefunc(CombuctorItemSlot, 'Update', Eqx_UpdateContainerSlot)
end

--[[ Bagnon Support ]]--

local BagnonItemSlot = Bagnon and Bagnon.ItemSlot
if BagnonItemSlot then
	hooksecurefunc(BagnonItemSlot, 'Update', Eqx_UpdateContainerSlot)
end

--[[ Baggins Support ]]--

if Baggins then
	hooksecurefunc(Baggins, 'UpdateItemButton',

		function (self, bag, button, bagID, slotID)
			if (bagID < 0 or bagID > 4) then
				--zz (bagID, slotID)
			end
			Eqx_UpdateContainerSlot (button)
		end
		)

end