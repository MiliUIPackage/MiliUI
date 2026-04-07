LoxxRotation = LoxxRotation or {};
local rotationOrder = {};
local function SendRotation()
	if not IsInGroup() then
		return;
	end
	if (#rotationOrder == 0) then
		return;
	end
	local channel = (IsInInstance() and "INSTANCE_CHAT") or "PARTY";
	local entries = {};
	for i, name in ipairs(rotationOrder) do
		entries[i] = tostring(i) .. "=" .. name;
	end
	local msg = "ROTATION:" .. table.concat(entries, ":");
	pcall(C_ChatInfo.SendAddonMessage, "LOXX", msg, channel);
end
LoxxRotation.UpdateRoster = function(partyAddonUsers, myName)
	if not myName then
		return;
	end
	local existing = {};
	for i, n in ipairs(rotationOrder) do
		existing[n] = i;
	end
	local inGroup = {[myName]=true};
	for name in pairs(partyAddonUsers or {}) do
		inGroup[name] = true;
	end
	local known, newPlayers = {}, {};
	for name in pairs(inGroup) do
		if existing[name] then
			table.insert(known, {name=name,pos=existing[name]});
		else
			table.insert(newPlayers, name);
		end
	end
	table.sort(known, function(a, b)
		return a.pos < b.pos;
	end);
	table.sort(newPlayers);
	local result = {};
	for _, e in ipairs(known) do
		table.insert(result, e.name);
	end
	for _, n in ipairs(newPlayers) do
		table.insert(result, n);
	end
	rotationOrder = result;
end;
LoxxRotation.HandleMessage = function(parts, sender)
	local parsed = {};
	for i = 2, #parts do
		local idx, name = parts[i]:match("^(%d+)=(.+)$");
		if (idx and name) then
			parsed[tonumber(idx)] = name;
		end
	end
	local clean = {};
	for i = 1, #parsed do
		if parsed[i] then
			table.insert(clean, parsed[i]);
		end
	end
	if (#clean > 0) then
		rotationOrder = clean;
	end
end;
LoxxRotation.GetNextKicker = function(partyAddonUsers, myName, myKickCdEnd, myExtraKicks, now)
	if (#rotationOrder == 0) then
		return nil;
	end
	now = now or GetTime();
	local function isReady(name)
		if (name == myName) then
			if ((myKickCdEnd or 0) <= now) then
				return true;
			end
			for _, ek in pairs(myExtraKicks or {}) do
				if (ek.cdEnd and (ek.cdEnd <= now)) then
					return true;
				end
			end
			return false;
		else
			local info = partyAddonUsers and partyAddonUsers[name];
			return (info ~= nil) and ((info.cdEnd or 0) <= now);
		end
	end
	local function getRemaining(name)
		if (name == myName) then
			local rem = (myKickCdEnd or 0) - now;
			for _, ek in pairs(myExtraKicks or {}) do
				if ek.cdEnd then
					rem = math.min(rem, ek.cdEnd - now);
				end
			end
			return math.max(0, rem);
		else
			local info = partyAddonUsers and partyAddonUsers[name];
			if not info then
				return math.huge;
			end
			return math.max(0, (info.cdEnd or 0) - now);
		end
	end
	for _, name in ipairs(rotationOrder) do
		if isReady(name) then
			return name;
		end
	end
	local bestRem, bestName = math.huge, nil;
	for _, name in ipairs(rotationOrder) do
		local rem = getRemaining(name);
		if (rem < bestRem) then
			bestRem = rem;
			bestName = name;
		end
	end
	return bestName;
end;
LoxxRotation.MarkNextKicker = function(bars, barCount, partyAddonUsers, myName, myKickCdEnd, myExtraKicks, now, showNext)
	local nextKicker = nil;
	if showNext then
		nextKicker = LoxxRotation.GetNextKicker(partyAddonUsers, myName, myKickCdEnd, myExtraKicks, now);
	end
	for i = 1, barCount do
		local bar = bars[i];
		if (bar and bar.nameText and bar.ttPlayerName) then
			if (nextKicker and (bar.ttPlayerName == nextKicker)) then
				bar.nameText:SetText("|cFF26FF73>|r " .. bar.ttPlayerName);
			else
				bar.nameText:SetText(bar.ttPlayerName);
			end
		end
	end
end;
LoxxRotation.GetOrder = function()
	local copy = {};
	for i, n in ipairs(rotationOrder) do
		copy[i] = n;
	end
	return copy;
end;
LoxxRotation.SetOrder = function(newOrder)
	rotationOrder = {};
	for i, n in ipairs(newOrder) do
		rotationOrder[i] = n;
	end
	SendRotation();
end;
