-- OmniCC configuration localization - English
local L = LibStub('AceLocale-3.0'):NewLocale('OmniCC', 'enUS', true)

L.Anchor = 'Anchor'
L.Anchor_BOTTOM = 'Bottom'
L.Anchor_BOTTOMLEFT = 'Bottom Left'
L.Anchor_BOTTOMRIGHT = 'Bottom Right'
L.Anchor_CENTER = 'Center'
L.Anchor_LEFT = 'Left'
L.Anchor_RIGHT = 'Right'
L.Anchor_TOP = 'Top'
L.Anchor_TOPLEFT = 'Top Left'
L.Anchor_TOPRIGHT = 'Top Right'
L.ColorAndScale = 'Color & Scale'
L.ColorAndScaleDesc = 'Adjust color and scale settings for different cooldown states'
L.CooldownText = 'Cooldown Text'
L.CreateTheme = 'Create Theme'
L.Display = DISPLAY
L.DisplayGroupDesc = 'Adjust what bits of information to display on cooldowns, and when'
L.Duration = 'Duration'
L.EnableCooldownSwipes = 'Draw cooldown swipes'
L.EnableCooldownSwipesDesc = 'Cooldown swipes are the dark background that indicates time remaining on cooldowns'
L.EnableText = 'Display cooldown text'
L.EnableTextDesc = 'Display time remaining on a cooldown'
L.FinishEffect = 'Finish Effect'
L.FinishEffectDesc = 'Adjust what effect to trigger when a cooldown ends'
L.FinishEffects = 'Finish Effects'
L.FontFace = 'Font Face'
L.FontOutline = 'Font Outline'
L.FontSize = 'Font Size'
L.HorizontalOffset = 'Horizontal Offset'
L.MinDuration = 'Minimum Cooldown Duration'
L.MinDurationDesc = 'How long, in seconds, a cooldown must be to display cooldown text.'
L.MinEffectDuration = 'Minimum Cooldown Duration'
L.MinEffectDurationDesc = 'How long a cooldown must be in order to trigger a finish effect'
L.MinSize = 'Minimum Cooldown Size'
L.MinSizeDesc =
    'How large something must be to display cooldown text. 100 is the size of a normal action button, 80 is about the size of a pet action button, and 47 is about the size of a debuff on the Blizzard target frame'
L.MMSSDuration = 'MM:SS Display Threshold'
L.MMSSDurationDesc = 'When to start displaying cooldown time remaining in MM:SS format'
L.Outline_NONE = NONE
L.Outline_OUTLINE = 'Thin'
L.Outline_OUTLINEMONOCHROME = 'Monochrome'
L.Outline_THICKOUTLINE = 'Thick'
L.Preview = PREVIEW
L.RuleAdd = 'Add Rule'
L.RuleAddDesc = 'Creates a new rule'
L.RuleEnable = ENABLE
L.RuleEnableDesc = 'Toggles this rule. If a rule is disabled, then OmniCC will skip checking it.'
L.RulePatterns = 'Patterns'
L.RulePatternsDesc =
    'The names or parts of names of UI elements that this rule should apply to. Each pattern should be entered on a separate line.'
L.RulePriority = 'Priority'
L.RulePriorityDesc =
    'Rules are evaluated ascending order. The first match is the one that will be applied to a cooldown.'
L.RuleRemove = REMOVE
L.RuleRemoveDesc = 'Removes this rule'
L.Rules = 'Rules'
L.RulesDesc =
    'Rules can be used to apply themes to specific elements of your UI. If no rules match for a particular UI element, then it will use the default theme.'
L.Rulesets = 'Rulesets'
L.RuleTheme = 'Theme'
L.RuleThemeDesc = 'What theme to apply to UI elements that match this rule'
L.ScaleText = 'Resize cooldown text to fit within frames'
L.ScaleTextDesc = 'Automatically adjust cooldown font text size based off how big the cooldown is'
L.State_charging = 'Restoring charges'
L.State_controlled = 'Lost control'
L.State_days = 'At least a day remaining'
L.State_hours = 'Hours remaining'
L.State_minutes = 'Under an hour remaining'
L.State_seconds = 'Under a minute remaining'
L.State_soon = 'Soon to expire'
L.TenthsDuration = 'Tenths of Seconds Display Threshold'
L.TenthsDurationDesc = 'When start displaying cooldown time remaining in 0.1 format'
L.TextColor = 'Text Color'
L.TextFont = 'Text Font'
L.TextPosition = 'Text Position'
L.TextShadow = 'Text Shadow'
L.TextShadowColor = COLOR
L.TextSize = 'Text Size'
L.Theme = 'Theme'
L.ThemeAdd = 'Add Theme'
L.ThemeAddDesc = 'Creates a new theme'
L.ThemeRemove = REMOVE
L.ThemeRemoveDesc = 'Removes this theme'
L.Themes = 'Themes'
L.ThemesDesc =
    "A theme is a collection of OmniCC apperance settings. Themes can be used in conjunction with rules to change OmniCC's on specific parts of your UI"
L.Typography = 'Typography'
L.TypographyDesc = 'Adjust how cooldown text looks, such as what font to use'
L.VerticalOffset = 'Vertical Offset'

L.TimerOffset = 'Timer Offset (MS)'
L.TimerOffsetDesc =
    'Subtract an amount of time from your cooldown timer text displays. You can use this, for example, to have timer text end when you are able to queue up an ability'

L.OmniCC = "OmniCC"