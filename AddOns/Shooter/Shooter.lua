local Shooter = Shooter or {};

Shooter.frame = CreateFrame("Frame", "Shooter", UIParent);
Shooter.frame:SetFrameStrata("BACKGROUND");

Shooter.frame:SetScript("OnEvent",
  function ()
    C_Timer.After(1, Screenshot);
  end
);

Shooter.frame:RegisterEvent("ACHIEVEMENT_EARNED");
