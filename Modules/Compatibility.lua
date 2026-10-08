local Map = BootyMap
local Compatibility = {}
Map.Modules.Compatibility = Compatibility
local state = {clippedPins = 0, status = ""}
local shapeLease, questLease, events, options, width, height, ownedMask
local function Env() return type(getfenv) == "function" and getfenv(0) or _G end
local function PinClip(lease, owner)
    -- The installed renderer caches xPlayer/yPlayer/mZoom/tick on pfMap.
    -- Replay no pin loop when it skipped an unchanged render. Map geometry
    -- changes explicitly mark this lease dirty; no additional timer is added.
    if not lease.dirty and owner.xPlayer == lease.x and owner.yPlayer == lease.y and
        owner.mZoom == lease.zoom and owner.tick == lease.tick then return end
    lease.x, lease.y, lease.zoom, lease.tick = owner.xPlayer, owner.yPlayer, owner.mZoom, owner.tick
    lease.dirty = false
    for _, pin in ipairs(owner.mpins) do
        if pin:IsShown() then
            if type(owner.xPlayer) ~= "number" or type(owner.yPlayer) ~= "number" or type(owner.mZoom) ~= "number" then
                lease.enabled = false
                state.status = "pfQuest render cache is unsupported; clipping is paused and its pins remain unchanged."
                return
            end
            local point, relative, relativePoint, x, y = pin:GetPoint(1)
            if point == "CENTER" and relative == owner.drawlayer and relativePoint == "CENTER" and
                not Map.Services.Geometry.Contains(options.shape, width, height, x, y, 8) then
                pin:Hide(); state.clippedPins = state.clippedPins + 1
            end
        end
    end
end
local function Quest()
    local owner = pfMap
    if not options or not options.pfQuestClip or not owner then return end
    if owner.drawlayer ~= Minimap or type(owner.mpins) ~= "table" or type(owner.UpdateMinimap) ~= "function" then
        state.status = "pfQuest clipping is unavailable for this renderer; its pins remain unchanged."
        return
    end
    if questLease then
        if owner ~= questLease.owner or owner.UpdateMinimap ~= questLease.guard then
            questLease.enabled = false; state.status = "pfQuest updater changed; clipping is paused until BootyMap is restarted."
        end
        return
    end
    local lease = {owner = owner, original = owner.UpdateMinimap, enabled = true, dirty = true}
    lease.guard = function(self)
        -- Keep pfQuest's renderer, cache, visibility rules, tooltips and nodes.
        -- Its public method accepts only self; native this/event remain intact.
        local result = lease.original(self)
        if lease.enabled and ownedMask and self == lease.owner and Map.Modules.NativeMinimap.GetGeometry() then
            local ok, reason = pcall(PinClip, lease, self)
            if not ok then Map.Modules.NativeMinimap.ReportInformationFailure(tostring(reason)) end
        end
        return result
    end
    owner.UpdateMinimap = lease.guard; questLease = lease
    state.status = "pfQuest viewport clipping is active; corner discovery still follows its circular renderer."
end
function Compatibility.Stop()
    if events then events:UnregisterAllEvents() end
    if shapeLease then
        shapeLease.enabled = false
        if Env().GetMinimapShape == shapeLease.guard then Env().GetMinimapShape = shapeLease.original end
        shapeLease = nil
    end
    if questLease then
        questLease.enabled = false
        if questLease.owner.UpdateMinimap == questLease.guard then questLease.owner.UpdateMinimap = questLease.original end
        questLease = nil
    end
    options, ownedMask, state.status = nil, false, ""
end
function Compatibility.SetMaskOwned(value)
    ownedMask = value == true
    if not ownedMask then state.status = "Minimap mask changed; shape reporting and pfQuest clipping yield to its owner." end
end
function Compatibility.Apply(value, mapWidth, mapHeight)
    -- Keep a paused foreign updater paused across unrelated settings changes.
    local blocked = questLease and (not questLease.enabled or questLease.owner.UpdateMinimap ~= questLease.guard)
    local previous = blocked and questLease.owner
    Compatibility.Stop()
    if value.shape == "circle" then return end
    options, width, height, ownedMask = value, mapWidth, mapHeight, true
    local lease = {original = Env().GetMinimapShape, enabled = true}
    lease.guard = function()
        if lease.enabled and ownedMask and Map.Modules.NativeMinimap.GetGeometry() then
            if options.shape == "rounded" or options.shape == "octagon" then return "ROUND" end
            return "SQUARE"
        end
        if lease.original then return lease.original() end
        return "ROUND"
    end
    shapeLease = lease; Env().GetMinimapShape = lease.guard
    if value.pfQuestClip then
        if not events then
            events = (Map.UI or BootyLib.UI).Components.CreateContainer("BootyMapCompatibilityEvents", UIParent)
            events:SetScript("OnEvent", function() Quest() end)
            state.frame = events
        end
        events:RegisterEvent("ADDON_LOADED")
        if blocked and pfMap == previous then
            questLease = {owner = previous, enabled = false}
            state.status = "pfQuest updater changed; clipping is paused until BootyMap is restarted."
        else Quest() end
    end
end
function Compatibility.GetState() return state end
