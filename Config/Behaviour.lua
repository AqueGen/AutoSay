local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local Kit = AutoSay.ConfigKit

Kit.Pages.social = function()
    return {
        type = "group",
        name = L["Behaviour"],
        order = 5,
        args = {
            timingGroup = {
                type = "group", name = L["Timing"], inline = true, order = 1,
                args = {
                    -- Left at the default width so this pair sits side by side, the
                    -- same way the two sliders under Limits do
                    messageDelay = {
                        type = "range", order = 1, min = 0, max = 10, step = 0.5,
                        name = L["Message delay"],
                        desc = L["Delay before sending message (seconds)"],
                        get = function() return Addon.db.profile.messageDelay end,
                        set = function(_, val) Addon.db.profile.messageDelay = val end,
                    },
                    cooldown = {
                        type = "range", order = 2, min = 0, max = 60, step = 1,
                        name = L["Cooldown"],
                        desc = L["Minimum time between messages (seconds)"],
                        get = function() return Addon.db.profile.cooldown end,
                        set = function(_, val) Addon.db.profile.cooldown = val end,
                    },
                    typingDelay = {
                        type = "toggle", order = 3, width = "full",
                        name = L["Human typing delay"],
                        desc = L["Delay messages as if typed by hand"] .. "\n"
                            .. L["Human typing delay example"],
                        get = function() return Addon.db.profile.social.typingDelay end,
                        set = function(_, v) Addon.db.profile.social.typingDelay = v end,
                    },
                },
            },
            limitsGroup = {
                type = "group", name = L["Limits"], inline = true, order = 2,
                args = {
                    budgetPerHour = {
                        type = "range", order = 1, min = 4, max = 30, step = 1,
                        name = L["Hourly message budget"],
                        desc = L["Maximum automatic messages per hour, all triggers combined"],
                        get = function() return Addon.db.profile.social.budgetPerHour end,
                        set = function(_, v) Addon.db.profile.social.budgetPerHour = v end,
                    },
                    personCooldownHours = {
                        type = "range", order = 2, min = 1, max = 24, step = 1,
                        name = L["Per-person cooldown (hours)"],
                        desc = L["Do not target the same player more often than this"],
                        get = function() return Addon.db.profile.social.personCooldownHours end,
                        set = function(_, v) Addon.db.profile.social.personCooldownHours = v end,
                    },
                    listen = {
                        type = "toggle", order = 3, width = "full",
                        name = L["Social listening"],
                        desc = L["Skip a message if someone else already said it"] .. "\n"
                            .. L["Social listening example"],
                        get = function() return Addon.db.profile.social.listen end,
                        set = function(_, v) Addon.db.profile.social.listen = v end,
                    },
                },
            },
            guildGrats = {
                type = "toggle", order = 6, width = "full",
                name = L["Congratulate guild achievements"],
                desc = L["Send grats when a guild member earns an achievement"],
                get = function() return Addon.db.profile.social.guildGrats end,
                set = function(_, v) Addon.db.profile.social.guildGrats = v end,
            },
            guildWelcome = {
                type = "toggle", order = 7, width = "full",
                name = L["Welcome new guild members"],
                desc = L["Greet players who join the guild (max 2 per hour, once per player)"],
                get = function() return Addon.db.profile.social.guildWelcome end,
                set = function(_, v) Addon.db.profile.social.guildWelcome = v end,
            },
        },
    }
end
