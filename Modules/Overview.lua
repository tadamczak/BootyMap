local Map = BootyMap
local UI = Map.UI.Components
local Overview = {}
Map.Modules.Overview = Overview
function Overview.Create(parent, host)
    local frame = UI.CreateContainer(nil, parent)
    frame:SetAllPoints(parent)
    local canvas = UI.CreateResponsiveCanvas(frame, "BootyMapOverviewScroll")
    local view = {frame = frame, canvas = canvas}
    local title = UI.CreateHeading(canvas, "Native minimap", 2, "gold")
    local status = UI.CreateComponentLabel(canvas, "", "white")
    status:SetJustifyH("LEFT"); status:SetJustifyV("TOP")
    local help = UI.CreateComponentLabel(canvas,
        "Open Settings to change map size, shape, border, zone text, zoom and native indicators. Settings apply immediately; shared profiles save and restore the complete layout.\n\nUse Edit to drag the minimap, then finish editing to return to your saved lock preference. Reset layout restores native placement, default size, locking and visible opacity. Reset all restores all map preferences.\n\nThe optional addon-button panel has size, spacing, columns, position, order and exceptions. Use /bm buttons for collected frame names and /bm refresh to discover late-created buttons. Disable MinimapButtonFrame and reload before enabling collection. Native controls, quest pins and buttons with continuous update handlers remain with their owners. Disable conflicting ShaguTweaks minimap customization. pfQuest may keep quest markers inside the native circle on a square map. Map > Information offers digital local/server time, 12/24-hour format, coordinates, font, size, color and position. Coordinates show --, -- while the world map is open. Map > Hover offers independent visibility, idle opacity, hide delay and fading. Edit keeps selected decoration visible; permanent Hide settings still apply. Landscape and portrait rectangles use the longest-side size. Compatibility can clip existing pfQuest pins to the viewport; corner discovery remains circular. Rounded masks and further integrations are planned separately.", "white")
    help:SetJustifyH("LEFT"); help:SetJustifyV("TOP")
    local settings = UI.CreateButton(canvas, nil, "Settings", 104, 24)
    local edit = UI.CreateButton(canvas, nil, "Edit", 104, 24)
    local enabled = UI.CreateButton(canvas, nil, "Disable", 104, 24)
    local layout = UI.CreateButton(canvas, nil, "Reset layout", 120, 24)
    local reset = UI.CreateButton(canvas, nil, "Reset all", 104, 24)
    local classic = UI.CreateButton(canvas, nil, "Classic", 104, 24)
    local booty = UI.CreateButton(canvas, nil, "Booty", 104, 24)
    local compact = UI.CreateButton(canvas, nil, "Compact", 104, 24)
    local actions = {settings, edit, enabled, layout, reset, classic, booty, compact}
    for _, button in ipairs(actions) do UI.StyleActionButton(button) end
    local function Result(ok, failure)
        if not ok and failure then host.Print(failure) end
        view:Refresh()
    end
    settings:SetScript("OnClick", function() host.OpenSettings() end)
    edit:SetScript("OnClick", function() Result(Map.Core.Runtime.SetEditing(not Map.Modules.NativeMinimap.GetState().editing)) end)
    enabled:SetScript("OnClick", function()
        local store, failure = Map.Database.Ensure()
        if not store then host.Print(failure); return end
        Result(Map.Core.Runtime.SetEnabled(not store.enabled))
    end)
    layout:SetScript("OnClick", function() Result(Map.Core.Runtime.ResetLayout()) end)
    reset:SetScript("OnClick", function() Result(Map.Core.Runtime.ResetAll()) end)
    classic:SetScript("OnClick", function() Result(Map.Core.Runtime.ApplyPreset("Classic")) end)
    booty:SetScript("OnClick", function() Result(Map.Core.Runtime.ApplyPreset("Booty")) end)
    compact:SetScript("OnClick", function() Result(Map.Core.Runtime.ApplyPreset("Compact")) end)
    local function Measure(width)
        local available = math.max(1, width - 32)
        title:ClearAllPoints(); title:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -16); title:SetWidth(available)
        status:ClearAllPoints(); status:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -48); status:SetWidth(available)
        local statusHeight = UI.MeasureTextHeight(status, available)
        status:SetHeight(statusHeight)
        local top = 58 + statusHeight
        help:ClearAllPoints(); help:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -top); help:SetWidth(available)
        local helpHeight = UI.MeasureTextHeight(help, available)
        help:SetHeight(helpHeight)
        return UI.LayoutFlow(canvas, actions, 16, top + helpHeight + 18, available, 8) + 16
    end
    function view:OnResize()
        if not frame:IsVisible() then return end
        local width, height = UI.GetFrameSpan(parent)
        UI.LayoutResponsiveCanvas(canvas, Measure, nil, math.max(1, width), math.max(1, height))
    end
    function view:Refresh()
        if not frame:IsVisible() then return end
        local runtime, native = Map.Core.Runtime.GetState(), Map.Modules.NativeMinimap.GetState()
        local store, failure = Map.Database.Ensure()
        local message = native.active and "Minimap customizations are active." or "Native minimap customizations are disabled."
        if native.editing then message = message .. " Edit mode: drag the minimap to move it." end
        if native.buttonStatus ~= "" then message = message .. "\n" .. native.buttonStatus
        elseif native.buttonCount > 0 then message = message .. "\nAddon panel: " .. native.buttonCount .. " buttons." end
        local compatibility = Map.Modules.Compatibility.GetState()
        if compatibility.status ~= "" then message = message .. "\n" .. compatibility.status end
        if native.compatibility and native.compatibility ~= "" then message = message .. "\n" .. tostring(native.compatibility) end
        if native.foreignChanges and native.foreignChanges > 0 then
            message = message .. "\nAnother addon changed minimap controls. Disable and enable BootyMap after choosing one minimap owner."
        end
        status:SetText(runtime.failure or failure or message)
        edit:SetText(native.editing and "Finish editing" or "Edit")
        UI.SetButtonEnabled(edit, native.active == true)
        enabled:SetText(store and store.enabled and "Disable" or "Enable")
        self:OnResize()
    end
    function view:Show() frame:Show(); self:Refresh(); return true end
    function view:Hide() frame:Hide(); return true end
    frame:SetScript("OnHide", function()
        if Map.Modules.NativeMinimap.GetState().editing then
            local ok, failure = Map.Core.Runtime.SetEditing(false)
            if not ok then host.Print(failure) end
        end
    end)
    frame:Hide()
    view.status, view.settingsButton, view.editButton, view.enabledButton = status, settings, edit, enabled
    view.layoutButton, view.resetButton = layout, reset
    view.presetButtons = {Classic = classic, Booty = booty, Compact = compact}
    return view
end
