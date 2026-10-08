local Hover = {}
BootyMap.Modules.Hover = Hover
local UI = (BootyMap.UI or BootyLib.UI).Components
local state = {active = false, factor = 1}
local api, frame, options, roots, targets, wait, elapsed, from, destination
function Hover.Configure(value) api = value end
function Hover.Refresh() api.refresh() end
local function CancelTimer()
    if frame then frame:SetScript("OnUpdate", nil) end
    wait, elapsed = nil, nil
end
local function IsOver()
    if not Minimap:IsVisible() then return false end
    local x, y = GetCursorPosition()
    for _, record in ipairs(roots) do
        local region = record.frame
        if region:IsVisible() then
            local left, right, bottom, top = region:GetLeft(), region:GetRight(), region:GetBottom(), region:GetTop()
            local scale = region:GetEffectiveScale()
            if left and right and bottom and top and x >= left * scale and x <= right * scale and
                y >= bottom * scale and y <= top * scale then return true end
        end
    end
    return false
end
local function SetFactor(value)
    state.factor = value
    for _, target in ipairs(targets) do api.animateAlpha(target.record, target.base * value) end
    BootyMap.Modules.Information.SetHoverPaused(options.hoverInformation and value == 0)
end
local function Tick(delta)
    if wait then
        wait = wait - delta
        if wait > 0 then return end
        delta = -wait
        wait = nil
        if api.force() or IsOver() then SetFactor(1); CancelTimer(); return end
        from, destination, elapsed = state.factor, options.hoverIdleAlpha, 0
    end
    elapsed = elapsed + delta
    local duration = options.hoverFadeMs / 1000
    local progress = duration == 0 and 1 or math.min(1, elapsed / duration)
    SetFactor(from + (destination - from) * progress)
    if progress == 1 then CancelTimer() end
end
local function OnUpdate()
    local ok, reason = pcall(Tick, type(arg1) == "number" and arg1 or 0)
    if not ok then CancelTimer(); api.failure(tostring(reason)) end
end
function Hover.Enter()
    if not state.active then return end
    CancelTimer()
    from, destination, elapsed = state.factor, 1, 0
    if options.hoverFadeMs == 0 or from == 1 then SetFactor(1)
    else frame:SetScript("OnUpdate", OnUpdate) end
end
function Hover.Leave()
    if not state.active or api.force() or IsOver() then return end
    CancelTimer(); wait = options.hoverDelayMs / 1000; elapsed = 0
    if state.factor == options.hoverIdleAlpha then CancelTimer(); return end
    if wait == 0 and options.hoverFadeMs == 0 then SetFactor(options.hoverIdleAlpha)
    else frame:SetScript("OnUpdate", OnUpdate) end
end
function Hover.Stop()
    state.active = false; CancelTimer()
    if roots then for _, record in ipairs(roots) do api.bind(record, false) end end
    if targets then for _, target in ipairs(targets) do api.releaseAlpha(target.record) end end
    roots, targets, options = nil, nil, nil
    state.factor = 1
    BootyMap.Modules.Information.SetHoverPaused(false)
    BootyMap.Modules.Information.SetHoverRows(false)
end
local function Hidden()
    CancelTimer()
    if state.active then SetFactor(options.hoverIdleAlpha) end
end
local function Shown()
    if state.active then Hover.Enter(); Hover.Leave() end
end
function Hover.Apply(value, rootRecords, targetRecords)
    Hover.Stop()
    if table.getn(targetRecords) == 0 then return end
    options, roots, targets = value, rootRecords, targetRecords
    if not frame then
        frame = UI.CreateContainer("BootyMapHoverTransitions", Minimap)
        frame:SetScript("OnHide", function()
            local ok, reason = pcall(Hidden)
            if not ok then api.failure(tostring(reason)) end
        end)
        frame:SetScript("OnShow", function()
            local ok, reason = pcall(Shown)
            if not ok then api.failure(tostring(reason)) end
        end)
        state.frame = frame
    end
    state.active = true
    BootyMap.Modules.Information.SetHoverRows(true)
    for _, record in ipairs(roots) do api.bind(record, true) end
    local factor = (api.force() or IsOver()) and 1 or value.hoverIdleAlpha
    for _, target in ipairs(targets) do api.initialAlpha(target.record, target.base * factor) end
    SetFactor(factor)
end
function Hover.GetState() return state end
