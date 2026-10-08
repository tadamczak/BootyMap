local Information = {}
BootyMap.Services.Information = Information
local function Finite(value) return type(value) == "number" and value - value == 0 end
function Information.Clock(source, format)
    local hour, minute
    if source == "server" and type(GetGameTime) == "function" then hour, minute = GetGameTime()
    elseif source == "localTime" and type(date) == "function" then
        hour, minute = tonumber(date("%H")), tonumber(date("%M"))
    end
    if not Finite(hour) or not Finite(minute) or hour < 0 or hour > 23 or minute < 0 or minute > 59 or
        hour ~= math.floor(hour) or minute ~= math.floor(minute) then return "--:--" end
    if format == "12" then
        local suffix = hour >= 12 and "PM" or "AM"
        hour = math.mod(hour, 12); if hour == 0 then hour = 12 end
        return string.format("%d:%02d %s", hour, minute, suffix)
    end
    return string.format("%02d:%02d", hour, minute)
end
function Information.Synchronize(openMap)
    if not openMap and type(SetMapToCurrentZone) == "function" then SetMapToCurrentZone() end
end
function Information.Coordinates(openMap)
    if openMap or type(GetPlayerMapPosition) ~= "function" then return "--, --" end
    local x, y = GetPlayerMapPosition("player")
    if not Finite(x) or not Finite(y) or x < 0 or x > 1 or y < 0 or y > 1 or (x == 0 and y == 0) then return "--, --" end
    return string.format("%.1f, %.1f", x * 100, y * 100)
end
