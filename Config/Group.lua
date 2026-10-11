local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local Kit = AutoSay.ConfigKit
local TagSuffix, groupChannelKeys, MatrixChannels, ChannelIsOff, ChannelOffNotice, AddCaptionRow, AddMatrixRow, NoneOn, BuildMessageMatrix, AddCustomGroups = Kit.TagSuffix, Kit.groupChannelKeys, Kit.MatrixChannels, Kit.ChannelIsOff, Kit.ChannelOffNotice, Kit.AddCaptionRow, Kit.AddMatrixRow, Kit.NoneOn, Kit.BuildMessageMatrix, Kit.AddCustomGroups

-- Group greetings, one builder per occasion: arriving and welcoming are different moments
-- with different phrases, so each gets its own tab, its own trigger row and its own ticks.
-- Party, raid and instance share the grid, so a row reads "this setting, these channels".
local function BuildGroupGreetingsSelf()
    local channels = MatrixChannels(groupChannelKeys, "enabledGreetingsSelf", "greetingsSelf")
    local selfJoinDesc = {
        party = L["Send greeting when you join a party"],
        raid = L["Send greeting when you join a raid"],
        -- Instance groups greet on zone-in instead of on group form
        instance = L["Send greeting once after you zone into the instance"],
    }

    local triggers = {}
    triggers.offNotice = {
        type = "description", order = 0.5, width = "full",
        name = ChannelOffNotice(channels),
    }
    AddCaptionRow(triggers, "captions", 1, channels)
    AddMatrixRow(triggers, "onSelfJoin", 2, L["On self join"], nil, channels, function(ch)
            return {
                disabled = function() return ChannelIsOff(ch) end,
                desc = selfJoinDesc[ch.key],
                get = function() return Addon.db.profile[ch.key].onSelfJoin end,
                set = function(_, val)
                    Addon.db.profile[ch.key].onSelfJoin = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay") -- refilter the phrase lists
                end,
            }
        end)
    AddMatrixRow(triggers, "includeGroupNames", 3,
        L["Name the group when I join"] .. TagSuffix("names"),
        NoneOn(channels, "onSelfJoin"), channels, function(ch)
            return {
                -- Off with its channel as well as with its parent trigger: two reasons,
                -- one cell, and the channel one has to win rather than be overwritten
                disabled = function()
                    return ChannelIsOff(ch) or not Addon.db.profile[ch.key].onSelfJoin
                end,
                desc = L["Add names of current group members to the greeting"],
                get = function() return Addon.db.profile[ch.key].includeGroupNames end,
                set = function(_, val)
                    Addon.db.profile[ch.key].includeGroupNames = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                end,
            }
        end)

    local args = {
        triggersGroup = {
            type = "group", name = L["Triggers"], inline = true, order = 1, args = triggers,
        },
        messagesGroup = {
            type = "group", name = L["Messages"], inline = true, order = 2,
            args = BuildMessageMatrix("groupGreetingsSelf", AutoSay.Greetings, channels),
        },
    }
    AddCustomGroups(args, channels, "customGreetings", "Custom greetings", 10)
    return args
end

-- The other half of the same tab: what goes out when somebody arrives after you.
local function BuildGroupGreetingsOthers()
    local channels = MatrixChannels(groupChannelKeys, "enabledGreetingsOthers", "greetingsOthers")
    local othersJoinDesc = {
        party = L["Send greeting when others join your party"],
        raid = L["Send greeting when others join your raid"],
        instance = L["Send greeting when others join your instance group"],
    }
    local leaderOnlyDesc = {
        party = L["Only greet newcomers when you are the party leader"],
        raid = L["Only greet newcomers when you are the raid leader"],
        instance = L["Only greet newcomers when you are the group leader"],
    }

    local triggers = {}
    triggers.offNotice = {
        type = "description", order = 0.5, width = "full",
        name = ChannelOffNotice(channels),
    }
    AddCaptionRow(triggers, "captions", 1, channels)
    AddMatrixRow(triggers, "onOthersJoin", 2, L["On others join"], nil, channels, function(ch)
            return {
                disabled = function() return ChannelIsOff(ch) end,
                desc = othersJoinDesc[ch.key],
                get = function() return Addon.db.profile[ch.key].onOthersJoin end,
                set = function(_, val)
                    Addon.db.profile[ch.key].onOthersJoin = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay") -- refilter the phrase lists
                end,
            }
        end)
    AddMatrixRow(triggers, "onOthersJoinLeaderOnly", 3,
        L["Only if leader"], NoneOn(channels, "onOthersJoin"), channels, function(ch)
            return {
                disabled = function()
                    return ChannelIsOff(ch) or not Addon.db.profile[ch.key].onOthersJoin
                end,
                desc = leaderOnlyDesc[ch.key],
                get = function() return Addon.db.profile[ch.key].onOthersJoinLeaderOnly end,
                set = function(_, val) Addon.db.profile[ch.key].onOthersJoinLeaderOnly = val end,
            }
        end)
    AddMatrixRow(triggers, "includeNames", 4,
        L["Name whoever joined"] .. TagSuffix("names"),
        NoneOn(channels, "onOthersJoin"), channels, function(ch)
            return {
                disabled = function()
                    return ChannelIsOff(ch) or not Addon.db.profile[ch.key].onOthersJoin
                end,
                desc = L["Add joined player names to the greeting"],
                get = function() return Addon.db.profile[ch.key].includeNames end,
                set = function(_, val)
                    Addon.db.profile[ch.key].includeNames = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                end,
            }
        end)

    local args = {
        triggersGroup = {
            type = "group", name = L["Triggers"], inline = true, order = 1, args = triggers,
        },
        messagesGroup = {
            type = "group", name = L["Messages"], inline = true, order = 2,
            args = BuildMessageMatrix("groupGreetingsOthers", AutoSay.Greetings, channels),
        },
    }
    AddCustomGroups(args, channels, "customGreetings", "Custom greetings", 10)
    return args
end

-- Group goodbyes: same grid, a single trigger row
local function BuildGroupGoodbyes()
    local channels = MatrixChannels(groupChannelKeys, "enabledGoodbyes", "goodbyes")
    local goodbyeDesc = {
        party = L["Send goodbye when leaving party"],
        raid = L["Send goodbye when leaving raid"],
        instance = L["Send goodbye when leaving instance group"],
    }

    local triggers = {}
    triggers.offNotice = {
        type = "description", order = 0.5, width = "full",
        name = ChannelOffNotice(channels),
    }
    AddCaptionRow(triggers, "captions", 1, channels)
    AddMatrixRow(triggers, "sendGoodbye", 2,
        L["Send goodbye on leave"], nil, channels, function(ch)
            return {
                disabled = function() return ChannelIsOff(ch) end,
                desc = goodbyeDesc[ch.key],
                get = function() return Addon.db.profile[ch.key].sendGoodbye end,
                set = function(_, val) Addon.db.profile[ch.key].sendGoodbye = val end,
            }
        end)
    -- Its own row rather than a qualifier under the one above: the two occasions are
    -- independent, and either can be on without the other
    AddMatrixRow(triggers, "sendGoodbyeOnRunEnd", 3,
        L["Send goodbye when the run ends"], nil, channels, function(ch)
            return {
                disabled = function() return ChannelIsOff(ch) end,
                desc = L["Send goodbye when the run ends desc"],
                get = function() return Addon.db.profile[ch.key].sendGoodbyeOnRunEnd end,
                set = function(_, val) Addon.db.profile[ch.key].sendGoodbyeOnRunEnd = val end,
            }
        end)

    local args = {
        triggersGroup = {
            type = "group", name = L["Triggers"], inline = true, order = 1, args = triggers,
        },
        messagesGroup = {
            type = "group", name = L["Messages"], inline = true, order = 2,
            args = BuildMessageMatrix("groupGoodbyes", AutoSay.Goodbyes, channels),
        },
    }
    AddCustomGroups(args, channels, "customGoodbyes", "Custom goodbyes", 10)
    return args
end

-- Group reconnects: two columns only - an instance group is rejoined through the queue,
-- so it has no reconnect trigger and no reconnect phrases
local function BuildGroupReconnects()
    local channels = MatrixChannels({ "party", "raid" }, "enabledReconnects", "reconnects")
    local reconnectDesc = {
        party = L["Send greeting when you reconnect to party"],
        raid = L["Send greeting when you reconnect to raid"],
    }

    local triggers = {}
    triggers.offNotice = {
        type = "description", order = 0.5, width = "full",
        name = ChannelOffNotice(channels),
    }
    AddCaptionRow(triggers, "captions", 1, channels)
    AddMatrixRow(triggers, "onReconnect", 2, L["On reconnect"], nil, channels, function(ch)
        return {
            disabled = function() return ChannelIsOff(ch) end,
            desc = reconnectDesc[ch.key],
            get = function() return Addon.db.profile[ch.key].onReconnect end,
            set = function(_, val) Addon.db.profile[ch.key].onReconnect = val end,
        }
    end)
    triggers.instanceNote = {
        type = "description", order = 3, fontSize = "small",
        name = "|cFF888888" .. L["Reconnects instance note"] .. "|r",
    }

    local args = {
        triggersGroup = {
            type = "group", name = L["Triggers"], inline = true, order = 1, args = triggers,
        },
        messagesGroup = {
            type = "group", name = L["Messages"], inline = true, order = 2,
            args = BuildMessageMatrix("groupReconnects", AutoSay.Reconnects, channels),
        },
    }
    AddCustomGroups(args, channels, "customReconnects", "Custom reconnects", 10)
    return args
end

-- No per-channel hiding here: the tab shows all three columns whatever the General
-- switches say, and those switches keep doing the only job they ever had - gating sends.
Kit.Pages.group = function()
    return {
        type = "group",
        name = "|cFF33DDAA" .. L["Group"] .. "|r",
        order = 10,
        childGroups = "tab",
        args = {
            greetings = {
                type = "group",
                name = L["Greetings"],
                order = 1,
                childGroups = "tab",
                args = {
                    -- Two occasions, two tabs: the tab is the trigger, so no phrase
                    -- needs a [self] or [newcomers] tag to say which one it serves
                    selfJoin = {
                        type = "group", order = 1,
                        name = L["When I join"],
                        args = BuildGroupGreetingsSelf(),
                    },
                    othersJoin = {
                        type = "group", order = 2,
                        name = L["When someone joins"],
                        args = BuildGroupGreetingsOthers(),
                    },
                },
            },
            goodbyes = {
                type = "group",
                name = L["Goodbyes"],
                order = 2,
                args = BuildGroupGoodbyes(),
            },
            reconnects = {
                type = "group",
                name = L["Reconnects"],
                order = 3,
                args = BuildGroupReconnects(),
            },
        },
    }
end
