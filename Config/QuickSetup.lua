local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local Kit = AutoSay.ConfigKit
local StyleCounts, TagSuffix = Kit.StyleCounts, Kit.TagSuffix

-- The styles mixed in beside the main one, as one line: the ticks live on the Style page
local function MixInSummary()
    local names = {}
    for _, id in ipairs(AutoSay.MessageStyles) do
        if id ~= Addon.db.profile.mainStyle then
            local _, selected = StyleCounts(id)
            if selected > 0 then names[#names + 1] = L["Style " .. id] end
        end
    end
    return L["Mix in"] .. ": |cFFFFFFFF" .. (#names > 0 and table.concat(names, ", ") or L["nothing"]) .. "|r"
end

local function SocialToggle(order, field, name, desc)
    return {
        type = "toggle", order = order, width = "full",
        name = name, desc = desc,
        get = function() return Addon.db.profile.social[field] end,
        set = function(_, v)
            Addon.db.profile.social[field] = v
            LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay") -- regrey the phrase lists
        end,
    }
end

Kit.Pages.general = function()
    return {
        type = "group",
        name = L["Quick setup"],
        order = 1,
        args = {
            enabled = {
                type = "toggle",
                name = L["Enable addon"],
                desc = L["Enable addon"],
                order = 1,
                width = "full",
                get = function() return Addon.db.profile.enabled end,
                set = function(_, val) Addon.db.profile.enabled = val end,
            },
            channelsGroup = {
                type = "group",
                name = L["Channels"],
                inline = true,
                order = 5,
                args = {
                    enableParty = {
                        type = "toggle",
                        name = L["Enable Party"],
                        desc = L["Send greetings and goodbyes in party chat"],
                        order = 1,
                        width = "full",
                        get = function() return Addon.db.profile.party.enabled end,
                        set = function(_, val)
                            Addon.db.profile.party.enabled = val
                            LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                        end,
                    },
                    enableRaid = {
                        type = "toggle",
                        name = L["Enable Raid"],
                        desc = L["Send greetings and goodbyes in raid chat"],
                        order = 2,
                        width = "full",
                        get = function() return Addon.db.profile.raid.enabled end,
                        set = function(_, val)
                            Addon.db.profile.raid.enabled = val
                            LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                        end,
                    },
                    -- Narrower than the other channel rows so its own qualifier sits
                    -- beside it instead of on a line of its own
                    enableInstance = {
                        type = "toggle",
                        name = L["Enable Instance"],
                        desc = L["Send greetings and goodbyes in instance chat"],
                        order = 3,
                        width = 1.0,
                        get = function() return Addon.db.profile.instance.enabled end,
                        set = function(_, val)
                            Addon.db.profile.instance.enabled = val
                            LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                        end,
                    },
                    skipRaidGroups = {
                        type = "toggle",
                        name = L["Skip LFR and battlegrounds"],
                        desc = L["Skip LFR and battlegrounds desc"],
                        order = 3.5,
                        width = 1.6,
                        hidden = function() return not Addon.db.profile.instance.enabled end,
                        get = function() return Addon.db.profile.instance.skipRaidGroups end,
                        set = function(_, val) Addon.db.profile.instance.skipRaidGroups = val end,
                    },
                    enableGuild = {
                        type = "toggle",
                        name = L["Enable Guild"],
                        desc = L["Send greetings and goodbyes to guild chat"],
                        order = 4,
                        width = "full",
                        get = function() return Addon.db.profile.guild.enabled end,
                        set = function(_, val)
                            Addon.db.profile.guild.enabled = val
                            LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                        end,
                    },
                    enableMythicPlus = {
                        type = "toggle",
                        name = L["Enable Mythic+"],
                        desc = L["Send key announcement in party chat when group is full"],
                        order = 5,
                        width = "full",
                        get = function() return Addon.db.profile.mythicplus.enabled end,
                        set = function(_, val)
                            Addon.db.profile.mythicplus.enabled = val
                            LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                        end,
                    },
                },
            },
            styleGroup = {
                type = "group",
                name = L["Style"],
                inline = true,
                order = 6,
                args = {
                    mainStyle = {
                        type = "select",
                        name = L["Main style"],
                        desc = L["Main style desc"],
                        order = 1,
                        width = 1.5,
                        values = function()
                            local v = { custom = L["Custom mix"] }
                            for _, id in ipairs(AutoSay.MessageStyles) do v[id] = L["Style " .. id] end
                            return v
                        end,
                        sorting = function()
                            local s = { "custom" }
                            for _, id in ipairs(AutoSay.MessageStyles) do s[#s + 1] = id end
                            return s
                        end,
                        get = function() return Addon.db.profile.mainStyle or "custom" end,
                        set = function(_, id)
                            if id == "custom" then
                                Addon.db.profile.mainStyle = nil
                                return
                            end
                            Addon.db.profile.mainStyle = id
                            Addon:ApplyStyleBundle(id, true, true)
                        end,
                        confirm = function(_, id)
                            if id == "custom" then return false end
                            return L["Main style confirm"]
                        end,
                    },
                    mainStyleVoice = {
                        type = "description",
                        order = 1.5,
                        fontSize = "medium",
                        hidden = function() return not Addon.db.profile.mainStyle end,
                        name = function()
                            local id = Addon.db.profile.mainStyle
                            return id and ("|cFFAAAAAA" .. L["Style " .. id .. " voice"] .. "|r") or ""
                        end,
                    },
                    mixIn = {
                        type = "description", order = 2, width = "full", fontSize = "medium",
                        name = MixInSummary,
                    },
                    editStyles = {
                        type = "execute", order = 1.2, width = 0.8,
                        name = L["Change styles"],
                        desc = L["Mix in desc"],
                        func = function() LibStub("AceConfigDialog-3.0"):SelectGroup("AutoSay", "style") end,
                    },
                    rolePhrases = SocialToggle(3, "rolePhrases",
                        L["Role-based phrases"]
                            .. " |A:roleicon-tiny-tank:14:14|a|A:roleicon-tiny-healer:14:14|a|A:roleicon-tiny-dps:14:14|a",
                        L["Role-based phrases desc"]),
                    timeOfDay = SocialToggle(4, "timeOfDay",
                        L["Time-of-day phrases"] .. TagSuffix("morning/evening/night"),
                        L["Time-of-day phrases desc"]),
                },
            },
            confirmGroup = {
                type = "group",
                name = L["Ask before sending"],
                inline = true,
                order = 7,
                args = {
                    confirmEnabled = {
                        type = "toggle",
                        name = L["Ask before sending"],
                        desc = L["Ask before sending desc"],
                        order = 1,
                        width = "full",
                        get = function() return Addon.db.profile.confirm.enabled end,
                        set = function(_, val) Addon:SetConfirmEnabled(val) end,
                    },
                    confirmTimeout = {
                        type = "range",
                        name = L["Panel timeout"],
                        desc = L["Panel timeout desc"],
                        order = 2,
                        min = 10,
                        max = 120,
                        step = 5,
                        hidden = function() return not Addon.db.profile.confirm.enabled end,
                        get = function() return Addon.db.profile.confirm.timeout end,
                        set = function(_, val) Addon.db.profile.confirm.timeout = val end,
                    },
                    confirmMove = {
                        type = "execute",
                        name = L["Move panel"],
                        desc = L["Move panel desc"],
                        order = 3,
                        hidden = function() return not Addon.db.profile.confirm.enabled end,
                        func = function() Addon:PreviewConfirmPanel() end,
                    },
                    confirmResetPosition = {
                        type = "execute",
                        name = L["Reset panel position"],
                        desc = L["Reset panel position desc"],
                        order = 4,
                        hidden = function() return not Addon.db.profile.confirm.enabled end,
                        func = function() Addon:ResetConfirmPanelPosition() end,
                    },
                },
            },
        },
    }
end
