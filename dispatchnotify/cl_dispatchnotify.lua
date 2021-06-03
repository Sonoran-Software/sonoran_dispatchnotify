--[[
    Sonaran CAD Plugins

    Plugin Name: dispatchnotify
    Creator: SonoranCAD
    Description: Show incoming 911 calls and allow units to attach to them.

    Put all client-side logic in this file.
]]

local pluginConfig = Config.GetPluginConfig("dispatchnotify")
local trackingCall = false
local trackingID = nil
local cur_blip = nil

if pluginConfig.enabled then

    local gpsLock = true
    local primaryUnitLock = true
    local lastPostal = nil
    local lastCoords = nil

    RegisterNetEvent("SonoranCAD::dispatchnotify:SetGps")
    AddEventHandler("SonoranCAD::dispatchnotify:SetGps", function(postal)
        -- try to set postal via command?
        if gpsLock then
            ExecuteCommand("postal "..tostring(postal))
            if lastPostal ~= nil and lastPostal ~= postal then
                TriggerEvent("chat:addMessage", {args = {"^0[ ^2Dispatch ^0] ", ("Call GPS coordinates updated (%s)."):format(postal)}})
                lastPostal = postal
            else
                lastPostal = postal
                TriggerEvent("chat:addMessage", {args = {"^0[ ^2Dispatch ^0] ", ("GPS coordinates set to caller's last known postal (%s)."):format(postal)}})
            end
        end
    end)

    RegisterNetEvent("SonoranCAD::dispatchnotify:SetLocation")
    AddEventHandler("SonoranCAD::dispatchnotify:SetLocation", function(coords)
        if gpsLock then
            SetNewWaypoint(coords.x, coords.y)
            if lastCoords ~= nil then
                if lastCoords.x == coords.x and lastCoords.y == coords.y then
                    TriggerEvent("chat:addMessage", {args = {"^0[ ^2Dispatch ^0] ", "GPS coordinates have been updated."}})
                    return
                end
            end
            lastCoords = coords
            TriggerEvent("chat:addMessage", {args = {"^0[ ^2Dispatch ^0] ", "GPS coordinates set to caller's last known location."}})
        end
    end)

    RegisterNetEvent("SonoranCAD::dispatchnotify:BeginTracking")
    AddEventHandler("SonoranCAD::dispatchnotify:BeginTracking", function(callID)
        local oldTrackValue = trackingCall
        trackingCall = true
        trackingID = callID
        if not oldTrackValue then
            track()
        end
    end)

    RegisterNetEvent("SonoranCAD::dispatchnotify:StopTracking")
    AddEventHandler("SonoranCAD::dispatchnotify:StopTracking", function()
        trackingCall = false
        trackingID = nil
    end)

    RegisterNetEvent("SonoranCAD::dispatchnotify:UpdateBlipPosition")
    AddEventHandler("SonoranCAD::dispatchnotify:UpdateBlipPosition", function(position)
        if cur_blip ~= nil then
            RemoveBlip(cur_blip)
        end
        cur_blip = AddBlipForCoord(position.x, position.y, position.z)
        SetBlipRoute(cur_blip, true)
    end)

    RegisterNetEvent("SonoranCAD::dispatchnotify:RemoveBlip")
    AddEventHandler("SonoranCAD::dispatchnotify:RemoveBlip", function()
        RemoveBlip(cur_blip)
        cur_blip = nil
    end)

    RegisterCommand("togglegps", function(source, args, rawCommand)
        gpsLock = not gpsLock
        TriggerEvent("chat:addMessage", {args = {"^0[ ^2GPS ^0] ", ("GPS lock has been %s"):format(gpsLock and "enabled" or "disabled")}})
    end)

    RegisterCommand("toggleprimarylock", function(source, args, rawCommand)
        primaryUnitLock = not primaryUnitLock
        TriggerEvent("chat:addMessage", {args = {"^0[ ^2GPS ^0] ", ("Primary unit lock has been %s"):format(gpsLock and "enabled" or "disabled")}})
    end)

    function track()
        local lastpostal = nil
        local postal = nil
        if trackingCall then
            while trackingCall and trackingID ~= nil do
                if IsPedInAnyVehicle(GetPlayerPed(-1), false) or not pluginConfig.requireOfficerInVehicleForTrack then
                    if exports[pluginConfig.nearestPostalResourceName] ~= nil then
                        postal = exports[pluginConfig.nearestPostalResourceName]:getPostal()
                    else
                        assert(false, "Required postal resource is not loaded. Cannot use postals plugin.")
                    end
                    if postal ~= nil and postal ~= lastpostal then
                        TriggerServerEvent("SonoranCAD::dispatchnotify:UpdateCallPostal", postal, trackingID)
                        lastpostal = postal
                    end
                    TriggerServerEvent("SonoranCAD::dispatchnotify:UpdatePosition", GetEntityCoords(GetPlayerPed(-1), 1), trackingID)
                end
                Citizen.Wait(pluginConfig.postalSendTimer)
            end
            RemoveBlip(cur_blip)
            cur_blip = nil
        end
    end

end