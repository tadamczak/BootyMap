local Map = BootyMap
local Assert = assert
local Configuration, Runtime = Map.Services.Configuration, Map.Core.Runtime
local fields
local positions = {{value = "native", text = "Native position"}, {value = "TOPLEFT", text = "Top left"},
    {value = "TOPRIGHT", text = "Top right"}, {value = "BOTTOMLEFT", text = "Bottom left"},
    {value = "BOTTOMRIGHT", text = "Bottom right"}}
local definitions = {
    {key = "hoverZone", label = "Zone name on hover", type = "checkbox", section = "Hover"},
    {key = "hoverInformation", label = "Clock and coordinates on hover", type = "checkbox", section = "Hover"},
    {key = "hoverButtons", label = "Addon-button panel on hover", type = "checkbox", section = "Hover"},
    {key = "hoverNativeControls", label = "Native controls on hover", type = "checkbox", section = "Hover",
        tooltip = "Keeps native status, clicks and tooltips; permanent Hide settings still apply."},
    {key = "hoverBorder", label = "Border on hover", type = "checkbox", section = "Hover"},
    {key = "hoverIdleAlpha", label = "Opacity without cursor (%)", type = "slider", min = 0, max = 100, step = 5, section = "Hover"},
    {key = "hoverFadeMs", label = "Fade duration (ms)", type = "slider", min = 0, max = 1000, step = 50, section = "Hover"},
    {key = "hoverDelayMs", label = "Hide delay (ms)", type = "slider", min = 0, max = 1000, step = 50, section = "Hover",
        tooltip = "Allows moving from the map to its buttons or information. Edit mode keeps selected elements visible."},
    {key = "clockVisible", label = "Show digital clock", type = "checkbox", section = "Information"},
    {key = "clockSource", label = "Clock time", type = "choice", section = "Information", choices = {
        {value = "localTime", text = "Local time"}, {value = "server", text = "Server time"}}},
    {key = "clockFormat", label = "Clock format", type = "choice", section = "Information", choices = {
        {value = "24", text = "24 hour"}, {value = "12", text = "12 hour (AM/PM)"}}},
    {key = "clockPositionText", label = "Digital clock position", type = "choice", section = "Information", choices = {
        {value = "top", text = "Above map"}, {value = "bottom", text = "Below map"}}},
    {key = "coordsVisible", label = "Show player coordinates", type = "checkbox", section = "Information",
        tooltip = "Updates four times per second. Shows --, -- while the world map is open or coordinates are unavailable, preserving the browsed zone."},
    {key = "coordsPositionText", label = "Coordinates position", type = "choice", section = "Information", choices = {
        {value = "top", text = "Above map"}, {value = "bottom", text = "Below map"}}},
    {key = "informationFont", label = "Information font", type = "choice", section = "Information", choices = {
        {value = "friz", text = "Friz Quadrata"}, {value = "arial", text = "Arial Narrow"}}},
    {key = "informationFontSize", label = "Information font size", type = "slider", min = 8, max = 24, step = 1, section = "Information"},
    {key = "informationColor", label = "Information color", type = "color", section = "Information"},
    {key = "collectButtons", label = "Collect addon buttons", type = "checkbox", section = "Addon buttons",
        tooltip = "Optional panel. Disable MinimapButtonFrame and reload before enabling collection. Native controls and quest pins are excluded."},
    {key = "buttonSize", label = "Button size", type = "slider", min = 16, max = 48, step = 1, section = "Addon buttons"},
    {key = "buttonSpacing", label = "Button spacing", type = "slider", min = 0, max = 16, step = 1, section = "Addon buttons"},
    {key = "buttonColumns", label = "Panel columns", type = "slider", min = 1, max = 12, step = 1, section = "Addon buttons"},
    {key = "buttonSide", label = "Panel position", type = "choice", section = "Addon buttons", choices = {
        {value = "top", text = "Above map"}, {value = "bottom", text = "Below map"},
        {value = "left", text = "Left of map"}, {value = "right", text = "Right of map"}}},
    {key = "buttonOrder", label = "Button order (frame names, comma separated)", type = "text", section = "Addon buttons",
        tooltip = "Listed buttons come first; remaining buttons sort by frame name. Use /bm buttons to list collected names."},
    {key = "buttonExceptions", label = "Keep on minimap (frame names, comma separated)", type = "text", section = "Addon buttons",
        tooltip = "These buttons retain their original parent, placement and drag handlers."},
    {key = "size", label = "Map size", type = "slider", min = 80, max = 400, step = 1, section = "Layout"},
    {key = "locked", label = "Lock position", type = "checkbox", section = "Layout",
        tooltip = "Unlock to allow dragging. Edit mode temporarily enables dragging without changing this preference."},
    {key = "snap", label = "Snap to screen edges", type = "checkbox", section = "Layout"},
    {key = "shape", label = "Map shape", type = "choice", section = "Appearance", choices = {
        {value = "circle", text = "Circle"}, {value = "square", text = "Square"}},
        tooltip = "Square changes the minimap mask. pfQuest may still limit its quest markers to the native circle; its square corners require a separate integration."},
    {key = "border", label = "Map border", type = "choice", section = "Appearance", choices = {
        {value = "native", text = "Native border"}, {value = "booty", text = "Booty project border"}, {value = "none", text = "No border"}}},
    {key = "alpha", label = "Map opacity (%)", type = "slider", min = 0, max = 100, step = 5, section = "Appearance",
        tooltip = "Use /bm reset if the map becomes hard to find."},
    {key = "zoneVisible", label = "Show zone name", type = "checkbox", section = "Zone"},
    {key = "zonePosition", label = "Zone name position", type = "choice", section = "Zone", choices = {
        {value = "top", text = "Above map"}, {value = "bottom", text = "Below map"}}},
    {key = "zoneFont", label = "Zone font", type = "choice", section = "Zone", choices = {
        {value = "native", text = "Native font"}, {value = "friz", text = "Friz Quadrata"}, {value = "arial", text = "Arial Narrow"}}},
    {key = "zoneFontSize", label = "Zone font size", type = "slider", min = 8, max = 24, step = 1, section = "Zone"},
    {key = "zonePvpColor", label = "Zone color follows PvP status", type = "checkbox", section = "Zone"},
    {key = "zoneColor", label = "Custom zone color", type = "color", section = "Zone",
        tooltip = "Used when zone color does not follow PvP status."},
    {key = "wheel", label = "Mouse wheel zoom", type = "checkbox", section = "Zoom"},
    {key = "zoom", label = "Preferred zoom", type = "choice", section = "Zoom", choices = {
        {value = -1, text = "Keep native zoom"}, {value = 0, text = "0 - Furthest"}, {value = 1, text = "1"},
        {value = 2, text = "2"}, {value = 3, text = "3"}, {value = 4, text = "4"}, {value = 5, text = "5 - Closest"}}},
}
local function Required(ok, failure) Assert(ok, failure) end
local function Add(definition)
    local key, field = definition.key, Configuration.Copy(definition)
    field.durableKey, field.default = "preferences", Configuration.GetDefault(key)
    if key == "alpha" or key == "hoverIdleAlpha" then field.default = field.default * 100 end
    field.path = {"Map", definition.section or "Layout"}
    field.get = function(store)
        local value = store.preferences[key]
        if (key == "alpha" or key == "hoverIdleAlpha") and value ~= nil then return value * 100 end
        return value
    end
    field.set = function(value)
        if field.type == "number" and type(value) == "string" then
            if value == "" then value = nil
            else
                local parsed = tonumber(value)
                Assert(parsed ~= nil, "Enter a numeric minimap " .. key .. ".")
                value = parsed
            end
        end
        -- Shared sliders round to whole numbers. Display opacity as percent
        -- while the native adapter and durable preferences use the 0-1 range.
        if (key == "alpha" or key == "hoverIdleAlpha") and value ~= nil then
            Assert(type(value) == "number", "Choose a numeric minimap opacity.")
            value = value / 100
        end
        Required(Runtime.SetOption(key, value))
    end
    table.insert(fields, field)
end
local function Build()
    fields = {{key = "enabled", label = "Enable minimap customizations", type = "checkbox", default = true,
        path = {"Map", "General"}, profile = false,
        tooltip = "Turning this off restores the captured native minimap layout and controls.",
        set = function(value) Required(Runtime.SetEnabled(value)) end},
        {key = "hideMinimapIcon", label = "Hide BootyMap minimap icon", type = "checkbox", default = false,
        path = {"Map", "General"}, set = function(value) Required(Runtime.SetMinimapHidden(value)) end}}
    for _, definition in ipairs(definitions) do Add(definition) end
    for _, definition in ipairs({{key = "zoom", label = "Zoom buttons"}, {key = "clock", label = "Native clock"},
        {key = "tracking", label = "Tracking"}, {key = "mail", label = "Mail"}, {key = "battlefield", label = "Battleground"}}) do
        local title = string.upper(string.sub(definition.key, 1, 1)) .. string.sub(definition.key, 2)
        Add({key = "hide" .. title, label = "Hide " .. string.lower(definition.label), type = "checkbox", section = "Native elements"})
        Add({key = definition.key .. "Position", label = definition.label .. " position", type = "choice",
            choices = positions, section = "Native elements"})
    end
    -- Shared profiles support profileOnly fields: placement participates in
    -- capture and transactional restore without adding raw coordinates to UI.
    Add({key = "x", label = "Saved map X", type = "number", profileOnly = true})
    Add({key = "y", label = "Saved map Y", type = "number", profileOnly = true})
end
function Map.GetSettings()
    local store = Map.Database.Ensure()
    if not store then return nil end
    if not fields then Build() end
    return {db = store, fields = fields}
end
