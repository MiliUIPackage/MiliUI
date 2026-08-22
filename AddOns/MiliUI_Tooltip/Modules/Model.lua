------------------------------------------------------------
-- 3D 模型（tooltip 右上角）
--
-- 放在 skin 上（自有框）。UnitFrames 的教訓照搬：
--   * 12.1 受限身分單位 SetUnit 會退回顯示玩家自己 → 先探針
--     IsSecret(UnitName(unit))，拿不到就什麼都不畫。
--   * 模型「隱藏時 SetUnit 會落空」→ 這裡每次顯示前都重新 SetUnit，
--     不依賴殘留狀態；清空用 ClearModel。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local Skin = ns.Skin

ns.Model = {}
local Model = ns.Model

local function Ensure(state)
    if state.model then return state.model end
    local model = CreateFrame("PlayerModel", nil, state.skin)
    model:SetSize(100, 100)
    model:SetFacing(-0.25)
    model:SetPoint("BOTTOMRIGHT", state.skin, "TOPRIGHT", 8, -16)
    model:Hide()
    model:SetScript("OnUpdate", function(self, elapsed)
        if IsControlKeyDown() or IsAltKeyDown() then
            self:SetFacing(self:GetFacing() + math.pi * elapsed)
        end
    end)
    state.model = model
    return model
end

function Model.OnUnit(tip, state, unit)
    if tip ~= GameTooltip then return end
    if not ns.db then return end
    if unit ~= "mouseover" then Model.Clear(tip) return end
    if not S.SafeBool(UnitExists, unit) or not S.SafeBool(UnitIsVisible, unit) then
        Model.Clear(tip)
        return
    end
    local isPlayer = S.SafeBool(UnitIsPlayer, unit)
    local show = (isPlayer and ns.db.unit.player.showModel)
        or (not isPlayer and ns.db.unit.npc.showModel)
    if not show then Model.Clear(tip) return end

    -- 受限身分探針：名字是秘密 ⇒ SetUnit 會退回畫玩家自己，寧可不畫
    local name = S.SafeCall(UnitName, unit)
    if S.IsSecret(name) then Model.Clear(tip) return end

    local model = Ensure(state)
    model:ClearModel()
    local ok = pcall(model.SetUnit, model, unit)
    if ok then
        model:SetFacing(-0.25)
        model:Show()
    else
        Model.Clear(tip)
    end
end

function Model.Clear(tip)
    local state = Skin.Get(tip)
    if state and state.model then
        state.model:ClearModel()
        state.model:Hide()
    end
end
