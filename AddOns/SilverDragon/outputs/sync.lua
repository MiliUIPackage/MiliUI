local core = LibStub("AceAddon-3.0"):GetAddon("SilverDragon")
local module = core:NewModule("Sync", "AceEvent-3.0")
local Debug = core.Debug

function module:OnInitialize()
	self.db = core.db:RegisterNamespace("Sync", {
		profile = {
			party = true,
			raid = true,
			guild = false,	-- 更改預設值
			nearby = false,
			quiet = false,
		},
	})

	core.RegisterCallback(self, "Seen")
	self:RegisterEvent("CHAT_MSG_ADDON")
	C_ChatInfo.RegisterAddonMessagePrefix("SilverDragon")

	local config = core:GetModule("Config", true)
	if config then
		config.options.plugins.sync = {
			sync = {
				type = "group",
				name = "同步",
				order = 92,
				get = function(info) return self.db.profile[info[#info]] end,
				set = function(info, v) self.db.profile[info[#info]] = v end,
				args = {
					about = config.desc("稀有怪獸與牠們的產地會告訴其他稀有怪獸與牠們的產地使用者你所看到的稀有怪。如果你不喜歡，可以叫牠閉嘴。", 0),
					quiet = config.toggle("安靜", "不要傳送稀有怪資訊給其他玩家", 10),
					party = config.toggle("隊伍", "接收來自隊伍成員的同步資訊", 20),
					raid = config.toggle("團隊", "接收來自團隊成員的同步資訊", 30),
					guild = config.toggle("公會同步", "接收來自公會成員的同步資訊", 40),
					nearby = config.toggle("只有附近的", "只接收來自附近玩家的同步資訊。無法得知公會成員是否在附近，所以只有附近的隊伍成員才算數。", 50),
				},
			},
		}
	end
end

local protocol_version = 2
local function SAM(channel, ...)
	core.Debug("Sending message", channel, protocol_version, ...)
	ChatThrottleLib:SendAddonMessage("NORMAL", "SilverDragon", strjoin("\t", tostringall(protocol_version, ...)), channel)
end
local function deSAM(val)
	if val == "nil" then
		return nil
	end
	if val and tostring(tonumber(val)) == val then
		-- the good ol' "if it turns into its own string representation" test
		return tonumber(val)
	end
	return val
end

function module:Seen(callback, id, zone, x, y, dead, source, unit, GUID)
	if source and (source:match("^sync") or source == "fake") then
		-- No feedback loops, kthxbai
		return
	end
	if self.db.profile.quiet then
		return
	end
	local name = core:NameForMob(id)
	if IsInGuild() and not IsInInstance() then
		SAM("GUILD", "seen", id, name, zone, nil, x, y, GUID)
	end
	if IsInGroup(LE_PARTY_CATEGORY_HOME) then--Don't send syncs to INSTANCE_CHAT party/raids (ie LFR/LFG)
		if IsInRaid() then
			SAM("RAID", "seen", id, name, zone, nil, x, y, GUID)
		else
			SAM("PARTY", "seen", id, name, zone, nil, x, y, GUID)
		end
	elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance() then
		SAM("INSTANCE_CHAT", "seen", id, name, zone, nil, x, y, GUID)
	end
end

local spam = {}
function module:CHAT_MSG_ADDON(event, prefix, msg, channel, sender)
	if prefix ~= "SilverDragon" or sender == UnitName("player") then
		return
	end
	sender = Ambiguate(sender, "none")
	if channel == "GUILD" and not self.db.profile.guild then
		return
	end
	if channel == "RAID" and not self.db.profile.raid then
		return
	end
	if channel == "PARTY" and not self.db.profile.party then
		return
	end
	if self.db.profile.nearby and not UnitInRange(sender) then
		-- note: will only ever detect group members as being nearby
		-- could enhance to include guild members via roster scanning to compare zones,
		-- or by using some guild member position lib.
		-- TODO: second return of UnitInRange is whether a check was performed; decide
		-- whether to treat unperformed checks as nearby.
		return
	end

	local ver, msgType, id, name, zone, level, x, y, GUID = strsplit("\t", msg)
	Debug("Message", channel, sender, msgType, id, name, zone, level, x, y, GUID)

	ver = deSAM(ver)
	level = deSAM(level)
	id = deSAM(id)
	x = deSAM(x)
	y = deSAM(y)
	zone = deSAM(zone)
	GUID = deSAM(GUID)

	if tonumber(ver or "") ~= protocol_version then
		Debug("Skipping: incompatible version")
		return
	end

	if msgType ~= "seen" then
		-- only one so far
		Debug("Skipping: unknown msgtype")
		return
	end

	if not (msgType and name and zone and id) then
		Debug("Skipping: insufficient data")
		return
	end

	-- We had one version which would include the " (Jade)" stuff in the syncs. Let's just strip that out.
	name = name:gsub("%s+%(.-%)$", "")

	-- id, zone, x, y, dead, source, unit, silent, force, GUID
	core:NotifyForMob(id, zone, x, y, false, "sync:"..channel..":"..sender, false, false, false, GUID)
end
