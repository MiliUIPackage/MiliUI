local _, addon = ...

-- Constants
local THIRD_WIDTH = 1.25

local maxCameraZoomFactor
if not addon.IsRetail() then
  maxCameraZoomFactor = 3.4
else
  maxCameraZoomFactor = 2.6
end

-------------------------------------------------------------------------
-------------------------------------------------------------------------

function addon:CreateCameraOptions()
  local cameraOptions = {
    type = "group",
    childGroups = "tree",
    name = "鏡頭",
    args = {
      instructions = {
        type = "description",
        name = "這些選項可以調整鏡頭。",
        fontSize = "medium",
        order = 1,
      },
      -------------------------------------------------
      header = {
        type = "header",
        name = "",
        order = 10,
      },
      -- TODO: This might need more work for classic
      cameraDistanceMaxZoomFactor = {
        type = "range",
        name = MAX_FOLLOW_DIST,
        desc = OPTION_TOOLTIP_MAX_FOLLOW_DIST,
        min = 1,
        max = maxCameraZoomFactor,
        step = 0.1,
        get = function()
          return tonumber(C_CVar.GetCVar("cameraDistanceMaxZoomFactor"))
        end,
        set = function(_, value)
          self:SetCVar("cameraDistanceMaxZoomFactor", value)
        end,
        width = THIRD_WIDTH,
        order = 11,
      },
      -------------------------------------------------
      cameraCollisionHeader = {
        type = "header",
        name = "鏡頭碰撞",
        order = 20,
        --this feature is only supported in 11.0 at the moment
        hidden = function()
          return not addon.IsRetail()
        end,
      },
      cameraIndirectVisibility = {
        type = "toggle",
        name = "鏡頭間接可見性",
        desc = "在碰撞和推動鏡頭向前之前，允許玩家角色受到環境的更多阻礙。",
        get = function()
          return C_CVar.GetCVarBool("cameraIndirectVisibility")
        end,
        set = function(_, value)
          self:SetCVar("cameraIndirectVisibility", value)
        end,
        --this feature is only supported in 11.0 at the moment
        hidden = function()
          return not addon.IsRetail()
        end,
        width = THIRD_WIDTH,
        order = 21,
      },
      cameraIndirectOffset = {
        type = "range",
        name = "鏡頭間接偏移",
        desc = "啟用「鏡頭間接可見性」時控制鏡頭碰撞的靈敏度。 [0] 是最敏感，[10] 是最不敏感。",
        min = 1,
        max = 10,
        step = 0.1,
        get = function()
          return tonumber(C_CVar.GetCVar("cameraIndirectOffset"))
        end,
        set = function(_, value)
          self:SetCVar("cameraIndirectOffset", value)
        end,
        disabled = function()
          return not C_CVar.GetCVarBool("cameraIndirectVisibility")
        end,
        --this feature is only supported in 11.0 at the moment
        hidden = function()
          return not addon.IsRetail()
        end,
        width = THIRD_WIDTH,
        order = 22,
      },
      -------------------------------------------------
      actionCameraHeader = {
        type = "header",
        name = "動感鏡頭",
        order = 30,
      },
      actionCam = {
        type = "select",
        name = "選擇動感鏡頭模式:",
        desc = "選擇動感鏡頭模式。",
        values = {
          ["default"] = "預設",
          ["on"] = "開啟",
          ["basic"] = "基本",
          ["full"] = "完整",
        },
        sorting = {
          "default",
          "on",
          "basic",
          "full",
        },
        get = function()
          return self.getActionCamMode()
        end,
        set = function(_, value)
          ConsoleExec("actioncam" .. " " .. value)
        end,
        width = THIRD_WIDTH,
        order = 31,
      },
    }
  }

  return cameraOptions
end
