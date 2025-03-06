--------------------------------------------------------
-- Namespaces
--------------------------------------------------------
local _, core = ...;

core.sectionNames = {}
core.mountList = {}

core.mountList[1] = {
	name = "SL",
	categories = {
		Achievement = {
			name = "成就",
			mounts = {186654, 186637, 184183, 182596, 186653, 184166, 186655, 187673, "m1549", "m1576"},
			mountID = {"m15491", "m1549", "m1576"}
		},
		Vendor = {
			name = "商人",
			mounts = {180748},
			mountID = {}
		},
		Treasures = {
			name = "寶藏",
			mounts = {180731, 180772, 190766},
			mountID = {}
		},
		Adventures = {
			name = "冒險",
			mounts = {183052, 183617, 183615, 183618},
			mountID = {}
		},
		Riddles = {
			name = "解謎",
			mounts = {184168,186713},
			mountID = {}
		},
		Tormentors = {
			name = "折磨者",
			mounts = {185973},
			mountID = {}
		},
		MawAssaults = {
			name = "淵喉進攻戰",
			mounts = {185996, 186000, 186103},
			mountID = {}
		},
		Reputation = {
			name = "聲望",
			mounts = {180729, 182082, 183518, 183740, 186647, 186648, 187629, 187640},
			mountID = {}
		},
		ParagonReputation = {
			name = "巔峰聲望",
			mounts = {182081, 183800, 186649, 186644, 186657, 186641},
			mountID = {}
		},
		DungeonDrop = {
			name = "地下城掉落",
			mounts = {181819, 186638, "m1445"},
			mountID = {1445}
		},
		RaidDrop = {
			name = "團本掉落",
			mounts = {186656, 186642, 190768},
			mountID = {}
		},
		Zone = {
			name = "區域",
			mounts = {181818},
			mountID = {}
		},
		DailyActivities = {
			name = "日常活動",
			mounts = {182614, 182589, 186643, 186651, 186646, 188808},
			mountID = {}
		},
		RareSpawn = {
			name = "稀有刷新",
			mounts = {180728, 180727, 180725, 182650, 180773, 182085, 184062, 182084, 182079, 180582, 183741, 184167, 187183, 186652 ,186645, 186659, 187676, 190765},
			mountID = {}
		},
		OozingNecrorayEgg = {
			name = "沾黏的死靈魟魚卵",
			mounts = {184160, 184161, 184162},
			mountID = {}
		},
		CovenantFeature = {
			name = "誓盟特色",
			mounts = {180726, 181316, 181300, 181317},
			mountID = {}
		},
		NightFae = {
			name = "暗夜妖精",
			mounts = {180263, 180721, 183053, 180722, 180413, 180415, 180414, 180723, 183801, 180724, 180730, 186493, 186494, 186495, 186492},
			mountID = {}
		},
		Kyrian = {
			name = "琪瑞安族",
			mounts = {180761, 180762, 180763, 180764, 180765, 180766, 180767, 180768, 186482, 186485, 186480, 186483},
			mountID = {}
		},
		Necrolords = {
			name = "死靈領主",
			mounts = {182078, 182077, 181822, 182076, 182075, 181821, 181815, 182074, 181820, 182080, 186487, 186488, 186490, 186489},
			mountID = {}
		},
		Venthyr = {
			name = "汎希爾族",
			mounts = {182954, 180581, 180948, 183715, 180945, 182209, 182332, 183798, 180461, 186476, 186478, 186477, 186479},
			mountID = {}				
		},
		ProtoformSynthesis = {
			name = "原型體合成",
			mounts = {187632, 187670, 187663, 187665, 187630, 187631, 187638, 187664, 187677, 187683, 190580, 187679, 187667, 187639, 188809, 187668, 188810, 187672, 187669, 187641, 187678, 187671, 187660, 187666},
			mountID = {}
		},
		Torghast = {
			name = "托迦司",
			mounts = {188700, 188696, 188736},
			mountID = {}
		}
	}
}
core.mountList[2] = {
	name = "BFA",
	categories = {
		Achievement = {
			name = "成就",
			mounts = {168056, 168055, 169162, 163577, 169194, 168329, 161215, 163216, 166539, 167171, 174861, 174654, 235515},
			mountID = {}
		},
		Vendor = {
			name = "商人",
			mounts = {163183, 166442, 166443, 163589, 169203, 169202, 174770},
			mountID = {}
		},
		Quest = {
			name = "任務",
			mounts = {159146, 168827, 168408, 169199, 174859, 174771, 169200, 170069},
			mountID = {}
		},
		Medals = {
			name = "服役勛章",
			mounts = {166464, 166436, 166469, 166465, 166463},
			mountID = {}
		},
		AlliedRaces = {
			name = "同盟種族",
			mounts = {155662, 156487, 161330, 157870, 174066, 156486, 155656, 161331, 164762, 174067, 223572},
			mountID = {}
		},
		Reputation = {
			name = "聲望",
			mounts = {161773, 161774, 161665, 161666, 161667, 161664, 167167, 167170, 168829, 174754, 161911, 161912, 161910, 161879, 161909, 161908},
			mountID = {}
		},
		Riddle = {
			name = "解謎",
			mounts = {156798},
			mountID = {}
		},
		Tinkering = {
			name = "製造",
			mounts = {167751},
			mountID = {}
		},
		Zone = {
			name = "區域",
			mounts = {163576, 163574, 163575, 163573},
			mountID = {}
		},
		RareSpawn = {
			name = "稀有刷新",
			mounts = {161479, 166433, 169201, 168370, 168823, 169163, 174860},
			mountID = {}
		},
		WorldBoss = {
			name = "世界首領",
			mounts = {174842},
			mountID = {}
		},
		WarfrontArathi = {
			name = "戰爭前線: 阿拉希",
			mounts = {163579, 163578, 163644, 163645, 163706, 163646},
			mountID = {}
		},
		WarfrontDarkshore = {
			name = "戰爭前線: 黑海岸",
			mounts = {166438, 166434, 166435, 166432},
			mountID = {}
		},
		AssaultVale = {
			name = "突襲: 恆春谷",
			mounts = {173887, 174752, 174841, 174840, 174649},
			mountID = {}
		},
		AssaultUldum = {
			name = "突襲: 奧丹姆",
			mounts = {174769, 174641, 174753},
			mountID = {}
		},
		DungeonDrop = {
			name = "地下城掉落",
			mounts = {159921, 160829, 159842, 168826, 168830},
			mountID = {}
		},	
		RaidDrop = {
			name = "團本掉落",
			mounts = {166518, 166705, 174872},
			mountID = {}
		},	
		IslandExpedition = {
			name = "海嶼探險",
			mounts = {163584, 163585, 163583, 163586, 163582, 166470, 166468, 166467, 166466},
			mountID = {}
		},	
		Dubloons = {
			name = "海員達布隆幣",
			mounts = {166471, 166745},
			mountID = {}
		},
		Visions = {
			name = "驚魂幻像",
			mounts = {174653},
			mountID = {}
		},
		ParagonReputation = {
			name = "巔峰聲望",
			mounts = {169198},
			mountID = {}
		}
	}
}
core.mountList[3] = {
	name = "LEGION",
	categories = {
		Achievement = {
			name = "成就",
			mounts = {141216, 138387, 141217, 143864, 152815, 153041, 129280},
			mountID = {}
		},
		Vendor = {
			name = "商人",
			mounts = {138811, 141713, 137570},
			mountID = {}
		},
		Quest = {
			name = "任務",
			mounts = {137573, 142436, 137577, 137578, 137579, 137580},
			mountID = {}
		},
		Riddle = {
			name = "解謎",
			mounts = {138201, 147835, 151623},
			mountID = {}
		},
		RareSpawn = {
			name = "稀有刷新",
			mounts = {138258, 152814, 152844, 152842, 152840, 152841, 152843, 152904, 152905, 152903, 152790},
			mountID = {}
		},
		DungeonDrop = {
			name = "地下城掉落",
			mounts = {142236, 142552},
			mountID = {}
		},
		RaidDrop = {
			name = "團本掉落",
			mounts = {137574, 143643, 152816, 137575, 152789},
			mountID = {}
		},
		Class = {
			name = "職業",
			mounts = {142231, 143502, 143503, 143505, 143504, 143493, 143492, 143490, 143491, 142225, 142232, 143489, 142227, 142228, 142226, 142233, 143637, "m868", "m860", "m861", "m898"},
			mountID = {868, 860, 861, 898}
		},
		ParagonReputation = {
			name = "巔峰聲望",
			mounts = {147806, 147804, 147807, 147805, 143764, 153042, 153044, 153043},
			mountID = {}
		},
		Reputation = {
			name = "聲望",
			mounts = {152788, 152797, 152793, 152795, 152794, 152796, 152791},
			mountID = {}
		}
	}																										
}
core.mountList[4] = {
	name = "WOD",
	categories = {
		Achievement = {
			name = "成就",
			mounts = {116670, 116383, 127140, 128706},
			mountID = {}
		},
		Vendor = {
			name = "商人",
			mounts = {116664, 116785, 116776, 116775, 116772, 116672, 116768, 116671, 128480, 128526, 123974, 116667, 116655},
			mountID = {}
		},
		Garrison = {
			name = "要塞入侵",
			mounts = {116779, 116673, 116786, 116663},
			mountID = {}
		},
		Missions = {
			name = "派遣任務",
			mounts = {116769, 128311},
			mountID = {}
		},
		Stables = {
			name = "獸欄",
			mounts = {116784, 116662, 116676, 116675, 116774, 116656, 116668, 116781},
			mountID = {}
		},
		TradingPost = {
			name = "貿易站",
			mounts = {116782, 116665},
			mountID = {}
		},
		RareSpawn = {
			name = "稀有刷新",
			mounts = {116674, 116659, 116661, 116792, 116767, 116773, 116794, 121815, 116780, 116669, 116658},
			mountID = {}
		},
		WorldBoss = {
			name = "世界首領",
			mounts = {116771},
			mountID = {}
		},
		RaidDrop = {
			name = "團本掉落",
			mounts = {116660, 123890},
			mountID = {}
		},
		FishingShack = {
			name = "釣魚小屋",
			mounts = {87791},
			mountID = {}
		}		
	}		
}
core.mountList[5] = {
	name = "MOP",
	categories = {
		Achievement = {
			name = "成就",
			mounts = {87769, 87773, 81559, 93662, 104208, 89785},
			mountID = {}
		},
		GoldenLotus = {
			name = "金蓮會",
			mounts = {87781, 87782, 87783},
			mountID = {}
		},
		CloudSerpent = {
			name = "雲蛟衛",
			mounts = {85430, 85429, 79802},
			mountID = {}
		},
		ShadoPan = {
			name = "影潘",
			mounts = {89305, 89306, 89307},
			mountID = {}
		},
		KunLai = {
			name = "昆萊山商人",
			mounts = {87788, 87789, 84101},
			mountID = {}
		},
		TheTillers = {
			name = "黑龍王子",
			mounts = {89362, 89390, 89391},
			mountID = {}
		},
		PrimalEggs = {
			name = "原始恐龍蛋",
			mounts = {94291, 94292, 94293},
			mountID = {}
		},
		Quest = {
			name = "任務",
			mounts = {93386, 87768, 94290, 93385},
			mountID = {}
		},
		RaidDrop = {
			name = "團本掉落",
			mounts = {87777, 93666, 95059, 104253},
			mountID = {}
		},
		RareSpawn = {
			name = "稀有刷新",
			mounts = {90655, 94229, 94230, 94231, 104269},
			mountID = {}
		},
		WorldBoss = {
			name = "世界首領",
			mounts = {94228, 87771, 89783, 95057},
			mountID = {}
		},
		Reputation = {
			name = "聲望",
			mounts = {93169, 95565, 81354, 89304, 85262, 89363, 87774, 93168, 95564},
			mountID = {}
		}
	}																																
}
core.mountList[6] = {
	name = "CATA",
	categories = {
		Achievement = {
			name = "成就",
			mounts = {62900, 62901, 69213, 69230, 77068},
			mountID = {}
		},
		Quest = {
			name = "任務",
			mounts = {54465},
			mountID = {}
		},
		Vendor = {
			name = "商人",
			mounts = {65356, 64999, 63044, 63045, 64998},
			mountID = {}
		},
		DungeonDrop = {
			name = "地下城掉落",
			mounts = {69747, 63040, 63043, 68823, 68824},
			mountID = {}
		},
		RaidDrop = {
			name = "團本掉落",
			mounts = {77067, 77069, 78919, 63041, 69224, 71665},
			mountID = {}
		},
		RareSpawn = {
			name = "稀有刷新",
			mounts = {67151, 63042, 63046},
			mountID = {}
		}		
	}										
}
core.mountList[7] = {
	name = "WOTLK",
	categories = {
		Achievement = {
			name = "成就",
			mounts = {44160, 45801, 45802, 51954, 51955},
			mountID = {}
		},
		Quest = {
			name = "任務",
			mounts = {43962, 52200},
			mountID = {}
		},
		Vendor = {
			name = "商人",
			mounts = {44690, 44231, 44234, 44226, 44689, 44230, 44235, 44225},
			mountID = {}
		},
		ArgentTournament = {
			name = "銀白十字軍",
			mounts = {46814, 45592, 45593, 45595, 45596, 45597, 46743, 46746, 46749, 46750, 46751, 46816, 47180, 45725, 45125, 45586, 45589, 45590, 45591, 46744, 46745, 46747, 46748, 46752, 46815, 46813},
			mountID = {}
		},
		Reputation = {
			name = "聲望",
			mounts = {44080, 44086, 43955, 44707, 43958, 43961},
			mountID = {}
		},
		DungeonDrop = {
			name = "地下城掉落",
			mounts = {43951, 44151},
			mountID = {}
		},
		RaidDrop = {
			name = "團本掉落",
			mounts = {43952, 43953, 43954, 43986, 49636, 43959, 45693, 50818, 44083},
			mountID = {}
		},
		RareSpawn = {
			name = "稀有刷新",
			mounts = {44168},
			mountID = {}
		}			
	}																		
}
core.mountList[8] = {
	name = "TBC",
	categories = {
		CenarionExpedition = {
			name = "塞納裡奧遠征隊",
			mounts = {33999},
			mountID = {}
		},
		Kurenai = {
			name = "庫雷尼/瑪格漢",
			mounts = {29227, 29231, 29229, 29230, 31830, 31832, 31834, 31836},
			mountID = {}
		},
		Netherwing = {
			name = "虛空之翼",
			mounts = {32858, 32859, 32857, 32860, 32861, 32862},
			mountID = {}
		},
		Shatari = {
			name = "薩塔禦天者",
			mounts = {32319, 32314, 32316, 32317, 32318},
			mountID = {}
		},
		Vendor = {
			name = "商人",
			mounts = {25473, 25527, 25528, 25529, 25470, 25471, 25472, 25477, 25531, 25532, 25533, 25474, 25475, 25476},
			mountID = {}
		},
		DungeonDrop = {
			name = "地下城掉落",
			mounts = {32768, 35513},
			mountID = {}
		},
		RaidDrop = {
			name = "團本掉落",
			mounts = {32458, 30480},
			mountID = {}
		}
	}
}
core.mountList[9] = {
	name = "Classic",
	categories = {	
		Reputation = {
			name = "聲望",
			mounts = {13086, 46102},
			mountID = {}
		},
		DungeonDrop = {
			name = "地下城掉落",
			mounts = {13335},
			mountID = {}
		},
		RaidDrop = {
			name = "團本掉落",
			mounts = {21218, 21321, 21323, 21324},
			mountID = {}
		}
	}						
}
core.mountList[10] = {
	name = "Alliance",
	categories = {	
		Human = {
			name = "人類",
			mounts = {18776, 18777, 18778, 5655, 2411, 2414, 5656},
			mountID = {}
		},
		NightElf = {
			name = "暗夜精靈",
			mounts = {18766, 18767, 18902, 8629, 8631, 8632, 47100},
			mountID = {}
		},
		Dwarf = {
			name = "矮人",
			mounts = {18785, 18786, 18787, 5864, 5872, 5873},
			mountID = {}
		},
		DarkIronDwarf = {
			name = "黑鐵矮人",
			mounts = {191123},
			mountID = {}
		},
		Gnome = {
			name = "地精",
			mounts = {18772, 18773, 18774, 8563, 8595, 13322, 13321},
			mountID = {}
		},
		Draenei = {
			name = "德萊尼",
			mounts = {29745, 29746, 29747, 28481, 29743, 29744},
			mountID = {}
		},
		Worgen = {
			name = "狼人",
			mounts = {73839, 73838},
			mountID = {}
		},
		Pandaren = {
			name = "熊貓人",
			mounts = {91010, 91012, 91011, 91013, 91014, 91015, 91004, 91008, 91009, 91005, 91006, 91007},
			mountID = {}
		},
		Dracthyr = {
			name = "半龍人",
			mounts = {201720, 201702, 201719, 201704, 198809, 198811, 198810, 198808},
			mountID = {},
		}		
	}				
}
core.mountList[11] = {
	name = "Horde",
	categories = {	
		Orc = {
			name = "獸人",
			mounts = {18796, 18798, 18797, 46099, 5668, 5665, 1132},
			mountID = {}
		},
		Undead = {
			name = "不死族",
			mounts = {13334, 18791, 13331, 13332, 13333, 46308, 47101},
			mountID = {}
		},
		Tauren = {
			name = "牛頭人",
			mounts = {18793, 18794, 18795, 15277, 15290, 46100},
			mountID = {}
		},
		Troll = {
			name = "食人妖",
			mounts = {18788, 18789, 18790, 8588, 8591, 8592},
			mountID = {}
		},
		Bloodelf = {
			name = "血精靈",
			mounts = {28936, 29223, 29224, 28927, 29220, 29221, 29222, 191566},
			mountID = {}
		},
		Goblin = {
			name = "哥不林",
			mounts = {62462, 62461},
			mountID = {}
		},			
		Pandaren = {
			name = "熊貓人",
			mounts = {91010, 91012, 91011, 91013, 91014, 91015, 91004, 91008, 91009, 91005, 91006, 91007},
			mountID = {}
		},
		Dracthyr = {
			name = "半龍人",
			mounts = {201720, 201702, 201719, 201704, 198809, 198811, 198810, 198808},
			mountID = {},
		}
	}
}
core.mountList[12] = {
	name = "Professions",
	categories = {	
		Alchemy = {
			name = "煉金術",
			mounts = {65891},
			mountID = {}
		},
		Archeology = {
			name = "考古學",
			mounts = {60954, 64883, 131734},
			mountID = {}
		},
		Engineering = {
			name = "工程學",
			mounts = {34060, 41508, 34061, 44413, 87250, 87251, 95416, 161134, 153594},
			mountID = {}
		},
		Fishing = {
			name = "釣魚",
			mounts = {46109, 23720, 152912, 163131},
			mountID = {}
		},
		Jewelcrafting = {
			name = "珠寶加工",
			mounts = {83088, 83087, 83090, 83089, 82453},
			mountID = {}
		},
		Tailoring = {
			name = "裁縫",
			mounts = {44554, 54797, 44558, 115363},
			mountID = {}
		},
		Leatherworking = {
			name = "製皮",
			mounts = {108883, 129962},
			mountID = {}
		},
		Blacksmith = {
			name = "鍛造",
			mounts = {137686},
			mountID = {}
		}
	}
}
core.mountList[13] = {
	name = "PVP",
	categories = {	
		Achievement = {
			name = "成就",
			mounts = {44223, 44224},
			mountID = {}
		},
		MarkHonor = {
			name = "榮耀印記",
			mounts = {19030, 29465, 29467, 29468, 29471, 35906, 43956, 29466, 29469, 29470, 29472, 19029, 34129, 44077},
			mountID = {}
		},
		Honor = {
			name = "榮譽",
			mounts = {140228, 140233, 140408, 140232, 140230, 140407, 164250},
			mountID = {}
		},
		ViciousSaddle = {
			name = "邪氣鞍座",
			mounts = {102533, 70910, 116778, 124540, 140348, 140354, 143649, 142235, 142437, 152869, 163124, 165020, 163121, 173713, 184013,184014, 186179, 70909, 102514, 116777, 124089, 140353, 140350, 143648, 142234, 142237, 152870, 163123, 163122, 173714, 186178, 187681, 187680, 187642, 187644, 201788, 201789, 205245, 205246, 210070, 210069, 213439, 213440},
			mountID = {}
		},
		Gladiator = {
			name = "角鬥士",
			mounts = {},
			mountID = {}
		},
		Halaa = {
			name = "哈剌",
			mounts = {28915, 29228},
			mountID = {}
		},
		TimelessIsle = {
			name = "永恆島",
			mounts = {103638},
			mountID = {}
		},
		TalonsVengeance = {
			name = "復仇之爪",
			mounts = {142369},
			mountID = {}
		}
	}
}
core.mountList[14] = {
	name = "WorldEvents",
	categories = {	
		Achievement = {
			name = "成就",
			mounts = {44177},
			mountID = {}
		},
		Brewfest = {
			name = "美酒節",
			mounts = {33977, 37828},
			mountID = {}
		},
		HallowsEnd = {
			name = "萬鬼節",
			mounts = {37012},
			mountID = {}
		},
		LoveAir = {
			name = "情人節",
			mounts = {72146, 50250, 210973, 232926},
			mountID = {}
		},
		NobleGarden = {
			name = "復活節",
			mounts = {72145, 212599},
			mountID = {}
		},
		WinterVeil = {
			name = "冬幕節",
			mounts = {128671},
			mountID = {}
		},
		Brawlers = {
			name = "鬥陣俱樂部",
			mounts = {98405},
			mountID = {}
		},
		DarkmoonFaire = {
			name = "暗月馬戲團",
			mounts = {72140, 73766, 142398, 153485},
			mountID = {}
		},
		TimeWalking = {
			name = "時光漫遊",
			mounts = {129923, 129922, 87775, 167894, 167895, 133543, 188674, 187595, 231374, 224398, 224399,234730,232624,205208,234721,234716,234740},
			mountID = {}
		},
		Lunar = {
			name = "新年慶典",
			mounts = {232901},
			mountID = {}
		}
	}
}
core.mountList[15] = {
	name = "Promotion",
	categories = {	
		BlizzardStore = {
			name = "暴雪商城",
			mounts = {54811, 69846, 78924, 95341, 97989, 107951, 112326, 122469, 147901, 156564, 160589, 166775, 166774, 166776, "m1266", "m1267", "m1290", "m1346", "m1291", "m1456", "m1330", "m1531", "m1581", "m1312", "m1662", 76755, "m1594", "m1583", "m1797", 203727, "m1795", "m1692", 212229, 228751, 229128, 219450, 224574, "m2237", 229418, 230184, 230200, 230201, 230185, 227362, 235344, 231297},
			mountID = {1266, 1267, 1290, 1346, 1291, 1456, 1330, 1531, 1581}
		},
		CollectorsEdition = {
			name = "典藏版",
			mounts = {85870, 109013, 128425, 153539, 153540, "m1289", "m1556", "m1792"},
			mountID = {1289, 1556}
		},
		WowClassic = {
			name = "魔獸世界經典版",
			mounts = {"m1444", "m1602", "m1812"},
			mountID = {1444, 1602}
		},
		anniversary = {
			name = "魔獸世界周年慶典坐騎",
			mounts = {172022, 172023, 186469, 208572, 228760, 229348},
			mountID = {}
		},
		Hearthstone = {
			name = "爐石戰記",
			mounts = {98618, "m1513", 163186, 212522},
			mountID = {1513}
		},
		WarcraftIII = {
			name = "魔獸爭霸III：重製版",
			mounts = {164571},
			mountID = {}
		},
		DiabloIV = {
			name = "暗黑破壞神 IV",
			mounts = {"m1596"},
			mountID = {}
		},		
		RAF = {
			name = "戰友招募",
			mounts = {173297, 173299, 204091},
			mountID = {}
		},
		AzerothChoppers = {
			name = "艾澤拉斯機車",
			mounts = {116789},
			mountID = {}
		},
		TCG = {
			name = "集換式卡牌",
			mounts = {49283, 49284, 49285, 49286, 49282, 49290, 54069, 54068, 68008, 69228, 68825, 71718, 72582, 72575, 79771, 93671},
			mountID = {}
		},
		AV = {
			name = "時空漫游: 奧特蘭克山谷",
			mounts = {172023, 172022},
			mountID = {}
		},
		PlunderStorm = {
			name="強襲風暴",
			mounts = {"m1259","m994",233241,233240,233243,233242},
		},
		ProductPromotion = {
			name="產品推廣",
			mounts = {"m1947", "m1946"}
		}
	}	
}
core.mountList[16] = {
	name = "Other",
	categories = {	
		GuildVendor = {
			name = "公會商人",
			mounts = {63125, 62298, 67107, 85666, 116666},
			mountID = {}
		},
		BMAH = {
			name = "黑市拍賣行",
			mounts = {19872, 19902, 44175, 163042},
			mountID = {}
		},
		MountCollection = {
			name = "坐騎收集",
			mounts = {44178, 44843, 44842, 98104, 91802, 98259, 69226, 87776, 137614, 163981, 118676, 198654},
			mountID = {}
		},
		ExaltedReputations = {
			name = "聲望崇拜",
			mounts = {163982},
			mountID = {}
		},
		Toy = {
			name = "玩具",
			mounts = {140500},
			mountID = {}
		},
		Heirlooms = {
			name = "傳家寶",
			mounts = {120968, 122703},
			mountID = {}
		},
		Paladin = {
			name="聖騎士",
			mounts = {47179, "m2233", "m41", "m84", "m149", "m150", "m350", "m351", "m367", "m368", "m1046", "m1047", "m1568"},
			mountID = {}
		},
		Warlock = {
			name="術士",
			mounts = {"m17", "m83"},
			mountID = {17, 83},
		},
		DemonHunter = {
			name="惡魔獵人",
			mounts = {"m780"},
		},
		TradingPost = {
			name = "貿易站",
			mounts = {190231, 190168, 190539, 190767, 190613, 206156, 137576, 208598, 211074, 210919, 212227, 212630, 212920, 192766, 226041, 226040, 226044, 226042, 226506, 223449, 223469, 187674, 233019,233020,233023,233354,212631, 223285, 221814, 207821, 190169, 189978, 206976, 206027, "m1595", 235646, 235650, 235555, 235556, 235554, 235657, 235557, 235658, 235659, 235662},
		},		
	}
}
core.mountList[17] = {
	name = "Unobtainable",
	categories = {	
		MythicPlus = {
			name = "傳奇 +",
			mounts = {182717, 187525, 174836, 187682, 192557, 199412, 204798, 209060, 213438, 226357},
			mountID = {}
		},
		ScrollOfResurrection = {
			name = "復活卷軸",
			mounts = {76902, 76889},
			mountID = {}
		},
		ChallengeMode = {
			name = "挑戰模式",
			mounts = {89154, 90710, 90711, 90712, 116791},
			mountID = {}
		},
		RAF = {
			name = "戰友招募",
			mounts = {83086, 106246, 118515, 37719, "m382"},
			mountID = {}
		},
		AOTC = {
			name = "引領潮流",
			mounts = {104246, 128422, 152901, 174862, 190771},
			mountID = {}
		},
		Brawl = {
			name = "鬥陣俱樂部",
			mounts = {142403, 98405, 166724},
			mountID = {}
		},
		Arena = {
			name = "競技場坐騎",
			mounts = {30609, 34092, 37676, 43516, 46708, 46171, 47840, 50435, 71339, 71954, 85785, 95041, 104325, 104326, 104327, 128277, 128281, 128282, 141843, 141844, 141845, 141846, 141847, 141848, 153493, 156879, 156880, 156881, 156884, 183937, 186177, 189507, 191290, 202086, 210345, 210077, 223586},
			mountID = {}
		},
		DCAzerothChopper = {
			name = "艾澤拉斯機車",
			mounts = {116788},
			mountID = {}
		},
		OriginalEpic = {
			name = "舊版史詩坐騎",
			mounts = {13328, 13329, 13327, 13326, 12354, 12353, 12302, 12303, 12351, 12330, 15292, 15293, 13317, 8586},
			mountID = {}
		},
		Promotion = {
			name = "舊版促銷坐騎",
			mounts = {76755, 95341, 112327, 92724, 143631, 163127, 43599, 151618, "m1458"},
			mountID = {}
		},
		RaidMounts = {
			name = "絕版團本坐騎",
			mounts = {49098, 49096, 49046, 49044, 44164, 33809, 21176, "m937"},
			mountID = {937}
		},
		BrewFest = {
			name = "美酒節",
			mounts = {33976},
			mountID = {}
		},
		Anniversary = {
			name="舊周年慶坐騎",
			mounts = {172012, 115484, "m1424"},
			mountID = {}
		},
		PreLaunchEvent = {
			name = "前夕事件",
			mounts = {163127, 163128, 217987, 217985},
			mountID = {}
		},
		RemixMOP = {
			name="潘達利亞混搭再造",
			mounts = {220766,220768,213582,213576,213584,213595,87784,213602,213603,213605,213606,213607,213604,213608,213609,213628,213627,87786,87787,84753,213626,213624,213625,213623,213622,213621,218111,213600,213601,213598,213597,213596},	
		}
	}
}
core.mountList[18] = {
	name = "Dragonflight",
	categories = {
		DragonRiding = {
			name = "飛龍騎術",
			mounts = {194034, 194705, 194521, 194549, 204361, 210412}
		},
		Achievement = {
			name = "成就",
			mounts = {192806, 192791, 192784, 205205, 208152, 210060, 192774, 210142, "m1614", 198822, 192792, 192788, 211862, 192765, "m1733", 217340},
		},
		Treasures = {
			name = "寶藏",
			mounts = {201440, 198825, 192777, 192779,205204, 210059},
		},
		Quest = {
			name = "任務",
			mounts = {192799, 198870, 206567, 206566, "m1545", 210774, 211873},
		},
		Reputation = {		
			name = "聲望",
			mounts = {192762, 198872, 192761, 192764, 200118, 201426, 201425, 205155, 205209, 205207, 210969, 210833, 210831, 210946, 210948, 210945, 209951, 209949},
		},
		Zone = {
			name = "區域",
			mounts = {192601, 198873, 198871, 192775, 201454, 192800, 204382, 192785, 192790, 192772, 191838, 205203, 205197,210775, 210769, 210058, 210057, 209947, 209950, 212645, "m1638", 192807, 198824, 229949},
		},
		Secret = {
			name = "秘密",
			mounts = {192786}
		},
		Vendor = {
			name = "商人",
			mounts = {206673, 206680, 206676, 206678, 206674, 206679, 206675, 211084}
		},
		Raid = {
			name = "團隊副本",
			mounts = {"m1818"}
		},
	}
}
core.mountList[19] = {
	name = "The War Within",
	categories = {
		RareDrops = {
			name = "稀有掉落",
			mounts = {223315,223270,223501},
		},
		Raid = {
			name = "團隊副本",
			mounts = {224147,224151, 236960, 235626},
		},
		Dungeon = {
			name = "地下城",
			mounts = {221765,225548},
		},
		Achievement = {
			name = "成就",
			mounts = {223266,224415,223267,223286,223158, "m2190"},
		},
		Quest = {
			name = "任務",
			mounts = {219391,224150},
		},
		Reputation = {
			name = "聲望",
			mounts = {223571,221753,223505,222989,223317,223314,223274,223264,223276,223278,223279},
		},
		Profession = {
			name = "專業技能",
			mounts = {221967},
		},
		Vendor = {
			name = "商人",
			mounts = {223153},
		},
		PVP = {
			name = "PVP",
			mounts = {223511,221813},
		},
		Zone = {
			name = "區域",
			mounts = {223269, 223318},
		},			
		SirenIsland = {
			name = "海妖島",
			mounts = {232639, 233058, 233489, 232991}
		},
		UnderMine = {
			name = "幽坑城",
			mounts = {229974, 229953, 229955,  229954, 233064, 229941, 229952, 229949}
		},
		Delves = {
			name = "探究",
			mounts = {229944,229956,229948,229935,229946,229936,229950}
		}		
	}
}

core.sectionNames[11] = {
	name = "經典",
	mounts = core.mountList[9],
	icon = "Interface\\AddOns\\MCL\\icons\\classic.blp",
}
core.sectionNames[10] = {
	name = "燃燒的遠征",
	mounts = core.mountList[8],
	icon = "Interface\\AddOns\\MCL\\icons\\bc.blp",
}
core.sectionNames[9] = {
	name = "巫妖王之怒",
	mounts = core.mountList[7],
	icon = "Interface\\AddOns\\MCL\\icons\\wrath.blp",
}
core.sectionNames[8] = {
	name = "浩劫與重生",
	mounts = core.mountList[6],
	icon = "Interface\\AddOns\\MCL\\icons\\cata.blp",
}
core.sectionNames[7] = {
	name = "潘達利亞迷霧",
	mounts = core.mountList[5],
	icon = "Interface\\AddOns\\MCL\\icons\\mists.blp",
}
core.sectionNames[6] = {
	name = "德拉諾之霸",
	mounts = core.mountList[4],
	icon = "Interface\\AddOns\\MCL\\icons\\wod.blp",
}
core.sectionNames[5] = {
	name = "軍臨天下",
	mounts = core.mountList[3],
	icon = "Interface\\AddOns\\MCL\\icons\\legion.blp",
}
core.sectionNames[4] = {
	name = "決戰艾澤拉斯",
	mounts = core.mountList[2],
	icon = "Interface\\AddOns\\MCL\\icons\\bfa.blp",
}
core.sectionNames[3] = {
	name = "暗影之境",
	mounts = core.mountList[1],
	icon = "Interface\\AddOns\\MCL\\icons\\sl.blp",
}
core.sectionNames[2] = {
	name = "巨龍崛起",
	mounts = core.mountList[18],
	icon = "Interface\\AddOns\\MCL\\icons\\df.blp",
}
core.sectionNames[1] = {
	name = "地心之戰",
	mounts = core.mountList[19],
	icon = "Interface\\AddOns\\MCL\\icons\\tww.blp",
}
core.sectionNames[12] = {
	name = "部落",
	mounts = core.mountList[11],
	icon = "Interface\\AddOns\\MCL\\icons\\horde.blp",
}
core.sectionNames[13] = {
	name = "聯盟",
	mounts = core.mountList[10],
	icon = "Interface\\AddOns\\MCL\\icons\\alliance.blp",
}
core.sectionNames[14] = {
	name = "專業技能",
	mounts = core.mountList[12],
	icon = "Interface\\AddOns\\MCL\\icons\\professions.blp",
}
core.sectionNames[15] = {
	name = "PVP",
	mounts = core.mountList[13],
	icon = "Interface\\AddOns\\MCL\\icons\\pvp.blp",
}
core.sectionNames[16] = {
	name = "世界事件",
	mounts = core.mountList[14],
	icon = "Interface\\AddOns\\MCL\\icons\\holiday.blp",
}
core.sectionNames[17] = {
	name = "促銷",
	mounts = core.mountList[15],
	icon = "Interface\\AddOns\\MCL\\icons\\promotion.blp",
}
core.sectionNames[18] = {
	name = "其他",
	mounts = core.mountList[16],
	icon = "Interface\\AddOns\\MCL\\icons\\other.blp",
}
core.sectionNames[19] = {
	name = "絕版",
	mounts = core.mountList[17],
	icon = "Interface\\AddOns\\MCL\\icons\\unobtainable.blp",
}
core.sectionNames[20] = {
	name = "釘選",
	mounts = {MCL_PINNED},
	icon = "Interface\\AddOns\\MCL\\icons\\pin.blp",	
}
core.sectionNames[21] = {
	name = "總覽",
	mounts = {},
	icon = "Interface\\AddOns\\MCL\\icons\\mcl.blp",	
}

core.regionalFilter = {
	['CN'] = {210077},
}

-- Mounts not currently in game?

-- 229945 - Busted - https://www.wowhead.com/item=229945/thunderdrum-misfire
-- 229947 - Busted
-- 232523 - Busted - https://www.wowhead.com/item=232523/g-99-breakneck