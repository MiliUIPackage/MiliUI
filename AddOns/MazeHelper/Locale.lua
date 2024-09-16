local _, MazeHelper = ...;

local locale = GetLocale();
local convert = {
    enGB = 'enUS',
    ptPT = 'ptBR',
};
local gameLocale = convert[locale] or locale or 'enUS';

MazeHelper.currentLocale = gameLocale;

MazeHelper.L = {};
local L = MazeHelper.L;

-- https://www.wowhead.com/npc=164501/mistcaller
MazeHelper.MISTCALLER_QUOTES = {
    enUS = {
        'No fooling you!',
        'You did it! Good guess!',
        'Hooray! You\'re almost there!',
    },

    -- RainbowUI (https://www.curseforge.com/members/rainbowui)
    zhTW = {
        '瞞不過你呢！',
        '成功了！猜得好！',
        '好棒！你快到了！',
    },

    -- nanjuekaien1 (https://github.com/nanjuekaien1)
    zhCN = {
        '被你看穿了！ ',
        '你成功了！猜得真准！',
        '噢耶！你快赢了！',
    },
};

MazeHelper.MISTCALLER_QUOTES_CURRENT = MazeHelper.MISTCALLER_QUOTES[gameLocale];

-- Common
L['SOLUTION'] = '|cff33cc66%s|r';
L['ANNOUNCE_SOLUTION'] = '%s';
L['ANNOUNCE_SOLUTION_WITH_ENGLISH'] = '%s / %s';
L['MAZE_HELPER_PRINT'] = '|cffffb833Maze Helper:|r %s';

-- English announce solution
L['ENGLISH_LEAF_FULL_CIRCLE'] = 'Filled leaf in a circle';
L['ENGLISH_LEAF_FULL_NOCIRCLE'] = 'Filled leaf without a circle';
L['ENGLISH_LEAF_NOFULL_CIRCLE'] = 'Empty leaf in a circle';
L['ENGLISH_LEAF_NOFULL_NOCIRCLE'] = 'Empty leaf without a circle';
L['ENGLISH_FLOWER_FULL_CIRCLE'] = 'Filled flower in a circle';
L['ENGLISH_FLOWER_FULL_NOCIRCLE'] = 'Filled flower without a circle';
L['ENGLISH_FLOWER_NOFULL_CIRCLE'] = 'Empty flower in a circle';
L['ENGLISH_FLOWER_NOFULL_NOCIRCLE'] = 'Empty flower without a circle';

-- Default to enUS (Google Translated from Russian with some my knowledge)
L['ZONE_NAME'] = 'Mistveil Tangle';
L['MISTCALLER_NAME'] = 'Mistcaller';
L['RESET'] = 'Reset';
L['CHOOSE_SYMBOLS_4'] = 'Select 4 symbols';
L['CHOOSE_SYMBOLS_3'] = 'Select 3 more symbols';
L['CHOOSE_SYMBOLS_2'] = 'Select 2 more symbols';
L['CHOOSE_SYMBOLS_1'] = 'Select 1 more symbol';
L['SOLUTION_NA'] = '|cffffb833There is no solution|r';
L['LEAF_FULL_CIRCLE'] = 'Filled leaf in a circle';
L['LEAF_FULL_NOCIRCLE'] = 'Filled leaf without a circle';
L['LEAF_NOFULL_CIRCLE'] = 'Empty leaf in a circle';
L['LEAF_NOFULL_NOCIRCLE'] = 'Empty leaf without a circle';
L['FLOWER_FULL_CIRCLE'] = 'Filled flower in a circle';
L['FLOWER_FULL_NOCIRCLE'] = 'Filled flower without a circle';
L['FLOWER_NOFULL_CIRCLE'] = 'Empty flower in a circle';
L['FLOWER_NOFULL_NOCIRCLE'] = 'Empty flower without a circle';
L['SENDED_BY'] = 'Sended by %s';
L['CLEARED_BY'] = 'Cleared by %s';
L['PASSED'] = 'Passed';
L['RESETED_PLAYER'] = '%s |cffff0537resetted|r this mini-game';
L['PASSED_PLAYER'] = '%s clicked on «|cff66ff6ePassed|r» button';
L['SETTINGS_REVEAL_RESETTER_LABEL'] = 'Reveal resetter of the mini-game';
L['SETTINGS_REVEAL_RESETTER_TOOLTIP'] = 'Type in the chat the name of the player who did click on the «Reset» or «Passed» button (only for yourself)';
L['SETTINGS_AUTOANNOUNCER_LABEL'] = 'Enable auto announcer';
L['SETTINGS_AUTOANNOUNCER_TOOLTIP'] = 'Automatically send a ready-made solution to the group chat';
L['SETTINGS_START_IN_MINMODE_LABEL'] = 'Start in minimized mode';
L['SETTINGS_START_IN_MINMODE_TOOLTIP'] = 'The first appearance will occur in minimized mode';
L['SETTINGS_AA_PARTY_LEADER'] = 'Party leader';
L['SETTINGS_AA_ALWAYS'] = 'Always';
L['SETTINGS_AA_TANK'] = 'Tank';
L['SETTINGS_AA_HEALER'] = 'Healer';
L['SETTINGS_SHOW_AT_BOSS_LABEL'] = 'Show at Boss';
L['SETTINGS_SHOW_AT_BOSS_TOOLTIP'] = 'Show this helper when fight with «Mistcaller»';
L['SETTINGS_SYNC_ENABLED_LABEL'] = 'Group sync';
L['SETTINGS_SYNC_ENABLED_TOOLTIP'] = 'Enable syncing of symbols selections with other group members|n|n|cffff6a00It is not recommended to turn off|r';
L['SETTINGS_USE_COLORED_SYMBOLS_LABEL'] = 'Use colored symbols';
L['SETTINGS_USE_COLORED_SYMBOLS_TOOLTIP'] = 'Use colored symbols instead of black and white';
L['SETTINGS_SHOW_SEQUENCE_NUMBERS_LABEL'] = 'Show sequence numbers';
L['SETTINGS_SHOW_SEQUENCE_NUMBERS_TOOLTIP'] = 'Show sequence numbers when clicking on symbols (1, 2, 3, 4)';
L['SETTINGS_PREDICT_SOLUTION_LABEL'] = 'Predict solution';
L['SETTINGS_PREDICT_SOLUTION_TOOLTIP'] = 'Predict the solution on 2-3 steps, but |cffff6a00first|r picked symbol |cffff6a00must be|r the entrance symbol|n|nYou can temporarily disable the prediction by clicking on the first symbol with the SHIFT pressed (or by double-click)';
L['SETTINGS_SHOW_LARGE_SYMBOL_LABEL'] = 'Show large symbol';
L['SETTINGS_SHOW_LARGE_SYMBOL_TOOLTIP'] = 'Show a large symbol at the top of the screen if there is a ready-made solution|n|nRight click to close';
L['SETTINGS_SCALE_LABEL'] = 'Scale';
L['SETTINGS_SCALE_TOOLTIP'] = 'Set the scale of the main window';
L['SETTINGS_SCALE_LARGE_SYMBOL_LABEL'] = 'Scale of large symbol';
L['SETTINGS_SCALE_LARGE_SYMBOL_TOOLTIP'] = 'Set the scale of the large symbol';
L['SETTINGS_USE_CLONE_AUTOMARKER_LABEL'] = 'Auto-marker on a clone';
L['SETTINGS_USE_CLONE_AUTOMARKER_TOOLTIP'] = 'Automatically set markers on Illusionary Clones in a boss fight|n|n|cffff6a00Note: These are markers for ease of communication, not for the solution|r';
L['SETTINGS_ANNOUNCE_WITH_ENGLISH_LABEL'] = 'Duplicate solution in English';
L['SETTINGS_ANNOUNCE_WITH_ENGLISH_TOOLTIP'] = 'Send the solution to the chat along with English phrases, for example, «Empty flower without a circle / Empty flower without a circle»';
L['SETTINGS_ANNOUNCE_ONLY_ENGLISH_LABEL'] = 'Solution in English only';
L['SETTINGS_ANNOUNCE_ONLY_ENGLISH_TOOLTIP'] = 'Send the solution to the chat in English only';
L['SETTINGS_SET_MARKER_SOLUTION_PLAYER_LABEL'] = 'Set marker on player';
L['SETTINGS_SET_MARKER_SOLUTION_PLAYER_TOOLTIP'] = 'Automatically set green marker on player if he clicked on symbol that became the solution';
L['SETTINGS_ALPHA_BACKGROUND_LABEL'] = 'Background alpha';
L['SETTINGS_ALPHA_BACKGROUND_TOOLTIP'] = 'Set the alpha for the background of the main window';
L['SETTINGS_ALPHA_BACKGROUND_LARGE_SYMBOL_LABEL'] = 'Large symbol\'s background alpha';
L['SETTINGS_ALPHA_BACKGROUND_LARGE_SYMBOL_TOOLTIP'] = 'Set the alpha for the background of the large symbol';
L['PRACTICE_TITLE'] = 'Select a symbol that differs in one way from the others';
L['PRACTICE_PLAY_AGAIN'] = 'Play again';
L['PRACTICE_BUTTON_TOOLTIP'] = 'Practice';
L['MINIMAP_BUTTON_LMB'] = 'LMB';
L['MINIMAP_BUTTON_RMB'] = 'RMB';
L['MINIMAP_BUTTON_TOGGLE_MAZEHELPER'] = 'Toggle «Maze Helper» frame';
L['MINIMAP_BUTTON_HIDE'] = 'Hide minimap button';
L['MINIMAP_BUTTON_COMMAND_SHOW'] = 'Use /mh minimap to show the minimap button again';
L['SETTINGS_AUTO_PASS_LABEL'] = 'Auto pass';
L['SETTINGS_AUTO_PASS_TOOLTIP'] = 'Auto «|cff66ff6ePassed|r» on successful passage through the mists';
L['SETTINGS_BORDERS_COLORS'] = 'Borders colors';
L['SETTINGS_ACTIVE_COLORPICKER'] = 'Selected';
L['SETTINGS_RECEIVED_COLORPICKER'] = 'Received';
L['SETTINGS_SOLUTION_COLORPICKER'] = 'Solution';
L['SETTINGS_PREDICTED_COLORPICKER'] = 'Predicted';
L['SETTINGS_SKULLMARKER_CLONE_LABEL'] = 'Skull on Clone';
L['SETTINGS_SKULLMARKER_CLONE_TOOLTIP'] = 'Automatically set the skull marker |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t to the targeted Illusionary Clone';
L['SETTINGS_SKULLMARKER_USE_MODIFIER_TOOLTIP'] = 'Use modifier key';
L['SETTINGS_AUTO_TOGGLE_VISIBILITY_LABEL'] = 'Auto show/hide';
L['SETTINGS_AUTO_TOGGLE_VISIBILITY_TOOLTIP'] = 'Automatically toggle the visibility of the main window';
L['SETTINGS_AUTOANNOUNCE_CHANNEL'] = 'Chat channel';
L['SETTINGS_AUTOANNOUNCE_CHANNEL_TOOLTIP'] = 'Select the chat channel to which the solution will be sent';
L['LOCKED_DRAG_BUTTON_TOOLTIP'] = 'Dragging is locked';
L['UNLOCKED_DRAG_BUTTON_TOOLTIP'] = 'Dragging is unlocked';


-- Chinese Traditional
-- BNS333 (https://www.curseforge.com/members/bns333)
-- RainbowUI (https://www.curseforge.com/members/rainbowui)
if gameLocale == 'zhTW' then
    L['ZONE_NAME'] = '霧紗密林';
    L['MISTCALLER_NAME'] = '喚霧者';
    L['CHOOSE_SYMBOLS_1'] = '再點選一個標誌';
    L['CHOOSE_SYMBOLS_2'] = '再點選兩個標誌';
    L['CHOOSE_SYMBOLS_3'] = '再點選三個標誌';
    L['CHOOSE_SYMBOLS_4'] = '點選四個標誌';
    L['CLEARED_BY'] = '被 %s 清除了';
    L['FLOWER_FULL_CIRCLE'] = '有外環實心的花';
    L['FLOWER_FULL_NOCIRCLE'] = '無外環實心的花';
    L['FLOWER_NOFULL_CIRCLE'] = '有外環空心的花';
    L['FLOWER_NOFULL_NOCIRCLE'] = '無外環空心的花';
    L['LEAF_FULL_CIRCLE'] = '有外環實心的葉';
    L['LEAF_FULL_NOCIRCLE'] = '無外環實心的葉';
    L['LEAF_NOFULL_CIRCLE'] = '有外環空心的葉';
    L['LEAF_NOFULL_NOCIRCLE'] = '無外環空心的葉';
    L['RESETED_PLAYER'] = '%s |cffff0537已重置|r此小遊戲';
    L['PASSED'] = '已通過';
    L['PASSED_PLAYER'] = '%s 點擊了«|cff66ff6e已通過|r»按鈕';
    L['RESET'] = '重置';
    L['SENDED_BY'] = '由 %s 發送';
    L['SETTINGS_AA_ALWAYS'] = '總是';
    L['SETTINGS_AA_HEALER'] = '治療者';
    L['SETTINGS_AA_PARTY_LEADER'] = '隊長';
    L['SETTINGS_AA_TANK'] = '坦克';
    L['SETTINGS_AUTOANNOUNCER_LABEL'] = '啟用自動通報';
    L['SETTINGS_AUTOANNOUNCER_TOOLTIP'] = '自動向隊伍發送現有的解決方案';
    L['SETTINGS_REVEAL_RESETTER_LABEL'] = '揭示迷你游戲的重置者';
    L['SETTINGS_REVEAL_RESETTER_TOOLTIP'] = '在聊天中輸入有點擊過“重置”或“已通過”按鈕的玩家的名字（僅供您自己使用）';
    L['SETTINGS_SHOW_AT_BOSS_LABEL'] = '在首領戰時顯示';
    L['SETTINGS_SHOW_AT_BOSS_TOOLTIP'] = '與«喚霧者»戰鬥時顯示此助手';
    L['SETTINGS_START_IN_MINMODE_LABEL'] = '以最小化模式啟動';
    L['SETTINGS_START_IN_MINMODE_TOOLTIP'] = '首次出現將以最小化模式進行';
    L['SOLUTION_NA'] = '|cffffb833沒有解決方案|r';
    L['SETTINGS_SYNC_ENABLED_LABEL'] = '組同步';
    L['SETTINGS_SYNC_ENABLED_TOOLTIP'] = '啟用符號選擇與其他組成員的同步|n|n|cffff6a00不建議關閉|r';
    L['SETTINGS_USE_COLORED_SYMBOLS_LABEL'] = '使用彩色符號';
    L['SETTINGS_USE_COLORED_SYMBOLS_TOOLTIP'] = '使用彩色符號代替黑白';
    L['SETTINGS_SHOW_SEQUENCE_NUMBERS_LABEL'] = '顯示序列號';
    L['SETTINGS_SHOW_SEQUENCE_NUMBERS_TOOLTIP'] = '單擊符號時顯示序列號（1、2、3、4）';
    L['SETTINGS_PREDICT_SOLUTION_LABEL'] = '預測解決方案';
    L['SETTINGS_PREDICT_SOLUTION_TOOLTIP'] = '在2-3步上預測解決方案，但是|cffff6a00第一個|r選擇的符號|cffff6a00必須是|r入口符號|n|n您可以通過按住SHIFT的方式單擊第一個符號來暫時禁用預測（或雙擊）';
    L['SETTINGS_SHOW_LARGE_SYMBOL_LABEL'] = '顯示大符號';
    L['SETTINGS_SHOW_LARGE_SYMBOL_TOOLTIP'] = '如果有現成的解決方案，請在屏幕頂部顯示一個大符號|n|n右鍵單擊以關閉';
    L['SETTINGS_SCALE_LABEL'] = '規模';
    L['SETTINGS_SCALE_TOOLTIP'] = '設置主窗口的比例';
    L['SETTINGS_SCALE_LARGE_SYMBOL_LABEL'] = '大符號的比例';
    L['SETTINGS_SCALE_LARGE_SYMBOL_TOOLTIP'] = '設置大符號的比例';
    L['SETTINGS_USE_CLONE_AUTOMARKER_LABEL'] = '分身上的自動標記';
    L['SETTINGS_USE_CLONE_AUTOMARKER_TOOLTIP'] = '在老闆戰鬥中自動在幻影分身上放置標記|n|n|cffff6a00注意力！ 這些是便於溝通的標記，而不是用於解決方案|r';
    L['SETTINGS_ANNOUNCE_WITH_ENGLISH_LABEL'] = '英文重複解決方案';
    L['SETTINGS_ANNOUNCE_WITH_ENGLISH_TOOLTIP'] = '將解決方案與英語短語一起發送至聊天，例如，“無外環空心的花/Empty flower without a circle”';
    L['SETTINGS_ANNOUNCE_ONLY_ENGLISH_LABEL'] = '解決方案僅用英文';
    L['SETTINGS_ANNOUNCE_ONLY_ENGLISH_TOOLTIP'] = '僅用英語發送解決方案';
    L['SETTINGS_SET_MARKER_SOLUTION_PLAYER_LABEL'] = '在玩家上設置標記';
    L['SETTINGS_SET_MARKER_SOLUTION_PLAYER_TOOLTIP'] = '如果玩家點擊成為解決方案的標誌，則自動在他身上設置綠色標記';
    L['SETTINGS_ALPHA_BACKGROUND_LABEL'] = '背景不透明度';
    L['SETTINGS_ALPHA_BACKGROUND_TOOLTIP'] = '為主窗口的背景設置不透明度';
    L['SETTINGS_ALPHA_BACKGROUND_LARGE_SYMBOL_LABEL'] = '大符號的背景不透明度';
    L['SETTINGS_ALPHA_BACKGROUND_LARGE_SYMBOL_TOOLTIP'] = '設置大符號背景的不透明度';
    L['PRACTICE_TITLE'] = '選擇一個符號與其他符號不同的符號';
    L['PRACTICE_PLAY_AGAIN'] = '再玩一次';
    L['PRACTICE_BUTTON_TOOLTIP'] = '實踐';
    L['MINIMAP_BUTTON_LMB'] = '左鍵';
    L['MINIMAP_BUTTON_RMB'] = '右鍵';
    L['MINIMAP_BUTTON_TOGGLE_MAZEHELPER'] = '切換“Maze Helper”窗口';
    L['MINIMAP_BUTTON_HIDE'] = '隱藏小地圖按鈕';
    L['MINIMAP_BUTTON_COMMAND_SHOW'] = '使用/mh minimap再次顯示小地圖按鈕';
    L['SETTINGS_AUTO_PASS_LABEL'] = '自動通過';
    L['SETTINGS_AUTO_PASS_TOOLTIP'] = '成功通過霧氣時自動«|cff66ff6e已通過|r»';
    L['SETTINGS_BORDERS_COLORS'] = '邊框顏色';
    L['SETTINGS_ACTIVE_COLORPICKER'] = '已選';
    L['SETTINGS_RECEIVED_COLORPICKER'] = '已收到';
    L['SETTINGS_SOLUTION_COLORPICKER'] = '解決方案';
    L['SETTINGS_PREDICTED_COLORPICKER'] = '預料到的';
    L['SETTINGS_SKULLMARKER_CLONE_LABEL'] = '複製體上骷髏標記';
    L['SETTINGS_SKULLMARKER_CLONE_TOOLTIP'] = '自動將頭骨標記|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t設置為目標幻影克隆';
    L['SETTINGS_SKULLMARKER_USE_MODIFIER_TOOLTIP'] = '使用修飾鍵';
    L['SETTINGS_AUTO_TOGGLE_VISIBILITY_LABEL'] = '自動顯示/隱藏';
    L['SETTINGS_AUTO_TOGGLE_VISIBILITY_TOOLTIP'] = '自動切換主窗口的可見性';
    L['SETTINGS_AUTOANNOUNCE_CHANNEL'] = '聊天頻道';
    L['SETTINGS_AUTOANNOUNCE_CHANNEL_TOOLTIP'] = '選擇解決方案將發送到的聊天頻道';
    L['LOCKED_DRAG_BUTTON_TOOLTIP'] = '拖動被鎖定';
    L['UNLOCKED_DRAG_BUTTON_TOOLTIP'] = '拖動已解鎖';

    return;
end

-- Chinese Simplified
-- Geminil82 (https://www.curseforge.com/members/Geminil82)
-- gjfLeo (https://github.com/gjfLeo)
-- NeoS0923 (https://www.curseforge.com/members/neos0923)
if gameLocale == 'zhCN' then
    L['ZONE_NAME'] = '纱雾迷结';
    L['MISTCALLER_NAME'] = '唤雾者';
    L['CHOOSE_SYMBOLS_1'] = '再点一个标志';
    L['CHOOSE_SYMBOLS_2'] = '再点两个标志';
    L['CHOOSE_SYMBOLS_3'] = '再点三个标志';
    L['CHOOSE_SYMBOLS_4'] = '点选四个标志';
    L['CLEARED_BY'] = '被 %s 清除了';
    L['FLOWER_FULL_CIRCLE'] = '有环 实心 花';
    L['FLOWER_FULL_NOCIRCLE'] = '无环 实心 花';
    L['FLOWER_NOFULL_CIRCLE'] = '有环 空心 花';
    L['FLOWER_NOFULL_NOCIRCLE'] = '无环 空心 花';
    L['LEAF_FULL_CIRCLE'] = '有环 实心 叶';
    L['LEAF_FULL_NOCIRCLE'] = '无环 实心 叶';
    L['LEAF_NOFULL_CIRCLE'] = '有环 空心 叶';
    L['LEAF_NOFULL_NOCIRCLE'] = '无环 空心 叶';
    L['PASSED'] = '通过';
    L['PASSED_PLAYER'] = '%s 点击了«|cff66ff6e通过|r»按钮';
    L['RESET'] = '重置';
    L['RESETED_PLAYER'] = '%s |cffff0537已重置|r此小游戏';
    L['SENDED_BY'] = '由 %s 发送';
    L['SETTINGS_AA_ALWAYS'] = '总是';
    L['SETTINGS_AA_HEALER'] = '治疗者';
    L['SETTINGS_AA_PARTY_LEADER'] = '队长';
    L['SETTINGS_AA_TANK'] = '坦克';
    L['SETTINGS_AUTOANNOUNCER_LABEL'] = '启用自动通报';
    L['SETTINGS_AUTOANNOUNCER_TOOLTIP'] = '自动向群聊发送现有的答案';
    L['SETTINGS_REVEAL_RESETTER_LABEL'] = '提示迷你游戏的重置者';
    L['SETTINGS_REVEAL_RESETTER_TOOLTIP'] = '在聊天框中显示点击“重置”或“通过”按钮的玩家（仅自己可见）';
    L['SETTINGS_SHOW_AT_BOSS_LABEL'] = '首领战时显示';
    L['SETTINGS_SHOW_AT_BOSS_TOOLTIP'] = '与唤雾者战斗时显示';
    L['SETTINGS_START_IN_MINMODE_LABEL'] = '启动时最小化';
    L['SETTINGS_START_IN_MINMODE_TOOLTIP'] = '首次出现将以最小化模式运行';
    L['SETTINGS_SYNC_ENABLED_LABEL'] = '队伍同步';
    L['SETTINGS_SYNC_ENABLED_TOOLTIP'] = '启用符号选择与其他队伍成员的同步|n|n|cffff6a00不建议关闭|r';
    L['SETTINGS_USE_COLORED_SYMBOLS_LABEL'] = '使用彩色符号';
    L['SETTINGS_USE_COLORED_SYMBOLS_TOOLTIP'] = '使用彩色符号代替黑白';
    L['SOLUTION_NA'] = '|cffffb833没有答案|r';
    L['SETTINGS_SHOW_SEQUENCE_NUMBERS_LABEL'] = '显示序号';
    L['SETTINGS_SHOW_SEQUENCE_NUMBERS_TOOLTIP'] = '单击符号时显示序号(1/2/3/4)';
    L['SETTINGS_PREDICT_SOLUTION_LABEL'] = '预测答案';
    L['SETTINGS_PREDICT_SOLUTION_TOOLTIP'] = '在2-3步预测答案，但是|cffff6a00第一个|r选择的符号|cffff6a00必须是|r入口符号|n|n您可以通过按住SHIFT的方式单击第一个符号来暂时禁用预测（或双击）';
    L['SETTINGS_SHOW_LARGE_SYMBOL_LABEL'] = '显示大符号';
    L['SETTINGS_SHOW_LARGE_SYMBOL_TOOLTIP'] = '如果有现成的解决方案，请在屏幕顶部显示一个大符号|n|n右键单击以关闭';
    L['SETTINGS_SCALE_LABEL'] = '规模';
    L['SETTINGS_SCALE_TOOLTIP'] = '设置主窗口的比例';
    L['SETTINGS_SCALE_LARGE_SYMBOL_LABEL'] = '大符号的比例';
    L['SETTINGS_SCALE_LARGE_SYMBOL_TOOLTIP'] = '设置大符号的比例';
    L['SETTINGS_USE_CLONE_AUTOMARKER_LABEL'] = '克隆上的自动标记';
    L['SETTINGS_USE_CLONE_AUTOMARKER_TOOLTIP'] = '在老板战斗中自动在幻影克隆上放置标记|n|n|cffff6a00注意：这些是便于沟通的标记，不是解决方案。|r';
    L['SETTINGS_ANNOUNCE_WITH_ENGLISH_LABEL'] = '英文重复解决方案';
    L['SETTINGS_ANNOUNCE_WITH_ENGLISH_TOOLTIP'] = '将解决方案与英语短语一起发送给聊天，例如，“无环 空心 花/Empty flower without a circle”';
    L['SETTINGS_ANNOUNCE_ONLY_ENGLISH_LABEL'] = '仅有英文版本的解决方案';
    L['SETTINGS_ANNOUNCE_ONLY_ENGLISH_TOOLTIP'] = '只用英语发送聊天的解决方案';
    L['SETTINGS_SET_MARKER_SOLUTION_PLAYER_LABEL'] = '在播放器上设置标记';
    L['SETTINGS_SET_MARKER_SOLUTION_PLAYER_TOOLTIP'] = '如果他单击成为解决方案的符号，则自动在玩家上设置绿色标记';
    L['SETTINGS_ALPHA_BACKGROUND_LABEL'] = '背景不透明度';
    L['SETTINGS_ALPHA_BACKGROUND_TOOLTIP'] = '为主窗口的背景设置不透明度';
    L['SETTINGS_ALPHA_BACKGROUND_LARGE_SYMBOL_LABEL'] = '大符号的背景不透明度';
    L['SETTINGS_ALPHA_BACKGROUND_LARGE_SYMBOL_TOOLTIP'] = '设置大符号背景的不透明度';
    L['PRACTICE_TITLE'] = '选择一个符号与其他符号不同的符号';
    L['PRACTICE_PLAY_AGAIN'] = '再玩一次';
    L['PRACTICE_BUTTON_TOOLTIP'] = '实践';
    L['MINIMAP_BUTTON_LMB'] = '左键';
    L['MINIMAP_BUTTON_RMB'] = '右键';
    L['MINIMAP_BUTTON_TOGGLE_MAZEHELPER'] = '切换«Maze Helper»窗口';
    L['MINIMAP_BUTTON_HIDE'] = '隐藏小地图按钮';
    L['MINIMAP_BUTTON_COMMAND_SHOW'] = '使用/mh minimap再次显示小地图按钮';
    L['SETTINGS_AUTO_PASS_LABEL'] = '自动通过';
    L['SETTINGS_AUTO_PASS_TOOLTIP'] = '成功通过雾气时自动«|cff66ff6e通过|r»';
    L['SETTINGS_BORDERS_COLORS'] = '边框颜色';
    L['SETTINGS_ACTIVE_COLORPICKER'] = '已选';
    L['SETTINGS_RECEIVED_COLORPICKER'] = '已收到';
    L['SETTINGS_SOLUTION_COLORPICKER'] = '解决方案';
    L['SETTINGS_PREDICTED_COLORPICKER'] = '预料到的';
    L['SETTINGS_SKULLMARKER_CLONE_LABEL'] = '头骨上克隆';
    L['SETTINGS_SKULLMARKER_CLONE_TOOLTIP'] = '自动将头骨标记|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t设置为目标幻影克隆';
    L['SETTINGS_SKULLMARKER_USE_MODIFIER_TOOLTIP'] = '使用修饰键';
    L['SETTINGS_AUTO_TOGGLE_VISIBILITY_LABEL'] = '自动显示/隐藏';
    L['SETTINGS_AUTO_TOGGLE_VISIBILITY_TOOLTIP'] = '自动切换主窗口的可见性';
    L['SETTINGS_AUTOANNOUNCE_CHANNEL'] = '聊天频道';
    L['SETTINGS_AUTOANNOUNCE_CHANNEL_TOOLTIP'] = '选择解决方案将发送到的聊天频道';
    L['LOCKED_DRAG_BUTTON_TOOLTIP'] = '拖动被锁定';
    L['UNLOCKED_DRAG_BUTTON_TOOLTIP'] = '拖动已解锁';

    return;
end
