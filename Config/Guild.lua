local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local Kit = AutoSay.ConfigKit
local MatrixChannels, BuildMessageMatrix, BuildCustomMessageList = Kit.MatrixChannels, Kit.BuildMessageMatrix, Kit.BuildCustomMessageList

-- Guild keeps the single-channel layout: one trigger, one plain phrase list.
-- The M+ pools have no channel and no trigger tags - one column, straight into db.profile.mythicplus.
local function BuildGuildGreetings()
    return {
        selfJoinGroup = {
            type = "group",
            name = L["On login"],
            inline = true,
            order = 1,
            args = {
                onSelfJoin = {
                    type = "toggle",
                    name = L["On login"],
                    desc = L["Send greeting when you log in"],
                    order = 1,
                    width = 1.2,
                    get = function() return Addon.db.profile.guild.onSelfJoin end,
                    set = function(_, val) Addon.db.profile.guild.onSelfJoin = val end,
                },
            },
        },
        messagesGroup = {
            type = "group",
            name = L["Messages"],
            inline = true,
            order = 2,
            args = BuildMessageMatrix("guildGreetings", AutoSay.Greetings,
                MatrixChannels({ "guild" }, "enabledGreetingsSelf", "greetingsSelf")),
        },
        customGroup = {
            type = "group",
            name = L["Custom greetings"],
            inline = true,
            order = 3,
            args = BuildCustomMessageList("guild", "customGreetings", "Custom greetings", "greetings"),
        },
    }
end

local function BuildGuildGoodbyes()
    return {
        triggersGroup = {
            type = "group",
            name = L["Triggers"],
            inline = true,
            order = 1,
            args = {
                sendGoodbye = {
                    type = "toggle",
                    name = L["On logout"],
                    desc = L["Send goodbye when you log out"],
                    order = 1,
                    width = 1.2,
                    get = function() return Addon.db.profile.guild.sendGoodbye end,
                    set = function(_, val) Addon.db.profile.guild.sendGoodbye = val end,
                },
            },
        },
        messagesGroup = {
            type = "group",
            name = L["Messages"],
            inline = true,
            order = 2,
            args = BuildMessageMatrix("guildGoodbyes", AutoSay.Goodbyes,
                MatrixChannels({ "guild" }, "enabledGoodbyes", "goodbyes")),
        },
        customGroup = {
            type = "group",
            name = L["Custom goodbyes"],
            inline = true,
            order = 3,
            args = BuildCustomMessageList("guild", "customGoodbyes", "Custom goodbyes", "goodbyes"),
        },
    }
end

-- Build guild member login greeting toggles
local function BuildGuildLoginToggles()
    local args = {}
    local order = 1

    -- Triggers panel
    args.triggersGroup = {
        type = "group",
        name = L["Triggers"],
        inline = true,
        order = order,
        args = {
            onMemberLogin = {
                type = "toggle",
                name = L["On member login"],
                desc = L["Send greeting when a guild member logs in"],
                order = 1,
                width = "full",
                get = function() return Addon.db.profile.guild.onMemberLogin end,
                set = function(_, val) Addon.db.profile.guild.onMemberLogin = val end,
            },
            memberLoginCooldown = {
                type = "range",
                name = L["Member login cooldown"],
                desc = L["Minimum time between guild member login greetings (seconds)"],
                order = 3,
                width = "full",
                min = 0,
                max = 60,
                step = 1,
                hidden = function() return not Addon.db.profile.guild.onMemberLogin end,
                get = function() return Addon.db.profile.guild.memberLoginCooldown end,
                set = function(_, val) Addon.db.profile.guild.memberLoginCooldown = val end,
            },
        },
    }
    order = order + 1

    -- Messages panel (style dropdown + the selected style's phrases)
    args.messagesGroup = {
        type = "group",
        name = L["Messages"],
        inline = true,
        order = order,
        args = BuildMessageMatrix("guildLoginGreetings", AutoSay.GuildLoginGreetings,
            MatrixChannels({ "guild" }, "enabledLoginGreetings", "login")),
    }
    order = order + 1

    -- Custom login greetings panel
    args.customGroup = {
        type = "group",
        name = L["Custom login greetings"],
        inline = true,
        order = order,
        args = BuildCustomMessageList("guild", "customLoginGreetings", "Custom login greetings", "login"),
    }
    order = order + 1

    args.placeholderNote = {
        type = "description",
        name = "|cFF888888" .. L["Guild login placeholder hint"] .. "|r",
        order = order,
        fontSize = "medium",
    }

    return args
end

Kit.Pages.guild = function()
    return {
        type = "group",
        name = "|cFF00CCFFGuild|r",
        order = 30,
        hidden = function() return not Addon.db.profile.guild.enabled end,
        args = {
            overview = {
                type = "description", order = 0, fontSize = "medium",
                name = L["Guild overview"],
            },
            greetings = {
                type = "group",
                name = L["Greetings"],
                order = 1,
                args = BuildGuildGreetings(),
            },
            goodbyes = {
                type = "group",
                name = L["Goodbyes"],
                order = 2,
                args = BuildGuildGoodbyes(),
            },
            -- Member Login tab hidden until feature is fully working
            -- memberLogin = {
            --     type = "group",
            --     name = L["Member Login"],
            --     order = 3,
            --     args = BuildGuildLoginToggles(),
            -- },
        },
    }
end
