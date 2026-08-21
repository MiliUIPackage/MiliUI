do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...

YUI.API = YUI.API or {}
YUI.WOW_API = YUI.WOW_API or {}
YUI.F = YUI.F or {}

local F = YUI.F
local API = YUI.WOW_API
local CombatAPI = YUI.API and YUI.API.Combat or API

local function GetCurrentTime()
    if CombatAPI and CombatAPI.GetTime then
        return CombatAPI.GetTime()
    end
    if GetTime then
        return GetTime()
    end
    return 0
end

function YUI:Debug(...)
    if not self.IsDev then
        return
    end
    print("|cFFFF00FFY|r|cFFFF6666U|r|cFFFF9900I|r ", ...)
end

function YUI:Print(...)
    print("|cFFFF00FFY|r|cFFFF6666U|r|cFFFF9900I|r ", ...)
end

function F:StrSplit(str, sep)
    sep = sep and string.gsub(sep, "([%%%-%*%+%.%[%]%(%)%?%^%$])", "%%%1") or
              "%s"
    local result = {}
    for part in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(result, part)
    end
    return result
end

function F:StrContains(str, substr)
    if str == nil or substr == nil or substr == "" then
        return false
    end
    return string.find(str, substr, 1, true) ~= nil
end

function F:SafeNum(val, default)
    if not YUI.IsRetail then return val or default or 0 end
    -- if issecretvalue and issecretvalue(val) then return default or 0 end
    return val or default or 0
end

function F:PrintKey(tab, filter)
    if type(tab) ~= "table" then
        print("Error: 入参必须是 table 类型！")
        return
    end

    -- 步骤1：收集所有键到临时数组
    local keys = {}
    for key, _ in pairs(tab) do
        table.insert(keys, key)
    end

    -- 步骤2：自定义排序规则（按字母/数值升序）
    table.sort(keys, function(a, b)
        local type_a = type(a)
        local type_b = type(b)

        -- 规则1：数字键优先于字符串键
        if type_a == "number" and type_b == "string" then
            return true
        elseif type_a == "string" and type_b == "number" then
            return false
        end

        -- 规则2：同类型键排序（数字按数值，字符串按字母）
        if type_a == "number" and type_b == "number" then
            return a < b -- 数字升序
        elseif type_a == "string" and type_b == "string" then
            -- 字符串按字母升序（忽略大小写可选，取消注释即可）
            -- return string.lower(a) < string.lower(b)
            return a < b -- 严格按ASCII字母序（区分大小写）
        end

        -- 其他类型（如布尔/表）默认放最后，按类型名排序
        return type_a < type_b
    end)

    -- 步骤3：打印排序后的键
    print("===== 表的所有键（按字母/数值升序） =====")
    for _, key in ipairs(keys) do
        local key_type = type(key)
        if filter then
            if string.match(key, filter) then
                print(key, tab[key])
            end
        else
            print(key, tab[key])
        end
    end
end

function F:PlaySound(key, channel, cooldown)
    self._LastPlay = self._LastPlay or {}
    local now = GetCurrentTime()
    if not cooldown or not self._LastPlay[key] or now - self._LastPlay[key] >= cooldown then
        -- TODO:
        print("Play Sound:", key, channel, cooldown)
        self._LastPlay[key] = now
    end
end

function F:GetPlayerVehicleName()
    -- 1. 获取当前玩家的载具坐骑GUID
    local vehicleGUID = UnitGUID("vehicle")
    
    -- 检查是否存在载具
    if not vehicleGUID then
        return "当前未乘坐任何载具"
    end
    
    -- 2. 通过GUID获取载具实体对象
    local vehicleUnit = nil
    -- 遍历可能的载具单位标识，确保兼容性
    local unitIds = {"vehicle", "mount", "pet"}
    for _, unitId in ipairs(unitIds) do
        if UnitExists(unitId) then
            vehicleUnit = unitId
            break
        end
    end
    
    -- 3. 获取载具名称
    local vehicleName = ""
    if vehicleUnit then
        -- 获取基础名称
        vehicleName = UnitName(vehicleUnit)
        -- 可选：获取带后缀的完整名称（如包含等级/品质）
        -- local fullName = UnitName("vehicle", true)
    end
    
    -- 容错处理
    if vehicleName == nil or vehicleName == "" then
        return "无法识别的载具"
    end
    
    return vehicleName
end

--- 获取渐变颜色的文本
--- @param text string 目标文本
--- @param startColor table 起始颜色 {r, g, b} (取值 0-1)
--- @param endColor table 结束颜色 {r, g, b} (取值 0-1)
--- @param options table|nil 可选限制 { maxVisibleChars = number, maxOutputBytes = number }
--- @return string 带有颜色转义符的渐变文本
function F:GetGradientText(text, startColor, endColor, options)
    if not text or text == "" then return "" end
    local originalText = text
    local maxVisibleChars = type(options) == "table" and tonumber(options.maxVisibleChars) or nil
    local maxOutputBytes = type(options) == "table" and tonumber(options.maxOutputBytes) or nil
    
    -- 获取颜色分量 (兼容数组和键值对格式)
    local r1, g1, b1 = startColor.r or startColor[1], startColor.g or startColor[2], startColor.b or startColor[3]
    local r2, g2, b2 = endColor.r or endColor[1], endColor.g or endColor[2], endColor.b or endColor[3]
    
    -- 1. 提取并保护 Tags (使用占位符替换，避免正则干扰)
    local tags = {}
    local placeholder_char = "\001"
    
    local function protect(pattern)
        text = string.gsub(text, pattern, function(match)
            table.insert(tags, match)
            return placeholder_char .. #tags .. placeholder_char
        end)
    end
    
    -- 必须按顺序保护！Link 最优先，因为它可能包含其他 Tag
    protect("|H.-|h.-|h")          -- Hyperlinks
    protect("|T.-|t")              -- Textures
    protect("|cn[%w_]+:")          -- Named Colors
    protect("|c%x%x%x%x%x%x%x%x")  -- Colors
    protect("|r")                  -- Reset
    protect("||")                  -- Escaped Pipe
    
    -- 2. 解析剩余文本（包含占位符）
    local segments = {}
    local len = string.len(text)
    local i = 1
    local visible_len = 0
    
    while i <= len do
        -- 检查是否是占位符 \001ID\001
        local s, e, id = string.find(text, "^" .. placeholder_char .. "(%d+)" .. placeholder_char, i)
        if s then
            table.insert(segments, { type = "tag", id = tonumber(id) })
            i = e + 1
        else
            -- 普通字符 (处理 UTF-8)
            local char_byte = string.byte(text, i)
            local char_len = 1
            if char_byte >= 240 then char_len = 4
            elseif char_byte >= 224 then char_len = 3
            elseif char_byte >= 192 then char_len = 2
            end
            
            -- 确保不越界
            if i + char_len - 1 > len then
                char_len = len - i + 1
            end
            
            local char = string.sub(text, i, i + char_len - 1)
            table.insert(segments, { type = "text", text = char })
            
            -- 只有非空白字符才计入 visible_len？或者全部计入？
            -- 为了保持渐变平滑，全部计入是合理的
            visible_len = visible_len + 1
            i = i + char_len
        end
    end

    if maxVisibleChars and maxVisibleChars > 0 and visible_len > maxVisibleChars then
        return originalText
    end

    if maxOutputBytes and maxOutputBytes > 0 and (string.len(originalText) + visible_len * 10 + 2) > maxOutputBytes then
        return originalText
    end
    
    -- 3. 构建结果
    local result = ""
    local current_idx = 0
    local color_depth = 0 -- 颜色深度：>0 表示处于显式颜色代码保护中
    local last_was_gradient = false -- 记录上一个输出是否是渐变字符
    
    for _, seg in ipairs(segments) do
        if seg.type == "tag" then
            local tag_content = tags[seg.id]
            local tag_prefix = string.sub(tag_content, 1, 2)
            
            -- 关键修复：在输出任何 Tag 之前，如果前一个是渐变字符，必须强制重置颜色。
            if last_was_gradient then
                result = result .. "|r"
                last_was_gradient = false
            end
            
            if tag_prefix == "|c" then
                result = result .. tag_content
                color_depth = color_depth + 1
                
            elseif tag_prefix == "|r" then
                result = result .. tag_content
                if color_depth > 0 then color_depth = color_depth - 1 end
                
            elseif tag_prefix == "|H" or tag_prefix == "|T" then
                if color_depth > 0 then
                    -- 处于颜色保护中（如蓝色物品），保留原样
                    result = result .. tag_content
                else
                    -- 普通物品/图标，且未被颜色包裹
                    -- 强制包裹纯白色，防止被周围环境影响
                    result = result .. "|cffffffff" .. tag_content .. "|r"
                end
                
            else
                -- 其他 Tag (如 ||)
                result = result .. tag_content
            end
            
        else
            -- 文本处理
            if color_depth > 0 then
                -- 处于显式颜色保护中，不应用渐变，直接输出
                result = result .. seg.text
                -- 显式文本也推进进度，保持连贯性
                current_idx = current_idx + 1
                last_was_gradient = false
            else
                -- 普通文本：应用渐变
                local ratio = 0
                if visible_len > 1 then
                    ratio = current_idx / (visible_len - 1)
                end
                
                local r = r1 + (r2 - r1) * ratio
                local g = g1 + (g2 - g1) * ratio
                local b = b1 + (b2 - b1) * ratio
                
                -- 注意：这里不加 |r 闭合，依靠下一个循环的 check 或最后的 |r 闭合
                -- 这样可以节省字符数，避免爆框
                result = result .. string.format("|cff%02x%02x%02x%s", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), seg.text)
                current_idx = current_idx + 1
                last_was_gradient = true
            end
        end
    end
    
    -- 调试用
    -- local finalResult = result .. "|r"
    -- print("Gradient Raw:", string.gsub(finalResult, "|", "||"))
    -- return finalResult
    
    local finalResult = result .. "|r"
    if maxOutputBytes and maxOutputBytes > 0 and string.len(finalResult) > maxOutputBytes then
        return originalText
    end
    return finalResult
end

--- 生成材质字符串 |T...|t
--- @param texture string|number 材质路径或FileID
--- @param height number|nil 高度 (默认 0=自动)
--- @param width number|nil 宽度 (默认 0=自动，通常与高度一致)
--- @param x number|nil X偏移
--- @param y number|nil Y偏移
function F:GetTextureString(texture, height, width, x, y)
    return string.format("|T%s:%s:%s:%s:%s|t", 
        texture, 
        height or 0, 
        width or height or 0, 
        x or 0, 
        y or 0
    )
end

--- 生成 Atlas 字符串 |A...|a
--- @param atlasName string Atlas名称
--- @param height number|nil 高度
--- @param width number|nil 宽度
--- @param x number|nil X偏移
--- @param y number|nil Y偏移
function F:GetAtlasString(atlasName, height, width, x, y)
    return string.format("|A:%s:%s:%s:%s:%s|a", 
        atlasName, 
        height or 0, 
        width or height or 0, 
        x or 0, 
        y or 0
    )
end

function F:GetTooltipAnchor(frame)
    if not GetScreenHeight or not frame then return "ANCHOR_BOTTOM" end
    if frame:GetBottom() < GetScreenHeight() / 2 then
       return "ANCHOR_TOP", 5
    else
       return "ANCHOR_BOTTOM", -5
    end
end
