

function LF:IsBlacklisted(source, index)
    if source == "m+" then
        return self.instances[index]
    elseif source == "raid" then
        return self.raids[index]
    elseif source == "pvp" then
        return self.pvptier == 0
    end
end
