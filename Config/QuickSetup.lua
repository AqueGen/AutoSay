local ADDON_NAME, AutoSay = ...
local Addon = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local Kit = AutoSay.ConfigKit
local StyleCounts = Kit.StyleCounts

local function MixInArgs()
    local args = {}
    for i, id in ipairs(AutoSay.MessageStyles) do
        args[id] = {
            type = "toggle",
            name = L["Style " .. id],
            desc = L["Style " .. id .. " voice"] .. "\n\n" .. L["Mix in desc"],
            order = i,
            hidden = function() return id == Addon.db.profile.mainStyle end,
            get = function()
                local _, _, _, full = StyleCounts(id)
                return full
            end,
            set = function(_, val) Addon:ApplyStyleBundle(id, false, val) end,
        }
    end
    return args
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
                        type = "group",
                        name = L["Mix in"],
                        inline = true,
                        order = 2,
                        args = MixInArgs(),
                    },
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
                        set = function(_, val)
                            Addon.db.profile.confirm.enabled = val
                            if not val then Addon:ConfirmDismiss() end
                            LibStub("AceConfigRegistry-3.0"):NotifyChange("AutoSay")
                        end,
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
                },
            },
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
    }
end
