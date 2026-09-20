do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI=_G.YUI
local GUI=YUI and YUI.GUI2
if not (GUI and GUI.Form) then return end
local Picker={}
local dropdownIconCrop={0.08,0.92,0.08,0.92}
Picker.parents=setmetatable({}, {__mode='k'})
GUI.VoicePicker=Picker
local function T(key)
    return YUI.Locale:Get('Core')[key]
end
local function DefaultClass()
    local unit=YUI.API and YUI.API.Unit
    return unit and unit.GetClassToken and unit.GetClassToken('player') or 'all'
end

function Picker:SetRowIcon(row,icon)
    local text=YUI.Sound:GetIconText(icon)
    row.icon:SetShown(not text)
    row.textBackground:SetShown(text~=nil)
    row.iconText:SetShown(text~=nil)
    row.iconText:SetText(text or '')
    if text then
        row.iconText:ClearAllPoints()
        row.iconText:SetPoint('CENTER',row.textBackground,'CENTER',0,0)
        row.iconText:SetSize(28,28)
        row.iconText:SetJustifyH('CENTER')
        row.iconText:SetJustifyV('MIDDLE')
        local font=GUI:GetFont('font.family.body')
        local size=GUI:GetMetric('font.size.lg',18)
        row.iconText:SetFont(font,size,'OUTLINE')
        local width=row.iconText:GetStringWidth()
        if width>28 then row.iconText:SetFont(font,math.max(6,size*28/width),'OUTLINE') end
    else
        row.icon:SetTexture(icon or 134400)
    end
end

function Picker.Layout(width,height)
    width=math.max(1,width-28)
    height=math.max(1,height-28)
    local columns=math.max(1,math.min(5,math.floor((width-44)/170)))
    local rows=math.max(1,math.min(10,math.floor((height-194)/46)))
    return {width=width,height=height,columns=columns,rows=rows,
        cardWidth=(width-54-(columns-1)*10)/columns}
end

function Picker:Open(parent,options)
    if not parent or not options or (not options.onSelect and not options.previewOnly) or not (YUI.Sound and YUI.Sound.GetEntries) then return nil end
    if self.dialog then self.dialog:Hide() end
    local layout=self.Layout(parent:GetWidth(),parent:GetHeight())
    if layout.width<320 or layout.height<300 then return nil,'parent-too-small' end
    if parent.HookScript and not self.parents[parent] then
        self.parents[parent]=true
        parent:HookScript('OnSizeChanged',function(frame)
            local dialog=Picker.dialog
            if dialog and dialog:IsShown() and dialog:GetParent()==frame then dialog:ResizeFromParent() end
        end)
    end
    if self.dialog then
        self.dialog:SetParent(parent)
        self.dialog:Reset(options,layout)
        return self.dialog
    end
    local dialog=GUI:CreatePanel(parent,{width=layout.width,height=layout.height,
        surface='color.surface.popup',border='color.popup.border',shadow=true})
    self.dialog=dialog
    dialog:SetPoint('CENTER',parent,'CENTER',0,0)
    dialog:SetFrameStrata(parent.GetFrameStrata and parent:GetFrameStrata() or 'DIALOG')
    dialog:SetFrameLevel(parent:GetFrameLevel()+30)
    dialog:EnableMouse(true)
    dialog.options=options
    dialog.selected=options.current
    dialog.class=options.class or DefaultClass()
    dialog.offset=0; dialog.query=''; dialog.rows={}; dialog.specOptions={}
    local function SelectionAvailable()
        if dialog.options and dialog.options.previewOnly then return false end
        if not dialog.selected then return false end
        for _,entry in ipairs(YUI.Sound:GetEntries({})) do if entry.id==dialog.selected then return true end end
        return false
    end
    local title=GUI:CreateText(dialog,T('sound.voice_selector.title'),'font.size.lg','color.text.heading','LEFT')
    dialog.title=title
    title:SetPoint('TOPLEFT',18,-16)
    local close=GUI:CreateCloseButton(dialog,function() dialog:Hide() end)
    close:SetPoint('TOPRIGHT',-14,-12)
    local search=GUI.Form:CreateEditBox(dialog,{width=layout.width-36,height=44,text='',placeholder=T('sound.center.search'),searchPlaceholder=true,onChange=function(_,value)
        dialog.query=value or ''; dialog.offset=0; if dialog.Refresh then dialog:Refresh() end
    end})
    search:SetScript('OnEscapePressed',function() dialog:Hide() end)
    local classOptions={}
    local spec
    local class=GUI.Form:CreateDropdown(dialog,{width=(layout.width-46)/2,height=44,
        options=function() return classOptions end,get=function() return dialog.class end,set=function(value)
            dialog.class=value; dialog.spec=nil; dialog.offset=0
            if spec then spec:SetValue('all',true); spec:RefreshOptions() end
            if dialog.Refresh then dialog:Refresh() end
        end})
    class:SetPoint('TOPLEFT',18,-66)
    spec=GUI.Form:CreateDropdown(dialog,{width=(layout.width-46)/2,height=44,
        options=function() return dialog.specOptions[dialog.class] or {{text=T('sound.voice_selector.all'),value='all'}} end,
        get=function() return dialog.spec or 'all' end,set=function(value)
            dialog.spec=value~='all' and value or nil; dialog.offset=0; if dialog.Refresh then dialog:Refresh() end
        end})
    spec:SetPoint('LEFT',class,'RIGHT',10,0)
    search:SetPoint('LEFT',spec,'RIGHT',10,0)
    local viewport=GUI:CreateScrollFrame(dialog,{width=layout.width-54,height=layout.rows*46-8,autoHide=true})
    viewport:SetPoint('TOPLEFT',18,-150)
    local empty=GUI:CreateText(viewport,T('sound.voice_selector.empty'),'font.size.md','color.text.secondary','CENTER')
    empty:SetPoint('CENTER'); empty:SetWidth(layout.width-60)
    local confirm=GUI.Form:CreateButton(dialog,{text=T('sound.voice_selector.confirm'),width=100,height=30,tone='accent',onClick=function()
        if SelectionAvailable() and dialog.options then
            local callback,selected=dialog.options.onSelect,dialog.selected
            dialog:Hide(); callback(selected)
        end
    end})
    GUI.Form:StyleDialogPrimary(confirm)
    confirm:SetPoint('BOTTOMRIGHT',-18,14)
    local cancel=GUI.Form:CreateTextLink(dialog,{text=T('sound.voice_selector.cancel'),width=90,height=34,colorKey='color.text.secondary',onClick=function() dialog:Hide() end})
    cancel:SetPoint('RIGHT',confirm,'LEFT',8*-1,0)
    local exit=GUI.Form:CreateButton(dialog,{text=T('sound.center.exit'),width=90,height=30,onClick=function() dialog:Hide() end})
    exit:SetPoint('BOTTOMRIGHT',-18,14)
    dialog.exitButton=exit;dialog.cancelButton=cancel
    local count=GUI:CreateText(dialog,'','font.size.md','color.text.secondary','LEFT')
    count:SetPoint('TOPLEFT',18,-124)
    local capacity=layout.columns*layout.rows
    local function MaxOffset()
        return math.max(0,math.ceil(#dialog.choices/layout.columns)-layout.rows)*layout.columns
    end
    local function Wheel(_,delta)
        dialog.offset=math.max(0,math.min(MaxOffset(),dialog.offset-delta*layout.columns))
        viewport:SetVerticalScroll(math.floor(dialog.offset/layout.columns)*46)
        dialog:RefreshRows()
    end
    if viewport.HookScript then viewport:HookScript('OnVerticalScroll',function()
        dialog.offset=math.min(MaxOffset(),math.max(0,math.floor(viewport:GetVerticalScroll()/46))*layout.columns)
        dialog:RefreshRows()
    end) end
    viewport:EnableMouseWheel(true); viewport:SetScript('OnMouseWheel',Wheel)
    for i=1,55 do
        local card=GUI:CreateFrame(viewport.child,{width=layout.cardWidth,height=38})
        card:SetPoint('TOPLEFT',((i-1)%layout.columns)*(layout.cardWidth+10),-math.floor((dialog.offset+i-1)/layout.columns)*46)
        local row={card=card}; dialog.rows[i]=row
        row.select=GUI.Form:CreateButton(card,{text='',width=layout.cardWidth,height=38,tone='default',onClick=function()
            if row.entry then
                if not dialog.options.previewOnly then dialog.selected=row.entry.id; dialog:RefreshRows() end
                if dialog.options.preview then dialog.options.preview(row.entry.id,dialog) end
            end
        end})
        row.select:SetPoint('LEFT',0,0)
        row.icon=GUI:CreateIcon(row.select,{width=32,height=32,texture=134400})
        row.icon:SetPoint('LEFT',6,0); row.select.gui2PreserveIconColor=true
        row.textBackground=GUI:CreatePanel(row.select,{width=32,height=32,
            surface='color.voice.textIcon',border=false,radiusKey='layout.radius.icon'})
        row.textBackground:SetPoint('LEFT',6,0)
        row.textBackground:EnableMouse(false); row.textBackground:Hide()
        row.iconText=GUI:CreateText(row.textBackground,'','font.size.lg','color.voice.textIconText','CENTER')
        row.iconText:SetPoint('CENTER',row.textBackground,'CENTER',0,0)
        row.iconText:SetSize(28,28); row.iconText:SetJustifyV('MIDDLE')
        row.iconText:SetWordWrap(false); row.iconText:Hide()
        row.label=GUI:CreateText(row.select,'','font.size.md','color.text.primary','CENTER')
        row.label:SetPoint('LEFT',row.icon,'RIGHT',6,0); row.label:SetWidth(layout.cardWidth-50)
        row.label:SetHeight(34); row.label:SetJustifyH('CENTER'); row.label:SetJustifyV('MIDDLE'); row.label:SetWordWrap(true); row.label:SetNonSpaceWrap(true)
        row.select:EnableMouseWheel(true); row.select:SetScript('OnMouseWheel',Wheel)
    end
    function dialog:RefreshRows()
        if self.paintedChoices==self.choices and self.paintedOffset==self.offset and self.paintedSelection==self.selected and self.paintedWidth==layout.width then return end
        self.paintedChoices,self.paintedOffset,self.paintedSelection,self.paintedWidth=self.choices,self.offset,self.selected,layout.width
        for i,row in ipairs(self.rows) do
            local entry=i<=capacity+layout.columns and self.choices[self.offset+i] or nil
            row.entry=entry
            if entry then
                row.card:ClearAllPoints(); row.card:SetPoint('TOPLEFT',((i-1)%layout.columns)*(layout.cardWidth+10),-math.floor((self.offset+i-1)/layout.columns)*46)
                row.card:Show(); row.label:SetText(entry.name)
                Picker:SetRowIcon(row,entry.icon)
                row.select:SetSelected(not self.options.previewOnly and entry.id==self.selected)
            else row.card:Hide() end
        end
        if #self.choices==0 then empty:Show() else empty:Hide() end
        confirm:SetDisabled(not SelectionAvailable(),true)
        count:SetText(#self.choices==0 and '0' or (self.offset+1)..'–'..math.min(self.offset+capacity,#self.choices)..' / '..#self.choices)
    end
    function dialog:Refresh()
        self.choices=YUI.Sound:GetEntries({query=self.query,class=self.class,spec=self.spec})
        self.offset=math.min(math.floor(self.offset/layout.columns)*layout.columns,MaxOffset())
        viewport.child:SetWidth(layout.width-54); GUI:FitScrollContent(viewport,math.max(1,math.ceil(#self.choices/layout.columns)*46-8))
        viewport:SetVerticalScroll(math.floor(self.offset/layout.columns)*46)
        self:RefreshRows()
    end
    function dialog:ResizeFromParent()
        local parent=self:GetParent()
        local nextLayout=Picker.Layout(parent:GetWidth(),parent:GetHeight())
        if nextLayout.width<320 or nextLayout.height<300 then self:Hide(); return end
        layout=nextLayout; capacity=layout.columns*layout.rows
        self:SetSize(layout.width,layout.height)
        search:SetWidth((layout.width-56)*0.5); class:SetWidth((layout.width-56)*0.25); spec:SetWidth((layout.width-56)*0.25)
        viewport:SetSize(layout.width-54,layout.rows*46-8); empty:SetWidth(layout.width-60)
        for i,row in ipairs(self.rows) do
            row.card:SetSize(layout.cardWidth,38); row.card:ClearAllPoints()
            row.card:SetPoint('TOPLEFT',((i-1)%layout.columns)*(layout.cardWidth+10),-math.floor((dialog.offset+i-1)/layout.columns)*46)
            row.select:SetWidth(layout.cardWidth); row.label:SetWidth(layout.cardWidth-50)
        end
        self:Refresh()
    end
    function dialog:RefreshSpecIcons()
        local icons=YUI.API and YUI.API.Icons
        for _,list in pairs(self.specOptions) do
            for _,choice in ipairs(list) do
                if choice.value~='all' then
                    choice.iconData=icons and icons.GetScopedSpecIcon and icons.GetScopedSpecIcon(choice.value,choice.icon,'settings') or nil
                    if choice.iconData and choice.iconData.custom==false then choice.icon=choice.iconData.texture or choice.icon;choice.iconData=nil end
                    choice.texCoord=not choice.iconData and dropdownIconCrop or nil
                end
            end
        end
        spec:RefreshOptions()
    end
    function dialog:OnIconScopeChanged(_,scope)
        if not scope or scope=='settings' then self:RefreshSpecIcons() end
    end
    function dialog:RefreshTitle()
        local heading=T(self.options.previewOnly and 'sound.center.browsePreview' or 'sound.voice_selector.title')
        if self.options.previewOnly then
            local sound=YUI.Sound
            local prefs=sound.GetPreferences and sound:GetPreferences()
            local packId=prefs and prefs.voicePackId or 'yui.default'
            heading=(heading or '')..' · '..sound:GetVoicePackLabel(packId)
        end
        title:SetText(heading)
        title:SetWidth(layout.width-80)
        title:SetWordWrap(false)
    end
    function dialog:Reset(nextOptions,nextLayout)
        self.options=nextOptions; layout=nextLayout
        confirm:SetShown(not nextOptions.previewOnly)
        exit:SetShown(nextOptions.previewOnly==true)
        cancel:SetShown(not nextOptions.previewOnly)
        self:RefreshTitle()
        cancel:ClearAllPoints()
        cancel:SetPoint('BOTTOMLEFT',18,14)
        self.selected=not nextOptions.previewOnly and nextOptions.current or nil; self.query=''; self.offset=0; self.spec=nil
        self.class=nextOptions.class or DefaultClass(); self.specOptions={}
        classOptions={{text=T('sound.voice_selector.all'),value='all'},
            {text=T('sound.voice_selector.general'),value='general',icon=132996,texCoord=dropdownIconCrop}}
        local settings=YUI.Settings
        for _,group in ipairs(settings and settings.GetSpecSelectionGroups and settings:GetSpecSelectionGroups({}) or {}) do
            for _,info in ipairs(group.classes) do
                classOptions[#classOptions+1]={text=info.name,value=info.token,icon=info.icon,texCoord=info.iconTexCoord}
                self.specOptions[info.token]={{text=T('sound.voice_selector.all'),value='all'}}
            end
            for _,info in ipairs(group.specs) do
                local list=self.specOptions[info.classInfo.token]
                list[#list+1]={text=info.displayName,value=info.specID,icon=info.icon}
            end
        end
        if nextOptions.classes then classOptions=nextOptions.classes end
        local countedOptions={}
        for _,choice in ipairs(classOptions) do
            local counted={}
            for key,value in pairs(choice) do counted[key]=value end
            counted.text=string.format(T('sound.center.categoryCount') or '%s (%d)',choice.text or '',
                #YUI.Sound:GetEntries({class=choice.value}))
            if choice.value=='general' then counted.icon=132996; counted.texCoord=dropdownIconCrop end
            countedOptions[#countedOptions+1]=counted
        end
        classOptions=countedOptions
        local found=false
        for _,choice in ipairs(classOptions) do if choice.value==self.class then found=true end end
        if not found then self.class='all' end
        capacity=layout.columns*layout.rows
        self:SetSize(layout.width,layout.height)
        self:ClearAllPoints(); self:SetPoint('CENTER',self:GetParent(),'CENTER',0,0)
        self:SetFrameLevel(self:GetParent():GetFrameLevel()+30)
        self:SetFrameStrata(self:GetParent().GetFrameStrata and self:GetParent():GetFrameStrata() or 'DIALOG')
        search:SetWidth((layout.width-56)*0.5); search:SetText('')
        class:SetWidth((layout.width-56)*0.25); spec:SetWidth((layout.width-56)*0.25)
        class:SetValue(self.class,true); class:RefreshOptions(); spec:SetValue('all',true); self:RefreshSpecIcons()
        if YUI.Event and YUI.Event.On then
            YUI.Event:On('YUI_SOUND_PREFERENCES_CHANGED','RefreshTitle',self)
            YUI.Event:On('YUI_SOUND_PACKS_CHANGED','RefreshTitle',self)
            YUI.Event:On('YUI_APPEARANCE_ICON_SET_CHANGED','RefreshSpecIcons',self)
            YUI.Event:On('YUI_APPEARANCE_ICON_SCOPE_CHANGED','OnIconScopeChanged',self)
        end
        viewport:SetSize(layout.width-54,layout.rows*46-8); empty:SetWidth(layout.width-60)
        for i,row in ipairs(self.rows) do
            row.card:SetSize(layout.cardWidth,38); row.card:ClearAllPoints()
            row.card:SetPoint('TOPLEFT',((i-1)%layout.columns)*(layout.cardWidth+10),-math.floor((dialog.offset+i-1)/layout.columns)*46)
            row.select:SetWidth(layout.cardWidth); row.label:SetWidth(layout.cardWidth-50)
        end
        self:Refresh(); self:Show()
        local scrim=GUI:ShowModalScrim(self)
        if scrim then
            scrim:SetParent(self:GetParent()); scrim:ClearAllPoints(); scrim:SetAllPoints(self:GetParent())
        end
    end
    dialog:SetScript('OnHide',function()
        search:ClearFocus()
        if dialog.options and dialog.options.stopPreview then dialog.options.stopPreview(dialog) end
        if YUI.Event then YUI.Event:OffOwner(dialog) end
        dialog.options=nil
    end)
    if dialog.EnableKeyboard then
        dialog:EnableKeyboard(true)
        dialog:SetScript('OnKeyDown',function(_,key)
            local handled=key=='ESCAPE' or key=='ENTER'
            if dialog.SetPropagateKeyboardInput then dialog:SetPropagateKeyboardInput(not handled) end
            if key=='ESCAPE' then dialog:Hide()
            elseif key=='ENTER' and SelectionAvailable() and dialog.options then
                local callback,selected=dialog.options.onSelect,dialog.selected
                dialog:Hide(); callback(selected)
            end
        end)
    end
    dialog:Reset(options,layout)
    return dialog
end

return Picker
