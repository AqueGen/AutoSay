-- Copyright (c) 2026 AqueGen. All rights reserved. See LICENSE.
local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local Kit = AutoSay.ConfigKit
local TagSuffix, groupChannelKeys, MatrixChannels, ChannelIsOff, ChannelOffNotice, AddCaptionRow, AddMatrixRow, BuildMessageMatrix, AddCustomGroups = Kit.TagSuffix, Kit.groupChannelKeys, Kit.MatrixChannels, Kit.ChannelIsOff, Kit.ChannelOffNotice, Kit.AddCaptionRow, Kit.AddMatrixRow, Kit.BuildMessageMatrix, Kit.AddCustomGroups

local function Refresh()
    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay") -- regrey the phrase lists
end

-- A trigger cell for one channel. A sub-option (parent set) is off with its channel as
-- well as with its parent trigger: two reasons, one cell, and the channel one has to win.
local function TriggerCell(field, desc, parent)
    return function(ch)
        return {
            disabled = function()
                return ChannelIsOff(ch) or (parent ~= nil and not Addon.db.profile[ch.key][parent])
            end,
            desc = type(desc) == "table" and desc[ch.key] or desc,
            get = function() return Addon.db.profile[ch.key][field] end,
            set = function(_, val)
                Addon.db.profile[ch.key][field] = val
                Refresh()
            end,
        }
    end
end

-- Every switch of the Group page in one grid: the rows are the moments, the columns the
-- chats. Instance is rejoined through the queue, so the reconnect row has no Instance cell.
local function BuildTriggers()
    local channels = MatrixChannels(groupChannelKeys, "enabledGreetingsSelf", "greetingsSelf")
    local reconnectChannels = MatrixChannels({ "party", "raid" }, "enabledReconnects", "reconnects")
    local args = {
        offNotice = {
            type = "description", order = 0.5, width = "full",
            name = ChannelOffNotice(channels),
        },
    }
    AddCaptionRow(args, "captions", 1, channels)
    AddMatrixRow(args, "onSelfJoin", 2, L["Greet when I join"], nil, channels,
        TriggerCell("onSelfJoin", {
            party = L["Send greeting when you join a party"],
            raid = L["Send greeting when you join a raid"],
            -- Instance groups greet on zone-in instead of on group form
            instance = L["Send greeting once after you zone into the instance"],
        }))
    AddMatrixRow(args, "includeGroupNames", 3, "    " .. L["Name the group when I join"] .. TagSuffix("names"),
        nil, channels,
        TriggerCell("includeGroupNames", L["Add names of current group members to the greeting"], "onSelfJoin"))
    AddMatrixRow(args, "onOthersJoin", 4, L["Greet when someone joins"], nil, channels,
        TriggerCell("onOthersJoin", {
            party = L["Send greeting when others join your party"],
            raid = L["Send greeting when others join your raid"],
            instance = L["Send greeting when others join your instance group"],
        }))
    AddMatrixRow(args, "onOthersJoinLeaderOnly", 5, "    " .. L["Only if leader"], nil, channels,
        TriggerCell("onOthersJoinLeaderOnly", {
            party = L["Only greet newcomers when you are the party leader"],
            raid = L["Only greet newcomers when you are the raid leader"],
            instance = L["Only greet newcomers when you are the group leader"],
        }, "onOthersJoin"))
    AddMatrixRow(args, "includeNames", 6, "    " .. L["Name whoever joined"] .. TagSuffix("names"), nil, channels,
        TriggerCell("includeNames", L["Add joined player names to the greeting"], "onOthersJoin"))
    AddMatrixRow(args, "sendGoodbye", 7, L["Send goodbye on leave"], nil, channels,
        TriggerCell("sendGoodbye", {
            party = L["Send goodbye when leaving party"],
            raid = L["Send goodbye when leaving raid"],
            instance = L["Send goodbye when leaving instance group"],
        }))
    -- Its own row rather than a qualifier of the one above: either can be on without the other
    AddMatrixRow(args, "sendGoodbyeOnRunEnd", 8, L["Send goodbye when the run ends"], nil, channels,
        TriggerCell("sendGoodbyeOnRunEnd", L["Send goodbye when the run ends desc"]))
    AddMatrixRow(args, "onReconnect", 9, L["On reconnect"], nil, reconnectChannels,
        TriggerCell("onReconnect", {
            party = L["Send greeting when you reconnect to party"],
            raid = L["Send greeting when you reconnect to raid"],
        }))
    return args
end

-- A phrase list page: the player's own lines on top, where they are found without scrolling
-- past the presets, then the ticks. The switches live on the Group page above.
local function ListPage(order, name, poolId, pool, channels, customsKey, customsLabel)
    local args = {
        messagesGroup = {
            type = "group", name = L["Messages"], inline = true, order = 20,
            args = BuildMessageMatrix(poolId, pool, channels),
        },
    }
    AddCustomGroups(args, channels, customsKey, customsLabel, 10)
    return { type = "group", order = order, name = name, args = args }
end

Kit.Pages.group = function()
    return {
        type = "group",
        name = L["Group"],
        order = 10,
        args = {
            overview = {
                type = "description", order = 0, fontSize = "medium",
                name = L["Group overview"],
            },
            triggersGroup = {
                type = "group", name = L["Triggers"], inline = true, order = 0.5,
                args = BuildTriggers(),
            },
            greetingsSelf = ListPage(1, L["When I join"], "groupGreetingsSelf", AutoSay.Greetings,
                MatrixChannels(groupChannelKeys, "enabledGreetingsSelf", "greetingsSelf"),
                "customGreetings", "Custom greetings both pages"),
            greetingsOthers = ListPage(2, L["When someone joins"], "groupGreetingsOthers", AutoSay.Greetings,
                MatrixChannels(groupChannelKeys, "enabledGreetingsOthers", "greetingsOthers"),
                "customGreetings", "Custom greetings both pages"),
            goodbyes = ListPage(3, L["Goodbyes"], "groupGoodbyes", AutoSay.Goodbyes,
                MatrixChannels(groupChannelKeys, "enabledGoodbyes", "goodbyes"),
                "customGoodbyes", "Custom goodbyes"),
            -- An instance group is rejoined through the queue: no reconnect list of its own
            reconnects = ListPage(4, L["Reconnects"], "groupReconnects", AutoSay.Reconnects,
                MatrixChannels({ "party", "raid" }, "enabledReconnects", "reconnects"),
                "customReconnects", "Custom reconnects"),
        },
    }
end
