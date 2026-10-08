local Map = BootyMap
local Assert = assert
local Configuration, Native = Map.Services.Configuration, Map.Modules.NativeMinimap
local Runtime = {}
Map.Core.Runtime = Runtime
local state = {initialized = false, stopped = false, batchDepth = 0}
local function Required(ok, failure) Assert(ok, failure) end
local function Call(callback, value)
    local called, result, failure = pcall(callback, value)
    if not called then return false, tostring(result) end
    if result ~= true then return false, failure or "The minimap adapter declined the operation." end
    return true
end
local function Refresh()
    -- SettingsHost owns settings/presentation refresh. Reentering it here can
    -- turn a live setting into a second, recursive minimap application.
    if state.view then state.view:Refresh() end
end
local function Report(reason)
    state.failure = tostring(reason)
    Refresh()
    if state.host then state.host.Print(state.failure) else BootyLib.Print("BootyMap: " .. state.failure) end
end
local function RejectStore(failure)
    local restored, reason = Call(Native.Stop)
    if not restored then failure = tostring(failure) .. " Restoration failed: " .. tostring(reason) end
    state.failure = failure
    Refresh()
    return false, failure
end
local function Ensure()
    local store, failure = Map.Database.Ensure()
    if not store then
        local _, reason = RejectStore(failure)
        return nil, reason
    end
    return store
end
local function Sync()
    local store, failure = Ensure()
    if not store then return false, failure end
    local ok, reason
    state.applying = true
    if state.stopped or not store.enabled then ok, reason = Call(Native.Stop)
    elseif Native.GetState().active then ok, reason = Call(Native.Apply, store)
    else ok, reason = Call(Native.Start, store) end
    state.applying = false
    state.failure = not ok and reason or nil
    Refresh()
    return ok, reason
end
local function Commit(target, key, value)
    local previous = target[key]
    target[key] = Configuration.Copy(value)
    if state.batchDepth > 0 then state.batchDirty = true; return true end
    local ok, failure = Sync()
    if not ok then
        target[key] = previous
        local restored, reason = Sync()
        if not restored then failure = tostring(failure) .. " Restoration failed: " .. tostring(reason) end
        state.failure = failure
        Refresh()
        return false, failure
    end
    return true
end
function Runtime.Initialize()
    local store, failure = Ensure()
    if not store then return false, failure end
    if not state.initialized then
        Native.SetFailureObserver(Report)
        Native.SetPositionObserver(function(x, y)
            local valid, reason = Configuration.ValidateValue("x", x)
            Required(valid, reason)
            valid, reason = Configuration.ValidateValue("y", y)
            Required(valid, reason)
            -- Drag drop has already applied the point. Persist once without
            -- revalidating or refreshing the native map on every mouse move.
            local current, message = Ensure()
            Required(current ~= nil, message)
            current.preferences.x, current.preferences.y = x, y
            Refresh()
        end)
    end
    state.initialized = true
    return true
end
function Runtime.OnHostReady(host) state.host = host; return Runtime.Start() end
function Runtime.GetState() return state end
function Runtime.IsAvailable() return state.initialized and not state.stopped end
function Runtime.IsBusy() return Native.GetState().editing == true end
function Runtime.CreateView(parent, host)
    if not state.view then state.view = Map.Modules.Overview.Create(parent, host) end
    return state.view
end
function Runtime.Start()
    local ok, failure = Runtime.Initialize()
    if not ok then return false, failure end
    state.stopped = false
    return Sync()
end
function Runtime.Stop()
    state.stopped = true
    local ok, failure = Call(Native.Stop)
    state.failure = not ok and failure or nil
    if state.view then state.view:Hide() end
    return ok, failure
end
function Runtime.OnActivationFailed()
    local ok, failure = Runtime.Stop()
    state.host = nil
    return ok, failure
end
function Runtime.SettingsChanged()
    if state.batchDepth > 0 then state.batchDirty = true; return true end
    return Sync()
end
function Runtime.BeginSettingsBatch() state.batchDepth = state.batchDepth + 1 end
function Runtime.EndSettingsBatch(success)
    if state.batchDepth == 0 then
        if success == false then state.batchDirty = nil end
        return true
    end
    state.batchDepth = state.batchDepth - 1
    if success == false then state.batchCancelled = true end
    if state.batchDepth == 0 then
        local dirty, cancelled = state.batchDirty, state.batchCancelled
        state.batchDirty, state.batchCancelled = nil, nil
        if not cancelled and dirty then Required(Sync()) end
    end
    return true
end
function Runtime.OnSettingsProfileApplied() Required(Runtime.SettingsChanged()) end
function Runtime.SetOption(key, value)
    local valid, failure = Configuration.ValidateValue(key, value)
    if not valid then return false, failure end
    local store, reason = Ensure()
    if not store then return false, reason end
    return Commit(store.preferences, key, value)
end
function Runtime.SetPosition(x, y)
    local valid, failure = Configuration.ValidateValue("x", x)
    if not valid then return false, failure end
    valid, failure = Configuration.ValidateValue("y", y)
    if not valid then return false, failure end
    local store, reason = Ensure()
    if not store then return false, reason end
    local preferences = Configuration.Copy(store.preferences)
    preferences.x, preferences.y = x, y
    return Commit(store, "preferences", preferences)
end
function Runtime.SetEnabled(value)
    if type(value) ~= "boolean" then return false, "Choose enabled or disabled." end
    local store, failure = Ensure()
    if not store then return false, failure end
    return Commit(store, "enabled", value)
end
function Runtime.SetMinimapHidden(value)
    if value ~= nil and type(value) ~= "boolean" then return false, "Choose a minimap-icon visibility setting." end
    local store, failure = Ensure()
    if not store then return false, failure end
    store.hideMinimapIcon = value
    if state.host and state.host.RefreshPresentation then state.host.RefreshPresentation() end
    return true
end
function Runtime.SetEditing(value)
    if type(value) ~= "boolean" then return false, "Choose edit mode on or off." end
    local store, reason = Ensure()
    if not store then return false, reason end
    local ok, failure = Call(Native.SetEditing, value)
    if not ok then state.failure = failure end
    Refresh()
    return ok, failure
end
local function ReplaceKnown(preferences, replacement)
    local result = Configuration.Copy(preferences)
    for key in pairs(result) do if Configuration.IsKnown(key) then result[key] = nil end end
    for key, value in pairs(replacement) do result[key] = Configuration.Copy(value) end
    return result
end
function Runtime.ResetLayout()
    if Native.GetState().editing then
        local ok, failure = Runtime.SetEditing(false)
        if not ok then return false, failure end
    end
    local store, failure = Ensure()
    if not store then return false, failure end
    local preferences = Configuration.Copy(store.preferences)
    preferences.x, preferences.y = nil, nil
    for _, key in ipairs({"size", "locked", "snap", "alpha"}) do preferences[key] = Configuration.GetDefault(key) end
    return Commit(store, "preferences", preferences)
end
function Runtime.ResetAll()
    if Native.GetState().editing then
        local ok, failure = Runtime.SetEditing(false)
        if not ok then return false, failure end
    end
    local store, failure = Ensure()
    if not store then return false, failure end
    return Commit(store, "preferences", ReplaceKnown(store.preferences, Configuration.Defaults()))
end
function Runtime.ApplyPreset(name)
    local preset, failure = Configuration.GetPreset(name)
    if not preset then return false, failure end
    local store, reason = Ensure()
    if not store then return false, reason end
    return Commit(store, "preferences", ReplaceKnown(store.preferences, preset))
end
function Runtime.Open(command)
    if command == "refresh" or command == "buttons" then
        local ok, failure = Native.RefreshButtons()
        if not ok then return false, failure end
        if command == "buttons" then
            local native = Native.GetState()
            local message = native.buttonStatus ~= "" and native.buttonStatus or native.buttonNames
            BootyLib.Print("BootyMap buttons: " .. (message ~= "" and message or "No collected buttons."))
        end
        Refresh()
        return true
    end
    if command == "enable" or command == "disable" then return Runtime.SetEnabled(command == "enable") end
    if command == "reset" then return Runtime.ResetLayout() end
    if command == "lock" then
        local ok, failure = Runtime.SetEditing(false)
        if not ok then return false, failure end
        return Runtime.SetOption("locked", true)
    end
    if command == "edit" then
        local ok, failure = Runtime.Initialize()
        if not ok then return false, failure end
        if not Native.GetState().active then
            local store, reason = Ensure()
            if not store then return false, reason end
            if not store.enabled or state.stopped then return false, "Enable BootyMap before entering edit mode." end
            ok, failure = Sync()
            if not ok then return false, failure end
        end
        return Runtime.SetEditing(not Native.GetState().editing)
    end
    if command ~= "" and command ~= "settings" then
        return false, "Use /bm, /bm settings, /bm edit, /bm lock, /bm reset, /bm refresh, /bm buttons, /bm enable or /bm disable."
    end
    if not state.host and BootyLib.Core.Runtime.started then
        local ok, failure = BootyLib.Core.Runtime.Activate(Map.Product)
        if not ok then return false, failure end
    end
    if not state.host then return false, state.failure or "BootyMap is waiting for login." end
    if command == "settings" then return state.host.OpenSettings() end
    return state.host.OpenView("map")
end
