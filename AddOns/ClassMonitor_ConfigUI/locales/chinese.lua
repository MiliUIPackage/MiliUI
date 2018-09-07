local ADDON_NAME, Engine = ...
local L = Engine.Locales

if GetLocale() == "zhCN" then
	L.CLASSMONITOR_CONFIG_RL = "已经做出了一至多项改动，请重载界面。"
	L.CLASSMONITOR_RESETCONFIG_CONFIRM = "这会重置所有已做出的设置，且需要重载界面。你确定要这样做吗？"
	L.CLASSMONITOR_CREATENEWPLUGIN_CONFIRM = "这将创建名为%s'，'%s'类型的模组。你确定要这样做吗？"
	L.CLASSMONITOR_SWITCHAUTOGRIDANCHOR_CONFIRM = "该功能仍然处于试验阶段。你确定要使用它吗？如果插件报错，请使用/clm reset恢复默认设置:)。"
	L.CLASSMONITOR_DELETEPLUGIN_CONFIRM = "这将会删除模组'%s'，以此模组为锚点的模组将会重定位。此操作不可撤消，你确定要这样做吗？"

	L.NoPluginDescription = "没有检测到该模组的描述"
	L.MustBeANumber = "请提供一个数值"
	L.InvalidSpellID = "错误的法术ID"
	L.InvalidSpellName = "错误的法术名称"
	L.PluginNameAlreadyExists = "模组%s已存在"
	L.Threshold = "阈值"
	L.Text = "文本"
	L.TextSize = "字体大小"
	L.TextSizeDesc = "文本大小"
	L.CurrentValue = "当前值"
	L.TimeLeft = "剩余时间"
	L.Duration = "持续时间"
	L.Filled = "填充"
	L.BorderRemind = "始终显示边框"
	L.Count = "数量"
	L.Colors = "颜色"
	L.BarColor = "监视条颜色"

	L.GlobalReset = "重置设置"
	L.GlobalResetDesc = "恢复之前的设置"
	L.GlobalWidth = "全局宽度"
	L.GlobalWidthDesc = "更改此数值会更改所有监视条的宽度"
	L.GlobalHeight = "全局高度"
	L.GlobalHeightDesc = "更改此数值会更改所有监视条的高度"
	L.GlobalAutoGridAnchor = "自动框架锚点（试验中）"
	L.GlobalAutoGridAnchorDesc = "自动网格锚点（试验中）"
	L.GlobalAutoGridAnchorEnabled = "启用"
	L.GlobalAutoGridAnchorEnabledDesc = "启用自动框架锚点"
	L.GlobalAutoGridAnchorSpacing = "垂直间隔"
	L.GlobalAutoGridAnchorSpacingDesc = "两个模组（监视条）间的垂直间隔"
	L.GlobalNewPluginInstance = "创建模组（监视条）"
	L.GlobalNewPluginInstanceDesc = "立即创建一个新的监视条"
	L.GlobalCreateNewPluginButton = "创建"
	L.GlobalCreateNewPluginButtonDesc = "点击以立即创建"
	L.GlobalDebugMode = "Debug"
	L.GlobalDebugModeDesc = "在Debug模式下，所有模块的额外信心都会显示"

	L.Delete = "删除"
	L.DeleteDesc = "立即删除此模组（监视条）"

	-- 帮助手册定义
	L.Name = "框架名称"
	L.NameDesc = "框架（监视条）名称"

	L.DisplayName = "名称"
	L.DisplayNameDesc = "会在控制台和错误提示里显示具体的框架（监视条）名称"

	L.Kind = "种类"
	L.KindDesc = "监视种类"
	--L.PluginShortDescription_Mover = "移动"

	L.Enabled = "启用"
	L.EnabledDesc = "启用/禁用此模组（监视条）"

	L.Autohide = "自动隐藏"
	L.AutohideDesc = "勾选后，此模组（监视条）会在非战斗状态下自动隐藏"

	L.Size = "尺寸"
	L.SizeDesc = "模组（监视条）的尺寸大小"
	L.Width = "宽度"
	L.WidthDesc = "模组宽度设置"
	L.Height = "高度"
	L.HeightDesc = "模组高度设置"

	L.Filter = "过滤器"
	L.FilterDesc = "Buff/Debuff"
	L.FilterValueHelpful = "Buff"
	L.FilterValueHarmful = "Debuff"

	L.Reverse = "反转"
	L.ReverseDesc = "将增长方向从向右变为向左"

	L.Unit = "单位"
	L.UnitDesc = "要监视的单位"
	L.UnitValuePlayer = "玩家"
	L.UnitValueTarget = "目标"
	L.UnitValueFocus = "焦点"
	L.UnitValuePet = "宠物"

	L.Specs = "专精"
	L.SpecsDesc = "在特定的职业专精下启用"

	L.Spell = "法术"
	L.SpellDesc = "要监视的法术"
	L.SpellSpellID = "法术ID"
	L.SpellSpellIDDesc = "要监视的法术ID"
	L.SpellSpellName = "法术名称"
	L.SpellSpellNameDesc = "要监视的法术名称"

	L.Anchor = "锚点"
	L.AnchorDesc = "锚点"
	L.AnchorPoint = "定位点"
	L.AnchorPointDesc = "模块相对于锚点的定位点"
	L.AnchorRelativeFrame = "相对框体"
	L.AnchorRelativeFrameDesc = "定位于锚点的框体"
	L.AnchorRelativePoint = "相对定位点"
	L.AnchorRelativePointDesc = "定位于相对定位点的框体"
	L.AnchorOffsetX = "水平偏移"
	L.AnchorOffsetXDesc = "相对于锚点的水平偏移"
	L.AnchorOffsetY = "垂直偏移"
	L.AnchorOffsetYDesc = "相对于锚点的垂直偏移"

	L.AutoGridAnchor = "自动网格坐标"
	L.AutoGridAnchorDesc = "自动网格锚点的坐标"
	L.AutoGridAnchorVerticalIndex = "行"
	L.AutoGridAnchorVerticalIndexDesc = "垂直网格参数"
	L.AutoGridAnchorHorizontalIndex = "列"
	L.AutoGridAnchorHorizontalIndexDesc = "水平网格参数"

	L.CustomColor = "自定义颜色"
	L.CustomColorDesc = "使用自定义颜色而不是框架设定颜色"

	-- 模组定义
	L.AuraCount = "最大堆叠数"
	L.AuraCountDesc = "最大堆叠数"
	L.AuraFilledDesc = "填充/不填充"

	L.AurabarTextDesc = "显示目前的堆叠数/最大堆叠数"
	L.AurabarDurationDesc = "显示光环剩余时间"
	L.AurabarColor = "监视条颜色"
	L.AurabarShowspellname = "光环名称"
	L.AurabarShowspellnameDesc = "显示光环名称"
	L.AurabarCountFromOther = "另外的计数来源"
	L.AurabarCountFromOtherDesc = "显示的计数来自其他法术"
	L.AurabarCountSpellID = "计数光环名称"
	L.AurabarCountSpellIDDesc = "计数光环名称"

	L.BanditsGuileShallow = GetSpellInfo(84745)
	L.BanditsGuileModerate = GetSpellInfo(84746)
	L.BanditsGuileDeep = GetSpellInfo(84747)

	L.CDText = "法术名称"
	L.CDTextDesc = "显示法术名称"
	L.CDDurationDesc = "显示剩余时间"

	L.ComboFilledDesc = "连击点填充/不填充"
	L.ComboBorderRemindDesc = "连击点边框是否一直显示"

	L.DemonicfuryTextDesc = "显示当前的恶魔之怒的数值"

	L.DotLatency = "Dot变色"
	L.DotLatencyDesc = "按照Dot剩余时间变化监视条颜色"
	L.DotThresholdDesc = "阈值"
	L.DotColor1 = "低于阈值"
	L.DotColor2 = "75%阈值"
	L.DotColor3 = "高于阈值"

	L.EclipseLunar = "月蚀"
	L.EclipseSolar = "日蚀"
	L.EclipseText = "方向"
	L.EclipseTextDesc = "显示鸟德月蚀条的充能方向"

	L.EnergizeFilling = "填充"
	L.EnergizeFillingDesc = "填充/留空此条"
	L.EnergizeDuration = "持续时间"
	L.EnergizeDurationDesc = "资源回复的持续时间"

	L.HealtTextDesc = "显示当前生命值"

	L.PowerType = "能量类型"
	L.PowerTypeDesc = "要监视的能量类型"
	L.PowerValueHolyPower = "神圣能量"
	L.PowerValueSoulShards = "灵魂碎片"
	L.PowerValueChi = "气"
	L.PowerValueShadowOrbs = "暗影宝珠"
	L.PowerValueArcaneBlast = "奥术充能"
	L.PowerCount = "最大能量数"
	L.PowerCountDesc = "最大能量数"
	L.PowerFilledDesc = "填充/不填充"
	L.ComboBorderRemindDesc = "能量点边框是否一直显示"

	L.RechargeTextDesc = "显示充能的剩余时间"

	L.RechargeBarTextDesc = "显示剩余时间"

	L.ResourceTextDesc = "显示当前值"
	L.ResourceHideifmax = "最大值时隐藏"
	L.ResourceHideifmaxDesc = "当前值等于最大值（离开战斗）时隐藏"

	L.RunesThresholdDesc = "每2次刷新的时间间隔"
	L.RunesOrientation = "符文种类"
	L.RunesOrientationDesc = "符文充能"
	L.RunesBlood = "血"
	L.RunesUnholy = "邪"
	L.RunesFrost = "冰"
	L.RunesDeath = "死"
	L.RunesOrientationHorizontal = "水平"
	L.RunesOrientationVertical = "垂直"
	L.RunesRunemap = "符文顺序"
	L.RunesRunemapDesc = "改变符文排列顺序"
	L.RunesSlot = "栏位%d"
	L.RunesSlotDesc = "选择符文放置在%d"
	L.RuneDuration = "符文冷却时间"
	L.RuneDurationDesc = "是否显示符文冷却时间"
	L.RuneDurationSize = "字体大小"
	L.RuneDurationSizeDesc = "符文冷却时间的显示字体大小"

	L.StaggerThresholdDesc = "超过此值则不显示生命值百分比"
	L.StaggerTextDesc = "显示当前醉拳值"
	--ALREADY LOCALIZED IN ENGLISH.LUA --L.StaggerLight = GetSpellInfo(124275)
	--ALREADY LOCALIZED IN ENGLISH.LUA --L.StaggerModerate = GetSpellInfo(124274)
	--ALREADY LOCALIZED IN ENGLISH.LUA --L.StaggerHeavy = GetSpellInfo(124273)

	L.StatueTextDesc = "显示雕像/光明之泉/食尸鬼/战旗的剩余持续时间"

	L.TankshieldDurationDesc = "显示护盾剩余时间"

	L.TotemsCountDesc = "图腾/仆从数量"
	L.TotemsTextDesc = "显示每根图腾/每个仆从的剩余时间"
	L.TotemsOthers = "1(其他职业)"
	L.TotemsShaman = "4(萨满)"

	--------
	L.PluginShortDescription_AURA = "光环堆叠"
	L.PluginDescription_AURA = "显示Buff/Debuff的堆叠数"
	L.PluginShortDescription_AURABAR = "光环监视条"
	L.PluginDescription_AURABAR = "为一个Buff/Debuff显示堆叠数量及剩余持续时间"
--	L.PluginShortDescription_BURNING_SOUL_SHARD = "毁灭术余烬"
--	L.PluginDescription_BURNING_SOUL_SHARD = "在一个监视条上显示毁灭术的余烬"
	L.PluginShortDescription_RESOURCE = "资源监视条"
	L.PluginDescription_RESOURCE = "在一个监视条上显示当前职业的主要资源，会根据专精/形态/姿态自动切换"
--	L.PluginShortDescription_COMBO = "连击点"
--	L.PluginDescription_COMBO = "显示连击点"
	L.PluginShortDescription_POWER = "能量点"
	L.PluginDescription_POWER = "显示神圣能量、灵魂收割、暗影宝珠或是其它能量点"
	L.PluginShortDescription_RUNES = "符文"
	L.PluginDescription_RUNES = "显示死亡骑士的符文，且符文的排列次序可自行调整"
--	L.PluginShortDescription_ECLIPSE = "月蚀条"
--	L.PluginDescription_ECLIPSE = "显示月蚀条"
	L.PluginShortDescription_ENERGIZE = "资源回复条"
	L.PluginDescription_ENERGIZE = "在一个监视条上显示有内置CD的隐藏法力回复效果，比如牧师的全神贯注"
	L.PluginShortDescription_HEALTH = "生命值"
	L.PluginDescription_HEALTH = "为玩家/目标/宠物/焦点提供一个生命值监视条"
	L.PluginShortDescription_DOT = "DoT监视条"
	L.PluginDescription_DOT = "在一个监视条上显示DOT剩余时间"
	L.PluginShortDescription_TOTEMS = "仆从生物"
	L.PluginDescription_TOTEMS = "显示萨满图腾，小德百花等等玩家仆从的剩余时间"
	--ALREADY LOCALIZED IN ENGLISH.LUA --L.PluginShortDescription_BANDITSGUILE = select(1, GetSpellInfo(84654)) -- 盗匪之诈
--	L.PluginDescription_BANDITSGUILE = "显示战斗贼盗匪之诈的堆叠层数"
	--ALREADY LOCALIZED IN ENGLISH.LUA --L.PluginShortDescription_STAGGER =  select(1, GetSpellInfo(124255)) -- 醉拳
	L.PluginDescription_STAGGER = "显示当前酿酒武僧的醉拳值，以及醉拳伤害相对于生命值的百分比"
	L.PluginShortDescription_TANKSHIELD = "坦克护盾"
	L.PluginDescription_TANKSHIELD = "在一个监视条上监视坦克护盾的剩余吸收量及剩余时间"
--	L.PluginShortDescription_BURNINGEMBERS = "爆燃灰烬"
--	L.PluginDescription_BURNINGEMBERS = "显示爆燃灰烬的当前值"
--	L.PluginShortDescription_DEMONICFURY = "恶魔之怒"
--	L.PluginDescription_DEMONICFURY = "显示恶魔之怒的当前值"
	L.PluginShortDescription_RECHARGE = "充能冷却"
	L.PluginDescription_RECHARGE = "监视充能类技能的冷却状态，监视条数目为该技能最大充能数"
	L.PluginShortDescription_RECHARGEBAR = "充能冷却监视条B"
	L.PluginDescription_RECHARGEBAR = "监视充能类技能的冷却状态，只有一个监视条，显示当前充能时间"
	L.PluginShortDescription_CD = "冷却时间"
	L.PluginDescription_CD = "在一个监视条上显示法术名称及剩余冷却时间"
	L.PluginShortDescription_STATUE = "雕像/光明之泉/食尸鬼/战旗监视条"
	L.PluginDescription_STATUE = "在一个监视条上显示以下技能的剩余时间：武僧雕像、死骑食尸鬼、牧师光明之泉和战士战旗"
end