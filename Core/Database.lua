local Map = BootyMap
local Assert = assert
local Configuration = Map.Services.Configuration
local Database = {SCHEMA_VERSION = 1}
Map.Database = Database
local function Defaults(store)
    local valid, failure = Configuration.Validate(store)
    Assert(valid, failure)
    store.schemaVersion = Database.SCHEMA_VERSION
    if store.enabled == nil then store.enabled = true end
    if store.hideMinimapIcon == nil then store.hideMinimapIcon = false end
    store.preferences = store.preferences or {}
    Configuration.FillDefaults(store)
    store.presentation = store.presentation or {}
    store.presentation.windows = store.presentation.windows or {}
    store.presentation.minimap = store.presentation.minimap or {angle = 225}
    store.addonVersion = Map.version
end
-- BootyMap owns new preferences only; it does not claim historical monolith data.
BootyLib.Data.RegisterOwner("map", "BootyMapDB", function() return false end, Defaults)
function Database.Ensure()
    local valid, failure = Configuration.Validate(BootyMapDB)
    if not valid then return nil, failure end
    return BootyLib.Data.Ensure("map")
end
