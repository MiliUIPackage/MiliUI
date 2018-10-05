if GetLocale() ~= 'zhTW' then return end
local L = OMNICC_LOCALS

L.OmniCC = "冷卻時間"

-- timer formats
L.TenthDuration = '%.1f'
L.MMSSDuration = '%d:%02d'
L.MinuteDuration = '%d分'
L.HourDuration = '%d小時'
L.DayDuration = '%dd'

-- effect names
L.None = NONE
L.Pulse = "跳動"
L.Shine = "亮光"
L.Alert = "警告"
L.Activate = "激活"
L.Flare = "閃光"

-- effect tooltips
L.ActivateTip = [[模擬快捷列按鈕上的技能"建議使用"時顯示的預設特效。]]
L.AlertTip = [[在畫面中央跳動冷卻倒數完成的圖示。]]
L.PulseTip = [[跳動冷卻倒數完成的圖示。]]

-- other
L.ConfigMissing = '無法載入 %s 因為插件 %s'
L.Version = '正在使用冷卻時間 |cffFCF75EOmniCC 版本 (%s)|r'