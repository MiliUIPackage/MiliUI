local ADDON, Addon = ...
local Asmon = Addon:NewModule('Asmon')

local Characters = {
    'Asmongold',
    'Wildanimal',
    'Záck',
    'Thuganomics',
    'Thugfresh',
    'Asmongler',
    'Sneakymcstâb',
    'Trolliborc',
}

function Asmon:OnEnable()
    local name, realm = UnitFullName('player')
    if Addon.sets.asmon or (GetCurrentRegion() == 1 and realm == "Kel'Thuzad" and tContains(Characters, name)) then
        Addon.showAsmon = true
        
        if not Addon.sets.asmon and LoadAddOn(ADDON .. '_Config') then
            Addon.AsmonLetter:Initial()
            Addon.sets.asmon = true
        end
    end
end