local addonName, addon = ...

function addon:initWardrobeClassColours()
    if not addon.db.profile.wardrobeClassColours then return end

    function WardrobeCollectionFrame.ClassDropdown:Refresh()
    	local classFilter = self:GetClassFilter();
    	if not classFilter then
    		return;
    	end

    	local classInfo = C_CreatureInfo.GetClassInfo(classFilter);
    	if not classInfo then
    		return;
    	end

    	self:SetupMenu(function(dropdown, rootDescription)
    		rootDescription:SetTag("MENU_WARDROBE_CLASS");

    		local function IsClassFilterSet(classInfo)
    			return self:GetClassFilter() == classInfo.classID; 
    		end;

    		local function SetClassFilter(classInfo)
    			self:SetClassFilter(classInfo.classID); 
    		end;

    		for classID = 1, GetNumClasses() do
    			local classInfo = C_CreatureInfo.GetClassInfo(classID);
                local classColor = GetClassColorObj(classInfo.classFile) or HIGHLIGHT_FONT_COLOR;
    			rootDescription:CreateRadio(classColor:WrapTextInColorCode(classInfo.className), IsClassFilterSet, SetClassFilter, classInfo);
    		end
    	end);
    end

end
