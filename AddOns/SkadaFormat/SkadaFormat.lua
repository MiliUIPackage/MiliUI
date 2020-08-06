function SkadaFormatNumber(self,number)
    if number then
        if self.db.profile.numberformat == 1 then
            if number < 10000 then
				return math.floor(number)
			elseif number < 100000 then
				return ("%0.2f萬"):format(number / 10000)
			elseif number < 1000000 then
				return ("%0.1f萬"):format(number / 10000)
			elseif number < 100000000 then
				return ("%d萬"):format(number / 10000)
			else
                return ("%0.2f億"):format(number / 100000000)
            end
        else
            return math.floor(number)
        end
    end
end

local frame= CreateFrame("Frame")
frame:SetScript("OnEvent", function(f, e, ...)
    if Skada.FormatNumber ~= nil and Skada.FormatNumber ~= SkadaFormatNumber then
        Skada.FormatNumber = SkadaFormatNumber
    end
end)

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
