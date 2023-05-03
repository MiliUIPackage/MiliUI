--高频变压器 @ NGA
--2023.4.23
--https://nga.178.com/read.php?tid=32246801
--modified by 彩虹ui

--显示格式设定： 
local aa = 2;       --1按d、h、m、s等字母来显示      2按天、时、分、秒等汉字来显示
local function Bufftime(seconds)
    if ( aa==1 ) then
        if ( seconds > 86400 ) then
	        local d = floor(seconds / 86400)
            return format("|cff00ff00%0.0fd|r", d)
        elseif ( seconds > 3600 ) then
		    local h = floor((seconds % 86400 / 3600)*10 + 0.5) / 10
            return format("|cff00ff00%0.1fh|r", h)
        elseif ( seconds > 300 ) then
            local m = floor(seconds / 60)
            return format("|cff00ff00%dm|r", m)
        elseif ( seconds > 60 ) then
            local m = floor(seconds / 60)
		    local s = seconds % 60
            return format("|cffffff00%dm:%02ds|r", m, s)
        elseif ( seconds > 0 ) then
	        local s = seconds % 60
            return format("|cffff0000%01ds|r", s)
	    end
	    return ""
    elseif ( aa==2 ) then
        if ( seconds > 86400 ) then
	    local d = floor(seconds / 86400)
        return format("|cff00ff00%d天|r", d)
    elseif ( seconds > 3600 ) then
		local h = floor((seconds % 86400 / 3600)*10 + 0.5) / 10
        return format("|cff00ff00%d小時|r", h)
    elseif ( seconds > 300 ) then
        local m = floor(seconds / 60)
        return format("|c00FFD700%d分|r", m)
    elseif ( seconds > 60 ) then
        local m = floor(seconds / 60)
		local s = seconds % 60
        return format("|c00FFD700%d:%02d|r", m, s)
    elseif ( seconds > 0 ) then
	    local s = seconds % 60
        return format("|c00FFFFFF%01d秒|r", s)
	end
	    return ""
    end
end
SecondsToTimeAbbrev = Bufftime


local function Buff(self)
	if self.buttonInfo.expirationTime and self.buttonInfo.expirationTime > 0 then
	    self.Duration:SetPoint("BOTTOM", 0, 5);
    end
end

local function UpBuffDate()
    for _, Bufficon in ipairs(BuffFrame.auraFrames) do
	    hooksecurefunc(Bufficon, "UpdateExpirationTime", Buff);
	end
    for _, DeBufficon in ipairs(DebuffFrame.auraFrames) do
		if DeBufficon.UpdateExpirationTime then
			hooksecurefunc(DeBufficon, "UpdateExpirationTime", Buff);
		end
	end
end

if GetLocale() == "zhTW" then 
	UpBuffDate();
end