local addonName, addon = ...

function addon:initWarbandTransferable()
    if not addon.db.profile.warbandTransferable then return end

    TokenFrame.ScrollBox:HookScript("OnShow", function()
        for _, frame in pairs(TokenFrame.ScrollBox.view.frames) do
            if frame.Content and frame.RefreshAccountCurrencyIcon then
                function frame:RefreshAccountCurrencyIcon()
                	if self.elementData.isAccountWide then
                		self.Content.AccountWideIcon.Icon:SetAtlas("warbands-icon", TextureKitConstants.UseAtlasSize);
                		self.Content.AccountWideIcon.Icon:SetScale(0.9);
                	elseif self.elementData.isAccountTransferable then
                		self.Content.AccountWideIcon.Icon:SetAtlas("warbands-transferable-icon", TextureKitConstants.UseAtlasSize);
                		self.Content.AccountWideIcon.Icon:SetScale(0.9);
                	else
                		self.Content.AccountWideIcon.Icon:SetAtlas(nil);
                	end

                	self.Content.AccountWideIcon:SetShown(self.Content.AccountWideIcon.Icon:GetAtlas() ~= nil);
                end
            end
        end
    end)

end
