function FilteredNamePlate.printTable(table , level, key)
  level = level or 1
  local indent = ""
  for i = 1, level do
    indent = indent.."  "
  end
  if key and key ~= "" then
    print(indent..key.." ".."=".." ".."{")
  else
    print(indent .. "{")
  end

  key = ""
  for k,v in pairs(table) do
     if type(v) == "table" then
        key = k
		print("key>>"..key)
        -- FilteredNamePlate.printTable(v, level + 1, key)
     else
        local content = string.format("%s%s = %s", indent .. "  ",tostring(k), tostring(v))
      print(content)
      end
  end
  print(indent .. "}")
end

function FilteredNamePlate.insertATabValue(tab, value)
    local isExist = false;
    for pos, name in ipairs(tab) do
        if (name == value) then
            isExist = true;
        end
    end
    if not isExist then table.insert(tab, value) end;
end

function FilteredNamePlate.removeATabValue(tab, value)
    for pos, name in ipairs(tab) do
        if (name == value) then
            table.remove(tab, pos)
        end
    end
end

function FilteredNamePlate.testForUnitAdd(frame)
	if frame.UnitFrame then
		print("have this!")
		frame.TP_Carrier:SetScale(0.2)
	else
		print("cannot do this")
	end
end

local popup, popupText, popupAcceptBtn, popupCloseBtn

local closeFuncForOld = function(f)
    f:GetParent():Hide()
end


function FilteredNamePlate:ExportATab(str)
    if popFrame == nil then
        popFrame = CreateFrame("Frame", nil, UIParent) -- Recycle the popup frame as an event handler.
        popFrame:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 24, edgeSize = 16,
            insets = {left = 2, right = 2, top = 2, bottom = 2}}
        )
        popFrame:SetSize(400, 80)
        popFrame:SetPoint("CENTER", UIParent, "CENTER")
        popFrame:SetFrameStrata("DIALOG")
        popFrame:Hide()

        popupEditText = CreateFrame("EditBox", "exportEditBox", popFrame, "InputBoxTemplate")
        popupEditText:SetPoint("TOPLEFT", 0, 0)
        popupEditText:SetMultiLine(true)
        popupEditText:SetMaxLetters(99999)
        popupEditText:EnableMouse(true)
        popupEditText:SetAutoFocus(false)
        popupEditText:SetWidth(380)
        popupEditText:SetHeight(70)

        local scrollArea = CreateFrame("ScrollFrame", "ECSAboutScroll", popFrame, "UIPanelScrollFrameTemplate")
        scrollArea:SetPoint("TOPLEFT", popFrame, "TOPLEFT", 8, -30)
        scrollArea:SetPoint("BOTTOMRIGHT", popFrame, "BOTTOMRIGHT", -30, 8)
        scrollArea:SetScrollChild(popupEditText)
        popAccept = CreateFrame("Button", nil, popFrame)
        popAccept:SetSize(40, 40)
        popAccept:SetPoint("TOP", popFrame, "TOPRIGHT", -10, 35)
    end
    popAccept:SetScript("OnClick",
        function(f)
            popFrame:Hide()
        end)
    popAccept:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    popAccept:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    popupEditText:SetText(str)
    popFrame:Show()
end