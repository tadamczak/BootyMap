local Map = BootyMap
local Runtime = Map.Core.Runtime
Map.GetMinimapGeometry = Map.Modules.NativeMinimap.GetGeometry
Map.ContainsMinimapPoint = Map.Modules.NativeMinimap.ContainsPoint
Map.Product = {
    id = "map", name = "BootyMap", title = "BootyMap", settingsLabel = "Map",
    version = Map.version, apiVersion = Map.API_VERSION, namespace = Map,
    description = "Layout, appearance, zoom and native indicators for your minimap.",
    requiredAddons = {"BootyLib"},
    Initialize = Runtime.Initialize, OnHostReady = Runtime.OnHostReady,
    OnActivationFailed = Runtime.OnActivationFailed,
    GetDatabase = Map.Database.Ensure, GetSettings = Map.GetSettings,
    Stop = Runtime.Stop, Start = Runtime.Start, IsBusy = Runtime.IsBusy,
    BeginSettingsBatch = Runtime.BeginSettingsBatch, EndSettingsBatch = Runtime.EndSettingsBatch,
    OnSettingsProfileApplied = Runtime.OnSettingsProfileApplied,
    views = {{id = "map", label = "Map", icon = "monitor", create = Runtime.CreateView,
        IsAvailable = Runtime.IsAvailable, width = 580, height = 450, minWidth = 350, minHeight = 300}},
    GetQuickMenu = function(host)
        return {{text = "Map", icon = "monitor", enabled = Runtime.IsAvailable(), action = function() return host.OpenView("map") end},
            {text = "Settings", icon = "settings", action = function() return host.OpenSettings() end},
            {text = "Reset minimap layout", icon = "monitor", action = Runtime.ResetLayout}}
    end,
}
local product, failure = BootyLib.RegisterProduct(Map.Product)
if not product then BootyLib.Print(failure) end
SlashCmdList = SlashCmdList or {}
SLASH_BOOTYMAP1, SLASH_BOOTYMAP2 = "/bm", "/bootymap"
SlashCmdList.BOOTYMAP = function(command)
    command = string.lower(string.gsub(string.gsub(command or "", "^%s+", ""), "%s+$", ""))
    local ok, reason = Runtime.Open(command)
    if ok == false and reason then BootyLib.Print("BootyMap: " .. tostring(reason)) end
    return ok, reason
end
