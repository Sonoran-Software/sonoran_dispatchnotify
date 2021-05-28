--[[
    Sonoran Plugins

    Plugin Configuration

    Put all needed configuration in this file.

]]
local config = {
    enabled = false,
    configVersion = "2.0",
    pluginName = "dispatchnotify", -- name your plugin here
    pluginAuthor = "SonoranCAD", -- author
    requiresPlugins = {"callcommands", "pushevents"}, -- required plugins for this plugin to work, separated by commas

    --[[
        Enable incoming 911 call notifications
    ]]
    enableUnitNotify = true,
    --[[
        Specifies what emergency calls are displayed as. Some countries use different numbers (like 999)
    ]]
    emergencyCallType = "911",
    --[[
        Specifies non-emergency call types. If unused, set to blank ("")
    ]]
    civilCallType = "311",
    --[[
        Some communities use 511 for tow calls. Specify below, or set blank ("") to disable
    ]]
    dotCallType = "511",

    --[[
        Command to respond to calls with
    ]]
    respondCommandName = "rcall",

    --[[
        Enable call responding (self-dispatching)

        If disabled, running commandName will return an error to the unit
    ]]
    enableUnitResponse = true,

    --[[
        If a dispatcher is detected to be online, automatically disable the response command.
    ]]
    dispatchDisablesSelfResponse = false,

    --[[
        Enable "units are on the way" notifications
    ]]
    enableCallerNotify = true,
    --[[
        notifyMethod: how should the caller be notified?
            none: disable notification
            chat: Sends a message in chat
            pnotify: Uses pNotify to show a notification
            custom: Use the custom event instead (see docs)
    ]]
    callerNotifyMethod = "chat",
    --[[
        notifyMessage: Message template to use when sending to the player

        You can use the following replacements:
            {officer} - officer name
    ]]
    notifyMessage = "Officer {officer} is responding to your call!",

    --[[
        Enable "incoming call" messages sent to your units.
    ]]
    enableUnitNotify = true,

    --[[
        unitNotifyMethod: how should units be notified?
            none: disable notification
            chat: Sends a message in chat
            pnotify: Uses pNotify to show a notification
            custom: Use the custom event instead (see docs)
    ]]
    unitNotifyMethod = "chat",
    --[[
        incomingCallMessage: how should officers be notified of a new 911 call?

        Parameters:
            {location} - location of call (street + postal)
            {description} - description as given by civilian
            {caller} - caller's name
            {callId} - ID of the call so LEO can respond with /r911 <id>
            {command} - The command to use

        Note: pNotify uses HTML (commented below), chat uses special codes.
    ]]
    --incomingCallMessage = "<b>Incoming Call!</b><br/>Location: {location}<br/>Description: {description}<br/>Use command /r911 <b>{callId}</b> to respond!",
    incomingCallMessage = "Incoming call from ^*{caller}^r! Location: ^3{location}^0 Description: ^3{description}^0 - Use /{command} ^*{callId}^r to respond!",

    --[[
        unitDutyMethod: How to detect if units are online?
            incad: units must be logged into the CAD
            permissions: units must have the "sonorancad.dispatchnotify" ACE permission (see docs)
            esxjob: requires esxsupport plugin, use jobs instead for on duty detection
            custom: Use custom function (defined below as unitDutyCustom)
    ]]
    unitDutyMethod = "incad",

    --[[
        esxJobsAllowed: What jobs should count as being on duty?
    ]]
    esxJobsAllowed = {
        ["police"] = true,
        ["ambulance"] = true,
        ["fire"] = true
    },

    --[[
        waypointType: Type of waypoint to use when officer is attached
            postal: set gps to caller's postal (less accurate, more realistic) - REQUIRES CONFIGURED POSTAL PLUGIN
            exact: set gps to caller's position (less realistic)
            none: disable waypointing
    ]]
    waypointType = "postal",

    --[[
        waypointFallbackEnabled: Fall back to postal if exact coordinates cannot be found (for self-generated calls)
    ]]
    waypointFallbackEnabled = true,
    postalSendTimer = 1500,
    nearestPostalResourceName = "nearest-postal"
}

if config.enabled then

    function unitDutyCustom(player)
        return false
    end

    Config.RegisterPluginConfig(config.pluginName, config)
end