local L = LibStub("AceLocale-3.0"):NewLocale("AutoSay", "enUS", true)
if not L then return end

-- General
L["AutoSay"] = "AutoSay"
L["Enable"] = "Enable"
L["Enable addon"] = "Enable addon"
L["Channels"] = "Channels"
L["Debug mode"] = "Show debug log"
L["Show debug messages in chat"] = "Print detailed debug messages to chat window"

-- Categories / Tabs
L["General"] = "General"
L["Greetings"] = "Greetings"
L["Goodbyes"] = "Goodbyes"
L["Messages"] = "Messages"
L["Reconnects"] = "Reconnects"

-- Channel names
L["Party"] = "Party"
L["Raid"] = "Raid"
L["Guild"] = "Guild"
L["PARTY"] = "Party"
L["RAID"] = "Raid"
L["GUILD"] = "Guild"

-- Per-channel tab names
L["Party Settings"] = "Party Settings"
L["Party Greetings"] = "Party Greetings"
L["Party Goodbyes"] = "Party Goodbyes"
L["Raid Settings"] = "Raid Settings"
L["Raid Greetings"] = "Raid Greetings"
L["Raid Goodbyes"] = "Raid Goodbyes"
L["Party Reconnects"] = "Party Reconnects"
L["Raid Reconnects"] = "Raid Reconnects"
L["Guild Settings"] = "Guild Settings"
L["Guild Greetings"] = "Guild Greetings"
L["Guild Goodbyes"] = "Guild Goodbyes"

-- Per-channel descriptions
L["Configure party chat settings"] = "Configure party chat settings"
L["Configure raid chat settings"] = "Configure raid chat settings"
L["Configure guild chat settings"] = "Configure guild chat settings"
L["Select greetings to use in party chat"] = "Select greetings to use in party chat"
L["Select goodbyes to use in party chat"] = "Select goodbyes to use in party chat"
L["Select greetings to use in raid chat"] = "Select greetings to use in raid chat"
L["Select goodbyes to use in raid chat"] = "Select goodbyes to use in raid chat"
L["Select greetings to use in guild chat"] = "Select greetings to use in guild chat"
L["Select goodbyes to use in guild chat"] = "Select goodbyes to use in guild chat"

-- Per-channel enable settings
L["Enable Party"] = "Enable Party"
L["Enable Party greetings"] = "Enable Party"
L["Send greetings and goodbyes in party chat"] = "Send greetings and goodbyes in party chat"
L["Send greetings to party chat"] = "Send greetings and goodbyes in party chat"
L["Enable Raid"] = "Enable Raid"
L["Enable Raid greetings"] = "Enable Raid"
L["Send greetings and goodbyes in raid chat"] = "Send greetings and goodbyes in raid chat"
L["Send greetings to raid chat"] = "Send greetings and goodbyes in raid chat"
L["Enable Guild"] = "Enable Guild"
L["Enable Guild greetings"] = "Enable Guild"
L["Send greetings and goodbyes to guild chat"] = "Send greetings and goodbyes to guild chat"
L["Send greeting to guild chat on login"] = "Send greeting to guild chat on login"
L["Send greetings to guild chat on login"] = "Send greeting to guild chat on login"

-- Triggers
L["Triggers"] = "Triggers"
L["On self join"] = "On self join"
L["Send greeting when you join"] = "Send greeting when you join"
L["Send greeting when you join a party"] = "Send greeting when you join a party"
L["Send greeting when you join a raid"] = "Send greeting when you join a raid"
L["On others join"] = "On others join"
L["Send greeting when others join"] = "Send greeting when others join"
L["Send greeting when others join your party"] = "Send greeting when others join your party"
L["Send greeting when others join your raid"] = "Send greeting when others join your raid"
L["On reconnect"] = "On reconnect"
L["Send greeting when you reconnect to party"] = "Send greeting when you reconnect to party"
L["Send greeting when you reconnect to raid"] = "Send greeting when you reconnect to raid"
L["On login"] = "On login"
L["Send greeting when you log in"] = "Send greeting when you log in"
L["On logout"] = "On logout"
L["Send goodbye when you log out"] = "Send goodbye when you log out"

-- Greet newcomers group
L["Greet newcomers"] = "Greet newcomers"
L["Only if leader"] = "Only if leader"
L["Only greet newcomers when you are the party leader"] = "Only greet newcomers when you are the party leader"
L["Only greet newcomers when you are the raid leader"] = "Only greet newcomers when you are the raid leader"

-- Names
L["Player Names"] = "Player Names"
L["Include player names"] = "Include player names"
L["Add joined player names to the greeting"] = "Add joined player names to the greeting"
L["Include group member names"] = "Include group member names"
L["Add names of current group members to the greeting"] = "Add names of current group members to the greeting"

-- Goodbyes
L["Send Goodbye"] = "Send Goodbye"
L["Send goodbye on leave"] = "Send goodbye on leave"
L["Send goodbye when leaving"] = "Send goodbye when leaving"
L["Send goodbye when leaving party"] = "Send goodbye when leaving party"
L["Send goodbye when leaving raid"] = "Send goodbye when leaving raid"

-- Messages
L["Message Selection"] = "Message Selection"
L["Greeting Messages"] = "Greeting Messages"
L["Select which greetings to use"] = "Select which greetings to use"
L["Goodbye Messages"] = "Goodbye Messages"
L["Select which goodbyes to use"] = "Select which goodbyes to use"

-- Message categories
L["Popular"] = "Popular"
L["More"] = "More"
L["Custom Messages"] = "Custom Messages"
L["Custom greeting"] = "Custom greeting"
L["Enter your custom greeting message"] = "Enter your custom greeting message"
L["Use custom greeting"] = "Use custom greeting"
L["Include your custom greeting in the message pool"] = "Include your custom greeting in the message pool"
L["Custom goodbye"] = "Custom goodbye"
L["Enter your custom goodbye message"] = "Enter your custom goodbye message"
L["Use custom goodbye"] = "Use custom goodbye"
L["Include your custom goodbye in the message pool"] = "Include your custom goodbye in the message pool"
L["Custom reconnect"] = "Custom reconnect"
L["Enter your custom reconnect message"] = "Enter your custom reconnect message"
L["Use custom reconnect"] = "Use custom reconnect"
L["Include your custom reconnect in the message pool"] = "Include your custom reconnect in the message pool"

-- Timing
L["Timing"] = "Timing"
L["Message delay"] = "Message delay"
L["Delay before sending message (seconds)"] = "Delay before sending message (seconds)"
L["Cooldown"] = "Cooldown"
L["Minimum time between messages (seconds)"] = "Minimum time between messages (seconds)"

-- Slash commands
L["Opens AutoSay settings"] = "Opens AutoSay settings"
L["Addon enabled"] = "Addon enabled"
L["Addon disabled"] = "Addon disabled"

-- Status messages
L["Sent greeting to"] = "Sent greeting to"
L["Sent goodbye to"] = "Sent goodbye to"

-- Simulation
L["Test Mode"] = "Simulation"
L["Test mode description"] = "Simulation mode allows you to test all addon functionality without being in a group, raid, or guild. Messages will be printed to chat instead of actually sent."
L["Test Mode Toggle"] = "Test Mode Toggle"
L["Enable Test Mode"] = "Enable Simulation"
L["Enable test mode desc"] = "Enable simulation mode to test events and preview messages without sending them"
L["Simulate Events"] = "Simulate Events"
L["Join Party"] = "Join Party"
L["Simulate joining a party"] = "Simulate joining a party"
L["Join Raid"] = "Join Raid"
L["Simulate joining a raid"] = "Simulate joining a raid"
L["Leave Group"] = "Leave Group"
L["Simulate leaving current group"] = "Simulate leaving current group"
L["Guild Greeting"] = "Guild Greeting"
L["Simulate guild login greeting"] = "Simulate guild login greeting"
L["Guild Goodbye"] = "Guild Goodbye"
L["Simulate guild logout goodbye"] = "Simulate guild logout goodbye"
L["Simulate Player Join"] = "Simulate Player Join"
L["Random Player Joins"] = "Random Player Joins"
L["Simulate a random player joining your group"] = "Simulate a random player joining your group"
L["Reconnect"] = "Reconnect"
L["Simulate reconnecting to group"] = "Simulate reconnecting to group"
L["Status"] = "Status"
L["Reset Test State"] = "Reset Test State"
L["Reset all test state and cooldowns"] = "Reset all test state and cooldowns"
L["Refresh Status"] = "Refresh Status"
L["Refresh the status display"] = "Refresh the status display"

-- Debug / Logging
L["Debug"] = "Logging"

-- Reset
L["Reset window size"] = "Reset window size"
L["Reset settings window to default size and position"] = "Reset settings window to default size and position"
L["Reset to Defaults"] = "Reset to Defaults"
L["Reset all settings to default values"] = "Reset all settings to default values"
L["Are you sure you want to reset all settings to defaults?"] = "Are you sure you want to reset all settings to defaults?"
L["Settings reset to defaults"] = "Settings reset to defaults"
