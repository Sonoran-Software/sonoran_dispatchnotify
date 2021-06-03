--[[
    Sonaran CAD Plugins

    Plugin Name: dispatchnotify
    Creator: SonoranCAD
    Description: Show incoming 911 calls and allow units to attach to them.

    Put all server-side logic in this file.
]]

CreateThread(function() Config.LoadPlugin("dispatchnotify", function(pluginConfig)

if pluginConfig.enabled then

    local DISPATCH_TYPE = {"CALL_NEW", "CALL_EDIT", "CALL_CLOSE", "CALL_NOTE", "CALL_SELF_CLEAR"}
    local ORIGIN = {"CALLER", "RADIO_DISPATCH", "OBSERVED", "WALK_UP"}
    local STATUS = {"PENDING", "ACTIVE", "CLOSED"}

    local CallOriginMapping = {} -- callId => playerId
    local EmergencyToCallMapping = {} -- eCallId => CallId

    local function findCall(id)
        for idx, callId in pairs(EmergencyToCallMapping) do
            print(("check %s = %s"):format(id, callId))
            if id == callId then
                return idx
            end
        end
        return nil
    end

    local function getCallFromOriginId(id)
        for k, call in GetCallCache() do
            if call.dispatch.metaData ~= nil then
                if tonumber(call.dispatch.metaData.createdFromId) == tonumber(id) then
                    return call
                end
            end
        end
        return nil
    end

    local function SendMessage(type, source, message)
        if type == "dispatch" then
            TriggerClientEvent("chat:addMessage", source, {args = {"^0[ ^2Dispatch ^0] ", message}})
        elseif type == pluginConfig.emergencyCallType then
            TriggerClientEvent("chat:addMessage", source, {args = {"^0[ ^1"..type.." ^0] ", message}})
        elseif type == pluginConfig.civilCallType then
            TriggerClientEvent("chat:addMessage", source, {args = {"^0[ ^1"..type.." ^0] ", message}})
        elseif type == pluginConfig.dotCallType then
            TriggerClientEvent("chat:addMessage", source, {args = {"^0[ ^1"..type.." ^0] ", message}})
        elseif type == "error" then
            TriggerClientEvent("chat:addMessage", source, {args = {"^0[ ^1Error ^0] ", message}})
        elseif type == "debug" and Config.debugMode then
            TriggerClientEvent("chat:addMessage", source, {args = {"[ Debug ] ", message}})
        end
    end

    local function IsPlayerOnDuty(player)
        if pluginConfig.unitDutyMethod == "incad" then
            if GetUnitByPlayerId(tostring(player)) ~= nil then
                return true
            else
                return false
            end
        elseif pluginConfig.unitDutyMethod == "permissions" then
            return IsPlayerAceAllowed(player, "sonorancad.dispatchnotify")
        elseif pluginConfig.unitDutyMethod == "esxjob" then
            assert(isPluginLoaded("esxsupport"), "esxsupport plugin is required to use the esx on duty method.")
            local job = GetCurrentJob(player)
            debugLog(("Player %s has job %s, return %s"):format(player, job, pluginConfig.esxJobsAllowed[GetCurrentJob(player)] ))
            if pluginConfig.esxJobsAllowed[GetCurrentJob(player)] then
                return true
            else
                return false
            end
        elseif pluginConfig.unitDutyMethod == "custom" then
            return unitDutyCustom(player)
        end
    end

    local ActiveDispatchers = {}

    AddEventHandler("SonoranCAD::pushevents:UnitLogin", function(unit)
        if unit.isDispatch and pluginConfig.dispatchDisablesSelfResponse then
            pluginConfig.enableUnitResponse = false
            debugLog("Self dispatching disabled, dispatch is online")
            table.insert(ActiveDispatchers, unit.id)
        end
    end)

    AddEventHandler("SonoranCAD::pushevents:UnitLogout", function(id)
        local idx = nil
        for i, k in pairs(ActiveDispatchers) do
            if id == k then
                idx = i
            end
        end
        if idx ~= nil then
            table.remove(ActiveDispatchers, idx)
        end
        if pluginConfig.dispatchDisablesSelfResponse and #ActiveDispatchers < 1 then
            pluginConfig.enableUnitResponse = true
            debugLog("Self dispatching enabled, dispatch is offline")
        end
    end)

    --EVENT_911 TriggerEvent('SonoranCAD::pushevents:IncomingCadCall', body.data.call, body.data.apiIds, body.data.metaData)
    RegisterServerEvent("SonoranCAD::pushevents:IncomingCadCall")
    AddEventHandler("SonoranCAD::pushevents:IncomingCadCall", function(call, metadata, apiIds)
        if metadata ~= nil and metadata.callerPlayerId ~= nil then
            CallOriginMapping[call.callId] = metadata.callerPlayerId
        end
        if pluginConfig.enableUnitNotify then
            local type = call.emergency and pluginConfig.civilCallType or pluginConfig.emergencyCallType
            local message = pluginConfig.incomingCallMessage:gsub("{caller}", call.caller):gsub("{location}", call.location):gsub("{description}", call.description):gsub("{callId}", call.callId):gsub("{command}", pluginConfig.respondCommandName)
            for k, v in pairs(GetUnitCache()) do
                local unit = GetSourceByApiId(v.data.apiIds)
                if not unit then
                    debugLog("no unit? "..json.encode(v))
                end
                if IsPlayerOnDuty(unit) then
                    if pluginConfig.unitNotifyMethod == "chat" then
                        SendMessage(type, unit, message)
                    elseif pluginConfig.unitNotifyMethod == "pnotify" then
                        TriggerClientEvent("pNotify:SendNotification", unit, {
                            text = message,
                            type = "error",
                            layout = "bottomcenter",
                            timeout = "10000"
                        })
                    end
                end
            end
        end
    end)

    RegisterServerEvent("SonoranCAD::callcommands:EmergencyCallAdd")
    AddEventHandler("SonoranCAD::callcommands:EmergencyCallAdd", function(playerId, callId)
        CallOriginMapping[callId] = playerId
    end)

    --Officer response
    registerApiType("NEW_DISPATCH", "emergency")
    registerApiType("ATTACH_UNIT", "emergency")
    registerApiType("REMOVE_911", "emergency")
    registerApiType("SET_CALL_POSTAL", "emergency")
    RegisterCommand(pluginConfig.respondCommandName, function(source, args, rawCommand)
        local source = tonumber(source)
        if not pluginConfig.enableUnitResponse then
            SendMessage("error", source, "Self dispatching is disabled.")
            return
        end
        if not IsPlayerOnDuty(source) then
            SendMessage("error", source, "You must be on duty to use this command.")
            return
        end
        if args[1] == nil then
            SendMessage("error", source, "Call ID must be specified.")
            return
        end
        local call = GetEmergencyCache()[tonumber(args[1])]
        if call == nil then
            call = GetCallCache()[EmergencyToCallMapping[findCall(args[1])]]
        end
        if call == nil then
            call = getCallFromOriginId(args[1])
        end
        if call == nil then
            SendMessage("error", source, "Could not find that call ID")
            return
        elseif call.dispatch ~= nil then
            call = call.dispatch
        end
        print("found the call: "..json.encode(call))
        local callerPlayerId = CallOriginMapping[call.callId]
        if callerPlayerId == nil and call.metaData ~= nil then
            callerPlayerId = call.metaData.callerPlayerId
        end
        if callerPlayerId == nil then
            debugLog("failed to find caller info")
        end
        local identifiers = GetIdentifiers(source)[Config.primaryIdentifier]
        local currentCall = EmergencyToCallMapping[call.callId] 
        if currentCall == nil then
            currentCall = getCallFromOriginId(call.callId)
        end
        if currentCall == nil then
            -- no mapped call, create a new one
            debugLog(("Creating new call request...(no mapped call for %s)"):format(call.callId))
            local postal = ""
            if isPluginLoaded("postals") and callerPlayerId ~= nil then
                if PostalsCache[tonumber(callerPlayerId)] ~= nil then
                    postal = PostalsCache[tonumber(callerPlayerId)]
                else
                    debugLog("Failed to obtain postal. "..json.encode(PostalsCache))
                    return
                end
            end
            local payload = {   serverId = Config.serverId,
                                origin = 0, 
                                status = 1, 
                                priority = 2,
                                block = "",
                                code = "",
                                postal = postal,
                                address = call.location, 
                                title = "OFFICER RESPONSE - "..call.callId, 
                                description = call.description, 
                                isEmergency = call.isEmergency,
                                notes = {"Officer responding"},
                                metaData = { callerPlayerId = callerPlayerId, createdFromId = call.callId },
                                units = { identifiers }
            }
            performApiRequest({payload}, "NEW_DISPATCH", function(response)
                debugLog("Call creation OK")
                if response:match("NEW DISPATCH CREATED - ID:") then
                    TriggerEvent("SonoranCAD::dispatchnotify:UnitRespond", source, response:match("%d+"))
                    EmergencyToCallMapping[call.callId] = tonumber(response:match("%d+"))
                end
                -- remove the 911 call
                local payload = { serverId = Config.serverId, callId = call.callId }
                performApiRequest({payload}, "REMOVE_911", function(resp)
                    debugLog("Remove status: "..tostring(resp))
                end)
            end)
        else
            -- Call already exists
            debugLog("Found Call. Attaching!")
            local data = {callId = currentCall, units = {identifiers}, serverId = Config.serverId}
            performApiRequest({data}, "ATTACH_UNIT", function(res)
                debugLog("Attach OK: "..tostring(res))
                SendMessage("debug", source, "You have been attached to the call.")
            end)
        end
    end)

    RegisterServerEvent("SonoranCAD::pushevents:UnitAttach")
    AddEventHandler("SonoranCAD::pushevents:UnitAttach", function(call, unit)
        print("hello, unit attach! "..json.encode(call))
        local callerId = nil
        if call.dispatch.metaData ~= nil then
            callerId = call.dispatch.metaData.callerPlayerId
        end
        local officerId = GetSourceByApiId(unit.data.apiIds)
        if officerId ~= nil then
            SendMessage("dispatch", officerId, ("You are now attached to call ^4%s^0. Description: ^4%s^0"):format(call.dispatch.callId, call.dispatch.description))
            if pluginConfig.waypointType == "exact" and callerId ~= nil and LocationCache[callerId] ~= nil then
                TriggerClientEvent("SonoranCAD::dispatchnotify:SetLocation", officerId, LocationCache[callerId].position)
            elseif pluginConfig.waypointType == "postal" or pluginConfig.waypointFallbackEnabled then
                if call.dispatch.postal ~= nil and call.dispatch.postal ~= "" then
                    if call.dispatch.metaData ~= nil and call.dispatch.trackPrimary and #call.dispatch.idents > 0 then
                        if GetSourceByApiId(GetUnitCache()[GetUnitById(call.dispatch.primary)].data.apiIds) == officerId then
                            TriggerClientEvent("SonoranCAD::dispatchnotify:BeginTracking", officerId, call.dispatch.callId)
                        end
                    else
                        TriggerClientEvent("SonoranCAD::dispatchnotify:SetGps", officerId, call.dispatch.postal)
                    end
                end
            end
        else
            debugLog("failed to find unit "..json.encode(unit))
        end
        debugLog(json.encode(unit))
        if pluginConfig.enableCallerNotify and callerId ~= nil then
            if pluginConfig.callerNotifyMethod == "chat" then
                SendMessage("dispatch", callerId, pluginConfig.notifyMessage:gsub("{officer}", unit.data.name))
            elseif pluginConfig.callerNotifyMethod == "pnotify" then
                TriggerClientEvent("pNotify:SendNotification", callerId, {
                    text = pluginConfig.notifyMessage:gsub("{officer}", unit.data.name),
                    type = "error",
                    layout = "bottomcenter",
                    timeout = "10000"
                })
            elseif pluginConfig.callerNotifyMethod == "custom" then
                TriggerEvent("SonoranCAD::dispatchnotify:UnitAttach", call.dispatch, callerId, officerId, unit.data.name)
            end
        end
    end)

    RegisterServerEvent("SonoranCAD::pushevents:DispatchEvent")
    AddEventHandler("SonoranCAD::pushevents:DispatchEvent", function(data)
        local dispatchType = data.dispatch_type
        local dispatchData = data.dispatch
        local metaData = data.dispatch.metaData
        if dispatchType ~= tostring(dispatchType) then
            -- hmm, expected a string, got a number
            dispatchType = DISPATCH_TYPE[data.dispatch_type+1]
        end
        local switch = {
            ["CALL_NEW"] = function()
                debugLog("CALL_NEW fired "..json.encode(dispatchData))
                local emergencyId = dispatchData.metaData.createdFromId
                for k, id in pairs(dispatchData.idents) do
                    print(id)
                    local unit = GetUnitCache()[GetUnitById(id)]
                    if not unit then
                        return
                    end
                    local officerId = GetSourceByApiId(unit.data.apiIds)
                    TriggerEvent("SonoranCAD::pushevents:UnitAttach", data, unit)
                end
            end,
            ["CALL_CLOSE"] = function()
                local cache = GetCallCache()[dispatchData.callId]
                if not cache then 
                    return 
                end
                SetCallCache(dispatchData.callId, nil)
                if cache.units ~= nil then
                    for k, v in pairs(cache.units) do
                        local officerId = GetUnitById(v.id)
                        if officerId ~= nil then
                            TriggerClientEvent("SonoranCAD::dispatchnotify:CallClosed", officerId, cache.callId)
                            TriggerClientEvent("SonoranCAD::dispatchnotify:StopTracking", officerId)
                            TriggerClientEvent("SonoranCAD::dispatchnotify:RemoveBlip", officerId)
                        end
                    end
                end
            end,
            ["CALL_NOTE"] = function() 
                TriggerEvent("SonoranCAD::dispatchnotify:CallNote", dispatchData.callId, dispatchData.notes)
            end,
            ["CALL_SELF_CLEAR"] = function() 
                TriggerEvent("SonoranCAD::dispatchnotify:CallSelfClear", dispatchData.units)
            end
        }
        if switch[dispatchType] then
            switch[dispatchType]()
        end
    end)

    AddEventHandler("SonoranCAD::pushevents:DispatchEdit", function(before, after)
        print(tostring(before.dispatch.trackPrimary)..":"..before.dispatch.primary)
        if before.dispatch.postal ~= after.dispatch.postal then
            print("trigger")
            TriggerEvent("SonoranCAD::dispatchnotify:CallEdit:Postal", after.dispatch.callId, after.dispatch.postal)
        end
        if before.address ~= after.address then
            TriggerEvent("SonoranCAD::dispatchnotify:CallEdit:Address", after.dispatch.callId, after.dispatch.address)
        end
        if before.dispatch.trackPrimary and after.dispatch.trackPrimary then
            if #after.dispatch.idents > 0 and after.dispatch.primary ~= -1 then
                TriggerClientEvent("SonoranCAD::dispatchnotify:BeginTracking", GetSourceByApiId(GetUnitCache()[GetUnitById(after.dispatch.primary)].data.apiIds), after.dispatch.callId)
            end
        elseif before.dispatch.trackPrimary and after.dispatch.trackPrimary then
            if #before.dispatch.idents > 0 then
                for k, id in pairs(before.dispatch.idents) do
                    local unit = GetUnitCache()[GetUnitById(id)]
                    if unit == nil then 
                        debugLog("No unit, skip")
                        return 
                    end
                    local officerId = GetSourceByApiId(unit.data.apiIds)
                    if officerId == nil then 
                        debugLog("No officerId, skip")
                        return 
                    end
                    if GetSourceByApiId(GetUnitCache()[GetUnitById(before.dispatch.primary)].data.apiIds) ~= officerId then
                        TriggerClientEvent("SonoranCAD::dispatchnotify:RemoveBlip", officerId)
                    else
                        TriggerClientEvent("SonoranCAD::dispatchnotify:StopTracking", officerId)
                    end
                end
            end
        end
    end)

    AddEventHandler("SonoranCAD::pushevents:UnitDetach", function(call, unit)
        local officerId = GetSourceByApiId(unit.data.apiIds)
        if GetCallCache()[call.dispatch.callId] == nil then
            debugLog("Ignore unit detach, call doesn't exist")
            return
        end
        if officerId ~= nil and call ~= nil then
            if call.dispatch.trackPrimary then
                TriggerClientEvent("SonoranCAD::dispatchnotify:StopTracking", officerId)
                TriggerClientEvent("SonoranCAD::dispatchnotify:RemoveBlip", officerId)
            end
            SendMessage("dispatch", officerId, ("You were detached from call %s."):format(call.dispatch.callId))
        end
    end)

    AddEventHandler("SonoranCAD::dispatchnotify:CallEdit:Postal", function(callId, postal)
        local call = GetCallCache()[callId]
        assert(call ~= nil, "Call not found, failed to process.")
        if call.dispatch.idents == nil then
            debugLog("no units attached "..json.encode(call))
            return
        end
        for k, id in pairs(call.dispatch.idents) do
            local unit = GetUnitCache()[GetUnitById(id)]
            if unit ~= nil then
                local officerId = GetSourceByApiId(unit.data.apiIds)
                if officerId ~= nil then
                    if not call.dispatch.trackPrimary then
                        TriggerClientEvent("SonoranCAD::dispatchnotify:SetGps", officerId, postal)
                    end
                else
                    debugLog("couldn't find officer")
                end
            end
        end
    end)

    RegisterServerEvent("SonoranCAD::dispatchnotify:UpdateCallPostal")
    AddEventHandler("SonoranCAD::dispatchnotify:UpdateCallPostal", function(clpostal, callid)
        local data = {}
        data[1] = {
            callId = callid,
            postal = clpostal,
            serverId = Config.serverId
        }
        performApiRequest(data, 'SET_CALL_POSTAL', function() end)
    end)

    RegisterServerEvent("SonoranCAD::dispatchnotify:UpdatePosition")
    AddEventHandler("SonoranCAD::dispatchnotify:UpdatePosition", function(location, callid)
        if GetCallCache()[callid] == nil then
            debugLog("Ignore postition update, call doesn't exist")
            return
        end
        local call = GetCallCache()[callid]
        for k, id in pairs(call.dispatch.idents) do
            local unit = GetUnitCache()[GetUnitById(id)]
            if unit ~= nil then
                local officerId = GetSourceByApiId(unit.data.apiIds)
                if GetUnitCache()[GetUnitById(call.dispatch.primary)] == nil then
                    TriggerClientEvent("SonoranCAD::dispatchnotify:StopTracking", officerId)
                    TriggerClientEvent("SonoranCAD::dispatchnotify:RemoveBlip", officerId)
                else
                    TriggerClientEvent("SonoranCAD::dispatchnotify:UpdateBlipPosition", officerId, location)
                end
            end
        end
    end)
end

end) end)
