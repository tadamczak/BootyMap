local Map = BootyMap
local Information = {}
Map.Modules.Information = Information
local UI, Service = (Map.UI or BootyLib.UI).Components, Map.Services.Information
local state = {active = false, elapsed = 0, clockElapsed = 0, updates = 0}
local frame, clockText, coordsText, options, lastClock, lastCoords, wasOpen
local fonts = {friz = "Fonts\\FRIZQT__.TTF", arial = "Fonts\\ARIALN.TTF"}
local function OpenMap()
    local shown = WorldMapFrame and WorldMapFrame:IsShown()
    return shown ~= nil and shown ~= false and shown ~= 0
end
local function Update(force)
    local open = OpenMap()
    if options.coordsVisible and (force or wasOpen ~= open) then Service.Synchronize(open) end
    wasOpen = open
    if options.clockVisible and (force or state.clockElapsed >= 1) then
        state.clockElapsed = 0
        local text = Service.Clock(options.clockSource, options.clockFormat)
        if text ~= lastClock then clockText:SetText(text); lastClock = text end
    end
    if options.coordsVisible then
        local text = Service.Coordinates(open)
        if text ~= lastCoords then coordsText:SetText(text); lastCoords = text end
    end
    state.updates = state.updates + 1
end
local function OnUpdate()
    local delta = type(arg1) == "number" and arg1 or 0
    state.elapsed, state.clockElapsed = state.elapsed + delta, state.clockElapsed + delta
    local interval = options.coordsVisible and 0.25 or 1
    if state.elapsed < interval then return end
    state.elapsed = 0
    local ok, reason = pcall(Update, false)
    if not ok then
        frame:SetScript("OnUpdate", nil)
        state.failure = tostring(reason)
        Map.Modules.NativeMinimap.ReportInformationFailure(state.failure)
    end
end
local function Wake()
    if state.active and frame:IsVisible() then
        frame:SetScript("OnUpdate", OnUpdate)
        if options.coordsVisible then
            frame:RegisterEvent("PLAYER_ENTERING_WORLD"); frame:RegisterEvent("ZONE_CHANGED")
            frame:RegisterEvent("ZONE_CHANGED_NEW_AREA"); frame:RegisterEvent("MINIMAP_ZONE_CHANGED")
        end
    end
end
local function Sleep() frame:SetScript("OnUpdate", nil); frame:UnregisterAllEvents() end
local function OnEvent()
    if options and options.coordsVisible then
        Service.Synchronize(OpenMap()); Update(false)
    end
end
local function Ensure()
    if frame then return end
    frame = UI.CreateContainer("BootyMapInformation", Minimap)
    frame:SetAllPoints(Minimap); frame:EnableMouse(false)
    clockText = UI.CreateComponentLabel(frame, "", "gold")
    coordsText = UI.CreateComponentLabel(frame, "", "gold")
    frame:SetScript("OnShow", Wake); frame:SetScript("OnHide", Sleep)
    frame:SetScript("OnEvent", function()
        local ok, reason = pcall(OnEvent)
        if not ok then Map.Modules.NativeMinimap.ReportInformationFailure(tostring(reason)) end
    end)
    state.frame, state.clockText, state.coordsText = frame, clockText, coordsText
end
local function Layout(label, visible, position, offset)
    label:SetFont(fonts[options.informationFont], options.informationFontSize, "")
    local color = options.informationColor
    label:SetTextColor(color[1], color[2], color[3], 1)
    label:SetWidth(math.max(options.size, 120)); label:SetHeight(options.informationFontSize + 4)
    label:ClearAllPoints()
    if position == "top" then label:SetPoint("BOTTOM", Minimap, "TOP", 0, offset)
    else label:SetPoint("TOP", Minimap, "BOTTOM", 0, -offset) end
    if visible then label:Show() else label:Hide() end
end
local function ResolveSide(side)
    local _, y = Minimap:GetCenter()
    local ratio = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local half = options.size * ratio / 2
    local required = (options.zoneFontSize + 12 + 2 * (options.informationFontSize + 6)) * ratio
    if side == "bottom" and y * ratio - half < required then return "top" end
    if side == "top" and UIParent:GetHeight() - y * ratio - half < required then return "bottom" end
    return side
end
function Information.GetPanelGap(side)
    if not state.active then return 8 end
    local extent = 0
    if options.clockVisible and state.clockSide == side then extent = state.clockOffset + options.informationFontSize + 4 end
    if options.coordsVisible and state.coordsSide == side then extent = math.max(extent, state.coordsOffset + options.informationFontSize + 4) end
    local ratio = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return math.max(8, extent * ratio + 6)
end
function Information.Apply(value)
    if not value.clockVisible and not value.coordsVisible then Information.Stop(); return end
    Ensure(); options = value
    state.active, state.failure = true, nil
    state.elapsed, state.clockElapsed = 0, 0
    local offset = value.zoneVisible and value.zoneFontSize + 12 or 4
    local clockSide, coordsSide = ResolveSide(value.clockPositionText), ResolveSide(value.coordsPositionText)
    local clockOffset = clockSide == value.zonePosition and offset or 4
    local coordsOffset = coordsSide == value.zonePosition and offset or 4
    if value.clockVisible and coordsSide == clockSide then coordsOffset = coordsOffset + value.informationFontSize + 6 end
    state.clockSide, state.coordsSide, state.clockOffset, state.coordsOffset = clockSide, coordsSide, clockOffset, coordsOffset
    Layout(clockText, value.clockVisible, clockSide, clockOffset)
    Layout(coordsText, value.coordsVisible, coordsSide, coordsOffset)
    frame:UnregisterAllEvents()
    if Minimap:IsVisible() then Update(true) end
    frame:Show(); Wake()
end
function Information.Stop()
    state.active = false; options = nil
    if frame then Sleep(); frame:UnregisterAllEvents(); frame:Hide() end
end
function Information.GetState() return state end
