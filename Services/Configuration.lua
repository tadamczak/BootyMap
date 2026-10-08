local Configuration = {}
BootyMap.Services.Configuration = Configuration
local defaults = {
    size = 140, shape = "circle", border = "native", alpha = 1, locked = true, snap = false,
    zoneVisible = true, zonePosition = "top", zoneFont = "native", zoneFontSize = 12,
    zonePvpColor = true, zoneColor = {1, 0.82, 0}, wheel = true, zoom = -1,
    hideZoom = false, hideClock = false, hideTracking = false, hideMail = false, hideBattlefield = false,
    zoomPosition = "native", clockPosition = "native", trackingPosition = "native",
    mailPosition = "native", battlefieldPosition = "native",
    collectButtons = false, buttonSize = 28, buttonSpacing = 4, buttonColumns = 4,
    buttonSide = "bottom", buttonOrder = "", buttonExceptions = "",
    clockVisible = false, clockSource = "localTime", clockFormat = "24", clockPositionText = "bottom",
    coordsVisible = false, coordsPositionText = "bottom", informationFont = "friz",
    informationFontSize = 12, informationColor = {1, 0.82, 0},
}
local options = {
    shape = {circle = true, square = true}, border = {native = true, booty = true, none = true},
    zonePosition = {top = true, bottom = true}, zoneFont = {native = true, friz = true, arial = true},
    buttonSide = {top = true, bottom = true, left = true, right = true},
    clockSource = {localTime = true, server = true}, clockFormat = {["12"] = true, ["24"] = true},
    clockPositionText = {top = true, bottom = true}, coordsPositionText = {top = true, bottom = true},
    informationFont = {friz = true, arial = true},
}
local positions = {native = true, TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true}
local function Finite(value)
    return type(value) == "number" and value == value and value - value == 0
end
local function Integer(value, low, high)
    return Finite(value) and value == math.floor(value) and value >= low and value <= high
end
function Configuration.Copy(value, copies)
    if type(value) ~= "table" then return value end
    copies = copies or {}
    if copies[value] then return copies[value] end
    local copy = {}; copies[value] = copy
    for key, child in pairs(value) do copy[key] = Configuration.Copy(child, copies) end
    return copy
end
function Configuration.IsKnown(key) return defaults[key] ~= nil or key == "x" or key == "y" end
function Configuration.GetDefault(key) return Configuration.Copy(defaults[key]) end
function Configuration.Defaults() return Configuration.Copy(defaults) end
function Configuration.ParseButtonNames(value)
    if type(value) ~= "string" or string.len(value) > 2048 then return nil end
    local result, count = {}, 0
    for name in string.gfind(value, "[^,]+") do
        name = string.gsub(string.gsub(name, "^%s+", ""), "%s+$", "")
        if not string.find(name, "^[%a_][%w_]*$") then return nil end
        if not result[name] then count = count + 1; result[name] = count end
    end
    return result
end
function Configuration.ValidateValue(key, value)
    if not Configuration.IsKnown(key) then return false, "Unknown minimap setting: " .. tostring(key) end
    -- Nil restores a known setting's default; coordinates retain native placement.
    if value == nil then return true end
    local valid
    if key == "x" or key == "y" then valid = Finite(value)
    elseif key == "size" then valid = Integer(value, 80, 400)
    elseif key == "zoneFontSize" or key == "informationFontSize" then valid = Integer(value, 8, 24)
    elseif key == "buttonSize" then valid = Integer(value, 16, 48)
    elseif key == "buttonSpacing" then valid = Integer(value, 0, 16)
    elseif key == "buttonColumns" then valid = Integer(value, 1, 12)
    elseif key == "buttonOrder" or key == "buttonExceptions" then valid = Configuration.ParseButtonNames(value) ~= nil
    elseif key == "zoom" then valid = Integer(value, -1, 5)
    elseif key == "alpha" then valid = Finite(value) and value >= 0 and value <= 1
    elseif options[key] then valid = type(value) == "string" and options[key][value]
    elseif positions[key] or string.find(key, "Position$") then valid = type(value) == "string" and positions[value]
    elseif key == "zoneColor" or key == "informationColor" then
        valid = type(value) == "table"
        if valid then
            for index = 1, 3 do valid = valid and Finite(value[index]) and value[index] >= 0 and value[index] <= 1 end
            for index in pairs(value) do if index ~= 1 and index ~= 2 and index ~= 3 then valid = false end end
        end
    else valid = type(value) == "boolean" end
    if not valid then return false, "Invalid minimap setting: " .. tostring(key) end
    return true
end
function Configuration.Validate(store)
    if store == nil then return true end
    if type(store) ~= "table" then return false, "Invalid BootyMap saved data. Preserve the saved file before repairing it." end
    if store.schemaVersion ~= nil and store.schemaVersion ~= 1 then
        return false, "Unsupported BootyMap saved format. Update the addon before opening it."
    end
    for _, key in ipairs({"enabled", "hideMinimapIcon"}) do
        if store[key] ~= nil and type(store[key]) ~= "boolean" then return false, "Invalid minimap setting: " .. key end
    end
    if store.preferences ~= nil then
        if type(store.preferences) ~= "table" then return false, "Invalid saved minimap preferences." end
        for key, value in pairs(store.preferences) do
            if Configuration.IsKnown(key) then
                local valid, failure = Configuration.ValidateValue(key, value)
                if not valid then return false, failure end
            end
        end
    end
    if store.presentation ~= nil and type(store.presentation) ~= "table" then return false, "Invalid minimap presentation settings." end
    if store.presentation then
        for _, key in ipairs({"windows", "minimap"}) do
            if store.presentation[key] ~= nil and type(store.presentation[key]) ~= "table" then
                return false, "Invalid minimap presentation setting: " .. key
            end
        end
    end
    return true
end
function Configuration.FillDefaults(store)
    for key, value in pairs(defaults) do
        if store.preferences[key] == nil then store.preferences[key] = Configuration.Copy(value) end
    end
end
function Configuration.GetPreset(name)
    local preset = Configuration.Defaults()
    if name == "Booty" then
        preset.size, preset.shape, preset.border = 160, "square", "booty"
        preset.hideZoom, preset.hideClock = true, true
    elseif name == "Compact" then
        preset.size, preset.shape, preset.border = 120, "square", "booty"
        preset.hideZoom, preset.hideClock, preset.zoneFontSize = true, true, 10
    elseif name ~= "Classic" then return nil, "Choose Classic, Booty or Compact." end
    return preset
end
