-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
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
                    lowercaseFirst = {
                        type = "toggle", order = 4, width = "full",
                        name = L["Lowercase first letter"],
                        desc = L["Lowercase first letter desc"],
                        get = function() return Addon.db.profile.social.lowercaseFirst end,
                        set = function(_, v) Addon.db.profile.social.lowercaseFirst = v end,
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
            guildGroup = {
                type = "group", name = L["Guild"], inline = true, order = 6,
                args = {
                    guildGrats = {
                        type = "toggle", order = 1, width = "full",
                        name = L["Congratulate guild achievements"],
                        desc = L["Send grats when a guild member earns an achievement"],
                        get = function() return Addon.db.profile.social.guildGrats end,
                        set = function(_, v) Addon.db.profile.social.guildGrats = v end,
                    },
                    guildWelcome = {
                        type = "toggle", order = 2, width = "full",
                        name = L["Welcome new guild members"],
                        desc = L["Greet players who join the guild (max 2 per hour, once per player)"],
                        get = function() return Addon.db.profile.social.guildWelcome end,
                        set = function(_, v) Addon.db.profile.social.guildWelcome = v end,
                    },
                },
            },
            advanced = {
                type = "group", name = L["Advanced"], inline = true, order = 20,
                args = {
                    minimapIcon = {
                        type = "toggle",
                        name = L["Show minimap icon"],
                        desc = L["Show or hide the minimap button"],
                        order = 15,
                        width = "full",
                        get = function() return not Addon.db.profile.minimap.hide end,
                        set = function(_, val)
                            Addon.db.profile.minimap.hide = not val
                            Addon:UpdateMinimapIcon()
                        end,
                    },
                    testModeEnabled = {
                        type = "toggle",
                        name = L["Enable Test Mode"],
                        desc = L["Enable test mode desc"],
                        order = 17,
                        width = "full",
                        get = function() return Addon.db.profile.testMode end,
                        set = function(_, val)
                            Addon.db.profile.testMode = val
                            -- Same invalidation as the slash toggle: delayed sends
                            -- built under the previous mode must not fire
                            Addon.state.sendGeneration = Addon.state.sendGeneration + 1
                            if val then
                                Addon:Print("|cFFFF9900Simulation:|r |cFF00FF00ON|r")
                            else
                                Addon:Print("|cFFFF9900Simulation:|r |cFFFF0000OFF|r")
                                Addon:TestReset()
                                Addon.db.profile.debugMode = false
                            end
                            LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                        end,
                    },
                    resetWindowSize = {
                        type = "execute",
                        name = L["Reset window size"],
                        desc = L["Reset settings window to default size and position"],
                        order = 19,
                        width = 1.5,
                        func = function()
                            Addon.db.profile.configWindowStatus = nil
                            local AceConfigDialog = LibStub("AceConfigDialog-3.0")
                            local status = AceConfigDialog:GetStatusTable("AutoSay")
                            status.width = 1000
                            status.height = 900
                            status.top = nil
                            status.left = nil
                            local frame = AceConfigDialog.OpenFrames["AutoSay"]
                            if frame then
                                frame:SetWidth(1000)
                                frame:SetHeight(900)
                                frame.frame:ClearAllPoints()
                                frame.frame:SetPoint("CENTER")
                            end
                        end,
                    },
                    resetDefaults = {
                        type = "execute",
                        name = L["Reset to Defaults"],
                        desc = L["Reset defaults desc"],
                        order = 20,
                        width = 1.5,
                        confirm = true,
                        confirmText = L["Reset defaults confirm"],
                        func = function()
                            -- Snapshot before the reset flips it: a live simulation must be torn
                            -- down completely (fabricated M+ listing, pending batches, flow flag),
                            -- not just have its timers invalidated - but TestReset must NOT run
                            -- for a user who never touched test mode, since it re-arms mid-group
                            -- greeting/goodbye state
                            local wasTestMode = Addon.db.profile.testMode
                            -- ResetProfile fires OnProfileReset, and that callback stamps the
                            -- one-shot migrations - without it the next login would migrate the
                            -- freshly reset profile straight back off its defaults
                            Addon.db:ResetProfile()
                            -- ResetProfile only touches the profile, and "reset everything" has
                            -- to mean the character's own memory too: the budget it has spent
                            -- this hour, who it has already welcomed, and which phrase each pool
                            -- said last. Left behind, a fresh-looking config would still be
                            -- refusing to greet someone it met an hour ago.
                            Addon:ClearGateCounters()
                            Addon:ClearPhraseHistory()
                            if wasTestMode then
                                Addon:TestReset() -- bumps sendGeneration itself
                            else
                                -- Still invalidate delayed sends built before the reset. The
                                -- guild-login batch cannot rely on its own stale-generation
                                -- clear (a NEW login would cancel that timer and inherit the
                                -- names), so drop the batch here explicitly.
                                Addon.state.sendGeneration = Addon.state.sendGeneration + 1
                                if Addon.state.guildLoginTimer then
                                    Addon:CancelTimer(Addon.state.guildLoginTimer)
                                    Addon.state.guildLoginTimer = nil
                                end
                                Addon.state.pendingGuildLogins = {}
                            end
                            LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                            Addon:Print(L["Settings reset to defaults"])
                        end,
                    },
                },
            },
        },
    }
end
