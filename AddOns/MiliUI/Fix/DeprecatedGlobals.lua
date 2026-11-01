------------------------------------------------------------
-- MiliUI: 12.1 移除的全域函式相容層
--
-- 12.1 從 FrameXML 移除了一批舊全域（見 Patch_12.1.0/API_changes 的
-- FrameXML Removed 清單）。有些第三方函式庫還在呼叫它們，而且是所有使用該
-- 函式庫的插件一起壞 —— 與其逐一去改函式庫（更新就被覆蓋、而且同一個函式庫
-- 常常有好幾份副本、只有版本最高的那份生效），不如把函式補回來。
--
-- 這些都是普通全域函式，不是受保護的 API，補回來沒有安全性問題。
------------------------------------------------------------
local AddonName, _ = ...
if AddonName ~= "MiliUI" then return end

-- SetDesaturation(texture, desaturate)
--
-- AceGUI-3.0 的 CheckBox widget（AceGUIWidget-CheckBox.lua 的 SetValue）還在用
-- 它。少了這個函式，任何 AceConfig 選項面板只要含有勾選框就會在建立時丟出
-- 「attempt to call a nil value」，整個面板變成一片空白 —— Stuf 的設定介面就是
-- 這樣壞的，而且 Masque、HandyNotes、Mapster 等等同樣中招。
--
-- 材質本身的 SetDesaturated 方法還在，所以直接轉呼叫即可。
if not SetDesaturation then
    function SetDesaturation(texture, desaturate)
        if texture and texture.SetDesaturated then
            texture:SetDesaturated(desaturate)
        end
    end
end

-- AnimateTexCoords(texture, texW, texH, frameW, frameH, numFrames, elapsed, throttle)
--
-- 12.1 把它收進 TextureUtil 表（Blizzard_SharedXMLBase/TextureUtil.lua 現在是
-- `function TextureUtil.AnimateTexCoords(...)`），全域名稱就沒了。
--
-- LibCustomGlow-1.0 的「按鈕發光」（ButtonGlow_Start）在 OnUpdate 裡用它跑爬行
-- 螞蟻動畫，v24 以前都是直接呼叫全域，因此一開啟這個發光類型就會每幀噴
-- 「attempt to call a nil value」—— Cell / MRT 帶的都是
-- 舊版副本。v25 起上游已改成先讀 TextureUtil，所以只要補回全域即可兩邊都活。
if not AnimateTexCoords and TextureUtil and TextureUtil.AnimateTexCoords then
    AnimateTexCoords = TextureUtil.AnimateTexCoords
end

-- GetItemInfo(item)
--
-- 12.1.5 把 Blizzard_DeprecatedItemScript 整支刪了，裡面那句
-- `GetItemInfo = C_Item.GetItemInfo` 跟著消失。12.1.0 以前它就只是這個別名，
-- 補回來等於回到 12.1.5 之前的狀態。
--
-- Auctionator 的專業視窗材料提示（Tooltips/Hooks.lua 的 SetRecipeReagentItem）
-- 還在裸呼叫它，滑過配方材料格就噴「attempt to call a nil value」。套組裡其他
-- 用到的插件都先取了 C_Item 的本地別名或有存在檢查，所以只補這一個。
if not GetItemInfo and C_Item and C_Item.GetItemInfo then
    GetItemInfo = C_Item.GetItemInfo
end

-- GetSpecialization() 系列（永恆版）
--
-- GetSpecialization／GetSpecializationInfo／GetActiveSpecGroup／
-- GetNumSpecializationsForClassID／GetSpecializationMasterySpells／GetTalentInfo
-- 這六個全域是 Blizzard_DeprecatedSpecialization 定義的，而那支插件的 TOC 是
-- `## AllowLoadGameType: classic, standard` —— 永恆版（camelot）不載入，六個全是
-- nil。GetSpecializationInfoByID／GetNumSpecializations／GetInspectSpecialization／
-- GetSpecializationRole 是 C 原生的，不在此限。
--
-- 套組裡裸呼叫前四個的有 CooldownManager、UnitFrames、InfoBar、QoL、DamageMeters、
-- Tooltip。照暴雪 Deprecated_Specialization_Standard.lua 的寫法補回來，正式服上
-- 暴雪那份已經載入，這裡的 `if not` 全部跳過。永恆版沒有專精，
-- C_SpecializationInfo.GetSpecialization() 回的是主天賦樹索引（暴雪自己的 Camelot 版
-- PaperDollFrame 也這麼用，沒點天賦時是 nil）；語意上怎麼對待是各插件自己的事。
if C_SpecializationInfo then
    if not GetNumSpecializationsForClassID then
        GetNumSpecializationsForClassID = C_SpecializationInfo.GetNumSpecializationsForClassID
    end
    if not GetSpecializationInfo then
        GetSpecializationInfo = C_SpecializationInfo.GetSpecializationInfo
    end
    if not GetSpecialization then
        GetSpecialization = C_SpecializationInfo.GetSpecialization
    end
    if not GetActiveSpecGroup then
        GetActiveSpecGroup = C_SpecializationInfo.GetActiveSpecGroup
    end
    if not GetSpecializationMasterySpells and C_SpecializationInfo.GetSpecializationMasterySpells then
        function GetSpecializationMasterySpells(specIndex, isInspect, isPet)
            local spells = C_SpecializationInfo.GetSpecializationMasterySpells(specIndex, isInspect, isPet)
            if not spells then return nil end
            return spells[1], spells[2]
        end
    end
    if not GetTalentInfo and C_SpecializationInfo.GetTalentInfo then
        function GetTalentInfo(tier, column, groupIndex, isInspect, target)
            local info = C_SpecializationInfo.GetTalentInfo({
                tier = tier, column = column, groupIndex = groupIndex,
                isInspect = isInspect, target = target,
            })
            if not info then return nil end
            return info.talentID, info.name, info.icon, info.selected, info.available, info.spellID,
                info.isPVPTalentUnlocked, info.tier, info.column, info.known, info.isGrantedByAura
        end
    end
end
