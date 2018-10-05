if not(GetLocale() == "koKR") then
  return
end

local L = WeakAuras.L

-- WeakAuras/Templates
	L["Abilities"] = "능력"
	L["Ability Charges"] = "능력 충전량"
	L["Add Triggers"] = "활성 조건 추가"
	L["Always Active"] = "항상 활성화"
	L["Always Show"] = "항상 표시"
	--[[Translation missing --]]
	L["Always show the aura, highlight it if debuffed."] = "Always show the aura, highlight it if debuffed."
	--[[Translation missing --]]
	L["Always show the aura, turns grey if on cooldown."] = "Always show the aura, turns grey if on cooldown."
	L["Always show the aura, turns grey if the debuff not active."] = "효과를 항상 표시하고, 약화 효과가 활성화되어 있지 않으면 회색으로 바뀝니다."
	L["Always shows the aura, grey if buff not active."] = "효과를 항상 표시하고, 강화 효과가 활성화되어 있지 않으면 회색으로 바뀝니다."
	--[[Translation missing --]]
	L["Always shows the aura, highlight it if buffed."] = "Always shows the aura, highlight it if buffed."
	--[[Translation missing --]]
	L["Always shows the aura, highlight while proc is active, blue on insufficient resources."] = "Always shows the aura, highlight while proc is active, blue on insufficient resources."
	--[[Translation missing --]]
	L["Always shows the aura, highlight while proc is active, blue when not usable."] = "Always shows the aura, highlight while proc is active, blue when not usable."
	--[[Translation missing --]]
	L["Always shows the aura, highlight while proc is active, turns red when out of range, blue on insufficient resources."] = "Always shows the aura, highlight while proc is active, turns red when out of range, blue on insufficient resources."
	--[[Translation missing --]]
	L["Always shows the aura, turns grey if on cooldown."] = "Always shows the aura, turns grey if on cooldown."
	--[[Translation missing --]]
	L["Always shows the aura, turns grey if the ability is not usable and red when out of range."] = "Always shows the aura, turns grey if the ability is not usable and red when out of range."
	--[[Translation missing --]]
	L["Always shows the aura, turns grey if the ability is not usable."] = "Always shows the aura, turns grey if the ability is not usable."
	--[[Translation missing --]]
	L["Always shows the aura, turns grey when on cooldown, blue when unusable."] = "Always shows the aura, turns grey when on cooldown, blue when unusable."
	--[[Translation missing --]]
	L["Always shows the aura, turns grey when on zero charges, blue when not usable."] = "Always shows the aura, turns grey when on zero charges, blue when not usable."
	--[[Translation missing --]]
	L["Always shows the aura, turns grey when on zero charges, highlight when active, blue on insufficient resources."] = "Always shows the aura, turns grey when on zero charges, highlight when active, blue on insufficient resources."
	--[[Translation missing --]]
	L["Always shows the aura, turns grey when on zero charges, red when out of range, blue on insufficient resources."] = "Always shows the aura, turns grey when on zero charges, red when out of range, blue on insufficient resources."
	--[[Translation missing --]]
	L["Always shows the aura, turns greys on zero charges, blue on insufficient resources."] = "Always shows the aura, turns greys on zero charges, blue on insufficient resources."
	--[[Translation missing --]]
	L["Always shows the aura, turns red when out of range, blue on insufficient resources."] = "Always shows the aura, turns red when out of range, blue on insufficient resources."
	--[[Translation missing --]]
	L["Always shows the aura, turns red when out of range."] = "Always shows the aura, turns red when out of range."
	L["Back"] = "뒤로"
	--[[Translation missing --]]
	L["Basic Show On Cooldown"] = "Basic Show On Cooldown"
	L["Bloodlust/Heroism"] = "피의 욕망/영웅심"
	L["buff"] = "강화 효과"
	L["Buff"] = "강화 효과"
	L["Buffs"] = "강화 효과"
	L["Cancel"] = "취소"
	L["Cast"] = "시전"
	--[[Translation missing --]]
	L["Charge and Buff Tracking"] = "Charge and Buff Tracking"
	--[[Translation missing --]]
	L["Charge and Debuff Tracking"] = "Charge and Debuff Tracking"
	--[[Translation missing --]]
	L["Charge Tracking"] = "Charge Tracking"
	L["cooldown"] = "재사용 대기시간"
	--[[Translation missing --]]
	L["Cooldown Tracking"] = "Cooldown Tracking"
	--[[Translation missing --]]
	L["Create Auras"] = "Create Auras"
	L["Debuffs"] = "약화 효과"
	L["Enchants"] = "마법부여"
	L["General"] = "일반"
	L["General Azerite Traits"] = "일반 아제라이트 특성"
	L["Health"] = "생명력"
	--[[Translation missing --]]
	L["Highlight while buffed, red when out of range."] = "Highlight while buffed, red when out of range."
	--[[Translation missing --]]
	L["Highlight while buffed."] = "Highlight while buffed."
	--[[Translation missing --]]
	L["Highlight while debuffed, red when out of range."] = "Highlight while debuffed, red when out of range."
	--[[Translation missing --]]
	L["Highlight while debuffed."] = "Highlight while debuffed."
	--[[Translation missing --]]
	L["Hold CTRL to create multiple auras at once"] = "Hold CTRL to create multiple auras at once"
	L["Keeps existing triggers intact"] = "활성 조건 그대로 유지"
	--[[Translation missing --]]
	L["Next"] = "Next"
	--[[Translation missing --]]
	L["On Procc Trinkets (Buff)"] = "On Procc Trinkets (Buff)"
	--[[Translation missing --]]
	L["On Use Trinkets (Buff)"] = "On Use Trinkets (Buff)"
	--[[Translation missing --]]
	L["On Use Trinkets (CD)"] = "On Use Trinkets (CD)"
	L["Only show the aura if the target has the debuff."] = "대상에 약화 효과가 있는 경우 그 효과만 표시합니다."
	--[[Translation missing --]]
	L["Only show the aura when the item is on cooldown."] = "Only show the aura when the item is on cooldown."
	L["Only shows the aura if the target has the buff."] = "대상에 강화 효과가 있는 경우 그 효과만 표시합니다."
	L["Only shows the aura when the ability is on cooldown."] = "능력이 재사용 대기 중인 경우 그 효과만 표시합니다."
	L["Pet alive"] = "소환수 생존"
	L["Pet Behavior"] = "소환수 행동"
	L["PvP Azerite Traits"] = "PvP 아제라이트 특성"
	L["PvP Talents"] = "명예 특성"
	L["PVP Trinkets (Buff)"] = "PvP 장신구 (강화 효과)"
	--[[Translation missing --]]
	L["PVP Trinkets (CD)"] = "PVP Trinkets (CD)"
	L["Replace all existing triggers"] = "모든 활성 조건 교체"
	L["Replace Triggers"] = "활성 조건 교체"
	L["Resources"] = "자원"
	L["Resources and Shapeshift Form"] = "자원과 태세 변환"
	L["Runes"] = "룬"
	L["Shapeshift Form"] = "태세 변환"
	--[[Translation missing --]]
	L["Show Charges and Check Usable"] = "Show Charges and Check Usable"
	--[[Translation missing --]]
	L["Show Charges with Proc Tracking"] = "Show Charges with Proc Tracking"
	--[[Translation missing --]]
	L["Show Charges with Range Tracking"] = "Show Charges with Range Tracking"
	--[[Translation missing --]]
	L["Show Charges with Usable Check"] = "Show Charges with Usable Check"
	--[[Translation missing --]]
	L["Show Cooldown and Buff"] = "Show Cooldown and Buff"
	--[[Translation missing --]]
	L["Show Cooldown and Buff and Check for Target"] = "Show Cooldown and Buff and Check for Target"
	--[[Translation missing --]]
	L["Show Cooldown and Buff and Check Usable"] = "Show Cooldown and Buff and Check Usable"
	--[[Translation missing --]]
	L["Show Cooldown and Check for Target"] = "Show Cooldown and Check for Target"
	--[[Translation missing --]]
	L["Show Cooldown and Check for Target & Proc Tracking"] = "Show Cooldown and Check for Target & Proc Tracking"
	--[[Translation missing --]]
	L["Show Cooldown and Check Usable"] = "Show Cooldown and Check Usable"
	--[[Translation missing --]]
	L["Show Cooldown and Check Usable & Target"] = "Show Cooldown and Check Usable & Target"
	--[[Translation missing --]]
	L["Show Cooldown and Check Usable, Proc Tracking"] = "Show Cooldown and Check Usable, Proc Tracking"
	--[[Translation missing --]]
	L["Show Cooldown and Check Usable, Target & Proc Tracking"] = "Show Cooldown and Check Usable, Target & Proc Tracking"
	--[[Translation missing --]]
	L["Show Cooldown and Debuff"] = "Show Cooldown and Debuff"
	--[[Translation missing --]]
	L["Show Cooldown and Debuff and Check for Target"] = "Show Cooldown and Debuff and Check for Target"
	--[[Translation missing --]]
	L["Show Cooldown and Proc Tracking"] = "Show Cooldown and Proc Tracking"
	--[[Translation missing --]]
	L["Show Cooldown and Totem Information"] = "Show Cooldown and Totem Information"
	L["Show Only if Buffed"] = "있는 강화 효과만 표시"
	L["Show Only if Debuffed"] = "있는 약화 효과만 표시"
	--[[Translation missing --]]
	L["Show Only if on Cooldown"] = "Show Only if on Cooldown"
	--[[Translation missing --]]
	L["Show Totem and Charge Information"] = "Show Totem and Charge Information"
	L["Specific Azerite Traits"] = "특정 아제라이트 특성"
	L["Stagger"] = "시간차"
	--[[Translation missing --]]
	L["Track the charge and proc, highlight while proc is active, turns red when out of range, blue on insufficient resources."] = "Track the charge and proc, highlight while proc is active, turns red when out of range, blue on insufficient resources."
	--[[Translation missing --]]
	L["Tracks the charge and the buff, highlight while the buff is active, blue on insufficient resources."] = "Tracks the charge and the buff, highlight while the buff is active, blue on insufficient resources."
	--[[Translation missing --]]
	L["Tracks the charge and the debuff, highlight while the debuff is active, blue on insufficient resources."] = "Tracks the charge and the debuff, highlight while the debuff is active, blue on insufficient resources."
	L["Unknown Item"] = "알 수 없는 아이템"
	L["Unknown Spell"] = "알 수 없는 주문"

