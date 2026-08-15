local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local MAX_CUSTOM_MESSAGES = 10

local ADDON_VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON_NAME, "Version") or ""
-- Append a green "New!" while the addon version still matches the minor release the option shipped in.
-- Auto-expires on the next minor: NewTag("Style", "1.6") stops matching once 1.7.0 ships.
local function NewTag(name, ver)
    if AutoSay.MessageLogic.VersionMatchesMinor(ADDON_VERSION, ver) then
        return name .. " |cFF00FF00New!|r"
    end
    return name
end

-- Style bundle picker state (UI only, deliberately not saved to the profile)
local replaceOnApply = false

-- Per-pool accordion fold state: shownStyle[poolId][style] = open (UI only, not saved)
local shownStyle = {}

-- Word shown for a per-phrase trigger tag
local triggerWords = { self = "self", others = "newcomers" }

-- The same grey [tag] the phrase rows use, for the switches that control that tag -
-- seeing [newcomers] on both ends makes the wiring obvious
local function TagSuffix(word)
    return " |cFF888888[" .. word .. "]|r"
end

-- Checkbox label for a preset message: tagged phrases carry a grey suffix, style word first,
-- then the role/faction tag, then the trigger: [fun, tank, self].
-- Inside its own style group the style word is redundant, so it is left out.
-- Time-of-day phrases have no style word, just their band: [morning] / [evening] / [night].
local function PresetLabel(msg, ownStyleGroup)
    if msg.band then return msg.text .. " |cFF888888[" .. msg.band .. "]|r" end
    local tags = {}
    if msg.style and not ownStyleGroup then table.insert(tags, msg.style) end
    if msg.role then
        -- The role reads best as its group-finder icon, not a word
        table.insert(tags, string.format("|A:roleicon-tiny-%s:14:14|a", AutoSay.RoleWords[msg.role] or "dps"))
    elseif msg.faction then
        table.insert(tags, msg.faction:lower())
    end
    if msg.trigger then table.insert(tags, triggerWords[msg.trigger] or msg.trigger) end
    if #tags == 0 then return msg.text end
    return msg.text .. " |cFF888888[" .. table.concat(tags, ", ") .. "]|r"
end

-- Role-tagged rows are never hidden or greyed by the character's class: the profile can be
-- shared across characters (mage today, tank alt tomorrow), so every role stays configurable.
-- The runtime pick already filters by the actual current role.

-- A phrase is ACTIVE only while every tag it depends on is switched on (AND semantics):
-- [newcomers] needs On others join, [self] needs On self join, a {names} slot needs the
-- names option, role phrases need the master switch. An inactive phrase stays visible but
-- greyed out - the tag on its row points at the switch that re-activates it.
-- settingsFn is nil for pools without trigger context (goodbyes/reconnects/guild login).
local function PhraseActive(msg, settingsFn)
    local roleDependent = msg.role or msg.text:find("{role}", 1, true)
    if roleDependent and not Addon.db.profile.social.rolePhrases then return false end
    if msg.band and not Addon.db.profile.social.timeOfDay then return false end
    if not settingsFn then return true end
    local settings = settingsFn()
    if msg.trigger == "others" and not settings.onOthersJoin then return false end
    if msg.trigger == "self" and not settings.onSelfJoin then return false end
    -- {names} rows are deliberately NOT greyed when the names options are off: the runtime
    -- still sends them with the slot stripped ("welcome {names}!" -> "welcome!"), so a grey
    -- row would claim "unused" about a phrase that is very much in play (and on guild, which
    -- has no names options at all, it would lock the row for good)
    return true
end

-- Channels sharing the Group tab, in AutoSay.Channels order (guild keeps its own tab)
local groupChannelKeys = {}
for _, c in ipairs(AutoSay.Channels) do
    if c.key ~= "guild" then groupChannelKeys[#groupChannelKeys + 1] = c.key end
end

local channelLabel = {
    party = L["Party"], raid = L["Raid"], instance = L["Instance"], guild = L["Guild"],
}

-- A matrix row is one flow row: a label cell plus one narrow checkbox per channel.
-- The caption row and every content row share these widths - change one, change them all
-- or the columns stop lining up (2.0 + 3*0.55 still fits the 4-wide dialog, and 0.55
-- is wide enough for the full "Instance" caption).
local MATRIX_LABEL_WIDTH, MATRIX_COL_WIDTH = 2.0, 0.55

-- Channel descriptors for a shared matrix: which profile table each column writes to
local function MatrixChannels(keys, enabledKey, withTriggers)
    local channels = {}
    for _, key in ipairs(keys) do
        channels[#channels + 1] = {
            key = key,
            tableFn = function() return Addon.db.profile[key][enabledKey] end,
            settingsFn = withTriggers and function() return Addon.db.profile[key] end or nil,
        }
    end
    return channels
end

-- AceConfig numeric widths are fixed pixels while the flow layout packs a visual line
-- until it runs out of window: on a wide window two logical rows interleave. A zero-text
-- full-width description after each row forces the line break, whatever the window width.
local function AddRowBreak(args, key, order, hidden)
    args[key .. "_brk"] = {
        type = "description", name = "", order = order,
        width = "full", hidden = hidden,
    }
end

-- Header row naming the columns: an empty cell under the labels, then a channel name per column
local function AddCaptionRow(args, key, order, channels, hidden)
    args[key] = {
        type = "description", name = " ", order = order,
        width = MATRIX_LABEL_WIDTH, hidden = hidden,
    }
    for i, ch in ipairs(channels) do
        args[key .. "_" .. ch.key] = {
            type = "description", order = order + i * 0.1,
            name = "|cFFFFD100" .. (channelLabel[ch.key] or "") .. "|r",
            width = MATRIX_COL_WIDTH, hidden = hidden,
        }
    end
    AddRowBreak(args, key, order + #channels * 0.1 + 0.01, hidden)
end

-- One matrix row. The cells are bare checkboxes, so each carries the column name as its
-- tooltip. hidden applies to the whole row on purpose: hiding a single cell would slide
-- every column right of it one place left.
local function AddMatrixRow(args, key, order, label, hidden, channels, cellFn)
    args[key] = {
        type = "description", name = label, order = order, fontSize = "medium",
        width = MATRIX_LABEL_WIDTH, hidden = hidden,
    }
    for i, ch in ipairs(channels) do
        local cell = cellFn(ch)
        cell.type = "toggle"
        cell.name = ""
        cell.desc = cell.desc and (channelLabel[ch.key] .. ": " .. cell.desc) or channelLabel[ch.key]
        cell.order = order + i * 0.1
        cell.width = MATRIX_COL_WIDTH
        cell.hidden = hidden
        args[key .. "_" .. ch.key] = cell
    end
    AddRowBreak(args, key, order + #channels * 0.1 + 0.01, hidden)
end

-- Hide a dependent row only once no channel has its parent switched on
local function NoneOn(channels, field)
    return function()
        for _, ch in ipairs(channels) do
            if Addon.db.profile[ch.key][field] then return false end
        end
        return true
    end
end

-- Style-grouped preset picker for one message pool: an accordion of style sections.
-- Each section header is a full-width button that folds/unfolds its rows;
-- "Classic" (every untagged phrase) starts open, styles start folded.
-- poolId keys the fold state; channels is a list of { key, tableFn, settingsFn } - one entry
-- renders the plain single-column list, several render the shared checkbox matrix.
local function BuildMessageMatrix(poolId, pool, channels)
    local matrix = #channels > 1
    local args = {}

    -- Greyed rows are gated elsewhere - point at the tab that re-activates them
    if channels[1].settingsFn then
        args.tagNote = {
            type = "description", order = 0.5, fontSize = "small",
            name = "|cFF888888" .. L["Tag navigation note"] .. "|r",
        }
    end

    local byStyle = { classic = {} }
    for _, msg in ipairs(pool) do
        local style = msg.style or (msg.band and "timeofday") or "classic"
        byStyle[style] = byStyle[style] or {}
        table.insert(byStyle[style], msg)
    end

    local styles = { "classic" }
    if byStyle.timeofday then styles[#styles + 1] = "timeofday" end
    for _, style in ipairs(AutoSay.MessageStyles) do
        -- classic is already the first section: it is a bundle id, not a phrase tag
        if style ~= "classic" and byStyle[style] then styles[#styles + 1] = style end
    end

    -- Single column reads top-to-bottom, so give it an order: untagged first, then grouped
    -- by tag (morning/evening/night, self before newcomers, tank/healer/dps), then alphabet
    local bandOrder = { morning = 1, evening = 2, night = 3 }
    local triggerOrder = { self = 1, others = 2 }
    local roleOrder = { TANK = 1, HEALER = 2, DAMAGER = 3 }
    local function PhraseSort(a, b)
        local av, bv = bandOrder[a.band] or 0, bandOrder[b.band] or 0
        if av ~= bv then return av < bv end
        av, bv = triggerOrder[a.trigger] or 0, triggerOrder[b.trigger] or 0
        if av ~= bv then return av < bv end
        av, bv = roleOrder[a.role] or 0, roleOrder[b.role] or 0
        if av ~= bv then return av < bv end
        return a.text:lower() < b.text:lower()
    end
    for _, bucket in pairs(byStyle) do
        table.sort(bucket, PhraseSort)
    end

    shownStyle[poolId] = shownStyle[poolId] or { classic = true }
    local open = shownStyle[poolId]

    local order = 1
    for _, style in ipairs(styles) do
        local entries = byStyle[style]
        local label
        if style == "classic" then
            label = L["Classic"]
        elseif style == "timeofday" then
            label = NewTag(L["Time of day"], "1.6")
        else
            label = NewTag(L["Style " .. style], "1.6")
        end

        local folded = function() return #styles > 1 and not open[style] end

        -- Pools without style phrases (guild login greetings) get a plain list, no accordion
        if #styles > 1 then
            args["head_" .. style] = {
                type = "execute", order = order, width = "full",
                dialogControl = "AutoSayCollapse",
                -- The leading "-"/"+" is the fold-state contract: AutoSayCollapse
                -- strips it and renders it as the [-]/[+] expand icon.
                -- Single channel: "active right now / whole category", active meaning enabled
                -- AND currently eligible by the tag filters. In the matrix a summed count over
                -- three channels would mean nothing, so it shows the category size instead -
                -- the checkboxes already say which channel uses what.
                name = function()
                    local count
                    if matrix then
                        count = string.format(L["%d phrases"], #entries)
                    else
                        local active = 0
                        local flags = channels[1].tableFn()
                        for _, msg in ipairs(entries) do
                            if flags[msg.key] and PhraseActive(msg, channels[1].settingsFn) then
                                active = active + 1
                            end
                        end
                        count = string.format("%d/%d", active, #entries)
                    end
                    return string.format("%s %s  |cFF888888(%s)|r",
                        open[style] and "-" or "+", label, count)
                end,
                func = function()
                    open[style] = not open[style]
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                end,
            }
            order = order + 1

            if matrix then
                AddCaptionRow(args, "cap_" .. style, order, channels, folded)
                order = order + 1
            end
        end

        for _, msg in ipairs(entries) do
            local rowLabel = PresetLabel(msg, msg.style ~= nil)
            if matrix then
                AddMatrixRow(args, "m_" .. msg.key, order, rowLabel, folded, channels, function(ch)
                    return {
                        -- Greyed out, not gone: the row's tag names the switch that re-activates it
                        disabled = function() return not PhraseActive(msg, ch.settingsFn) end,
                        get = function() return ch.tableFn()[msg.key] end,
                        set = function(_, val)
                            ch.tableFn()[msg.key] = val
                            Addon:InvalidateBundleCache()
                        end,
                    }
                end)
            else
                local ch = channels[1]
                args["m_" .. msg.key] = {
                    type = "toggle",
                    name = rowLabel,
                    order = order,
                    -- One column: tags must be readable without hovering, folding beats truncation
                    width = "full",
                    hidden = folded,
                    disabled = function() return not PhraseActive(msg, ch.settingsFn) end,
                    get = function() return ch.tableFn()[msg.key] end,
                    set = function(_, val)
                        ch.tableFn()[msg.key] = val
                        Addon:InvalidateBundleCache()
                    end,
                }
            end
            order = order + 1
        end
    end

    return args
end

-- Build a custom message list UI group for any message type
-- Pre-allocates all MAX_CUSTOM_MESSAGES slots with hidden functions
-- so that add/delete dynamically shows/hides entries via NotifyChange.
local function BuildCustomMessageList(channel, customsKey, labelKey)
    local args = {}

    -- Header showing count
    args.header = {
        type = "description",
        name = function()
            local n = #(Addon.db.profile[channel][customsKey] or {})
            return L[labelKey] .. " (" .. n .. "/" .. MAX_CUSTOM_MESSAGES .. ")"
        end,
        order = 1,
        fontSize = "medium",
    }

    -- Pre-allocate all possible message slots (hidden when idx > current count)
    for i = 1, MAX_CUSTOM_MESSAGES do
        local idx = i
        local baseOrder = 10 + (i - 1) * 3

        args["toggle_" .. idx] = {
            type = "toggle",
            name = function()
                local entry = (Addon.db.profile[channel][customsKey] or {})[idx]
                return entry and entry.text or ""
            end,
            order = baseOrder,
            width = 2.5,
            hidden = function()
                return idx > #(Addon.db.profile[channel][customsKey] or {})
            end,
            -- A custom {role} text obeys the same master switch as the preset role rows -
            -- grey it the same way, or the list would show an active row that never fires
            disabled = function()
                local entry = (Addon.db.profile[channel][customsKey] or {})[idx]
                return entry and entry.text and entry.text:find("{role}", 1, true)
                    and not Addon.db.profile.social.rolePhrases or false
            end,
            get = function()
                local entry = (Addon.db.profile[channel][customsKey] or {})[idx]
                return entry and entry.enabled or false
            end,
            set = function(_, val)
                local entry = (Addon.db.profile[channel][customsKey] or {})[idx]
                if entry then entry.enabled = val end
            end,
        }

        args["delete_" .. idx] = {
            type = "execute",
            name = L["Delete"],
            order = baseOrder + 1,
            width = 0.5,
            hidden = function()
                return idx > #(Addon.db.profile[channel][customsKey] or {})
            end,
            func = function()
                local list = Addon.db.profile[channel][customsKey]
                if list then
                    table.remove(list, idx)
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                end
            end,
        }
    end

    -- New message input — pressing Okay/Enter directly adds the message
    args.newMessageInput = {
        type = "input",
        name = L["Add"],
        order = 10 + MAX_CUSTOM_MESSAGES * 3,
        width = "full",
        hidden = function()
            return #(Addon.db.profile[channel][customsKey] or {}) >= MAX_CUSTOM_MESSAGES
        end,
        validate = function(_, val)
            -- SendChatMessage errors out above 255 bytes
            if val and #val > 255 then return L["Message is too long (max 255 characters)"] end
            return true
        end,
        get = function() return "" end,
        set = function(_, val)
            if val and val ~= "" then
                -- {dungeon}/{key} only resolve on the M+ path; elsewhere they are stripped
                -- on send. Accept the text, but say so once per session.
                local hasMPlusToken = false
                for _, token in ipairs(AutoSay.MPlusTokens) do
                    if val:find(token, 1, true) then hasMPlusToken = true end
                end
                if channel ~= "mythicplus" and not Addon.mplusTokenHintShown and hasMPlusToken then
                    Addon.mplusTokenHintShown = true
                    Addon:Print(L["Mythic+ placeholders ({dungeon}, {key}, {upgrade}, {time}) only work in Mythic+ messages - they are removed from other messages."])
                end

                local list = Addon.db.profile[channel][customsKey]
                if not list then
                    list = {}
                    Addon.db.profile[channel][customsKey] = list
                end
                if #list < MAX_CUSTOM_MESSAGES then
                    table.insert(list, { text = val, enabled = true })
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                end
            end
        end,
    }

    return args
end

-- Custom messages stay per channel - one inline list each, under the shared matrix
local function AddCustomGroups(args, channels, customsKey, labelKey, order)
    for i, ch in ipairs(channels) do
        args["custom_" .. ch.key] = {
            type = "group",
            name = channelLabel[ch.key],
            inline = true,
            order = order + i,
            args = BuildCustomMessageList(ch.key, customsKey, labelKey),
        }
    end
end

-- Group greetings: party, raid and instance share one phrase list, one column each.
-- The trigger switches use the same grid, so a row reads "this setting, these channels".
local function BuildGroupGreetings()
    local channels = MatrixChannels(groupChannelKeys, "enabledGreetings", true)
    local selfJoinDesc = {
        party = L["Send greeting when you join a party"],
        raid = L["Send greeting when you join a raid"],
        -- Instance groups greet on zone-in instead of on group form
        instance = L["Send greeting once after you zone into the instance"],
    }
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
    AddCaptionRow(triggers, "captions", 1, channels)
    AddMatrixRow(triggers, "onSelfJoin", 2,
        L["On self join"] .. TagSuffix("self"), nil, channels, function(ch)
            return {
                desc = selfJoinDesc[ch.key],
                get = function() return Addon.db.profile[ch.key].onSelfJoin end,
                set = function(_, val)
                    Addon.db.profile[ch.key].onSelfJoin = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay") -- refilter the phrase lists
                end,
            }
        end)
    AddMatrixRow(triggers, "includeGroupNames", 3,
        L["Include group member names"] .. TagSuffix("{names}"),
        NoneOn(channels, "onSelfJoin"), channels, function(ch)
            return {
                desc = L["Add names of current group members to the greeting"],
                disabled = function() return not Addon.db.profile[ch.key].onSelfJoin end,
                get = function() return Addon.db.profile[ch.key].includeGroupNames end,
                set = function(_, val)
                    Addon.db.profile[ch.key].includeGroupNames = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay") -- refilter the phrase lists
                end,
            }
        end)
    AddMatrixRow(triggers, "onOthersJoin", 4,
        L["On others join"] .. TagSuffix("newcomers"), nil, channels, function(ch)
            return {
                desc = othersJoinDesc[ch.key],
                get = function() return Addon.db.profile[ch.key].onOthersJoin end,
                set = function(_, val)
                    Addon.db.profile[ch.key].onOthersJoin = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay") -- refilter the phrase lists
                end,
            }
        end)
    AddMatrixRow(triggers, "onOthersJoinLeaderOnly", 5,
        L["Only if leader"], NoneOn(channels, "onOthersJoin"), channels, function(ch)
            return {
                desc = leaderOnlyDesc[ch.key],
                disabled = function() return not Addon.db.profile[ch.key].onOthersJoin end,
                get = function() return Addon.db.profile[ch.key].onOthersJoinLeaderOnly end,
                set = function(_, val) Addon.db.profile[ch.key].onOthersJoinLeaderOnly = val end,
            }
        end)
    AddMatrixRow(triggers, "includeNames", 6,
        L["Include player names"] .. TagSuffix("{names}"),
        NoneOn(channels, "onOthersJoin"), channels, function(ch)
            return {
                desc = L["Add joined player names to the greeting"],
                disabled = function() return not Addon.db.profile[ch.key].onOthersJoin end,
                get = function() return Addon.db.profile[ch.key].includeNames end,
                set = function(_, val)
                    Addon.db.profile[ch.key].includeNames = val
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay") -- refilter the phrase lists
                end,
            }
        end)

    local args = {
        triggersGroup = {
            type = "group", name = L["Triggers"], inline = true, order = 1, args = triggers,
        },
        messagesGroup = {
            type = "group", name = L["Messages"], inline = true, order = 2,
            args = BuildMessageMatrix("groupGreetings", AutoSay.Greetings, channels),
        },
    }
    AddCustomGroups(args, channels, "customGreetings", "Custom greetings", 10)
    return args
end

-- Group goodbyes: same grid, a single trigger row
local function BuildGroupGoodbyes()
    local channels = MatrixChannels(groupChannelKeys, "enabledGoodbyes")
    local goodbyeDesc = {
        party = L["Send goodbye when leaving party"],
        raid = L["Send goodbye when leaving raid"],
        instance = L["Send goodbye when leaving instance group"],
    }

    local triggers = {}
    AddCaptionRow(triggers, "captions", 1, channels)
    AddMatrixRow(triggers, "sendGoodbye", 2,
        L["Send goodbye on leave"], nil, channels, function(ch)
            return {
                desc = goodbyeDesc[ch.key],
                get = function() return Addon.db.profile[ch.key].sendGoodbye end,
                set = function(_, val) Addon.db.profile[ch.key].sendGoodbye = val end,
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
    local channels = MatrixChannels({ "party", "raid" }, "enabledReconnects")
    local reconnectDesc = {
        party = L["Send greeting when you reconnect to party"],
        raid = L["Send greeting when you reconnect to raid"],
    }

    local triggers = {}
    AddCaptionRow(triggers, "captions", 1, channels)
    AddMatrixRow(triggers, "onReconnect", 2, L["On reconnect"], nil, channels, function(ch)
        return {
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
                MatrixChannels({ "guild" }, "enabledGreetings", true)),
        },
        customGroup = {
            type = "group",
            name = L["Custom greetings"],
            inline = true,
            order = 3,
            args = BuildCustomMessageList("guild", "customGreetings", "Custom greetings"),
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
                MatrixChannels({ "guild" }, "enabledGoodbyes")),
        },
        customGroup = {
            type = "group",
            name = L["Custom goodbyes"],
            inline = true,
            order = 3,
            args = BuildCustomMessageList("guild", "customGoodbyes", "Custom goodbyes"),
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
            MatrixChannels({ "guild" }, "enabledLoginGreetings")),
    }
    order = order + 1

    -- Custom login greetings panel
    args.customGroup = {
        type = "group",
        name = L["Custom login greetings"],
        inline = true,
        order = order,
        args = BuildCustomMessageList("guild", "customLoginGreetings", "Custom login greetings"),
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

-- Tooltip body of a style bundle button: its phrases, one line per AutoSay.StylePools header
-- (both completion pools share the "Completion" header, so they merge into a single line).
-- Cached per style - eight multi-line listings are not worth building for a tooltip nobody hovers.
--- Does this bundle lean towards the class the player is on right now?
local function BundleSuitsPlayer(style)
    local tokens = AutoSay.StyleClasses[style]
    if not tokens then return false end
    local _, playerClass = UnitClass("player")
    for _, token in ipairs(tokens) do
        if token == playerClass then return true end
    end
    return false
end

local bundleDescCache = {}
local function BundleDesc(style)
    local desc = bundleDescCache[style]
    if desc then return desc end

    -- Counts, not the phrases themselves: a bundle holds dozens of lines, and a tooltip
    -- that listed them buried the one thing the button had to say. The phrases live on the
    -- Group, Guild and Mythic+ tabs, where they can be read and ticked one at a time.
    local order, counts = {}, {}
    for _, pool in ipairs(AutoSay.StylePools) do
        local n = 0
        for _, msg in ipairs(AutoSay[pool.messages]) do
            if AutoSay.MessageLogic.StyleMatches(msg, style) then n = n + 1 end
        end
        if n > 0 then
            if not counts[pool.header] then order[#order + 1] = pool.header end
            counts[pool.header] = (counts[pool.header] or 0) + n
        end
    end
    local lines = {}
    for j, header in ipairs(order) do
        lines[j] = "|cFFFFD100" .. L[header] .. ":|r " .. string.format(L["%d phrases"], counts[header])
    end

    desc = table.concat(lines, "\n") .. "\n\n" .. L["Bundle button hint"]
    bundleDescCache[style] = desc
    return desc
end

-- Main options table. Built on first request, not at login: the tree is ~1300 closures deep and
-- most sessions never open the settings. AceConfig re-calls the getter, hence the memo.
local function BuildOptions()
    return {
    type = "group",
    name = "|cFF0099FFAuto|r|cFFFFD700Say|r",
    handler = Addon,
    args = {
        -- General settings
        general = {
            type = "group",
            name = L["General"],
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
                minimapIcon = {
                    type = "toggle",
                    name = L["Show minimap icon"],
                    desc = L["Show or hide the minimap button"],
                    order = 2,
                    width = "full",
                    get = function() return not Addon.db.profile.minimap.hide end,
                    set = function(_, val)
                        Addon.db.profile.minimap.hide = not val
                        Addon:UpdateMinimapIcon()
                    end,
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
                            name = NewTag(L["Enable Instance"], "1.6"),
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
                            name = NewTag(L["Skip LFR and battlegrounds"], "1.6"),
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
                timingGroup = {
                    type = "group",
                    name = L["Timing"],
                    inline = true,
                    order = 10,
                    args = {
                        messageDelay = {
                            type = "range",
                            name = L["Message delay"],
                            desc = L["Delay before sending message (seconds)"],
                            order = 1,
                            min = 0,
                            max = 10,
                            step = 0.5,
                            width = "full",
                            get = function() return Addon.db.profile.messageDelay end,
                            set = function(_, val) Addon.db.profile.messageDelay = val end,
                        },
                        cooldown = {
                            type = "range",
                            name = L["Cooldown"],
                            desc = L["Minimum time between messages (seconds)"],
                            order = 2,
                            min = 0,
                            max = 60,
                            step = 1,
                            width = "full",
                            get = function() return Addon.db.profile.cooldown end,
                            set = function(_, val) Addon.db.profile.cooldown = val end,
                        },
                    },
                },
                testModeGroup = {
                    type = "group",
                    name = L["Test Mode"],
                    inline = true,
                    order = 17,
                    args = {
                        testModeEnabled = {
                            type = "toggle",
                            name = L["Enable Test Mode"],
                            desc = L["Enable test mode desc"],
                            order = 1,
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
                    },
                },
                resetWindowSize = {
                    type = "execute",
                    name = L["Reset window size"],
                    desc = L["Reset settings window to default size and position"],
                    order = 19,
                    width = "full",
                    func = function()
                        Addon.db.profile.configWindowStatus = nil
                        local AceConfigDialog = LibStub("AceConfigDialog-3.0")
                        local status = AceConfigDialog:GetStatusTable("AutoSay")
                        status.width = 1000
                        status.height = 700
                        status.top = nil
                        status.left = nil
                        local frame = AceConfigDialog.OpenFrames["AutoSay"]
                        if frame then
                            frame:SetWidth(1000)
                            frame:SetHeight(700)
                            frame.frame:ClearAllPoints()
                            frame.frame:SetPoint("CENTER")
                        end
                    end,
                },
                resetDefaults = {
                    type = "execute",
                    name = L["Reset to Defaults"],
                    desc = L["Reset all settings to default values"],
                    order = 20,
                    width = "full",
                    confirm = true,
                    confirmText = L["Are you sure you want to reset all settings to defaults?"],
                    func = function()
                        -- Snapshot before the reset flips it: a live simulation must be torn
                        -- down completely (fabricated M+ listing, pending batches, flow flag),
                        -- not just have its timers invalidated - but TestReset must NOT run
                        -- for a user who never touched test mode, since it re-arms mid-group
                        -- greeting/goodbye state
                        local wasTestMode = Addon.db.profile.testMode
                        Addon.db:ResetProfile()
                        -- The reset wipes the one-shot migration stamps back to their defaults;
                        -- without re-stamping, the next login would re-run MigrateInstanceChannel
                        -- and overwrite the instance settings chosen after this reset
                        -- The OnProfileReset callback stamps the one-shot migrations; without
                        -- that, the next login would migrate the freshly reset profile
                        Addon:StampMigrationsDone()
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
                        Addon:InvalidateBundleCache()
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                        Addon:Print(L["Settings reset to defaults"])
                    end,
                },
            },
        },

        -- === STYLE ===
        style = {
            type = "group",
            name = NewTag(L["Style"], "1.6"),
            order = 3,
            args = {
                styleBundles = {
                    type = "group", order = 1, inline = true,
                    name = NewTag(L["Message style bundles"], "1.6"),
                    args = (function()
                        local args = {
                            desc = {
                                type = "description", order = 1,
                                name = L["Style bundle desc"],
                            },
                            replace = {
                                type = "toggle", order = 2, width = "full",
                                name = NewTag(L["Replace current selection"], "1.6"),
                                desc = L["Replace current selection desc"],
                                get = function() return replaceOnApply end,
                                set = function(_, v) replaceOnApply = v end,
                            },
                        }
                        -- One button per bundle: click applies it; the tooltip counts what it
                        -- holds, built on first hover of that button (see BundleDesc)
                        for i, style in ipairs(AutoSay.MessageStyles) do
                            args["bundle_" .. style] = {
                                type = "execute", order = 10 + i, width = 0.9,
                                -- Green name = bundle fully enabled; clicking then disables it
                                name = function()
                                    local label = NewTag(L["Style " .. style], "1.6")
                                    if Addon:IsStyleBundleEnabled(style) then
                                        return "|cFF00FF00" .. label .. "|r"
                                    end
                                    return label
                                end,
                                desc = function() return BundleDesc(style) end,
                                confirm = function()
                                    return Addon:IsStyleBundleEnabled(style)
                                        and L["Disable this bundle on all channels?"]
                                        or L["Apply this bundle to all channels?"]
                                end,
                                func = function()
                                    local state = not Addon:IsStyleBundleEnabled(style)
                                    Addon:ApplyStyleBundle(style, replaceOnApply, state)
                                end,
                            }
                        end
                        -- Under the buttons rather than inside each tooltip: the one line
                        -- that is actually about this character should not need a hover.
                        -- Bundles with no class leaning are simply not mentioned here.
                        args.classHint = {
                            type = "description", order = 100, width = "full",
                            name = function()
                                local names = {}
                                for _, style in ipairs(AutoSay.MessageStyles) do
                                    if BundleSuitsPlayer(style) then
                                        names[#names + 1] = L["Style " .. style]
                                    end
                                end
                                if #names == 0 then return "" end
                                local _, playerClass = UnitClass("player")
                                local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[playerClass]
                                local list = table.concat(names, ", ")
                                return "|cFFFFD100" .. L["Often suits"] .. ":|r "
                                    .. (color and color:WrapTextInColorCode(list) or list)
                            end,
                        }
                        return args
                    end)(),
                },
                rolePhrases = {
                    type = "toggle", order = 1.5, width = "full",
                    name = NewTag(L["Role-based phrases"], "1.6")
                        .. " |A:roleicon-tiny-tank:14:14|a|A:roleicon-tiny-healer:14:14|a|A:roleicon-tiny-dps:14:14|a",
                    desc = L["Role-based phrases desc"],
                    get = function() return Addon.db.profile.social.rolePhrases end,
                    set = function(_, v)
                        Addon.db.profile.social.rolePhrases = v
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay") -- refilter the phrase lists
                    end,
                },
                roleEnableAll = {
                    type = "execute", order = 1.6, width = 0.7,
                    name = L["Enable all"],
                    desc = L["Enable every role phrase on every channel"],
                    confirm = true, confirmText = L["Enable all role phrases on every channel?"],
                    func = function() Addon:SetTaggedPhrasesEnabled("role", true) end,
                },
                roleDisableAll = {
                    type = "execute", order = 1.7, width = 0.7,
                    name = L["Disable all"],
                    desc = L["Disable every role phrase on every channel"],
                    confirm = true, confirmText = L["Disable all role phrases on every channel?"],
                    func = function() Addon:SetTaggedPhrasesEnabled("role", false) end,
                },
                timeOfDay = {
                    type = "toggle", order = 2, width = "full",
                    name = L["Time-of-day phrases"] .. TagSuffix("morning/evening/night"),
                    desc = L["Time-of-day phrases desc"],
                    get = function() return Addon.db.profile.social.timeOfDay end,
                    set = function(_, v)
                        Addon.db.profile.social.timeOfDay = v
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                    end,
                },
                bandEnableAll = {
                    type = "execute", order = 2.1, width = 0.7,
                    name = L["Enable all"],
                    desc = L["Enable every time-of-day phrase on every channel"],
                    confirm = true, confirmText = L["Enable all time-of-day phrases on every channel?"],
                    func = function() Addon:SetTaggedPhrasesEnabled("band", true) end,
                },
                bandDisableAll = {
                    type = "execute", order = 2.2, width = 0.7,
                    name = L["Disable all"],
                    desc = L["Disable every time-of-day phrase on every channel"],
                    confirm = true, confirmText = L["Disable all time-of-day phrases on every channel?"],
                    func = function() Addon:SetTaggedPhrasesEnabled("band", false) end,
                },
                tone = {
                    type = "group", order = 4, inline = true,
                    name = NewTag(L["Tone"], "1.6"),
                    args = {
                        lowercaseFirst = {
                            type = "toggle", order = 1, width = "full",
                            name = NewTag(L["Lowercase first letter"], "1.6"),
                            desc = L["Lowercase first letter desc"],
                            get = function() return Addon.db.profile.social.lowercaseFirst end,
                            set = function(_, v) Addon.db.profile.social.lowercaseFirst = v end,
                        },
                    },
                },
            },
        },

        -- === SOCIAL ===
        social = {
            type = "group",
            name = L["Social"],
            order = 5,
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
                typingDelay = {
                    type = "toggle", order = 4, width = "full",
                    name = L["Human typing delay"],
                    desc = L["Delay messages as if typed by hand"] .. "\n"
                        .. L["Human typing delay example"],
                    get = function() return Addon.db.profile.social.typingDelay end,
                    set = function(_, v) Addon.db.profile.social.typingDelay = v end,
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
        },

        -- === GROUP (party / raid / instance share one phrase list) ===
        -- No per-channel hiding here: the tab shows all three columns whatever the General
        -- switches say, and those switches keep doing the only job they ever had - gating sends.
        group = {
            type = "group",
            name = NewTag("|cFF33DDAA" .. L["Group"] .. "|r", "1.6"),
            order = 10,
            childGroups = "tab",
            args = {
                greetings = {
                    type = "group",
                    name = L["Greetings"],
                    order = 1,
                    args = BuildGroupGreetings(),
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
        },

        -- === GUILD ===
        guild = {
            type = "group",
            name = "|cFF00CCFFGuild|r",
            order = 30,
            childGroups = "tab",
            hidden = function() return not Addon.db.profile.guild.enabled end,
            args = {
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
        },

        -- === MYTHIC+ ===
        mythicplus = {
            type = "group",
            name = "|cFFFF00FFMythic+|r",
            order = 35,
            childGroups = "tab",
            hidden = function() return not Addon.db.profile.mythicplus.enabled end,
            args = {
                -- Tab 1: Group Ready (key announce when group fills 5/5)
                groupReady = {
                    type = "group",
                    name = L["Group Ready"],
                    order = 1,
                    args = {
                        settingsGroup = {
                            type = "group",
                            name = L["Settings"],
                            inline = true,
                            order = 1,
                            args = {
                                announceOnFull = {
                                    type = "toggle",
                                    name = L["Announce when group is full"],
                                    desc = L["Send a message when your M+ group reaches 5 players"],
                                    order = 1,
                                    width = "full",
                                    get = function() return Addon.db.profile.mythicplus.announceOnFull end,
                                    set = function(_, val) Addon.db.profile.mythicplus.announceOnFull = val end,
                                },
                                announceOnStart = {
                                    type = "toggle",
                                    name = NewTag(L["Announce at key start"], "1.6"),
                                    desc = L["Announce at key start desc"],
                                    order = 2,
                                    width = "full",
                                    get = function() return Addon.db.profile.mythicplus.announceOnStart end,
                                    set = function(_, val) Addon.db.profile.mythicplus.announceOnStart = val end,
                                },
                                howItWorks = {
                                    type = "description",
                                    name = "|cFF888888" .. L["M+ how it works"] .. "|r",
                                    order = 3,
                                    fontSize = "medium",
                                },
                                includeKeyLevel = {
                                    type = "toggle",
                                    name = NewTag(L["Include key level"], "1.6"),
                                    desc = L["Include key level desc"],
                                    order = 4,
                                    width = "full",
                                    get = function() return Addon.db.profile.mythicplus.includeKeyLevel end,
                                    set = function(_, val) Addon.db.profile.mythicplus.includeKeyLevel = val end,
                                },
                            },
                        },
                        dungeonNamesGroup = {
                            type = "group",
                            name = L["Dungeon Names"],
                            inline = true,
                            order = 3,
                            args = {
                                useClientLanguage = {
                                    type = "toggle",
                                    name = L["Use client language for dungeon names"],
                                    desc = L["Use client language for dungeon names desc"],
                                    order = 1,
                                    width = "full",
                                    get = function() return Addon.db.profile.mythicplus.useClientLanguage end,
                                    set = function(_, val)
                                        Addon.db.profile.mythicplus.useClientLanguage = val
                                        LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                                    end,
                                },
                                dungeonNamesPreview = {
                                    type = "description",
                                    name = function()
                                        local useClient = Addon.db.profile.mythicplus.useClientLanguage
                                        local names = {}
                                        for id, enName in pairs(AutoSay.DungeonNames) do
                                            if useClient then
                                                local localName = select(1, C_ChallengeMode.GetMapUIInfo(id))
                                                names[#names + 1] = localName or enName
                                            else
                                                names[#names + 1] = enName
                                            end
                                        end
                                        -- pairs order is unstable: without a sort the rows reshuffle on every redraw
                                        table.sort(names)
                                        -- Split into two rows of 4
                                        local half = math.ceil(#names / 2)
                                        local row1 = {}
                                        local row2 = {}
                                        for i, n in ipairs(names) do
                                            if i <= half then
                                                row1[#row1 + 1] = "|cFFFFFFFF" .. n .. "|r"
                                            else
                                                row2[#row2 + 1] = "|cFFFFFFFF" .. n .. "|r"
                                            end
                                        end
                                        return table.concat(row1, ",  ") .. "\n" .. table.concat(row2, ",  ")
                                    end,
                                    order = 2,
                                    width = "full",
                                    fontSize = "medium",
                                },
                            },
                        },
                        messagesGroup = {
                            type = "group",
                            name = L["Messages"],
                            inline = true,
                            order = 10,
                            args = BuildMessageMatrix("mplusKeyAnnounce", AutoSay.KeyAnnounce,
                                MatrixChannels({ "mythicplus" }, "enabledKeyAnnounce")),
                        },
                        customGroup = {
                            type = "group",
                            name = L["Custom Messages"],
                            inline = true,
                            order = 12,
                            args = BuildCustomMessageList("mythicplus", "customKeyAnnounce", "Custom Messages"),
                        },
                        placeholderNote = {
                            type = "description",
                            name = "|cFF888888" .. L["Placeholder hint"] .. "|r",
                            order = 13,
                            fontSize = "medium",
                        },
                    },
                },
                -- Tab 2: Completion, itself split into On time / Depleted sub-tabs
                completion = {
                    type = "group",
                    name = L["Completion Messages"],
                    order = 2,
                    childGroups = "tab",
                    args = {
                        -- Non-group args render above the sub-tab strip
                        completionEnabled = {
                            type = "toggle",
                            name = L["Send message on completion"],
                            desc = L["Send a message to party chat when a M+ dungeon is completed"],
                            order = 1,
                            width = "full",
                            get = function() return Addon.db.profile.mythicplus.completionEnabled end,
                            set = function(_, val) Addon.db.profile.mythicplus.completionEnabled = val end,
                        },
                        timed = {
                            type = "group",
                            name = L["On time"],
                            order = 10,
                            args = {
                                messages = {
                                    type = "group",
                                    name = L["Messages"],
                                    inline = true,
                                    order = 1,
                                    args = BuildMessageMatrix("mplusCompletionTimed", AutoSay.CompletionTimed,
                                        MatrixChannels({ "mythicplus" }, "enabledCompletionTimed")),
                                },
                                customs = {
                                    type = "group",
                                    name = L["Custom timed messages"],
                                    inline = true,
                                    order = 2,
                                    args = BuildCustomMessageList("mythicplus", "customCompletionTimed", "Custom timed messages"),
                                },
                                placeholderNote = {
                                    type = "description",
                                    name = "\n|cFF888888" .. L["Completion placeholder hint"] .. "|r",
                                    order = 3,
                                    fontSize = "medium",
                                },
                            },
                        },
                        depleted = {
                            type = "group",
                            name = L["Depleted"],
                            order = 20,
                            args = {
                                messages = {
                                    type = "group",
                                    name = L["Messages"],
                                    inline = true,
                                    order = 1,
                                    args = BuildMessageMatrix("mplusCompletionDepleted", AutoSay.CompletionDepleted,
                                        MatrixChannels({ "mythicplus" }, "enabledCompletionDepleted")),
                                },
                                customs = {
                                    type = "group",
                                    name = L["Custom depleted messages"],
                                    inline = true,
                                    order = 2,
                                    args = BuildCustomMessageList("mythicplus", "customCompletionDepleted", "Custom depleted messages"),
                                },
                                placeholderNote = {
                                    type = "description",
                                    name = "\n|cFF888888" .. L["Completion placeholder hint"] .. "|r",
                                    order = 3,
                                    fontSize = "medium",
                                },
                            },
                        },
                    },
                },
            },
        },

        -- Test mode settings
        testMode = {
            type = "group",
            name = L["Test Mode"],
            order = 50,
            hidden = function() return not Addon.db.profile.testMode end,
            args = {
                description = {
                    type = "description",
                    name = L["Test mode description"],
                    order = 0,
                    fontSize = "medium",
                },
                simulateGroupEvents = {
                    type = "group",
                    name = L["Party"] .. " / " .. L["Raid"],
                    inline = true,
                    order = 10,
                    args = {
                        simulateParty = {
                            type = "execute",
                            name = L["Join Party"],
                            desc = L["Simulate joining a party"],
                            order = 1,
                            width = 0.8,
                            func = function() Addon:TestJoinParty() end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                        simulateRaid = {
                            type = "execute",
                            name = L["Join Raid"],
                            desc = L["Simulate joining a raid"],
                            order = 2,
                            width = 0.8,
                            func = function() Addon:TestJoinRaid() end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                        simulateInstance = {
                            type = "execute",
                            name = NewTag(L["Enter Instance"], "1.6"),
                            desc = L["Simulate zoning into an instance group"],
                            order = 2.5,
                            width = 1.0,
                            func = function() Addon:TestJoinInstance() end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                        simulateLeave = {
                            type = "execute",
                            name = L["Leave Group"],
                            desc = L["Simulate leaving current group"],
                            order = 3,
                            width = 0.8,
                            func = function() Addon:TestLeaveGroup() end,
                            disabled = function() return not Addon.db.profile.testMode or not Addon.testState.simulatedGroupType end,
                        },
                        simulateReconnect = {
                            type = "execute",
                            name = L["Reconnect"],
                            desc = L["Simulate reconnecting to group"],
                            order = 4,
                            width = 0.8,
                            func = function() Addon:TestReconnect() end,
                            disabled = function() return not Addon.db.profile.testMode or not Addon.testState.simulatedGroupType end,
                        },
                        simulatePlayerJoin = {
                            type = "execute",
                            name = L["Random Player Joins"],
                            desc = L["Simulate a random player joining your group"],
                            order = 5,
                            width = 1.0,
                            func = function() Addon:TestPlayerJoins() end,
                            disabled = function() return not Addon.db.profile.testMode or not Addon.testState.simulatedGroupType end,
                        },
                    },
                },
                simulateGuildEvents = {
                    type = "group",
                    name = L["Guild"],
                    inline = true,
                    order = 20,
                    args = {
                        simulateGuild = {
                            type = "execute",
                            name = L["Guild Greeting"],
                            desc = L["Simulate guild login greeting"],
                            order = 1,
                            width = 0.8,
                            func = function() Addon:TestGuildGreeting() end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                        simulateGuildBye = {
                            type = "execute",
                            name = L["Guild Goodbye"],
                            desc = L["Simulate guild logout goodbye"],
                            order = 2,
                            width = 0.8,
                            func = function() Addon:TestGuildGoodbye() end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                        -- Guild Member Login simulation hidden until feature is fully working
                        -- simulateGuildMemberLogin = {
                        --     type = "execute",
                        --     name = L["Guild Member Login"],
                        --     desc = L["Simulate a guild member logging in"],
                        --     order = 3,
                        --     width = 1.0,
                        --     func = function() Addon:TestGuildMemberLogin() end,
                        --     disabled = function() return not Addon.db.profile.testMode end,
                        -- },
                    },
                },
                simulateMythicPlus = {
                    type = "group",
                    name = L["Mythic+"],
                    inline = true,
                    order = 25,
                    args = {
                        simulateRole = {
                            type = "select",
                            name = L["Simulate role"],
                            desc = L["Simulate role desc"],
                            order = 1,
                            width = 0.8,
                            values = {
                                leader = L["Leader"],
                                joined = L["Joined"],
                            },
                            sorting = { "leader", "joined" },
                            get = function() return Addon.testState.mythicPlusRole end,
                            set = function(_, val) Addon.testState.mythicPlusRole = val end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                        simulateKeyAnnounce = {
                            type = "execute",
                            name = L["Simulate M+ Flow"],
                            desc = L["Simulate M+ flow desc"],
                            order = 2,
                            width = 1.2,
                            func = function() Addon:TestMythicPlusFlow() end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                        simulateKeyStart = {
                            type = "execute",
                            name = NewTag(L["Simulate Key Start"], "1.6"),
                            desc = L["Simulate key start desc"],
                            order = 3,
                            width = 1.2,
                            func = function() Addon:TestKeyStart() end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                        simulateTimed = {
                            type = "execute",
                            name = L["Simulate Timed"],
                            desc = L["Simulate completing a timed M+ key"],
                            order = 4,
                            width = 1.0,
                            func = function() Addon:TestCompletionTimed() end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                        simulateDepleted = {
                            type = "execute",
                            name = L["Simulate Depleted"],
                            desc = L["Simulate completing a depleted M+ key"],
                            order = 5,
                            width = 1.0,
                            func = function() Addon:TestCompletionDepleted() end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                    },
                },
                simulationContext = {
                    type = "group",
                    name = NewTag(L["Simulation context"], "1.6"),
                    inline = true,
                    order = 27,
                    args = {
                        simulateAssignedRole = {
                            type = "select",
                            name = NewTag(L["Simulate assigned role"], "1.6"),
                            desc = L["Simulate assigned role desc"],
                            order = 1,
                            width = 0.8,
                            values = {
                                TANK = L["Tank"],
                                HEALER = L["Healer"],
                                DAMAGER = L["DPS"],
                            },
                            sorting = { "TANK", "HEALER", "DAMAGER" },
                            get = function() return Addon.testState.simulatedRole end,
                            set = function(_, val) Addon.testState.simulatedRole = val end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                        simulateRealTime = {
                            type = "toggle",
                            name = NewTag(L["Use real time"], "1.6"),
                            desc = L["Use real time desc"],
                            order = 2,
                            width = 0.8,
                            get = function() return Addon.testState.simulatedHour == nil end,
                            set = function(_, val)
                                if val then
                                    Addon.testState.simulatedHour = nil
                                else
                                    Addon.testState.simulatedHour = tonumber(date("%H"))
                                end
                            end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                        simulateHour = {
                            type = "range",
                            name = NewTag(L["Simulate hour"], "1.6"),
                            desc = L["Simulate hour desc"],
                            order = 3,
                            width = 1.5,
                            min = 0, max = 23, step = 1,
                            get = function() return Addon.testState.simulatedHour or tonumber(date("%H")) end,
                            set = function(_, val) Addon.testState.simulatedHour = val end,
                            disabled = function() return not Addon.db.profile.testMode or Addon.testState.simulatedHour == nil end,
                        },
                        simulatePreviewWhatsNew = {
                            type = "execute",
                            name = NewTag(L["Preview What's new"], "1.6"),
                            desc = L["Preview What's new desc"],
                            order = 4,
                            width = 1.2,
                            func = function() Addon:TestPreviewWhatsNew() end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                    },
                },
                statusGroup = {
                    type = "group",
                    name = L["Status"],
                    inline = true,
                    order = 30,
                    args = {
                        currentStatus = {
                            type = "description",
                            name = function()
                                local status = "|cFFFFCC00Current Status:|r\n"
                                if Addon.db.profile.testMode then
                                    status = status .. "Simulation: |cFF00FF00ON|r\n"
                                else
                                    status = status .. "Simulation: |cFFFF0000OFF|r\n"
                                end

                                if Addon.testState.simulatedGroupType then
                                    status = status .. "Simulated group: |cFFFFFF00" .. Addon.testState.simulatedGroupType .. "|r\n"
                                else
                                    status = status .. "Simulated group: |cFF888888None|r\n"
                                end

                                local groupCooldown = math.max(0, Addon.db.profile.cooldown - (GetTime() - Addon.state.lastGroupMessageTime))
                                local guildCooldown = math.max(0, Addon.db.profile.cooldown - (GetTime() - Addon.state.lastGuildMessageTime))

                                status = status .. "Group cooldown: "
                                if groupCooldown > 0 then
                                    status = status .. "|cFFFF8800" .. string.format("%.1f", groupCooldown) .. "s|r"
                                else
                                    status = status .. "|cFF00FF00Ready|r"
                                end

                                status = status .. " | Guild cooldown: "
                                if guildCooldown > 0 then
                                    status = status .. "|cFFFF8800" .. string.format("%.1f", guildCooldown) .. "s|r"
                                else
                                    status = status .. "|cFF00FF00Ready|r"
                                end

                                return status
                            end,
                            order = 1,
                            fontSize = "medium",
                        },
                        resetButton = {
                            type = "execute",
                            name = L["Reset Test State"],
                            desc = L["Reset all test state and cooldowns"],
                            order = 2,
                            width = 1.0,
                            func = function() Addon:TestReset() end,
                            disabled = function() return not Addon.db.profile.testMode end,
                        },
                        refreshButton = {
                            type = "execute",
                            name = L["Refresh Status"],
                            desc = L["Refresh the status display"],
                            order = 3,
                            width = 0.8,
                            func = function()
                                -- Trigger options refresh
                                LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                            end,
                        },
                    },
                },
                debugGroup = {
                    type = "group",
                    name = L["Debug"],
                    inline = true,
                    order = 40,
                    args = {
                        debugMode = {
                            type = "toggle",
                            name = L["Debug mode"],
                            desc = L["Show debug messages in chat"],
                            order = 1,
                            width = "full",
                            get = function() return Addon.db.profile.debugMode end,
                            set = function(_, val) Addon.db.profile.debugMode = val end,
                        },
                    },
                },
            },
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
    AceConfigDialog:AddToBlizOptions("AutoSay", "AutoSay")
end

-- Hook into OnInitialize to setup config
local origOnInitialize = Addon.OnInitialize
function Addon:OnInitialize()
    origOnInitialize(self)
    self:SetupConfig()
end
