-- 真實的 12.1.5 zhTW 提示資料（/mtip record 2026-10-18 抓的，Tests/fixtures/export 產生，不要手改）
-- 每筆：kind、tip、locale、numLines（FontString 行數）、data（TooltipData 整張，lines[].type 是 Enum 數字，typeName 是對照名）、
-- lines（post-call 當下 1..numLines 的 FontString 文字與顏色；lineIndex 不在 data 裡的就是別家後加的行）
return {
{
    data = {
      dataInstanceID = 4791,
      hyperlink = "|cnIQ2:|Hitem:262452::::::::90:70:::1:3524::::::|h[精工製作之錘]|h|r",
      id = 262452,
      isAzeriteEmpoweredItem = false,
      isAzeriteItem = false,
      isCorruptedItem = false,
      lines = {
        [1] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0.1176470667123795
          },
          leftText = "精工製作之錘",
          lineIndex = 1,
          quality = 2,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "|A:House-Decor-budget-icon:21:21|a1",
          type = 22,
          typeName = "ItemName"
        },
        [2] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "|cFF66BBFF房屋裝飾|r",
          lineIndex = 2,
          type = 0,
          typeName = "None"
        },
        [3] = {
          bonding = 8,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "使用後綁定",
          lineIndex = 3,
          type = 20,
          typeName = "ItemBinding"
        },
        [4] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "首次收藏加成：|cnHIGHLIGHT_FONT_COLOR:+10點房屋經驗值|r",
          lineIndex = 4,
          type = 0,
          typeName = "None"
        }
      },
      overrideItemLevel = 1,
      type = 0
    },
    kind = "item",
    lines = {
      [1] = {
        left = {
          color = {
            [1] = 0.1176470667123795,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|T7479466:16:16:0:0:32:32:2:30:2:30|t 精工製作之錘"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|A:House-Decor-budget-icon:21:21|a1"
        }
      },
      [2] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|cFF66BBFF房屋裝飾|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [3] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "使用後綁定"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [4] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "首次收藏加成：|cnHIGHLIGHT_FONT_COLOR:+10點房屋經驗值|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [5] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "拍賣"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff2000 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
        }
      },
      [6] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "拍賣日期"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff0 天|r"
        }
      },
      [7] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = " "
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [8] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.81960791349411011,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "資料片: |cffffffff至暗之夜 (12.0)|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      }
    },
    locale = "zhTW",
    numLines = 8,
    source = 53,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 4795,
      hyperlink = "|cnIQ2:|Hitem:262452::::::::90:70:::1:3524::::::|h[精工製作之錘]|h|r",
      id = 262452,
      isAzeriteEmpoweredItem = false,
      isAzeriteItem = false,
      isCorruptedItem = false,
      lines = {
        [1] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0.1176470667123795
          },
          leftText = "精工製作之錘",
          lineIndex = 1,
          quality = 2,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "|A:House-Decor-budget-icon:21:21|a1",
          type = 22,
          typeName = "ItemName"
        },
        [2] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "|cFF66BBFF房屋裝飾|r",
          lineIndex = 2,
          type = 0,
          typeName = "None"
        },
        [3] = {
          bonding = 8,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "使用後綁定",
          lineIndex = 3,
          type = 20,
          typeName = "ItemBinding"
        },
        [4] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "首次收藏加成：|cnHIGHLIGHT_FONT_COLOR:+10點房屋經驗值|r",
          lineIndex = 4,
          type = 0,
          typeName = "None"
        },
        [5] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "使用： 將此裝飾加入你的房屋箱子。",
          lineIndex = 5,
          spellID = 1268845,
          type = 44,
          typeName = "ItemSpellTriggerOnUse",
          wrapText = true
        }
      },
      overrideItemLevel = 1,
      type = 0
    },
    kind = "item",
    lines = {
      [1] = {
        left = {
          color = {
            [1] = 0.1176470667123795,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|T7479466:16:16:0:0:32:32:2:30:2:30|t 精工製作之錘"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|A:House-Decor-budget-icon:21:21|a1"
        }
      },
      [2] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|cFF66BBFF房屋裝飾|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [3] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "使用後綁定"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [4] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "首次收藏加成：|cnHIGHLIGHT_FONT_COLOR:+10點房屋經驗值|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [5] = {
        left = {
          color = {
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "使用： 將此裝飾加入你的房屋箱子。"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [6] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "拍賣"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff2000 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
        }
      },
      [7] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "拍賣日期"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff0 天|r"
        }
      },
      [8] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = " "
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [9] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.81960791349411011,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "資料片: |cffffffff至暗之夜 (12.0)|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      }
    },
    locale = "zhTW",
    numLines = 9,
    source = 54,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 4835,
      hyperlink = "|cnIQ2:|Hitem:262452::::::::90:70:::1:3524::::::|h[精工製作之錘]|h|r",
      id = 262452,
      isAzeriteEmpoweredItem = false,
      isAzeriteItem = false,
      isCorruptedItem = false,
      lines = {
        [1] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0.1176470667123795
          },
          leftText = "精工製作之錘",
          lineIndex = 1,
          quality = 2,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "|A:House-Decor-budget-icon:21:21|a1",
          type = 22,
          typeName = "ItemName"
        },
        [2] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "|cFF66BBFF房屋裝飾|r",
          lineIndex = 2,
          type = 0,
          typeName = "None"
        },
        [3] = {
          bonding = 8,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "使用後綁定",
          lineIndex = 3,
          type = 20,
          typeName = "ItemBinding"
        },
        [4] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "首次收藏加成：|cnHIGHLIGHT_FONT_COLOR:+10點房屋經驗值|r",
          lineIndex = 4,
          type = 0,
          typeName = "None"
        },
        [5] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "使用： 將此裝飾加入你的房屋箱子。",
          lineIndex = 5,
          spellID = 1268845,
          type = 44,
          typeName = "ItemSpellTriggerOnUse",
          wrapText = true
        }
      },
      overrideItemLevel = 1,
      type = 0
    },
    kind = "item",
    lines = {
      [1] = {
        left = {
          color = {
            [1] = 0.1176470667123795,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|T7479466:16:16:0:0:32:32:2:30:2:30|t 精工製作之錘"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|A:House-Decor-budget-icon:21:21|a1"
        }
      },
      [2] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|cFF66BBFF房屋裝飾|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [3] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "使用後綁定"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [4] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "首次收藏加成：|cnHIGHLIGHT_FONT_COLOR:+10點房屋經驗值|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [5] = {
        left = {
          color = {
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "使用： 將此裝飾加入你的房屋箱子。"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [6] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "拍賣|cff87abff x1|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff2000 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
        }
      },
      [7] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "拍賣日期"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff0 天|r"
        }
      },
      [8] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = " "
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [9] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.81960791349411011,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "資料片: |cffffffff至暗之夜 (12.0)|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [10] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.81960791349411011,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "物品 ID: |cffffffff262452|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [11] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.81960791349411011,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "圖示 ID: |cffffffff7479466|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      }
    },
    locale = "zhTW",
    numLines = 11,
    source = 55,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 4683,
      hyperlink = "|cnIQ1:|Hitem:77589::::::::90:70:::1:3524::::::|h[G91陸鯊]|h|r",
      id = 77589,
      isAzeriteEmpoweredItem = false,
      isAzeriteItem = false,
      isCorruptedItem = false,
      lines = {
        [1] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "G91陸鯊",
          lineIndex = 1,
          quality = 1,
          type = 22,
          typeName = "ItemName"
        },
        [2] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "需要等級32",
          level = 32,
          lineIndex = 2,
          requirementType = 5,
          type = 43,
          typeName = "UsageRequirement",
          usable = true
        },
        [3] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "",
          lineIndex = 2,
          maxPrice = -1,
          price = 2500,
          type = 11,
          typeName = "SellPrice"
        }
      },
      overrideItemLevel = 15,
      type = 0
    },
    kind = "item",
    lines = {
      [1] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|T622095:16:16:0:0:32:32:2:30:2:30|t G91陸鯊"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [2] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "需要等級32"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [3] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "售價: 25|A:coin-silver:14:14:2:0|a"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [4] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "商人"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff25 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
        }
      },
      [5] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "拍賣"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff7 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 38 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
        }
      },
      [6] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "拍賣日期"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff0 天|r"
        }
      },
      [7] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "庫存"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff總計：|cffffffff18|r|r"
        }
      },
      [8] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "  |A:raceicon128-bloodelf-male:13:13|a |cfff48cba角色1|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff銀行：|cffffffff18|r|r"
        }
      },
      [9] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = " "
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [10] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.81960791349411011,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "資料片: |cffffffff潘達利亞之謎 (5.0)|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [11] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.81960791349411011,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "堆疊上限: |cffffffff20|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      }
    },
    locale = "zhTW",
    numLines = 11,
    source = 41,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 4686,
      hyperlink = "|cnIQ1:|Hitem:77589::::::::90:70:::1:3524::::::|h[G91陸鯊]|h|r",
      id = 77589,
      isAzeriteEmpoweredItem = false,
      isAzeriteItem = false,
      isCorruptedItem = false,
      lines = {
        [1] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "G91陸鯊",
          lineIndex = 1,
          quality = 1,
          type = 22,
          typeName = "ItemName"
        },
        [2] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "使用： 對45碼內的一名敵人及其附近10碼範圍內的任何敵人造成1點火焰傷害。 （1分鐘冷卻時間）",
          lineIndex = 2,
          spellID = 124199,
          type = 44,
          typeName = "ItemSpellTriggerOnUse",
          wrapText = true
        },
        [3] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "需要等級32",
          level = 32,
          lineIndex = 3,
          requirementType = 5,
          type = 43,
          typeName = "UsageRequirement",
          usable = true
        },
        [4] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "",
          lineIndex = 3,
          maxPrice = -1,
          price = 2500,
          type = 11,
          typeName = "SellPrice"
        }
      },
      overrideItemLevel = 15,
      type = 0
    },
    kind = "item",
    lines = {
      [1] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|T622095:16:16:0:0:32:32:2:30:2:30|t G91陸鯊"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [2] = {
        left = {
          color = {
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "使用： 對45碼內的一名敵人及其附近10碼範圍內的任何敵人造成1點火焰傷害。 （1分鐘冷卻時間）"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [3] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "需要等級32"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [4] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "售價: 25|A:coin-silver:14:14:2:0|a"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [5] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "商人"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff25 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
        }
      },
      [6] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "拍賣"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff7 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 38 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
        }
      },
      [7] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "拍賣日期"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff0 天|r"
        }
      },
      [8] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "庫存"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff總計：|cffffffff18|r|r"
        }
      },
      [9] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "  |A:raceicon128-bloodelf-male:13:13|a |cfff48cba角色1|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff銀行：|cffffffff18|r|r"
        }
      },
      [10] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = " "
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [11] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.81960791349411011,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "資料片: |cffffffff潘達利亞之謎 (5.0)|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [12] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.81960791349411011,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "堆疊上限: |cffffffff20|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      }
    },
    locale = "zhTW",
    numLines = 12,
    source = 42,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 4420,
      id = 96231,
      lines = {
        [1] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "近戰範圍",
          lineIndex = 4,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "",
          type = 0,
          typeName = "None"
        },
        [2] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "立即",
          lineIndex = 5,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "冷卻時間15秒",
          type = 0,
          typeName = "None"
        },
        [3] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "中斷目標的施法，並使其在5秒內無法施放同系的法術。",
          lineIndex = 6,
          type = 34,
          typeName = "SpellDescription",
          wrapText = true
        }
      },
      type = 1
    },
    kind = "spell",
    lines = {
      [1] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|T523893:16:16:0:0:32:32:2:30:2:30|t 責難"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [2] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "等級|cffffffff1|r/1"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [3] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = " "
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [4] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "近戰範圍"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [5] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "立即"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "冷卻時間15秒"
        }
      },
      [6] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "中斷目標的施法，並使其在5秒內無法施放同系的法術。"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      }
    },
    locale = "zhTW",
    numLines = 6,
    source = 26,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 4425,
      id = 204054,
      lines = {
        [1] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "",
          lineIndex = 3,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "",
          type = 0,
          typeName = "None"
        },
        [2] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "被動",
          lineIndex = 4,
          type = 33,
          typeName = "SpellPassive"
        },
        [3] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "你的奉獻效果範圍提高15%，且範圍內的敵人移動速度降低50%。",
          lineIndex = 5,
          type = 34,
          typeName = "SpellDescription",
          wrapText = true
        }
      },
      type = 1
    },
    kind = "spell",
    lines = {
      [1] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|T236260:16:16:0:0:32:32:2:30:2:30|t 神聖之地"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [2] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "等級|cffffffff1|r/1"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [3] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = " "
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [4] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "被動"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [5] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "你的奉獻效果範圍提高15%，且範圍內的敵人移動速度降低50%。"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      }
    },
    locale = "zhTW",
    numLines = 5,
    source = 28,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 4418,
      id = 10326,
      lines = {
        [1] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "5250法力",
          lineIndex = 4,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "20碼距離",
          type = 0,
          typeName = "None"
        },
        [2] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "施法時間1.3秒",
          lineIndex = 5,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "冷卻時間15秒",
          type = 0,
          typeName = "None"
        },
        [3] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "聖光的力量迫使一名指定的不死生物、變異怪或惡魔逃跑，最多40秒。任何傷害都會中斷此效果。弱小的生物有一定機率直接遭到毀滅。同一時間只能作用於一個目標。",
          lineIndex = 6,
          type = 34,
          typeName = "SpellDescription",
          wrapText = true
        }
      },
      type = 1
    },
    kind = "spell",
    lines = {
      [1] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|T571559:16:16:0:0:32:32:2:30:2:30|t 退邪術"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [2] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "等級|cffffffff0|r/1"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [3] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = " "
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [4] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "5250法力"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "20碼距離"
        }
      },
      [5] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "施法時間1.3秒"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "冷卻時間15秒"
        }
      },
      [6] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "聖光的力量迫使一名指定的不死生物、變異怪或惡魔逃跑，最多40秒。任何傷害都會中斷此效果。弱小的生物有一定機率直接遭到毀滅。同一時間只能作用於一個目標。"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      }
    },
    locale = "zhTW",
    numLines = 6,
    source = 24,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 4395,
      id = 31884,
      lines = {
        [1] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "復仇之怒",
          lineIndex = 1,
          rightColor = {
            b = 0.501960813999176,
            g = 0.501960813999176,
            r = 0.501960813999176
          },
          rightText = "",
          type = 13,
          typeName = "SpellName"
        },
        [2] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "",
          lineIndex = 1,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "",
          type = 0,
          typeName = "None"
        },
        [3] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "立即",
          lineIndex = 2,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "冷卻時間1分鐘",
          type = 0,
          typeName = "None"
        },
        [4] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "呼喚聖光以成為懲戒的化身，使你的傷害、治療效果和致命一擊機率提高15%，加速提高3%，持續24秒。\13\
\13\
消耗的每道聖能都會使加速額外提高2%，最多提高20%。",
          lineIndex = 3,
          type = 34,
          typeName = "SpellDescription",
          wrapText = true
        },
        [5] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 4,
          type = 1,
          typeName = "Blank"
        },
        [6] = {
          leftColor = {
            b = 1,
            g = 0.83529418706893921,
            r = 0.44313728809356689
          },
          leftText = "復仇展翅雕紋",
          lineIndex = 5,
          type = 0,
          typeName = "None"
        },
        [7] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "神聖、懲戒",
          lineIndex = 6,
          type = 0,
          typeName = "None"
        },
        [8] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "使你施放復仇之怒時顯現的翅膀變成四翼。",
          lineIndex = 7,
          type = 0,
          typeName = "None",
          wrapText = true
        }
      },
      type = 1
    },
    kind = "spell",
    lines = {
      [1] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|T135875:16:16:0:0:32:32:2:30:2:30|t 復仇之怒"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [2] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "立即"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "冷卻時間1分鐘"
        }
      },
      [3] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "呼喚聖光以成為懲戒的化身，使你的傷害、治療效果和致命一擊機率提高15%，加速提高3%，持續24秒。\13\
\13\
消耗的每道聖能都會使加速額外提高2%，最多提高20%。"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [4] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = " "
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [5] = {
        left = {
          color = {
            [1] = 0.44313728809356689,
            [2] = 0.83529418706893921,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "復仇展翅雕紋"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [6] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "神聖、懲戒"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [7] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "使你施放復仇之怒時顯現的翅膀變成四翼。"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      }
    },
    locale = "zhTW",
    numLines = 7,
    source = 10,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 4623,
      id = 2259,
      lines = {
        [1] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "鍊金術",
          lineIndex = 1,
          rightColor = {
            b = 0.501960813999176,
            g = 0.501960813999176,
            r = 0.501960813999176
          },
          rightText = "",
          type = 13,
          typeName = "SpellName"
        },
        [2] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "",
          lineIndex = 1,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "",
          type = 0,
          typeName = "None"
        },
        [3] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "使鍊金師可以配製初級的藥水。需要由草藥學採集的草藥。\13\
\13\
|CFFFFFFFF特殊能力：混金術|R\13\
每當你喝下自己能製作的藥劑或精煉藥劑時，獲得的效果與持續時間將提升。",
          lineIndex = 2,
          type = 34,
          typeName = "SpellDescription",
          wrapText = true
        }
      },
      type = 1
    },
    kind = "spell",
    lines = {
      [1] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|T4620669:16:16:0:0:32:32:2:30:2:30|t 鍊金術"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [2] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "使鍊金師可以配製初級的藥水。需要由草藥學採集的草藥。\13\
\13\
|CFFFFFFFF特殊能力：混金術|R\13\
每當你喝下自己能製作的藥劑或精煉藥劑時，獲得的效果與持續時間將提升。"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      }
    },
    locale = "zhTW",
    numLines = 2,
    source = 29,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 4652,
      guid = "Item-966-0-4000000B1BAE9C4B",
      id = 271465,
      isAzeriteEmpoweredItem = false,
      isAzeriteItem = false,
      isCorruptedItem = false,
      lines = {
        [1] = {
          leftColor = {
            b = 0.93333339691162109,
            g = 0.207843154668808,
            r = 0.63921570777893066
          },
          leftText = "聖化烈焰戰盔",
          lineIndex = 1,
          quality = 4,
          type = 22,
          typeName = "ItemName"
        },
        [2] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "|cFF 0FF 0英雄難度|r",
          lineIndex = 2,
          type = 0,
          typeName = "None"
        },
        [3] = {
          itemLevel = 334,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "物品等級334",
          lineIndex = 3,
          type = 31,
          typeName = "ItemLevel"
        },
        [4] = {
          currentLevel = 6,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "提升等級：神話 6/6",
          lineIndex = 4,
          maxLevel = 6,
          trackStringID = 978,
          type = 32,
          typeName = "ItemUpgradeLevel"
        },
        [5] = {
          bonding = 3,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "靈魂綁定",
          lineIndex = 5,
          type = 20,
          typeName = "ItemBinding"
        },
        [6] = {
          isValidInvSlot = true,
          isValidItemType = true,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "頭部",
          lineIndex = 6,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "鎧甲",
          type = 21,
          typeName = "EquipSlot"
        },
        [7] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "326點護甲",
          lineIndex = 7,
          type = 0,
          typeName = "None"
        },
        [8] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "+189力量",
          lineIndex = 8,
          type = 0,
          typeName = "None"
        },
        [9] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "+3910耐力",
          lineIndex = 9,
          type = 0,
          typeName = "None"
        },
        [10] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "+141致命一擊",
          lineIndex = 10,
          type = 0,
          typeName = "None"
        },
        [11] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "+60精通",
          lineIndex = 11,
          type = 0,
          typeName = "None"
        },
        [12] = {
          leftColor = {
            b = 0.501960813999176,
            g = 0.501960813999176,
            r = 0.501960813999176
          },
          leftText = "+189智力",
          lineIndex = 12,
          type = 42,
          typeName = "DisabledLine"
        },
        [13] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 13,
          type = 1,
          typeName = "Blank"
        },
        [14] = {
          enchantID = 8017,
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "附魔：附魔頭盔 - 強化迴避符文|A:Professions-ChatIcon-Quality-12-Tier2:20:20|a",
          lineIndex = 14,
          type = 15,
          typeName = "ItemEnchantmentPermanent"
        },
        [15] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 15,
          type = 1,
          typeName = "Blank"
        },
        [16] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "聖化烈焰光輝（4/5）",
          lineIndex = 16,
          type = 0,
          typeName = "None"
        },
        [17] = {
          leftColor = {
            b = 0.59215688705444336,
            g = 1,
            r = 1
          },
          leftText = "  聖化烈焰壁壘",
          lineIndex = 17,
          type = 0,
          typeName = "None"
        },
        [18] = {
          leftColor = {
            b = 0.59215688705444336,
            g = 1,
            r = 1
          },
          leftText = "  聖化烈焰護手",
          lineIndex = 18,
          type = 0,
          typeName = "None"
        },
        [19] = {
          leftColor = {
            b = 0.59215688705444336,
            g = 1,
            r = 1
          },
          leftText = "  聖化烈焰戰盔",
          lineIndex = 19,
          type = 0,
          typeName = "None"
        },
        [20] = {
          leftColor = {
            b = 0.59215688705444336,
            g = 1,
            r = 1
          },
          leftText = "  聖化烈焰護脛",
          lineIndex = 20,
          type = 0,
          typeName = "None"
        },
        [21] = {
          leftColor = {
            b = 0.501960813999176,
            g = 0.501960813999176,
            r = 0.501960813999176
          },
          leftText = "  聖化烈焰肩鎧",
          lineIndex = 21,
          type = 42,
          typeName = "DisabledLine"
        },
        [22] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 22,
          type = 1,
          typeName = "Blank"
        },
        [23] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "套裝：神聖意圖有額外10%的機率啟動，且消耗神聖意圖時可獲得神聖力量，使造成的神聖傷害提高10%，持續12秒。",
          lineIndex = 23,
          type = 0,
          typeName = "None",
          wrapText = true
        },
        [24] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "套裝：消耗神聖意圖會賦予神性仲裁者，使你其他消耗聖能的技能對主要目標釋放一個聖光仲裁者，造成63787點神聖傷害，並對8碼內的敵人造成29767點神聖傷害。神性仲裁者生效期間中無法觸發。",
          lineIndex = 24,
          type = 0,
          typeName = "None",
          wrapText = true
        },
        [25] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 25,
          type = 1,
          typeName = "Blank"
        },
        [26] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "耐久度 93 / 100",
          lineIndex = 26,
          type = 0,
          typeName = "None"
        },
        [27] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "",
          lineIndex = 26,
          maxPrice = -1,
          price = 246878,
          type = 11,
          typeName = "SellPrice"
        }
      },
      type = 0
    },
    kind = "item",
    lines = {
      [1] = {
        left = {
          color = {
            [1] = 0.63921570777893066,
            [2] = 0.207843154668808,
            [3] = 0.93333339691162109,
            [4] = 1
          },
          shown = true,
          text = "聖化烈焰戰盔"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [2] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|cFF 0FF 0英雄難度|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [3] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "物品等級334"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [4] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "提升等級：神話 6/6"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [5] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "靈魂綁定"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [6] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "頭部"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "鎧甲"
        }
      },
      [7] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "326點護甲"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [8] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "+189力量"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [9] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "+3910耐力"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [10] = {
        left = {
          color = {
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "+141致命一擊"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [11] = {
        left = {
          color = {
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "+60精通"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [12] = {
        left = {
          color = {
            [1] = 0.501960813999176,
            [2] = 0.501960813999176,
            [3] = 0.501960813999176,
            [4] = 1
          },
          shown = true,
          text = "+189智力"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [13] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = " "
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [14] = {
        left = {
          color = {
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "附魔：附魔頭盔 - 強化迴避符文|A:Professions-ChatIcon-Quality-12-Tier2:20:20|a"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [15] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = " "
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [16] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "聖化烈焰光輝（4/5）"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [17] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 0.59215688705444336,
            [4] = 1
          },
          shown = true,
          text = "  聖化烈焰壁壘"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [18] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 0.59215688705444336,
            [4] = 1
          },
          shown = true,
          text = "  聖化烈焰護手"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [19] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 0.59215688705444336,
            [4] = 1
          },
          shown = true,
          text = "  聖化烈焰戰盔"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [20] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 0.59215688705444336,
            [4] = 1
          },
          shown = true,
          text = "  聖化烈焰護脛"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [21] = {
        left = {
          color = {
            [1] = 0.501960813999176,
            [2] = 0.501960813999176,
            [3] = 0.501960813999176,
            [4] = 1
          },
          shown = true,
          text = "  聖化烈焰肩鎧"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [22] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = " "
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [23] = {
        left = {
          color = {
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "套裝：神聖意圖有額外10%的機率啟動，且消耗神聖意圖時可獲得神聖力量，使造成的神聖傷害提高10%，持續12秒。"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [24] = {
        left = {
          color = {
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "套裝：消耗神聖意圖會賦予神性仲裁者，使你其他消耗聖能的技能對主要目標釋放一個聖光仲裁者，造成63787點神聖傷害，並對8碼內的敵人造成29767點神聖傷害。神性仲裁者生效期間中無法觸發。"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [25] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = " "
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [26] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "耐久度 93 / 100"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      },
      [27] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "售價: 24|A:coin-gold:14:14:2:0|a 68|A:coin-silver:14:14:2:0|a 78|A:coin-copper:14:14:2:0|a"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = false
        }
      }
    },
    locale = "zhTW",
    numLines = 27,
    source = 31,
    tip = "ShoppingTooltip1"
  },
}
