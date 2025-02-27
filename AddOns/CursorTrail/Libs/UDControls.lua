local CONTROLS_VERSION = "2024-10-16"  -- Version (date) of this file.  Stored as "UDControls.VERSION".

--[[---------------------------------------------------------------------------
FILE:   UDControls.lua
DESC:   Adds functions to your addon's private data block that can be used
        to create various UI controls.
AUTHOR: UppyDan  (Credits: Large portions of this file are based on code from Mikord's "MSBT Options".)

REQUIREMENTS / DEPENDANCIES:
        The following files must be placed in your addon's folder ...
            - UDControls.lua
        Also, any icon artwork used in calls to CreateIconButton() must also
        be placed in your addon's folder.
        Finally, add UDControls.lua to your TOC file.

USAGE:  See examples at end of this comment block.
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
CHANGE HISTORY:
    Oct 16, 2024
        - Added SmallTooltip:Show(), SmallTooltip:Hide(), and SmallTooltip:SetTextColor().
        - Added anchor/relativeFrame/relativeAnchor/x/y parameters to ContextMenu:Open().
        - Minor changes to CreateColorSwatch().
        - Added support to MsgBox3() for sending a key to a visible message box so it
          can be forced to close a certain way if necessary to prevent data corruption.
                e.g.  MsgBox3("SendKey", "ESCAPE")
        - Updated MsgBox3() by changing its 'bShowAlertIcon' parameter into a 'boolFlags' string
          of space delimited StaticPopupDialog flags that can be set true (or false by putting
          a '-' character infront of the flag name).  See MsgBox3 examples.
    Oct 09, 2024
        - Added flashing scrollbar buttons in listboxes and dropdown menus when
          there are more lines above/below those being shown.
        - Scrollbar buttons now auto-repeat when held down.
        - Brightened scrollbars thumb texture.
        - Fixed dropdown bugs caused when using CDropDown.AddSeparator().
        - Improved Outline() so it makes perfect corners now.  The old implementation
          can still be used by specifying 'version=1' in the options parameter.
          Also add a new option parameter named "expand".
        - Added FillFrame() function.
        - Reduced the frame level of the [X] button from 501 to be just one level higher than its parent.
        - Added UDControls configuration parameters for changing behavior of ALL listboxes created afterwards:
            UDControls.kSetButtonFlashing   - Scrollbar button flashing mode for ALL listboxes.  (Default is true)
            UDControls.kButtonFlashAlpha    - Intensity of scrollbar button flashing.  (Default it 0.5)
            UDControls.kButtonFlashSecs     - Seconds between scrollbar button flashing.  (Default it 0.6)
        - Changed ContextMenu function names to start with upper-case letters (to be consistent with
          all other exposed function names in this file).
        - Minor adjustments to scrollbar position in listboxes and dropdown menus.
        - Minor loop optimization in CListBox.Refresh().
        - Fixed bug in CListBox.SelectNextItem() and CListBox.SelectPreviousItem().
        - Updated comments.
    Sep 25, 2024
        - Fixed LUA errors in Classic WoW 1.15.4 that were caused by the removal of
          the OptionsButtonTemplate and OptionsBoxTemplate templates from its API.
        - Added GetLabelWidth() to checkboxes.  (See CCheckBox.GetLabelWidth() .)
        - Added MsgBox3(), CCheckBox:Click().
        - Added support to MsgBox3() and MsgBox() for hooking "OnShow" and "OnHide" script
          functions by specifying their first three parameters like this ...
                MsgBox3("HookScript", "OnShow", function(self) print("MsgBox OnShow() called.") end
                MsgBox3("HookScript", "OnHide", function(self) print("MsgBox OnHide() called.") end
          Also can determine if a message box is being shown like this ...
                local isShown = MsgBox3("IsShown")
    Sep 15, 2024
        - Added CUtil.EnhanceFrameEdges(), CUtil.CreateContextMenu().
    Jul 24, 2024
        - Fixed GetMouseFocus() errors caused in WoW 11.0.  (Added CUtil.GetMouseFocus() and exported that function too.)
    Jun 25, 2024
        - Added CListBox.AddSeparator() and CDropDown.AddSeparator().
        - Changed listbox tooltips so they can optionally appear for disabled lines.
          To enable this behavior, set the listbox's "tooltipWhileDisabled" variable to true.
        - Fixed listbox tooltip refreshing when scrolling with mouse wheel.  Tooltips for listbox lines now
          refresh immediately when scrolling with the mouse wheel while hovering over a listbox line.
        - Changed CListBox.ClearSelection() so it also hides the highlight frame.
        - Renamed listbox's "lineHandler" variable to "createLineHandler".
        - Updated listbox and dropdown examples.
        - Changed dropdown's change handler so it also provides the selected item's text and index #.
        - Added CDropDown.SelectNextOrPrevious().
        - Consolidate all places that set tooltip info into one function, setTooltipInfo().
        - Consolidate all places that showed tooltips into one function, showTooltip().
        - Added SetTooltipTitleAndText() to controls in this file.
        - Added CListBox.Line_SetTooltipTitleAndText() for implementing different tooltips on each line of a listbox.
        - Added GameTooltip_SetTitleAndText() and Outline() functions.
        - Added SetMouseWheelStepSpeed() and SetMouseWheelDefault() to TextScrollFrame.
    Jun 11, 2024
        - Moved many local functions into "class" tables to avoid hitting the "200 local variables" limit.
          This change has no effect on the exposed interfaces.
          (See CListBox, CDropDown, CCheckBox, CButton, COptionsButton, CSlider, CGroupBox, CUtil.)
        - Disable listbox scrollbar's UP button if at top of list, or its DOWN button if at bottom of list.
        - Added CListBox.SetDynamicWheelSpeed() for scrolling listbox and dropdown contents based on mouse wheel speed.
        - Added CloseDropDowns().
        - Added bCallChangeHandler parameter to CDropDown functions that select an item.
        - Added support for custom click handling when a dropdown or colorswatch control is clicked with
          other mouse buttons.
        - Updated comments.
    May 28, 2024
        - Renamed this file to "UDControls.lua" (was "Controls.lua").
        - Added CONTROLS_VERSION, indicating the version (date) of this file.
        - Fixed dropdown height calculations so they no longer shrink so small they can't show any lines.
          (Occurred when the bottom of a dropdown menu went beyoond the bottom of the screen.)
        - Fixed dropdown menu tooltips.
        - Changed CreateGroupBox() title text to be left-justified.
        - Added CreateTextureButton().
        - Made CreateOptionButton() available.  Added an example for it.
        - Added tooltipAnchor to option buttons returned by CreateOptionButton().
        - Changed msgBox() default preferred index from 3 to 1.
        - Updated comments and examples.
        - Added CreateTexture_NEW(), CreateHorizontalDivider(), and TextSize object.
        - Added a close [X] button to the frame created by CreateTextScrollFrame().
        - Added support for right-clicking listbox lines.  See RegisterForClicks() in the listbox example.
        - Fixed minor problems with listbox scrollbars, including using mousewheel over them.
        - Changed CListBox.OnMouseWheel() so it scrolls by the slider's step size when it's changed to
          a value greater than one.  Otherwise, mousewheel scrolls by page size (as it did previously).
        - Added CListBox.SelectNextItem() and CListBox.SelectPreviousItem().
        - Removed Enable/Disable functions from the listbox.  Those functions are not working correctly,
          and are not necessary at the moment.
    Mar 06, 2024
        - Added SetBackColor()/GetBackColor() to the groupbox control, for changing its background color.
        - Added MsgBox().
        - Added a parameter to CDropDown.Sort() for optionally sorting while ignoring upper/lower case.
        - Fixed listbox so hovering or clicking over empty lines at the bottom of it do nothing, especially
          if another frame underneath the listbox processes "OnEnter", "OnLeave", or "OnClick" events.
        - Fixed CListBox.SelectItem() so the lower bounds no longer can be a negative number.
        - Fixed bugs in code and examples where CreateFontString() parameters were in the wrong order.
        - Updated listbox comments to include GetSelectedItemNumber() as an available function.
        - Added CListBox.SelectItemText() and CListBox.ClearSelection().
        - Updated local aliases to certain global variables for faster access to them.
    Jan 23, 2024
        - Updated example for customizing listbox lines.
        - Removed dropdown.listbox variable since it created cyclic references.
          Replaced it with dropdown:GetListBoxFrame(), which essentially does the
          same thing without causing cyclic references.  (Added CDropDown.GetListBoxFrame().)
        - Moved setpointFunc() to be a direct member of the dropdown object since
          it's listbox doesn't exist until after the dropdown is clicked.
        - Added vdt_dump() helper function.
    Jan 18, 2024
        - Updated color picker functionality to support the API changes in WoW 10.2.5.
        - Added DisplayAllFonts() for use by developers.
    Aug 13, 2023
        - Modified CreateListBox() to accept a parameter for creating a listbox border.
        - Added a ListBox example.
        - Added GetSelectedItemNumber() to listboxes.
        - Updated CListBox.SelectItem() with a 'bScrollIntoView' parameter to
          automatically scroll the selected item into view.
        - Added a smart delay to CListBox.ScrollSelectionIntoView() and
          TextScrollFrame's SetVerticalScroll() in case they are called shortly after
          the control was created.  This gives the control enough time to fully initialize
          itself so scrolling, and the scrollbar thumb position, work properly.
        - Uncommented CreateIconButton() functionality.
    Aug 03, 2023
        - Renamed instances of "Checkbox", "Listbox", "Groupbox", "Editbox" to
          use the more common upper-casing found in other addons.
    Aug 02, 2023
        - Added setpointFunc to the dropdown.listbox variable, for changing the
          alignment of a dropdown's listbox relative to its editbox part.
        - Fixed dropdown Enable() and Disable() so they affect the fullWidthButton variable.
    Jul 22, 2023
        - Added handleGlobalMouseClick() to handle closing dropdowns when users
          click somewhere else while one is open.
        - Added CreateGroupBox().
        - Renamed some internal variables.

    Jul 09, 2023
        - Updated CDropDown.AddItem() with a parameter to prevent adding duplicate items.
          (e.g. dropdown:AddItem(name, nil, true) adds 'name' only if it doesn't exist.)
          Updated CDropDown.RemoveItem() so it works with text as well as an ID.
          Improved performance of CDropDown.ClearSelection().

    Jun 30, 2023
        - Original version.
-------------------------------------------------------------------------------

================================[ INTERFACES ]=================================
~~~~~~~~~~~~~~~
    Creator
   Functions
~~~~~~~~~~~~~~~

        CreateCheckBox()        - Returns a CheckBox object.
        CreateColorSwatch()     - Returns a ColorSwatch object.
        CreateContextMenu()     - Returns a ListBox object that behaves as a context menu.
        CreateDropDown()        - Returns a DropDown object.
        CreateGroupBox()        - Returns a group box frame.
        CreateIconButton()      - Returns a standard button frame.
        CreateListBox()         - Returns a ListBox object.
        CreateOptionButton()    - Returns a standard button frame.
        CreateSlider()          - Returns a Slider object.
        CreateTextScrollFrame() - Returns a TextScrollFrame object.
        CreateTextureButton()   - Returns a standard button frame.
        DisplayAllFonts()       - Creates and shows a window of all game fonts. (For development use.)

        handleGlobalMouseClick() - (OPTIONAL) Register your addon for the GLOBAL_MOUSE_DOWN event, and
                                  call this function when it occurs.  Do this to close a dropdown when
                                  users click somewhere else while it is open.  (See dropdown example.)
                                  Ideally, register this event when your UI is shown, and unregister it
                                  when your UI is closed.  This will minimize event handling to just
                                  while the UI is open.
        MsgBox()                - Shows a window that displays a text message and up to two buttons
                                  with corresponding handler functions that can process custom data.

~~~~~~~~~~~~~~~
   CheckBox
~~~~~~~~~~~~~~~

    Functions:
        Click()
        Configure()
        Disable()
        Enable()
        GetChecked()
        GetLabelWidth()
        SetChecked()
        SetClickHandler( function(isChecked) )
        SetLabel()
        SetTooltip()
        SetTooltipTitleAndText()

    Callbacks:
        clickHandler()      - Called when the checkbox is clicked.  See SetClickHandler().

    Variables:
        checkButton
        fontString

~~~~~~~~~~~~~~~~~~~
    ContextMenu
~~~~~~~~~~~~~~~~~~~

    Functions:
        Close()
        GetColor()
        GetBackColor()
        Open()
        SetColor()
        SetBackColor()

~~~~~~~~~~~~~~~~~~~
    ColorSwatch
~~~~~~~~~~~~~~~~~~~
    * See AceGUIWidget-ColorPicker.lua for future enhancement ideas.

    Functions:
        CloseColorPicker()
        Disable()
        Enable()
        GetColor()
        SetColor()
        SetColorChangedHandler()
        SetTooltip()
        SetTooltipTitleAndText()

    Variables:
        borderTexture
        oldDisableHandler
        oldEnableHandler

~~~~~~~~~~~~~~~
   DropDown
~~~~~~~~~~~~~~~

    Functions:
        AddItem( text, ID )  - ID can be a number or text.
        AddSeparator()
        Clear()
        ClearSelection()
        Configure()
        Disable()
        Enable()
        GetNumItems()
        GetSelectedID()
        GetSelectedIndex()
        GetSelectedText()
        HideSelections()
        RemoveItem()
        SelectID( ID )  - ID can be a number or string.
        SelectIndex( itemNum )  - itemNum starts at 1, not 0.
        SelectNext()
        SelectNextOrPrevious( bNext )
        SelectPrevious()
        SelectText()
        SetChangeHandler( function(thisDD, selectedID, selectedText, selectedIndex) )
        SetBackdropBorderColor()
        SetBackdropColor()
        SetButtonFlashing()     - Enables/disables scrollbar button flashing for the dropdown list.
        SetLabel()
        SetListBoxHeight()
        SetListBoxWidth()
        SetTooltip()
        SetTooltipTitleAndText()
        Sort()

    Callbacks:
        changeHandler()     - Called when one of the dropdown's options is selected.  See SetChangeHandler().

    Variables:
        buttonFrame
        items
        itemIDs
        listbox             - See the ListBox section.
        listboxHeight
        selectedItem        - Selected item's index #.
        setpointFunc

~~~~~~~~~~~~~~~
   ListBox
~~~~~~~~~~~~~~~

    Functions:
        AddItem( text, bScrollIntoView )
        AddSeparator()
        Clear()
        ClearSelection()
        Configure()
        ConfigureAutoRepeat()   - Configures auto-repeat rate and initial delay for ALL listboxes.
        ConfigureFlashing()     - Configures scrollbar button flashing rate and intensity for a listbox.
        Disable()
        Enable()
        GetItem()
        GetLine()
        GetNumItems()
        GetNumLines()
        GetOffset()
        GetSelectedItem()       - Returns selected item (text).
        GetSelectedItemNumber() - Returns the selected line number.
        Line_SetTooltipTitleAndText()   - Sets a tooltip title and text for a specific line of a listbox.
        Refresh()
        RemoveItem()
        SetButtonFlashing()     - Enables/disables scrollbar button flashing for a listbox.
        SetClickHandler( function(thisLB, line, value, mouseButton, bDown) )
        SetCreateLineHandler( function(thisLB) )
        SetDisplayHandler( function(thisLB, line, value, isSelected) )
        SetDynamicWheelSpeed()
        SetOffset()
        SelectItem( itemNumber, bScrollIntoView )  - Selects the specified item number.
        SelectItemText( text, bScrollIntoView )    - Selects the item matching the specified text.
        SelectNextItem()
        SelectPreviousItem()

    Callbacks:
        clickHandler()      - Called when a line in the listbox is clicked.  See SetClickHandler().
        displayHandler()    - Called when a line is being displayed.  See SetDisplayHandler().
        createLineHandler() - Called when a new line needs to be created.  See SetCreateLineHandler().

    Variables:
        disabledLineAlpha   - The alpha level for disabled lines.  (Default is 0.4)
        displayFrame        - Area where listbox contents is displayed.  (Excludes scrollbar.)
        sliderFrame         - Scrollbar for the listbox.
        upButton            - Scrollbar's up button.
        downButton          - Scrollbar's down button.
        highlightFrame      - For highlighting the selected line.
        items               - All the data that can be displayed by the listbox.
        lines               - The data lines that are visible (within the height of the listbox).
                              Each line can have its own tooltip.  (See listbox example below.)
            lines[i]:SetTooltip(text, anchor)                    - Sets tooltip text for a line in the listbox.
            lines[i]:SetTooltipTitleAndText(title, text, anchor) - Sets tooltip title and text for a line in the listbox.
        lineCache           - Contains lines that that will no longer fit on the page because the listbox
                              height was reduced.  These lines are reused the next time a new line is "created".
        selectedItem        - Selected item's index #.
        separatorLeft       - Left side offset for separator lines.  (Typically a positive number.)
        separatorRight      - Right side offset for separator lines.  (Typically a negative number.)
        tooltipWhileDisabled - If true, shows tooltip even when the line is disabled.

~~~~~~~~~~~~~~~~~~~~~
    Option Button
~~~~~~~~~~~~~~~~~~~~~

    Functions:
        Configure()         - Sets the button's height, text, and optional tooltip.
        SetClickHandler( function(mouseButton, bDown) )
        SetLabel()          - Sets the button's text.
        SetTooltip()
        SetTooltipTitleAndText()

    Callbacks:
        clickHandler()      - Called when the button is clicked.  See SetClickHandler().

~~~~~~~~~~~~~~~
    Slider
~~~~~~~~~~~~~~~

    Functions:
        Configure()
        SetLabel()
        SetTooltip()
        SetTooltipTitleAndText()
        SetValueChangedHandler( function(value) )
        SetMinMaxValues()
        SetValueStep()
        GetValue()
        SetValue()
        Enable()
        Disable()

    Callbacks:
        valueChangedHandler()   - Called when the value of the slider is changed.  See SetValueChangedHandler().

    Variables:
        sliderFrame
        sliderFrame.tooltip         - Text to show when mouse is over this control.
        sliderFrame.tooltipAnchor   - Defaults to "ANCHOR_RIGHT".
        labelFontString
        labelText

~~~~~~~~~~~~~~~~~~~~~
   TextScrollFrame
~~~~~~~~~~~~~~~~~~~~~

    Functions:
        AddText()
        GetNextVerticalPosition()
        SetMouseWheelDefault()
        SetMouseWheelStepSpeed()
        SetScrollTextBackColor()
        SetVerticalScroll()

    Variables:
        bg
        closeBtn
        nextVertPos
        scrollChild
        scrollFrame
        strings
        title

~~~~~~~~~~~~~~
   GroupBox
~~~~~~~~~~~~~~

    Functions:
        GetBackColor
        SetBackColor
        SetTitleBackColor
        UpdateTitleSize

    Variables:
        background
        title
        titleBackground


=================================[ EXAMPLES ]==================================
~~~~~~~~~~~~~~~~~~
 CheckBox Example
~~~~~~~~~~~~~~~~~~

    local kAddonFolderName, private = ...  -- First line of LUA file that will use these controls.
        .                                  -- (The variable names can be changed to anything you like.)
        .
        .

    local checkbox = private.UDControls.CreateCheckBox( YourOptionsFrame, "GameFontNormal" )
    checkbox:SetLabel("An example of a checkbox option.")
    checkbox:SetTooltip("Click me to change my value!")
    checkbox:SetPoint("TOPLEFT", YourOptionsFrame, "TOPLEFT", 10, -10)
    checkbox:SetPoint("RIGHT", YourOptionsFrame, "RIGHT", -10, 0)
    checkbox:SetClickHandler( function(thisCheckBox, isChecked)
                print( thisCheckBox.fontString:GetText() .." -->", isChecked and "ON" or "OFF" )
            end)

    checkbox:SetChecked(true)  -- Set its default state.


~~~~~~~~~~~~~~~~~~~~~
 ColorSwatch Example
~~~~~~~~~~~~~~~~~~~~~

    local kAddonFolderName, private = ...  -- First line of LUA file that will use these controls.
        .                                  -- (The variable names can be changed to anything you like.)
        .
        .

    -- Assume "YourObjectTexture" already exists and is the thing you want to change the color of.
    -- Something like this ...
    --    YourObjectFrame = CreateFrame("Frame", nil, UIParent)
    --    YourObjectTexture = YourObjectFrame:CreateTexture()

    local colorswatch = private.UDControls.CreateColorSwatch( YourOptionsFrame )
    colorswatch:SetPoint("TOPLEFT", YourOptionsFrame, "TOPLEFT", 16, -16)

    colorswatch:SetColor(1,0,0)  -- RGB (No alpha value.  Opacity slider will be hidden in the color picker.)
        - OR -
    colorswatch:SetColor(1,0,0, 1)  -- RGBA (Alpha value specified.  Opacity slider will be shown in the color picker.)

    colorswatch:SetColorChangedHandler(function(self) YourObjectTexture:SetVertexColor(self.r, self.g, self.b, self.a) end)


~~~~~~~~~~~~~~~~~~~~~
 ContextMenu Example
~~~~~~~~~~~~~~~~~~~~~

    local kAddonFolderName, private = ...  -- First line of LUA file that will use these controls.
        .                                  -- (The variable names can be changed to anything you like.)
        .
        .

    YourOptionsFrame.contextMenu = private.UDControls.CreateContextMenu(YourOptionsFrame)
    YourOptionsFrame.contextMenu:SetColor(0.24, 0.48, 0.6,  1)
    YourOptionsFrame.contextMenu:SetBackColor(0.5, 1, 1,  0.95)

    YourOptionsFrame:SetScript("OnMouseUp", function(self, mouseButton)
            if mouseButton == "RightButton" then
                -- Open context menu.
                local iconR = "Interface\\COMMON\\Indicator-Red"
                local iconG = "Interface\\COMMON\\Indicator-Green"

                local lines = {}
                local i = 1
                lines[i] = {isDivider=true}; i=i+1
                lines[i] = {text="Enabled Line",  icon=iconG, func=function() print("Enabled line clicked.") end}; i=i+1
                lines[i] = {text="Disabled Line", icon=iconR, disabled=true}; i=i+1
                lines[i] = {isDivider=true}; i=i+1

                self.contextMenu:Open( lines )
            else
                -- Close context menu.
                if self.contextMenu then self.contextMenu:Close() end
            end
        end)

    hooksecurefunc(private.UDControls, "handleGlobalMouseClick", function(mouseButton)
            -- Hide context menu when user clicks anywhere outside of it.
            if (mouseButton == nil or mouseButton == "LeftButton") then
                local cmenu = YourOptionsFrame.contextMenu
                if cmenu:IsShown() and not cmenu:IsMouseOver() then
                    cmenu:Close()
                end
            end
        end)



~~~~~~~~~~~~~~~~~~
 DropDown Example
~~~~~~~~~~~~~~~~~~

    local kAddonFolderName, private = ...  -- First line of LUA file that will use these controls.
        .                                  -- (The variable names can be changed to anything you like.)
        .
        .

    --************************** OPTIONAL **************************
    -- Add these lines to your main addon file to close our dropdown control
    -- when users click somewhere else while the dropdown is open.

        yourEventFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
        function yourEventFrame:GLOBAL_MOUSE_DOWN(button)
            private.UDControls.handleGlobalMouseClick(button)
        end

    -- Even better, don't call the RegisterEvent() line until the UI using our
    -- dropdown control is shown, and unregister the event when the UI is closed.
    -- Then there is no overhead at all while the UI is closed.
    -- For example:

        YourOptionsFrame:SetScript("OnShow", function(self)
                private.yourEventFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
            end)

        YourOptionsFrame:SetScript("OnHide", function(self)
                private.yourEventFrame:UnregisterEvent("GLOBAL_MOUSE_DOWN")
            end)
    --************************ END OPTIONAL ************************

    local dropdown = private.UDControls.CreateDropDown(YourOptionsFrame)
    ----dropdown.listbox:SetScale( 0.95 )  -- (Optional) Shrinks the dropdown.
    ----dropdown:SetBackdropBorderColor(0.7, 0.7, 0.0)  -- (Optional) Colorize the dropdown edges.
    dropdown:SetButtonFlashing( true )  -- (Optional) Flashes scrollbar buttons if more lines are above/below.

    dropdown:SetPoint("TOPLEFT", YourOptionsFrame, "TOPLEFT", 16, -16)
    dropdown:Configure(200, "Color Names:", "")  -- (width, label, tooltip_text)

    -- (Optional) Reposition label to the left of the dropdown.
    dropdown.labelFontString:ClearAllPoints()
    dropdown.labelFontString:SetPoint("RIGHT", dropdown, "LEFT", -1, 0)
    dropdown.labelFontString:SetJustifyH("RIGHT")

    dropdown:SetChangeHandler( function(thisDD, selectedID, selectedText, selectedIndex)
            print( "Selected Item ==>  Index: " .. (selectedIndex or "nil")
                   ..",  ID: " .. (selectedID or "nil")
                   ..",  Text: " .. (selectedText or "nil") )
        end)

    dropdown:AddItem("Red", 101)      -- or AddItem("Red") if not using ID#s.
    dropdown:AddItem("White", 102)    -- or AddItem("White") if not using ID#s.
    dropdown:AddItem("Blue", 103)     -- or AddItem("Blue") if not using ID#s.

    dropdown:SelectID(102)  -- Selects "White" by ID.  Requires ID#s when calling AddItem().
        -- OR --
    dropdown:SelectIndex(1)  -- Selects first item in the dropdown.
        -- OR --
    dropdown:SelectText("Blue") -- Selects "Blue".

    -- Show a tooltip while hovering over any part of the dropdown.
    dropdown.tooltip = "Some helpful info about this dropdown menu."
    dropdown.tooltipAnchor = "ANCHOR_TOP"  -- (Optional)

    -- (Optional) To change the size of the dropdown's listbox ...
    dropdown:SetListBoxWidth(250)
    dropdown:SetListBoxHeight( UIParent:GetHeight() * 0.5 )  -- Limit expanded height to 1/2 screen height.

    -- (Optional) To change the alignment of the dropdown's listbox (relative to its editbox ) ...
    dropdown.setpointFunc = function(listbox, editbox)
            -- LEFT alignment ...
            listbox:SetPoint("TOPLEFT", editbox, "BOTTOMLEFT", 2, 5)
                -- OR --
            -- CENTER alignment ...
            listbox:SetPoint("TOP", editbox, "BOTTOM", 0, 5)
            listbox:SetPoint("CENTER", editbox, "CENTER", 0, 0)
                -- OR --
            -- RIGHT alignment ...
            listbox:SetPoint("TOPRIGHT", editbox, "BOTTOMRIGHT", 0, 5)
        end


~~~~~~~~~~~~~~~~~~
 GroupBox Example
~~~~~~~~~~~~~~~~~~

    local kAddonFolderName, private = ...  -- First line of LUA file that will use these controls.
        .                                  -- (The variable names can be changed to anything you like.)
        .
        .

    local groupbox = private.UDControls.CreateGroupBox("Options", "TOPLEFT", YourOptionsFrame, "TOPLEFT", x, y, width, height)
    groupbox:SetBackColor(0.0, 0.0, 0.2, 1.0)   -- (Optional) Change groupbox background color.
    groupbox:SetBackdropBorderColor(0.6 ,0.6, 0.6) -- (Optional) Darken the border edges.
    groupbox.title:SetPoint("TOPLEFT", 10, 3)    -- (Optional) Reposition the title.
    groupbox.title:SetTextColor(1, 1, 1)         -- (Optional) Make the title text white.
    groupbox:SetTitleBackColor(0.15, 0.15, 0.15) -- (Optional) Give the title a solid background color.

    -- (Optional) Give the title text a stronger shadow.
    local shadowOfs = 2
    groupbox.title:SetShadowOffset(shadowOfs, -shadowOfs)
    groupbox:UpdateTitleSize( {left=3, right=shadowOfs-2, top=1, bottom=shadowOfs} )


~~~~~~~~~~~~~~~~~
 ListBox Example
~~~~~~~~~~~~~~~~~

    local listboxW = 150
    local listboxLineH = 20
    local listboxLinesPerPage = 5
    local listboxH = (listboxLineH * listboxLinesPerPage) + 5

    -- - - - - - - - - - - - - - - - - - - - - - - - - - --
    local function listboxCreateLine(thisLB)
        local line = CreateFrame("Button", nil, thisLB)

        -- Text.
        line.fontString = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line.fontString:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
        line.fontString:SetJustifyH("LEFT")
        line.fontString:SetPoint("LEFT", line, "LEFT", 4, 0)
        line.fontString:SetPoint("RIGHT", line, "RIGHT")
        line.fontString:SetPoint("TOP", line, "TOP")
        line.fontString:SetPoint("BOTTOM", line, "BOTTOM")

        -- (OPTIONAL) "Delete Item" button.
        local iconPath = "Interface\\Addons\\" .. kAddonFolderName .. "\\Media\\"
        line.deleteBtn = private.UDControls.CreateIconButton(line, listboxLineH-8, iconPath, "DeleteIcon", "DeleteIconHighlight")
        -- NOTE: Alternatively, you could call CreateTextureButton() in the previous line instead of CreateIconButton().
        line.deleteBtn:SetTooltip("Click to delete the item.")
        local rightInset = -3
        line.deleteBtn:SetHitRectInsets(0, rightInset, 0, 0)  -- (Left, Right, Top, Bottom)
        line.deleteBtn:SetPoint("RIGHT", line, "RIGHT", rightInset, 0)
        line.deleteBtn:SetClickHandler( function(thisBtn)
                local listboxLine = thisBtn:GetParent()
                local listbox = listboxLine.parentListBox
                local itemNum = listboxLine.itemNumber
                local itemText = listboxLine.fontString:GetText()
                listbox:RemoveItem(itemNum)
                listbox:Refresh()
                print("Deleted listbox item:", itemText)
            end)

        -- (OPTIONAL) Symbolic Icon.
        line.icon = line:CreateTexture(nil, "ARTWORK")
        line.icon:SetTexture(nil)
        line.icon:SetSize(16, 16)
        line.icon:SetPoint("RIGHT", line.deleteBtn, "LEFT", -1, 0)

        return line
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - --
    local function listboxDisplayLine(thisLB, line, value, isSelected)
        ----local color = isSelected and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR
        ----line.fontString:SetTextColor(color.r, color.g, color.b)
        line.fontString:SetText(value)

        -- Disable lines that contain the letter 'o'.
        local disabled = value:find("o")  -- Disable lines containing the letter 'o'.
        line:SetEnabled(not disabled)

        -- (Optional) Completely hide icon buttons on disabled lines.
        line.deleteBtn:SetShown(not disabled)
        line.icon:SetShown(not disabled)

        -- Update the line's tooltip.  (Example of how to simulate CListBox.SetToolTip().)
        if disabled then
            line:SetTooltip("Disabled because the line contains the letter 'o'.")
        else
            line:SetTooltip("Some useful info about this line.")
        end

        -- Show symbolic icon for lines containing the letter 'e'.
        if value:find("e") then
            line.icon:SetTexture("Interface\\COMMON\\FavoritesIcon")
        else
            line.icon:SetTexture(nil)
        end

        ----line.deleteBtn:SetShown(value ~= "Cat" and value ~= "Eagle") -- EXAMPLE of how to selectively hide listbox icon buttons.
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - --
    local function listboxOnClickLine(thisLB, line, value, mouseButton, bDown)
        print("Selected listbox item:", value)
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - --

    ----private.UDControls.kSetButtonFlashing = true  -- (Optional) All listboxes created after this
                                                      -- line will have flashing scrollbar buttons.
                                                      -- See also SetButtonFlashing().
    -- Create listbox.
    local listbox = private.UDControls.CreateListBox(YourOptionsFrame)
    listbox.tooltipWhileDisabled = true  -- (Optional)
    listbox:SetButtonFlashing( true )  -- (Optional) This listbox's scrollbar buttons will flash if more lines are above/below.
    listbox:Configure(listboxW, listboxH, listboxLineH)
	listbox:SetPoint("TOPLEFT", YourOptionsFrame, "TOPLEFT", 18, -35)
	listbox:SetCreateLineHandler( listboxCreateLine )
	listbox:SetDisplayHandler( listboxDisplayLine )
	listbox:SetClickHandler( listboxOnClickLine )

    -- Create listbox label.
    listbox.label = listbox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    listbox.label:SetText("Animals:")
    listbox.label:SetPoint("BOTTOMLEFT", listbox, "TOPLEFT", 4, 2)

    -- Fill the listbox.  (Empty string is used to add a separator line, just as an example.)
    local animals = {"Dog","Cat","Horse","Cow","","Elephant","Lion","Zebra","Eagle","Snake","Fish","Penguin"}
	listbox:Clear()
	for index, value in pairs(animals) do
        if value == "" then
            listbox:AddSeparator()
        else
            listbox:AddItem( value )
        end
	end
    listbox:SelectItem(1)

    YourOptionsFrame.listbox = listbox


~~~~~~~~~~~~~~~~
 MsgBox Example
~~~~~~~~~~~~~~~~
    See the examples documented in the implementation of MsgBox().


~~~~~~~~~~~~~~~~~~~~~~~
 Option Button Example
~~~~~~~~~~~~~~~~~~~~~~~
    Note: An option button is a basic red button with yellow text (and optional tooltip).

    local optionBtn = private.UDControls.CreateOptionButton(YourOptionsFrame)
    optionBtn:Configure(24, "OB Text", "Optional OB Tooltip")
    optionBtn.tooltipAnchor = "ANCHOR_TOP"  -- (Optional)
    optionBtn:SetPoint("TOPLEFT", YourOptionsFrame, "TOPLEFT", 10, 10)
    optionBtn:RegisterForClicks("AnyDown", "AnyUp")  -- (Optional)
    optionBtn:SetClickHandler( function(thisBtn, mouseButton, bDown)
            print("Option button clicked.  (", mouseButton, bDown and "DOWN" or "UP", ")")
        end)


~~~~~~~~~~~~~~~~~~~~~~~~~
 TextScrollFrame Example
~~~~~~~~~~~~~~~~~~~~~~~~~

    local kAddonFolderName, private = ...  -- First line of LUA file that will use these controls.
        .                                  -- (The variable names can be changed to anything you like.)
        .
        .

    local tsf = private.UDControls.CreateTextScrollFrame(YourOptionsFrame, "*** Scroll Window Test ***", 333)

    local title = tsf.scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -4)
    title:SetText("General Info")

    local firstLine = tsf.scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    firstLine:SetPoint("TOP", title, "BOTTOM", 0, -1)
    firstLine:SetJustifyH("LEFT")  -- Specify this when using text with carriage returns in it.
    firstLine:SetText("This is the first line.\n  (Scroll way down to see the last!)")

    local footer = tsf.scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    footer:SetPoint("TOP", 0, -5000)
    footer:SetText("This is 5000 pixels below the top, so scrollChild automatically adjusts its height.")

        -- < OR > --

    local indent = 16 -- pixels
    tsf:AddText("General Info:", 0, 4, "GameFontNormalLarge")
    tsf:AddText("This is the first line.\n  (Scroll way down to see the last!)")
    tsf:AddText("|cffEE5500Line #2 is orange.|r", indent)
    tsf:AddText("This is line #3.  It is a very long line in order to test the .:.:.:. word wrap feature of the scroll frame.\n ", indent)
    tsf:AddText("This is 5000 pixels below the top, so scrollChild automatically adjusts its height.", 0, 5000)


-----
 FYI
-----
    SetTextureColor() / SetTextureBackgroundColor() == SetColorTexture()
                                                       Also see texture:SetVertexColor().

-------------------------------------------------------------------------------]]


local kAddonFolderName, private = ...
if private.UDControls then return end  -- Prevent multiple includes of this file.
private.UDControls = {}


--#############################################################################
-------------------------------------------------------------------------------
-- Aliases to Globals.
-------------------------------------------------------------------------------
--#############################################################################

local _  -- Prevent tainting global _ .
local assert = assert
local C_Timer = C_Timer
local ColorPickerFrame = ColorPickerFrame
local CreateFrame = CreateFrame
----local DevTools_Dump = DevTools_Dump
local GameTooltip = GameTooltip
local GetAddOnMetadata = GetAddOnMetadata or C_AddOns.GetAddOnMetadata
----local GetBuildInfo = GetBuildInfo
local GetMouseFoci = GetMouseFoci
local GetMouseFocus = GetMouseFocus
local GetTime = GetTime
local HIGHLIGHT_FONT_COLOR = HIGHLIGHT_FONT_COLOR
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local IsControlKeyDown = IsControlKeyDown
local math = math
local next = next
local NORMAL_FONT_COLOR = NORMAL_FONT_COLOR
----local OpacityFrameSlider = OpacityFrameSlider  -- WoW 10.2.5 and newer.
----local OpacitySliderFrame = OpacitySliderFrame  -- WoW 10.2 and older.
local pairs = pairs
local PlaySound = PlaySound
----local PlaySoundFile = PlaySoundFile
local print = print
----local select = select
----local SOUNDKIT = SOUNDKIT
local string = string
local table = table
----local tinsert = tinsert
local type = type
----local UIFrameFadeIn = UIFrameFadeIn
----local UIFrameFadeOut = UIFrameFadeOut
----local UIParent = UIParent
local unpack = unpack


-------------------------------------------------------------------------------
--[[                        Development Switches                             ]]
-------------------------------------------------------------------------------

----> Enable next 2 lines to find missing aliases to global things.  Reload afterwards to trigger errors.
--~     local _G = _G
--~     setfenv(1, private)  -- Everything after this uses our namespace rather than _G.


--#############################################################################
-------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------
--#############################################################################


-- Templates compatible with all versions of WoW.
local kGameTocVersion = select(4, GetBuildInfo())
local function isVanillaWoW() return (kGameTocVersion < 20000) end
local function isRetailWoW() return (kGameTocVersion >= 100000) end
local kMinVer_10_2_5 = (kGameTocVersion >= 100205)  -- WoW 10.2.5 or newer?

-- Other constants.
local kSeparatorLine = "|-"
----local kTitleLinePrefix = "|#"

-- Backdrop table to be reused for sliders.
local gSliderBackdrop

-- Emphasis shown when a listbox entry is moused over.
local gEmphasizeFrame

-- Container frame holding the listbox used by all dropdown controls.
local gDropDownListBoxFrame

-- Used for correctly calculating string widths.
local gCalcFontString

-- Height of lines in listboxes and dropdown menus.
local kListBoxLineHeight = 17  --DJUadded  (and changed from 20)

-- Customized Color Picker vars.
local gColorPickerAttributes
local gAssociatedColorSwatch
local kCustomizedTag = "customizedBy" .. kAddonFolderName
local kColorPickerDefaultHeight = kMinVer_10_2_5 and 210 or 200
local kColorPickerButtonWidth = kMinVer_10_2_5 and 150 or 138  -- Default width is 144.
local gColorPaletteFrame

-- Misc constants.
local kTexture_White8x8 = "Interface\\Buttons\\WHITE8X8"
local kScrollbarGlitchTime = 0.01 -- secs

local CUtil = {}  -- Forward declaration.


--#############################################################################
-------------------------------------------------------------------------------
-- Version independent color picker functions and variables.
-------------------------------------------------------------------------------
--#############################################################################


local gOpacitySlider = kMinVer_10_2_5 and OpacityFrameSlider or OpacitySliderFrame
assert(gOpacitySlider)
local gColorPickerOkayBtn = kMinVer_10_2_5 and ColorPickerFrame.Footer.OkayButton or ColorPickerOkayButton
assert(gColorPickerOkayBtn)
local gColorPickerCancelBtn = kMinVer_10_2_5 and ColorPickerFrame.Footer.CancelButton or ColorPickerCancelButton
assert(gColorPickerCancelBtn)
local gColorPickerWheel = kMinVer_10_2_5 and ColorPickerFrame.Content.ColorPicker.Wheel or ColorPickerWheel

-------------------------------------------------------------------------------
local function ColorPickerFrame_SetColorRGB(r, g, b)
    if kMinVer_10_2_5 then
        ColorPickerFrame.Content.ColorPicker:SetColorRGB(r, g, b)
    else  -- Older version.
        ColorPickerFrame:SetColorRGB(r, g, b)
    end
end

-------------------------------------------------------------------------------
local function OpacitySlider_GetValue()
    if kMinVer_10_2_5 then
        ----return OpacityFrameSlider:GetValue() --<BUG> Associated color swatch not updated when opacity slider changed.
        return ColorPickerFrame.Content.ColorPicker:GetColorAlpha()
    else  -- Older version.
        return OpacitySliderFrame:GetValue()
    end
end

-------------------------------------------------------------------------------
local function OpacitySlider_SetValue(opacity)
    if kMinVer_10_2_5 then
        ----return OpacityFrameSlider:SetValue(opacity) --<BUG> Associated color swatch not updated when opacity slider changed.
        return ColorPickerFrame.Content.ColorPicker:SetColorAlpha(opacity)
    else  -- Older version.
        return OpacitySliderFrame:SetValue(opacity)
    end
end


--#############################################################################
-------------------------------------------------------------------------------
-- Helper functions.
-------------------------------------------------------------------------------
--#############################################################################


-- ****************************************************************************
-- Does nothing.  i.e. noop()
-- ****************************************************************************
local function DoNothing() end

-- ****************************************************************************
-- Dumps a variable to the ViragDevTools addon, if it is loaded.
-- ****************************************************************************
local function vdt_dump(varValue, varDescription)  -- e.g.  vdt_dump(someVar, "Checkpoint 1")
    if _G.ViragDevTool_AddData then
        _G.ViragDevTool_AddData(varValue, varDescription)
    end
end


-- ****************************************************************************
-- Calls GetPoint() for the specified frame and returns a single table
-- containing all the parameters returned by that function.
-- ****************************************************************************
local function getPointTable(frame)
    return { frame:GetPoint() }
end


-- ****************************************************************************
-- Unpacks the point parameters in the supplied table (pointTable), and then
-- calls SetPoint() for the specified frame using those unpacked parameters.
-- ****************************************************************************
local function setPointTable(frame, pointTable)
    frame:ClearAllPoints()
    frame:SetPoint( unpack(pointTable) )
end


-- ****************************************************************************
-- Handles setting tooltip information for controls in this file.
-- ****************************************************************************
local function setTooltipInfo(frame, title, text, anchor)
    frame.tooltipTitle = title
    frame.tooltip = text
    frame.tooltipAnchor = anchor
end


-- ****************************************************************************
-- Handles showing the tooltips for controls in this file.
-- ****************************************************************************
local function showTooltip(frame, owner)  --DJUadded
    owner = owner or frame
    if (frame.tooltip) then
        GameTooltip:SetOwner(owner, frame.tooltipAnchor or "ANCHOR_RIGHT")
        if (frame.tooltipTitle) then
            CUtil.GameTooltip_SetTitleAndText(frame.tooltipTitle, frame.tooltip, true)
        else -- Tooltip doesn't have a title.
            GameTooltip:SetText(frame.tooltip, nil, nil, nil, nil, true) -- (text, r, g, b, a, wrap)
        end
    end
end


--#############################################################################
-------------------------------------------------------------------------------
-- ListBox functions.
-------------------------------------------------------------------------------
--#############################################################################

local CListBox = {}


-- ****************************************************************************
-- Shows the highlight frame over the passed line.
-- ****************************************************************************
function CListBox.ShowHighlight(thisLB, line)
    local highlight = thisLB.highlightFrame
    highlight:ClearAllPoints()
    highlight:SetParent(line)
    highlight:SetPoint("TOPLEFT")
    highlight:SetPoint("BOTTOMRIGHT")
    highlight:Show()

    if (gEmphasizeFrame:GetParent() == line) then gEmphasizeFrame:Hide() end
end


-- ****************************************************************************
-- Shows or hides the scroll bar and resizes the display area as necessary.
-- ****************************************************************************
function CListBox.ShowHideScrollBar(thisLB)
    -- Show or hide the scroll bar if there are more items than will fit on the page.
    local display = thisLB.displayFrame
    local slider = thisLB.sliderFrame
    local dx = -1*slider:GetWidth()
    if not thisLB.bHideBorder then  -- Showing listbox border?
        dx = dx - (2*thisLB.margin)
    end

    if (#thisLB.items <= #thisLB.lines) then
        slider:Hide()
        display:SetPoint("BOTTOMRIGHT")
    else
        --DJUremoved:  display:SetPoint("BOTTOMRIGHT", display:GetParent(), "BOTTOMRIGHT", dx, 0)
        display:SetPoint("BOTTOMRIGHT", thisLB, "BOTTOMRIGHT", dx, 0)  --DJUchanged (see previous line)
        slider:Show()
    end
end


-- ****************************************************************************
-- Returns whether the listbox is fully configured.
-- ****************************************************************************
function CListBox.IsConfigured(thisLB)
    return thisLB.configured and thisLB.createLineHandler and thisLB.displayHandler
end


-- ****************************************************************************
-- Returns the current offset.
-- ****************************************************************************
function CListBox.GetOffset(thisLB)  -- Returned offset is 0-based.
    return math.floor( thisLB.sliderFrame:GetValue()+0.5 ) -- Round off in case SetObeyStepOnDrag(false) is set.  --DJUchanged
end


-- ****************************************************************************
-- Returns the current offset.
-- ****************************************************************************
function CListBox.SetOffset(thisLB, offset)  -- 'offset' is 0-based.
    thisLB.sliderFrame:SetValue(offset)
end


-- ****************************************************************************
-- Called when the listbox needs to be refreshed.
-- ****************************************************************************
function CListBox.FlashButtons(thisLB)
    ----UDC_FlashCnt=(UDC_FlashCnt and UDC_FlashCnt+1 or 1); print( "FlashCnt:", UDC_FlashCnt) -- For debugging.
    ----local fadeSecs = 0.3
    ----if fadeSecs > thisLB.buttonFlashSecs then fadeSecs = thisLB.buttonFlashSecs end
    CListBox.buttonFlashState = not CListBox.buttonFlashState
    for i = 1, 2 do
        local btn = (i == 1) and thisLB.upButton or thisLB.downButton

        -- Flash button glow.
        btn.glow:SetShown( btn:IsEnabled() and CListBox.buttonFlashState or false )

        ------ Fade button glow in/out.
        ----if btn:IsEnabled() then
        ----    btn.glow:Show()
        ----    if CListBox.buttonFlashState then
        ----        UIFrameFadeIn(btn.glow, fadeSecs, 0, thisLB.buttonFlashAlpha)
        ----    else
        ----        UIFrameFadeOut(btn.glow, fadeSecs, thisLB.buttonFlashAlpha, 0)
        ----    end
        ----else
        ----    btn.glow:Hide()
        ----end
    end
end


-- ****************************************************************************
-- Creates a ticker for flashing listbox scrollbar buttons (when more data is above/below).
-- ****************************************************************************
function CListBox.startButtonFlasher(thisLB)
    if thisLB.buttonFlashEnabled and not thisLB.buttonFlashTicker then
        CListBox.buttonFlashState = nil
        thisLB.buttonFlashTicker = C_Timer.NewTicker( thisLB.buttonFlashSecs, function()
                    CListBox.FlashButtons(thisLB)  -- Call repeatedly.
                end)

        local shortDelay = 0.02
        if thisLB.buttonFlashSecs > shortDelay * 2 then
            C_Timer.After(shortDelay, function() CListBox.FlashButtons(thisLB) end)  -- Call "immediately".
        end
    end
end


-- ****************************************************************************
-- Stops the ticker for flashing listbox scrollbar buttons.
-- ****************************************************************************
function CListBox.stopButtonFlasher(thisLB)
    if thisLB.buttonFlashTicker then
        thisLB.buttonFlashTicker:Cancel()
        thisLB.buttonFlashTicker = nil
        thisLB.upButton.glow:Hide()
        thisLB.downButton.glow:Hide()
        CListBox.buttonFlashState = nil
    end
end


-- ****************************************************************************
-- Enables/disables flashing scrollbar buttons for the specified listbox.
-- ****************************************************************************
function CListBox.SetButtonFlashing(thisLB, enabled)
    thisLB.buttonFlashEnabled = enabled
    if not enabled then
        CListBox.stopButtonFlasher(thisLB)
    end
end


-- ****************************************************************************
-- Configures scrollbar flashing rate and intensity for the specified listbox.
-- EXAMPLE:  listbox:ConfigureFlashing(1.0, 0.5)  -- (Full intensity every half sec.)
-- ****************************************************************************
function CListBox.ConfigureFlashing(thisLB, buttonFlashAlpha, buttonFlashSecs)
    local udcontrols = private.UDControls
    buttonFlashAlpha = buttonFlashAlpha or udcontrols.kButtonFlashAlpha
    buttonFlashSecs = buttonFlashSecs or udcontrols.kButtonFlashSecs
    assert(buttonFlashAlpha >= 0.0 and buttonFlashAlpha <= 1.0)
    assert(buttonFlashSecs > 0)

    thisLB.buttonFlashSecs = buttonFlashSecs
    thisLB.buttonFlashAlpha = buttonFlashAlpha
    thisLB.upButton.glow:SetAlpha( buttonFlashAlpha * 0.8 )  -- Make top button glow less bright/annoying.
    thisLB.downButton.glow:SetAlpha( buttonFlashAlpha )
end


-- ****************************************************************************
-- Configures scrollbar button auto-repeat rate and initial delay for ALL listboxes.
-- Auto-repeat occurs when a scrollbar button is held down.
-- (Initial delay seconds = autoRepeatDelayCount * autoRepeatSecs)
-- EXAMPLE:  listbox:ConfigureAutoRepeat(0.2, 2)
-- ****************************************************************************
function CListBox.ConfigureAutoRepeat(thisLB, autoRepeatSecs, autoRepeatDelayCount)
    autoRepeatSecs = autoRepeatSecs or 0.075
    autoRepeatDelayCount = autoRepeatDelayCount or 4
    assert(autoRepeatSecs > 0)
    assert(autoRepeatDelayCount > 0)
    CListBox.autoRepeatSecs = autoRepeatSecs
    CListBox.autoRepeatDelayCount = autoRepeatDelayCount
end

CListBox.ConfigureAutoRepeat()  -- Initialize auto-repeat variables for ALL listboxes.


-- ****************************************************************************
-- Called when the listbox needs to be refreshed.
-- ****************************************************************************
function CListBox.Refresh(thisLB)
    -- Don't do anything if the listbox isn't configured.
    if (not CListBox.IsConfigured(thisLB)) then return end

    -- Handle scroll bar showing / resizing.
    CListBox.ShowHideScrollBar(thisLB)

    -- Hide the highlight.
    thisLB.highlightFrame:Hide()

    -- Show or hide the correct lines depending on how many items there are and
    -- apply a highlight to the selected item.
    local selectedItem = thisLB.selectedItem
    local isDropDownListBox = (gDropDownListBoxFrame and thisLB == gDropDownListBoxFrame.listbox)
    local lineOffset = CListBox.GetOffset(thisLB)
    for lineNum, line in ipairs(thisLB.lines) do
        if (lineNum > #thisLB.items) then
            line:Hide()
            line.invisibleLine:Hide()
        else
            line.itemNumber = lineNum + lineOffset
            line:Show()

            local value = thisLB.items[ line.itemNumber ]
            local lineText
            if isDropDownListBox then
                -- Get the line's text from the dropdown variable (not the listbox variable).
                lineText = gDropDownListBoxFrame.dropdown.items[ line.itemNumber ]
            else
                lineText = value
            end

            local isSeparator = (lineText == kSeparatorLine)
            if isSeparator then
                local thick = math.max(1, thisLB.lineHeight * 0.1)
                line.separatorLine:SetThickness(thick)
                line.tooltip = nil
            end

            line:SetEnabled( not isSeparator )
            line.separatorLine:SetShown( isSeparator )
            line:SetShown( not isSeparator )
            ----print("CListBox.Refresh(): ", lineNum, line.lineNumber, line.fontString:GetText(), line.invisibleLine:IsShown() and " <COVERED>" or "") -- For debugging.

            -- Move the highlight to the selected line and show it.
            local isSelected = (selectedItem == line.itemNumber)
            if isSelected then
                CListBox.ShowHighlight(thisLB, line)
            end

            -- Call the display handler.
            if (thisLB.displayHandler and not isSeparator) then
                thisLB:displayHandler(line, value, isSelected)
            end

            line.invisibleLine:SetShown( not line:IsEnabled() )  -- Covers disabled lines so tooltips still work).
        end
    end

    -- Disable top scroll button if at top of list, or bottom button if at bottom of list.
    local scrollPos = thisLB.sliderFrame:GetValue()
    local minPos, maxPos = thisLB.sliderFrame:GetMinMaxValues()
    local enableUP = scrollPos > minPos
    local enableDOWN = scrollPos < maxPos
    thisLB.upButton:SetEnabled( enableUP )
    thisLB.downButton:SetEnabled( enableDOWN )

    -- Flash scroll button(s) if more lines are above/below those being shown.
    if enableUP or enableDOWN then
        CListBox.startButtonFlasher(thisLB)
    elseif thisLB.buttonFlashTicker then
        CListBox.stopButtonFlasher(thisLB)
    end

    ----if thisLB.bMoreIndicators then  --DJUadded...  For use with CListBox.SetIndicators().
    ----    local scrollPos = thisLB.sliderFrame:GetValue()
    ----    local minPos, maxPos = thisLB.sliderFrame:GetMinMaxValues()
    ----    thisLB.moreAbove:SetShown( scrollPos > minPos )
    ----    thisLB.moreBelow:SetShown( scrollPos < maxPos )
    ----end
end


-- ****************************************************************************
-- Called when the listbox is scrolled up.
-- ****************************************************************************
function CListBox.ScrollUp(thisLB)
    local slider = thisLB.sliderFrame
    slider:SetValue(slider:GetValue() - slider:GetValueStep())
end


-- ****************************************************************************
-- Called when the listbox is scrolled down.
-- ****************************************************************************
function CListBox.ScrollDown(thisLB)
    local slider = thisLB.sliderFrame
    slider:SetValue(slider:GetValue() + slider:GetValueStep())
end


-- ****************************************************************************
-- Called when one of the lines in the listbox is clicked.
-- ****************************************************************************
function CListBox.OnClickLine(thisLine, mouseButton, bDown)  --DJUchanged
    local listbox = thisLine.parentListBox
    listbox.selectedItem = thisLine.lineNumber + CListBox.GetOffset(listbox)

    CListBox.ShowHighlight(listbox, thisLine)

    if (listbox.clickHandler) then
        listbox:clickHandler( thisLine, listbox.items[listbox.selectedItem], mouseButton, bDown )
    end
end


-- ****************************************************************************
-- Called when the mouse enters an enabled line.
-- ****************************************************************************
function CListBox.OnEnterLine(thisLine)
    ----print("CListBox.OnEnterLine(): ", thisLine.fontString:GetText(), thisLine:IsEnabled())
    local listbox = thisLine.parentListBox
    if (thisLine.itemNumber ~= listbox.selectedItem) then
        gEmphasizeFrame:ClearAllPoints()
        gEmphasizeFrame:SetParent(thisLine)
        gEmphasizeFrame:SetPoint("TOPLEFT")
        gEmphasizeFrame:SetPoint("BOTTOMRIGHT")
        gEmphasizeFrame:Show()
    end

    if (thisLine.tooltip) then showTooltip(thisLine) end
end


-- ****************************************************************************
-- Called when the mouse leaves an enabled line.
-- ****************************************************************************
function CListBox.OnLeaveLine(thisLine)
    ----print("CListBox.OnLeaveLine(): ", thisLine.fontString:GetText())
    gEmphasizeFrame:Hide()
    GameTooltip:Hide()
end


-- ****************************************************************************
-- Called when the mouse enters a disabled line.
-- ****************************************************************************
function CListBox.OnEnterInvisibleLine(thisLine)
    ----print("CListBox.OnEnterInvisibleLine(): ", thisLine.relativeLine.fontString:GetText(), thisLine.relativeLine:IsEnabled())
    local relativeLine = thisLine.relativeLine
    local listbox = thisLine.parentListBox
    if (listbox.tooltipWhileDisabled) then
        if (relativeLine.tooltip) then showTooltip(relativeLine, thisLine) end
    end
end


-- ****************************************************************************
-- Called when the mouse leaves a disabled line.
-- ****************************************************************************
function CListBox.OnLeaveInvisibleLine(thisLine)
    ----print("CListBox.OnLeaveInvisibleLine(): ", thisLine.relativeLine.fontString:GetText())
    GameTooltip:Hide()
end


-- ****************************************************************************
-- Called when the scroll up button is pressed.
-- ****************************************************************************
function CListBox.OnClickUp(thisBtn, mouseButton, bDown)
    if mouseButton ~= "LeftButton" then return end  -- Only process left button.

    local listbox = thisBtn:GetParent():GetParent()
    CListBox.ScrollUp(listbox)
    ----PlaySound(826)
end


-- ****************************************************************************
-- Called when the scroll down button is pressed.
-- ****************************************************************************
function CListBox.OnClickDown(thisBtn, mouseButton, bDown)
    if mouseButton ~= "LeftButton" then return end  -- Only process left button.

    local listbox = thisBtn:GetParent():GetParent()
    CListBox.ScrollDown(listbox)
    ----PlaySound(827)
end


-- ****************************************************************************
-- Called when the listbox line is enabled.
-- ****************************************************************************
function CListBox.OnEnableLine(thisLine)
    ----print("CListBox.OnEnableLine: ", thisLine.fontString:GetText())
    thisLine:SetAlpha(1.0)
    thisLine.invisibleLine:Hide()  -- Let 'thisLine' show tooltips.
end


-- ****************************************************************************
-- Called when the listbox line is disabled.
-- ****************************************************************************
function CListBox.OnDisableLine(thisLine)
    ----print("CListBox.OnDisableLine: ", thisLine.fontString:GetText())
    local listbox = thisLine.parentListBox
    thisLine:SetAlpha( listbox.disabledLineAlpha or 0.4 )
    if listbox.tooltipWhileDisabled then
        thisLine.invisibleLine:Show()  -- Let the invisible line show tooltips.
    end
end


-- ****************************************************************************
-- Pass in true to scroll listbox contents based mouse wheel speed.
-- ****************************************************************************
function CListBox.SetDynamicWheelSpeed(thisLB, bDynamicSpeed)  --DJUadded
    assert(bDynamicSpeed == nil or bDynamicSpeed == true or bDynamicSpeed == false)
    thisLB.bDynamicWheelSpeed = bDynamicSpeed
    if bDynamicSpeed then
        thisLB.sliderFrame:SetValueStep(1)
    end
end

-- ****************************************************************************
-- Called when the mouse wheel is scrolled in the display frame.
-- ****************************************************************************
function CListBox.OnMouseWheel(thisDisplay, delta)  --DJUchanged ...
    local listbox = thisDisplay:GetParent()
    local slider = listbox.sliderFrame
    local numLines = listbox.linesPerPage
    local scrollAmt

    if slider:GetValueStep() > 1 then  -- Use custom step size?
        scrollAmt = 1
    elseif IsControlKeyDown() then  -- Scroll by page size?
        scrollAmt = math.max(1, numLines-2)
    elseif listbox.bDynamicWheelSpeed then  -- Scroll based on wheel speed?
        if not listbox.lastWheelTime then listbox.lastWheelTime = 0 end
        local t = GetTime()  -- seconds
        local dt = t - listbox.lastWheelTime
        listbox.lastWheelTime = t

        if     dt <= 0.015 then scrollAmt = 5
        elseif dt <= 0.025 then scrollAmt = 3
        elseif dt <= 0.200 then scrollAmt = 2
        else scrollAmt = 1
        end

        scrollAmt = math.min(scrollAmt, numLines-1)
        ----print("scrollAmt:", scrollAmt, "  dt:", dt)
    else -- Scroll normally.
        scrollAmt = 1
    end

    local mouseFocus = CUtil.GetMouseFocus()
    if mouseFocus and mouseFocus.parentListBox and mouseFocus.parentListBox == listbox then
        ----print("LINE OnLeave:", mouseFocus.fontString:GetText(), mouseFocus:IsEnabled())
        mouseFocus:GetScript("OnLeave")(mouseFocus)  -- Calls CListBox.OnLeaveLine() .
    end

    -- Scroll.
    if (delta < 0) then
        for i = 1, scrollAmt do
            CListBox.ScrollDown(listbox)
        end
    elseif (delta > 0) then
        for i = 1, scrollAmt do
            CListBox.ScrollUp(listbox)
        end
    end

    mouseFocus = CUtil.GetMouseFocus()
    if mouseFocus and mouseFocus.parentListBox and mouseFocus.parentListBox == listbox then
        ----print("LINE OnEnter:", mouseFocus.fontString:GetText(), mouseFocus:IsEnabled())
        mouseFocus:GetScript("OnEnter")(mouseFocus)  -- Calls CListBox.OnEnterLine() .
    end
end


-- ****************************************************************************
-- Called when the scroll bar slider is changed.
-- ****************************************************************************
function CListBox.OnSliderChanged(thisSlider, value)
    CListBox.Refresh( thisSlider:GetParent() )
end


-- ****************************************************************************
-- Sets tooltip text for a specific line in the listbox.
-- ****************************************************************************
function CListBox.Line_SetTooltip(thisLine, tooltipText, tooltipAnchor)
    setTooltipInfo(thisLine, nil, tooltipText, tooltipAnchor)
end


-- ****************************************************************************
-- Sets tooltip title and text for a specific line in the listbox.
-- ****************************************************************************
function CListBox.Line_SetTooltipTitleAndText(thisLine, tooltipTitle, tooltipText, tooltipAnchor)
    setTooltipInfo(thisLine, tooltipTitle, tooltipText, tooltipAnchor)
end


-- ****************************************************************************
-- Creates a new line using the register create line handler.
-- ****************************************************************************
function CListBox.CreateLine(thisLB)
    -- Get a line from end of cache, if there are any.  Otherwise, call the
    -- registered line handler to create a new line.
    local lineCache = thisLB.lineCache
    local line = (#lineCache > 0) and table.remove(lineCache) or thisLB:createLineHandler()

    line.parentListBox = thisLB
    line:SetParent(thisLB.displayFrame)
    line:SetHeight(thisLB.lineHeight)
    line:ClearAllPoints()
    ----line:RegisterForClicks("LeftButtonUp", "RightButtonUp")   --DJUadded
    line:SetScript("OnClick", CListBox.OnClickLine)
    line:SetScript("OnEnter", CListBox.OnEnterLine)
    line:SetScript("OnLeave", CListBox.OnLeaveLine)
    line:SetScript("OnEnable", CListBox.OnEnableLine)
    line:SetScript("OnDisable", CListBox.OnDisableLine)

    line.SetTooltip = CListBox.Line_SetTooltip
    line.SetTooltipTitleAndText = CListBox.Line_SetTooltipTitleAndText

    local lines = thisLB.lines
    if (#lines == 0) then
        line:SetPoint("TOPLEFT", 0, -thisLB.margin)  --DJUchanged
        line:SetPoint("TOPRIGHT", 0, -thisLB.margin)  --DJUchanged
    else
        line:SetPoint("TOPLEFT", lines[#lines], "BOTTOMLEFT")
        line:SetPoint("TOPRIGHT", lines[#lines], "BOTTOMRIGHT")
    end

    if not line.invisibleLine then
        -- Create an invisible line over the line so we can still show tooltips while the line is disabled.
        line.invisibleLine = CreateFrame("Button", nil, thisLB)
        line.invisibleLine.parentListBox = thisLB
        line.invisibleLine:SetFrameStrata( line:GetFrameStrata() )
        line.invisibleLine:SetFrameLevel( line:GetFrameLevel()+10 )
        line.invisibleLine:SetScript("OnEnter", CListBox.OnEnterInvisibleLine)
        line.invisibleLine:SetScript("OnLeave", CListBox.OnLeaveInvisibleLine)

--~         --vvvvvvvvvvvvvvvvvvvvvvvvvv[ FOR DEBUGGING ]vvvvvvvvvvvvvvvvvvvvvvvvvv
--~         line.invisibleLine.bg = line.invisibleLine:CreateTexture()
--~         line.invisibleLine.bg:SetAllPoints()
--~         line.invisibleLine.bg:SetColorTexture(1, 0.4, 0.4,  0.2)
--~         --^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    end
    line.invisibleLine.relativeLine = line
    line.invisibleLine:ClearAllPoints()
    line.invisibleLine:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
    line.invisibleLine:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, 0)
    if not thisLB.tooltipWhileDisabled then
        line.invisibleLine:Hide()
    end

    if not line.separatorLine then
        line.separatorLine = line.invisibleLine:CreateLine(nil, "BACKGROUND", nil, 0)
        line.separatorLine:SetColorTexture(0.25, 0.25, 0.25, 0.5)
        local left = (thisLB.separatorLeft or 0) + 4
        local right = (thisLB.separatorRight or 0) - 4
        line.separatorLine:SetStartPoint("LEFT", left, 0)
        line.separatorLine:SetEndPoint("RIGHT", right, 0)
        line.separatorLine:Hide()
    end

    ----private.UDControls.Outline(line.invisibleLine, {r=0, g=1, b=0, a=1, thickness=2})  -- For debugging.
    ----private.UDControls.Outline(line, {r=1, g=0, b=0, a=1, thickness=1})  -- For debugging.

    lines[#lines+1] = line
    line.lineNumber = #lines
end


-- ****************************************************************************
-- Reconfigures the listbox if it was already configured.
-- ****************************************************************************
function CListBox.Reconfigure(thisLB, width, height, lineHeight)
    -- Don't allow negative widths.
    if (width < 0) then width = 0 end

    -- Setup container frame.
    thisLB:SetWidth(width)
    thisLB:SetHeight(height)

    -- Setup line calculations.
    thisLB.lineHeight = lineHeight
    thisLB.linesPerPage = math.floor(height / lineHeight)

    -- Resize the line height of existing lines.
    for _, line in ipairs(thisLB.lines) do
        line:SetHeight(thisLB.lineHeight)
    end

    -- Add lines if more will fit on the page and they are needed.
    local lines = thisLB.lines
    if (#thisLB.items > #lines) then
        while (#lines < thisLB.linesPerPage and #thisLB.items > #lines) do
            CListBox.CreateLine(thisLB)
        end
    end

    -- Remove and cache lines that will no longer fit on the page.
    local lineCache = thisLB.lineCache
    for x = thisLB.linesPerPage+1, #lines do
        lines[#lines]:Hide()
        lineCache[#lineCache+1] = table.remove(lines)
    end

    -- Setup slider frame.
    local slider = thisLB.sliderFrame
    slider:Hide()
    slider:SetMinMaxValues(0, math.max(#thisLB.items - #thisLB.lines, 0))
    slider:SetValue(0)

    CListBox.Refresh(thisLB)
end


-- ****************************************************************************
-- Configures the listbox.
-- ****************************************************************************
function CListBox.Configure(thisLB, width, height, lineHeight)
    -- Don't do anything if required parameters are invalid.
    if (not width or not height or not lineHeight) then return end

    if (CListBox.IsConfigured(thisLB)) then CListBox.Reconfigure(thisLB, width, height, lineHeight) return end

    -- Don't allow negative widths.
    if (width < 0) then width = 0 end

    -- Setup container frame.
    thisLB:SetWidth(width)
    thisLB:SetHeight(height)

    -- Setup slider frame.
    local slider = thisLB.sliderFrame
    slider:SetMinMaxValues(0, 0)
    slider:SetValue(0)

    -- Setup line calculations.
    thisLB.lineHeight = lineHeight
    thisLB.linesPerPage = math.floor(height / lineHeight)

    thisLB.configured = true
end


-- ****************************************************************************
-- Set the function to be called when a listbox line needs to be created.
-- The handler function must return a "Button" frame.
--      handler = function(thisLB)
-- ****************************************************************************
function CListBox.SetCreateLineHandler(thisLB, handler)
    thisLB.createLineHandler = handler
end


-- ****************************************************************************
-- Set the function to be called when a line is being displayed.
--      handler = function(thisLB, line, value, isSelected)
-- ****************************************************************************
function CListBox.SetDisplayHandler(thisLB, handler)
    thisLB.displayHandler = handler
end


-- ****************************************************************************
-- Set the function to be called when a line in the listbox is clicked.
--      handler = function(thisLB, line, value, mouseButton, bDown)
-- ****************************************************************************
function CListBox.SetClickHandler(thisLB, handler)
    thisLB.clickHandler = handler
end


-- ****************************************************************************
-- Adds the passed item to the listbox.
-- ****************************************************************************
function CListBox.AddItem(thisLB, newItem, bScrollIntoView)
    -- Don't do anything if the listbox isn't configured.
    if (not CListBox.IsConfigured(thisLB)) then return end

    -- Add the passed item to the items list.
    local items = thisLB.items
    items[#items + 1] = newItem

    --  Create a new line if the max number allowed per page hasn't been reached.
    local lines = thisLB.lines
    if (#lines < thisLB.linesPerPage) then
        CListBox.CreateLine(thisLB)
    end

    -- Set the new max offset value.
    local maxOffset = math.max(#items - #lines, 0)
    thisLB.sliderFrame:SetMinMaxValues(0, maxOffset)

    -- Make sure the newly added item is visible if the force flag is set.
    if (bScrollIntoView) then CListBox.SetOffset(thisLB, maxOffset) end

    CListBox.Refresh(thisLB)
end


-- ****************************************************************************
-- Adds a separator line to the listbox.  (i.e. Divider line.)
-- ****************************************************************************
function CListBox.AddSeparator(thisLB)
    CListBox.AddItem(thisLB, kSeparatorLine)
end


-- ****************************************************************************
-- Removes the passed item number from the listbox.
-- ****************************************************************************
function CListBox.RemoveItem(thisLB, itemNumber)
    -- Don't do anything if the listbox isn't configured.
    if (not CListBox.IsConfigured(thisLB)) then return end

    local items = thisLB.items
    table.remove(items, itemNumber)

    -- Set the new max offset value.
    thisLB.sliderFrame:SetMinMaxValues(0, math.max(#items - #thisLB.lines, 0))

    CListBox.Refresh(thisLB)
end


-- ****************************************************************************
-- Returns the number of items in the listbox.
-- ****************************************************************************
function CListBox.GetNumItems(thisLB)
    return #thisLB.items
end


-- ****************************************************************************
-- Returns the number of visible lines in the listbox.
-- ****************************************************************************
function CListBox.GetNumLines(thisLB)
    return math.min(#thisLB.lines, #thisLB.items)
end


-- ****************************************************************************
-- Sets the listbox offset so that the selected item is shown.
-- ****************************************************************************
function CListBox.ScrollSelectionIntoView(thisLB)  --DJUadded
    ----local delaySecs = 0.1
    ----if GetTime() - thisLB.creationTime < delaySecs then
    ----    -- Must delay executing this function until 0.1 secs after the listbox
    ----    -- was created.  Otherwise, the scrollbar's thumb position and/or listbox
    ----    -- contents do not scroll correctly.
    ----    C_Timer.After(delaySecs, function() CListBox.ScrollSelectionIntoView(thisLB) end)
    ----    return  -- Stop here.
    ----end

    ----for i, line in ipairs(thisLB.lines) do
    ----    if line:IsShown() and line.itemNumber == thisLB.selectedItem then
    ----        return  -- Done.  Line is already in view.
    ----    end
    ----end

    local lineNum = thisLB.selectedItem - CListBox.GetOffset(thisLB)
    if not thisLB.lines[lineNum] then
        CListBox.SetOffset(thisLB, thisLB.selectedItem - #thisLB.lines)
        CListBox.Refresh(thisLB)

        -- This next part fixes a glitch where the scrollbar's thumb position was sometimes below the scrollbar.
        if thisLB.sliderFrame:IsShown() and not thisLB.bGlitchFixed then  -- Only need to do this once.
            thisLB.bGlitchFixed = true
            local temp = thisLB.sliderFrame:GetValue()
            thisLB.sliderFrame:SetValue(0)
            C_Timer.After(kScrollbarGlitchTime, function() thisLB.sliderFrame:SetValue(temp) end) -- Restore pos.
        end
    end
end


-- ****************************************************************************
-- Selects the specified item number in the listbox.
-- If bCallClickHandler is true, this function also calls the listbox's click handler.
-- ****************************************************************************
function CListBox.SelectItem(thisLB, itemNumber, bScrollIntoView, bCallClickHandler)  --DJUadded bScrollIntoView, bCallClickHandler.
    -- Don't do anything if the listbox isn't configured.
    if (not CListBox.IsConfigured(thisLB)) then return end

    itemNumber = itemNumber or 0  --DJUadded
    if type(itemNumber) ~= "number" then itemNumber = 0 end  --DJUadded

    --DJUremoved:  thisLB.selectedItem = itemNumber <= #thisLB.items and itemNumber or 0
    if itemNumber < 0 or itemNumber > #thisLB.items then itemNumber = 0 end  --DJUadded
    thisLB.selectedItem = itemNumber  --DJUadded

    if bScrollIntoView then CListBox.ScrollSelectionIntoView(thisLB) end  --DJUadded

    -- Highlight the selected line if it's visible.
    local line = thisLB.lines[thisLB.selectedItem - CListBox.GetOffset(thisLB)]
    if (line) then
        CListBox.ShowHighlight(thisLB, line)

        -- Call click handler.
        if bCallClickHandler and thisLB.clickHandler then  --DJUadded
            thisLB:clickHandler(line, thisLB.items[thisLB.selectedItem], "LeftButton")  --DJUadded
        end
    end
end


-- ****************************************************************************
-- Clears the listbox selection (so nothing is selected).
-- ****************************************************************************
function CListBox.ClearSelection(thisLB)   --DJUadded
    CListBox.SelectItem(thisLB, 0)  -- Clears selection.
    thisLB.highlightFrame:Hide()
end


-- ****************************************************************************
-- Selects the specified item text in the listbox.
-- ****************************************************************************
function CListBox.SelectItemText(thisLB, text, bScrollIntoView)  --DJUadded
    -- Don't do anything if the listbox isn't configured.
    if (not CListBox.IsConfigured(thisLB)) then return end

    if text then
        local items = thisLB.items
        for i = 1, #items do
            if items[i] == text then
                return CListBox.SelectItem(thisLB, i, bScrollIntoView) -- SUCCESS.
            end
        end
    end

    CListBox.ClearSelection(thisLB)
end


-- ****************************************************************************
-- Returns the item for the specified item number from the listbox.
-- ****************************************************************************
function CListBox.GetItem(thisLB, itemNumber)
    return thisLB.items[itemNumber]
end


-- ****************************************************************************
-- Returns the selected item from the listbox.
-- ****************************************************************************
function CListBox.GetSelectedItem(thisLB)
    if (thisLB.selectedItem ~= 0) then return thisLB.items[thisLB.selectedItem] end
end


-- ****************************************************************************
-- Returns the selected item number for the listbox.  (0 means nothing selected.)
-- ****************************************************************************
function CListBox.GetSelectedItemNumber(thisLB)  --DJUadded
    return thisLB.selectedItem or 0
end


-- ****************************************************************************
-- Returns the specified line object from the listbox.
-- ****************************************************************************
function CListBox.GetLine(thisLB, lineNumber)
    local lines = thisLB.lines
    if (lineNumber <= #lines) then return lines[lineNumber] end
end


-- ****************************************************************************
-- Selects item after the currently selected item and returns true.
-- Returns false if last item is already selected.
-- (Scrolls selected line into view if necessary.)
-- ****************************************************************************
function CListBox.SelectNextItem(thisLB)  --DJUadded
    local itemNum = CListBox.GetSelectedItemNumber(thisLB)
    if itemNum < CListBox.GetNumItems(thisLB) then
        thisLB.bGlitchFixed = true -- Must prevent its timer from messing up our selection logic!
        CListBox.SelectItem(thisLB, itemNum+1, true, true)  -- Scrolls into view and calls click handler.
        return true
    end
    return false
end


-- ****************************************************************************
-- Selects item before the currently selected item and returns true.
-- Returns false if first item is already selected.
-- (Scrolls selected line into view if necessary.)
-- ****************************************************************************
function CListBox.SelectPreviousItem(thisLB)  --DJUadded
    local itemNum = CListBox.GetSelectedItemNumber(thisLB)
    if itemNum > 1 then
        thisLB.bGlitchFixed = true -- Must prevent its timer from messing up our selection logic!
        CListBox.SelectItem(thisLB, itemNum-1, true, true)  -- Scrolls into view and calls click handler.
        return true
    end
    return false
end


-- ****************************************************************************
-- Clears the listbox contents.
-- ****************************************************************************
function CListBox.Clear(thisLB)
    -- Don't do anything if the listbox isn't configured.
    if (not CListBox.IsConfigured(thisLB)) then return end

    local items = thisLB.items
    for k, v in ipairs(items) do
        items[k] = nil
    end

    thisLB.sliderFrame:SetMinMaxValues(0, 0)  -- Set the new max offset value.
    thisLB.selectedItem = 0
    CListBox.Refresh(thisLB)
end

---->>> DJUremoved.  These don't work right.  Would need to add calls to EnableMouse() for
----    the displayFrame, and calls to EnableMouseWheel() for the sliderFrame.  Additionally,
----    I think EnableMouseWheel() is needed on each line object, and possibly any icon buttons
----    the caller added to those lines.  A lot of work for a feature not needed at this time.
----    (IDEA: It might be easier to have a "blocker" frame that covers the listbox (to disable it.)
----
------ ****************************************************************************
------ Disables the listbox.
------ ****************************************************************************
----function CListBox.Disable(thisLB)
----    thisLB.displayFrame:EnableMouseWheel(false)
----    thisLB.sliderFrame:EnableMouse(false)
----    thisLB.upButton:Disable()
----    thisLB.downButton:Disable()
----end
----
----
------ ****************************************************************************
------ Enables the listbox.
------ ****************************************************************************
----function CListBox.Enable(thisLB)
----    thisLB.displayFrame:EnableMouseWheel(true)
----    thisLB.sliderFrame:EnableMouse(true)
----    thisLB.upButton:Enable()
----    thisLB.downButton:Enable()
----end


---->>> WORKS, but not really worth using more memory for this.
------ ****************************************************************************
------ Creates graphics for indicating more lines are above/below current scroll view.
------ Example (uses defaults):  listbox:SetIndicators( {} )
------ ****************************************************************************
----function CListBox.SetIndicators(thisLB, options)  --DJUadded
----    if not options then
----        thisLB.bMoreIndicators = nil
----        if thisLB.moreAbove then thisLB.moreAbove:Hide() end
----        if thisLB.moreBelow then thisLB.moreBelow:Hide() end
----        return  -- Done.
----    end
----
----    thisLB.bMoreIndicators = true
----    local r, g, b, a = options.r or 0.5, options.g or 0.5, options.b or 0.5, options.a or 1
----    local thickness = options.thickness or 1
----    local inset = options.inset or 1
----    local halfLen = (options.length or 50) / 2
----    local dx = 1
----
----    thisLB.moreAbove = thisLB.displayFrame:CreateLine(nil, "BACKGROUND", nil, 0)
----    thisLB.moreAbove:SetThickness(thickness)
----    thisLB.moreAbove:SetColorTexture(r, g, b, a)
----    thisLB.moreAbove:SetStartPoint("TOP", dx-halfLen, -inset-1)
----    thisLB.moreAbove:SetEndPoint("TOP", dx+halfLen, -inset-1)
----    thisLB.moreAbove:Hide()
----
----    inset = inset + 2
----    thisLB.moreBelow = thisLB.displayFrame:CreateLine(nil, "BACKGROUND", nil, 0)
----    thisLB.moreBelow:SetThickness(thickness)
----    thisLB.moreBelow:SetColorTexture(r, g, b, a)
----    thisLB.moreBelow:SetStartPoint("BOTTOM", dx-halfLen, inset)
----    thisLB.moreBelow:SetEndPoint("BOTTOM", dx+halfLen, inset)
----    thisLB.moreBelow:Hide()
----end


-- ****************************************************************************
-- Called when the listbox is hidden.
-- ****************************************************************************
function CListBox.OnHide(thisLB)
    CListBox.stopButtonFlasher(thisLB)
    if CListBox.autoRepeatTicker then
        CListBox.autoRepeatTicker:Cancel()
    end
end

-- ****************************************************************************
-- Called when a listbox scrollbar button is clicked down.
-- ****************************************************************************
function CListBox.Button_OnMouseDown(thisBtn, mouseButton)
    if mouseButton == "LeftButton" then
        local clistbox = CListBox
        if clistbox.autoRepeatTicker then
            clistbox.autoRepeatTicker:Cancel()
        end
        clistbox.autoRepeatCount = 0
        clistbox.autoRepeatTicker = C_Timer.NewTicker(clistbox.autoRepeatSecs, function()
            ----UDC_BtnRepCnt=(UDC_BtnRepCnt and UDC_BtnRepCnt+1 or 1); print( "BtnRepCnt:", UDC_BtnRepCnt) -- For debugging.
            clistbox.autoRepeatCount = clistbox.autoRepeatCount + 1
            if clistbox.autoRepeatCount >= clistbox.autoRepeatDelayCount then
                thisBtn.onClickHander(thisBtn, mouseButton, true)  -- Button down.
            end
        end)
    end
end

-- ****************************************************************************
-- Called when a listbox scrollbar button is released.
-- ****************************************************************************
function CListBox.Button_OnMouseUp(thisBtn, mouseButton)
    if mouseButton == "LeftButton" then
        local clistbox = CListBox
        if clistbox.autoRepeatTicker then
            clistbox.autoRepeatTicker:Cancel()
            clistbox.autoRepeatTicker = nil
            if clistbox.autoRepeatCount < clistbox.autoRepeatDelayCount then
                thisBtn.onClickHander(thisBtn, mouseButton, false)  -- Button up.
            end
            clistbox.autoRepeatCount = 0
        end
    else
        thisBtn.onClickHander(thisBtn, mouseButton, false)  -- Button up.
    end
end

-- ****************************************************************************
-- Called to create listbox scrollbar up/down buttons.  ('isUpButton' specifies which button to create.)
-- ****************************************************************************
function CListBox.CreateSliderButton(thisLB, thisSlider, buttonW, buttonH, isUpButton)
    local template = (isUpButton and "UIPanelScrollUpButtonTemplate") or "UIPanelScrollDownButtonTemplate"

    local button = CreateFrame("Button", nil, thisSlider, template)
    button:SetSize(buttonW, buttonH)
    button.isUpButton = isUpButton
    button.onClickHander = (isUpButton and CListBox.OnClickUp) or CListBox.OnClickDown

    -- Button glow.
    button.glow = button:CreateTexture(nil, "OVERLAY")
    button.glow:Hide()
    button.glow:SetTexture("Interface\\CHATFRAME\\ChatFrame")
    if isVanillaWoW() then
        button.glow:SetTexCoord(0, 1/4, 0, 1/4)  -- x1, x2, y1, y2
    else
        button.glow:SetTexCoord(0, 1/8, 0, 1/4)  -- x1, x2, y1, y2
    end
    button.glow:SetPoint("TOPLEFT", -4, 5)
    button.glow:SetPoint("BOTTOMRIGHT", 1, -3)

    -- Button scripts.
    button:SetScript("OnMouseDown", CListBox.Button_OnMouseDown)
    button:SetScript("OnMouseUp", CListBox.Button_OnMouseUp)

    return button
end

-- ****************************************************************************
-- Creates and returns a listbox object ready to be configured.
-- ****************************************************************************
local function CreateListBox(parent, bHideBorder)  --DJUadded 'bHideBorder' to this function.
    -- Create the frame used to emphasize the entry the mouse is over.
    if (not gEmphasizeFrame) then
        gEmphasizeFrame = CreateFrame("Frame")

        local texture = gEmphasizeFrame:CreateTexture(nil, "ARTWORK")
        texture:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
        texture:SetBlendMode("ADD")
        texture:SetPoint("TOPLEFT", gEmphasizeFrame, "TOPLEFT")
        texture:SetPoint("BOTTOMRIGHT", gEmphasizeFrame, "BOTTOMRIGHT")
    end

    -- Create container frame.
    local listbox = CreateFrame("Frame", nil, parent, (not bHideBorder and "InsetFrameTemplate") or nil)
    ----local listbox = CreateFrame("Frame", nil, parent, bHideBorder or "InsetFrameTemplate3")  -- Nice rect frame with thin bg.
    ----local listbox = CreateFrame("Frame", nil, parent, bHideBorder or "ThinBorderTemplate") -- Nice rect frame.  Just add color!
    ----local listbox = CreateFrame("Frame", nil, parent, bHideBorder or "GlowBoxTemplate") -- Bright yellow border with black-to-yellow gradient background.
    ----local listbox = CreateFrame("Frame", nil, parent, bHideBorder or "BackdropTemplate") --DJUadded
    ----if not bHideBorder then
    ----    listbox:SetBackdrop{  --DJUadded
    ----        ----bgFile = kTexture_White8x8,
    ----        bgFile ="Interface\\FrameGeneral\\UI-Background-Marble",
    ----        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    ----        insets = {left=3, right=3, top=2, bottom=3},  edgeSize=16,
    ----    }
    ----    ----listbox:SetBackdropColor(0,0,0, 1)  --DJUadded
    ----    ----listbox:SetBackdropBorderColor(0.9, 0.9, 0.0)  -- (Optional) Colorize the edges.  --DJUadded
    ----end

    listbox.bHideBorder = bHideBorder
    listbox.creationTime = GetTime()  --DJUadded
    listbox.autoRepeatCount = 0
    listbox.buttonFlashEnabled = private.UDControls.kSetButtonFlashing
    listbox:SetScript("OnHide", CListBox.OnHide)  --DJUadded

    -- Highlight frame.
    local highlight = CreateFrame("Frame")

    local texture = highlight:CreateTexture(nil, "ARTWORK")
    texture:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    texture:SetBlendMode("ADD")
    texture:SetPoint("TOPLEFT", highlight, "TOPLEFT")
    texture:SetPoint("BOTTOMRIGHT", highlight, "BOTTOMRIGHT")

    -- Create display area.
    local display = CreateFrame("Frame", nil, listbox)

    -- Prevent highlight changes or mouse clicks from doing anything over empty lines.
    display:SetScript("OnEnter", function(self) end)  -- Do nothing.  --DJUadded
    display:SetScript("OnLeave", function(self) end)  -- Do nothing.  --DJUadded
    display:SetScript("OnMouseDown", function(self) end)  -- Do nothing.  --DJUadded
    display:SetScript("OnMouseUp", function(self) end)  -- Do nothing.  --DJUadded

    -- Create slider (scrollbar) to track the position.
    local sliderWidth = 16
    local sliderButtonWidth = sliderWidth + 2
    local sliderButtonHeight = sliderWidth - 0.75

    local slider = CreateFrame("Slider", nil, listbox)
    slider:Hide()
    slider:SetWidth(sliderWidth)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetScript("OnValueChanged", CListBox.OnSliderChanged)

    -- Resize thumb texture to fit nicely inside our slider.
    slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    local thumb = slider:GetThumbTexture()
    thumb:SetVertexOffset(UPPER_LEFT_VERTEX,   2, -1.25)
    thumb:SetVertexOffset(LOWER_LEFT_VERTEX,   2,  1.25)
    thumb:SetVertexOffset(UPPER_RIGHT_VERTEX, -2, -1.25)
    thumb:SetVertexOffset(LOWER_RIGHT_VERTEX, -2,  1.25)

    -- Brighten the scrollbar thumb.
    local drawLayer, subLevel = thumb:GetDrawLayer()
    slider.thumbOverlay = slider:CreateTexture()
    slider.thumbOverlay:SetDrawLayer(drawLayer, subLevel+1)
    slider.thumbOverlay:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    slider.thumbOverlay:SetSize(sliderWidth-1, sliderWidth-1)
    slider.thumbOverlay:SetPoint("CENTER", thumb, "CENTER", -0.5, 0)
    slider.thumbOverlay:SetAlpha(0.75)
--~     slider.thumbOverlay2 = slider:CreateTexture()
--~     slider.thumbOverlay2:SetDrawLayer(drawLayer, subLevel+1)
--~     slider.thumbOverlay2:SetSize(12, 4)
--~     slider.thumbOverlay2:SetPoint("CENTER", thumb, "CENTER", -0.3, 0.5)
--~     slider.thumbOverlay2:SetColorTexture(0.7, 0.7, 0.0,  0.6)
--~     ----slider.thumbOverlay2:SetColorTexture(0.7, 0.7, 0.0,  0.4)

    slider.background = slider:CreateTexture(nil, "BACKGROUND")
    slider.background:SetPoint("TOPLEFT", 0, 0)
    slider.background:SetPoint("BOTTOMRIGHT", -1, 0)
    slider.background:SetColorTexture(0.06, 0.06, 0.06)

    local upButton = CListBox.CreateSliderButton(listbox, slider, sliderButtonWidth, sliderButtonHeight, true)
    local downButton = CListBox.CreateSliderButton(listbox, slider, sliderButtonWidth, sliderButtonHeight, false)

    -- Set scrollbar position.
    local dx = 0  -- Shifts scrollbar left/right while keeping all its parts aligned.
    local sliderButtonX = (sliderButtonWidth - sliderWidth) / 2  -- Centers button horizontally to slider.
    local sliderButtonYt, sliderButtonYb
    if bHideBorder then
        -- Listbox does not have borders.  (Probably for a dropdown menu.)
        listbox.margin = 0
        sliderButtonYt = 2.5
        sliderButtonYb = -6
        slider:SetPoint("RIGHT", listbox, "RIGHT", dx+7.3, 0)
        slider:SetPoint("TOP", listbox, "TOP", 0, sliderButtonYt - upButton:GetHeight() + 8)
        slider:SetPoint("BOTTOM", listbox, "BOTTOM", 0, sliderButtonYb + downButton:GetHeight() - 8.25)
    else
        -- Normal listbox with borders.
        listbox.margin = 2
        sliderButtonYt = -listbox.margin - 2.75
        sliderButtonYb = listbox.margin + 1.9

        slider:SetPoint("RIGHT", listbox, "RIGHT", -listbox.margin - 2 + dx, 0)
        slider:SetPoint("TOP", listbox, "TOP", 0, 3.3 - upButton:GetHeight())
        slider:SetPoint("BOTTOM", listbox, "BOTTOM", 0, downButton:GetHeight() - 4.5)
    end

    -- Set scrollbar button positions.
    upButton:SetPoint("TOP", listbox, "TOP", 0, sliderButtonYt)
    upButton:SetPoint("RIGHT", slider, "RIGHT", sliderButtonX, 0)
    downButton:SetPoint("BOTTOM", listbox, "BOTTOM", 0, sliderButtonYb)
    downButton:SetPoint("RIGHT", slider, "RIGHT", sliderButtonX, 0)

    -- Set display area position and size.
    display:SetPoint("TOPLEFT", listbox, "TOPLEFT", listbox.margin, -listbox.margin)
    display:SetPoint("BOTTOMRIGHT", listbox, "BOTTOMRIGHT", -listbox.margin, listbox.margin)

    -- Make it work with the mouse wheel.
    display:EnableMouseWheel(true)
    display:SetScript("OnMouseWheel", CListBox.OnMouseWheel)
    slider:EnableMouseWheel(true)  --DJUadded
    slider:SetScript("OnMouseWheel", CListBox.OnMouseWheel)  --DJUadded

    -- Extension functions.
    listbox.Configure               = CListBox.Configure
    listbox.ConfigureAutoRepeat     = CListBox.ConfigureAutoRepeat  --DJUadded
    listbox.ConfigureFlashing       = CListBox.ConfigureFlashing  --DJUadded
    listbox.SetButtonFlashing       = CListBox.SetButtonFlashing  --DJUadded
    listbox.SetCreateLineHandler    = CListBox.SetCreateLineHandler
    listbox.SetDisplayHandler       = CListBox.SetDisplayHandler
    listbox.SetClickHandler         = CListBox.SetClickHandler
    listbox.GetOffset               = CListBox.GetOffset
    listbox.SetOffset               = CListBox.SetOffset
    listbox.AddItem                 = CListBox.AddItem
    listbox.AddSeparator            = CListBox.AddSeparator  --DJUadded
    listbox.RemoveItem              = CListBox.RemoveItem
    listbox.GetItem                 = CListBox.GetItem
    listbox.GetSelectedItem         = CListBox.GetSelectedItem
    listbox.GetSelectedItemNumber   = CListBox.GetSelectedItemNumber  --DJUadded
    listbox.SelectItem              = CListBox.SelectItem  -- i.e. CListBox.SelectItemNumber()
    listbox.SelectItemText          = CListBox.SelectItemText  --DJUadded
    listbox.SelectNextItem          = CListBox.SelectNextItem  --DJUadded
    listbox.SelectPreviousItem      = CListBox.SelectPreviousItem  --DJUadded
    listbox.ClearSelection          = CListBox.ClearSelection  --DJUadded
    listbox.GetLine                 = CListBox.GetLine
    listbox.GetNumItems             = CListBox.GetNumItems
    listbox.GetNumLines             = CListBox.GetNumLines
    listbox.Refresh                 = CListBox.Refresh
    listbox.Clear                   = CListBox.Clear
    listbox.SetDynamicWheelSpeed    = CListBox.SetDynamicWheelSpeed  --DJUadded
    --DJUremoved:  listbox.Disable                 = CListBox.Disable
    --DJUremoved:  listbox.Enable                  = CListBox.Enable
    ----listbox.SetIndicators           = CListBox.SetIndicators  --DJUadded

    -- Track internal values.
    listbox.displayFrame = display
    listbox.sliderFrame = slider
    listbox.upButton = upButton
    listbox.downButton = downButton
    listbox.highlightFrame = highlight
    listbox.items = {}
    listbox.lines = {}
    listbox.lineCache = {}
    listbox.selectedItem = 0

    CListBox.ConfigureFlashing(listbox)
    return listbox
end


--#############################################################################
-------------------------------------------------------------------------------
-- CheckBox functions.
-------------------------------------------------------------------------------
--#############################################################################

local CCheckBox = {}


-- ****************************************************************************
-- Called when the internal CheckButton is clicked.
-- ****************************************************************************
function CCheckBox.OnClick(thisCheckButton)
    local isChecked = thisCheckButton:GetChecked() and true or false
    if (isChecked) then PlaySound(856) else PlaySound(857) end

    local checkbox = thisCheckButton:GetParent()
    if (checkbox.clickHandler) then checkbox:clickHandler(isChecked) end
end


-- ****************************************************************************
-- Called when the mouse enters the internal CheckButton.
-- ****************************************************************************
function CCheckBox.OnEnter(thisCheckButton)
    if (thisCheckButton.tooltip) then showTooltip(thisCheckButton) end
end


-- ****************************************************************************
-- Called when the mouse leaves the internal CheckButton.
-- ****************************************************************************
function CCheckBox.OnLeave(thisCheckButton)
    GameTooltip:Hide()
end


-- ****************************************************************************
-- Sets the label for the checkbox.  Returns label width.
-- ****************************************************************************
function CCheckBox.SetLabel(thisCheckBox, label)
    local fontString = thisCheckBox.fontString
    fontString:SetText(label or "")
    gCalcFontString:SetText(label or "")
    thisCheckBox.labelWidth = gCalcFontString:GetStringWidth()
    local width = math.ceil( thisCheckBox.checkButton:GetWidth() + thisCheckBox.labelWidth + 2 )
    thisCheckBox:SetWidth(width)
    local rightInset = thisCheckBox.bClickableText and -thisCheckBox.labelWidth or 0  --DJUadded
    thisCheckBox.checkButton:SetHitRectInsets(0, rightInset, 0, 0)  --DJUadded
end


-- ****************************************************************************
-- Returns the width of the text part of the checkbox.
-- ****************************************************************************
function CCheckBox.GetLabelWidth(thisCheckBox)
    return thisCheckBox.labelWidth
end


-- ****************************************************************************
-- Sets the tooltip text for the checkbox.
-- ****************************************************************************
function CCheckBox.SetTooltip(thisCheckBox, tooltipText, tooltipAnchor)
    setTooltipInfo( thisCheckBox.checkButton, nil, tooltipText, tooltipAnchor )
end


-- ****************************************************************************
-- Sets the tooltip title and text for the checkbox.
-- ****************************************************************************
function CCheckBox.SetTooltipTitleAndText(thisCheckBox, tooltipTitle, tooltipText, tooltipAnchor)
    setTooltipInfo( thisCheckBox.checkButton, tooltipTitle, tooltipText, tooltipAnchor )
end


-- ****************************************************************************
-- Configures the checkbox.
-- ****************************************************************************
function CCheckBox.Configure(thisCheckBox, size, label, tooltip, tooltipAnchor)
    --DJUremoved:  if (not size) then return end  -- Don't do anything if required parameters are invalid.
    size = size or 26  --DJUadded

    -- Setup the container frame.
    thisCheckBox:SetHeight(size)

    -- Setup the checkbox dimensions.
    local check = thisCheckBox.checkButton
    check:SetWidth(size)
    check:SetHeight(size)

    -- Setup the label and tooltip.
    CCheckBox.SetLabel(thisCheckBox, label)
    CCheckBox.SetTooltip(thisCheckBox, tooltip, tooltipAnchor)

    thisCheckBox.configured = true
end


-- ****************************************************************************
-- Sets the function to be called when the checkbox is clicked.
-- It is passed the checkbox and whether or not it's checked.
-- ****************************************************************************
function CCheckBox.SetClickHandler(thisCheckBox, handler)
    thisCheckBox.clickHandler = handler
end


-- ****************************************************************************
-- Returns whether or not the checkbox is checked.
-- ****************************************************************************
function CCheckBox.GetChecked(thisCheckBox)
    return thisCheckBox.checkButton:GetChecked() and true or false
end


-- ****************************************************************************
-- Sets the checked state.
-- ****************************************************************************
function CCheckBox.SetChecked(thisCheckBox, isChecked)
    thisCheckBox.checkButton:SetChecked(isChecked)
end


-- ****************************************************************************
-- Disables the checkbox.
-- ****************************************************************************
function CCheckBox.Disable(thisCheckBox)
    thisCheckBox.checkButton:Disable()
    thisCheckBox.fontString:SetTextColor(0.5, 0.5, 0.5)
end


-- ****************************************************************************
-- Enables the checkbox.
-- ****************************************************************************
function CCheckBox.Enable(thisCheckBox)
    thisCheckBox.checkButton:Enable()
    thisCheckBox.fontString:SetTextColor( NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b )
end


-- ****************************************************************************
-- Clicks the checkbox.
-- ****************************************************************************
function CCheckBox.Click(thisCheckBox)  --DJUadded
    thisCheckBox.checkButton:Click()
end


-- ****************************************************************************
-- Creates and returns a checkbox object ready to be configured.
-- ****************************************************************************
local function CreateCheckBox(parent, fontTemplateName, dx, dy, bClickableText)
    --DJUadded:  fontTemplateName (e.g. "GameFontNormal"), dx, dy, bClickableText.
    fontTemplateName = fontTemplateName or "GameFontNormalSmall"  --DJUadded
    dx = dx or 0   --DJUadded
    dy = dy or 1   --DJUadded

    -- XXX Hack to work around apparent WoW API bug not returning correct string width.
    if (not gCalcFontString) then
        gCalcFontString = UIParent:CreateFontString(nil, "ARTWORK", fontTemplateName)
    end

    -- Create container frame.
    local checkbox = CreateFrame("Frame", nil, parent)

    -- Create check button.
    local checkButton = CreateFrame("CheckButton", nil, checkbox)
    checkButton:SetPoint("TOPLEFT")
    checkButton:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    checkButton:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    checkButton:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    checkButton:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    checkButton:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checkButton:SetScript("OnClick", CCheckBox.OnClick)
    checkButton:SetScript("OnEnter", CCheckBox.OnEnter)
    checkButton:SetScript("OnLeave", CCheckBox.OnLeave)

    -- Label.
    local fontString = checkbox:CreateFontString(nil, "OVERLAY", fontTemplateName)
    fontString:SetJustifyH("LEFT")
    fontString:SetPoint("LEFT", checkButton, "RIGHT", dx, dy)
    fontString:SetPoint("RIGHT", checkbox, "RIGHT", 0, dy)

    -- Make clicking the text toggle the checkbox.  --DJUadded
    checkbox.bClickableText = bClickableText
    ---->>> PROBLEM: This approach doesn't highlight checkbox when mouse hovers over text.  Use SetHitRectInsets() instead.
    ----if bClickableText then
    ----    fontString:SetPoint("TOP", checkbox, 0, dy-2)
    ----    fontString:SetPoint("BOTTOM", checkbox, 0, dy+2)
    ----    fontString:SetScript("OnMouseUp", function(self) checkButton:Click() end)
    ----end

    -- Extension functions.
    checkbox.Click              = CCheckBox.Click
    checkbox.Configure          = CCheckBox.Configure
    checkbox.GetLabelWidth      = CCheckBox.GetLabelWidth
    checkbox.SetLabel           = CCheckBox.SetLabel
    checkbox.SetTooltip         = CCheckBox.SetTooltip
    checkbox.SetTooltipTitleAndText = CCheckBox.SetTooltipTitleAndText
    checkbox.SetClickHandler    = CCheckBox.SetClickHandler
    checkbox.GetChecked         = CCheckBox.GetChecked
    checkbox.SetChecked         = CCheckBox.SetChecked
    checkbox.Disable            = CCheckBox.Disable
    checkbox.Enable             = CCheckBox.Enable

    -- Track internal values.
    checkbox.checkButton = checkButton
    checkbox.fontString = fontString

    CCheckBox.Configure(checkbox)  --DJUadded
    return checkbox
end


--#############################################################################
-------------------------------------------------------------------------------
-- Button functions.
-------------------------------------------------------------------------------
--#############################################################################

local CButton = {}


-- ****************************************************************************
-- Called when the button is clicked.
-- ****************************************************************************
function CButton.OnClick(thisBtn, mouseButton, bDown)  --DJUadded mouseButton, bDown.
    PlaySound(856)
    if (thisBtn.clickHandler) then thisBtn:clickHandler(mouseButton, bDown) end
end


-- ****************************************************************************
-- Called when the mouse enters the button.
-- ****************************************************************************
function CButton.OnEnter(thisBtn)
    if (thisBtn.tooltip) then showTooltip(thisBtn) end
end


-- ****************************************************************************
-- Called when the mouse leaves the button.
-- ****************************************************************************
function CButton.OnLeave(thisBtn)
    GameTooltip:Hide()
end


-- ****************************************************************************
-- Sets the tooltip text for the button.
-- ****************************************************************************
function CButton.SetTooltip(thisBtn, tooltipText, tooltipAnchor)
    setTooltipInfo( thisBtn, nil, tooltipText, tooltipAnchor )
end


-- ****************************************************************************
-- Sets the tooltip title and text for the button.
-- ****************************************************************************
function CButton.SetTooltipTitleAndText(thisBtn, tooltipTitle, tooltipText, tooltipAnchor)
    setTooltipInfo( thisBtn, tooltipTitle, tooltipText, tooltipAnchor )
end


-- ****************************************************************************
-- Sets the function to be called when the button is clicked.
-- ****************************************************************************
function CButton.SetClickHandler(thisBtn, handler)
    thisBtn.clickHandler = handler
end


-- ****************************************************************************
-- Creates and returns a generic button object.  Only used internally.
-- ****************************************************************************
local function CreateButton(parent)
    -- Create button frame.
    local button = CreateFrame("Button", nil, parent)
    button:SetScript("OnClick", CButton.OnClick)
    button:SetScript("OnEnter", CButton.OnEnter)
    button:SetScript("OnLeave", CButton.OnLeave)

    -- Extension functions.
    button.SetClickHandler  = CButton.SetClickHandler
    button.SetTooltip = CButton.SetTooltip
    button.SetTooltipTitleAndText = CButton.SetTooltipTitleAndText

    return button
end


--#############################################################################
-------------------------------------------------------------------------------
-- OptionButton functions.
-------------------------------------------------------------------------------
--#############################################################################

local COptionButton = {}


-- ****************************************************************************
-- Set the label for the option button.
-- ****************************************************************************
function COptionButton.SetLabel(thisOB, label)
    thisOB:SetText(label or "")
    thisOB:SetWidth(thisOB:GetFontString():GetStringWidth() + 50)
end


-- ****************************************************************************
-- Configures the option button.
-- ****************************************************************************
function COptionButton.Configure(thisOB, height, label, tooltip, tooltipAnchor)
    thisOB:SetHeight(height)
    COptionButton.SetLabel(thisOB, label)
    CButton.SetTooltip(thisOB, tooltip, tooltipAnchor)
end


-- ****************************************************************************
-- Creates and returns a push button object ready to be configured.
-- ****************************************************************************
local function CreateOptionButton(parent)
    -- Create generic button.
    local button = CreateButton(parent)
    local fontString = button:CreateFontString(nil, "OVERLAY")
    fontString:SetPoint("CENTER")
    button:SetFontString(fontString)
    button:SetNormalFontObject(GameFontNormalSmall)
    button:SetHighlightFontObject(GameFontHighlightSmall)
    button:SetDisabledFontObject(GameFontDisableSmall)
    button:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    button:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
    button:SetDisabledTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    button:GetNormalTexture():SetTexCoord(0, 0.625, 0, 0.6875)
    button:GetPushedTexture():SetTexCoord(0, 0.625, 0, 0.6875)
    button:GetDisabledTexture():SetTexCoord(0, 0.625, 0, 0.6875)
    button:GetHighlightTexture():SetTexCoord(0, 0.625, 0, 0.6875)

    -- Extension functions.
    button.SetLabel         = COptionButton.SetLabel
    button.Configure        = COptionButton.Configure

    return button
end


--#############################################################################
-------------------------------------------------------------------------------
-- IconButton functions.
-------------------------------------------------------------------------------
--#############################################################################


-- ****************************************************************************
-- Creates and returns an icon button object ready to be configured.
-- Requires three icon BLP files to be specified.  'iconPath' can be set to the
-- path where these files reside, or if left nil, the addon's folder will be used.
-- Each icon file's name must begin.
-- (The ".blp" file extension must not be specified. 'iconPath' must end with "\\".)
-- EXAMPLE: (for a delete "X" button)
--   local deleteBtn = CreateIconButton(YourOptionsFrame, 24, "Interface\\Addons\\YourAddonName\\YourIcons\\"
--                                     "DeleteIcon", "DeleteIconHighlight", "DeleteIconDisable")
-- ****************************************************************************
local function CreateIconButton(parent, iconSize, iconPath, iconFname, iconHighlightFname, iconDisabledFname)  --DJUchanged
    iconSize = iconSize or 24
    iconPath = iconPath or "Interface\\Addons\\" .. kAddonFolderName .. "\\"
    local button = CreateButton(parent)
    button:SetWidth(iconSize)
    button:SetHeight(iconSize)
    if iconFname then button:SetNormalTexture(iconPath .. iconFname) end
    if iconHighlightFname then button:SetHighlightTexture(iconPath .. iconHighlightFname) end
    if iconDisabledFname then button:SetDisabledTexture(iconPath .. iconDisabledFname) end
    return button
end

-- ****************************************************************************
-- Similar to CreateIconButton, but uses textures created by the caller instead of names to images.
-- EXAMPLE: (for a delete "X" button)
--    local function createRedX(parent)
--        local tex = YourOptionsFrame:CreateTexture(nil, "ARTWORK")
--        tex:SetTexture("Interface\\BUTTONS\\UI-StopButton")
--        tex:SetSize(16, 16)
--        tex:SetVertexColor(1.0, 0.22, 0.22,  0.8)  -- Changes icon color to red.
--        return tex
--    end
--    local normal, highlight, disabled = createRedX(YourOptionsFrame), createRedX(YourOptionsFrame), createRedX(YourOptionsFrame)
--    local pushed = normal
--    normal:SetAlpha(0.4)
--    disabled:SetAlpha(0.2)
--    local deleteBtn = private.UDControls.CreateTextureButton(YourOptionsFrame, normal, highlight, pushed, disabled)
-- ****************************************************************************
local function CreateTextureButton(parent, normalTexture, highlightTexture, pushedTexture, disabledTexture)  --DJUadded
    local button = CreateButton(parent)
    button:SetSize(16, 16)
    local tex = normalTexture or highlightTexture or pushedTexture or disabledTexture
    if tex.GetObjectType and tex:GetObjectType() == "Texture" then
        button:SetSize( tex:GetSize() )  -- Make button same size as the first specified texture.
    end
    if normalTexture then button:SetNormalTexture(normalTexture) end
    if highlightTexture then button:SetHighlightTexture(highlightTexture) end
    if pushedTexture then button:SetPushedTexture(pushedTexture) end
    if disabledTexture then button:SetDisabledTexture(disabledTexture) end
    return button
end


--#############################################################################
-------------------------------------------------------------------------------
-- Slider functions.
-------------------------------------------------------------------------------
--#############################################################################

local CSlider = {}


-- ****************************************************************************
-- Called when the value of the slider changes.
-- ****************************************************************************
function CSlider.OnValueChanged(thisSliderFrame, value)
    local slider = thisSliderFrame:GetParent()
    if (slider.labelText ~= "") then
        slider.labelFontString:SetText(slider.labelText .. ": " .. value)
    else
        slider.labelFontString:SetText(value)
    end
    if (slider.valueChangedHandler) then slider:valueChangedHandler(value) end
end


-- ****************************************************************************
-- Called when the mouse enters the slider.
-- ****************************************************************************
function CSlider.OnEnter(thisSliderFrame)
    if (thisSliderFrame.tooltip) then showTooltip(thisSliderFrame) end
end


-- ****************************************************************************
-- Called when the mouse leaves the slider.
-- ****************************************************************************
function CSlider.OnLeave(thisSliderFrame)
    GameTooltip:Hide()
end


-- ****************************************************************************
-- Sets the label for the slider.
-- ****************************************************************************
function CSlider.SetLabel(thisSlider, label)
    thisSlider.labelText = label or ""
    if (thisSlider.labelText ~= "") then
        thisSlider.labelFontString:SetText(thisSlider.labelText .. ": " .. thisSlider:GetValue())
    else
        thisSlider.labelFontString:SetText( thisSlider:GetValue() )
    end
end


-- ****************************************************************************
-- Sets the tooltip text for the slider.
-- ****************************************************************************
function CSlider.SetTooltip(thisSlider, tooltipText, tooltipAnchor)
    setTooltipInfo( thisSlider.sliderFrame, nil, tooltipText, tooltipAnchor )
end


-- ****************************************************************************
-- Sets the tooltip title and text for the slider.
-- ****************************************************************************
function CSlider.SetTooltipTitleAndText(thisSlider, tooltipTitle, tooltipText, tooltipAnchor)
    setTooltipInfo( thisSlider.sliderFrame, tooltipTitle, tooltipText, tooltipAnchor )
end


-- ****************************************************************************
-- Configures the slider.
-- ****************************************************************************
function CSlider.Configure(thisSlider, width, label, tooltip, tooltipAnchor)
    thisSlider:SetWidth(width)
    CSlider.SetLabel(thisSlider, label)
    CSlider.SetTooltip(thisSlider, tooltip, tooltipAnchor)
end


-- ****************************************************************************
-- Sets the function to be called when the value of the slider is changed.
--      handler = function(thisSlider, value)
-- ****************************************************************************
function CSlider.SetValueChangedHandler(thisSlider, handler)
    thisSlider.valueChangedHandler = handler
end


-- ****************************************************************************
-- Sets the minimum and maximum values for the slider.
-- ****************************************************************************
function CSlider.SetMinMaxValues(thisSlider, minValue, maxValue)
    thisSlider.sliderFrame:SetMinMaxValues( minValue, maxValue )
end


-- ****************************************************************************
-- Sets how far the slider moves with each "tick."
-- ****************************************************************************
function CSlider.SetValueStep(thisSlider, value)
    thisSlider.sliderFrame:SetValueStep( value )
end


-- ****************************************************************************
-- Sets the current value of the slider.
-- ****************************************************************************
function CSlider.GetValue(thisSlider)
    return thisSlider.sliderFrame:GetValue()
end


-- ****************************************************************************
-- Sets the current value of the slider.
-- ****************************************************************************
function CSlider.SetValue(thisSlider, value)
    thisSlider.sliderFrame:SetValue( value )
end


-- ****************************************************************************
-- Disables the slider.
-- ****************************************************************************
function CSlider.Disable(thisSlider)
    thisSlider.sliderFrame:EnableMouse(false)
    thisSlider.labelFontString:SetTextColor(0.5, 0.5, 0.5)
end


-- ****************************************************************************
-- Enables the slider.
-- ****************************************************************************
function CSlider.Enable(thisSlider)
    thisSlider.sliderFrame:EnableMouse(true)
    thisSlider.labelFontString:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
end


-- ****************************************************************************
-- Creates and returns a slider object ready to be configured.
-- ****************************************************************************
local function CreateSlider(parent)
    -- Create the backdrop table if it hasn't already been so it can be reused.
    if (not gSliderBackdrop) then
        gSliderBackdrop = {
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = {left=3, right=3, top=6, bottom=6},
        }
    end

    -- Create container frame.
    local slider = CreateFrame("Frame", nil, parent)
    slider:SetHeight(30)

    -- Create slider.
    local sliderFrame = CreateFrame("Slider", nil, slider)
    sliderFrame:SetOrientation("HORIZONTAL")
    sliderFrame:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    sliderFrame:SetPoint("LEFT")
    sliderFrame:SetPoint("RIGHT")
    sliderFrame:SetHeight(16)
    sliderFrame:SetBackdrop(gSliderBackdrop)
    sliderFrame:SetObeyStepOnDrag(true)
    sliderFrame:SetScript("OnValueChanged", CSlider.OnValueChanged)
    sliderFrame:SetScript("OnEnter", CSlider.OnEnter)
    sliderFrame:SetScript("OnLeave", CSlider.OnLeave)

    -- Label.
    local label = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOM", sliderFrame, "TOP", 0, 0)

    -- Extension functions.
    slider.Configure                = CSlider.Configure
    slider.SetLabel                 = CSlider.SetLabel
    slider.SetTooltip               = CSlider.SetTooltip
    slider.SetTooltipTitleAndText   = CSlider.SetTooltipTitleAndText
    slider.SetValueChangedHandler   = CSlider.SetValueChangedHandler
    slider.SetMinMaxValues          = CSlider.SetMinMaxValues
    slider.SetValueStep             = CSlider.SetValueStep
    slider.GetValue                 = CSlider.GetValue
    slider.SetValue                 = CSlider.SetValue
    slider.Enable                   = CSlider.Enable
    slider.Disable                  = CSlider.Disable

    -- Track internal values.
    slider.sliderFrame = sliderFrame
    slider.labelFontString = label
    slider.labelText = ""
    return slider
end


--#############################################################################
-------------------------------------------------------------------------------
-- DropDown functions.
-------------------------------------------------------------------------------
--#############################################################################

local CDropDown = {}


-- ****************************************************************************
-- Hides the dropdown listbox frame that holds the selections.
-- ****************************************************************************
function CDropDown.HideSelections(thisDD)  -- [ Keywords: CDropDown.CloseDropDownMenu() ]
    if (gDropDownListBoxFrame:IsShown() and gDropDownListBoxFrame.dropdown == thisDD) then
        gDropDownListBoxFrame:Hide()
    end
end


-- ****************************************************************************
-- Called when the mouse enters the dropdown.
-- ****************************************************************************
function CDropDown.OnEnter(thisDD)
    if (thisDD.tooltip) then showTooltip(thisDD) end
end


-- ****************************************************************************
-- Called when the mouse leaves the dropdown.
-- ****************************************************************************
function CDropDown.OnLeave(thisDD)
    GameTooltip:Hide()
end


-- ****************************************************************************
-- Called when the dropdown is hidden.
-- ****************************************************************************
function CDropDown.OnHide(thisDD)
    CDropDown.HideSelections(thisDD)
end


-- ****************************************************************************
-- Returns the common listbox frame used by all dropdown menus to display
-- their items when clicked open.
-- ****************************************************************************
function CDropDown.GetListBoxFrame(thisDD)  --DJUadded
    return gDropDownListBoxFrame
end


-- ****************************************************************************
-- Pass in true to scroll dropdown contents based mouse wheel speed.
-- ****************************************************************************
function CDropDown.SetDynamicWheelSpeed(thisDD, bDynamicSpeed)  --DJUadded
    assert(bDynamicSpeed == nil or bDynamicSpeed == true or bDynamicSpeed == false)
    thisDD.bDynamicWheelSpeed = bDynamicSpeed
end


-- ****************************************************************************
-- Called when the button for the dropdown is pressed.
-- ****************************************************************************
function CDropDown.OnClick(thisDropDownButton, mouseButton)
    if mouseButton ~= "LeftButton" then return end  -- Only process left button.

    -- Close the listbox and exit if it's already open for the dropdown.
    local dropdown = thisDropDownButton:GetParent()
    if (gDropDownListBoxFrame:IsShown() and gDropDownListBoxFrame.dropdown == dropdown) then
        gDropDownListBoxFrame:Hide()
        return
    end
    ----vdt_dump(gDropDownListBoxFrame, "gDropDownListBoxFrame")

    -- Resize and move the dropdown listbox frame for the clicked dropdown.
    local kListBoxBottomMargin = 18  --DJUadded and changed value from 24 to 18.
    local totalHeight = #dropdown.items * kListBoxLineHeight
    local listboxHeight = dropdown.listboxHeight or (kListBoxLineHeight * 7)  -- Use specified height, or default to 7 lines.
    local listboxWidth = dropdown.listboxWidth or dropdown:GetWidth()
    listboxWidth = listboxWidth - 4  --DJUchanged: From +20 to -4.
    totalHeight = math.max(math.min(totalHeight, listboxHeight), kListBoxLineHeight)

    --DJUadded vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
    -- Limit height of listbox so its bottom is always on screen.
    local maxHeight = math.max( thisDropDownButton:GetBottom()-kListBoxBottomMargin, 3*kListBoxLineHeight )
    maxHeight = maxHeight / gDropDownListBoxFrame:GetScale()  -- GetBottom() is relative to screen, not parent.
    if (totalHeight > maxHeight) then
        ----totalHeight = maxHeight  -- Leaves different amounts of space at bottom of listbox.
        totalHeight = math.floor(maxHeight / kListBoxLineHeight) * kListBoxLineHeight  -- Keeps it a multiple of line height.
    end
    --DJUadded ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

    gDropDownListBoxFrame:SetParent(dropdown:GetParent())
    gDropDownListBoxFrame:SetHeight(totalHeight + kListBoxBottomMargin)
    gDropDownListBoxFrame:SetWidth(listboxWidth)
    gDropDownListBoxFrame:ClearAllPoints()
    if dropdown.setpointFunc then  --DJUadded
       dropdown.setpointFunc(gDropDownListBoxFrame, dropdown) --DJUadded
    else
        gDropDownListBoxFrame:SetPoint("TOPRIGHT", dropdown, "BOTTOMRIGHT", 0, 5)  --DJUchanged to work better when scaling listbox.
    end
    gDropDownListBoxFrame:SetFrameLevel( dropdown:GetFrameLevel()+5 )
    gDropDownListBoxFrame.dropdown = dropdown

    -- Setup the listbox.
    local listbox = gDropDownListBoxFrame.listbox
    CListBox.Clear(listbox)
    listbox:SetPoint("TOPLEFT", gDropDownListBoxFrame, "TOPLEFT", 7, -9)  --DJUchanged: From 8,-12 to 7,-9.
    listbox:SetPoint("BOTTOMRIGHT", gDropDownListBoxFrame, "BOTTOMRIGHT", -12, 12)
    CListBox.Configure(listbox, 0, totalHeight, kListBoxLineHeight)
    CListBox.SetDynamicWheelSpeed(listbox, dropdown.bDynamicWheelSpeed)
    CListBox.SetButtonFlashing(listbox, dropdown.buttonFlashEnabled)

    for itemNum in ipairs(dropdown.items) do
        CListBox.AddItem(listbox, itemNum)
    end
    CListBox.SelectItem(listbox, dropdown.selectedItem)
    CListBox.SetOffset(listbox, dropdown.selectedItem - 1)

    gDropDownListBoxFrame:Show()
    gDropDownListBoxFrame:Raise()

    -- This next part fixes a glitch where the scrollbar's thumb position was sometimes below the scrollbar.
    if listbox.sliderFrame:IsShown() and not listbox.bGlitchFixed then  -- Only need to do this once.
        listbox.bGlitchFixed = true
        local temp = listbox.sliderFrame:GetValue()
        listbox.sliderFrame:SetValue(0)
        C_Timer.After(kScrollbarGlitchTime, function() listbox.sliderFrame:SetValue(temp) end) -- Restore pos.
    end
end


-- ****************************************************************************
-- Called by listbox to create a line.
-- ****************************************************************************
function CDropDown.CreateLine(thisDD)
    local line = CreateFrame("Button", nil, thisDD)
    line.fontString = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    line.fontString:SetPoint("LEFT", line, "LEFT", 4, 0)  --DJUadded X offset.
    line.fontString:SetPoint("RIGHT", line, "RIGHT")
    line.fontString:SetJustifyH("LEFT")  --DJUadded
    return line
end


-- ****************************************************************************
-- Called by listbox to display a line.
-- ****************************************************************************
function CDropDown.DisplayLine(thisDDLB, line, value, isSelected) -- thisDDLB == gDropDownListBoxFrame.listbox
    local dropdown = gDropDownListBoxFrame.dropdown
    local lineText = dropdown.items[value]

    line.fontString:SetText(lineText)
    local color = (isSelected and HIGHLIGHT_FONT_COLOR) or NORMAL_FONT_COLOR
    line.fontString:SetTextColor(color.r, color.g, color.b)

    ------ Call the display handler.
    ----local isSeparator = (lineText == kSeparatorLine)
    ----if (dropdown.displayHandler and not isSeparator) then
    ----    dropdown:displayHandler(line, value, lineText, isSelected)  --DJUadded
    ----end
    --^^^WOULD NEED TO ADD CDropDown.SetDisplayHandler( func(thisDD, line, value, text, isSelected) )
end


-- ****************************************************************************
-- Called when a line is clicked.
-- ****************************************************************************
function CDropDown.OnClickLine(thisDDLB, line, value) -- thisDDLB == gDropDownListBoxFrame.listbox
    local dropdown = gDropDownListBoxFrame.dropdown
    dropdown.selectedFontString:SetText(dropdown.items[value])
    dropdown.selectedItem = value
    gDropDownListBoxFrame:Hide()

    -- Call the registered change handler for the dropdown.
    if (dropdown.changeHandler) then
        dropdown:changeHandler( dropdown.itemIDs[value],  -- Item's ID.
                                dropdown.items[value],  -- Item's displayed text.
                                value )  -- Item's index number.
    end
end


-- ****************************************************************************
-- Sets the label for the dropdown.
-- ****************************************************************************
function CDropDown.SetLabel(thisDD, label)
    thisDD.labelFontString:SetText(label or "")
end


-- ****************************************************************************
-- Sets the tooltip text for the dropdown.
-- ****************************************************************************
function CDropDown.SetTooltip(thisDD, tooltipText, tooltipAnchor)
    setTooltipInfo( thisDD, nil, tooltipText, tooltipAnchor )
end


-- ****************************************************************************
-- Sets the tooltip title and text for the dropdown.
-- ****************************************************************************
function CDropDown.SetTooltipTitleAndText(thisDD, tooltipTitle, tooltipText, tooltipAnchor)
    setTooltipInfo( thisDD, tooltipTitle, tooltipText, tooltipAnchor )
end


-- ****************************************************************************
-- Enables/disables flashing scrollbar buttons for the specified listbox.
-- ****************************************************************************
function CDropDown.SetButtonFlashing(thisDD, enabled)
    thisDD.buttonFlashEnabled = enabled
end

-- ****************************************************************************
-- Configures the dropdown.
-- ****************************************************************************
function CDropDown.Configure(thisDD, width, label, tooltip)
    -- Don't do anything if required parameters are invalid.
    ----DJUremoved:  if (not width) then return end
    assert(width ~= nil and width > 0)  --DJUadded

    -- Set the width of the dropdown and the max height of the listbox is shown.
    thisDD:SetWidth(width)

    CDropDown.SetLabel(thisDD, label)
    CDropDown.SetTooltip(thisDD, tooltip)

    -- Stretch the dropdown's button over its entire width so users can click anywhere to open it.
    -- Also adjust top/bottom points to match when the (optional) tooltip appears/disappears.
    local button = thisDD.buttonFrame
    button:SetHitRectInsets( -thisDD:GetWidth()+button:GetWidth(), 0, -2, -2 ) -- (Left, Right, Top, Bottom)
end


-- ****************************************************************************
-- Sets the max height the listbox frame can be for the dropdown.
-- ****************************************************************************
function CDropDown.SetListBoxHeight(thisDD, height)
    thisDD.listboxHeight = height
end

-- ****************************************************************************
-- Sets the width of the listbox frame for the dropdown.
-- ****************************************************************************
function CDropDown.SetListBoxWidth(thisDD, width)
    thisDD.listboxWidth = width
end


-- ****************************************************************************
-- Sets the function to be called when one of the dropdown's options is selected.
--      handler = function(thisDD, selectedID, selectedText, selectedIndex)
-- ****************************************************************************
function CDropDown.SetChangeHandler(thisDD, handler)
    thisDD.changeHandler = handler
end


-- ****************************************************************************
-- Returns the number of items in the listbox.
-- ****************************************************************************
function CDropDown.GetNumItems(thisDD)  --DJUadded
    return #thisDD.items
end


-- ****************************************************************************
-- Adds the passed text and id to the dropdown.
-- ****************************************************************************
function CDropDown.AddItem(thisDD, text, id, bPreventDuplicate)
    if bPreventDuplicate then
        -- Check if 'text' already exists.  If so, update its ID and return.
        for itemNum, itemText in ipairs(thisDD.items) do
            if (itemText == text) then
                thisDD.itemIDs[itemNum] = id  -- Update existing item's ID.
                return  -- Done.
            end
        end
    end

    -- New item, so add it.
    thisDD.items[ #thisDD.items+1 ] = text
    thisDD.itemIDs[ #thisDD.items ] = id
end


-- ****************************************************************************
-- Adds a separator line to the dropdown.
-- ****************************************************************************
function CDropDown.AddSeparator(thisDD)
    CDropDown.AddItem(thisDD, kSeparatorLine, kSeparatorLine)
end


-- ****************************************************************************
-- Remove the passed item id from the dropdown.
-- ****************************************************************************
function CDropDown.RemoveItem_Helper(thisDD, itemNumToRemove)
    -- Hide dropdown if it is shown.
    CDropDown.HideSelections(thisDD)

    -- Clear the selected item if it's the item being removed.
    if (itemNumToRemove == thisDD.selectedItem) then
        thisDD.selectedItem = 0
        thisDD.selectedFontString:SetText("")
    end

    table.remove(thisDD.items, itemNumToRemove)
    table.remove(thisDD.itemIDs, itemNumToRemove)
    return true
end
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
function CDropDown.RemoveItem(thisDD, id)
    assert(id)

    -- Compare id with ID entries.
    for itemNum, itemID in ipairs(thisDD.itemIDs) do
        if (itemID == id) then
            return CDropDown.RemoveItem_Helper(thisDD, itemNum)  -- DONE.
        end
    end

    -- Compare id with text entries.
    if (type(id) == "string") then
        for itemNum, itemText in ipairs(thisDD.items) do
            if (itemText == id) then
                return CDropDown.RemoveItem_Helper(thisDD, itemNum)  -- DONE.
            end
        end
    end

    return false  -- FAILED.
end


-- ****************************************************************************
-- Clears the dropdown.
-- ****************************************************************************
function CDropDown.Clear(thisDD)
    local items = thisDD.items
    for k, v in ipairs(items) do
        items[k] = nil
    end

    local itemIDs = thisDD.itemIDs
    for k, v in ipairs(itemIDs) do
        itemIDs[k] = nil
    end

    thisDD.selectedFontString:SetText(nil)
    thisDD.selectedItem = nil  --DJUadded
end


-- ****************************************************************************
-- Clears the dropdown selection.  (The popup menu contents will still exist.)
-- ****************************************************************************
function CDropDown.ClearSelection(thisDD)  --DJUadded
    if (thisDD.selectedItem ~= nil and thisDD.selectedItem ~= 0) then
        thisDD.selectedItem = 0
        thisDD.selectedFontString:SetText("")
    end
end


-- ****************************************************************************
-- Gets the selected index (item number) from the dropdown.
-- ****************************************************************************
function CDropDown.GetSelectedIndex(thisDD)  --DJUadded
    return thisDD.selectedItem
end


-- ****************************************************************************
-- Sets the selected item for the dropdown given an item number (1-based index).
-- Returns true if successful, nil otherwise.
-- ****************************************************************************
function CDropDown.SelectIndex(thisDD, itemNum, bCallChangeHandler)  --DJUadded
    if (itemNum == nil) then return end  -- Fail.
    thisDD.selectedFontString:SetText( thisDD.items[itemNum] )
    thisDD.selectedItem = itemNum

    -- Call the registered change handler for the dropdown.
    if (bCallChangeHandler and thisDD.changeHandler) then
        thisDD:changeHandler( thisDD.itemIDs[itemNum],  -- Item's ID.
                              thisDD.items[itemNum],  -- Item's displayed text.
                              itemNum )  -- Item's index number.
    end
    return true
end


-- ****************************************************************************
-- Gets the selected id from the dropdown.
-- ****************************************************************************
function CDropDown.GetSelectedID(thisDD)
    if (thisDD.selectedItem) then return thisDD.itemIDs[ thisDD.selectedItem ] end
end


-- ****************************************************************************
-- Sets the selected item for the dropdown given an item ID.
-- Returns true if successful, nil otherwise.
-- ****************************************************************************
function CDropDown.SelectID(thisDD, id, bCallChangeHandler)
    if (id == nil) then return end  -- Fail.
    for itemNum, itemID in ipairs(thisDD.itemIDs) do
        if (itemID == id) then
            CDropDown.SelectIndex(thisDD, itemNum, bCallChangeHandler)  --DJUadded
            return true  -- Done, exit loop.     --DJUadded
            --DJUremoved:  thisDD.selectedFontString:SetText( thisDD.items[itemNum] )
            --DJUremoved:  thisDD.selectedItem = itemNum
            --DJUremoved:  return
        end
    end
end


-- ****************************************************************************
-- Gets the selected text from the dropdown.
-- ****************************************************************************
function CDropDown.GetSelectedText(thisDD)
    return thisDD.selectedFontString:GetText()
end


-- ****************************************************************************
-- Sets the selected item for the dropdown given the text shown in the menu.
-- Returns true if successful, nil otherwise.
-- ****************************************************************************
function CDropDown.SelectText(thisDD, text, bCallChangeHandler)  --DJUadded
    if (text == nil or text == "") then return end  -- Fail.
    for itemNum, itemText in ipairs(thisDD.items) do
        if (itemText == text) then
            CDropDown.SelectIndex(thisDD, itemNum, bCallChangeHandler)
            return true  -- Done, exit loop.
        end
    end
end


-- ****************************************************************************
-- Selects next or previous item in the dropdown and invokes the change handler (if set).
-- ****************************************************************************
function CDropDown.SelectNextOrPrevious(thisDD, bNext)  --DJUadded
    if gDropDownListBoxFrame:IsShown() then gDropDownListBoxFrame:Hide() end
    local numItems = thisDD:GetNumItems()
    local itemNum = thisDD:GetSelectedIndex()

    -- Find next/previous line.  (Skip separator lines.)
    local bFound = false
    if bNext then
        while not bFound and itemNum < numItems do  -- Find next line that is not a separator.
            itemNum = itemNum + 1
            local itemText = thisDD.items[itemNum]
            bFound = (itemText ~= kSeparatorLine)
        end
    else -- Previous
        while not bFound and itemNum > 1 do  -- Find previous line that is not a separator.
            itemNum = itemNum - 1
            local itemText = thisDD.items[itemNum]
            bFound = (itemText ~= kSeparatorLine)
        end
    end

    -- Select the line we found.
    if bFound then
        thisDD:SelectIndex(itemNum)
        if thisDD.changeHandler then
            -- Call the registered change handler for the dropdown.
            thisDD:changeHandler( thisDD.itemIDs[itemNum],  -- Item's ID.
                                  thisDD.items[itemNum],  -- Item's displayed text.
                                  itemNum )  -- Item's index number.
        end
    end
end


-- ****************************************************************************
-- Sorts the contents of the dropdown.
-- ****************************************************************************
function CDropDown.Sort(thisDD, bCaseInsensitive)
    local selectedID = CDropDown.GetSelectedID(thisDD)

    -- Sort the dropdown items and associated IDs using an insertion sort.
    local items = thisDD.items
    local itemIDs = thisDD.itemIDs
    local tempItem, tempID, j
    for i = 2, #items do
        tempItem = items[i]
        tempID = itemIDs[i]
        j = i - 1
        if bCaseInsensitive then
            while (j > 0 and string.lower(items[j]) > string.lower(tempItem)) do
                items[j + 1] = items[j]
                itemIDs[j + 1] = itemIDs[j]
                j = j - 1
            end
        else -- Case sensitive sort.
            while (j > 0 and items[j] > tempItem) do
                items[j + 1] = items[j]
                itemIDs[j + 1] = itemIDs[j]
                j = j - 1
            end
        end
        items[j + 1] = tempItem
        itemIDs[j + 1] = tempID
    end

    CDropDown.SelectID(thisDD, selectedID)
end


-- ****************************************************************************
-- Disables the dropdown.
-- ****************************************************************************
function CDropDown.Disable(thisDD)
    CDropDown.HideSelections(thisDD)
    thisDD:EnableMouse(false)
    thisDD.buttonFrame:Disable()
    thisDD.labelFontString:SetTextColor(0.5, 0.5, 0.5)
    thisDD.selectedFontString:SetTextColor(0.5, 0.5, 0.5)
end


-- ****************************************************************************
-- Enables the dropdown.
-- ****************************************************************************
function CDropDown.Enable(thisDD)
    thisDD:EnableMouse(true)
    thisDD.buttonFrame:Enable()
    thisDD.labelFontString:SetTextColor( NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b )
    thisDD.selectedFontString:SetTextColor( HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b )
end


-- ****************************************************************************
-- Sets the color of the dropdown's background.  ('alpha' is optional.)
-- ****************************************************************************
function CDropDown.SetBackdropColor(thisDD, r, g, b, alpha)  --DJUadded
    ----if (gDropDownListBoxFrame.dropdown == thisDD) then
        gDropDownListBoxFrame:SetBackdropColor(r, g, b, (alpha or 1.0))
    ----end
end

-- ****************************************************************************
-- Sets the color of the dropdown's edges.  ('alpha' is optional.)
-- ****************************************************************************
function CDropDown.SetBackdropBorderColor(thisDD, r, g, b, alpha)  --DJUadded
    ----if (gDropDownListBoxFrame.dropdown == thisDD) then
        gDropDownListBoxFrame:SetBackdropBorderColor(r, g, b, (alpha or 1.0))
    ----end
end

-- ****************************************************************************
-- Creates the listbox frame that dropdowns use.
-- ****************************************************************************
function CDropDown.CreateListBoxFrame(parent, bDropDown)  --DJUchanged: Added bDropDown.
    assert(not gDropDownListBoxFrame)  --DJUadded
    gDropDownListBoxFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    gDropDownListBoxFrame:EnableMouse(true)
    gDropDownListBoxFrame:SetToplevel(true)
    gDropDownListBoxFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    gDropDownListBoxFrame:SetBackdrop{  --DJUchanged ...
        ----bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        -----bgFile = "Interface\\Addons\\" .. kAddonFolderName .. "\\Controls-Background-SolidBlack",
        bgFile = kTexture_White8x8,
        ----edgeFile = (not bDropDown and "Interface\\Tooltips\\UI-Tooltip-Border") or nil,
        ----edgeFile = (bDropDown and "Interface\\DialogFrame\\UI-DialogBox-Gold-Border") or "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        ----insets = {left = 6, right = 6, top = 6, bottom = 6},
        ----insets = {left=2, right=4, top=4, bottom=4},  edgeSize=12,
        ----insets = {left=6, right=6, top=6, bottom=6},  edgeSize=24,
        ----insets = {left=6, right=9, top=6, bottom=6},  edgeSize=24,
        ----insets = {left=4, right=4, top=4, bottom=4},  edgeSize=16,
        insets = {left=3, right=3, top=2, bottom=3},  edgeSize=12,
    }
    gDropDownListBoxFrame:Hide()
    gDropDownListBoxFrame:SetBackdropColor(0,0,0, 1)  -- --DJUadded: Solid black background.
    ----gDropDownListBoxFrame:SetBackdropBorderColor(0.7,0.7,0.7, 1)  --DJUadded: Darken the dropdown's edges.
    ----local c = 0.5
    ----gDropDownListBoxFrame.TopEdge:SetVertexColor(c,c,c, 1)
    ----gDropDownListBoxFrame.TopLeftCorner:SetVertexColor(c,c,c, 1)
    ----gDropDownListBoxFrame.TopRightCorner:SetVertexColor(c,c,c, 1)

    local listbox = CreateListBox(gDropDownListBoxFrame, true)  --DJUchanged: Added true param.
    gDropDownListBoxFrame.listbox = listbox
    listbox:SetToplevel(true)
    listbox:SetFrameStrata("FULLSCREEN_DIALOG")
    ----listbox:SetIndicators( {inset = -5} )  --DJUadded
    listbox:SetCreateLineHandler(CDropDown.CreateLine)
    listbox:SetDisplayHandler(CDropDown.DisplayLine)
    listbox:SetClickHandler(CDropDown.OnClickLine)

    --DJUadded vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
    gDropDownListBoxFrame:SetClampedToScreen(true)  -- Keep the bottom of the dropdown list on-screen.
    gDropDownListBoxFrame:SetScript("OnKeyDown", function(this, key)
            -- Close dropdown list when Escape key is pressed.
            local bPassKeyToParent = false
            if key == "ESCAPE" then this:Hide()
            else bPassKeyToParent = true end
            if not InCombatLockdown() then this:SetPropagateKeyboardInput(bPassKeyToParent) end
        end)
    --DJUadded ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
end


-- ****************************************************************************
-- Creates and returns a dropdown object ready to be configured.
-- ****************************************************************************
local function CreateDropDown(parent, bDisableWheelCycling)
    -- Create dropdown listbox if it hasn't already been.
    if (not gDropDownListBoxFrame) then CDropDown.CreateListBoxFrame(parent, true) end  --DJUchanged: Added true param.

    -- Create container frame.
    local dropdown = CreateFrame("Frame", nil, parent)

    dropdown:SetHeight(25)  --DJUchanged: Was 38.
    dropdown:EnableMouse(true)
    dropdown:SetScript("OnEnter", CDropDown.OnEnter)
    dropdown:SetScript("OnLeave", CDropDown.OnLeave)
    dropdown:SetScript("OnHide", CDropDown.OnHide)
    if bDisableWheelCycling then  --DJUadded...
        dropdown:SetScript("OnMouseWheel", function() end)  -- Do nothing.
    else
        dropdown:SetScript("OnMouseWheel", function(thisDD, delta) --DJUadded
                thisDD:HideSelections()  -- i.e. CloseDropDownMenu()
                local bNext = (delta < 0) -- i.e. WheelDown?
                CDropDown.SelectNextOrPrevious(thisDD, bNext)
            end)
    end

    -- Left border.
    local left = dropdown:CreateTexture(nil, "BACKGROUND")
    left:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame")
    left:SetWidth(9)
    left:SetHeight(25)
    left:SetPoint("BOTTOMLEFT")
    left:SetTexCoord(0.125, 0.1953125, 0.28125, 0.671875)

    -- Right border.
    local right = dropdown:CreateTexture(nil, "BACKGROUND")
    right:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame")
    right:SetWidth(9)
    right:SetHeight(25)
    right:SetPoint("BOTTOMRIGHT")
    right:SetTexCoord(0.7890625, 0.859375, 0.28125, 0.671875)

    -- Middle border.
    local middle = dropdown:CreateTexture(nil, "BACKGROUND")
    middle:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame")
    middle:SetWidth(76)
    middle:SetHeight(25)
    middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
    middle:SetPoint("RIGHT", right, "LEFT", 0, 0)
    middle:SetTexCoord(0.1953125, 0.7890625, 0.28125, 0.671875)

    -- Label.
    local labelFontString = dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelFontString:SetPoint("BOTTOMLEFT", left, "TOPLEFT", 2, 2)

    -- DropDown button.
    local button = CreateFrame("Button", nil, dropdown)
    button:SetSize(22, 25)  -- Was 24,24
    button:SetPoint("BOTTOMRIGHT", 1, 0)
    button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    button:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    button:GetHighlightTexture():SetBlendMode("ADD")
    button:SetScript("OnClick", CDropDown.OnClick)
    button:SetScript("OnEnter", function(self) CDropDown.OnEnter(dropdown) end)  --DJUadded
    button:SetScript("OnLeave", function(self) CDropDown.OnLeave(dropdown) end)  --DJUadded
    button:SetScript("OnHide", function(self) CDropDown.OnHide(dropdown) end)  --DJUadded

    -- Selected text.
    local selected = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selected:SetPoint("LEFT", left, "RIGHT", 1, 0)  --DJUadded offsets.
    selected:SetPoint("RIGHT", button, "LEFT")
    selected:SetJustifyH("LEFT")  --DJUchanged (was "RIGHT")

    -- Extension functions.
    dropdown.Configure          = CDropDown.Configure
    dropdown.SetButtonFlashing  = CDropDown.SetButtonFlashing  --DJUadded
    dropdown.SetListBoxHeight   = CDropDown.SetListBoxHeight
    dropdown.SetListBoxWidth    = CDropDown.SetListBoxWidth
    dropdown.SetLabel           = CDropDown.SetLabel
    dropdown.SetTooltip         = CDropDown.SetTooltip
    dropdown.SetTooltipTitleAndText = CDropDown.SetTooltipTitleAndText
    dropdown.SetChangeHandler   = CDropDown.SetChangeHandler
    dropdown.HideSelections     = CDropDown.HideSelections
    dropdown.GetNumItems        = CDropDown.GetNumItems  --DJUadded
    dropdown.AddItem            = CDropDown.AddItem
    dropdown.RemoveItem         = CDropDown.RemoveItem
    dropdown.Clear              = CDropDown.Clear
    dropdown.ClearSelection     = CDropDown.ClearSelection  --DJUadded
    dropdown.GetSelectedText    = CDropDown.GetSelectedText
    dropdown.SelectText         = CDropDown.SelectText  --DJUadded
    dropdown.GetSelectedID      = CDropDown.GetSelectedID
    dropdown.SelectID           = CDropDown.SelectID
    dropdown.GetSelectedIndex   = CDropDown.GetSelectedIndex  --DJUadded
    dropdown.SelectIndex        = CDropDown.SelectIndex  --DJUadded
    dropdown.Sort               = CDropDown.Sort
    dropdown.Disable            = CDropDown.Disable
    dropdown.Enable             = CDropDown.Enable
    dropdown.GetListBoxFrame    = CDropDown.GetListBoxFrame  --DJUadded
    dropdown.SelectNextOrPrevious = CDropDown.SelectNextOrPrevious  --DJUadded
    dropdown.SelectNext         = function(thisDD) thisDD:SelectNextOrPrevious(true) end  --DJUadded
    dropdown.SelectPrevious     = function(thisDD) thisDD:SelectNextOrPrevious(false) end  --DJUadded
    dropdown.SetBackdropColor   = CDropDown.SetBackdropColor  --DJUadded
    dropdown.SetBackdropBorderColor = CDropDown.SetBackdropBorderColor  --DJUadded
    dropdown.SetDynamicWheelSpeed = CDropDown.SetDynamicWheelSpeed  --DJUadded
    dropdown.AddSeparator       = CDropDown.AddSeparator  --DJUadded

    -- Track internal values.
    dropdown.selectedFontString = selected
    dropdown.buttonFrame = button
    dropdown.labelFontString = labelFontString
    dropdown.items = {}
    dropdown.itemIDs = {}
    dropdown.selectedItem = 0  -- index #
    dropdown.buttonFlashEnabled = private.UDControls.kSetButtonFlashing

    return dropdown
end


--[[
--#############################################################################
-------------------------------------------------------------------------------
-- EditBox functions.
-------------------------------------------------------------------------------
--#############################################################################

local CEditBox = {}


-- ****************************************************************************
-- Called when the editbox has focus and escape is pressed.
-- ****************************************************************************
function CEditBox.OnEscape(thisEditBoxFrame)
    thisEditBoxFrame:ClearFocus()
    local editbox = thisEditBoxFrame:GetParent()
    if (editbox.escapeHandler) then editbox:escapeHandler() end
end


-- ****************************************************************************
-- Called when the editbox loses focus.
-- ****************************************************************************
function CEditBox.OnFocusLost(thisEditBoxFrame)
    thisEditBoxFrame:HighlightText(0, 0)
end


-- ****************************************************************************
-- Called when the editbox gains focus.
-- ****************************************************************************
function CEditBox.OnFocusGained(thisEditBoxFrame)
    thisEditBoxFrame:HighlightText()
end


-- ****************************************************************************
-- Called when the text in the editbox changes.
-- ****************************************************************************
function CEditBox.OnTextChanged(thisEditBoxFrame)
    local editbox = thisEditBoxFrame:GetParent()
    if (editbox.textChangedHandler) then editbox:textChangedHandler() end
end


-- ****************************************************************************
-- Called when the mouse enters the editbox.
-- ****************************************************************************
function CEditBox.OnEnter(thisEditBoxFrame)
    if (thisEditBoxFrame.tooltip) then showTooltip(thisEditBoxFrame) end
end


-- ****************************************************************************
-- Called when the mouse leaves the editbox.
-- ****************************************************************************
function CEditBox.OnLeave(thisEditBoxFrame)
    GameTooltip:Hide()
end


-- ****************************************************************************
-- Sets the label for the editbox.
-- ****************************************************************************
function CEditBox.SetLabel(thisEB, label)
    thisEB.labelFontString:SetText(label)
end


-- ****************************************************************************
-- Sets the tooltip text for the editbox.
-- ****************************************************************************
function CEditBox.SetTooltip(thisEB, tooltipText, tooltipAnchor)
    setTooltipInfo( thisEB.editboxFrame, nil, tooltipText, tooltipAnchor )
end


-- ****************************************************************************
-- Sets the tooltip title and text for the editbox.
-- ****************************************************************************
function CEditBox.SetTooltipTitleAndText(thisEB, tooltipTitle, tooltipText, tooltipAnchor)
    setTooltipInfo( thisEB.editboxFrame, tooltipTitle, tooltipText, tooltipAnchor )
end


-- ****************************************************************************
-- Configures the editbox.
-- ****************************************************************************
function CEditBox.Configure(thisEB, width, label, tooltip, tooltipAnchor)
    -- Don't do anything if required parameters are invalid.
    if (not width) then return end

    thisEB:SetWidth(width)
    CEditBox.SetLabel(thisEB, label)
    CEditBox.SetTooltip(thisEB, tooltip, tooltipAnchor)
end


-- ****************************************************************************
-- Sets the handler to be called when the enter button is pressed.
-- ****************************************************************************
function CEditBox.SetEnterHandler(thisEB, handler)
    thisEB.editboxFrame:SetScript("OnEnterPressed", handler)
end


-- ****************************************************************************
-- Sets the handler to be called when the escape button is pressed.
-- ****************************************************************************
function CEditBox.SetEscapeHandler(thisEB, handler)
    thisEB.escapeHandler = handler
end


-- ****************************************************************************
-- Sets the handler to be called when the text in the editbox changes.
--      handler = function(thisEB)
-- ****************************************************************************
function CEditBox.SetTextChangedHandler(thisEB, handler)
    thisEB.textChangedHandler = handler
end


-- ****************************************************************************
-- Sets the focus to the editbox.
-- ****************************************************************************
function CEditBox.SetFocus(thisEB)
    thisEB.editboxFrame:SetFocus()
end


-- ****************************************************************************
-- Gets the text entered in the editbox.
-- ****************************************************************************
function CEditBox.GetText(thisEB)
    return thisEB.editboxFrame:GetText()
end


-- ****************************************************************************
-- Sets the text entered in the editbox.
-- ****************************************************************************
function CEditBox.SetText(thisEB, text)
    return thisEB.editboxFrame:SetText(text or "")
end


-- ****************************************************************************
-- Disables the editbox.
-- ****************************************************************************
function CEditBox.Disable(thisEB)
    thisEB.editboxFrame:EnableMouse(false)
    thisEB.labelFontString:SetTextColor(0.5, 0.5, 0.5)
end

-- ****************************************************************************
-- Enables the editbox.
-- ****************************************************************************
function CEditBox.Enable(thisEB)
    thisEB.editboxFrame:EnableMouse(true)
    thisEB.labelFontString:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
end


-- ****************************************************************************
-- Creates and returns an editbox object ready to be configured.
-- ****************************************************************************
local function CreateEditBox(parent)
    -- Create container frame.
    local editbox = CreateFrame("Frame", nil, parent)
    editbox:SetHeight(32)

    -- Create editbox frame.
    local editboxFrame = CreateFrame("EditBox", nil, editbox)
    editboxFrame:SetHeight(20)
    editboxFrame:SetPoint("BOTTOMLEFT", editbox, "BOTTOMLEFT", 5, 0)
    editboxFrame:SetPoint("BOTTOMRIGHT")
    editboxFrame:SetAutoFocus(false)
    editboxFrame:SetFontObject(ChatFontNormal)
    editboxFrame:SetScript("OnEscapePressed", CEditBox.OnEscape)
    editboxFrame:SetScript("OnEditFocusLost", CEditBox.OnFocusLost)
    editboxFrame:SetScript("OnEditFocusGained", CEditBox.OnFocusGained)
    editboxFrame:SetScript("OnTextChanged", CEditBox.OnTextChanged)
    editboxFrame:SetScript("OnEnter", CEditBox.OnEnter)
    editboxFrame:SetScript("OnLeave", CEditBox.OnLeave)

    -- Left border.
    local left = editboxFrame:CreateTexture(nil, "BACKGROUND")
    left:SetTexture("Interface\\Common\\Common-Input-Border")
    left:SetWidth(8)
    left:SetHeight(20)
    left:SetPoint("LEFT", editboxFrame, "LEFT", -5, 0)
    left:SetTexCoord(0, 0.0625, 0, 0.625)

    -- Right border.
    local right = editboxFrame:CreateTexture(nil, "BACKGROUND")
    right:SetTexture("Interface\\Common\\Common-Input-Border")
    right:SetWidth(8)
    right:SetHeight(20)
    right:SetPoint("RIGHT")
    right:SetTexCoord(0.9375, 1, 0, 0.625)

    -- Middle border.
    local middle = editboxFrame:CreateTexture(nil, "BACKGROUND")
    middle:SetTexture("Interface\\Common\\Common-Input-Border")
    middle:SetWidth(10)
    middle:SetHeight(20)
    middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
    middle:SetPoint("RIGHT", right, "LEFT", 0, 0)
    middle:SetTexCoord(0.0625, 0.9375, 0, 0.625)

    -- Label.
    local label = editbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT")
    label:SetPoint("TOPRIGHT")
    label:SetJustifyH("LEFT")

    -- Extension functions.
    editbox.Configure               = CEditBox.Configure
    editbox.SetLabel                = CEditBox.SetLabel
    editbox.SetTooltip              = CEditBox.SetTooltip
    editbox.SetTooltipTitleAndText  = CEditBox.SetTooltipTitleAndText
    editbox.SetEnterHandler         = CEditBox.SetEnterHandler
    editbox.SetEscapeHandler        = CEditBox.SetEscapeHandler
    editbox.SetTextChangedHandler   = CEditBox.SetTextChangedHandler
    editbox.SetFocus                = CEditBox.SetFocus
    editbox.GetText                 = CEditBox.GetText
    editbox.SetText                 = CEditBox.SetText
    editbox.Disable                 = CEditBox.Disable
    editbox.Enable                  = CEditBox.Enable

    -- Track internal values.
    editbox.editboxFrame = editboxFrame
    editbox.labelFontString = label
    return editbox
end
]]


--#############################################################################
-------------------------------------------------------------------------------
-- ColorSwatch functions.
-------------------------------------------------------------------------------
--#############################################################################


-- ****************************************************************************
-- Returns true if the standard color picker has been modified by functions
-- in this file.  Returns nil if it is in its original state.
-- ****************************************************************************
local function isColorPickerCustomized()
    return ColorPickerFrame[kCustomizedTag]
end


-- ****************************************************************************
-- Restores modified attributes of the ColorPickerFrame back to their original values.
-- Returns true if our customizations were undone.
-- Returns false if the color picker is not currently customized.
-- ****************************************************************************
local function ColorPickerFrame_RestoreAttributes()
    if not isColorPickerCustomized() then
        return false  -- Color picker is not currenlty customized.  (Nothing to restore.)
    end

    local orig = gColorPickerAttributes

    if gColorPaletteFrame then gColorPaletteFrame:Hide() end
    ColorPickerFrame:SetHeight( orig.height )
    ColorPickerFrame:EnableKeyboard( orig.isKeyboardEnabled )
    ColorPickerFrame:SetClampedToScreen( orig.isClamped )
    ColorPickerFrame:SetClampRectInsets( unpack(orig.insets) )

    setPointTable(ColorPickerFrame, orig.point)

    gColorPickerOkayBtn:SetWidth( orig.okayBtnW )
    setPointTable(gColorPickerOkayBtn, orig.okayBtnPoint)

    gColorPickerCancelBtn:SetWidth( orig.cancelBtnW )
    setPointTable(gColorPickerCancelBtn, orig.cancelBtnPoint)

    if orig.hexBoxPoint then setPointTable(ColorPickerFrame.Content.HexBox, orig.hexBoxPoint) end
    if orig.titleWidth  then ColorPickerFrame.Header:SetWidth( orig.titleWidth ) end
    if orig.title       then ColorPickerFrame.Header.Text:SetText( orig.title ) end

    ColorPickerFrame[kCustomizedTag] = nil  -- Done.  (We restored color picker to original state.)
    return true
end


-- ****************************************************************************
-- Saves current attributes of the ColorPickerFrame that will by modified by this file.
-- ****************************************************************************
local function ColorPickerFrame_SaveAttributes()
    if not gColorPickerAttributes then
        local orig = {}
        orig.height = ColorPickerFrame:GetHeight()
        orig.isKeyboardEnabled = ColorPickerFrame:IsKeyboardEnabled()
        orig.isClamped = ColorPickerFrame:IsClampedToScreen()
        orig.insets = { ColorPickerFrame:GetClampRectInsets() }
        orig.point = getPointTable(ColorPickerFrame)

        orig.okayBtnW = gColorPickerOkayBtn:GetWidth()
        orig.okayBtnPoint = getPointTable(gColorPickerOkayBtn)

        orig.cancelBtnW = gColorPickerCancelBtn:GetWidth()
        orig.cancelBtnPoint = getPointTable(gColorPickerCancelBtn)

        if ColorPickerFrame.Content and ColorPickerFrame.Content.HexBox then
            orig.hexBoxPoint = getPointTable( ColorPickerFrame.Content.HexBox )
        end

        if ColorPickerFrame.Header then
            orig.titleWidth = ColorPickerFrame.Header:GetWidth()
            orig.title = ColorPickerFrame.Header.Text:GetText()
        end

        gColorPickerAttributes = orig  -- Store data in our global var.

        -- Always restore these original attributes whenever our color picker is closed.
        ColorPickerFrame:SetScript("OnHide", function(self)
                    if not ColorPickerFrame_RestoreAttributes() then
                        -- The standard color picker (not our customized version) was closed.
                        -- Always update our stored position to preserve where user last moved it.
                        gColorPickerAttributes.point = getPointTable( ColorPickerFrame )
                    end
                end)
    end
end


-- ****************************************************************************
-- Sets the color of the color swatch.
-- ****************************************************************************
local function ColorSwatch_SetColor(thisCS, r, g, b, a)
    -- Update our variables.
    thisCS.r = r
    thisCS.g = g
    thisCS.b = b
    thisCS.a = a

    -- Update swatch button's color.
    thisCS:GetNormalTexture():SetVertexColor(r, g, b, a)
end


-- ****************************************************************************
-- Returns the color of the color swatch.
-- ****************************************************************************
local function ColorSwatch_GetColor(thisCS)
    return thisCS.r, thisCS.g, thisCS.b, thisCS.a
end


-- ****************************************************************************
-- Called when the color picker values change, or the picker is canceled.
-- ****************************************************************************
local function ColorSwatch_Callback(previousValues)
    local swatchBtn = gAssociatedColorSwatch
    if not swatchBtn then return end

    local r, g, b, a
    if previousValues then
        -- The user canceled.  Extract the old color from 'previousValues', initialized in ShowColorPicker().
        r, g, b, a = previousValues.r, previousValues.g, previousValues.b, previousValues.a
    else
        -- Either color or opacity changed.  Check both.
        r, g, b = ColorPickerFrame:GetColorRGB()
        if ColorPickerFrame.hasOpacity then
            a = OpacitySlider_GetValue()
            ----if not kMinVer_10_2_5 then
            ----    a = 1.0 - a  -- Older versions of WoW flip opacity and alpha.
            ----end
        end
    end

    ColorSwatch_SetColor(swatchBtn, r, g, b, a)  -- Updates color of the swatch button.
    if swatchBtn.colorChangedHandler then swatchBtn:colorChangedHandler() end  -- Updates color of caller's UI element(s).
end


-- ****************************************************************************
-- Creates a color palette frame (if necessary).  This palette is shown in the color picker.
-- ****************************************************************************
local function ColorSwatch_CreateColorPalette()
    if not gColorPaletteFrame then
        local paletteColors = {
                { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, -- white
                { r = 0.0, g = 0.0, b = 0.0, a = 1.0 }, -- black
                { r = 1.0, g = 0.0, b = 0.0, a = 1.0 },	-- red
                --{ r = 1.0, g = 0.0, b = 0.5, a = 1.0 }, -- rose
                { r = 1.0, g = 0.0, b = 1.0, a = 1.0 },	-- magenta
                { r = 0.5, g = 0.0, b = 1.0, a = 1.0 },	-- violet
                { r = 0.0, g = 0.0, b = 1.0, a = 1.0 },	-- blue
                { r = 0.0, g = 0.5, b = 1.0, a = 1.0 },	-- azure
                { r = 0.0, g = 1.0, b = 1.0, a = 1.0 },	-- cyan
                --{ r = 0.0, g = 1.0, b = 0.5, a = 1.0 }, -- aquamarine
                { r = 0.0, g = 1.0, b = 0.0, a = 1.0 }, -- green
                { r = 0.5, g = 1.0, b = 0.0, a = 1.0 }, -- chartreuse
                { r = 1.0, g = 1.0, b = 0.0, a = 1.0 }, -- yellow
                { r = 1.0, g = 0.5, b = 0.0, a = 1.0 }, -- orange
                { r = 0.976, g = 0.549, b = 0.714, a = 1.0 }, -- Pastels ...
                { r = 0.984, g = 0.714, b = 0.820, a = 1.0 },
                { r = 0.647, g = 0.537, b = 0.757, a = 1.0 },
                { r = 0.757, g = 0.702, b = 0.843, a = 1.0 },
                { r = 0.459, g = 0.537, b = 0.749, a = 1.0 },
                { r = 0.580, g = 0.659, b = 0.816, a = 1.0 },
                { r = 0.604, g = 0.808, b = 0.874, a = 1.0 },
                { r = 0.710, g = 0.882, b = 0.682, a = 1.0 },
                { r = 0.749, g = 0.894, b = 0.462, a = 1.0 },
                { r = 0.999, g = 0.980, b = 0.506, a = 1.0 },
                { r = 0.992, g = 0.792, b = 0.635, a = 1.0 },
                --{ r = 0.859, g = 0.835, b = 0.725, a = 1.0 },
                --{ r = 0.0, g = 0.0, b = 0.0, a = 1.0 }, -- black
                --{ r = 0.1, g = 0.1, b = 0.1, a = 1.0 }, -- shades of gray
                --{ r = 0.2, g = 0.2, b = 0.2, a = 1.0 },
                --{ r = 0.3, g = 0.3, b = 0.3, a = 1.0 },
                --{ r = 0.4, g = 0.4, b = 0.4, a = 1.0 },
                { r = 0.5, g = 0.5, b = 0.5, a = 1.0 }, -- gray
                --{ r = 0.6, g = 0.6, b = 0.6, a = 1.0 },
                --{ r = 0.7, g = 0.7, b = 0.7, a = 1.0 },
                --{ r = 0.8, g = 0.8, b = 0.8, a = 1.0 },
                --{ r = 0.9, g = 0.9, b = 0.9, a = 1.0 },
                --{ r = 1.0, g = 1.0, b = 1.0, a = 1.0 }, -- white
                --{ r = 0.7, g = 0.7, b = 0.7, a = 0.7 }, -- transparent gray
            }
        local rows = 2
        local cols = 12
        local spacer = 0
        local margin = 0
        local swatchSize = 20
        local bgtable = {
                bgFile = kTexture_White8x8,
                edgeFile = kTexture_White8x8,
                tile = false,
                tileSize = 16,
                edgeSize = 1,
                insets = { 0, 0, 0, 0 },
            }

        -- Create a frame for the palette squares.
        gColorPaletteFrame = CreateFrame("Frame", nil, ColorPickerFrame, BackdropTemplateMixin and "BackdropTemplate")
        gColorPaletteFrame:SetBackdrop(bgtable)
        gColorPaletteFrame:SetFrameLevel( gColorPickerOkayBtn:GetFrameLevel() )
        gColorPaletteFrame:SetSize((cols*swatchSize)+((cols-1)*spacer)+(2*margin),
                                   (rows*swatchSize)+((rows-1)*spacer)+(2*margin))
        gColorPaletteFrame:ClearAllPoints()
        gColorPaletteFrame:SetPoint("CENTER", ColorPickerFrame, "CENTER", 0, 0)
        gColorPaletteFrame:SetPoint("BOTTOM", gColorPickerOkayBtn, "TOP", 0, 8)
        gColorPaletteFrame:SetBackdropColor(0, 0, 0, 0)
        gColorPaletteFrame:SetBackdropBorderColor(0, 0, 0, 0)
        ----gColorPaletteFrame:Show()

        -- Create palette swatch squares.
        local i, j, k = 0, 0, 0
        for j = 1, rows do
            for i = 1, cols do
                k = k + 1
                local color = paletteColors[k]
                if not color then break end  -- Stop if no more colors in palette.
                local f = CreateFrame("Button", nil, gColorPaletteFrame, BackdropTemplateMixin and "BackdropTemplate")
                f:SetBackdrop(bgtable)
                f:SetBackdropColor(color.r, color.g, color.b, color.a)
                f:SetBackdropBorderColor(0, 0, 0)  --(0, 0, 0, color.a)
                f:SetSize(swatchSize, swatchSize)
                ----createCheckerboardBG(f, false, swatchSize, swatchSize)
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", gColorPaletteFrame, "TOPLEFT",
                              margin + (spacer*(i-1)) + ((i-1)*swatchSize),
                            -(margin + (spacer*(j-1)) + ((j-1)*swatchSize)))

                f:SetScript("OnClick", function(self)  -- 'self' is one of the palette buttons.
                            local r, g, b, a = self:GetBackdropColor()
                            ColorPickerFrame_SetColorRGB(r, g, b)
                            if ColorPickerFrame.hasOpacity then
                                ColorPickerFrame.opacity = a
                                OpacitySlider_SetValue( ColorPickerFrame.opacity )
                            end
                        end)
            end
        end
    end

    gColorPaletteFrame:Show()
    ColorPickerFrame:SetHeight( kColorPickerDefaultHeight + gColorPaletteFrame:GetHeight() + 16 )
end


-- ****************************************************************************
-- Called when the color swatch is clicked.  Shows the color picker.
-- ****************************************************************************
local function ColorSwatch_ShowColorPicker(thisCS)
    if ColorPickerFrame:IsShown() then
        if isColorPickerCustomized() then return end  -- Already shown.  Do nothing else.

        -- Otherwise, color picker is opened by another addon.  Close that one so we can show ours (later).
        ColorPickerFrame:Hide()
    end
    ----vdt_dump(thisCS, "thisCS in ColorSwatch_ShowColorPicker()")

    ColorPickerFrame_SaveAttributes()
    ColorPickerFrame[kCustomizedTag] = true  -- So we restore the color picker to original state when it is closed.
    gAssociatedColorSwatch = thisCS

    thisCS.r = thisCS.r or 1
    thisCS.g = thisCS.g or 1
    thisCS.b = thisCS.b or 1
    ColorPickerFrame.previousValues = {r = thisCS.r, g = thisCS.g, b = thisCS.b, a = thisCS.a}

    if (thisCS.a ~= nil) then
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = thisCS.a
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacity = nil
    end

    ColorPickerFrame.func = ColorSwatch_Callback  -- Old Blizzard name.  (Does same thing as 'swatchFunc'.)
    ColorPickerFrame.swatchFunc = ColorSwatch_Callback  -- New Blizzard name (10.2.5 and later).
    ColorPickerFrame.opacityFunc = ColorSwatch_Callback
    ColorPickerFrame.cancelFunc = ColorSwatch_Callback

    if kMinVer_10_2_5 then  -- WoW 10.2.5 or newer?
        -- Set new API stuff.
        ColorPickerFrame.Content.ColorSwatchOriginal:SetColorTexture(thisCS.r, thisCS.g, thisCS.b)
        ColorPickerFrame.Content.HexBox:OnColorSelect(thisCS.r, thisCS.g, thisCS.b)
    end

    -- Set color and opacity.
    ColorPickerFrame_SetColorRGB(thisCS.r, thisCS.g, thisCS.b)
    if (ColorPickerFrame.opacity) then
        OpacitySlider_SetValue(ColorPickerFrame.opacity)
    end

    --::::::::::::::::::[ CUSTOMIZE COLOR PICKER ]:::::::::::::::::::

    -- Attach color picker to top-right corner of the parent frame.
    ColorPickerFrame:ClearAllPoints()
    ColorPickerFrame:SetPoint("TOPLEFT", thisCS:GetParent(), "TOPRIGHT", -12, -6)
    ColorPickerFrame:SetClampedToScreen(true)  -- Keep color picker frame on screen.
    ColorPickerFrame:SetClampRectInsets(12, -12, -12, 12) -- Allow for dragging partially off screen.

    -- Verify no other addon customtized the color picker.  (Check its height.)
    if (ColorPickerFrame:GetHeight() <  kColorPickerDefaultHeight+1) then
        -- Change title text.
        if ColorPickerFrame.Header then  -- (Header variable doesn't exist in classic WoW versions.)
            ColorPickerFrame.Header.Text:SetText( kAddonFolderName .. " " .. gColorPickerAttributes.title )
            local strWidth = ColorPickerFrame.Header.Text:GetStringWidth()
            ColorPickerFrame.Header:SetWidth( strWidth+41 )
        end

        -- Reposition the Color Picker's OK and CANCEL buttons (slightly).
        gColorPickerOkayBtn:SetWidth(kColorPickerButtonWidth)  -- Was 144.
        gColorPickerCancelBtn:SetWidth(kColorPickerButtonWidth)  -- Was 144.
        gColorPickerCancelBtn:ClearAllPoints()
        gColorPickerCancelBtn:SetPoint("BOTTOMRIGHT", ColorPickerFrame, "BOTTOMRIGHT", -14, 16)
        gColorPickerOkayBtn:ClearAllPoints()
        gColorPickerOkayBtn:SetPoint("RIGHT", gColorPickerCancelBtn, "LEFT", -2, 0)

        -- Reposition the hex box (if it exists).
        if ColorPickerFrame.Content and ColorPickerFrame.Content.HexBox then
            ColorPickerFrame.Content.HexBox:ClearAllPoints()
            ColorPickerFrame.Content.HexBox:SetPoint("RIGHT", ColorPickerFrame.Content, "RIGHT", -23, 0)
            ColorPickerFrame.Content.HexBox:SetPoint("BOTTOM", ColorPickerFrame.Content.ColorPicker, "BOTTOM", 0, 6)
        end

        -- Add color palette swatches to the bottom of the standard color picker.
        ColorSwatch_CreateColorPalette()
    end
    --:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

    -- Finish.
    ColorPickerFrame:EnableKeyboard(false)  -- Prevent color picker from intercepting keystrokes.
    ColorPickerFrame:Hide()  -- Forces the OnShow handler to run the next time OnShow() is called.
    ColorPickerFrame:Show()
end


-- ****************************************************************************
-- Closes the color picker (if it is open) by triggering its OK or CANCEL button
-- depending on the bSaveChanges parameter passed in.
-- ****************************************************************************
local function ColorSwatch_CloseColorPicker(thisCS, bSaveChanges)
    if ColorPickerFrame:IsShown() then
        if bSaveChanges then
            gColorPickerOkayBtn:Click()
        else
            gColorPickerCancelBtn:Click()
        end
    end
end


-- ****************************************************************************
-- Called when the mouse enters the color swatch.
-- ****************************************************************************
local function ColorSwatch_OnEnter(thisCS)
    if (thisCS.tooltip) then showTooltip(thisCS) end
    ----thisCS.borderTexture:SetVertexColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
end


-- ****************************************************************************
-- Called when the mouse leaves the color swatch.
-- ****************************************************************************
local function ColorSwatch_OnLeave(thisCS)
    GameTooltip:Hide()
    ----thisCS.borderTexture:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
end


-- ****************************************************************************
-- Sets the handler to be called when the color changes.
-- ****************************************************************************
local function ColorSwatch_SetColorChangedHandler(thisCS, handler)
    thisCS.colorChangedHandler = handler
end


-- ****************************************************************************
-- Sets the tooltip text for the color swatch.
-- ****************************************************************************
local function ColorSwatch_SetTooltip(thisCS, tooltipText, tooltipAnchor)
    setTooltipInfo( thisCS, nil, tooltipText, tooltipAnchor )
end


-- ****************************************************************************
-- Sets the tooltip title and text for the color swatch.
-- ****************************************************************************
local function ColorSwatch_SetTooltipTitleAndText(thisCS, tooltipTitle, tooltipText, tooltipAnchor)
    setTooltipInfo( thisCS, tooltipTitle, tooltipText, tooltipAnchor )
end


-- ****************************************************************************
-- Disables the colors watch.
-- ****************************************************************************
local function ColorSwatch_Disable(thisCS)
    thisCS:GetNormalTexture():SetVertexColor(0.5, 0.5, 0.5) -- Dim the color swatch.
    thisCS:SetAlpha(0.2)
    thisCS:oldDisableHandler()
end


-- ****************************************************************************
-- Enables the color swatch.
-- ****************************************************************************
local function ColorSwatch_Enable(thisCS)
    thisCS:oldEnableHandler()
    thisCS:GetNormalTexture():SetVertexColor(thisCS.r, thisCS.g, thisCS.b)  -- Undim the color swatch.
    thisCS:SetAlpha(1.0)
end


-- ****************************************************************************
-- Creates and returns a color swatch object ready to be configured.
-- ****************************************************************************
local function CreateColorSwatch(parent, size)
    ----vdt_dump(gColorPickerAttributes, "gColorPickerAttributes") -- For debugging.
    size = size or 20

    -- Create button frame.
    local colorswatch = CreateFrame("Button", nil, parent)
    colorswatch:SetSize(size, size)
    colorswatch:SetNormalTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
    colorswatch:SetScript("OnClick", function(self, mouseButton)
                if mouseButton ~= "LeftButton" then return end  -- Only process left button.
                ColorSwatch_ShowColorPicker(self)
            end)
    colorswatch:SetScript("OnEnter", ColorSwatch_OnEnter)
    colorswatch:SetScript("OnLeave", ColorSwatch_OnLeave)

    -- Border texture.
    colorswatch.borderTexture = colorswatch:CreateTexture(nil, "BACKGROUND")
    ----colorswatch.borderTexture:SetColorTexture(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
    colorswatch.borderTexture:SetColorTexture(1, 1, 1)
    colorswatch.borderTexture:SetSize(size-2, size-2)
    colorswatch.borderTexture:SetPoint("CENTER", -0.1, 0)

    -- Checkerboard texture.  (Requires WoW version 10.0.2 or later to use texture 188523.)
    if (kGameTocVersion >= 100002) then
        colorswatch.checkers = colorswatch:CreateTexture(nil, "BACKGROUND")
        colorswatch.checkers:SetSize(size * 0.75, size * 0.75)
        colorswatch.checkers:SetTexture(188523) -- Tileset\\Generic\\Checkers
        colorswatch.checkers:SetTexCoord(.25, 0, 0.5, .25)
        colorswatch.checkers:SetDesaturated(true)
        colorswatch.checkers:SetVertexColor(1, 1, 1, 0.75)
        colorswatch.checkers:SetPoint("CENTER")
    end

    -- Save old disable/enable handlers.
    colorswatch.oldDisableHandler = colorswatch.Disable
    colorswatch.oldEnableHandler = colorswatch.Enable

    -- Extension functions.
    colorswatch.SetColor                = ColorSwatch_SetColor
    colorswatch.GetColor                = ColorSwatch_GetColor
    colorswatch.SetColorChangedHandler  = ColorSwatch_SetColorChangedHandler
    colorswatch.SetTooltip              = ColorSwatch_SetTooltip
    colorswatch.SetTooltipTitleAndText  = ColorSwatch_SetTooltipTitleAndText
    colorswatch.Disable                 = ColorSwatch_Disable
    colorswatch.Enable                  = ColorSwatch_Enable
    colorswatch.CloseColorPicker        = ColorSwatch_CloseColorPicker

    -- Finish.
    return colorswatch
end


--#############################################################################
-------------------------------------------------------------------------------
-- TextScrollFrame functions.
-- (Based on Mayron's video, "Creating WoW AddOns - Episode 8 - Scroll Frames and More XML".)
-- https://www.youtube.com/watch?v=1CQHKo1Pt2Q&list=PL3wt7cLYn4N-3D3PTTUZBM2t1exFmoA2G&index=10
-------------------------------------------------------------------------------
--#############################################################################


-- ****************************************************************************
-- Creates and returns a scrollable text frame object.
-- ****************************************************************************
local function CreateTextScrollFrame(parent, title, width, height)  --DJUadded
    parent = parent or UIParent
    width = width or 400
    height = height or 600

    local margin = 9

    -----------------------------
    -- Create a container frame.
    -----------------------------
    local containerFrame = CreateFrame("frame", nil, parent) ----, "BackdropTemplate")
    ----containerFrame:Hide()
    containerFrame:SetFrameStrata("DIALOG")
    containerFrame:SetFrameLevel(10)
    ----containerFrame:SetToplevel(true)
    containerFrame:EnableMouse(true)  -- Prevents clicking thru this frame and triggering things beneath it.
    containerFrame:SetPoint("CENTER")
    containerFrame:SetWidth(width)
    containerFrame:SetHeight(height)
    ----containerFrame:SetBackdropColor(0,0,0, 1)

    -- Create dark marbled background.
    containerFrame.bg = containerFrame:CreateTexture(nil, "BACKGROUND") ----, "BackdropTemplate")
    containerFrame.bg:SetPoint("TOPLEFT", 1, -1)
    containerFrame.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    containerFrame.bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble", true, true)
    ----containerFrame.bg:SetColorTexture(0, 0, 0, 1) -- Black

    containerFrame.bg:SetHorizTile(true)
    containerFrame.bg:SetVertTile(true)
    ----containerFrame.bg:SetBackdropColor(0,0,0, 1)

    -- Create border around the edges.
    for k, v in pairs({
            {"UI-Frame-InnerTopLeft", "TOPLEFT", 0, 0},
            {"UI-Frame-InnerTopRight", "TOPRIGHT", 0, 0},
            {"UI-Frame-InnerBotLeftCorner", "BOTTOMLEFT", 0, 0},
            {"UI-Frame-InnerBotRight", "BOTTOMRIGHT", 0, 0},
            {"_UI-Frame-InnerTopTile", "TOPLEFT", 6, 0, "TOPRIGHT", -6, 0},
            {"_UI-Frame-InnerBotTile", "BOTTOMLEFT", 6, 0, "BOTTOMRIGHT", -6, 0},
            {"!UI-Frame-InnerLeftTile", "TOPLEFT", 0, -6, "BOTTOMLEFT", 0, 6},
            {"!UI-Frame-InnerRightTile", "TOPRIGHT", 0, -6, "BOTTOMRIGHT", 0, 6}
            }) do
        local border = containerFrame:CreateTexture(nil, "BORDER", v[1])
        border:ClearAllPoints()
        border:SetPoint( v[2], v[3], v[4] )
        if v[5] then border:SetPoint( v[5], v[6], v[7] ) end
    end

    -- Create title banner.
    if title then
        containerFrame.title = containerFrame:CreateFontString(nil, "ARTWORK", "SplashHeaderFont")  -- "GameFontNormalLarge"?
        containerFrame.title:SetPoint("TOP", 0, -margin-1)
        ----local titleFont = containerFrame.title:GetFontObject()
        ----titleFont:SetTextColor(1,1,1)
        ----titleFont:SetShadowColor(0,0,1)
        containerFrame.title:SetText(title)
    end

    -- Create CLOSE button.
    containerFrame.closeBtn = CreateFrame("Button", nil, containerFrame, "UIPanelButtonTemplate")
    containerFrame.closeBtn:SetText("Close")
    containerFrame.closeBtn:SetPoint("BOTTOM", 0, 12)
    containerFrame.closeBtn:SetSize(width/3, 24)
    containerFrame.closeBtn:SetScript("OnClick", function(self) self:GetParent():Hide() end)

    -- [X] BUTTON --
    local x, y, size = -7, -8, 22
    if not isRetailWoW() then
        x, y, size = 1, 1, 36
    end
    containerFrame.xBtn = CreateFrame("Button", nil, containerFrame, "UIPanelCloseButton")
    containerFrame.xBtn:SetFrameLevel( containerFrame:GetFrameLevel()+1 )
    containerFrame.xBtn:SetSize(size, size)
    containerFrame.xBtn:SetPoint("TOPRIGHT", containerFrame, "TOPRIGHT", x, y)
    containerFrame.xBtn:SetScript("OnClick", function(self) self:GetParent():Hide() end)

    -----------------------------------------------------------------
    -- Create a scroll frame (view port) inside the container frame.
    -----------------------------------------------------------------

    -- Create the scrolling parent frame and size it to fit inside the texture.
    containerFrame.scrollFrame = CreateFrame("ScrollFrame", nil, containerFrame, "UIPanelScrollFrameTemplate")
    if containerFrame.title then
        containerFrame.scrollFrame:SetPoint("TOP", containerFrame.title, "BOTTOM", 0, -8)
    else
        containerFrame.scrollFrame:SetPoint("TOP", containerFrame, "TOP", 0, -margin)
    end
    containerFrame.scrollFrame:SetPoint("LEFT", margin, 0)
    containerFrame.scrollFrame:SetPoint("BOTTOM", containerFrame.closeBtn, "TOP", 0, margin*0.6)
    containerFrame.scrollFrame:SetPoint("RIGHT", -23, 0)

    containerFrame.scrollFrame.ScrollBar:ClearAllPoints()
	containerFrame.scrollFrame.ScrollBar:SetPoint("TOPLEFT", containerFrame.scrollFrame, "TOPRIGHT", 2, -17)
	containerFrame.scrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", containerFrame.scrollFrame, "BOTTOMRIGHT", 18, 16)

    containerFrame.scrollFrame.ScrollBar.texture = containerFrame.scrollFrame.ScrollBar:CreateTexture(nil, "BACKGROUND")
    containerFrame.scrollFrame.ScrollBar.texture:SetPoint("TOPLEFT", 0, -4)
    containerFrame.scrollFrame.ScrollBar.texture:SetPoint("BOTTOMRIGHT", -1, 5)
    containerFrame.scrollFrame.ScrollBar.texture:SetColorTexture(0.08, 0.08, 0.08, 0.5)

    ----containerFrame.scrollFrame.ScrollBar:SetValueStep(0.0001)  <<< HAD NO EFFECT.

    containerFrame.scrollFrame.defaultOnMouseWheel = containerFrame.scrollFrame:GetScript("OnMouseWheel")
    containerFrame.scrollFrame:SetScript("OnMouseWheel", function(self, delta)  -- See Mayron's video (above) @ ~30 minutes.
            -- Customize mouse wheel scroll speed.
            if not self.lastWheelTime then self.lastWheelTime = 0 end
            local t = GetTime()  -- seconds
            local dt = t - self.lastWheelTime
            self.lastWheelTime = t

            -- Compute step size based on mousewheel speed.  (Call SetMouseWheelStepSpeed() to change these values.)
            local step = delta * self.stepSize
            if     dt <= 0.015 then step = step * self.stepMultSpeed3  -- Largest multipler.
            elseif dt <= 0.025 then step = step * self.stepMultSpeed2
            elseif dt <= 0.200 then step = step * self.stepMultSpeed1  -- Smallest multiplier.
            end

            local newValue = self:GetVerticalScroll() - step
            if (newValue < 0) then newValue = 0
            elseif (newValue > self:GetVerticalScrollRange()) then newValue = self:GetVerticalScrollRange()
            end
            self:SetVerticalScroll(newValue)
        end)

    -- Create the scrolling child frame, set its width to fit, and give it an arbitrary minimum height of 1.
    containerFrame.scrollChild = CreateFrame("Frame", nil, containerFrame.scrollFrame)
    containerFrame.scrollChild:SetWidth( containerFrame:GetWidth()-18 )
    containerFrame.scrollChild:SetHeight( 1 )  -- Specifies an arbitrary minimum height.
    containerFrame.scrollChild.bg = containerFrame.scrollChild:CreateTexture(nil, "BACKGROUND")
    containerFrame.scrollChild.bg:SetAllPoints(containerFrame.scrollFrame, true)
    containerFrame.scrollChild.bg:SetColorTexture(0.6, 0.3, 0.0, 0.13)  -- R, G, B, a
    containerFrame.scrollFrame:SetScrollChild( containerFrame.scrollChild )

    ------------------------
    -- Extension functions.
    ------------------------

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- AddText(text, dx, dy, fontName):
    --      Note: You can change color of text parts using the "|cAARRGGBB...|r" syntax.
    containerFrame.strings = {}
    containerFrame.nextVertPos = 0  -- # of pixels from the top to add the next text string.
    containerFrame.AddText = function(self, text, dx, dy, fontName)
            assert(type(self) == "table")  -- Fails if this function is called using a dot instead of a colon.
            dx = dx or 0
            dy = dy or 1

            local numStrings = #self.strings
            numStrings = numStrings + 1
            local str = self.scrollChild:CreateFontString(nil, "ARTWORK", fontName or "GameFontNormal")
            self.strings[numStrings] = str  -- Store this string.

            str:SetJustifyH("LEFT")  -- Required when using carriage returns or wordwrap.
            str:SetText(text)
            str:SetPoint("LEFT", dx+2, 0)
            str:SetPoint("RIGHT", -20, 0)
            if (numStrings > 1) then
                str:SetPoint("TOP", self.strings[numStrings-1], "BOTTOM", 0, -dy)
            else -- It's the first string to be added.
                dy = math.max(dy, 0)  -- Prevents a scrolling bug when thumb is dragged below bottom of scrollbar.
                str:SetPoint("TOP", self.scrollChild, "TOP", 0, -dy)
            end
            str.verticalScrollPos = self.nextVertPos  -- Each string knows its position.
            self.nextVertPos = self.nextVertPos + str:GetHeight() + dy

            return str  -- Return the font string so it can be customized.
        end

    ---->>> DIDN'T CLEAR THE FRAME!
    ------ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    ------ Clear():
    ------ Clears all text from the frame.
    ----containerFrame.Clear = function(self)
    ----        assert(type(self) == "table")  -- Fails if this function is called using a dot instead of a colon.
    ----        for i = 1, #self.strings do
    ----            self.strings[i] = nil  -- Release the fontstring for the garbage collector to collect.
    ----        end
    ----        self.nextVertPos = 0
    ----    end

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- GetNextVerticalPosition():
    -- Returns vertical position (in pixels) of where the next line will be added by AddText().
    containerFrame.GetNextVerticalPosition = function(self)
            return self.nextVertPos
        end

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- SetVerticalScroll(offsetInPixels):
    -- Scrolls to 'offsetInPixels' from the top.  'offsetInPixels' must be positive!
    containerFrame.SetVerticalScroll = function(self, offsetInPixels)
            assert(type(self) == "table")  -- Fails if this function is called using a dot instead of a colon.
            assert(offsetInPixels >= 0)
            local delaySecs = 0.1
            if (GetTime() - self.creationTime < delaySecs and offsetInPixels > 0) then
                -- Must delay executing this function until 0.1 secs after the control
                -- was created.  Otherwise, the scrollbar's thumb position and/or the
                -- control's contents do not scroll correctly.
                C_Timer.After(delaySecs, function() self:SetVerticalScroll(offsetInPixels) end)
            else
                -- Scroll to the specified offset.
                self.scrollFrame:SetVerticalScroll(offsetInPixels)
            end
        end

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- SetScrollTextBackColor(r, g, b, alpha):
    containerFrame.SetScrollTextBackColor = function(self, r, g, b, alpha)
            assert(type(self) == "table")  -- Fails if this function is called using a dot instead of a colon.
            self.scrollChild.bg:SetColorTexture(r, g, b, alpha)
        end

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- SetMouseWheelStepSpeed(stepSize, stepMultSpeed1, stepMultSpeed2, stepMultSpeed3):
    --  stepSize: How far the text scrolls from a single mouse wheel click.
    --  stepMultSpeed1: Smallest multiplier applied to stepSize when mouse wheel is scrolled faster than normal.
    --  stepMultSpeed2: Medium multiplier applied to stepSize when mouse wheel is scrolled even faster.
    --  stepMultSpeed3: Largest multiplier applied to stepSize when mouse wheel is scrolled even faster.
    containerFrame.SetMouseWheelStepSpeed = function(self, stepSize, stepMultSpeed1, stepMultSpeed2, stepMultSpeed3)
            local scrollFrame = self.scrollFrame
            scrollFrame.stepSize = stepSize or 20
            scrollFrame.stepMultSpeed1 = stepMultSpeed1 or 2.5
            scrollFrame.stepMultSpeed2 = stepMultSpeed2 or 4
            scrollFrame.stepMultSpeed3 = stepMultSpeed3 or 8
        end

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- SetMouseWheelDefault():
    -- Restores the default mouse wheel scrolling.  (One mouse wheel click scrolls half a page.)
    containerFrame.SetMouseWheelDefault = function(self)
            self.scrollFrame:SetScript("OnMouseWheel", self.scrollFrame.defaultOnMouseWheel)
        end

    -----------
    -- Finish.
    -----------
    containerFrame:SetMouseWheelStepSpeed()
    containerFrame.creationTime = GetTime()
    return containerFrame
end


--#############################################################################
-------------------------------------------------------------------------------
-- GroupBox functions.
-------------------------------------------------------------------------------
--#############################################################################

local CGroupBox = {}


-- ****************************************************************************
-- Make the title's background size the same as the current title's text size,
-- plus extra margin space along each edge (if specified).
-- Call this if title text is changed so title background size matches the text.
-- The margins parameter must be a table containing elements named left, right,
-- top, and bottom.  e.g.  {left=1, right=1, top=1, bottom=1}
-- ****************************************************************************
function CGroupBox.UpdateTitleSize(thisGB, margins)
    assert(type(margins) == "table", "Expected a table for margins, got a ".. type(margins)..".")
    margins = margins or {}
    margins.left = margins.left or 0
    margins.right = margins.right or 0
    margins.top = margins.top or 0
    margins.bottom = margins.bottom or 0

    thisGB.titleBackground:SetPoint("TOPLEFT", thisGB.title, "TOPLEFT", -margins.left, margins.top)
    thisGB.titleBackground:SetPoint("BOTTOMRIGHT", thisGB.title, "BOTTOMRIGHT", margins.right, -margins.bottom)
end

-- ****************************************************************************
-- Change the title text's background color.
-- ****************************************************************************
function CGroupBox.SetTitleBackColor(thisGB, r, g, b, alpha)
    if not thisGB.titleBackground then
        thisGB.titleBackground = thisGB:CreateTexture(nil, "BACKGROUND")
        thisGB.titleBackground:SetTexture(kTexture_White8x8)
    end
    thisGB.titleBackground:SetVertexColor(r, g, b, alpha)
    CGroupBox.UpdateTitleSize(thisGB, {left=1, right=1, top=1, bottom=1})  -- Make background size same as title size.
end

-- ****************************************************************************
-- Sets the color of the groupbox background.
-- ****************************************************************************
function CGroupBox.SetBackColor(thisGB, r, g, b, alpha)
    thisGB.background:SetVertexColor(r, g, b, alpha or 1)
end

-- ****************************************************************************
-- Gets the color of the groupbox background.
-- ****************************************************************************
function CGroupBox.GetBackColor(thisGB)
    return thisGB.background:GetVertexColor()
end

-- ****************************************************************************
-- Creates and returns a group box frame with the given title.
-- Set title to nil if you don't want title text for the groupbox.
-- Set width to nil to have the groupbox expand to the right edge of its parent (minus space for a margin).
-- Set height to nil to have the groupbox expand to the bottom of its parent (minus space for a margin).
-- ****************************************************************************
local function CreateGroupBox(title, anchor, parent, relativeAnchor, x, y, width, height)  --DJUadded
    ----local groupbox = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    ----groupbox:SetBackdrop{  -- See WoW file, Backdrop.lua, for many sample backdrop tables.
    ----    bgFile = kTexture_White8x8,  ----tile=true,  tileSize=8,
    ----    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",  tileEdge=true,  edgeSize=16,
    ----    insets = {left=4, right=4, top=4, bottom=4},
    ----}
    local groupbox = CreateFrame("Frame", nil, parent, "TooltipBorderBackdropTemplate")

    groupbox:SetPoint(anchor, parent, relativeAnchor, x, y)
    if (width and width > 0) then
        groupbox:SetWidth(width)
    else
        groupbox:SetPoint("RIGHT", -16, 0)
    end
    if (height and height > 0) then
        groupbox:SetHeight(height)
    else
        groupbox:SetPoint("BOTTOM", 0, -16)
    end

    groupbox.background = groupbox:CreateTexture(nil, "BACKGROUND")
    groupbox.background:SetTexture(kTexture_White8x8)
    local margin = 4
    groupbox.background:SetPoint("TOPLEFT", margin, -margin)
    groupbox.background:SetPoint("BOTTOMRIGHT", -margin, margin)
    groupbox.background:SetVertexColor(0.1, 0.1, 0.1,  0.5)  -- Set a color so the background isn't transparent.
    ----CGroupBox.SetBackColor(groupbox, 1,0,1, 1)  -- FOR TESTING.

    if title then
        groupbox.title = groupbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        groupbox.title:SetPoint("TOPLEFT", 6, 12)
        groupbox.title:SetJustifyH("LEFT")
        groupbox.title:SetText(title or "")
    end

    -- Extension functions.
    groupbox.GetBackColor       = CGroupBox.GetBackColor
    groupbox.SetBackColor       = CGroupBox.SetBackColor
    groupbox.SetTitleBackColor  = CGroupBox.SetTitleBackColor
    groupbox.UpdateTitleSize    = CGroupBox.UpdateTitleSize

    return groupbox
end


--#############################################################################
-------------------------------------------------------------------------------
-- Utility Functions.  --DJUadded--
-------------------------------------------------------------------------------
--#############################################################################


-- ****************************************************************************
function CUtil.handleGlobalMouseClick(button)
    -- Closes any open dropdown list if user clicks outside of it.
    -- Call this function from a GLOBAL_MOUSE_DOWN event handler in your addon.
    -- Based on \Interface\SharedXML\UIDropDownMenu.lua, UIDropDownMenu_HandleGlobalMouseEvent().
        if not gDropDownListBoxFrame or not gDropDownListBoxFrame:IsShown() then return end  -- Nothing to do.
        if button == nil or button == "LeftButton" then
            -- Did user click somewhere inside the dropdown or its listbox?  If so, exit.
            if gDropDownListBoxFrame:IsMouseOver() then return end
            if gDropDownListBoxFrame.dropdown and gDropDownListBoxFrame.dropdown:IsMouseOver() then return end
            -- Otherwise, user clicked outside of the dropdown.  Close its listbox.
            gDropDownListBoxFrame:Hide()
        end
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- NOTE: While the following hooksecurefunc line works nicely without extra work needed from the addon using
    --       the dropdown in this file, I did not prefer using it because it is always called on every
    --       mouse click, even when the UI containing our dropdown isn't being displayed.  (And even if
    --       the UI doesn't contain any dropdown controls!)
    --       The more robust solution for closing dropdowns when users click outside of them is to require
    --       addon developers to handle the GLOBAL_MOUSE_DOWN event and call handleGlobalMouseClick() in that
    --       event handler.  This approach permits registering the event when the UI is shown, and
    --       unregistering the event when the UI is closed.  Then mouse clicks are only causing extra
    --       work while the UI is open.  And if the UI doesn't use any dropdown controls, the addon developer
    --       can simply do nothing and ignore GLOBAL_MOUSE_DOWN events.
--~     hooksecurefunc("UIDropDownMenu_HandleGlobalMouseEvent", private.UDControls.handleGlobalMouseClick)


-- ****************************************************************************
function CUtil.DisplayAllFonts(width, height)
        -- Create the fonts frame, if necessary.
        if (_G.FontNamesScrollFrame == nil) then
            _G.FontNamesScrollFrame = CreateTextScrollFrame(UIParent, "*** Available Game Fonts ***", width or 1000, height or 600)

            local fontNames = _G.GetFonts()
            table.sort(fontNames, function(name1, name2) return (name1 < name2); end)
            local name
            for i = 1, #fontNames do
                name = fontNames[i]
                if (name and type(name) == "string" ----and name ~= ""
                    and name ~= "ScrollingMessageFrame"
                    and name:sub(1, 6) ~= "table:"
                  ) then
                    ----print("DBG: fontNames["..i.."]:", name)
                    _G.FontNamesScrollFrame:AddText(name, nil, nil, name)
                end
            end
        end

        -- Show the fonts frame.
        _G.FontNamesScrollFrame:Show()
    end


-- ****************************************************************************
CUtil.MsgBoxScripts = {}  -- Used by MsgBox(), MsgBox3(), and MsgBox_Command().


-- ****************************************************************************
function CUtil.MsgBox( msg,    -- Deprecated 2024-09-23. (Replaced by MsgBox3.)
                    btnText1, btnFunc1,
                    btnText2, btnFunc2,
                    customData, customData2, -- Can be tables of values if more than two data parameters are needed.
                    bShowAlertIcon, soundID, timeoutSecs, preferredIndex)
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
--~ EXAMPLE 1: Basic message with a single "Okay" button.
--~     MsgBox("Job done.")
--~
--~ EXAMPLE 2: A prompt with two choices that each call a function that uses a custom data buffer (myDataBuffer).
--~     MsgBox("Bad data found!  Click OK to use it anyway, or CANCEL to restore defaults.",
--~             _G.OKAY, function(thisPopupFrame, data, data2)  -- 'data2' unused in this example.
--~                             local dataBuffer = data
--~                             saveMyData(dataBuffer)
--~                         end,
--~             _G.CANCEL, function(thisPopupFrame, data, reason)  -- 'reason' can be "clicked", "timeout", or "override".
--~                             local dataBuffer = data
--~                             restoreMyDefaultData(dataBuffer)
--~                         end,
--~             myDataBuffer, nil,  -- data, data2
--~             true, SOUNDKIT.ALARM_CLOCK_WARNING_3, 0, 3)  -- Icon, Sound, Timeout, Preferred Index.
--~
--~ EXAMPLE 3: A Yes/No prompt with a single function for "Yes", and a 15 second time limit.
--~     MsgBox("Uh oh! Show help?\n\n(This message goes away after 15 seconds.)",
--~             _G.YES, showMyHelp,
--~             _G.NO, nil,
--~             nil, nil,  -- data, data2
--~             false, SOUNDKIT.ALARM_CLOCK_WARNING_3, 15)  -- Icon, Sound, Timeout, Preferred Index.
--~
--~ EXAMPLE 4: Demonstrates how to pass more than two parameters to a button's handler function.
--~     local SrcName = "My DPS Profile"
--~     local DestName = "My Tank Profile"
--~     MsgBox( 'Are you sure?\n\nThe profile "'..SrcName..'" will be copied to "'..DestName..'".',
--~             "Copy Profile", function(thisPopupFrame, data, data2)  -- 'data2' unused in this example.
--~                                 data.profileFrame:copyProfile( data.srcName, data.destName )
--~                             end,
--~             _G.CANCEL, nil,
--~             {profileFrame=ProfileFrame, srcName=SrcName, destName=DestName}, nil,  -- data, data2
--~             false)  -- Icon, Sound, Timeout, Preferred Index.
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    local msgboxID = "MSGBOX_FOR_" .. kAddonFolderName

    local cmdResult = CUtil.MsgBox_Command(msgboxID, msg, btnText1, btnFunc1) -- Pass our ID and first 3 params to MsgBox_Command().
    if cmdResult ~= nil then return cmdResult end  -- Caller specified a message box command, so return now.

    assert(msg and type(msg) == "string" and msg ~= "")
    assert(btnFunc1 == nil or type(btnFunc1) == "function")
    assert(btnFunc2 == nil or type(btnFunc2) == "function")
    assert(bShowAlertIcon == true or bShowAlertIcon == false or bShowAlertIcon == nil)

    if (btnText1 == "" or btnText1 == nil) then btnText1 = OKAY end
    if (btnText2 == "") then btnText2 = nil end
    if (bShowAlertIcon ~= true) then bShowAlertIcon = nil end  -- Forces it to be 'true' or 'nil'.

    _G.StaticPopupDialogs[msgboxID] =
    {
        text = (msg or ""),
        showAlert = bShowAlertIcon,
        sound = soundID,
        timeout = timeoutSecs,

        enterClicksFirstButton = true,
        hideOnEscape = true,
        whileDead = true,
        exclusive = true,  -- Makes the popup go away if any other popup is displayed.
        preferredIndex = preferredIndex or 1,  -- Which of the global StaticPopup frames to use (if available).

        button1 = btnText1,
        OnAccept = btnFunc1,

        button2 = btnText2,
        OnCancel = btnFunc2,

        OnShow = function(self, customData)  -- 'self' is the popup frame.
            ----local dialog = _G.StaticPopupDialogs[ self.which ]
            local callback = CUtil.MsgBoxScripts["OnShow"]
            if callback then callback(self, customData) end
        end,

        OnHide = function(self)  -- 'self' is the popup frame.
            local dialog = _G.StaticPopupDialogs[ self.which ]
            dialog.data = nil
            dialog.data2 = nil
            local callback = CUtil.MsgBoxScripts["OnHide"]
            if callback then callback(self) end
        end,
    }

    local msgbox = _G.StaticPopup_Show(msgboxID)
    if msgbox then
        -- Note: 'data' and 'data2' are passed to your OnAccept() function, and only 'data' is passed to OnCancel().
        msgbox.data = customData
        msgbox.data2 = customData2
    end
    return msgbox
end


-- ****************************************************************************
-- Similar to CUtil.MsgBox(), except this function allows up to three buttons instead of two.
-- Also, there is only one customData parameter instead of two.  (Pass multiple parameters as a table.)
-- ENTER key triggers button 1.
-- ESCAPE key triggers the button named _G.CANCEL (if it exists), or _G.NO (if it exists).
-- Y key triggers the button named _G.YES (if it exists).
-- N key triggers the button named _G.NO (if it exists).
-- The 'boolFlags' parameter can be nil, true to show an alert icon, or a string of StaticPopupDialog
-- flags (separated by spaces) to set true.  To set a flag false, put a dash '-' in front of its name.
-- For a list of flags that can be set, see preInit() below.
-- ****************************************************************************
function CUtil.MsgBox3( msg,
                    btnText1, btnFunc1,
                    btnText2, btnFunc2,
                    btnText3, btnFunc3,
                    customData, -- Can be tables of values.
                    boolFlags, soundID, timeoutSecs, preferredIndex)
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
--~ EXAMPLE 1: Basic message with a single "Okay" button.
--~     MsgBox3("Job done.")
--~
--~ EXAMPLE 2: A prompt with two choices that each call a function that uses a custom data buffer (myDataBuffer).
--~     MsgBox3("Bad data found!  Click OK to use it anyway, or CANCEL to restore defaults.",
--~             _G.OKAY, function(thisPopupFrame, data, reason)  -- 'reason' can be "clicked", "timeout", or "override".
--~                             local dataBuffer = data
--~                             saveMyData(dataBuffer)
--~                         end,
--~             _G.CANCEL, function(thisPopupFrame, data, reason)
--~                             local dataBuffer = data
--~                             restoreMyDefaultData(dataBuffer)
--~                         end,
--~             nil, nil,  -- Button3 hidden.
--~             myDataBuffer,  -- data
--~             "showAlert fullScreenCover", SOUNDKIT.ALARM_CLOCK_WARNING_3, 0, 3)  -- Flags, Sound, Timeout, Preferred Index.
--~
--~ EXAMPLE 3: A prompt with three buttons (YES/NO/CANCEL), each call a function that uses a custom data buffer (myDataBuffer).
--~     MsgBox3("Save data before continuing?",
--~             _G.YES, function(thisPopupFrame, data, reason)  -- 'reason' can be "clicked", "timeout", or "override".
--~                             local dataBuffer = data
--~                             saveMyData(dataBuffer)
--~                             processData(dataBuffer)
--~                         end,
--~             _G.NO, function(thisPopupFrame, data, reason)
--~                             local dataBuffer = data
--~                             processData(dataBuffer)
--~                         end,
--~             _G.CANCEL, function(thisPopupFrame, data, reason)
--~                             print("Operation canceled.")
--~                         end,
--~             myDataBuffer,  -- data
--~             "showAlert -whileDead", SOUNDKIT.IG_MAINMENU_OPEN, 0, 3)  -- Flags, Sound, Timeout, Preferred Index.
--~
--~ EXAMPLE 4: A Yes/No prompt with a single function for "Yes", and a 15 second time limit.
--~     MsgBox3("Uh oh! Show help?\n\n(This message goes away after 15 seconds.)",
--~             _G.YES, showMyHelp,  -- Button1 calls function showMyHelp().
--~             _G.NO, nil,  -- Button2 displayed, but does nothing.
--~             nil, nil,  -- Button3 hidden.
--~             nil,  -- data
--~             nil, nil, 15)  -- Flags, Sound, Timeout, Preferred Index.
--~
--~ EXAMPLE 5: Setting custom OnShow/OnHide script functions.
--~     MsgBox3("HookScript", "OnShow", function(self) print("MsgBox OnShow() called.") end  -- (Only need to do this once.)
--~     MsgBox3("HookScript", "OnHide", function(self) print("MsgBox OnHide() called.") end  -- (Only need to do this once.)
--~     MsgBox3("Hello world!")
--~
--~ EXAMPLE 6: Checking if a message box is being shown, and getting its frame it it is.
--~     if MsgBox3("IsShown") then
--~         print( "The frame for the displayed message box is:", MsgBox3("GetFrame") )
--~     end
--~
--~ For more info, see ...
--~     https://warcraft.wiki.gg/wiki/Creating_simple_pop-up_dialog_boxes
--~     https://wowpedia.fandom.com/wiki/Creating_simple_pop-up_dialog_boxes
--~     https://wowwiki-archive.fandom.com/wiki/Creating_simple_pop-up_dialog_boxes
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    local msgboxID = "MSGBOX3_FOR_" .. kAddonFolderName

    local cmdResult = CUtil.MsgBox_Command(msgboxID, msg, btnText1, btnFunc1) -- Pass our ID and first 3 params to MsgBox_Command().
    if cmdResult ~= nil then return cmdResult end  -- Caller specified a message box command, so return now.

    assert(msg and type(msg) == "string" and msg ~= "")
    assert(btnFunc1 == nil or type(btnFunc1) == "function")
    assert(btnFunc2 == nil or type(btnFunc2) == "function")
    assert(btnFunc3 == nil or type(btnFunc3) == "function")

    if (btnText1 == "" or btnText1 == nil) then btnText1 = OKAY end
    if (btnText2 == "") then btnText2 = nil end
    if (btnText3 == "") then btnText3 = nil end
    btnFunc1 = btnFunc1 or DoNothing
    btnFunc2 = btnFunc2 or DoNothing
    btnFunc3 = btnFunc3 or DoNothing

    if not _G.StaticPopupDialogs[msgboxID] then
        _G.StaticPopupDialogs[msgboxID] =
        {
            --_________________________________________________________________
            preInit = function(self)  -- 'self' is the StaticPopupDialogs table for this message box.
                -- For a list of flags, see https://warcraft.wiki.gg/wiki/Creating_simple_pop-up_dialog_boxes .
                self.whileDead = true
                self.exclusive = true  -- Makes the popup go away if any other popup is displayed.
                self.showAlert = nil
                self.showAlertGear = nil
                self.fullScreenCover = nil  -- System modal message box.  (Darkens entire screen.)
                self.verticalButtonLayout = nil
                self.interruptCinematic = nil
                self.notClosableByLogout = nil
                self.noCancelOnReuse = nil
                self.cancels = nil
            end,
            --_________________________________________________________________
            postInit = function(self)  -- 'self' is the StaticPopupDialogs table for this message box.
                -- Prevents caller from changing these options.
                self.selectCallbackByIndex = true  -- Required when using OnButton1, OnButton2, etc.  (Return true from them to keep popup open.)
                self.enterClicksFirstButton = nil  -- Required!  ENTER key handled in our own keypress function.
                self.hideOnEscape = nil  -- Required!  ESCAPE key handled in our own keypress function.
                self.hasMoneyFrame = nil
                self.hasMoneyInputFrame = nil
                self.hasEditBox = nil
                self.hasDropdown = nil
                self.hasItemFrame = nil
                self.subText = nil
                self.compactItemFrame = nil
                self.extraButton = nil
            end,
            --_________________________________________________________________
            OnShow = function(self, customData)  -- 'self' is the popup frame.
                local dialogInfo = _G.StaticPopupDialogs[ self.which ]
                dialogInfo.msgboxFrame = self

                -- Customize buttons.
                local popupName = self:GetName()
                local minBtnH = 24
                for i = 1, 4 do
                    local btn = _G[popupName.."Button"..i]
                    if btn:GetHeight() < minBtnH then
                        btn:SetHeight(minBtnH)
                        deltaH = 1
                    end
                end

                -- Customize frame height (if necessary).
                C_Timer.After(0.01, function()
                    local frameH = self:GetHeight()
                    local minH = minBtnH + 56
                    if self.AlertIcon and self.AlertIcon:IsShown() then minH = minH + 4 end
                    if frameH < minH then self:SetHeight(minH) end
                end)

                -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
                -- Process Y, N, ENTER, and ESCAPE keys.
                self:SetScript("OnKeyDown", function(self, key)
                    local bPassKeyToParent = false
                    if key == "ENTER" then
                        StaticPopup_OnClick(self, 1)  -- Trigger button1.
                    elseif key == "ESCAPE" then
                        local btnNum = CUtil.findSPDButton(self, _G.CANCEL) or CUtil.findSPDButton(self, _G.NO)
                        if btnNum then StaticPopup_OnClick(self, btnNum)
                        ----else self:Hide()  -- No cancel button, so just close the frame.
                        end
                    elseif key == "Y" then
                        local btnNum = CUtil.findSPDButton(self, _G.YES)
                        if btnNum then StaticPopup_OnClick(self, btnNum)
                        ----else bPassKeyToParent = true
                        end
                    elseif key == "N" then
                        local btnNum = CUtil.findSPDButton(self, _G.NO)
                        if btnNum then StaticPopup_OnClick(self, btnNum)
                        ----else bPassKeyToParent = true
                        end
                    else
                        bPassKeyToParent = true
                    end
                    if not InCombatLockdown() then self:SetPropagateKeyboardInput(bPassKeyToParent) end
                end)
                -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

                local callback = CUtil.MsgBoxScripts["OnShow"]
                if callback then callback(self, customData) end
            end,
            --_________________________________________________________________
            OnHide = function(self)  -- 'self' is the popup frame.
                local dialogInfo = _G.StaticPopupDialogs[ self.which ]
                local callback = CUtil.MsgBoxScripts["OnHide"]
                if callback then callback(self) end
                dialogInfo.msgboxFrame = nil
            end,
            --_________________________________________________________________
        }
    end

    -- If a prior message is still showing, wait for it to close.
    local dialogInfo = _G.StaticPopupDialogs[msgboxID]
    local delaySecs = dialogInfo.msgboxFrame and 0.15 or 0 -- Allow time for prior message to close.
    C_Timer.After( delaySecs, function()
        ----assert(dialogInfo.msgboxFrame == nil) -- Fails if our wait time was too short.

        -- Set caller's parameters.
        dialogInfo:preInit()
        dialogInfo.sound = soundID
        dialogInfo.timeout = timeoutSecs
        dialogInfo.preferredIndex = preferredIndex or 1  -- Which of the global StaticPopup frames to use (if available).

        dialogInfo.text = (msg or "")
        dialogInfo.button1 = btnText1
        dialogInfo.button2 = btnText2
        dialogInfo.button3 = btnText3
        dialogInfo.OnButton1 = btnFunc1
        dialogInfo.OnButton2 = btnFunc2
        dialogInfo.OnButton3 = btnFunc3

        if (boolFlags == true) then dialogInfo.showAlert = true  -- Legacy support for 'bShowAlertIcon' param.
        elseif (boolFlags == false or boolFlags == nil) then dialogInfo.showAlert = nil  -- Legacy support for 'bShowAlertIcon' param.
        else -- Parse boolFlags string.
            local delimiter = " "
            for flag in string.gmatch(boolFlags, "([^"..delimiter.."]+)") do
                flag = flag:trim()
                ----print("MsgBox boolFlag:", flag)  -- For debugging.
                if flag:sub(1,1) == "-" then  -- If starts with '-', set flag to nil (false).
                    dialogInfo[flag:sub(2)] = nil
                else  -- Set flag to true.
                    dialogInfo[flag] = true
                end
            end
        end
        dialogInfo:postInit()

        -- Show the message box.
        _G.StaticPopup_Show(msgboxID, nil, nil, customData)  -- which, text1, text2, customData
    end)
end


-- ****************************************************************************
--  Helper function that executes configuration or status commands for MsgBox3()
--  and MsgBox() popup frames.
--  NOTE: This implementation is required instead of just frame:IsShown() or
--  frame:HookScript() because message boxes don't have their own permanent frame.
--  One is temporarily assigned to them by the game each time a message is shown.
--
-- Supported commands:
--      MsgBox_Command( msgboxID, "IsShown" )
--      MsgBox_Command( msgboxID, "GetFrame" )
--      MsgBox_Command( msgboxID, "HookScript", "OnShow", function(self) )
--      MsgBox_Command( msgboxID, "HookScript", "OnHide", function(self) )
--      MsgBox_Command( msgboxID, "SendKey", keyName )  -- e.g. "ESCAPE", "ENTER", "Y", "N".
--
-- Returns: Returns nil if the cmd parameter is not a supported command.  Otherwise, it returns
--          whatever the specified command requested.  If the command normally returns nothing,
--          then true or false is returned indicating success or failure.
-- ****************************************************************************
function CUtil.MsgBox_Command(msgboxID, cmd, arg1, arg2)
    if cmd == "HookScript" then
        local scriptName, scriptFunc = arg1, arg2
        ----print(kAddonFolderName, "CUtil.MsgBox_Command(", cmd, scriptName, scriptFunc, ")")
        assert(scriptFunc == nil or type(scriptFunc) == "function")  -- Fails if bad parameters passed in.
        assert(scriptName == "OnShow" or scriptName == "OnHide") -- Fails if unsupported script name passed in.
        CUtil.MsgBoxScripts[scriptName] = scriptFunc
        return true
    elseif cmd == "IsShown" then
        assert(arg1 == nil and arg2 == nil)
        local dialogInfo = _G.StaticPopupDialogs[msgboxID]
        if dialogInfo and dialogInfo.msgboxFrame then return true end
    elseif cmd == "GetFrame" then
        assert(arg1 == nil and arg2 == nil)
        local dialogInfo = _G.StaticPopupDialogs[msgboxID]
        if dialogInfo and dialogInfo.msgboxFrame then return dialogInfo.msgboxFrame end
--~ --      MsgBox_Command( msgboxID, "Click", buttonNumberOrText )  -- e.g. 1, 2, 3, OKAY, CANCEL, YES, NO.
--~     elseif cmd == "Click" then
--~         local dialogInfo = _G.StaticPopupDialogs[msgboxID]
--~         if dialogInfo and dialogInfo.msgboxFrame then
--~             if type(arg1) == "string" then
--~                 arg1 = CUtil.findSPDButton(dialogInfo, arg1)  -- Find button number contain the text.
--~             end
--~             if arg1 >= 1 and arg1 <= 3 then
--~                 StaticPopup_OnClick(dialogInfo.msgboxFrame, arg1)
--~                 return true
--~             end
--~         end
    elseif cmd == "SendKey" then
        assert(type(arg1) == "string" and arg1 ~= "")
        local dialogInfo = _G.StaticPopupDialogs[msgboxID]
        if dialogInfo and dialogInfo.msgboxFrame then
            local onKeyDown = dialogInfo.msgboxFrame:GetScript("OnKeyDown")
            onKeyDown(dialogInfo.msgboxFrame, arg1)
            return true
        end
    else -- A command was not passed in.
        return nil
    end

    return false  -- If we get here, 'cmd' is valid but it failed.
end


-- ****************************************************************************
-- Helper function that finds a specific button name in a static popup dialog.
-- The button's name can either match perfectly, or start with the search text
-- followed by a space character.  Comparisons are case-insensitive.
-- Returns the button's number (1 - 4) if found, or nil if not.
-- ****************************************************************************
function CUtil.findSPDButton(thisStaticPopup, searchText)
    assert(searchText)
    local len = searchText:len()
    searchText = searchText:lower()
    for i = 1, 4 do
        local btn = _G[thisStaticPopup:GetName().."Button"..i]
        if btn and btn:IsShown() and btn:IsEnabled() then
            local fontString = (isRetailWoW() and btn.Text) or btn:GetFontString()
            local text = fontString:GetText():lower()
            if text == searchText
                or (text:sub(1,len) == searchText and text:sub(len+1,len+1) == " ")
            then
                return i
            end
        end
    end
end

-- ****************************************************************************
-- Creates the "new feature" glowy text used in the Blizzard UI for new features.
-- ****************************************************************************
function CUtil.CreateTexture_NEW(parent, bRightJustify, x, y)
    local anchor = parent
    if parent:GetObjectType() ~= "Frame" then
        parent = parent:GetParent()  -- In case caller sent us a FontString, for example.
        assert(parent:GetObjectType() == "Frame") -- Fails if we can't find a frame to use.
    end
    local tex = parent:CreateTexture(nil, "OVERLAY")
    tex:SetTexture("Interface\\Glues\\CHARACTERCREATE\\NewCharacterNotification")
    local minX, maxX, minY, maxY = 0.0, 1.0,  0.0, 0.5  -- (0.0% to 1.0%)
    if bRightJustify then
        minY, maxY = 0.5, 1.0
        tex:SetPoint("LEFT", anchor, "RIGHT", (x or 0), (y or 0))
    else -- Left justify.
        tex:SetPoint("RIGHT", anchor, "LEFT", (x or 0), (y or 0))
    end
    tex:SetTexCoord(minX, maxX, minY, maxY)
    tex:SetSize(128, 64)
    tex:SetScale(0.65)
    return tex
end


-- ****************************************************************************
-- Creates a horizontal divider (separator) line.
-- ****************************************************************************
function CUtil.CreateHorizontalDivider(parent, width, height)
    local divider = parent:CreateTexture(nil, "OVERLAY")
    divider:SetTexture("Interface\\RaidFrame\\Raid-HSeparator")
    ----divider:SetVertexColor(1,1,1, 0.5)
    divider:SetSize(width or 32, height or 12)
    return divider
end


-- ****************************************************************************
-- An object for getting width and height of a text string.
-- EXAMPLE:
--      local TextSize = private.UDControls.TextSize
--      TextSize:SetFontObject("GameFontNormalSmall")
--      print("Text Size (width, height):", TextSize:GetSize("This is the line of text to measure."))
-- ****************************************************************************
CUtil.TextSize = {
    fontString = UIParent:CreateFontString(nil, "BACKGROUND", "GameFontNormal"),

    GetSize = function(self, text)  -- TextSize:GetSize(text)
        local fs = self.fontString
        ----fs:SetHeight(1200)  -- Set to an arbitrary large height to hold all the lines in the text parameter.
        fs:SetText(text)
        local height = fs:GetStringHeight()
        local width = fs:GetUnboundedStringWidth()
        fs:SetText("")
        return width, height
    end,

    SetFontObject = function(self, fontTemplateName)  -- TextSize:SetFontObject()
        self.fontString:SetFontObject(fontTemplateName)
    end,

    SetFont = function(self, fontName, fontSize, fontFlags)  -- TextSize:SetFont()
        self.fontString:SetFont(fontName, fontSize, fontFlags)
    end,

    GetFont = function(self)  -- TextSize:GetFont()
        return self.fontString:GetFont()  -- Returns fontName, fontSize, fontFlags.
    end,
}


-- ****************************************************************************
-- Close any open dropdown menu created by this file's CreateDropDown() function.
-- ****************************************************************************
function CUtil.CloseDropDowns()
    if gDropDownListBoxFrame and gDropDownListBoxFrame:IsShown() then
        gDropDownListBoxFrame:Hide()
    end
end


-- ****************************************************************************
-- Creates a colored outline around the specified frame.  (Useful for debugging frame positions.)
-- The "expand" option is for thicknesses greater than 1, and can be ...
--      nil - The outline will be centered on the frame's sides.
--      -1  - The outline will expand inward from the frame's sides.
--      1   - The outline will expand outward from the frame's sides.
-- EXAMPLES:
--      private.UDControls.Outline( yourFrame, {r=1, g=0, b=0, a=0.5, thickness=5, expand=-1} )
--      private.UDControls.Outline( yourFrame, {version=1, thickness=3} )
-- ****************************************************************************
function CUtil.Outline(frame, options)
    local r = (options and options.r) or 1
    local g = (options and options.g) or 1
    local b = (options and options.b) or 1
    local a = (options and options.a) or 1
    local thickness = (options and options.thickness) or 1
    local version = (options and options.version) or -1
    local expand = (options and options.expand) or 0

    local ofs = (version==1 and 0) or (thickness / 2)
    local ex = (version==1 and 0) or (expand * ofs)
    ----ex = ex + expand  -- For testing.
    frame._edges = frame._edges or {}
    for i = 1, 4 do
        frame._edges[i] = frame._edges[i] or frame:CreateLine(nil, "BACKGROUND", nil, 0)
        local line = frame._edges[i]
        line:SetThickness(thickness)
        line:SetColorTexture(r, g, b, a)
        if i == 1 then -- TOP
            line:SetStartPoint("TOPLEFT", -ofs-ex, ex)
            line:SetEndPoint("TOPRIGHT", ofs+ex, ex)
        elseif i == 2 then -- RIGHT
            line:SetStartPoint("TOPRIGHT", ex, -ofs+ex)
            line:SetEndPoint("BOTTOMRIGHT", ex, ofs-ex)
        elseif i == 3 then -- BOTTOM
            line:SetStartPoint("BOTTOMRIGHT", ofs+ex, -ex)
            line:SetEndPoint("BOTTOMLEFT", -ofs-ex, -ex)
        else -- LEFT
            line:SetStartPoint("BOTTOMLEFT", -ex, ofs-ex)
            line:SetEndPoint("TOPLEFT", -ex, -ofs+ex)
        end
    end
end


-- ****************************************************************************
-- Fills the specified frame with a color.  (Useful for debugging frame positions.)
-- EXAMPLE:
--      private.UDControls.FillFrame( yourFrame, {r=1, g=0, b=0, a=0.5, inset=1} )
-- ****************************************************************************
function CUtil.FillFrame(frame, options)
    local r = (options and options.r) or 1
    local g = (options and options.g) or 1
    local b = (options and options.b) or 1
    local a = (options and options.a) or 1
    local inset = (options and options.inset) or 0

    if not frame._fillTexture then
        frame._fillTexture = frame:CreateTexture()
        frame._fillTexture:SetPoint("TOPLEFT", inset, -inset)
        frame._fillTexture:SetPoint("BOTTOMRIGHT", -inset, inset)
    end
    frame._fillTexture:SetColorTexture(r, g, b, a)
end


-- ****************************************************************************
-- Displays tooltips that has text and a title.
-- ****************************************************************************
function CUtil.GameTooltip_SetTitleAndText(title, text, wrapText)
    GameTooltip:ClearLines()
    local r, g, b = HIGHLIGHT_FONT_COLOR:GetRGB()
    GameTooltip:AddLine(title, r, g, b, wrapText)
    r, g, b = NORMAL_FONT_COLOR:GetRGB()
    GameTooltip:AddLine(text, r, g, b, wrapText)
    GameTooltip:Show()
end


-- ****************************************************************************
-- Displays tooltips that has text and a title.
-- ****************************************************************************
function CUtil.GetMouseFocus()
    if GetMouseFocus then return GetMouseFocus() end  -- Older API version.

    -- Else use GetMouseFoci(), which was added in WoW 11.0.
    local frames = GetMouseFoci()
    ----assert(frames[1]) -- If fails, try wrapping calling code in C_Timer.After(0.02, function() ... end)
    return frames[1]
end


-- ****************************************************************************
-- Adds an "edges" variable to the specified table that adds lines around
-- the edges of the frame.  The color of the lines can change be changed
-- by calling frame.edges:setColor(r,g,b,a).
-- ****************************************************************************
function CUtil.EnhanceFrameEdges(frame, x1, y1, x2, y2)
    assert(not frame.edges) -- Don't call this more than once, or with a frame that already has a ".edges" table.
    frame.edges = CreateFrame("Frame", nil,  frame, "ThinBorderTemplate")
    frame.edges:SetPoint("TOPLEFT", frame.titleBox or frame, "TOPLEFT", x1, y1)
    frame.edges:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", x2, y2)
    frame.edges:SetScale(0.92)
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    frame.edges.setColor = function(self, r, g, b, alpha)
        assert(type(self) == "table") -- First param must be a frame.
        r=r or 1; g=g or 1; b=b or 1; alpha=alpha or 1;
        self.color = {r=r, g=g, b=b, alpha=alpha}
        for i, region in ipairs({self:GetRegions()}) do
            if region.SetVertexColor then region:SetVertexColor(r, g, b, alpha); end
        end
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    frame.edges.getColor = function(self)
        if self and self.color then
            return self.color.r, self.color.g, self.color.b, self.color.alpha
        end
        return 1, 1, 1, 1
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    frame.edges:setColor(0.6, 0.6, 0.6,  1)  -- Set a default color.
end

-------------------------------------------------------------------------------
function CUtil.CreateContextMenu(parent, fontTemplateName, sizes)
    local listbox = CreateListBox( parent )
    listbox:Hide()
    local sizes = sizes or {}
    listbox.sizes = {lineHeight   = sizes.lineHeight    or 20,
                    iconSize      = sizes.iconSize      or 19,
                    leftPadding   = sizes.leftPadding   or 6,
                    rightPadding  = sizes.rightPadding  or 6,
                    iconPadding   = sizes.iconPadding   or 8,
                    bottomPadding = sizes.bottomPadding or 3,
                    edgeW         = sizes.edgeW         or 4 }
    listbox.fontTemplateName = fontTemplateName or "GameFontNormal"
    listbox.separatorLeft = listbox.sizes.leftPadding - 4
    listbox.separatorRight = -listbox.sizes.rightPadding
    listbox:Configure(10, 10, listbox.sizes.lineHeight)  -- Temp sizes for now, so we can add items.
    listbox:SetFrameStrata("FULLSCREEN")
    listbox:SetClampedToScreen(true)

    -------------------------
    -- CONTEXT MENU SCRIPTS
    -------------------------

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    listbox:SetScript("OnHide", function(self) self:Clear() end)  -- ContextMenu:OnHide()
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    listbox:SetScript("OnKeyDown", function(self, key)  -- ContextMenu:OnKeyDown()
            -- Close listbox when Escape key is pressed.
            local bPassKeyToParent = false
            if key == "ESCAPE" then self:Close()
            else bPassKeyToParent = true end
            if not InCombatLockdown() then self:SetPropagateKeyboardInput(bPassKeyToParent) end
        end)
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

    ---------------------------
    -- CONTEXT MENU CALLBACKS
    ---------------------------

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- ContextMenu:OnCreateLine()
	listbox:SetCreateLineHandler( function(thisLB) -- (listbox == ContextMenu)
            local iconSize = thisLB.sizes.iconSize
            local leftPadding = thisLB.sizes.leftPadding
            local rightPadding = thisLB.sizes.rightPadding
            local lineButton = CreateFrame("Button", nil, thisLB)

            lineButton.fontString = lineButton:CreateFontString(nil, "OVERLAY", thisLB.fontTemplateName)
            lineButton.fontString:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
            lineButton.fontString:SetJustifyH("LEFT")
            lineButton.fontString:SetPoint("TOPLEFT", lineButton, "TOPLEFT", leftPadding, 0)
            lineButton.fontString:SetPoint("BOTTOMRIGHT", lineButton, "BOTTOMRIGHT", -iconSize - rightPadding, 0)

            lineButton.icon = lineButton:CreateTexture(nil, "ARTWORK")
            lineButton.icon:SetPoint("RIGHT", lineButton, "RIGHT", -1 - rightPadding, 0)
            lineButton.icon:SetSize(iconSize, iconSize)

            return lineButton
        end)
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- ContextMenu:OnDisplayLine()
	listbox:SetDisplayHandler( function(thisLB, lineButton, value, isSelected) -- (listbox == ContextMenu)
            local line = value
            lineButton.fontString:SetText( line.text or "" )
            lineButton:SetEnabled( not line.disabled )
            lineButton.icon:SetTexture( line.icon )
            lineButton:SetTooltipTitleAndText( line.tooltipTitle, line.tooltip ) ----, "ANCHOR_LEFT")
        end)
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    -- ContextMenu:OnClickLine()
	listbox:SetClickHandler( function(thisLB, lineButton, value, mouseButton, bDown) -- (listbox == ContextMenu)
            local line = value
            thisLB:Hide()
            thisLB:ClearSelection()
            if line.func then line.func() end  -- Execute action.
        end)
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

    ---------------------------
    -- CONTEXT MENU FUNCTIONS
    ---------------------------

    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    function listbox:Open(lines, anchor, relativeFrame, relativeAnchor, x, y)  -- ContextMenu:Open()
    -- Each line in the "lines" parameter can have one or more of the following values:
    --  * text      - The text to show for this line in the menu.
    --  * icon      - An icon (path name) to show at end of the menu line.
    --  * func      - The function to execute when the menu line is selected.
    --  * disabled  - Set true to disable the menu line.
    --  * isDivider - Set true to show a divider line in the menu.
    --  * isSpacer  - Set true to show an empty line in the menu.
            local TextSize = CUtil.TextSize
            TextSize:SetFontObject( self.fontTemplateName )

            -- Add items.
            self:Clear()
            local sizes = self.sizes
            local maxWidth = 10
            for i = 1, #lines do
                local line = lines[i]
                if line.isDivider then
                    self:AddSeparator()
                elseif line.isSpacer then
                    line.text = " "
                    self:AddItem(line)
                elseif line.title then
                    assert(nil)  --TODO: Currently unsupported.
                else
                    self:AddItem(line)
                    local width = TextSize:GetSize( line.text )
                    maxWidth = math.max(maxWidth, width)
                end
            end

            -- Set listbox size.
            local listboxW = maxWidth + sizes.iconSize + sizes.iconPadding + sizes.leftPadding + sizes.rightPadding + sizes.edgeW
            local listboxH = (#lines * sizes.lineHeight) + sizes.bottomPadding + sizes.edgeW
            self:Configure(listboxW, listboxH, sizes.lineHeight)  -- Set final size.

            -- Show context menu at mouse location, or at the specified position if provided.
            if anchor then  -- Show at specified position.
                self:SetPoint(anchor, relativeFrame, relativeAnchor, x, y)
            else  -- Show at mouse position.
                x, y = GetScaledCursorPosition()
                x = x - (self:GetWidth() * 0.33)
                y = y + (sizes.lineHeight * 0.5) + sizes.edgeW
                self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
            end
            self:Show()
        end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    function listbox:Close() self:Hide() end  -- ContextMenu:Close()
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    function listbox:SetColor(r, g, b, alpha) self.edges:setColor(r, g, b, alpha) end  -- ContextMenu:SetColor()
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    function listbox:GetColor() return self.edges:getColor() end  -- ContextMenu:GetColor()
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    function listbox:SetBackColor(r, g, b, alpha)  -- ContextMenu:SetBackColor()
        self.Bg:SetVertexColor(r or 1,  g or 1,  b or 1,  alpha or 1)
    end
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --
    function listbox:GetBackColor() return self.Bg:GetVertexColor() end  -- ContextMenu:GetBackColor()
    -- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - --

    CUtil.EnhanceFrameEdges( listbox, 1, -0.5, -1, 0 )  -- (frame, x1, y1, x2, y2)
    return listbox
end


-- ****************************************************************************
-- SmallTooltip is for showing a smaller tooltips than GameTooltip does.
-- EXAMPLE:  SmallTooltip:Show(YourButton, "Info about your button.", "ANCHOR_TOP")
-- ****************************************************************************
CUtil.SmallTooltip = {}
function CUtil.SmallTooltip:validate()
    if not self.tooltip then
        self.tooltip = CreateFrame("Frame", nil, UIParent, "TooltipBorderedFrameTemplate")
        self.tooltip:Hide()
        self.tooltip:SetFrameStrata("TOOLTIP")
        self.tooltip:SetBackdropColor(0, 0, 0, 1)  -- Makes background a little darker.
        ----self.tooltip:SetBackdropBorderColor(0, 1, 1, 1)
        self.tooltip.fontString = self.tooltip:CreateFontString(nil, "ARTWORK")
        self.tooltip.fontString:SetFont("Fonts\\ARIALN.ttf", 12, "")
        self.tooltip.fontString:SetPoint("CENTER", 1, 0)
    end
end


-- ****************************************************************************
-- Displays a small tooltip containing the specified text.  The anchor parameter
-- can be "ANCHOR_RIGHT", "ANCHOR_LEFT", "ANCHOR_TOP", "ANCHOR_BOTTOM", or nil.
-- If parent is nil, UIParent is used.
-- ****************************************************************************
function CUtil.SmallTooltip:Show(parent, text, anchor, x, y)
    assert(text ~= nil and text ~= "")
    assert(parent == nil or type(parent) == "table")
    self:validate()

    parent = parent or UIParent
    self.tooltip:SetParent(parent)
	self.tooltip.fontString:SetText(text)
	local strW = self.tooltip.fontString:GetStringWidth()
	local strH = self.tooltip.fontString:GetStringHeight()
	self.tooltip:SetSize( strW+16, strH+13 )

    self.tooltip:ClearAllPoints()
    if parent == UIParent then
        if (anchor == "ANCHOR_TOP") then self.tooltip:SetPoint("TOP", x, y)
        elseif (anchor == "ANCHOR_BOTTOM") then self.tooltip:SetPoint("BOTTOM", x, y)
        elseif (anchor == "ANCHOR_LEFT") then self.tooltip:SetPoint("LEFT", x, y)
        elseif (anchor == "ANCHOR_RIGHT") then self.tooltip:SetPoint("RIGHT", x, y)
        else self.tooltip:SetPoint("CENTER")
        end
    else
        if (anchor == "ANCHOR_TOP") then self.tooltip:SetPoint("BOTTOM", parent, "TOP", x, y)
        elseif (anchor == "ANCHOR_BOTTOM") then self.tooltip:SetPoint("TOP", parent, "BOTTOM", x, y)
        elseif (anchor == "ANCHOR_LEFT") then self.tooltip:SetPoint("RIGHT", parent, "LEFT", x, y)
        else self.tooltip:SetPoint("LEFT", parent, "RIGHT", x, y) -- "ANCHOR_RIGHT"
        end
    end

    self.tooltip:Show()
end

-- ****************************************************************************
function CUtil.SmallTooltip:Hide()
    self:validate()
    self.tooltip:Hide()
end

-- ****************************************************************************
function CUtil.SmallTooltip:GetTextColor()
    self:validate()
    return self.tooltip.fontString:GetTextColor()
end

-- ****************************************************************************
function CUtil.SmallTooltip:SetTextColor(r, g, b, alpha)
    self:validate()
    self.tooltip.fontString:SetTextColor(r, g, b, alpha)
end


--#############################################################################
-------------------------------------------------------------------------------
-- Module interface.
-------------------------------------------------------------------------------
--#############################################################################

private.UDControls.VERSION = CONTROLS_VERSION


-- Exposed Config.  (If changed, they must be set before calling any other UDControls functions!)
private.UDControls.kSetButtonFlashing = false   -- Default scrollbar button flashing mode for ALL listboxes.
                                                -- Can be overriden for a specific control by SetButtonFlashing().
private.UDControls.kButtonFlashAlpha = 0.5  -- Can be overriden by ConfigureFlashing().
private.UDControls.kButtonFlashSecs = 0.6   -- Can be overriden by ConfigureFlashing().


-- Exposed Functions.
private.UDControls.CreateCheckBox         = CreateCheckBox
private.UDControls.CreateColorSwatch      = CreateColorSwatch  --DJUadded
private.UDControls.CreateDropDown         = CreateDropDown
--~ private.UDControls.CreateEditBox          = CreateEditBox
private.UDControls.CreateGroupBox         = CreateGroupBox  --DJUadded
private.UDControls.CreateIconButton       = CreateIconButton
private.UDControls.CreateListBox          = CreateListBox
private.UDControls.CreateOptionButton     = CreateOptionButton
private.UDControls.CreateSlider           = CreateSlider
private.UDControls.CreateTextScrollFrame  = CreateTextScrollFrame  --DJUadded
private.UDControls.CreateTextureButton    = CreateTextureButton  --DJUadded


-- Exposed Utility Functions.  --DJUadded--
private.UDControls.CloseDropDowns         = CUtil.CloseDropDowns
private.UDControls.CreateContextMenu      = CUtil.CreateContextMenu
private.UDControls.CreateHorizontalDivider= CUtil.CreateHorizontalDivider
private.UDControls.CreateTexture_NEW      = CUtil.CreateTexture_NEW
private.UDControls.DisplayAllFonts        = CUtil.DisplayAllFonts
private.UDControls.DoNothing              = DoNothing
private.UDControls.EnhanceFrameEdges      = CUtil.EnhanceFrameEdges
private.UDControls.FillFrame              = CUtil.FillFrame
private.UDControls.GameTooltip_SetTitleAndText = CUtil.GameTooltip_SetTitleAndText
private.UDControls.GetMouseFocus          = CUtil.GetMouseFocus
private.UDControls.handleGlobalMouseClick = CUtil.handleGlobalMouseClick
private.UDControls.MsgBox                 = CUtil.MsgBox
private.UDControls.MsgBox3                = CUtil.MsgBox3
private.UDControls.Outline                = CUtil.Outline
private.UDControls.SmallTooltip           = CUtil.SmallTooltip
private.UDControls.TextSize               = CUtil.TextSize

--- End of File ---