local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local MAX_CUSTOM_MESSAGES = 10

-- Style bundle picker state (UI only, deliberately not saved to the profile)

-- Per-pool accordion fold state: shownStyle[poolId][style] = open (UI only, not saved)
local shownStyle = {}
local showAll = {}
local snapshots = {}

-- The same grey [tag] the phrase rows use, for the switches that control that tag -
-- seeing [newcomers] on both ends makes the wiring obvious
local function TagSuffix(word)
    return " |cFF888888[" .. word .. "]|r"
end

-- Checkbox label for a preset message: tagged phrases carry a grey suffix, style word first,
-- then the role/faction tag, then the trigger: [fun, tank, self].
-- Inside its own style group the style word is redundant, so it is left out.
-- Time-of-day phrases have no style word, just their band: [morning] / [evening] / [night].
local function PresetLabel(msg, ownStyleGroup, styleName)
    if msg.band then return msg.text .. " |cFF888888[" .. msg.band .. "]|r" end
    local tags = {}
    if msg.style and not ownStyleGroup then
        table.insert(tags, styleName and L["Style " .. msg.style] or msg.style)
    end
    if msg.role then
        -- The role reads best as its group-finder icon, not a word
        table.insert(tags, string.format("|A:roleicon-tiny-%s:14:14|a", AutoSay.RoleWords[msg.role] or "dps"))
    elseif msg.faction then
        table.insert(tags, msg.faction:lower())
    end
    -- No trigger tag: the phrase lists are split by occasion now, so the tab already said it.
    -- A {names} slot needs no tag either - it is written in the phrase for anyone to see,
    -- and the switch that fills it carries the matching [names] tag of its own.
    if #tags == 0 then return msg.text end
    return msg.text .. " |cFF888888[" .. table.concat(tags, ", ") .. "]|r"
end

-- Role-tagged rows are never hidden or greyed by the character's class: the profile can be
-- shared across characters (mage today, tank alt tomorrow), so every role stays configurable.
-- The runtime pick already filters by the actual current role.

-- A phrase is ACTIVE only while everything it depends on is switched on (AND semantics):
-- the occasion is the tab it sits on, a {names} slot needs that tab's naming switch, and a
-- role or time-of-day tag needs its master switch on the Style tab. An inactive phrase stays
-- visible but greyed out, next to the switch that would bring it back.
-- settingsFn always resolves to the channel's settings; poolKind says which switch of that
-- table governs this list.
-- A reconnect draws from the Reconnects list and only falls back to the greetings when that
-- list has nothing to say. So "On reconnect" keeps a greeting row live only while the
-- channel's reconnect list is silent: with a reconnect phrase the sender can use, the
-- fallback never runs, and a greeting row that no join trigger can reach is dead however
-- it looks. Silence is judged the way every other row here is judged - by the switches, not
-- by this character's role or the hour, both of which change under a panel that stays open.
local function ReconnectFallsBackToGreetings(settings, channelKey)
    if not settings.onReconnect then return false end
    local social = Addon.db.profile.social
    local live = {}
    for _, msg in ipairs(AutoSay.Reconnects) do
        live[msg.key] = (msg.band == nil or social.timeOfDay == true)
            and (msg.role == nil or social.rolePhrases == true)
    end
    -- A custom line the sender refuses is silence too: CustomTextUsable drops {role} with the
    -- master switch off, and on guild chat whatever the switch says
    local customs = settings.customReconnects
    if customs then
        local usable = {}
        for _, entry in ipairs(customs) do
            local roleText = entry.text and entry.text:find("{role}", 1, true)
            if not roleText or (social.rolePhrases == true and channelKey ~= "guild") then
                usable[#usable + 1] = entry
            end
        end
        customs = usable
    end
    return AutoSay.MessageLogic.PoolIsSilent(settings.enabledReconnects, live, customs)
end

--- The M+ pools share a gate the channel pools do not have: they all speak in party chat
--- and all sit under the M+ master switch
local function IsMPlusPoolKind(poolKind)
    return poolKind == "mplusKey"
        or poolKind == "mplusCompletionTimed"
        or poolKind == "mplusCompletionDepleted"
end

local function PhraseActive(msg, settingsFn, poolKind, channelKey)
    -- Nothing is sent at all while the addon is off, so nothing in any list is live
    if not Addon.db.profile.enabled then return false end
    local roleDependent = msg.role or msg.text:find("{role}", 1, true)
    local slotted = msg.text:find("{names}", 1, true) ~= nil
    if roleDependent and not Addon.db.profile.social.rolePhrases then return false end
    -- The runtime refuses role phrases on guild chat whatever the master switch says
    if roleDependent and channelKey == "guild" then return false end
    if msg.band and not Addon.db.profile.social.timeOfDay then return false end
    if not settingsFn then return true end
    local settings = settingsFn()
    if not settings then return true end

    -- The switch that governs this particular list. A channel switched off silences all of
    -- them; beyond that a goodbye list follows the goodbye toggle, a reconnect list follows
    -- the reconnect toggle, and so on. Without this only the greetings list ever greyed.
    if IsMPlusPoolKind(poolKind) then
        if not settings.enabled then return false end
        -- Said in party chat, so the party switch silences these as well
        if Addon.db.profile.party.enabled == false then return false end
        -- Beyond the master switch each M+ pool has its own trigger: each completion
        -- outcome follows its own switch, and the key announce needs one of its two
        -- announce moments switched on
        if poolKind == "mplusCompletionTimed" and not settings.completionTimedEnabled then return false end
        if poolKind == "mplusCompletionDepleted" and not settings.completionDepletedEnabled then return false end
        if poolKind == "mplusKey" and not (settings.announceOnFull or settings.announceOnStart) then
            return false
        end
    else
        if settings.enabled == false then return false end
        if poolKind == "goodbyes" then
            -- Two occasions feed this list now, and either one keeps it alive
            if not (settings.sendGoodbye or settings.sendGoodbyeOnRunEnd) then return false end
        elseif poolKind == "reconnects" then
            if not settings.onReconnect then return false end
        elseif poolKind == "login" then
            if not settings.onMemberLogin then return false end
        elseif poolKind == "greetingsSelf" then
            -- A phrase written around a {names} slot is waiting for the switch on this very
            -- tab: without names there is nothing to put in the hole, and the sentence that
            -- remains is not one anybody wrote
            if slotted and not settings.includeGroupNames then return false end
            -- This list is what goes out when you arrive, and a reconnect borrows it when
            -- the reconnect list has nothing the addon could say
            if not (settings.onSelfJoin or ReconnectFallsBackToGreetings(settings, channelKey)) then
                return false
            end
        elseif poolKind == "greetingsOthers" then
            if not settings.onOthersJoin then return false end
            if slotted and not settings.includeNames then return false end
        end
    end
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
-- enabled<Pool> -> custom<Pool>: the custom list that feeds the same occasion
local CUSTOMS_BY_ENABLED_KEY = {
    enabledGreetingsSelf = "customGreetings",
    enabledGreetingsOthers = "customGreetings",
    enabledGoodbyes = "customGoodbyes",
    enabledReconnects = "customReconnects",
    enabledLoginGreetings = "customLoginGreetings",
    enabledKeyAnnounce = "customKeyAnnounce",
    enabledCompletionTimed = "customCompletionTimed",
    enabledCompletionDepleted = "customCompletionDepleted",
}

local function MatrixChannels(keys, enabledKey, poolKind)
    local channels = {}
    for _, key in ipairs(keys) do
        channels[#channels + 1] = {
            key = key,
            poolKind = poolKind,
            customsKey = CUSTOMS_BY_ENABLED_KEY[enabledKey],
            tableFn = function() return Addon.db.profile[key][enabledKey] end,
            -- Always exposed now: every list has a switch of its own to follow, not just
            -- the greetings list with its trigger toggles
            settingsFn = function() return Addon.db.profile[key] end,
        }
    end
    return channels
end

--- A channel switched off on the General tab. Its triggers and phrases change nothing
--- until it is switched back on, so both are shown as inactive rather than merely ignored.
local function ChannelIsOff(ch)
    local settings = ch.settingsFn and ch.settingsFn()
    return settings ~= nil and settings.enabled == false
end

--- Warning row for the channels that are switched off, naming the tab that switches them
--- back on. Returns an empty string while every channel is live, which hides the row.
local function ChannelOffNotice(channels)
    return function()
        local names = {}
        for _, ch in ipairs(channels) do
            if ChannelIsOff(ch) then names[#names + 1] = channelLabel[ch.key] or ch.key end
        end
        if #names == 0 then return "" end
        return "|cFFFF7F3F" .. string.format(L["Channel off notice"], table.concat(names, ", ")) .. "|r"
    end
end

--- Mythic+ speaks in party chat, so the party switch reaches it too. Same warning row the
--- phrase matrices carry, on a tab that has no channel columns of its own to grey.
local MythicPlusPartyNotice = ChannelOffNotice({
    { key = "party", settingsFn = function() return Addon.db.profile.party end },
})

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
            name = function()
                local label = channelLabel[ch.key] or ""
                if ChannelIsOff(ch) then
                    return "|cFF7F7F7F" .. label .. "\n" .. L["channel off"] .. "|r"
                end
                return "|cFFFFD100" .. label .. "|r"
            end,
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
-- poolId keys the fold state; channels is a list of { key, tableFn, settingsFn } that every
-- tick in the list writes to.
--- Channels that could speak but have nothing to say: the trigger is on, the channel is on,
--- and not one phrase of this pool is ticked for it. Silence with no explanation anywhere,
--- until now.
local function EmptyPoolNotice(pool, channels)
    return function()
        local names = {}
        for _, ch in ipairs(channels) do
            local settings = ch.settingsFn and ch.settingsFn()
            local flags = settings and ch.tableFn and ch.tableFn()
            if flags and not ChannelIsOff(ch) then
                local anyLive = false
                for _, msg in ipairs(pool) do
                    if flags[msg.key] and PhraseActive(msg, ch.settingsFn, ch.poolKind, ch.key) then
                        anyLive = true
                        break
                    end
                end
                -- A custom line counts as content the same way the phrase list does
                if not anyLive and ch.customsKey and settings[ch.customsKey] then
                    for _, entry in ipairs(settings[ch.customsKey]) do
                        if entry.enabled and entry.text and entry.text:match("%S") then
                            anyLive = true
                            break
                        end
                    end
                end
                -- Only worth saying when something upstream would have let a line out
                if not anyLive and PhraseActive({ key = "probe", text = "probe" },
                    ch.settingsFn, ch.poolKind, ch.key) then
                    names[#names + 1] = channelLabel[ch.key] or ch.key
                end
            end
        end
        if #names == 0 then return "" end
        return "|cFFFF7F3F" .. string.format(L["Nothing selected notice"],
            table.concat(names, ", ")) .. "|r"
    end
end

--- Phrases this channel could never say, whatever is ticked: the guild has no group role and
--- no newcomers of its own (guild member logins have their own list), so those rows would be
--- permanently dead decoration on that tab.
local function PoolForChannels(pool, channels)
    local kind = channels[1].poolKind
    local side = (kind == "greetingsSelf" and "self")
        or (kind == "greetingsOthers" and "others") or nil
    local guildOnly = #channels == 1 and channels[1].key == "guild"
    if not side and not guildOnly then return pool end
    local kept = {}
    for _, msg in ipairs(pool) do
        local roleBound = msg.role ~= nil or msg.text:find("{role}", 1, true) ~= nil
        local fitsSide = AutoSay.MessageLogic.PhraseInPool(msg, { side = side })
        -- Guild chat has no group role, and its arrivals have their own list
        if fitsSide and not (guildOnly and roleBound) then kept[#kept + 1] = msg end
    end
    return kept
end

-- One tick per phrase, whatever the number of channels: a ticked row is on in every channel
-- the list serves. The db keeps its per-channel tables, so a row reads as ticked while any
-- channel has it, and a click writes the same value to all of them.
local function BuildMessageMatrix(poolId, pool, channels)
    pool = PoolForChannels(pool, channels)
    local function Selected()
        local snap = snapshots[poolId]
        local epoch = Addon.configViewEpoch or 0
        if not snap or snap.epoch ~= epoch then
            local tables = {}
            for i, ch in ipairs(channels) do tables[i] = ch.tableFn() end
            snap = { epoch = epoch, keys = AutoSay.MessageLogic.SelectedKeys(pool, tables) }
            snapshots[poolId] = snap
        end
        return snap.keys
    end
    local function AllView() return showAll[poolId] == true end
    local args = {}

    args.viewCount = {
        type = "description", order = 0.1, width = 1.6, fontSize = "medium",
        hidden = AllView,
        name = function()
            local n = 0
            for key in pairs(Selected()) do
                for _, ch in ipairs(channels) do
                    if ch.tableFn()[key] then
                        n = n + 1
                        break
                    end
                end
            end
            return string.format(L["Selected N of M"], n, #pool)
        end,
    }
    args.viewToggle = {
        type = "execute", order = 0.2, width = 0.8,
        name = function() return AllView() and L["Selected only"] or L["All phrases"] end,
        func = function()
            showAll[poolId] = not AllView() or nil
            Addon:BumpConfigView()
            LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
        end,
    }
    args.viewEmpty = {
        type = "description", order = 0.3, width = "full",
        hidden = function() return AllView() or next(Selected()) ~= nil end,
        name = "|cFFFFD100" .. L["Nothing selected hint"] .. "|r",
    }

    args.emptyNotice = {
        type = "description", order = 0.4, width = "full",
        name = EmptyPoolNotice(pool, channels),
    }

    -- Greyed rows are gated elsewhere - point at the tab that re-activates them
    if not IsMPlusPoolKind(channels[1].poolKind) then
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

    -- Everything starts folded: fifteen sections open on Classic pushed the rest of
    -- the list, and the custom-message boxes below it, off the visible area
    shownStyle[poolId] = shownStyle[poolId] or {}
    local open = shownStyle[poolId]

    local order = 1
    for _, style in ipairs(styles) do
        local entries = byStyle[style]
        local label
        if style == "classic" then
            label = L["Classic"]
        elseif style == "timeofday" then
            label = L["Time of day"]
        else
            label = L["Style " .. style]
        end

        local folded = function() return #styles > 1 and not open[style] end

        -- Pools without style phrases (guild login greetings) get a plain list, no accordion
        if #styles > 1 then
            args["head_" .. style] = {
                type = "execute", order = order, width = "full",
                dialogControl = "AutoSayCollapse",
                hidden = function() return not AllView() end,
                -- The leading "-"/"+" is the fold-state contract: AutoSayCollapse
                -- strips it and renders it as the [-]/[+] expand icon.
                -- "active right now / whole category" either way: with the section folded
                -- this count is the only thing saying whether a style is on, half on, or
                -- off, and "17 phrases" answered none of those. In the matrix a phrase
                -- counts as active when at least one channel can currently send it.
                name = function()
                    local active = 0
                    for _, msg in ipairs(entries) do
                        for _, ch in ipairs(channels) do
                            if ch.tableFn()[msg.key]
                                and PhraseActive(msg, ch.settingsFn, ch.poolKind, ch.key) then
                                active = active + 1
                                break
                            end
                        end
                    end
                    local colour = (active == 0 and "|cFF888888")
                        or (active == #entries and "|cFF00FF00")
                        or "|cFFFFD100"
                    return string.format("%s %s  %s(%d/%d)|r",
                        open[style] and "-" or "+", label, colour, active, #entries)
                end,
                func = function()
                    open[style] = not open[style]
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                end,
            }
            order = order + 1
        end

        for _, msg in ipairs(entries) do
            local plainLabel = PresetLabel(msg, msg.style ~= nil)
            local taggedLabel = PresetLabel(msg, false, true)
            local rowHidden = function()
                if AllView() then return folded() end
                return not Selected()[msg.key]
            end
            args["m_" .. msg.key] = {
                type = "toggle",
                name = function() return AllView() and plainLabel or taggedLabel end,
                order = order,
                -- One column: tags must be readable without hovering, folding beats truncation
                width = "full",
                hidden = rowHidden,
                -- Greyed out, not gone, while no channel could send it
                disabled = function()
                    for _, ch in ipairs(channels) do
                        if PhraseActive(msg, ch.settingsFn, ch.poolKind, ch.key) then return false end
                    end
                    return true
                end,
                get = function()
                    for _, ch in ipairs(channels) do
                        if ch.tableFn()[msg.key] then return true end
                    end
                    return false
                end,
                set = function(_, val)
                    for _, ch in ipairs(channels) do ch.tableFn()[msg.key] = val end
                end,
            }
            order = order + 1
        end
    end

    return args
end

-- {dungeon}/{key} only resolve on the M+ path; elsewhere they are stripped on send.
-- The text is accepted, but the player hears about it once per session.
local function WarnMPlusTokens(text)
    if Addon.mplusTokenHintShown then return end
    for _, token in ipairs(AutoSay.MPlusTokens) do
        if text:find(token, 1, true) then
            Addon.mplusTokenHintShown = true
            Addon:Print(L["Mythic+ placeholders ({dungeon}, {key}, {upgrade}, {time}) only work in Mythic+ messages - they are removed from other messages."])
            return
        end
    end
end

-- Build a custom message list UI group for any message type
-- Pre-allocates all MAX_CUSTOM_MESSAGES slots with hidden functions
-- so that add/delete dynamically shows/hides entries via NotifyChange.
local function BuildCustomMessageList(channel, customsKey, labelKey, poolKind)
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
            -- Greyed by the same rules as a preset row: the switch governing this pool,
            -- the channel's own switch, and for a {role} text the role master switch
            disabled = function()
                local entry = (Addon.db.profile[channel][customsKey] or {})[idx]
                if not entry or not entry.text then return false end
                return not PhraseActive({ key = "custom", text = entry.text },
                    function() return Addon.db.profile[channel] end, poolKind, channel)
                    -- channel is the profile key here ("guild"), which is what the guild
                    -- role rule inside PhraseActive matches on
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
                if channel ~= "mythicplus" then WarnMPlusTokens(val) end
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

-- One list of own lines for several channels. The db keeps a list per channel; this shows
-- their texts once each and writes every add, tick and delete to all of them.
local function SharedCustomTexts(channels, customsKey)
    local texts, seen = {}, {}
    for _, ch in ipairs(channels) do
        for _, entry in ipairs(Addon.db.profile[ch.key][customsKey] or {}) do
            if entry.text and not seen[entry.text] then
                seen[entry.text] = true
                texts[#texts + 1] = entry.text
            end
        end
    end
    return texts
end

local function EachCustomEntry(channels, customsKey, text, fn)
    for _, ch in ipairs(channels) do
        for _, entry in ipairs(Addon.db.profile[ch.key][customsKey] or {}) do
            if entry.text == text then fn(entry, ch) end
        end
    end
end

local function BuildSharedCustomList(channels, customsKey, labelKey)
    local args = {
        header = {
            type = "description", order = 1, fontSize = "medium",
            name = function()
                return string.format("%s (%d/%d)", L[labelKey],
                    #SharedCustomTexts(channels, customsKey), MAX_CUSTOM_MESSAGES)
            end,
        },
    }
    -- A slot for every line the per-channel lists can hold between them: lists written
    -- apart before they were shared can add up to more than one list's cap
    local slots = #channels * MAX_CUSTOM_MESSAGES
    for i = 1, slots do
        local idx = i
        local baseOrder = 10 + (i - 1) * 3
        local function Text() return SharedCustomTexts(channels, customsKey)[idx] end
        local function Hidden() return Text() == nil end
        args["toggle_" .. idx] = {
            type = "toggle", order = baseOrder, width = 2.5,
            name = function() return Text() or "" end,
            hidden = Hidden,
            disabled = function()
                local text = Text()
                if not text then return false end
                for _, ch in ipairs(channels) do
                    if PhraseActive({ key = "custom", text = text }, ch.settingsFn, ch.poolKind, ch.key) then
                        return false
                    end
                end
                return true
            end,
            get = function()
                local on = false
                EachCustomEntry(channels, customsKey, Text(), function(entry)
                    if entry.enabled then on = true end
                end)
                return on
            end,
            set = function(_, val)
                EachCustomEntry(channels, customsKey, Text(), function(entry) entry.enabled = val end)
            end,
        }
        args["delete_" .. idx] = {
            type = "execute", order = baseOrder + 1, width = 0.5,
            name = L["Delete"],
            hidden = Hidden,
            func = function()
                local text = Text()
                for _, ch in ipairs(channels) do
                    local list = Addon.db.profile[ch.key][customsKey]
                    for j = #(list or {}), 1, -1 do
                        if list[j].text == text then table.remove(list, j) end
                    end
                end
                LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
            end,
        }
    end
    args.newMessageInput = {
        type = "input", order = 10 + slots * 3, width = "full",
        name = L["Add"],
        hidden = function()
            return #SharedCustomTexts(channels, customsKey) >= MAX_CUSTOM_MESSAGES
        end,
        validate = function(_, val)
            -- SendChatMessage errors out above 255 bytes
            if val and #val > 255 then return L["Message is too long (max 255 characters)"] end
            return true
        end,
        get = function() return "" end,
        set = function(_, val)
            if not val or val == "" then return end
            -- All chats or none: a line that went into some lists only would read as on
            -- while another chat never says it
            local adds = {}
            for _, ch in ipairs(channels) do
                local settings = Addon.db.profile[ch.key]
                settings[customsKey] = settings[customsKey] or {}
                local present = false
                for _, entry in ipairs(settings[customsKey]) do
                    if entry.text == val then present = true end
                end
                if not present then
                    if #settings[customsKey] >= MAX_CUSTOM_MESSAGES then
                        Addon:Print(L["Own lines full"])
                        return
                    end
                    adds[#adds + 1] = settings[customsKey]
                end
            end
            WarnMPlusTokens(val)
            for _, list in ipairs(adds) do
                table.insert(list, { text = val, enabled = true })
            end
            EachCustomEntry(channels, customsKey, val, function(entry) entry.enabled = true end)
            LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
        end,
    }
    return args
end

local function AddCustomGroups(args, channels, customsKey, labelKey, order)
    args.customShared = {
        type = "group", inline = true, order = order,
        name = L["My own lines"],
        args = BuildSharedCustomList(channels, customsKey, labelKey),
    }
end

-- Tooltip body of a style bundle button: its phrases, one line per AutoSay.StylePools header
-- (both completion pools share the "Completion" header, so they merge into a single line).
-- Cached per style - eight multi-line listings are not worth building for a tooltip nobody hovers.
-- Class names in their own colours. The list is built once from the API rather than
-- hardcoded, so a class Blizzard adds later needs no edit here.
local classNameCache
local function ClassLabel(token)
    if not classNameCache then
        classNameCache = {}
        for i = 1, (GetNumClasses and GetNumClasses() or 0) do
            local name, file = GetClassInfo(i)
            if name and file then classNameCache[file] = name end
        end
    end
    local name = classNameCache[token] or token
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    return color and color:WrapTextInColorCode(name) or name
end

--- Which switch governs a pool, keyed by the settings table it writes to
local POOL_KIND_BY_KEY = {
    enabledGreetingsSelf = "greetingsSelf",
    enabledGreetingsOthers = "greetingsOthers",
    enabledGoodbyes = "goodbyes",
    enabledReconnects = "reconnects",
    enabledLoginGreetings = "login",
    enabledKeyAnnounce = "mplusKey",
    enabledCompletionTimed = "mplusCompletionTimed",
    enabledCompletionDepleted = "mplusCompletionDepleted",
}

--- Every settings table a pool can be enabled in: the channels, or the single M+ table
local function PoolTargets(pool)
    local targets = {}
    if pool.mplus then
        targets[1] = { key = "mythicplus", settings = Addon.db.profile.mythicplus }
    else
        for _, c in ipairs(AutoSay.Channels) do
            targets[#targets + 1] = { key = c.key, settings = Addon.db.profile[c.key] }
        end
    end
    return targets
end

--- total    phrases the set owns
--- selected ticked on at least one channel
--- sendable of those, the ones at least one channel could send right now
--- full     every phrase ticked on every channel that has the pool, which is what
---          ticking the style would produce - a phrase ticked in one channel only must not
---          colour the set as finished
local function CountPhrases(matches)
    local total, selected, sendable, full = 0, 0, 0, true
    for _, pool in ipairs(AutoSay.StylePools) do
        local poolKind = POOL_KIND_BY_KEY[pool.enabledKey]
        local targets = PoolTargets(pool)
        for _, msg in ipairs(AutoSay[pool.messages]) do
            if matches(msg) and AutoSay.MessageLogic.PhraseInPool(msg, pool) then
                total = total + 1
                local on, canSend = false, false
                for _, target in ipairs(targets) do
                    local flags = target.settings and target.settings[pool.enabledKey]
                    if flags then
                        if flags[msg.key] then
                            on = true
                            if not canSend and PhraseActive(msg, function() return target.settings end,
                                poolKind, target.key) then
                                canSend = true
                            end
                        else
                            full = false
                        end
                    end
                end
                if on then selected = selected + 1 end
                if canSend then sendable = sendable + 1 end
            end
        end
    end
    return total, selected, sendable, full
end

local function StyleCounts(style)
    return CountPhrases(function(msg) return AutoSay.MessageLogic.StyleMatches(msg, style) end)
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

    -- Only what the row cannot show: the name is already coloured by how much of the set
    -- is on, and the counts beside it give the exact numbers
    desc = L["Style " .. style .. " voice"] .. "\n\n" .. table.concat(lines, "\n")
    bundleDescCache[style] = desc
    return desc
end

local Kit = { Pages = {} }
AutoSay.ConfigKit = Kit
Kit.TagSuffix = TagSuffix
Kit.groupChannelKeys = groupChannelKeys
Kit.MatrixChannels = MatrixChannels
Kit.ChannelIsOff = ChannelIsOff
Kit.ChannelOffNotice = ChannelOffNotice
Kit.MythicPlusPartyNotice = MythicPlusPartyNotice
Kit.AddCaptionRow = AddCaptionRow
Kit.AddMatrixRow = AddMatrixRow
Kit.NoneOn = NoneOn
Kit.BuildMessageMatrix = BuildMessageMatrix
Kit.BuildCustomMessageList = BuildCustomMessageList
Kit.AddCustomGroups = AddCustomGroups
Kit.ClassLabel = ClassLabel
Kit.StyleCounts = StyleCounts
Kit.BundleDesc = BundleDesc
