local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions = LibStub("AceDBOptions-3.0")
local Kit = AutoSay.ConfigKit

-- Main options table. Built on first request, not at login: the tree is ~1300 closures deep and
-- most sessions never open the settings. AceConfig re-calls the getter, hence the memo.
local function BuildOptions()
    -- AceDB keeps the chosen profile per character (AutoSayDB.profileKeys is keyed by
    -- "Name - Realm"), so a warlock switched to a dark profile stays on it while the
    -- paladin keeps its own. The library's own tab already carries the Character and Class
    -- shortcuts, which is the whole feature: nothing here needs to know about classes.
    local profiles = AceDBOptions:GetOptionsTable(Addon.db)
    profiles.order = 90

    return {
    type = "group",
    name = "|cFF0099FFAuto|r|cFFFFD700Say|r",
    handler = Addon,
    args = {
        general = Kit.Pages.general(),
        style = Kit.Pages.style(),
        social = Kit.Pages.social(),
        group = Kit.Pages.group(),
        guild = Kit.Pages.guild(),
        mythicplus = Kit.Pages.mythicplus(),
        testMode = Kit.Pages.testMode(),
        profiles = profiles,
    },
    }
end

-- What the Blizzard AddOns tab shows: a door, not the room. The whole option
-- tree used to be embedded there, and it fits badly - the panel is narrower and
-- shorter than the phrase matrices need, so every list arrived with its columns
-- squeezed and its own scrollbar inside Blizzard's scrollbar. The standalone
-- window is the one this addon is designed around, and this is how you reach it
-- from where a player goes looking for addon settings.
local function BuildBlizzardStub()
    return {
        type = "group",
        name = "AutoSay",
        args = {
            open = {
                type = "execute",
                name = L["Open AutoSay settings"],
                desc = L["Open AutoSay settings desc"],
                order = 1,
                width = "double",
                func = function()
                    -- The settings panel sits on top of everything, so the
                    -- window would open behind it. Closing it first is what
                    -- makes the button feel like it did something.
                    if SettingsPanel and SettingsPanel:IsShown() then
                        HideUIPanel(SettingsPanel)
                    end
                    Addon:OpenConfig()
                end,
            },
            slash = {
                type = "description",
                name = "\n" .. L["Open AutoSay settings hint"],
                order = 2,
                fontSize = "medium",
            },
        },
    }
end

-- Register options
local options
function Addon:SetupConfig()
    AceConfig:RegisterOptionsTable("AutoSay", function()
        options = options or BuildOptions()
        return options
    end)

    -- Two tables on purpose: "AutoSay" is the real tree the standalone window
    -- draws, "AutoSay-Blizzard" is the stub the AddOns tab gets. Registering the
    -- real one in both places is what put the squeezed copy there.
    AceConfig:RegisterOptionsTable("AutoSay-Blizzard", BuildBlizzardStub)
    AceConfigDialog:AddToBlizOptions("AutoSay-Blizzard", "AutoSay")
end

-- Hook into OnInitialize to setup config
local origOnInitialize = Addon.OnInitialize
function Addon:OnInitialize()
    origOnInitialize(self)
    self:SetupConfig()
end
