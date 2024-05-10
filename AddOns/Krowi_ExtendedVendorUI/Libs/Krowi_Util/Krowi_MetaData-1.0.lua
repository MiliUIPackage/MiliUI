--[[
    Copyright (c) 2023 Krowi

    All Rights Reserved unless otherwise explicitly stated.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]

local lib = LibStub("Krowi_Util-1.0");

if not lib then
	return;
end

lib.Metadata = {};
local metadata = lib.Metadata;

function metadata.GetAddOnMetadata(addonName)
    local title = GetAddOnMetadata(addonName, "Title");
    local prefix = GetAddOnMetadata(addonName, "X-Prefix");
    local acronym = GetAddOnMetadata(addonName, "X-Acronym");
    local build = GetBuildInfo();
    local version = GetAddOnMetadata(addonName, "Version");
    local author = GetAddOnMetadata(addonName, "Author");
    local icon = GetAddOnMetadata(addonName, "IconTexture");
    local discordInviteLink = GetAddOnMetadata(addonName, "X-Discord-Invite-Link");
    local discordServerName = GetAddOnMetadata(addonName, "X-Discord-Server-Name");
    local curseForge = GetAddOnMetadata(addonName, "X-CurseForge");
    local wago = GetAddOnMetadata(addonName, "X-Wago");
    local woWInterface = GetAddOnMetadata(addonName, "X-WoWInterface");

    return {
        AddonName = addonName,
        Title = title,
        Prefix = prefix,
        Acronym = acronym,
        Build = build,
        Version = version,
        BuildVersion = build .. "." .. version,
        Author = author,
        Icon = icon,
        DiscordInviteLink = discordInviteLink,
        DiscordServerName = discordServerName,
        CurseForge = curseForge,
        Wago = wago,
        WoWInterface = woWInterface
    };
end