local _, T = ...
-- See https://www.townlong-yak.com/addons/venture-plan/localization

local C, z, V, K = GetLocale(), nil
V =
    C == "zhCN" and { -- 83/84 (98%)
      "“…或者不是。最好读到最后。”", "“第一章：法师都是近战。”", "“别被骗了！咕咕不是应急食品。”", "“一切正如预言里所说那样。”", "“结果并不如预言的那样。”", "“扭转乾坤！力挽狂澜！”", "“惜败。”", "“正如预言所说那样。”", "“有什么问题吗？”", "“走狗屎运的话可能会赢。”",
      "%d 冒险剩余...", z, "%d 位同伴已做好冒险准备。", "%d 队伍持续中...", "（近战）", "（远程）", "一份由你的伙伴完成的冒险的详细记录。", "过期时间：", "冒险报告", "所有的伙伴都准备好冒险了。",
      "指定队伍", "指定预设队伍", "即使失败也会获得奖励。", "增益最近的队友，两轮内使其造成的全部伤害提高{1}，受到的全部伤害降低{2}%。对自身造成{3}点伤害。", "正在检查健康状况...", "清除所有预设队列", "点击以完成", "伙伴生命值发生了变化。", "全部完成", "当前进度：%s",
      "结果不确定", "受诅咒的冒险指南", "受诅咒的战术指南", "使全部敌人受到负面效果，接下来的{2}轮内每次造成{1}点伤害。此效果可以多次叠加。", "对所有敌人施加负面效果，在此轮和接下来的三轮中分别造成{1}伤害。此外，受到来自最近敌人三轮内的伤害提高{2}。", "失败", "团灭", "持续：", "编辑预设队列", "每隔一轮，一个随机敌人会受到{}％最大生命值的伤害。",
      "每个伙伴可从此失败的任务中获取%s经验。", "在第%d轮时先发", "伙伴经验", "考虑的可能性：", "为最近的盟友恢复{1}生命值，并使其受到的伤害增加{2}%，持续两轮。", "在预设队伍 - %s", "受到的攻击：", "对一个随机敌人造成{}的伤害。", "对所有远程敌人造成{}伤害。", "在近战中对所有敌人造成{}伤害，并在三轮内增加20%的自身伤害。",
      "心能不足", "没什么效果。", "没有考虑到所有的技能。", "未检验全部结果。", "预估：", "数量：%s", "所有敌人下轮造成的伤害降低{}%。", "所有敌人两轮内造成的伤害减少{}%。", "使最近盟友两轮受到的伤害降低5000%。", "敌人剩余生命值：%s",
      "小队中需要一名伙伴", "即将返回：", "奖励：", "选择伙伴", "派遣预设队伍", "开始冒险", "即将开始…", "目标：", "预设队伍可以更改直到点击%s。", "预设派遣这些新手参加这次冒险。",
      "插件版本可能已过期。", "指南展示了一系列可能的结果，既有胜利，也有可怕的失败。", "伙伴等级会影响你的部队等级。", "持续轮数：", "存活轮数：%s", "需要轮数：%s", "使用：打断指南的思考", "使用：让这本书选择阵型和战术", "用法：阅读指南，然后决定你的冒险小队的命运。", "胜利",
      "不保证一定胜利", "如果开始的话会赢得: %s", "你的部队等级是你伙伴等级中位数的向下取整数值(%s)，四舍五入。招募其他同伴时不会降低。", "[冷却时间：%d轮]",
    }
    or C == "zhTW" and { -- 84/84 (100%)
      "“…或者不是。最好讀到最後。”", "\"第一章：法師必須近戰。\"", "不要相信這個謊話！平衡德不是應急口糧。", "\"一切都如預期。\"", "\"不如預期。\"", "\"扭轉乾坤！反敗為勝！\"", "\"眼看勝利就在眼前，可惜。\"", "\"結果如同預期。\"", "\"有什麼疑問嗎？\"", "\"看你的運氣囉\"",
      "%d個冒險尚待完成...", "%d個夥伴已經在分派隊伍中。", "%d個夥伴已經準備好冒險。", "%d個隊伍尚待處理...", "(近戰)", "(遠程)", "詳細戰鬥紀錄", "冒險過期還有:", "冒險報告", "所有同伴都準備好出發冒險了。",
      "指派隊伍", "指派暫定隊伍", "即使冒險失敗仍會獲得獎勵", "使最接近的盟友造成的傷害提高{1}，持續兩回合。 使最近的盟友受到的傷害降低{2}％，持續兩回合。 對自身造成{3}傷害。", "血量恢復後檢查...", "清除所有隊伍分派", "點擊完成", "夥伴生命值已經改變。", "全部完成", "目前進度:%s",
      "結果不明確", "被詛咒的冒險者指南", "被詛咒的戰術指南", "使全部敵人受到減益效果，接下來的{2}回合內每次造成{1}點傷害。此效果可以多次疊加。", "給所有敵人減益，並在接下來的三個回合中，每回合造成{1}點傷害。 使最近的敵人受到的所有傷害提高{2}，持續三回合。", "失敗", "自殺式出擊\r\n", "持續時間", "編輯隊伍", "每隔一個回合，一個隨機敵人會受到{}％最大血量的傷害",
      "任務失敗使每個夥伴獲得%s經驗值", "在%d回合第一次施放", "追隨者經驗值", "審慮過的可能性:", "治療最近的盟友{1}。 使最近的盟友承受的所有傷害提高{2}％，持續兩回合。", "在分派隊伍中: %s", "受到攻擊：", "對隨機敵人造成{}傷害", "對遠距離的所有敵人造成{}傷害。", "在近戰中對所有敵人造成{}傷害，並在三回合內增加20%的自身傷害。",
      "靈魄不足", "無效", "並非所有技能都被計算。", "並非所有結果都經過審查。", "預估:", "數量：%s", "使所有敵人的傷害降低{}％，持續到下一回合。", "使所有敵人的傷害降低{}％，持續兩回合。", "使最近的盟友減傷5000%，持續兩回合。", "敵方剩餘血量：%s",
      "需要有夥伴在隊伍中", "即將返回:", "獎勵：", "選擇冒險者", "派發分配隊伍", "開始冒險", "即將開始…", "目標：", "暫定隊伍直到您點擊 %s 前可被更改。", "暫時將這些菜鳥分配給這次冒險。",
      "此指南可能已經過期。", "本指南提供你幾個可能的結果。其中一些冒險會凱旋歸來；其他的則會是可怕的失敗。", "這些追隨者目前會影響你的部隊等級:", "技能回合", "存活回合：%s", "需要回合：%s", "使用: 中斷指南的審慮。", "使用: 讓本書選擇部隊和陣型。", "使用：閱讀本指南，決定你的冒險隊伍的命運。", "勝利",
      "無法保證勝利。", "如果開始於: %s 將會獲勝", "您的部隊等級是追隨者等級的中位數(%s)取整數。", "[冷卻:%d 回合]",
    } or nil

K = V and {
      "\"... or not. Better read this thing to the end.\"", "\"Chapter 1: Mages Must Melee.\"", "\"Do not believe its lies! Balance druids are not emergency rations.\"", "\"Everything went as foretold.\"", "\"Nothing went as expected.\"", "\"Snatch victory from the jaws of defeat!\"", "\"So close, and yet so far.\"", "\"The outcome was as foretold.\"", "\"Was there ever any doubt?\"", "\"With your luck, there is only one way this ends.\"",
      "%d |4adventure:adventures; remaining...", "%d |4companion is:companions are; in a tentative party.", "%d |4companion is:companions are; ready for adventures.", "%d |4party:parties; remaining...", "(melee)", "(ranged)", "A detailed record of an adventure completed by your companions.", "Adventure Expires In:", "Adventure Report", "All companions are ready for adventures.",
      "Assign Party", "Assign Tentative Party", "Awarded even if the adventurers are defeated.", "Buffs the closest ally, increasing all damage dealt by {1} and reducing all damage taken by {2}% for two turns. Inflicts {3} damage to self.", "Checking health recovery...", "Clear all tentative parties", "Click to complete", "Companion health has changed.", "Complete All", "Current Progress: %s",
      "Curse of Uncertainty", "Cursed Adventurer's Guide", "Cursed Tactical Guide", "Debuffs all enemies, dealing {1} damage during each of the next {2} turns. Multiple applications of this effect overlap.", "Debuffs all enemies, dealing {1} damage this turn and during each of the next three turns. Additionally, increases all damage taken by the nearest enemy by {2} for three turns.", "Defeated", "Doomed Run", "Duration:", "Edit party", "Every other turn, a random enemy is attacked for {}% of their maximum health.",
      "Failing this mission grants %s to each companion.", "First cast during turn %d.", "Follower XP", "Futures considered:", "Heals the closest ally for {1}, and increases all damage taken by the ally by {2}% for two turns.", "In Tentative Party - %s", "Incoming attacks:", "Inflicts {} damage to a random enemy.", "Inflicts {} damage to all enemies at range.", "Inflicts {} damage to all enemies in melee, and increases own damage dealt by 20% for three turns.",
      "Insufficient anima", "It does nothing.", "Not all abilities have been taken into account.", "Not all outcomes have been examined.", "Preliminary:", "Quantity: %s", "Reduces all enemies' damage dealt by {}% during the next turn.", "Reduces all enemies' damage dealt by {}% for two turns.", "Reduces the damage taken by the closest ally by 5000% for two turns.", "Remaining enemy health: %s",
      "Requires a companion in the party", "Returning soon:", "Rewards:", "Select adventurers", "Send Tentative Parties", "Start the adventure", "Starting soon...", "Targets:", "Tentative parties can be changed until you click %s.", "Tentatively assign these rookies to this adventure.",
      "The Guide may be out of date.", "The guide shows you a number of possible futures. In some, the adventure ends in triumph; in others, a particularly horrible failure.", "These companions currently affect your troop level:", "Ticks:", "Turns survived: %s", "Turns taken: %s", "Use: Interrupt the guide's deliberations.", "Use: Let the book select troops and battle tactics.", "Use: Read the guide, determining the fate of your adventuring party.", "Victorious",
      "Victory could not be guaranteed.", "Would win if started in: %s", "Your troop level is the median level of your companions (%s), rounded down. It does not decrease when you recruit additional companions.", "[CD: %dT]",
}

local L = K and {}
for i=1,K and #K or 0 do
	L[K[i]] = V[i]
end

T.LT = L or nil
