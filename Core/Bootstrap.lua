BootyMap = BootyMap or {}
local Map = BootyMap
local version = type(GetAddOnMetadata) == "function" and GetAddOnMetadata("BootyMap", "Version")
Map.version = type(version) == "string" and version ~= "" and version or "0.1.0-dev.1"
Map.API_VERSION = 1
Map.Core = Map.Core or {}
Map.Services = Map.Services or {}
Map.Modules = Map.Modules or {}
Map.UI = BootyLib.UI
