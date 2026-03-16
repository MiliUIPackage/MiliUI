------------------------------------------------------------
-- MiliUI: Stuf 預設值
-- 1. 首次安裝 + 重置預設時自動套用
-- 2. MiliUI 設定面板提供手動「匯入預設值」按鈕
-- 3. frame.x / frame.y 使用 CENTER-based 計算
------------------------------------------------------------

local floor = math.floor

-- ═══════════════════════════════════════════════════════
--  CENTER-based 偏移設定
--  全部以「畫面正中央」為原點
--  X 正值 = 往右，負值 = 往左
--  Y 正值 = 往上，負值 = 往下
-- ═══════════════════════════════════════════════════════
local PLAYER_OFFSET  = { x = -400, y = -200 }
local TARGET_OFFSET  = { x =  200, y = -200 }
local TOT_OFFSET     = { x =  410, y = -200 }   -- target + 210
local FOCUS_OFFSET   = { x =  200, y = -100 }   -- target x, player y + 100
local FOCUST_OFFSET  = { x =  325, y = -100 }   -- target + 125
local PET_OFFSET     = { x = -530, y = -200 }   -- player - 130
local ARENA_OFFSET   = { x =  500, y = 300 }   -- 競技場區域

--- 取得 TOPLEFT 座標 = 畫面中心 + 偏移
local function CX(offset)
    return floor(GetScreenWidth() / 2 + offset.x)
end
local function CY(offset)
    return -floor(GetScreenHeight() / 2) + offset.y
end

-- ═══════════════════════════════════════════════════════
--  建立預設值表（每次呼叫都重新計算解析度）
-- ═══════════════════════════════════════════════════════
function MiliUI_BuildStufDefaults()
    local playerx, playery = CX(PLAYER_OFFSET), CY(PLAYER_OFFSET)
    local targetx, targety = CX(TARGET_OFFSET), CY(TARGET_OFFSET)
    local arenax, arenay   = CX(ARENA_OFFSET),  CY(ARENA_OFFSET)

    return {
        global={
            bartexture="TukTex",
            bglist="statusbar",
            bg="TukTex",
            bgcolor={ r=0, g=0, b=0, a=0.4, },
            bgmousecolor={ r=1, g=1, b=0, a=0.6, },
            border="Blizzard Tooltip",
            borderaggrocolor={ r=1, g=0, b=0, a=0, },
            bordermousecolor={ r=1, g=1, b=0, a=0, },
            alpha=1, shortk=100000,
            classification={
                worldboss=" 首領",
                rareelite=" 稀有精英",
                elite=" 精英",
                rare=" 稀有",
                normal="",
            },
            classcolor={ },
            reactioncolor={
                [1]={ r=1, g=0, b=0, },
                [2]={ r=0.8, g=0, b=0, },
                [3]={ r=1, g=0.3, b=0, },
                [4]={ r=1, g=1, b=0, },
                [5]={ r=0.4, g=0.8, b=0.2, },
                [6]={ r=0, g=0.9, b=0, },
                [7]={ r=0, g=0.7, b=0, },
                [8]={ r=0, g=0.5, b=0, },
                [9]={ r=0.8, g=1, b=0.8, },
                [10]={ r=1, g=0.8, b=0.8, },
            },
            powercolor={
                [0]={ r=0.2, g=0.5, b=1, },
            },
            auracolor={
                Buff={ r=0, g=0, b=0, },
                MyBuff={ r=0.5, g=0.5, b=0.6 },
            },
            hpgreen={ r=0, g=0.5, b=0, a=1, },
            hpred={ r=0.5, g=0, b=0, a=1, },
            gray={ r=0.4, g=0.4, b=0.4, a=0.8, },
            hpfadecolor={ r=1, g=0.1, b=0.1, a=1, },
            mpfadecolor={ r=1, g=1, b=1, a=0.5, },
            shadowcolor={ r=0, g=0, b=0, a=0.9, },
            castcolor={ r=1, g=0.7, b=0, },
            channelcolor={ r=0, g=1, b=0, },
            completecolor={ r=1, g=1, b=0, },
            failcolor={ r=1, g=0, b=0, },
            hidepartyinraid = true,
            disableboss = true,
            disableprframes = true,
            strata="LOW",
        },
        player={
            frame={ x=playerx, y=playery, w=200, h=50, bordercolor={r=0, g=0, b=0, a=0, }, fasthp = true, },
            portrait={
                x=0, y=0, w=200, h=50, show3d=true,
                bg="TukTex", bgcolor={ r=0.165, g=0.165, b=0.165, a=1, },
                framelevel = 2,
            },
            hpbar={
                x=0, y=0, w=200, h=50,
                fade=false, vertical=nil, reverse=nil,
                barcolormethod="class", bgcolormethod="classdark", bgalpha=0.75,
                baralpha = 0.4,
                framelevel = 4,
                inc = true,
                border="Square Outline",
                bordercolor = {r=0, g=0, b=0, a=1, },
                bartexture = "TukTex",
            },
            mpbar={
                x=8, y=-8, w=200, h=50, framelevel=0,
                fade=false, vertical=nil, reverse=nil,
                barcolormethod="power", bgcolormethod="powerdark", bgalpha=1,
                bartexture = "TukTex",
                border="Square Outline",
                bordercolor = {r=0, g=0, b=0, a=1, },
            },
            text1={
                x=3, y=-3, w=200, h=50,
                pattern="[name]",
                fontsize=15, fontflags="OUTLINE", justifyH="LEFT", justifyV="TOP", shadowx=0, shadowy=0,
                framelevel=5,
            },
            text2={
                x=3, y=-21, w=140, h=12,
                pattern="[level]",
                fontsize=12, fontflags="OUTLINE",
                justifyH="LEFT", justifyV="TOP",
                shadowx=0, shadowy=0,
                framelevel=5,
            },
            text3={
                x=-42, y=-2, w=200, h=50,
                pattern="[curhp] || ",
                fontsize=10, justifyH="RIGHT", justifyV="CENTER",
                framelevel=5,
                fontcolor = {r=0.851, g=0.851, b=0.851, a=1, },
                fontflags="OUTLINE",
            },
            text4={
                x=8, y=-10, w=200, h=50,
                pattern="[curmp]/[maxmp]",
                fontsize=12, justifyH="CENTER", justifyV="BOTTOM",
                fontflags="OUTLINE",
                framelevel=11,
                fontcolor = {r=1, g=1, b=1, a=1, },
            },
            text5={
                x=10, y=-48, w=200, h=10,
                pattern="[percmp]%",
                fontsize=10, justifyH="RIGHT", justifyV="BOTTOM",
                fontflags="OUTLINE",
                framelevel=11,
            },
            text6={
                x=0, y=3, w=200, h=50,
                pattern="[gray_if_dead:\230\173\187\228\186\161][gray_if_ghost:\233\157\136\233\173\130]",
                fontsize=14, justifyH="CENTER", justifyV="BOTTOM", shadowx=0, shadowy=0,
            },
            text7={
                x=-2, y=-2, w=200, h=50,
                pattern="[perchp]%",
                framelevel=5,
                fontflags="OUTLINE",
                fontsize=13, justifyH="RIGHT", justifyV="CENTER", shadowx=0, shadowy=0,
            },
            text8={ hide=true, x=0, y=0, w=1, h=1, pattern="", fontsize=10, justifyH="CENTER", justifyV="CENTER", },
            combattext={ x=-1, y=-2, w=52, h=14, fontsize=12, justifyH="CENTER", justifyV="TOP", shadowx=-1, shadowy=-1, hide = true, },
            grouptext={
                x=5, y=-40, w=14, h=12,
                fontsize=10, justifyH="CENTER", justifyV="CENTER", shadowx=-1, shadowy=-1,
                bgcolor={ r=0, g=0, b=0, a=0.3, },
                hide = true,
            },
            buffgroup={ hide=true, x=0, y=-52, w=17, h=17, count=32, rows=2, cols=16, },
            debuffgroup={ hide=true, x=0, y=-52, w=17, h=17, count=40, rows=3, cols=16, push="v", },
            tempenchant={ hide=true, x=-17, y=-52, w=17, h=17, count=2, growth="TBLR", },
            dispellicon={ x=149, y=-4, w=42, h=42, hide = true, },
            voiceicon={ x=-7, y=7, w=16, h=16, },
            pvpicon={ x=-15, y=-12, w=28, h=28, hide=true, },
            statusicon={ x=-8, y=10, w=14, h=14, framelevel=10, },
            leadericon={ x=7, y=10, w=12, h=12, framelevel=10, },
            looticon={ x=18, y=10, w=12, h=12, framelevel=10, },
            lfgicon={ hide=true },
            raidtargeticon={ x=84, y=10, w=20, h=20, framelevel=5, },
            infoicon={ x=50, y=-37, w=12, h=12, hide = true, },
            totembar={ x=20, y=13, w=32, h=12, bgcolor={ r=0, g=0, b=0, a=0.4, }, },
            runebar={ x=8, y=0, w=38, h=6, bgcolor={ r=0, g=0, b=0, a=0.4, }, },
            druidbar={
                x=63, y=-37, w=127, h=3,
                fade=nil, vertical=nil, reverse=nil,
                barcolormethod="TukTex", bgcolormethod="TukTex", bgalpha=0.4,
                barcolor={ r=0.3, g=0.3, b=1, }, bgcolor={ r=0, g=0, b=0, },
            },
            castbar={
                hide=false, x=0, y=0, w=200, h=52, alpha=0.8,
                baralpha=1, bgcolor={ r=0, g=0, b=0, a=0.5, },
                spellx=34, spelly=-2, spellw=166, spellh=50,
                spellfontsize=12, spelljustifyH="LEFT", spelljustifyV="CENTER", spellshadowx=0, spellshadowy=0,
                spellfontcolor={ r=1, g=0.5, b=0.2, a=1, }, spellfontflags="OUTLINE",
                timex=-2, timey=-35, timew=200, timeh=12,
                timefontsize=12, timejustifyH="CENTER", timejustifyV="CENTER", timeshadowx=0, timeshadowy=0,
                timefontcolor={ r=1, g=1, b=1, a=1, }, timefontflags="OUTLINE",
                timeformat = "remaindurationdelay",
                iconx=10, icony=-17, iconw=20, iconh=20, iconalpha=1,
                framelevel = 6,
                border="None",
            },
            vehicleicon={ hide=true, },
            holybar={ x=5, y=0, framelevel=0, },
            shardbar={ x=5, y=-7, },
            chibar={ x=5, y=-2, framelevel=0, },
            arcanebar={ x=5, y=-2, },
            essencesbar={ x=5, y=-3 },
            priestbar={ x=5, y=-2, },
        },
        target={
            frame={ x=targetx, y=targety, w=200, h=50, bordercolor={r=0, g=0, b=0, a=0, }, fasthp = true, },
            portrait={
                x=0, y=0, w=200, h=50, show3d=true,
                bg="TukTex", bgcolor={ r=0.165, g=0.165, b=0.165, a=1, },
                framelevel = 2,
            },
            hpbar={
                x=0, y=0, w=200, h=50,
                vertical=nil, reverse=nil,
                bartexture = "TukTex",
                barcolormethod="classreaction", bgcolormethod="classreactiondark", bgalpha=0.75,
                baralpha = 0.4,
                framelevel = 4,
                inc = true,
                border="Square Outline",
                bordercolor = {r=0, g=0, b=0, a=1, },
            },
            mpbar={
                x=-8, y=-8, w=200, h=50,
                vertical=nil, reverse=nil, hflip=nil,
                bartexture = "TukTex",
                barcolormethod="power", bgcolormethod="powerdark", bgalpha=1,
                border="Square Outline",
                bordercolor = {r=0, g=0, b=0, a=1, },
                framelevel = 0,
            },
            text1={
                x=3, y=-3, w=200, h=50,
                pattern="[name]",
                fontsize=15, fontflags="OUTLINE", justifyH="LEFT", justifyV="TOP", shadowx=0, shadowy=0,
                framelevel=5,
            },
            text2={
                pattern="[difficulty:level][difficulty:classification]",
                x=3, y=-21, w=200, h=14,
                fontsize=12, justifyH="LEFT", justifyV="TOP", shadowx=0, shadowy=0,
                fontflags="OUTLINE",
                framelevel=5,
            },
            text3={
                x=-42, y=-2, w=200, h=50,
                pattern="[curhp] || ",
                fontsize=10, justifyH="RIGHT", justifyV="CENTER",
                framelevel=5,
                fontcolor = {r=0.851, g=0.851, b=0.851, a=1, },
                fontflags="OUTLINE",
            },
            text4={
                x=-8, y=-10, w=200, h=50,
                pattern="[curmp]/[maxmp]",
                fontsize=12, justifyH="CENTER", justifyV="BOTTOM",
                fontflags="OUTLINE",
                framelevel=11,
                fontcolor = {r=1, g=1, b=1, a=1, },
            },
            text5={
                x=0, y=-48, w=200, h=10,
                pattern="[percmp]%",
                fontsize=10, justifyH="RIGHT", justifyV="BOTTOM",
                fontflags="OUTLINE",
                framelevel=11,
            },
            text6={
                pattern="[gray_if_oor:超出距離 ][gray_if_tapped:無獎勵目標 ][gray_if_offline:離線 ][gray_if_dead:死亡 ][gray_if_ghost:鬼魂 ]",
                x=0, y=3, w=200, h=50,
                fontsize=14, justifyH="CENTER", justifyV="BOTTOM", shadowx=0, shadowy=0,
                fontflags="OUTLINE",
                framelevel=10,
            },
            text7={
                x=-2, y=-2, w=200, h=50,
                pattern="[perchp]%",
                framelevel=5,
                fontflags="OUTLINE",
                fontsize=13, justifyH="RIGHT", justifyV="CENTER", shadowx=0, shadowy=0,
            },
            text8={
                x=3, y=-16, w=195, h=50, fontsize=10, justifyH="LEFT", justifyV="CENTER",
                pattern="[class_if_pc:race][class_if_pc:class][class_if_npc:creaturetype]",
                fontcolor = {r=0.984, g=1, b=0.953, a=0.861, },
                fontflags="OUTLINE",
                framelevel=5,
            },
            combattext={ x=141, y=-2, w=52, h=14, fontsize=12, justifyH="CENTER", justifyV="TOP", shadowx=-1, shadowy=-1, hide=true, },
            grouptext={
                x=172, y=-40, w=14, h=12,
                fontsize=10, justifyH="CENTER", justifyV="CENTER", shadowx=-1, shadowy=-1,
                bgcolor={ r=0, g=0, b=0, a=0.3, },
                hide = true,
            },
            buffgroup={
                x=-10, y=-62, w=25, h=25,
                count=16, rows=2, cols=8, growth="LRTB", showpie=true,
                counttx=5, countty=-5, counttfontflags="OUTLINE", counttfontsize=10,
            },
            debuffgroup={
                x=0, y=8, w=25, h=25,
                count=16, rows=2, cols=8, growth="LRBT", showpie=true,
                counttx=5, countty=-5, counttfontflags="OUTLINE", counttfontsize=10,
            },
            auratimers={
                x=0, y=-52, w=70, h=13,
                count=12, rows=6, cols=2, growth="TBLR", push="v",
                hide = true,
            },
            dispellicon={ x=-2, y=-4, w=42, h=42, hide = true, },
            pvpicon={ x=176, y=-12, w=28, h=28, hide=true, },
            statusicon={ x=-8, y=10, w=14, h=14, framelevel=10, },
            leadericon={ x=5, y=6, w=12, h=12, framelevel=10, },
            looticon={ x=18, y=10, w=12, h=12, framelevel=10, },
            raidtargeticon={ x=84, y=10, w=20, h=20, framelevel=5, },
            infoicon={ x=50, y=-37, w=12, h=12, hide=true, },
            lfgicon={ x=-40, y=12, w=30, h=30, circular=true, framelevel=3, hide=true, },
            castbar={
                hide=false, x=0, y=0, w=200, h=52, alpha=0.8,
                baralpha=1, bgcolor={ r=0, g=0, b=0, a=0.5, },
                spellx=34, spelly=-2, spellw=166, spellh=50,
                spellfontsize=12, spelljustifyH="LEFT", spelljustifyV="CENTER", spellshadowx=0, spellshadowy=0,
                spellfontcolor={ r=1, g=0.5, b=0.2, a=1, }, spellfontflags="OUTLINE",
                timex=-2, timey=-35, timew=200, timeh=12,
                timefontsize=12, timejustifyH="CENTER", timejustifyV="CENTER", timeshadowx=0, timeshadowy=0,
                timefontcolor={ r=1, g=1, b=1, a=1, }, timefontflags="OUTLINE",
                timeformat = "remaindurationdelay",
                iconx=10, icony=-17, iconw=20, iconh=20, iconalpha=1,
                framelevel = 6,
                border="None",
            },
            comboframe={
                x=80, y=-28, w=29, h=18,
                color={ r=0.7, g=0, b=0, a=1, },
                glowcolor={ r=1, g=1, b=0, a=0.8, },
            },
            inspectbutton={ x=186, y=5, w=25, h=25, framelevel=8, },
            threatbar={ x=157, y=-2, w=32, h=12, framelevel=5, bgcolor={ r=0, g=0, b=0, a=0.4, }, },
            rangetext={ x=4, y=10, w=200, h=10, fontsize=12, justifyH="LEFT", framelevel=5, fontflags="OUTLINE", },
        },
        targettarget={
            frame={ x=targetx+210, y=targety, w=120, h=28, },
            portrait={ x=0, y=0, w=24, h=24, show3d=nil, hide=true, },
            hpbar={
                x=0, y=0, w=120, h=20,
                barcolormethod="classreaction", bgcolormethod="classreactiondark", bgalpha=0.6, baralpha=0.4,
                bartexture = "TukTex",
                border="Square Outline",
                bordercolor = {r=0, g=0, b=0, a=1, },
            },
            mpbar={
                x=0, y=-20, w=120, h=10,
                barcolormethod="power", bgcolormethod="powerdark", bgalpha=0.6, baralpha=0.4,
                bartexture = "TukTex",
                border="Square Outline",
                bordercolor = {r=0, g=0, b=0, a=1, },
            },
            text1={
                pattern="[name]",
                x=0, y=1, w=120, h=20,
                fontflags="OUTLINE",
                fontsize=12, justifyH="CENTER", justifyV="CENTER", shadowx=0, shadowy=0,
            },
            text2={
                hide=true, pattern="[level] [class:creaturetype]",
                x=37, y=-11, w=108, h=10,
                fontsize=10, justifyH="LEFT", justifyV="TOP", shadowx=-1, shadowy=-1,
            },
            text3={
                pattern="[perchp]%",
                fontflags="OUTLINE",
                x=122, y=-2, w=60, h=10,
                fontsize=12, justifyH="LEFT", justifyV="TOP",
            },
            text4={
                hide=true, pattern="[curmp]/[maxmp]",
                x=25, y=-24, w=54, h=10,
                fontsize=10, justifyH="RIGHT", justifyV="CENTER",
            },
            buffgroup={ x=0, y=-32, w=20, h=20, count=12, rows=2, cols=6, },
            debuffgroup={ x=0, y=5, w=20, h=20, count=12, rows=2, cols=6, growth = "LRBT" },
            statusicon={ hide=true, x=-6, y=-20, w=10, h=10, },
            dispellicon={ hide=true, x=54, y=-1, w=22, h=22, },
            pvpicon={ hide=true, x=-8, y=-5, w=16, h=16, },
            raidtargeticon={ hide=true, x=4, y=7, w=12, h=12, },
            infoicon={ hide=true, x=0, y=0, w=12, h=12, },
        },
        targettargettarget={
            frame={ hide=true, x=512, y=-37, w=36, h=12, },
            portrait={ x=0, y=0, w=12, h=12, },
            hpbar={ x=12, y=0, w=24, h=9, barcolormethod="hpgreen", bgcolormethod="hpgreendark", bgalpha=0.3, },
            mpbar={ x=12, y=-9, w=24, h=3, barcolormethod="power", bgcolormethod="powerdark", bgalpha=0.3, },
            text1={ hide=true, pattern="[reaction:name]", x=12, y=0, w=24, h=12, },
            text2={ pattern="[reaction:perchp]", x=12, y=0, w=24, h=12, fontsize=10, justifyH="CENTER", justifyV="CENTER", },
            text3={ hide=true, pattern="", x=0, y=0, w=10, h=10, fontsize=10, },
            text4={ hide=true, pattern="", x=0, y=0, w=10, h=10, fontsize=10, },
            raidtargeticon={ hide=true, x=4, y=4, w=8, h=8, },
            buffgroup={ hide=true, x=0, y=-12, w=6, h=6, count=6, rows=1, cols=6, },
            debuffgroup={ hide=true, x=0, y=-12, w=6, h=6, count=6, rows=1, cols=6, push="v", },
            infoicon={ hide=true, x=0, y=0, w=12, h=12, },
        },
        focus={
            frame={ x=targetx, y=playery+100, w=120, h=50, },
            portrait={ x=0, y=0, w=120, h=40, show3d=true, framelevel = 2, },
            hpbar={
                x=0, y=0, w=120, h=40,
                barcolormethod="classreaction", bgcolormethod="classreactiondark",
                bgalpha=0.6, baralpha = 0.4,
                framelevel = 5,
                bartexture = "TukTex",
                border="Square Outline",
                bordercolor = {r=0, g=0, b=0, a=1, },
            },
            mpbar={
                x=0, y=-40, w=120, h=10, barcolormethod="power", bgcolormethod="powerdark", bgalpha=1,
                bartexture = "TukTex",
                border="Square Outline",
                bordercolor = {r=0, g=0, b=0, a=1, },
                framelevel = 5,
            },
            text1={ pattern="[name]", x=0, y=-8, w=120, h=12, fontsize=12, justifyH="CENTER", justifyV="TOP", shadowx=0, shadowy=0, fontflags="OUTLINE", framelevel = 5, },
            text2={ hide=true, pattern="[level] [class:creaturetype]", x=37, y=-11, w=108, h=10, fontsize=10, justifyH="LEFT", justifyV="TOP", shadowx=-1, shadowy=-1, framelevel = 5, },
            text3={ pattern="[perchp]%", x=0, y=-25, w=120, h=10, fontsize=10, justifyH="CENTER", justifyV="CENTER", fontflags="OUTLINE", framelevel = 5, },
            text4={ hide=true, pattern="[curmp]/[maxmp]", x=25, y=-24, w=54, h=10, fontsize=10, justifyH="RIGHT", justifyV="CENTER", framelevel = 5, },
            buffgroup={ x=0, y=-50, w=12, h=12, count=10, rows=1, cols=10, growth="LRTB", },
            debuffgroup={ x=0, y=-50, w=12, h=12, count=10, rows=1, cols=10, growth="LRTB", push="v", },
            auratimers={ hide=true, x=0, y=-24, w=50, h=12, count=4, rows=4, cols=1, growth="TBLR", push="v", },
            statusicon={ hide=true, x=-6, y=-20, w=10, h=10, },
            dispellicon={ hide=true, x=57, y=-1, w=22, h=22, },
            pvpicon={ hide=true, x=-8, y=-5, w=16, h=16, },
            raidtargeticon={ hide=true, x=4, y=7, w=12, h=12, },
            infoicon={ hide=true, x=0, y=0, w=12, h=12, },
            threatbar={ hide=true, x=10, y=12, w=32, h=12, bgcolor={ r=0, g=0, b=0, a=0.4, }, },
            comboframe={ hide=true, x=0, y=-16, w=25, h=15, color={ r=0.7, g=0, b=0, a=1, }, glowcolor={ r=1, g=1, b=0, a=0.8, }, },
            castbar={
                x=0, y=0, w=120, h=40, alpha=1,
                baralpha=0, bgcolor={ r=1, g=1, b=0, a=0.8, },
                spellx=0, spelly=0, spellw=120, spellh=20,
                spellfontsize=10, spelljustifyH="LEFT", spelljustifyV="CENTER", spellshadowx=0, spellshadowy=0,
                spellfontcolor={ r=1, g=0.5, b=0.2, a=1, },
                timex=0, timey=0, timew=120, timeh=20,
                timefontsize=8, timejustifyH="RIGHT", timejustifyV="CENTER",
                timefontcolor={ r=1, g=1, b=1, a=1, },
                iconx=-20, icony=0, iconw=20, iconh=20,
                spellfontflags="OUTLINE",
                timefontflags="OUTLINE",
                framelevel=10,
            },
            rangetext={ x=0, y=12, w=120, h=10, fontsize=11, justifyH="LEFT", framelevel=6, fontflags="OUTLINE", },
        },
        focustarget={
            frame={ x=targetx+125, y=playery+100, w=70, h=50, },
            portrait={ x=0, y=0, w=12, h=12, hide=true, },
            hpbar={ x=0, y=0, w=70, h=50, barcolormethod="classreaction", bgcolormethod="classreactiondark", bgalpha=0.6, baralpha=0.4, bartexture = "TukTex", border="Square Outline", bordercolor = {r=0, g=0, b=0, a=1, }, },
            mpbar={ x=0, y=-9, w=50, h=3, hide = true, barcolormethod="power", bgcolormethod="powerdark", bgalpha=0.6, baralpha=0.4, bartexture = "TukTex", border="Square Outline", bordercolor = {r=0, g=0, b=0, a=1, }, },
            text1={ pattern="[name]", x=0, y=5, w=100, h=50, fontflags="OUTLINE", justifyH="LEFT", justifyV="TOP", },
            text2={ pattern="[perchp]%", x=0, y=0, w=70, h=50, fontsize=12, justifyH="CENTER", justifyV="CENTER", fontflags="OUTLINE", },
            text3={ hide=true, pattern="", x=0, y=0, w=10, h=10, fontsize=10, },
            text4={ hide=true, pattern="", x=0, y=0, w=10, h=10, fontsize=10, },
            raidtargeticon={ hide=true, x=-33, y=10, w=26, h=26, framelevel=6, },
            buffgroup={ hide=true, x=0, y=-12, w=6, h=6, count=6, rows=1, cols=6, },
            debuffgroup={ hide=true, x=0, y=-12, w=6, h=6, count=6, rows=1, cols=6, push="v", },
            infoicon={ hide=true, x=0, y=0, w=12, h=12, },
        },
        pet={
            frame={ x=playerx-130, y=playery, w=120, h=50, },
            portrait={ x=0, y=0, w=120, h=40, show3d=true, bg="TukTex", bgcolor={ r=0.165, g=0.165, b=0.165, a=1, }, framelevel = 2, },
            hpbar={ x=0, y=0, w=120, h=40, baralpha=0.8, barcolormethod="classreaction", bgcolormethod="classreactiondark", bgalpha=0, bartexture = "TukTex", border="Square Outline", bordercolor = {r=0, g=0, b=0, a=1, }, framelevel = 4, },
            mpbar={ x=0, y=-40, w=120, h=10, barcolormethod="class", bgcolormethod="classreactiondark", bgalpha=1, bartexture = "TukTex", border="Square Outline", bordercolor = {r=0, g=0, b=0, a=1, }, },
            text1={ pattern="[name]", x=3, y=-3, w=120, h=12, fontsize=13, justifyH="LEFT", justifyV="TOP", shadowx=-1, shadowy=-1, framelevel = 5, fontflags="OUTLINE", },
            text2={ pattern="[level] [class:creaturetype]", x=3, y=-18, w=108, h=10, fontsize=10, justifyH="LEFT", justifyV="TOP", shadowx=-1, shadowy=-1, framelevel = 5, fontflags="OUTLINE", },
            text3={ pattern="[perchp]%", x=0, y=15, w=120, h=40, fontsize=12, justifyH="RIGHT", justifyV="BOTTOM", framelevel = 5, fontflags="OUTLINE", },
            text4={ pattern="[curmp]/[maxmp]", x=0, y=0, w=120, h=50, fontsize=10, justifyH="CENTER", justifyV="BOTTOM", framelevel = 11, fontflags="OUTLINE", },
            text5={ pattern="[curhp]/[maxhp]", x=-1, y=2, w=120, h=40, fontsize=10, justifyH="RIGHT", justifyV="BOTTOM", framelevel = 5, fontflags="OUTLINE", fontcolor = {r=0.851, g=0.851, b=0.851, a=1, }, },
            text6={ pattern="[gray_if_dead:\230\173\187\228\186\161]", x=0, y=-2, w=120, h=40, fontsize=10, justifyH="CENTER", justifyV="BOTTOM", framelevel = 5, fontflags="OUTLINE", },
            combattext={ x=-1, y=1, w=40, h=12, fontsize=10, justifyH="CENTER", justifyV="TOP", hide=true, },
            buffgroup={ x=0, y=-52, w=20, h=20, count=12, rows=2, cols=6, },
            debuffgroup={ x=0, y=5, w=20, h=20, count=12, rows=2, cols=6, growth = "LRBT" },
            statusicon={ hide=true, x=-6, y=-20, w=10, h=10, },
            dispellicon={ hide=true, x=54, y=-1, w=22, h=22, },
            pvpicon={ hide=true, x=-8, y=-5, w=16, h=16, },
            raidtargeticon={ hide=true, x=4, y=7, w=12, h=12, },
            infoicon={ hide=true, x=0, y=0, w=12, h=12, },
            castbar={
                x=0, y=0, w=120, h=40, alpha=1,
                baralpha=1, bgcolor={ r=0, g=0, b=0, a=0.5, },
                spellx=34, spelly=5, spellw=120, spellh=50,
                spellfontsize=12, spelljustifyH="LEFT", spelljustifyV="CENTER", spellshadowx=0, spellshadowy=0,
                spellfontcolor={ r=1, g=0.5, b=0.2, a=1, }, spellfontflags="OUTLINE",
                timex=0, timey=-26, timew=120, timeh=12,
                timefontsize=12, timejustifyH="CENTER", timejustifyV="CENTER", timeshadowx=0, timeshadowy=0,
                timefontcolor={ r=1, g=1, b=1, a=1, }, timefontflags="OUTLINE",
                timeformat = "remaindurationdelay",
                iconx=10, icony=-11, iconw=20, iconh=20, iconalpha=1,
                framelevel = 6,
                border="None",
            },
            pettime={ x=0, y=-2, w=120, h=10, fontsize=10, shadowx=0, shadowy=0, fontflags="OUTLINE", justifyH = "RIGHT", fontcolor = {a=1, b=0.518, g=0.373, r=1}, },
        },
        party1={
            frame={ x=16, y=-30, w=250, h=30, hide=true, },
            portrait={ x=0, y=0, w=36, h=36, show3d=true, bg="Flat Smooth", bgcolor={ r=0, g=0, b=0, a=0.4, }, hide=true, },
            hpbar={ x=0, y=0, w=250, h=20, fade=nil, vertical=nil, reverse=nil, hflip=nil, barcolormethod="class", bgcolormethod="classdark", bgalpha=1, bartexture = "TukTex", border="Square Outline", bordercolor = {r=0, g=0, b=0, a=1, }, },
            mpbar={ x=0, y=-20, w=250, h=10, fade=nil, vertical=nil, reverse=nil, hflip=nil, barcolormethod="power", bgcolormethod="powerdark", bgalpha=1, bartexture = "TukTex", border="Square Outline", bordercolor = {r=0, g=0, b=0, a=1, }, },
            text1={ pattern="[name]", x=10, y=8, w=200, h=12, fontsize=12, justifyH="LEFT", justifyV="TOP", shadowx=0, shadowy=0, fontflags="OUTLINE", framelevel = 12, },
            text2={ pattern="[level]", x=12, y=-9, w=108, h=10, fontsize=10, justifyH="LEFT", justifyV="TOP", shadowx=-1, shadowy=-1, fontflags="OUTLINE", framelevel = 5, },
            text3={ pattern="[perchp]%", x=0, y=-1, w=250, h=20, fontsize=14, justifyH="RIGHT", justifyV="CENTER", fontflags="OUTLINE", framelevel = 5, },
            text4={ pattern="[curmp]/[maxmp]", x=49, y=-28, w=96, h=8, fontsize=8, justifyH="RIGHT", justifyV="CENTER", fontflags="OUTLINE", framelevel = 5, hide=true, },
            text5={ pattern="[percmp]%", x=0, y=-22, w=250, h=10, fontsize=10, justifyH="RIGHT", justifyV="BOTTOM", fontflags="OUTLINE", framelevel = 5, },
            text6={ pattern="[gray_if_oor:\232\182\133\229\135\186\232\183\157\233\155\162][gray_if_dead:\230\173\187\228\186\161][gray_if_ghost:\233\172\188\233\173\130][gray_if_offline:\233\155\162\231\183\154]", x=0, y=-15, w=250, h=10, fontsize=10, justifyH="CENTER", justifyV="CENTER", fontflags="OUTLINE", framelevel = 7, },
            combattext={ x=-1, y=1, w=40, h=12, fontsize=10, justifyH="CENTER", justifyV="TOP", hide=true, },
            buffgroup={ x=28, y=-40, w=12, h=12, count=12, rows=1, cols=12, hide=true, },
            debuffgroup={ x=147, y=-14, w=12, h=12, count=8, rows=2, cols=4, growth="TBLR", hide=true, },
            dispellicon={ x=112, y=-4, w=34, h=34, hide=true, },
            voiceicon={ x=-7, y=7, w=16, h=16, hide=true, },
            pvpicon={ x=-12, y=-9, w=23, h=23, hide=true, },
            statusicon={ x=0, y=17, w=12, h=12, framelevel = 7, },
            leadericon={ x=13, y=17, w=10, h=10, framelevel = 7, },
            looticon={ x=22, y=17, w=10, h=10, framelevel = 7, },
            raidtargeticon={ x=115, y=10, w=20, h=20, framelevel = 11, },
            infoicon={ x=37, y=-28, w=9, h=9, hide=true, },
            castbar={
                x=0, y=-30, w=250, h=10, alpha=1,
                baralpha=0, bgcolor={ r=1, g=1, b=0, a=0.8, },
                spellx=0, spelly=0, spellw=250, spellh=12,
                spellfontsize=12, spelljustifyH="CENTER", spelljustifyV="CENTER", spellshadowx=0, spellshadowy=0,
                spellfontcolor={ r=1, g=0.5, b=0.2, a=1, },
                timex=0, timey=-1, timew=250, timeh=10,
                timefontsize=10, timejustifyH="RIGHT", timejustifyV="CENTER",
                timefontcolor={ r=1, g=1, b=1, a=1, },
                iconx=0, icony=0, iconw=10, iconh=10, iconhide=false,
                bartexture="TukTex",
                spellfontflags="OUTLINE",
                timefontflags="OUTLINE",
            },
            vehicleicon={ hide=true, },
        },
        party2={ frame={ x=16, y=-90, hide=true }, },
        party3={ frame={ x=16, y=-150, hide=true }, },
        party4={ frame={ x=16, y=-210, hide=true }, },
        pettarget={
            frame={ hide=true, x=188, y=-88, w=120, h=30, },
            portrait={ x=0, y=0, w=12, h=12, hide=true, },
            hpbar={ x=0, y=0, w=120, h=20, barcolormethod="classreaction", bgcolormethod="classreactiondark", bgalpha=1, border="Square Outline", bordercolor = {r=0,g=0,b=0,a=1,}, },
            mpbar={ x=0, y=-20, w=120, h=10, barcolormethod="power", bgcolormethod="powerdark", bgalpha=1, border="Square Outline", bordercolor = {r=0,g=0,b=0,a=1,}, },
            text1={ pattern="[name]", x=4, y=-4, w=120, h=20, fontsize=12, justifyH="LEFT", justifyV="TOP", shadowx=0, shadowy=0, fontflags="OUTLINE", framelevel = 5, },
            text2={ pattern="[perchp]%", x=116, y=-4, w=50, h=12, fontsize=10, justifyH="CENTER", justifyV="CENTER", fontflags="OUTLINE", framelevel = 5, },
            text3={ hide=true, pattern="", x=0, y=0, w=10, h=10, fontsize=10, },
            text4={ hide=true, pattern="", x=0, y=0, w=10, h=10, fontsize=10, },
            raidtargeticon={ x=50, y=15, w=20, h=20, framelevel = 3, },
            buffgroup={ hide=true, x=0, y=-12, w=6, h=6, count=6, rows=1, cols=6, },
            debuffgroup={ hide=true, x=0, y=-12, w=6, h=6, count=6, rows=1, cols=6, push="v", },
            infoicon={ hide=true, x=0, y=0, w=12, h=12, },
        },
        party1target={ frame={ x=280, y=-30, hide=true, }, },
        party2target={ frame={ x=280, y=-90, hide=true, }, },
        party3target={ frame={ x=280, y=-150, hide=true, }, },
        party4target={ frame={ x=280, y=-210, hide=true, }, },
        partypet1={
            frame={ hide=true, x=7, y=-185, w=36, h=12, },
            portrait={ x=0, y=0, w=12, h=12, },
            hpbar={ x=12, y=0, w=24, h=9, barcolormethod="hpgreen", bgcolormethod="hpgreendark", bgalpha=0.3, },
            mpbar={ x=12, y=-9, w=24, h=3, barcolormethod="power", bgcolormethod="powerdark", bgalpha=0.3, },
            raidtargeticon={ hide=true, x=4, y=4, w=8, h=8, },
            text1={ hide=true, pattern="[name]", x=12, y=0, w=24, h=12, fontsize=9, justifyH="LEFT", justifyV="TOP", shadowx=-1, shadowy=-1, },
            text2={ pattern="[perchp]", x=12, y=0, w=24, h=12, fontsize=9, justifyH="CENTER", justifyV="CENTER", },
            text3={ hide=true, pattern="", x=0, y=0, w=10, h=10, fontsize=10, },
            text4={ hide=true, pattern="", x=0, y=0, w=10, h=10, fontsize=10, },
            buffgroup={ hide=true, x=0, y=-12, w=6, h=6, count=6, rows=1, cols=6, },
            debuffgroup={ hide=true, x=0, y=-12, w=6, h=6, count=6, rows=1, cols=6, push="v", },
            infoicon={ hide=true, x=0, y=0, w=12, h=12, },
        },
        partypet2={ frame={ hide=true, x=7, y=-245, }, },
        partypet3={ frame={ hide=true, x=7, y=-305, }, },
        partypet4={ frame={ hide=true, x=7, y=-365, }, },
        arena1={
            frame={ hide=true, x=arenax, y=arenay, w=78, h=24, },
            portrait={ x=0, y=0, w=24, h=24, show3d=nil, },
            hpbar={ x=24, y=-1, w=53, h=17, barcolormethod="hpgreen", bgcolormethod="hpgreendark", bgalpha=0.3, },
            mpbar={ x=24, y=-19, w=53, h=5, barcolormethod="power", bgcolormethod="powerdark", bgalpha=0.3, },
            text1={ pattern="[class:name]", x=25, y=0, w=54, h=12, fontsize=12, justifyH="LEFT", justifyV="TOP", shadowx=-1, shadowy=-1, },
            text2={ hide=true, pattern="", x=0, y=0, w=54, h=10, },
            text3={ pattern="[perchp]%", x=25, y=-13, w=54, h=10, fontsize=10, justifyH="CENTER", justifyV="CENTER", },
            text4={ hide=true, pattern="", x=0, y=0, w=54, h=10, },
            buffgroup={ x=0, y=-24, w=10, h=10, count=8, rows=1, cols=8, growth="LRTB", },
            debuffgroup={ x=0, y=-23, w=10, h=10, count=8, rows=1, cols=8, growth="LRTB", push="v", },
            infoicon={ hide=true, x=0, y=0, w=12, h=12, },
            castbar={
                x=-1, y=1, w=80, h=26, alpha=1,
                baralpha=0, bgcolor={ r=1, g=1, b=0, a=0.2, },
                spellx=0, spelly=-12, spellw=80, spellh=12,
                spellfontsize=10, spelljustifyH="CENTER", spelljustifyV="CENTER", spellshadowx=-1, spellshadowy=-1,
                spellfontcolor={ r=1, g=0.5, b=0.2, a=0.7, },
                timex=0, timey=0, timew=80, timeh=26,
                timefontsize=8, timejustifyH="CENTER", timejustifyV="CENTER",
                timefontcolor={ r=1, g=0.5, b=0.2, a=0, },
                iconx=-16, icony=0, iconw=14, iconh=14, iconalpha=0,
            },
        },
        arena2={ frame={ hide=true, x=arenax, y=arenay - 47, w=78, h=24, }, },
        arena3={ frame={ hide=true, x=arenax, y=arenay - 94, w=78, h=24, }, },
        arena4={ frame={ hide=true, x=arenax, y=arenay - 141, w=78, h=24, }, },
        arena5={ frame={ hide=true, x=arenax, y=arenay - 188, w=78, h=24, }, },
        arena1target={
            frame={ hide=true, x=arenax + 79, y=arenay, w=78, h=24, },
            portrait={ x=55, y=0, w=24, h=24, show3d=nil, },
            hpbar={ x=1, y=-1, w=53, h=17, barcolormethod="hpgreen", bgcolormethod="hpgreendark", reverse=true, bgalpha=0.3, },
            mpbar={ x=1, y=-19, w=53, h=5, barcolormethod="power", bgcolormethod="powerdark", reverse=true, bgalpha=0.3, },
            text1={ pattern="[reaction:*][class:name]", x=1, y=0, w=54, h=12, fontsize=12, justifyH="RIGHT", justifyV="TOP", shadowx=-1, shadowy=-1, },
            text2={ hide=true, pattern="", x=1, y=-11, w=108, h=10, },
            text3={ pattern="[perchp]%", x=1, y=-13, w=54, h=10, fontsize=10, justifyH="CENTER", justifyV="CENTER", },
            text4={ hide=true, pattern="", x=1, y=-24, w=54, h=10, },
            buffgroup={ hide=true, x=0, y=-24, w=10, h=10, count=8, rows=1, cols=8, growth="LRTB", },
            debuffgroup={ hide=true, x=0, y=-23, w=10, h=10, count=8, rows=1, cols=8, growth="LRTB", push="v", },
            infoicon={ hide=true, x=0, y=0, w=12, h=12, },
        },
        arena2target={ frame={ hide=true, x=arenax + 79, y=arenay - 47, w=78, h=24, }, },
        arena3target={ frame={ hide=true, x=arenax + 79, y=arenay - 94, w=78, h=24, }, },
        arena4target={ frame={ hide=true, x=arenax + 79, y=arenay - 141, w=78, h=24, }, },
        arena5target={ frame={ hide=true, x=arenax + 79, y=arenay - 188, w=78, h=24, }, },
        arenapet1={
            frame={ hide=true, x=arenax - 37, y=arenay - 12, w=36, h=12, },
            portrait={ x=24, y=0, w=12, h=12, },
            hpbar={ x=0, y=0, w=24, h=12, barcolormethod="hpgreen", bgcolormethod="hpgreendark", reverse=true, bgalpha=0.3, },
            mpbar={ hide=true, x=0, y=-9, w=24, h=3, barcolormethod="power", bgcolormethod="powerdark", bgalpha=0.3, },
            text1={ hide=true, pattern="", x=0, y=0, w=24, h=12, },
            text2={ pattern="[perchp]", x=0, y=0, w=24, h=12, fontsize=9, justifyH="CENTER", justifyV="CENTER", },
            text3={ hide=true, pattern="", x=0, y=0, w=10, h=10, fontsize=10, },
            text4={ hide=true, pattern="", x=0, y=0, w=10, h=10, fontsize=10, },
            buffgroup={ hide=true, x=0, y=-12, w=6, h=6, count=6, rows=1, cols=6, },
            debuffgroup={ hide=true, x=0, y=-12, w=6, h=6, count=6, rows=1, cols=6, push="v", },
            infoicon={ hide=true, x=0, y=0, w=12, h=12, },
        },
        arenapet2={ frame={ hide=true, x=arenax - 37, y=arenay - 59, w=78, h=24, }, },
        arenapet3={ frame={ hide=true, x=arenax - 37, y=arenay - 106, w=78, h=24, }, },
        arenapet4={ frame={ hide=true, x=arenax - 37, y=arenay - 153, w=78, h=24, }, },
        arenapet5={ frame={ hide=true, x=arenax - 37, y=arenay - 200, w=78, h=24, }, },
        boss1={
            frame={ x=arenax, y=arenay, w=120, h=10, },
            portrait={ x=0, y=0, w=24, h=24, show3d=nil, hide=true, },
            hpbar={
                x=0, y=0, w=120, h=10, barcolormethod="hpred", bgcolormethod="hpreddark", bgalpha=1,
                bartexture="TukTex",
                border="Square Outline",
                bordercolor={r=0, g=0, b=0, a=1, },
            },
            mpbar={ hide=true, x=24, y=-19, w=53, h=5, barcolormethod="power", bgcolormethod="powerdark", bgalpha=0.3, },
            text1={
                pattern="[name]", x=0, y=8, w=120, h=12,
                fontsize=12, justifyH="LEFT", justifyV="TOP", shadowx=-1, shadowy=-1,
                fontflags="OUTLINE",
                framelevel=5,
            },
            text2={ hide=true, pattern="", x=0, y=0, w=54, h=10, },
            text3={
                pattern="[perchp]%", x=-12, y=0, w=120, h=10,
                fontsize=10, justifyH="RIGHT", justifyV="CENTER",
                fontflags="OUTLINE",
                framelevel=5,
            },
            text4={ hide=true, pattern="", x=0, y=0, w=54, h=10, },
            buffgroup={
                hide=true,
                x=0, y=-24, w=10, h=10,
                count=8, rows=1, cols=8, growth="RLBT",
            },
            debuffgroup={
                hide=true,
                x=0, y=-24, w=10, h=10,
                count=8, rows=1, cols=8, growth="LRTB",
            },
            infoicon={ hide=true, x=0, y=0, w=12, h=12, },
            castbar={
                x=0, y=-10, w=120, h=10, alpha=1,
                baralpha=0, bgcolor={ r=1, g=1, b=0, a=0.8, },
                spellx=0, spelly=0, spellw=120, spellh=10,
                spellfontsize=10, spelljustifyH="CENTER", spelljustifyV="CENTER", spellshadowx=0, spellshadowy=0,
                spellfontcolor={ r=1, g=0.5, b=0.2, a=1, },
                timex=0, timey=0, timew=120, timeh=10,
                timefontsize=8, timejustifyH="RIGHT", timejustifyV="CENTER",
                timefontcolor={ r=1, g=1, b=1, a=1, },
                iconx=-10, icony=0, iconw=10, iconh=10, iconalpha=1,
                spellfontflags="OUTLINE",
                timefontflags="OUTLINE",
            },
            raidtargeticon={ x=110, y=10, w=20, h=20, },
            threatbar={ hide=true, x=10, y=12, w=32, h=12, bgcolor={ r=0, g=0, b=0, a=0.4, }, },
        },
        boss2={ frame={ x=arenax, y=arenay - 47, w=78, h=24, }, },
        boss3={ frame={ x=arenax, y=arenay - 94, w=78, h=24, }, },
        boss4={ frame={ x=arenax, y=arenay - 141, w=78, h=24, }, },
        boss5={ frame={ x=arenax, y=arenay - 188, w=78, h=24, }, },
        boss1target={
            frame={ x=arenax + 130, y=arenay, w=80, h=10, },
            portrait={ x=55, y=0, w=24, h=24, show3d=nil, hide=true, },
            hpbar={
                x=1, y=-1, w=80, h=10, barcolormethod="classreaction", bgcolormethod="classreactiondark", reverse=true, bgalpha=1,
                bartexture="TukTex",
                border="Square Outline",
                bordercolor={r=0, g=0, b=0, a=1, },
            },
            mpbar={ hide=true, x=1, y=-19, w=53, h=5, barcolormethod="power", bgcolormethod="powerdark", reverse=true, bgalpha=0.3, },
            text1={
                pattern="[name]",
                x=0, y=8, w=80, h=10,
                fontsize=12, justifyH="CENTER", justifyV="TOP", shadowx=0, shadowy=0,
                fontflags="OUTLINE",
                framelevel=5,
            },
            text2={ hide=true, pattern="", x=1, y=-11, w=108, h=10, },
            text3={
                hide=true,
                pattern="[perchp]%",
                x=1, y=-13, w=54, h=10,
                fontsize=10, justifyH="CENTER", justifyV="CENTER",
            },
            text4={ hide=true, pattern="", x=1, y=-24, w=54, h=10, },
            buffgroup={
                hide=true, x=0, y=-24, w=10, h=10,
                count=8, rows=1, cols=8, growth="LRTB",
            },
            debuffgroup={
                hide=true, x=0, y=-23, w=10, h=10,
                count=8, rows=1, cols=8, growth="LRTB", push="v",
            },
            infoicon={ hide=true, x=0, y=0, w=12, h=12, },
            raidtargeticon={ x=74, y=6, w=12, h=12, },
        },
        boss2target={ frame={ x=arenax + 130, y=arenay - 47, w=80, h=10, }, },
        boss3target={ frame={ x=arenax + 130, y=arenay - 94, w=80, h=10, }, },
        boss4target={ frame={ x=arenax + 130, y=arenay - 141, w=80, h=10, }, },
        boss5target={ frame={ x=arenax + 130, y=arenay - 188, w=80, h=10, }, },
    }
end

-- ═══════════════════════════════════════════════════════
--  解析度變更時需要重新定位的框架（不含 arena）
-- ═══════════════════════════════════════════════════════
local RESOLUTION_FRAMES = {
    "player", "target", "targettarget",
    "focus", "focustarget", "pet",
}

-- ═══════════════════════════════════════════════════════
--  (1) Hook Stuf:LoadDefaults
--  LoadDefaults 定義在 Stuf_Options（LOD），
--  必須等 Stuf_Options 載入後才能 hook。
--  觸發情境：首次安裝 / 使用者按 Stuf 重置預設
--  注意：Stuf 內部以 justboss=1 呼叫 LoadDefaults
--        初始化 boss 框架，此時不應覆寫其他設定。
-- ═══════════════════════════════════════════════════════
EventUtil.ContinueOnAddOnLoaded("Stuf_Options", function()
    local Stuf = _G["Stuf"]
    if not Stuf or not Stuf.LoadDefaults then return end

    hooksecurefunc(Stuf, "LoadDefaults", function(_, db, restore, perchar, justboss)
        -- justboss: Stuf 只在初始化 boss 框架，跳過 MiliUI 覆寫
        if justboss then return end

        local miliDefaults = MiliUI_BuildStufDefaults()
        if restore then
            local targetDB = perchar and StufCharDB or StufDB
            if targetDB then
                for unit, data in pairs(miliDefaults) do
                    if targetDB[unit] then
                        for element, values in pairs(data) do
                            if type(values) == "table" then
                                targetDB[unit][element] = CopyTable(values)
                            else
                                targetDB[unit][element] = values
                            end
                        end
                    else
                        targetDB[unit] = CopyTable(data)
                    end
                end
            end
        else
            for unit, data in pairs(miliDefaults) do
                if db[unit] then
                    for element, values in pairs(data) do
                        if type(values) == "table" then
                            db[unit][element] = CopyTable(values)
                        else
                            db[unit][element] = values
                        end
                    end
                else
                    db[unit] = CopyTable(data)
                end
            end
        end
    end)
end)

-- ═══════════════════════════════════════════════════════
--  (2) 解析度追蹤：DISPLAY_SIZE_CHANGED
--  等 Stuf 完全初始化後（PLAYER_ENTERING_WORLD + 3 秒），
--  記錄解析度並監聽變更。
-- ═══════════════════════════════════════════════════════
EventUtil.ContinueOnAddOnLoaded("Stuf", function()
    local Stuf = _G["Stuf"]
    if not Stuf then return end

    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    initFrame:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")

        C_Timer.After(3, function()
            local lastScreenW = floor(GetScreenWidth())
            local lastScreenH = floor(GetScreenHeight())

            local lastEventTime = 0
            local resizeFrame = CreateFrame("Frame")
            resizeFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
            resizeFrame:SetScript("OnEvent", function()
                lastEventTime = GetTime()
                local thisTime = lastEventTime
                C_Timer.After(0.5, function()
                    if lastEventTime ~= thisTime then return end

                    local targetDB = (StufDB == "perchar") and StufCharDB or StufDB
                    if not targetDB or type(targetDB) ~= "table" then return end

                    local oldW, oldH = lastScreenW, lastScreenH
                    local newW, newH = floor(GetScreenWidth()), floor(GetScreenHeight())
                    if oldW == newW and oldH == newH then return end

                    for _, unit in ipairs(RESOLUTION_FRAMES) do
                        local unitDB = targetDB[unit]
                        if unitDB and unitDB.frame and unitDB.frame.x and unitDB.frame.y then
                            -- 反算：TOPLEFT → CENTER offset（用舊解析度）
                            local offsetX = unitDB.frame.x - floor(oldW / 2)
                            local offsetY = unitDB.frame.y + floor(oldH / 2)
                            -- 正算：CENTER offset → TOPLEFT（用新解析度）
                            unitDB.frame.x = floor(newW / 2) + offsetX
                            unitDB.frame.y = -floor(newH / 2) + offsetY

                            -- 直接重新定位框架
                            local uf = Stuf.units[unit]
                            if uf then
                                uf:ClearAllPoints()
                                uf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", unitDB.frame.x, unitDB.frame.y)
                            end
                        end
                    end

                    lastScreenW = newW
                    lastScreenH = newH
                end)
            end)
        end)
    end)
end)
