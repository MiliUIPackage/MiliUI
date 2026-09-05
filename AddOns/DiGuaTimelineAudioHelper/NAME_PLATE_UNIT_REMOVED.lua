local addonName, addonTable = ...

local f = CreateFrame("Frame")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

f:SetScript("OnEvent", function(self, event, unit)
    if unit then
        if addonTable.SpellCastCounter then addonTable.SpellCastCounter[unit] = nil end
        if addonTable.SpellCastStartTime then addonTable.SpellCastStartTime[unit] = nil end
        if addonTable.SpellChannelStart then addonTable.SpellChannelStart[unit] = nil end
        if addonTable.SpellCastSuccessTriggered then addonTable.SpellCastSuccessTriggered[unit] = nil end
        -- 清空"已施放恐惧咆哮"标记：单位消失/死亡后，下一只同类怪需重新施放恐惧咆哮才有资格播"残杀"
        if addonTable.HasCastFearRoar then addonTable.HasCastFearRoar[unit] = nil end
        if addonTable.SpellChannelCounter then addonTable.SpellChannelCounter[unit] = nil end
        if addonTable.UnitAbsorbAmountChanged then addonTable.UnitAbsorbAmountChanged[unit] = nil end
        -- 清空"准备诱捕"首次触发标记，单位消失后下一只可重新触发
        if addonTable.UnitTargetTriggered then addonTable.UnitTargetTriggered[unit] = nil end
        -- 停止该单位的进战斗轮询 ticker，避免残留
        if addonTable.UnitTargetTickers and addonTable.UnitTargetTickers[unit] then
            addonTable.UnitTargetTickers[unit]:Cancel()
            addonTable.UnitTargetTickers[unit] = nil
        end
        -- 取消该姓名板关联的时间轴倒计时（怪物死亡/离开视野时提前消失）
        if addonTable.CancelCustomEncounterBar then
            addonTable.CancelCustomEncounterBar(unit)
        end
    end
end)