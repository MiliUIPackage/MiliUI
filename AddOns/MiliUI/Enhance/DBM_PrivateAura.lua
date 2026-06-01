------------------------------------------------------------
-- MiliUI DBM Private Aura
-- 抑制 DBM 私人光環的全部倒數文字，只保留乾淨圖示
------------------------------------------------------------
--
-- 私人光環文字的三條來源（11.x 起）：
--   1) showCountdownNumbers=true → 圖示內的小倒數
--   2) showCountdownFrame=true 會自動生成一段獨立 duration FontString；
--      唯一藏法是 durationAnchor 釘到螢幕外（Cell 在 Indicators/Built-in.lua 就是這樣處理）
--   3) PrivateAurasTextAnchorEnabled → SetPrivateWarningTextAnchor 的中央警告文字
--
-- DBM 預設三條全活，所以光改 DBM.Options 不夠。
--
-- 重要：絕對不能替換 C_UnitAuras.AddPrivateAuraAnchor，Blizzard 的 CompactUnitFrame
-- （centerDefensiveBuff 等）也會讀這個 API，addon 一旦把它換掉，整條 secure 路徑就被汙染，
-- 會炸 "attempt to perform boolean test on local 'checkedRange' (a secret boolean value)"
-- 之類的 secret-value 錯誤。
--
-- 因此改採「事後重註冊」策略：
--   * 包覆 DBM.PrivateAuras:RegisterPrivateAuras（只動 DBM 命名空間，不會汙染 Blizzard 路徑）
--   * 跑完 DBM 原始流程後，把它登記到 PAFrames[unit].Anchors 的主錨點全部 Remove，
--     再用我們的乾淨參數重新 Add：showCountdownNumbers=false、durationAnchor 釘到 frame 左方 -10000
--   * 順手把 StackAnchors 也清掉（它們只是為了承載 UpscaleDuration 的大字 anchor，沒它沒差）
--   * 包覆期間暫時關掉 PrivateAurasTextAnchorEnabled，DBM 不會去 SetPrivateWarningTextAnchor

local function ApplyHook()
    if not DBM or not DBM.PrivateAuras or not DBM.PrivateAuras.RegisterPrivateAuras then
        return false
    end
    if DBM.PrivateAuras._MiliUIPAHooked then return true end
    DBM.PrivateAuras._MiliUIPAHooked = true

    local orig = DBM.PrivateAuras.RegisterPrivateAuras
    DBM.PrivateAuras.RegisterPrivateAuras = function(self, unit, settingsOverwrite)
        local savedText = DBM.Options.PrivateAurasTextAnchorEnabled
        DBM.Options.PrivateAurasTextAnchorEnabled = false
        local ok, err = pcall(orig, self, unit, settingsOverwrite)
        DBM.Options.PrivateAurasTextAnchorEnabled = savedText
        if not ok then error(err) end

        local PAFrames = self.PAFrames and self.PAFrames[unit]
        if not PAFrames then return end

        -- 決定圖示尺寸（為了 HideTooltip 情境，frame 自身可能是 0.001，要看 settings）
        local width, height, hideBorder
        if settingsOverwrite then
            width      = settingsOverwrite.Width
            height     = settingsOverwrite.Height
            hideBorder = settingsOverwrite.HideBorder
        else
            local prefix = (unit == "player") and "PrivateAurasPlayer" or "PrivateAurasCoTank"
            width      = DBM.Options[prefix .. "Width"]
            height     = DBM.Options[prefix .. "Height"]
            hideBorder = DBM.Options[prefix .. "HideBorder"]
        end
        local borderScale = hideBorder and -100 or (width and width / 16) or 1

        -- 重註冊主錨點：保留 DBM 設好的 PAFrames[unit][auraIndex] 當 parent，
        -- 拔掉 DBM 加上去的錨點，用我們的乾淨參數重新登記。
        if PAFrames.Anchors then
            for auraIndex = 1, 10 do
                local anchorId = PAFrames.Anchors[auraIndex]
                local frame    = PAFrames[auraIndex]
                if anchorId and frame then
                    C_UnitAuras.RemovePrivateAuraAnchor(anchorId)
                    PAFrames.Anchors[auraIndex] = C_UnitAuras.AddPrivateAuraAnchor({
                        unitToken            = unit,
                        auraIndex            = auraIndex,
                        parent               = frame,
                        showCountdownFrame   = true,
                        showCountdownNumbers = false,
                        isContainer          = false,
                        iconInfo = {
                            iconAnchor = {
                                point        = "CENTER",
                                relativeTo   = frame,
                                relativePoint= "CENTER",
                                offsetX      = 0,
                                offsetY      = 0,
                            },
                            iconWidth   = width,
                            iconHeight  = height,
                            borderScale = borderScale,
                        },
                        -- 把 Blizzard 自動生成的 duration FontString 釘到螢幕外
                        durationAnchor = {
                            point        = "CENTER",
                            relativeTo   = frame,
                            relativePoint= "CENTER",
                            offsetX      = -10000,
                            offsetY      = 0,
                        },
                    })
                end
            end
        end

        -- StackAnchors 在 DBM 裡只負責 UpscaleDuration 的大字 anchor，沒它沒差，直接清掉。
        if PAFrames.StackAnchors then
            for auraIndex = 1, 10 do
                local anchorId = PAFrames.StackAnchors[auraIndex]
                if anchorId then
                    C_UnitAuras.RemovePrivateAuraAnchor(anchorId)
                    PAFrames.StackAnchors[auraIndex] = nil
                end
            end
        end
    end

    return true
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "DBM-Core" or arg1 == "MiliUI" then
            ApplyHook()
        end
    elseif event == "PLAYER_LOGIN" then
        ApplyHook()
    end
end)
