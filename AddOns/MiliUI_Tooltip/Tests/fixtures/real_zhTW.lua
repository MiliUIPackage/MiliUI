-- 真實的 12.1.5 zhTW 提示資料（/mtip record 2026-10-18 抓的，Tests/fixtures/export 產生，不要手改）
-- 每筆：kind、tip、locale、numLines（FontString 行數）、data（TooltipData 整張，lines[].type 是 Enum 數字，typeName 是對照名）、
-- lines（post-call 當下 1..numLines 的 FontString 文字與顏色；lineIndex 不在 data 裡的就是別家後加的行）
return {
{
    data = {
      dataInstanceID = 17501,
      id = 155145,
      lines = {
        [1] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "奧流之術",
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
          rightText = "冷卻時間2分鐘",
          type = 0,
          typeName = "None"
        },
        [4] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "移除8碼範圍內所有敵人身上的1個增益效果，並恢復1道聖能。",
          lineIndex = 3,
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
          text = "|T136222:16:16:0:0:32:32:2:30:2:30|t 奧流之術"
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
          text = "冷卻時間2分鐘"
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
          text = "移除8碼範圍內所有敵人身上的1個增益效果，並恢復1道聖能。"
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
    numLines = 3,
    source = 53,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 18098,
      id = 121820,
      lines = {
        [1] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "黑曜夜翼",
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
            g = 0.80000007152557373,
            r = 0
          },
          leftText = "戰隊坐騎",
          lineIndex = 2,
          rightColor = {
            b = 1,
            g = 0.73333334922790527,
            r = 0.40000003576278692
          },
          rightText = "飛行",
          type = 0,
          typeName = "None"
        },
        [3] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "",
          lineIndex = 2,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "",
          type = 0,
          typeName = "None"
        },
        [4] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "施法時間1.5秒",
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
        [5] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "將你變成黑曜夜翼，使你可以飛得非常快，並且可以讓一名盟友坐在你的背上。這是一隻飛行坐騎。",
          lineIndex = 4,
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
          text = "|T399041:16:16:0:0:32:32:2:30:2:30|t 黑曜夜翼"
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
            [2] = 0.80000007152557373,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "戰隊坐騎"
        },
        right = {
          color = {
            [1] = 0.40000003576278692,
            [2] = 0.73333334922790527,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "飛行"
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
          text = "施法時間1.5秒"
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
          text = "將你變成黑曜夜翼，使你可以飛得非常快，並且可以讓一名盟友坐在你的背上。這是一隻飛行坐騎。"
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
    numLines = 4,
    source = 55,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 18101,
      id = 53385,
      lines = {
        [1] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "神性風暴",
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
          leftText = "3道聖能",
          lineIndex = 2,
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
        [4] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "釋放一陣旋風般的神聖能量，對附近所有敵人造成15087點神聖傷害。\13\
\13\
超過5個目標時，造成的傷害降低。",
          lineIndex = 4,
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
          text = "|T236250:16:16:0:0:32:32:2:30:2:30|t 神性風暴"
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
          text = "3道聖能"
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
          text = "立即"
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
          text = "釋放一陣旋風般的神聖能量，對附近所有敵人造成15087點神聖傷害。\13\
\13\
超過5個目標時，造成的傷害降低。"
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
    numLines = 4,
    source = 56,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 18108,
      id = 7328,
      lines = {
        [1] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "救贖",
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
          leftText = "2000法力",
          lineIndex = 2,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "40碼距離",
          type = 0,
          typeName = "None"
        },
        [3] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "施法時間8.2秒",
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
        [4] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "復活一名死去的友方玩家，被復活的玩家擁有35%的生命力和法力。無法在戰鬥中施放。",
          lineIndex = 4,
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
          text = "|T135955:16:16:0:0:32:32:2:30:2:30|t 救贖"
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
          text = "2000法力"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "40碼距離"
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
          text = "施法時間8.2秒"
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
          text = "復活一名死去的友方玩家，被復活的玩家擁有35%的生命力和法力。無法在戰鬥中施放。"
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
    numLines = 4,
    source = 58,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 18109,
      id = 5502,
      lines = {
        [1] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "感應不死生物",
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
          rightText = "",
          type = 0,
          typeName = "None"
        },
        [4] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "在小地圖上顯示附近所有不死生物的位置，直到取消為止。同一時間內只能啟動一種追蹤技能。",
          lineIndex = 3,
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
          text = "|T135974:16:16:0:0:32:32:2:30:2:30|t 感應不死生物"
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
          text = "在小地圖上顯示附近所有不死生物的位置，直到取消為止。同一時間內只能啟動一種追蹤技能。"
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
    numLines = 3,
    source = 59,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 18124,
      id = 343527,
      lines = {
        [1] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "死刑宣判",
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
          leftText = "30碼距離",
          lineIndex = 2,
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
          lineIndex = 3,
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
          leftText = "在目標周圍釋放從天而降的衝擊，對10碼內的所有敵人造成28097點神聖傷害，並召喚一把錘子緩慢從天而降，砸向目標。\13\
\13\
在10秒後，使受到初始衝擊影響的所有目標受到相當於你在此期間造成的20%神聖傷害。",
          lineIndex = 4,
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
          text = "|T613954:16:16:0:0:32:32:2:30:2:30|t 死刑宣判"
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
          text = "30碼距離"
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
      [4] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "在目標周圍釋放從天而降的衝擊，對10碼內的所有敵人造成28097點神聖傷害，並召喚一把錘子緩慢從天而降，砸向目標。\13\
\13\
在10秒後，使受到初始衝擊影響的所有目標受到相當於你在此期間造成的20%神聖傷害。"
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
    numLines = 4,
    source = 60,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 15967,
      guid = "Item-966-0-4000000B0DCDFCB8",
      id = 241325,
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
          leftText = "血騎士精煉藥劑",
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
          leftText = "使用： 使你的加速提高151點，持續1小時。\13\
\13\
持續1小時，且死亡之後仍然有效。消耗相同精煉藥劑後，可額外延長1小時。 （3秒冷卻時間）",
          lineIndex = 2,
          spellID = 1235110,
          type = 44,
          typeName = "ItemSpellTriggerOnUse",
          wrapText = true
        },
        [3] = {
          isGameInfo = false,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "\"由經驗豐富的鍊金師製造。可在拍賣場進行買賣。\"",
          lineIndex = 3,
          type = 37,
          typeName = "FlavorText",
          wrapText = true
        },
        [4] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "品質：|A:Professions-Icon-Quality-12-Tier1-Small:38:40:0:-1|a",
          lineIndex = 4,
          type = 12,
          typeName = "ProfessionCraftingQuality",
          wrapText = true
        },
        [5] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "",
          lineIndex = 4,
          maxPrice = -1,
          price = 468000,
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
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|T7548904:16:16:0:0:32:32:2:30:2:30|t 血騎士精煉藥劑"
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
          text = "使用： 使你的加速提高151點，持續1小時。\13\
\13\
持續1小時，且死亡之後仍然有效。消耗相同精煉藥劑後，可額外延長1小時。 （3秒冷卻時間）"
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
          text = "\"由經驗豐富的鍊金師製造。可在拍賣場進行買賣。\""
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
          text = "品質：|A:Professions-Icon-Quality-12-Tier1-Small:38:40:0:-1|a"
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
          text = "售價: 46|A:coin-gold:14:14:2:0|a 80|A:coin-silver:14:14:2:0|a"
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
          text = "|cffffffff2 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 92 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 50 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
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
          text = "|cffffffff168 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 88 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
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
          text = "|cffffffff3 天|r"
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
          text = "|cff66bbff總計：|cffffffff38|r|r"
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
          text = "  |A:raceicon128-bloodelf-male:13:13|a |cfff48cba角色1-伺服器|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff背包：|cffffffff16|r|r"
        }
      },
      [11] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "  |A:raceicon128-magharorc-male:13:13|a |cff0070dd角色2-伺服器|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff背包：|cffffffff14|r|r"
        }
      },
      [12] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "  |A:raceicon128-dracthyr-male:13:13|a |cff33937f角色3-伺服器|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff背包：|cffffffff4|r|r"
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
          text = "  |A:raceicon128-magharorc-male:13:13|a |cff8788ee角色4-伺服器|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff背包：|cffffffff1|r|r"
        }
      },
      [14] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "  ..."
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
          text = "  |A:communities-guildbanner-background:13:13|a |cffff80ff公會|r-伺服器"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff公會：|cffffffff2|r|r"
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
      [17] = {
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
      [18] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.81960791349411011,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "堆疊上限: |cffffffff200|r"
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
    numLines = 18,
    source = 1,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 15975,
      guid = "Item-966-0-400000075FD45970",
      id = 109076,
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
          leftText = "哥布林滑翔工具組",
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
          leftText = "使用： 降低你的掉落速度，持續2分鐘。 （3分鐘冷卻時間）",
          lineIndex = 2,
          spellID = 126389,
          type = 44,
          typeName = "ItemSpellTriggerOnUse",
          wrapText = true
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
          price = 24500,
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
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "|T133632:16:16:0:0:32:32:2:30:2:30|t 哥布林滑翔工具組"
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
          text = "使用： 降低你的掉落速度，持續2分鐘。 （3分鐘冷卻時間）"
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
          text = "售價: 2|A:coin-gold:14:14:2:0|a 45|A:coin-silver:14:14:2:0|a"
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
          text = "|cffffffff7 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
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
          text = "|cffffffff8 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 00 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
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
          text = "|cffffffff2 天|r"
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
          text = "|cff66bbff總計：|cffffffff221|r|r"
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
          text = "  |A:raceicon128-bloodelf-male:13:13|a |cfff48cba角色1-伺服器|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff背包：|cffffffff35|r|r"
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
          text = "  |A:raceicon128-magharorc-male:13:13|a |cff0070dd角色2-伺服器|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff背包：|cffffffff11|r|r"
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
          text = "  |A:raceicon128-bloodelf-male:13:13|a |cffc41e3a角色5-伺服器|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff背包：|cffffffff3|r|r"
        }
      },
      [11] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "  |A:raceicon128-zandalari-male:13:13|a |cffc41e3a角色6-伺服器|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff背包：|cffffffff2|r|r"
        }
      },
      [12] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "  |A:communities-guildbanner-background:13:13|a |cffff80ff公會|r-伺服器"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff公會：|cffffffff170|r|r"
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
            [1] = 1,
            [2] = 0.81960791349411011,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "資料片: |cffffffff德拉諾之霸 (6.0)|r"
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
            [2] = 0.81960791349411011,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "堆疊上限: |cffffffff200|r"
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
    numLines = 15,
    source = 4,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 16007,
      guid = "Item-966-0-4000000B17FD75E2",
      id = 272226,
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
          leftText = "迷霧潛獵者罩氅",
          lineIndex = 1,
          quality = 4,
          type = 22,
          typeName = "ItemName"
        },
        [2] = {
          itemLevel = 308,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "物品等級308",
          lineIndex = 2,
          type = 31,
          typeName = "ItemLevel"
        },
        [3] = {
          currentLevel = 6,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "提升等級：勇士 6/6",
          lineIndex = 3,
          maxLevel = 6,
          trackStringID = 973,
          type = 32,
          typeName = "ItemUpgradeLevel"
        },
        [4] = {
          bonding = 3,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "靈魂綁定",
          lineIndex = 4,
          type = 20,
          typeName = "ItemBinding"
        },
        [5] = {
          isValidInvSlot = true,
          isValidItemType = true,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "背部",
          lineIndex = 5,
          type = 21,
          typeName = "EquipSlot"
        },
        [6] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "66點護甲",
          lineIndex = 6,
          type = 0,
          typeName = "None"
        },
        [7] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "+83力量",
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
          leftText = "+1629耐力",
          lineIndex = 8,
          type = 0,
          typeName = "None"
        },
        [9] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "+64致命一擊",
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
          leftText = "+38臨機應變",
          lineIndex = 10,
          type = 0,
          typeName = "None"
        },
        [11] = {
          leftColor = {
            b = 0.501960813999176,
            g = 0.501960813999176,
            r = 0.501960813999176
          },
          leftText = "+83智力",
          lineIndex = 11,
          type = 42,
          typeName = "DisabledLine"
        },
        [12] = {
          leftColor = {
            b = 0.501960813999176,
            g = 0.501960813999176,
            r = 0.501960813999176
          },
          leftText = "+83敏捷",
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
          leftText = "",
          lineIndex = 12,
          maxPrice = -1,
          price = 463141,
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
          text = "|T7865329:16:16:0:0:32:32:2:30:2:30|t 迷霧潛獵者罩氅"
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
          text = "物品等級308"
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
          text = "提升等級：勇士 6/6"
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
      [5] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "背部"
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
          text = "66點護甲"
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
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "+83力量"
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
          text = "+1629耐力"
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
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "+64致命一擊"
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
          text = "+38臨機應變"
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
            [1] = 0.501960813999176,
            [2] = 0.501960813999176,
            [3] = 0.501960813999176,
            [4] = 1
          },
          shown = true,
          text = "+83智力"
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
          text = "+83敏捷"
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
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "售價: 46|A:coin-gold:14:14:2:0|a 31|A:coin-silver:14:14:2:0|a 41|A:coin-copper:14:14:2:0|a"
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
          text = "|cffffffff46 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 31 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 41 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
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
          text = "分解"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff未知  |r"
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
          text = "|cff66bbff總計：|cffffffff2|r|r"
        }
      },
      [17] = {
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
          text = "|cff66bbff背包：|cffffffff1|r|r"
        }
      },
      [18] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "  |A:warbands-icon:17:13|a |cffc4a300戰隊|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff銀行：|cffffffff1|r|r"
        }
      },
      [19] = {
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
      [20] = {
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
    numLines = 20,
    source = 12,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 16032,
      guid = "Item-966-0-4000000B1CB7C20D",
      hasDynamicData = true,
      id = 268213,
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
          leftText = "『督軍之怒』馬茲羅亞",
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
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "僅可裝備一件",
          lineIndex = 6,
          type = 0,
          typeName = "None"
        },
        [7] = {
          isValidInvSlot = true,
          isValidItemType = true,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "雙手",
          lineIndex = 7,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "斧",
          type = 21,
          typeName = "EquipSlot"
        },
        [8] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "332-690點傷害",
          lineIndex = 8,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "速度 3.60",
          type = 0,
          typeName = "None"
        },
        [9] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "（每秒141.9點傷害）",
          lineIndex = 9,
          type = 0,
          typeName = "None"
        },
        [10] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "+189力量",
          lineIndex = 10,
          type = 0,
          typeName = "None"
        },
        [11] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "+3910耐力",
          lineIndex = 11,
          type = 0,
          typeName = "None"
        },
        [12] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "+142致命一擊",
          lineIndex = 12,
          type = 0,
          typeName = "None"
        },
        [13] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "+59精通",
          lineIndex = 13,
          type = 0,
          typeName = "None"
        },
        [14] = {
          leftColor = {
            b = 0.501960813999176,
            g = 0.501960813999176,
            r = 0.501960813999176
          },
          leftText = "+189敏捷",
          lineIndex = 14,
          type = 42,
          typeName = "DisabledLine"
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
          enchantID = 8039,
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "附魔：附魔武器 - 刃多雷的敏銳|A:Professions-ChatIcon-Quality-12-Tier2:20:20|a",
          lineIndex = 16,
          type = 15,
          typeName = "ItemEnchantmentPermanent"
        },
        [17] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "薩拉斯鳳凰之油|A:Professions-ChatIcon-Quality-12-Tier1:20:20|a（13分鐘）",
          lineIndex = 17,
          type = 0,
          typeName = "None"
        },
        [18] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "裝備： 你的攻擊有很高的機率施加毒液之牙，在6秒內造成5246點自然傷害，隨後會產生爆發，對附近的敵人造成2295點自然傷害。多次觸發可以重疊。",
          lineIndex = 18,
          spellID = 1291718,
          type = 45,
          typeName = "ItemSpellTriggerOnEquip",
          wrapText = true
        },
        [19] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 19,
          type = 1,
          typeName = "Blank"
        },
        [20] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "祖爾詹之咬（2/3）",
          lineIndex = 20,
          type = 0,
          typeName = "None"
        },
        [21] = {
          leftColor = {
            b = 0.59215688705444336,
            g = 1,
            r = 1
          },
          leftText = "  祖爾金的斬首技藝",
          lineIndex = 21,
          type = 0,
          typeName = "None"
        },
        [22] = {
          leftColor = {
            b = 0.501960813999176,
            g = 0.501960813999176,
            r = 0.501960813999176
          },
          leftText = "  『督軍復仇』阿曼穆索",
          lineIndex = 22,
          type = 42,
          typeName = "DisabledLine"
        },
        [23] = {
          leftColor = {
            b = 0.59215688705444336,
            g = 1,
            r = 1
          },
          leftText = "  『督軍之怒』馬茲羅亞",
          lineIndex = 23,
          type = 0,
          typeName = "None"
        },
        [24] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 24,
          type = 1,
          typeName = "Blank"
        },
        [25] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "套裝：精進你的斬首技巧以彈跳至附近的第二個敵人，造成其100%的傷害，並同時對兩個目標施加毒液之牙。",
          lineIndex = 25,
          type = 0,
          typeName = "None",
          wrapText = true
        },
        [26] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 26,
          type = 1,
          typeName = "Blank"
        },
        [27] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "耐久度 120 / 120",
          lineIndex = 27,
          type = 0,
          typeName = "None"
        },
        [28] = {
          isGameInfo = false,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "\"羅亞說我們的祖父，偉大的祖爾金背叛了祂們。但憑什麼相信祂們？\"",
          lineIndex = 28,
          type = 37,
          typeName = "FlavorText",
          wrapText = true
        },
        [29] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "",
          lineIndex = 28,
          maxPrice = -1,
          price = 1070685,
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
          text = "『督軍之怒』馬茲羅亞"
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
          text = "僅可裝備一件"
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
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "雙手"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "斧"
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
          text = "332-690點傷害"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "速度 3.60"
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
          text = "（每秒141.9點傷害）"
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
      [11] = {
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
      [12] = {
        left = {
          color = {
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "+142致命一擊"
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
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "+59精通"
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
            [1] = 0.501960813999176,
            [2] = 0.501960813999176,
            [3] = 0.501960813999176,
            [4] = 1
          },
          shown = true,
          text = "+189敏捷"
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
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "附魔：附魔武器 - 刃多雷的敏銳|A:Professions-ChatIcon-Quality-12-Tier2:20:20|a"
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
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "薩拉斯鳳凰之油|A:Professions-ChatIcon-Quality-12-Tier1:20:20|a（13分鐘）"
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
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "裝備： 你的攻擊有很高的機率施加毒液之牙，在6秒內造成5246點自然傷害，隨後會產生爆發，對附近的敵人造成2295點自然傷害。多次觸發可以重疊。"
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
      [20] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "祖爾詹之咬（2/3）"
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
            [1] = 1,
            [2] = 1,
            [3] = 0.59215688705444336,
            [4] = 1
          },
          shown = true,
          text = "  祖爾金的斬首技藝"
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
            [1] = 0.501960813999176,
            [2] = 0.501960813999176,
            [3] = 0.501960813999176,
            [4] = 1
          },
          shown = true,
          text = "  『督軍復仇』阿曼穆索"
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
            [1] = 1,
            [2] = 1,
            [3] = 0.59215688705444336,
            [4] = 1
          },
          shown = true,
          text = "  『督軍之怒』馬茲羅亞"
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
      [25] = {
        left = {
          color = {
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "套裝：精進你的斬首技巧以彈跳至附近的第二個敵人，造成其100%的傷害，並同時對兩個目標施加毒液之牙。"
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
      [27] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "耐久度 120 / 120"
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
      [28] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "\"羅亞說我們的祖父，偉大的祖爾金背叛了祂們。但憑什麼相信祂們？\""
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
      [29] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "售價: 107|A:coin-gold:14:14:2:0|a 6|A:coin-silver:14:14:2:0|a 85|A:coin-copper:14:14:2:0|a"
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
    numLines = 29,
    source = 17,
    tip = "ShoppingTooltip1"
  },
{
    data = {
      dataInstanceID = 16031,
      guid = "Item-966-0-4000000B0CA26E27",
      id = 249275,
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
          leftText = "高貴決心壁壘",
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
          leftText = "|cFF 0FF 0英雄難度|r\
|cFF C89EB卓越虛無鍛造：英雄|r",
          lineIndex = 2,
          type = 0,
          typeName = "None"
        },
        [3] = {
          itemLevel = 285,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "物品等級285",
          lineIndex = 3,
          type = 31,
          typeName = "ItemLevel"
        },
        [4] = {
          bonding = 3,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "靈魂綁定",
          lineIndex = 4,
          type = 20,
          typeName = "ItemBinding"
        },
        [5] = {
          isValidInvSlot = true,
          isValidItemType = true,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "副手",
          lineIndex = 5,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "盾牌",
          type = 21,
          typeName = "EquipSlot"
        },
        [6] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "931點護甲",
          lineIndex = 6,
          type = 0,
          typeName = "None"
        },
        [7] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "2327格擋",
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
          leftText = "+60力量",
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
          leftText = "+1110耐力",
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
          leftText = "+24致命一擊",
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
          leftText = "+56臨機應變",
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
          leftText = "+183智力",
          lineIndex = 12,
          type = 42,
          typeName = "DisabledLine"
        },
        [13] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "耐久度 120 / 120",
          lineIndex = 13,
          type = 0,
          typeName = "None"
        },
        [14] = {
          isGameInfo = true,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "「毀滅才是唯一的崇高之舉。」 - 統治者阿瓦齊恩",
          lineIndex = 14,
          type = 37,
          typeName = "FlavorText",
          wrapText = true
        },
        [15] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "",
          lineIndex = 14,
          maxPrice = -1,
          price = 543554,
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
          text = "|T7412729:16:16:0:0:32:32:2:30:2:30|t 高貴決心壁壘"
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
          text = "|cFF 0FF 0英雄難度|r\
|cFF C89EB卓越虛無鍛造：英雄|r"
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
          text = "物品等級285"
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
      [5] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "副手"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "盾牌"
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
          text = "931點護甲"
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
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "2327格擋"
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
          text = "+60力量"
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
          text = "+1110耐力"
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
          text = "+24致命一擊"
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
          text = "+56臨機應變"
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
          text = "+183智力"
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
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "耐久度 120 / 120"
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
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "「毀滅才是唯一的崇高之舉。」 - 統治者阿瓦齊恩"
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
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "售價: 54|A:coin-gold:14:14:2:0|a 35|A:coin-silver:14:14:2:0|a 54|A:coin-copper:14:14:2:0|a"
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
          text = "|cffffffff54 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 35 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 54 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
        }
      },
      [17] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "分解"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff未知  |r"
        }
      },
      [18] = {
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
          text = "|cff66bbff總計：|cffffffff2|r|r"
        }
      },
      [19] = {
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
          text = "|cff66bbff背包：|cffffffff1|r|r"
        }
      },
      [20] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "  |A:warbands-icon:17:13|a |cffc4a300戰隊|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff銀行：|cffffffff1|r|r"
        }
      },
      [21] = {
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
      [22] = {
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
    numLines = 22,
    source = 19,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 16042,
      guid = "Item-966-0-4000000B1B56CE6E",
      id = 268210,
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
          leftText = "狠毒靈魂鬥棍",
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
          itemLevel = 308,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "物品等級308",
          lineIndex = 3,
          type = 31,
          typeName = "ItemLevel"
        },
        [4] = {
          currentLevel = 2,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "提升等級：英雄 2/6",
          lineIndex = 4,
          maxLevel = 6,
          trackStringID = 974,
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
          leftText = "單手",
          lineIndex = 6,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "錘",
          type = 21,
          typeName = "EquipSlot"
        },
        [7] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "95-123點傷害",
          lineIndex = 7,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "速度 2.60",
          type = 0,
          typeName = "None"
        },
        [8] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "（每秒41.9點傷害）",
          lineIndex = 8,
          type = 0,
          typeName = "None"
        },
        [9] = {
          leftColor = {
            b = 0.501960813999176,
            g = 0.501960813999176,
            r = 0.501960813999176
          },
          leftText = "+431智力",
          lineIndex = 9,
          type = 42,
          typeName = "DisabledLine"
        },
        [10] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "+1448耐力",
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
          leftText = "+27致命一擊",
          lineIndex = 11,
          type = 0,
          typeName = "None"
        },
        [12] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "+63精通",
          lineIndex = 12,
          type = 0,
          typeName = "None"
        },
        [13] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "耐久度 110 / 110",
          lineIndex = 13,
          type = 0,
          typeName = "None"
        },
        [14] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "",
          lineIndex = 13,
          maxPrice = -1,
          price = 836170,
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
          text = "|T7502390:16:16:0:0:32:32:2:30:2:30|t 狠毒靈魂鬥棍"
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
          text = "物品等級308"
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
          text = "提升等級：英雄 2/6"
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
          text = "單手"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "錘"
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
          text = "95-123點傷害"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "速度 2.60"
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
          text = "（每秒41.9點傷害）"
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
            [1] = 0.501960813999176,
            [2] = 0.501960813999176,
            [3] = 0.501960813999176,
            [4] = 1
          },
          shown = true,
          text = "+431智力"
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
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "+1448耐力"
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
          text = "+27致命一擊"
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
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "+63精通"
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
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "耐久度 110 / 110"
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
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "售價: 83|A:coin-gold:14:14:2:0|a 61|A:coin-silver:14:14:2:0|a 70|A:coin-copper:14:14:2:0|a"
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
          text = "|cffffffff83 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 61 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 70 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
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
          text = "分解"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff未知  |r"
        }
      },
      [17] = {
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
          text = "|cff66bbff總計：|cffffffff2|r|r"
        }
      },
      [18] = {
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
          text = "|cff66bbff背包：|cffffffff2|r|r"
        }
      },
      [19] = {
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
      [20] = {
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
    numLines = 20,
    source = 21,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 16351,
      guid = "Item-966-0-4000000B0CFFA04A",
      id = 249343,
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
          leftText = "艾恩先知的凝視",
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
          leftText = "|cFF 0FF 0傳奇難度|r\
|cFF C89EB卓越虛無鍛造：傳奇|r",
          lineIndex = 2,
          type = 0,
          typeName = "None"
        },
        [3] = {
          itemLevel = 298,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "物品等級298",
          lineIndex = 3,
          type = 31,
          typeName = "ItemLevel"
        },
        [4] = {
          bonding = 3,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "靈魂綁定",
          lineIndex = 4,
          type = 20,
          typeName = "ItemBinding"
        },
        [5] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "僅可裝備一件",
          lineIndex = 5,
          type = 0,
          typeName = "None"
        },
        [6] = {
          isValidInvSlot = true,
          isValidItemType = true,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "飾品",
          lineIndex = 6,
          type = 21,
          typeName = "EquipSlot"
        },
        [7] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "+123精通",
          lineIndex = 7,
          type = 0,
          typeName = "None"
        },
        [8] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 8,
          type = 1,
          typeName = "Blank"
        },
        [9] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "裝備： 你的傷害和治療效果有一定機率賦予你艾恩之視，持續12秒。在作用期間，施放法術和技能會召喚出不穩定的艾恩蔑視，並消耗其精華，使你的力量提高26點，持續12秒。多次觸發可以重疊。",
          lineIndex = 9,
          spellID = 1256896,
          type = 45,
          typeName = "ItemSpellTriggerOnEquip",
          wrapText = true
        },
        [10] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 10,
          type = 1,
          typeName = "Blank"
        },
        [11] = {
          isGameInfo = false,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "\"有些地方就連虔信者也不敢凝視。\"",
          lineIndex = 11,
          type = 37,
          typeName = "FlavorText",
          wrapText = true
        },
        [12] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "",
          lineIndex = 11,
          maxPrice = -1,
          price = 490351,
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
          text = "|T7636702:16:16:0:0:32:32:2:30:2:30|t 艾恩先知的凝視"
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
          text = "|cFF 0FF 0傳奇難度|r\
|cFF C89EB卓越虛無鍛造：傳奇|r"
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
          text = "物品等級298"
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
      [5] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "僅可裝備一件"
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
          text = "飾品"
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
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "+123精通"
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
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "裝備： 你的傷害和治療效果有一定機率賦予你艾恩之視，持續12秒。在作用期間，施放法術和技能會召喚出不穩定的艾恩蔑視，並消耗其精華，使你的力量提高26點，持續12秒。多次觸發可以重疊。"
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
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "\"有些地方就連虔信者也不敢凝視。\""
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
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "售價: 49|A:coin-gold:14:14:2:0|a 3|A:coin-silver:14:14:2:0|a 51|A:coin-copper:14:14:2:0|a"
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
          text = "|cffffffff49 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 03 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 51 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
        }
      },
      [14] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "分解"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff未知  |r"
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
          text = "|cff66bbff總計：|cffffffff6|r|r"
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
          text = "  |A:raceicon128-bloodelf-male:13:13|a |cffa330c9角色7|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff背包：|cffffffff1|r, 裝備：|cffffffff1|r|r"
        }
      },
      [17] = {
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
          text = "|cff66bbff背包：|cffffffff1|r|r"
        }
      },
      [18] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "  |A:raceicon128-magharorc-male:13:13|a |cff8788ee角色4|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff背包：|cffffffff1|r|r"
        }
      },
      [19] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "  |A:raceicon128-dracthyr-male:13:13|a |cff33937f角色3|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff裝備：|cffffffff1|r|r"
        }
      },
      [20] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "  ..."
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
      [22] = {
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
    numLines = 22,
    source = 32,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 16713,
      guid = "Item-966-0-4000000B20E7E464",
      id = 281029,
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
          leftText = "蟲群呼喚指環",
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
          itemLevel = 324,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "物品等級324",
          lineIndex = 3,
          type = 31,
          typeName = "ItemLevel"
        },
        [4] = {
          currentLevel = 3,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "提升等級：神話 3/6",
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
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "僅可裝備一件",
          lineIndex = 6,
          type = 0,
          typeName = "None"
        },
        [7] = {
          isValidInvSlot = true,
          isValidItemType = true,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "手指",
          lineIndex = 7,
          type = 21,
          typeName = "EquipSlot"
        },
        [8] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "+1962耐力",
          lineIndex = 8,
          type = 0,
          typeName = "None"
        },
        [9] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "+104加速",
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
          leftText = "+279精通",
          lineIndex = 10,
          type = 0,
          typeName = "None"
        },
        [11] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 11,
          type = 1,
          typeName = "Blank"
        },
        [12] = {
          enchantID = 7967,
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "附魔：附魔戒指 - 老鷹之眼|A:Professions-ChatIcon-Quality-12-Tier2:20:20|a",
          lineIndex = 12,
          type = 15,
          typeName = "ItemEnchantmentPermanent"
        },
        [13] = {
          gemIcon = 7549137,
          gemItemID = 240900,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "|cffffffff+16點精通和+7點加速|r",
          lineIndex = 13,
          type = 3,
          typeName = "GemSocket",
          wrapText = true
        },
        [14] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 14,
          type = 1,
          typeName = "Blank"
        },
        [15] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "裝備： 你的攻擊有機率強化指環的低語，召喚一隻酸育天譴。天譴會飛向你的目標並爆炸，對附近所有敵人造成5980點自然傷害。",
          lineIndex = 15,
          spellID = 1310082,
          type = 45,
          typeName = "ItemSpellTriggerOnEquip",
          wrapText = true
        },
        [16] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 16,
          type = 1,
          typeName = "Blank"
        },
        [17] = {
          isGameInfo = false,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "\"不祥的低語從戒指中傳出，聲音大到足以聽見，卻又細密得讓人無法完全理解。\"",
          lineIndex = 17,
          type = 37,
          typeName = "FlavorText",
          wrapText = true
        },
        [18] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 18,
          type = 1,
          typeName = "Blank"
        },
        [19] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "<按下Shift+右鍵以插入寶石>",
          lineIndex = 19,
          type = 0,
          typeName = "None"
        },
        [20] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "",
          lineIndex = 19,
          maxPrice = -1,
          price = 386760,
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
          text = "|T8268560:16:16:0:0:32:32:2:30:2:30|t 蟲群呼喚指環"
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
          text = "物品等級324"
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
          text = "提升等級：神話 3/6"
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
          text = "僅可裝備一件"
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
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "手指"
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
          text = "+1962耐力"
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
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "+104加速"
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
          text = "+279精通"
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
      [12] = {
        left = {
          color = {
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "附魔：附魔戒指 - 老鷹之眼|A:Professions-ChatIcon-Quality-12-Tier2:20:20|a"
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
          text = "|cffffffff+16點精通和+7點加速|r"
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
      [15] = {
        left = {
          color = {
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "裝備： 你的攻擊有機率強化指環的低語，召喚一隻酸育天譴。天譴會飛向你的目標並爆炸，對附近所有敵人造成5980點自然傷害。"
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
      [17] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "\"不祥的低語從戒指中傳出，聲音大到足以聽見，卻又細密得讓人無法完全理解。\""
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
      [19] = {
        left = {
          color = {
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "<按下Shift+右鍵以插入寶石>"
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
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "售價: 38|A:coin-gold:14:14:2:0|a 67|A:coin-silver:14:14:2:0|a 60|A:coin-copper:14:14:2:0|a"
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
          text = "|cffffffff38 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 67 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 60 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
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
          text = "分解"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff未知  |r"
        }
      },
      [23] = {
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
          text = "|cff66bbff總計：|cffffffff2|r|r"
        }
      },
      [24] = {
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
          text = "|cff66bbff裝備：|cffffffff1|r|r"
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
          text = "  |A:raceicon128-magharorc-male:13:13|a |cff0070dd角色2|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff裝備：|cffffffff1|r|r"
        }
      },
      [26] = {
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
      [27] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff9d5db8KeystoneLoot|r"
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
      [28] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|TInterface\\AddOns\\KeystoneLoot\\assets\\tier_bis:16:16|t 最佳裝備 (懲戒)"
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
      [29] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|A:questlog-questtypeicon-raid:16:16:0:0|a 克希斯的解放 - 克希斯"
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
      [30] = {
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
      [31] = {
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
    numLines = 31,
    source = 38,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 16720,
      guid = "Item-966-0-4000000B1D7508F9",
      id = 271466,
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
          leftText = "聖化烈焰護手",
          lineIndex = 1,
          quality = 4,
          type = 22,
          typeName = "ItemName"
        },
        [2] = {
          itemLevel = 321,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "物品等級321",
          lineIndex = 2,
          type = 31,
          typeName = "ItemLevel"
        },
        [3] = {
          currentLevel = 6,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "提升等級：英雄 6/6",
          lineIndex = 3,
          maxLevel = 6,
          trackStringID = 974,
          type = 32,
          typeName = "ItemUpgradeLevel"
        },
        [4] = {
          leftColor = {
            b = 1,
            g = 0.501960813999176,
            r = 1
          },
          leftText = "已塑形為：",
          lineIndex = 4,
          type = 0,
          typeName = "None"
        },
        [5] = {
          leftColor = {
            b = 1,
            g = 0.501960813999176,
            r = 1
          },
          leftText = "璀璨光明使者護手",
          lineIndex = 5,
          type = 0,
          typeName = "None"
        },
        [6] = {
          bonding = 3,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "靈魂綁定",
          lineIndex = 6,
          type = 20,
          typeName = "ItemBinding"
        },
        [7] = {
          isValidInvSlot = true,
          isValidItemType = true,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "手",
          lineIndex = 7,
          rightColor = {
            b = 1,
            g = 1,
            r = 1
          },
          rightText = "鎧甲",
          type = 21,
          typeName = "EquipSlot"
        },
        [8] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "224點護甲",
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
          leftText = "+125力量",
          lineIndex = 9,
          type = 0,
          typeName = "None"
        },
        [10] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "+2527耐力",
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
          leftText = "+92加速",
          lineIndex = 11,
          type = 0,
          typeName = "None"
        },
        [12] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "+51精通",
          lineIndex = 12,
          type = 0,
          typeName = "None"
        },
        [13] = {
          leftColor = {
            b = 0.501960813999176,
            g = 0.501960813999176,
            r = 0.501960813999176
          },
          leftText = "+125智力",
          lineIndex = 13,
          type = 42,
          typeName = "DisabledLine"
        },
        [14] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 14,
          type = 1,
          typeName = "Blank"
        },
        [15] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "聖化烈焰光輝（4/5）",
          lineIndex = 15,
          type = 0,
          typeName = "None"
        },
        [16] = {
          leftColor = {
            b = 0.59215688705444336,
            g = 1,
            r = 1
          },
          leftText = "  聖化烈焰壁壘",
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
          leftText = "  聖化烈焰護手",
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
          leftText = "  聖化烈焰戰盔",
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
          leftText = "  聖化烈焰護脛",
          lineIndex = 19,
          type = 0,
          typeName = "None"
        },
        [20] = {
          leftColor = {
            b = 0.501960813999176,
            g = 0.501960813999176,
            r = 0.501960813999176
          },
          leftText = "  聖化烈焰肩鎧",
          lineIndex = 20,
          type = 42,
          typeName = "DisabledLine"
        },
        [21] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 21,
          type = 1,
          typeName = "Blank"
        },
        [22] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "套裝：神聖意圖有額外10%的機率啟動，且消耗神聖意圖時可獲得神聖力量，使造成的神聖傷害提高10%，持續12秒。",
          lineIndex = 22,
          type = 0,
          typeName = "None",
          wrapText = true
        },
        [23] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "套裝：消耗神聖意圖會賦予神性仲裁者，使你其他消耗聖能的技能對主要目標釋放一個聖光仲裁者，造成63787點神聖傷害，並對8碼內的敵人造成29767點神聖傷害。神性仲裁者生效期間中無法觸發。",
          lineIndex = 23,
          type = 0,
          typeName = "None",
          wrapText = true
        },
        [24] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 24,
          type = 1,
          typeName = "Blank"
        },
        [25] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "耐久度 55 / 55",
          lineIndex = 25,
          type = 0,
          typeName = "None"
        },
        [26] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "",
          lineIndex = 25,
          maxPrice = -1,
          price = 295170,
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
          text = "|T7730302:16:16:0:0:32:32:2:30:2:30|t 聖化烈焰護手"
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
          text = "物品等級321"
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
          text = "提升等級：英雄 6/6"
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
            [2] = 0.501960813999176,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "已塑形為："
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
            [2] = 0.501960813999176,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "璀璨光明使者護手"
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
      [7] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "手"
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
      [8] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "224點護甲"
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
          text = "+125力量"
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
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "+2527耐力"
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
          text = "+92加速"
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
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "+51精通"
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
            [1] = 0.501960813999176,
            [2] = 0.501960813999176,
            [3] = 0.501960813999176,
            [4] = 1
          },
          shown = true,
          text = "+125智力"
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
      [15] = {
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
      [16] = {
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
      [17] = {
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
      [18] = {
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
      [19] = {
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
      [20] = {
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
      [21] = {
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
      [22] = {
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
      [23] = {
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
      [24] = {
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
      [25] = {
        left = {
          color = {
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "耐久度 55 / 55"
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
          text = "售價: 29|A:coin-gold:14:14:2:0|a 51|A:coin-silver:14:14:2:0|a 70|A:coin-copper:14:14:2:0|a"
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
          text = "|cffffffff29 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 51 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 70 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
        }
      },
      [28] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "分解"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff未知  |r"
        }
      },
      [29] = {
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
          text = "|cff66bbff總計：|cffffffff1|r|r"
        }
      },
      [30] = {
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
          text = "|cff66bbff裝備：|cffffffff1|r|r"
        }
      },
      [31] = {
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
      [32] = {
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
    numLines = 32,
    source = 39,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 16872,
      guid = "Item-966-0-4000000B1CF2D337",
      id = 270173,
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
          leftText = "祖爾金的斬首技藝",
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
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "僅可裝備一件",
          lineIndex = 6,
          type = 0,
          typeName = "None"
        },
        [7] = {
          isValidInvSlot = true,
          isValidItemType = true,
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "飾品",
          lineIndex = 7,
          type = 21,
          typeName = "EquipSlot"
        },
        [8] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "+179力量",
          lineIndex = 8,
          type = 0,
          typeName = "None"
        },
        [9] = {
          leftColor = {
            b = 0.501960813999176,
            g = 0.501960813999176,
            r = 0.501960813999176
          },
          leftText = "+179敏捷",
          lineIndex = 9,
          type = 42,
          typeName = "DisabledLine"
        },
        [10] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 10,
          type = 1,
          typeName = "Blank"
        },
        [11] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "裝備： 你的攻擊有一定機率觸發斬首，向你的目標以弧線投擲一把巨斧，造成44002點物理傷害。\13\
\13\
目標每失去1%生命力，此傷害便提高2%。",
          lineIndex = 11,
          spellID = 1291728,
          type = 45,
          typeName = "ItemSpellTriggerOnEquip",
          wrapText = true
        },
        [12] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 12,
          type = 1,
          typeName = "Blank"
        },
        [13] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "祖爾詹之咬（2/3）",
          lineIndex = 13,
          type = 0,
          typeName = "None"
        },
        [14] = {
          leftColor = {
            b = 0.59215688705444336,
            g = 1,
            r = 1
          },
          leftText = "  祖爾金的斬首技藝",
          lineIndex = 14,
          type = 0,
          typeName = "None"
        },
        [15] = {
          leftColor = {
            b = 0.501960813999176,
            g = 0.501960813999176,
            r = 0.501960813999176
          },
          leftText = "  『督軍復仇』阿曼穆索",
          lineIndex = 15,
          type = 42,
          typeName = "DisabledLine"
        },
        [16] = {
          leftColor = {
            b = 0.59215688705444336,
            g = 1,
            r = 1
          },
          leftText = "  『督軍之怒』馬茲羅亞",
          lineIndex = 16,
          type = 0,
          typeName = "None"
        },
        [17] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 17,
          type = 1,
          typeName = "Blank"
        },
        [18] = {
          leftColor = {
            b = 0,
            g = 1,
            r = 0
          },
          leftText = "套裝：精進你的斬首技巧以彈跳至附近的第二個敵人，造成其100%的傷害，並同時對兩個目標施加毒液之牙。",
          lineIndex = 18,
          type = 0,
          typeName = "None",
          wrapText = true
        },
        [19] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = " ",
          lineIndex = 19,
          type = 1,
          typeName = "Blank"
        },
        [20] = {
          isGameInfo = false,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "\"你想要斧頭？\"",
          lineIndex = 20,
          type = 37,
          typeName = "FlavorText",
          wrapText = true
        },
        [21] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "",
          lineIndex = 20,
          maxPrice = -1,
          price = 525564,
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
          text = "|T7956755:16:16:0:0:32:32:2:30:2:30|t 祖爾金的斬首技藝"
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
          text = "僅可裝備一件"
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
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "飾品"
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
          text = "+179力量"
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
            [1] = 0.501960813999176,
            [2] = 0.501960813999176,
            [3] = 0.501960813999176,
            [4] = 1
          },
          shown = true,
          text = "+179敏捷"
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
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "裝備： 你的攻擊有一定機率觸發斬首，向你的目標以弧線投擲一把巨斧，造成44002點物理傷害。\13\
\13\
目標每失去1%生命力，此傷害便提高2%。"
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
      [13] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "祖爾詹之咬（2/3）"
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
            [1] = 1,
            [2] = 1,
            [3] = 0.59215688705444336,
            [4] = 1
          },
          shown = true,
          text = "  祖爾金的斬首技藝"
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
            [1] = 0.501960813999176,
            [2] = 0.501960813999176,
            [3] = 0.501960813999176,
            [4] = 1
          },
          shown = true,
          text = "  『督軍復仇』阿曼穆索"
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
            [2] = 1,
            [3] = 0.59215688705444336,
            [4] = 1
          },
          shown = true,
          text = "  『督軍之怒』馬茲羅亞"
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
      [18] = {
        left = {
          color = {
            [1] = 0,
            [2] = 1,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "套裝：精進你的斬首技巧以彈跳至附近的第二個敵人，造成其100%的傷害，並同時對兩個目標施加毒液之牙。"
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
      [20] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "\"你想要斧頭？\""
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
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "售價: 52|A:coin-gold:14:14:2:0|a 55|A:coin-silver:14:14:2:0|a 64|A:coin-copper:14:14:2:0|a"
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
          text = "|cffffffff52 |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t 55 |TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t 64 |TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t|r"
        }
      },
      [23] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "分解"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cffffffff未知  |r"
        }
      },
      [24] = {
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
          text = "|cff66bbff總計：|cffffffff2|r|r"
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
          text = "|cff66bbff裝備：|cffffffff1|r|r"
        }
      },
      [26] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "  |A:raceicon128-magharorc-male:13:13|a |cff0070dd角色2|r"
        },
        right = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff66bbff裝備：|cffffffff1|r|r"
        }
      },
      [27] = {
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
      [28] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|cff9d5db8KeystoneLoot|r"
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
      [29] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|TInterface\\AddOns\\KeystoneLoot\\assets\\tier_bis:16:16|t 最佳裝備 (懲戒)"
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
      [30] = {
        left = {
          color = {
            [1] = 1,
            [2] = 0.82352948188781738,
            [3] = 0,
            [4] = 1
          },
          shown = true,
          text = "|A:questlog-questtypeicon-raid:16:16:0:0|a 劇毒深淵 - 盤蛇祭壇"
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
      [31] = {
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
      [32] = {
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
    numLines = 32,
    source = 45,
    tip = "GameTooltip"
  },
{
    data = {
      dataInstanceID = 16008,
      guid = "Item-966-0-4000000B202B299B",
      id = 268253,
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
          leftText = "絲織巫毒披氅",
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
          itemLevel = 321,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "物品等級321",
          lineIndex = 3,
          type = 31,
          typeName = "ItemLevel"
        },
        [4] = {
          currentLevel = 2,
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "提升等級：神話 2/6",
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
          leftText = "背部",
          lineIndex = 6,
          type = 21,
          typeName = "EquipSlot"
        },
        [7] = {
          leftColor = {
            b = 1,
            g = 1,
            r = 1
          },
          leftText = "72點護甲",
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
          leftText = "+94力量",
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
          leftText = "+1895耐力",
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
          leftText = "+32加速",
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
          leftText = "+76精通",
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
          leftText = "+94智力",
          lineIndex = 12,
          type = 42,
          typeName = "DisabledLine"
        },
        [13] = {
          leftColor = {
            b = 0.501960813999176,
            g = 0.501960813999176,
            r = 0.501960813999176
          },
          leftText = "+94敏捷",
          lineIndex = 13,
          type = 42,
          typeName = "DisabledLine"
        },
        [14] = {
          leftColor = {
            b = 0,
            g = 0.82352948188781738,
            r = 1
          },
          leftText = "",
          lineIndex = 13,
          maxPrice = -1,
          price = 445834,
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
          text = "絲織巫毒披氅"
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
          text = "物品等級321"
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
          text = "提升等級：神話 2/6"
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
          text = "背部"
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
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "72點護甲"
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
          text = "+94力量"
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
          text = "+1895耐力"
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
          text = "+32加速"
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
          text = "+76精通"
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
          text = "+94智力"
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
            [1] = 0.501960813999176,
            [2] = 0.501960813999176,
            [3] = 0.501960813999176,
            [4] = 1
          },
          shown = true,
          text = "+94敏捷"
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
            [1] = 1,
            [2] = 1,
            [3] = 1,
            [4] = 1
          },
          shown = true,
          text = "售價: 44|A:coin-gold:14:14:2:0|a 58|A:coin-silver:14:14:2:0|a 34|A:coin-copper:14:14:2:0|a"
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
    numLines = 14,
    source = 11,
    tip = "ShoppingTooltip1"
  },
}
