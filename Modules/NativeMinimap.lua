local Map = BootyMap
local Native = {}
Map.Modules.NativeMinimap = Native
local UI = (Map.UI or BootyLib.UI).Components
local Assert = assert
local function Fail(message) Assert(false, message) end
local state = {active = false, editing = false, restorationBlocked = false, foreignChanges = 0, compatibility = "",
    buttonCount = 0, buttonNames = "", buttonStatus = ""}
local records, store, surface, editor, mask, pingSlot, zoneSlot = {}, nil, nil, nil, nil, nil, nil
local failureObserver, positionObserver, dragging, dragPoints, RefreshEditor
local buttonPanel, buttonEvents, buttonRecords = nil, nil, {}
local nativeMask, squareMask = "Textures\\MinimapMask", "Interface\\Buttons\\WHITE8X8"
local fonts = {friz = "Fonts\\FRIZQT__.TTF", arial = "Fonts\\ARIALN.TTF"}
local widgetSpecs = {
    {"MinimapZoomIn", "hideZoom", "zoomPosition"}, {"MinimapZoomOut", "hideZoom", "zoomPosition"},
    {"GameTimeFrame", "hideClock", "clockPosition"}, {"MiniMapTrackingFrame", "hideTracking", "trackingPosition"},
    {"MiniMapMailFrame", "hideMail", "mailPosition"}, {"MiniMapBattlefieldFrame", "hideBattlefield", "battlefieldPosition"}
}
local function Global(name) return type(getglobal) == "function" and getglobal(name) or _G[name] end
local function Enabled(value) return value ~= nil and value ~= false and value ~= 0 end
local function Finite(value) return type(value) == "number" and value - value == 0 end
local function Call(callback, ...)
    local oldThis, oldEvent, oldArg = this, event, arg1
    -- Lua 5.0's implicit arg.n preserves the native setter's exact arity.
    local ok, first, second = pcall(callback, unpack(arg))
    this, event, arg1 = oldThis, oldEvent, oldArg
    return ok, first, second
end
local function Must(callback, ...)
    local ok, result = Call(callback, unpack(arg))
    if not ok then Fail(tostring(result)) end
    if result == false then Fail("A native minimap write was declined.") end
    return result
end
local function Equal(a, b, tolerance)
    if a == b then return true end
    if type(a) ~= type(b) then return false end
    if type(a) == "number" then return math.abs(a - b) < (tolerance or 0.00001) end
    if type(a) ~= "table" then return false end
    if type(a.GetName) == "function" or type(b.GetName) == "function" then return false end
    for key, value in pairs(a) do if not Equal(value, b[key], tolerance) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function PropertyEqual(key, a, b)
    -- Native layout uses float rects and scale conversion. A sub-millipixel
    -- readback difference is not a rejected write; non-layout values stay strict.
    local tolerance = (key == "width" or key == "height" or key == "points") and 0.001 or nil
    return Equal(a, b, tolerance)
end
local function WriteFailure(record, key, desired, actual)
    if type(desired) == "number" and type(actual) == "number" then
        return string.format("%s %s write was declined (wanted %.9f, read %.9f).", record.name, key, desired, actual)
    end
    return record.name .. " " .. key .. " write was declined."
end
local function ReadPoints(frame)
    local result = {}
    for index = 1, frame:GetNumPoints() do
        local point, relative, relativePoint, x, y = frame:GetPoint(index)
        result[index] = {point, relative, relativePoint, x, y}
    end
    return result
end
local function SetPoints(frame, value)
    if frame:ClearAllPoints() == false then return false end
    for index = 1, table.getn(value) do
        local p = value[index]
        if frame:SetPoint(p[1], p[2], p[3], p[4], p[5]) == false then return false end
    end
end
local function ReadWidth(frame) return frame:GetWidth() end
local function SetWidth(frame, value) return frame:SetWidth(value) end
local function ReadHeight(frame) return frame:GetHeight() end
local function SetHeight(frame, value) return frame:SetHeight(value) end
local function ReadAlpha(frame) return frame:GetAlpha() end
local function SetAlpha(frame, value) return frame:SetAlpha(value) end
local function ReadMovable(frame) return Enabled(frame:IsMovable()) end
local function SetMovable(frame, value) return frame:SetMovable(value and 1 or nil) end
local function ReadClamp(frame) return Enabled(frame:IsClampedToScreen()) end
local function SetClamp(frame, value) return frame:SetClampedToScreen(value and 1 or nil) end
local function ReadWheel(frame) return Enabled(frame:IsMouseWheelEnabled()) end
local function SetWheel(frame, value) return frame:EnableMouseWheel(value and 1 or nil) end
local function ReadZoom(frame) return frame:GetZoom() end
local function SetZoom(frame, value) return frame:SetZoom(value) end
local function ReadFont(frame)
    local path, size, flags = frame:GetFont()
    return {path, size, flags or ""}
end
local function SetFont(frame, value) return frame:SetFont(value[1], value[2], value[3]) end
local function ReadColor(frame)
    local r, g, b, a = frame:GetTextColor()
    return {r, g, b, a or 1}
end
local function SetColor(frame, value) return frame:SetTextColor(value[1], value[2], value[3], value[4]) end
local function Record(name, frame)
    frame = frame or Global(name)
    if not frame then return nil end
    local record = records[name]
    if record and record.frame ~= frame then Fail(name .. " was replaced.") end
    if not record then record = {name = name, frame = frame, leases = {}, scripts = {}}; records[name] = record end
    return record
end
local function CaptureClusterGeometry(record, lease)
    if record.name ~= "MinimapCluster" then return end
    local x, y = record.frame:GetCenter()
    local ratio = record.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    lease.centerX, lease.centerY = x * ratio, y * ratio
    lease.clusterWidth, lease.clusterHeight = record.frame:GetWidth(), record.frame:GetHeight()
end
local function SameClusterGeometry(record, lease, current)
    if record.name ~= "MinimapCluster" or not lease.centerX or table.getn(current) ~= 1 then return false end
    local relative = current[1][2]
    if relative ~= nil and relative ~= UIParent and relative ~= "UIParent" then return false end
    local x, y = record.frame:GetCenter()
    local ratio = record.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return Finite(x) and Finite(y) and Equal(x * ratio, lease.centerX, 0.001) and
        Equal(y * ratio, lease.centerY, 0.001) and Equal(record.frame:GetWidth(), lease.clusterWidth, 0.001) and
        Equal(record.frame:GetHeight(), lease.clusterHeight, 0.001)
end
local function ReleaseProperty(record, key)
    local lease = record.leases[key]
    if not lease then return true end
    local ok, current = Call(lease.read, record.frame)
    if not ok then return false, tostring(current) end
    if PropertyEqual(key, current, lease.original) then record.leases[key] = nil; return true end
    if not PropertyEqual(key, current, lease.applied) and not (key == "points" and SameClusterGeometry(record, lease, current)) then
        state.foreignChanges = state.foreignChanges + 1; record.leases[key] = nil; return true
    end
    local written, reason = Call(lease.write, record.frame, lease.original)
    local inspected, after = Call(lease.read, record.frame)
    if written and reason ~= false and inspected and PropertyEqual(key, after, lease.original) then record.leases[key] = nil; return true end
    return false, tostring(not written and reason or not inspected and after or record.name .. " " .. key .. " restoration was declined.")
end
local function Property(record, key, read, write, desired)
    if desired == nil then local ok, reason = ReleaseProperty(record, key); if not ok then Fail(reason) end; return end
    local inspected, actual = Call(read, record.frame)
    if not inspected then Fail(tostring(actual)) end
    local lease = record.leases[key]
    if lease and not PropertyEqual(key, actual, lease.applied) and not (key == "points" and SameClusterGeometry(record, lease, actual)) then
        Fail(record.name .. " " .. key .. " has another owner.")
    end
    if not lease then lease = {read = read, write = write, original = actual}; record.leases[key] = lease end
    if lease.applied ~= nil and PropertyEqual(key, actual, desired) then return end
    lease.applied = desired
    local written, reason = Call(write, record.frame, desired)
    local readOK, after = Call(read, record.frame)
    if readOK then lease.applied = after end
    if not written then Fail(tostring(reason)) end
    if reason == false or not readOK or not PropertyEqual(key, after, desired) then Fail(WriteFailure(record, key, desired, after)) end
    if key == "points" then CaptureClusterGeometry(record, lease) end
end
local function ReleaseSlot(owner, key, original, guard, script)
    local current = script and owner:GetScript(key) or owner[key]
    if current == original then return true end
    if current ~= guard then state.foreignChanges = state.foreignChanges + 1; return true end
    if script then
        local ok, reason = Call(owner.SetScript, owner, key, original)
        if not ok or reason == false then return false, tostring(not ok and reason or key .. " restoration was declined.") end
        if owner:GetScript(key) ~= original then return false, key .. " restoration was declined." end
    else owner[key] = original end
    return true
end
local function Script(record, key, callback)
    local lease = record.scripts[key]
    if not callback then
        if lease then
            lease.enabled = false
            local ok, reason = ReleaseSlot(record.frame, key, lease.original, lease.guard, true)
            if not ok then Fail(reason) end
            record.scripts[key] = nil
        end
        return
    end
    if not lease then
        lease = {original = record.frame:GetScript(key), callback = callback, enabled = true}; record.scripts[key] = lease
        lease.guard = function()
            if not lease.enabled then if lease.original then return lease.original() end; return end
            return lease.callback(lease.original)
        end
        Must(record.frame.SetScript, record.frame, key, lease.guard)
        if record.frame:GetScript(key) ~= lease.guard then Fail(key .. " write was declined.") end
    elseif record.frame:GetScript(key) ~= lease.guard then Fail(key .. " has another owner.") end
    lease.enabled = true
end
local function Note(message)
    state.compatibility = state.compatibility == "" and message or state.compatibility .. " " .. message
end
local function Notify(reason)
    local original = tostring(reason)
    local restored, restoreReason = Native.Stop()
    state.failure = original .. (restored and "" or " Restoration: " .. tostring(restoreReason))
    if failureObserver then
        local ok, failure = Call(failureObserver, state.failure)
        if not ok then state.failure = state.failure .. " Notification: " .. tostring(failure) end
    end
    return false, state.failure
end
local function Callback(callback, ...)
    local ok, result, second = Call(callback, unpack(arg))
    if not ok then local _, failure = Notify(result); Fail(failure) end
    return result, second
end
local function ShaguEnabled(title)
    local shagu = Global("ShaguTweaks")
    local config = Global("ShaguTweaks_config")
    if not shagu or not config then return false end
    local translated = shagu.T and shagu.T[title] or title
    return config[translated] == 1 and shagu.mods and shagu.mods[translated] ~= nil
end
local function CheckOwner()
    -- pfQuest publishes a compatibility-only pfUI namespace even without pfUI.
    local pf = Global("pfUI")
    if pf and pf.minimap then Fail("Disable pfUI minimap ownership before enabling BootyMap.") end
    if ShaguEnabled("MiniMap Square") then Fail("Disable ShaguTweaks MiniMap Square and reload before enabling BootyMap.") end
end
local function Hidden(record, hidden)
    local lease = record.visibility
    if not hidden then
        if not lease then return end
        lease.enabled = false
        if record.frame.Show == lease.showGuard and record.frame.Hide == lease.hideGuard and
            not Enabled(record.frame:IsShown()) and lease.nativeShown then
            Must(lease.show, record.frame)
            if not Enabled(record.frame:IsShown()) then Fail(record.name .. " visibility restoration was declined.") end
        end
        local showOK, showReason = ReleaseSlot(record.frame, "Show", lease.show, lease.showGuard)
        local hideOK, hideReason = ReleaseSlot(record.frame, "Hide", lease.hide, lease.hideGuard)
        if not showOK or not hideOK then Fail(showReason or hideReason) end
        record.visibility = nil; return
    end
    if not lease then
        lease = {show = record.frame.Show, hide = record.frame.Hide, nativeShown = Enabled(record.frame:IsShown())}
        record.visibility = lease
        lease.showGuard = function(owner)
            if not lease.enabled or owner ~= record.frame then return lease.show(owner) end
            lease.nativeShown = true
            local ok, reason = Call(lease.hide, owner)
            if not ok or reason == false then
                local _, failure = Notify(ok and record.name .. " hiding was declined." or reason)
                Fail(failure)
            end
        end
        lease.hideGuard = function(owner)
            if not lease.enabled or owner ~= record.frame then return lease.hide(owner) end
            lease.nativeShown = false
            local ok, reason = Call(lease.hide, owner)
            if not ok or reason == false then
                local _, failure = Notify(ok and record.name .. " hiding was declined." or reason)
                Fail(failure)
            end
            return reason
        end
        record.frame.Show, record.frame.Hide = lease.showGuard, lease.hideGuard
    elseif record.frame.Show ~= lease.showGuard or record.frame.Hide ~= lease.hideGuard then Fail(record.name .. " visibility has another owner.") end
    lease.enabled = true
    Must(lease.hide, record.frame)
    if Enabled(record.frame:IsShown()) then Fail(record.name .. " hiding was declined.") end
end
local function ReleaseMask()
    if not mask then return true end
    mask.enabled = false
    if Minimap.SetMaskTexture == mask.guard and not mask.foreign and mask.applied ~= mask.original then
        local ok, reason = Call(mask.setter, Minimap, mask.original)
        if not ok or reason == false then return false, tostring(not ok and reason or "Minimap mask restoration was declined.") end
        mask.applied = mask.original
    end
    local ok, reason = ReleaseSlot(Minimap, "SetMaskTexture", mask.setter, mask.guard)
    if ok then mask = nil end
    return ok, reason
end
local function Shape(options)
    if options.shape == "circle" and not mask then return end
    if not mask then
        -- The 1.12 minimap has SetMaskTexture, but no readable mask property.
        -- Only take the native baseline; known/custom borders require a reload.
        local border = Global("MinimapBorder")
        local texture = border and type(border.GetTexture) == "function" and border:GetTexture()
        if type(texture) ~= "string" or string.lower(texture) ~= "interface\\minimap\\ui-minimap-border" then
            Fail("Cannot establish the native mask. Disable other minimap shape owners and reload before using Square.")
        end
        mask = {setter = Minimap.SetMaskTexture, original = nativeMask, applied = nativeMask}
        local owned = mask
        mask.guard = function(owner, texturePath)
            if owner == Minimap then
                owned.foreign = true
                if owned.enabled then
                    if pingSlot then pingSlot.enabled = false end
                    Note("Another addon changed the minimap mask; BootyMap will preserve it.")
                end
            end
            return owned.setter(owner, texturePath)
        end
        Minimap.SetMaskTexture = mask.guard
    elseif Minimap.SetMaskTexture ~= mask.guard or mask.foreign then Fail("Minimap mask has another owner.") end
    mask.enabled = true
    local desired = options.shape == "square" and squareMask or nativeMask
    if mask.applied ~= desired then mask.applied = desired; Must(mask.setter, Minimap, desired) end
    Note("WoW 1.12 has no mask getter; shape reset uses the native circular mask baseline.")
end
local function Ping(lease, ...)
    local x, y, sound = arg[1], arg[2], arg[3]
    if not state.active or not lease.enabled or not store or store.preferences.shape ~= "square" then
        return lease.original(unpack(arg))
    end
    if not Finite(x) or not Finite(y) then return lease.original(unpack(arg)) end
    local dx, dy = x * Minimap:GetWidth(), y * Minimap:GetHeight()
    if dx * dx + dy * dy < Minimap:GetWidth() * Minimap:GetWidth() / 4 then return lease.original(unpack(arg)) end
    -- Native event/update retain the ping timer, fade and all interior behavior.
    if math.abs(dx) <= Minimap:GetWidth() / 2 and math.abs(dy) <= Minimap:GetHeight() / 2 then
        MiniMapPing:SetPoint("CENTER", Minimap, "CENTER", dx, dy)
        MiniMapPing:SetAlpha(1); MiniMapPing:Show()
        if sound and type(PlaySound) == "function" then PlaySound("MapPing") end
    else MiniMapPing:Hide() end
end
local function MouseUp(original)
    if original then Must(original) end
    if not state.active or not store or store.preferences.shape ~= "square" or not pingSlot or not pingSlot.enabled then return end
    if arg1 ~= nil and arg1 ~= "LeftButton" then return end
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local cx, cy = Minimap:GetCenter()
    x, y = x / scale + (Global("CURSOR_OFFSET_X") or -7) - cx, y / scale + (Global("CURSOR_OFFSET_Y") or -9) - cy
    if x * x + y * y >= Minimap:GetWidth() * Minimap:GetWidth() / 4 and
        math.abs(x) <= Minimap:GetWidth() / 2 and math.abs(y) <= Minimap:GetHeight() / 2 then
        Must(Minimap.PingLocation, Minimap, x, y)
    end
end
local function OnMouseUp(original) Callback(MouseUp, original) end
local function Wheel(original)
    if not state.active then
        if original then Callback(original) end
        return
    end
    if not Finite(arg1) or arg1 == 0 then return end
    local zoom = math.max(0, math.min(Minimap:GetZoomLevels() - 1, Minimap:GetZoom() + (arg1 > 0 and 1 or -1)))
    local lease = records.Minimap.leases.zoom
    local ok, reason = Call(Minimap.SetZoom, Minimap, zoom)
    if lease then lease.applied = Minimap:GetZoom() end
    if not ok then Fail(tostring(reason)) end
    if reason == false then Fail("Minimap zoom was declined.") end
end
local function OnWheel(original) Callback(Wheel, original) end
local function PingCallbacks(options)
    local record = records.Minimap
    if options.shape == "square" then
        if type(Global("Minimap_SetPing")) ~= "function" or not Global("MiniMapPing") then Fail("Native minimap ping callbacks are unavailable.") end
        if not pingSlot then
            pingSlot = {original = Global("Minimap_SetPing"), enabled = true}
            local owned = pingSlot
            pingSlot.guard = function(...)
                if not owned.enabled then return owned.original(unpack(arg)) end
                return Callback(Ping, owned, unpack(arg))
            end
            local env = type(getfenv) == "function" and getfenv(0) or _G
            env.Minimap_SetPing = pingSlot.guard
        elseif Global("Minimap_SetPing") ~= pingSlot.guard then Fail("Minimap ping has another owner.") end
        pingSlot.enabled = true; Script(record, "OnMouseUp", OnMouseUp)
    else
        if pingSlot then
            pingSlot.enabled = false
            local env = type(getfenv) == "function" and getfenv(0) or _G
            local ok, reason = ReleaseSlot(env, "Minimap_SetPing", pingSlot.original, pingSlot.guard)
            if not ok then Fail(reason) end
            pingSlot = nil
        end
        Script(record, "OnMouseUp", nil)
    end
    if options.wheel then
        Property(record, "wheel", ReadWheel, SetWheel, true); Script(record, "OnMouseWheel", OnWheel)
    else Script(record, "OnMouseWheel", nil); Property(record, "wheel", ReadWheel, SetWheel, nil) end
end
local function ZoneUpdate(owned)
    if owned.original then Must(owned.original) end
    if not owned.enabled or not state.active or not store or store.preferences.zonePvpColor then return end
    local record = records.MinimapZoneText
    local lease = record.leases.color
    if lease then lease.original, lease.applied = ReadColor(record.frame), ReadColor(record.frame) end
    local color = store.preferences.zoneColor
    Property(record, "color", ReadColor, SetColor, {color[1], color[2], color[3], 1})
end
local function Zone(options)
    local button, text = Record("MinimapZoneTextButton"), Record("MinimapZoneText")
    if button then
        Hidden(button, not options.zoneVisible)
        Property(button, "width", ReadWidth, SetWidth, options.size + 16)
        Property(button, "height", ReadHeight, SetHeight, math.max(20, options.zoneFontSize + 8))
        local top = options.zonePosition == "top"
        Property(button, "points", ReadPoints, SetPoints, {{top and "BOTTOM" or "TOP", Minimap, top and "TOP" or "BOTTOM", 0, top and 5 or -5}})
    end
    if not text then return end
    local native = text.leases.font and text.leases.font.original or ReadFont(text.frame)
    Property(text, "font", ReadFont, SetFont, {fonts[options.zoneFont] or native[1], options.zoneFontSize, native[3]})
    -- Stock XML fixes the label at 128x12 independently of its clickable owner.
    -- Resize both rectangles so the configured font fits the bounded zone row.
    Property(text, "width", ReadWidth, SetWidth, options.size + 16)
    Property(text, "height", ReadHeight, SetHeight, math.max(20, options.zoneFontSize + 8))
    if not options.zonePvpColor then
        if type(Global("Minimap_Update")) ~= "function" then Fail("Native zone updater is unavailable.") end
        if not zoneSlot then
            zoneSlot = {original = Global("Minimap_Update"), enabled = true}
            local owned = zoneSlot
            zoneSlot.guard = function()
                if not owned.enabled then if owned.original then return owned.original() end; return end
                return Callback(ZoneUpdate, owned)
            end
            local env = type(getfenv) == "function" and getfenv(0) or _G
            env.Minimap_Update = zoneSlot.guard
        elseif Global("Minimap_Update") ~= zoneSlot.guard then Fail("Minimap zone updater has another owner.") end
        local c = options.zoneColor
        Property(text, "color", ReadColor, SetColor, {c[1], c[2], c[3], 1})
    else
        if zoneSlot then
            zoneSlot.enabled = false
            local env = type(getfenv) == "function" and getfenv(0) or _G
            local ok, reason = ReleaseSlot(env, "Minimap_Update", zoneSlot.original, zoneSlot.guard)
            if not ok then Fail(reason) end
            zoneSlot = nil
        end
        Property(text, "color", ReadColor, SetColor, nil)
    end
end
local function NativeBorder(record, ratio)
    if not record.borderGeometry then
        local cx, cy = record.frame:GetCenter()
        local mx, my = Minimap:GetCenter()
        record.borderGeometry = {record.frame:GetWidth(), record.frame:GetHeight(), cx and cx - mx or 0, cy and cy - my or 0}
    end
    local g = record.borderGeometry
    Property(record, "width", ReadWidth, SetWidth, g[1] * ratio)
    Property(record, "height", ReadHeight, SetHeight, g[2] * ratio)
    Property(record, "points", ReadPoints, SetPoints, {{"CENTER", Minimap, "CENTER", g[3] * ratio, g[4] * ratio}})
end
local function Border(options)
    local native, top = Record("MinimapBorder"), Record("MinimapBorderTop")
    if options.border == "native" then
        if native then Property(native, "alpha", ReadAlpha, SetAlpha, nil) end
        if top then Property(top, "alpha", ReadAlpha, SetAlpha, nil) end
    else
        if native then Property(native, "alpha", ReadAlpha, SetAlpha, 0) end
        if top then Property(top, "alpha", ReadAlpha, SetAlpha, 0) end
    end
    if options.border == "booty" then
        if not surface then
            surface = UI.CreateContainer(nil, Minimap)
            surface:EnableMouse(false); surface:SetFrameStrata(Minimap:GetFrameStrata())
            surface:SetFrameLevel(math.max(0, Minimap:GetFrameLevel() - 1))
            surface:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -4, 4); surface:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 4, -4)
        end
        UI.Window.ApplyProjectSurface(surface)
        Must(surface.SetBackdropColor, surface, 0.015, 0.015, 0.015, 0)
        Must(surface.Show, surface)
    elseif surface then Must(surface.Hide, surface) end
end
local function Widgets(options)
    local corners = {}
    for _, spec in ipairs(widgetSpecs) do
        local record = Record(spec[1])
        if record then
            if spec[1] == "GameTimeFrame" and not options.hideClock and record.frame:GetScript("OnShow") and not Enabled(record.frame:IsShown()) then
                Note("The native clock is hidden by another addon (including ShaguTweaks); its OnShow handler is preserved.")
            end
            Hidden(record, options[spec[2]])
            local corner = options[spec[3]] or "native"
            if corner == "native" then Property(record, "points", ReadPoints, SetPoints, nil)
            else
                local offset = corners[corner] or 0
                local left = string.find(corner, "LEFT") ~= nil
                local top = string.find(corner, "TOP") ~= nil
                Property(record, "points", ReadPoints, SetPoints, {{corner, Minimap, corner, left and -4 or 4, top and -offset or offset}})
                if not options[spec[2]] then corners[corner] = offset + math.max(16, record.frame:GetHeight()) + 4 end
            end
        end
    end
end
local function MapCenter()
    local x, y = Minimap:GetCenter()
    if not Finite(x) or not Finite(y) then Fail("Minimap center is unavailable.") end
    local ratio = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * ratio, y * ratio
end
local function ClampPosition(x, y, options)
    local half = options.size * Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale() / 2
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    x, y = math.max(half, math.min(width - half, x)), math.max(half, math.min(height - half, y))
    if options.snap then
        if x - half < 12 then x = half elseif width - x - half < 12 then x = width - half end
        if y - half < 12 then y = half elseif height - y - half < 12 then y = height - half end
    end
    return x, y
end
local function Position(x, y, options)
    x, y = ClampPosition(x, y, options)
    local mapX, mapY = MapCenter()
    local cluster = records.MinimapCluster
    local cx, cy = cluster.frame:GetCenter()
    local ratio = cluster.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    Property(cluster, "points", ReadPoints, SetPoints, {{"CENTER", UIParent, "BOTTOMLEFT", (x - mapX + cx * ratio) / ratio, (y - mapY + cy * ratio) / ratio}})
    return x, y
end
local function CancelDrag()
    if not dragging then return end
    local record = records.MinimapCluster
    Must(record.frame.StopMovingOrSizing, record.frame)
    local lease = record.leases.points
    if lease then lease.applied = ReadPoints(record.frame) end
    Property(record, "points", ReadPoints, SetPoints, dragPoints)
    dragging = false
    dragPoints = nil
end
local function DragStart()
    if dragging then return end
    if not state.active or not store or not (state.editing or store.preferences.locked == false) then return end
    local record = records.MinimapCluster
    -- Own a points lease before native StartMoving creates its temporary anchor.
    Property(record, "points", ReadPoints, SetPoints, ReadPoints(record.frame))
    dragPoints = ReadPoints(record.frame); dragging = true
    Must(record.frame.StartMoving, record.frame)
end
local function DragStop()
    if not dragging then return end
    local record = records.MinimapCluster
    Must(record.frame.StopMovingOrSizing, record.frame)
    record.leases.points.applied = ReadPoints(record.frame)
    dragging, dragPoints = false, nil
    local x, y = MapCenter()
    x, y = Position(x, y, store.preferences)
    if positionObserver then Must(positionObserver, x, y) end
    Map.Modules.Information.Apply(store.preferences)
    if store.preferences.collectButtons then Must(Native.RefreshButtons) end
end
local function Editor()
    if editor then return end
    editor = UI.CreateContainer("BootyMapEditOverlay", Minimap)
    state.editFrame = editor
    editor:SetAllPoints(Minimap); editor:SetFrameStrata("DIALOG"); editor:SetFrameLevel(Minimap:GetFrameLevel() + 30)
    UI.Window.ApplyProjectSurface(editor); editor:SetBackdropColor(0.015, 0.015, 0.015, 0.25)
    editor:EnableMouse(true); editor:RegisterForDrag("LeftButton")
    editor:SetScript("OnDragStart", function() Callback(DragStart) end)
    editor:SetScript("OnDragStop", function() Callback(DragStop) end)
    editor:SetScript("OnHide", function() Callback(CancelDrag); state.editing = false end)
    if UI.CreateHeading then
        local label = UI.CreateHeading(editor, "BootyMap", 3, "gold", "settings")
        label:SetPoint("CENTER", editor, "CENTER", 0, 0)
    end
    editor:Hide()
end
function Native.SetEditing(value)
    if type(value) ~= "boolean" then return false, "Choose edit mode on or off." end
    if value and not state.active then return false, "Native minimap is not active." end
    local ok, reason = Call(function()
        if value then Editor() end
        state.editing = value == true
        RefreshEditor()
    end)
    if not ok then return Notify(reason) end
    return true
end
RefreshEditor = function()
    if state.active and store and (state.editing or store.preferences.locked == false) then
        Editor()
        Property(records.MinimapCluster, "movable", ReadMovable, SetMovable, true)
        Must(editor.Show, editor)
    else
        CancelDrag()
        if editor then Must(editor.Hide, editor) end
        if records.MinimapCluster then Property(records.MinimapCluster, "movable", ReadMovable, SetMovable, nil) end
    end
end
local function HideOwn(frame)
    if not frame then return true end
    local ok, reason = Call(frame.Hide, frame)
    if not ok or reason == false then return false, tostring(not ok and reason or "Minimap surface hiding was declined.") end
    if Enabled(frame:IsShown()) then return false, "Minimap surface hiding was declined." end
    return true
end
local function ReadParent(frame) return frame:GetParent() end
local function SetParent(frame, value) return frame:SetParent(value) end
local function ReadScale(frame) return frame:GetScale() end
local function SetScale(frame, value) return frame:SetScale(value) end
local function ReadLevel(frame) return frame:GetFrameLevel() end
local function SetLevel(frame, value) return frame:SetFrameLevel(value) end
local function ReadStrata(frame) return frame:GetFrameStrata() end
local function SetStrata(frame, value) return frame:SetFrameStrata(value) end
local buttonKeys = {"parent", "scale", "width", "height", "strata", "level", "points"}
local function ReleaseButton(record)
    local parent = record.leases.parent
    if parent and record.frame:GetParent() ~= parent.applied then
        -- Another collector took this button. Do not restore geometry into its
        -- new parent, even if individual widths/points happen to match ours.
        record.leases = {}; state.foreignChanges = state.foreignChanges + 1
    end
    Script(record, "OnDragStart", nil); Script(record, "OnDragStop", nil)
    for _, key in ipairs(buttonKeys) do
        local ok, reason = ReleaseProperty(record, key)
        if not ok then Fail(reason) end
    end
    buttonRecords[record.name] = nil
end
local function StopButtons()
    if buttonEvents then buttonEvents:UnregisterAllEvents() end
    for _, record in pairs(buttonRecords) do ReleaseButton(record) end
    local ok, reason = HideOwn(buttonPanel)
    if not ok then Fail(reason) end
    state.buttonCount, state.buttonNames = 0, ""
    state.buttonStatus = ""
end
local nativeButtons = {MinimapZoneTextButton = true, MinimapZoomIn = true, MinimapZoomOut = true,
    GameTimeFrame = true, MiniMapTrackingFrame = true, MiniMapMailFrame = true, MiniMapBattlefieldFrame = true,
    MiniMapWorldMapButton = true, MiniMapMeetingStoneFrame = true, MiniMapTracking = true,
    MiniMapVoiceChatFrame = true, MiniMapLFGFrame = true}
local function ButtonCandidate(frame, exceptions)
    if not frame.GetObjectType or not frame.GetName or not frame.GetScript then return false end
    local name, kind = frame:GetName(), frame:GetObjectType()
    if not name or nativeButtons[name] or exceptions[name] or frame.minimap or
        string.find(name, "^pfMap") or string.find(name, "^pfQuest") or string.find(name, "^MBF") then return false end
    if kind ~= "Button" and kind ~= "CheckButton" then return false end
    -- Positional OnUpdate owners cannot be safely suspended: their callback may
    -- also drive animations or status. Keep those buttons with their addon.
    return frame:GetScript("OnUpdate") == nil and
        (frame:GetScript("OnClick") ~= nil or frame:GetScript("OnMouseUp") ~= nil)
end
local function NoDrag() end
local function Buttons(options)
    if not options.collectButtons then StopButtons(); return end
    if Global("MinimapButtonFrame") or (type(IsAddOnLoaded) == "function" and Enabled(IsAddOnLoaded("MinimapButtonFrame"))) then
        StopButtons(); state.buttonStatus = "MinimapButtonFrame owns addon buttons; disable it and reload to use this panel."
        return
    end
    state.buttonStatus = ""
    if not buttonPanel then
        buttonPanel = UI.CreateContainer("BootyMapButtonPanel", UIParent)
        buttonPanel:SetFrameStrata("MEDIUM"); UI.Window.ApplyProjectSurface(buttonPanel)
        state.buttonPanel = buttonPanel
        buttonEvents = UI.CreateContainer("BootyMapButtonEvents", UIParent)
        buttonEvents:SetScript("OnEvent", function() Native.RefreshButtons() end)
    end
    buttonEvents:RegisterEvent("ADDON_LOADED"); buttonEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    local exceptions = Map.Services.Configuration.ParseButtonNames(options.buttonExceptions)
    local ranks = Map.Services.Configuration.ParseButtonNames(options.buttonOrder)
    local list, seen = {}, {}
    local function Add(frame)
        if not seen[frame] and ButtonCandidate(frame, exceptions) then
            seen[frame] = true; table.insert(list, frame)
        end
    end
    for _, record in pairs(buttonRecords) do
        if record.frame:GetParent() ~= buttonPanel or not ButtonCandidate(record.frame, exceptions) then ReleaseButton(record)
        else Add(record.frame) end
    end
    -- Scan only the minimap and one container level. Never enumerate unrelated
    -- global frames or collect unnamed pins; discovery runs on events/refresh.
    for _, owner in ipairs({Minimap, MinimapCluster}) do
        for _, child in ipairs({owner:GetChildren()}) do
            Add(child)
            if child ~= Minimap and child:GetObjectType() == "Frame" and child.GetChildren then
                for _, nested in ipairs({child:GetChildren()}) do Add(nested) end
            end
        end
    end
    table.sort(list, function(a, b)
        local an, bn = a:GetName(), b:GetName()
        local ar, br = ranks[an] or 9999, ranks[bn] or 9999
        if ar ~= br then return ar < br end
        return an < bn
    end)
    local count = table.getn(list)
    state.buttonCount = count
    if count == 0 then state.buttonNames = ""; buttonPanel:Hide(); return end
    local columns, size, gap = math.min(count, options.buttonColumns), options.buttonSize, options.buttonSpacing
    local rows, names = math.ceil(count / columns), {}
    buttonPanel:SetWidth(12 + columns * size + (columns - 1) * gap)
    buttonPanel:SetHeight(12 + rows * size + (rows - 1) * gap)
    local ratio = Minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local x, y = MapCenter()
    local half, pw, ph = options.size * ratio / 2, buttonPanel:GetWidth(), buttonPanel:GetHeight()
    local side, screenW, screenH = options.buttonSide, UIParent:GetWidth(), UIParent:GetHeight()
    local panelGap = Map.Modules.Information.GetPanelGap
    -- When the map touches a screen edge, prefer the opposite side over
    -- clamping a panel on top of the map. Persist the user's requested side.
    if side == "top" and y + half + panelGap(side) + ph > screenH then side = "bottom"
    elseif side == "bottom" and y - half - panelGap(side) - ph < 0 then side = "top"
    elseif side == "left" and x - half - 8 - pw < 0 then side = "right"
    elseif side == "right" and x + half + 8 + pw > screenW then side = "left" end
    if side == "top" then y = y + half + panelGap(side) + ph / 2
    elseif side == "bottom" then y = y - half - panelGap(side) - ph / 2
    elseif side == "left" then x = x - half - 8 - pw / 2
    else x = x + half + 8 + pw / 2 end
    x = math.max(pw / 2, math.min(UIParent:GetWidth() - pw / 2, x))
    y = math.max(ph / 2, math.min(UIParent:GetHeight() - ph / 2, y))
    buttonPanel:ClearAllPoints(); buttonPanel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    for index, frame in ipairs(list) do
        local record = Record(frame:GetName(), frame); buttonRecords[record.name] = record
        Property(record, "parent", ReadParent, SetParent, buttonPanel)
        Property(record, "scale", ReadScale, SetScale, 1)
        Property(record, "width", ReadWidth, SetWidth, size)
        Property(record, "height", ReadHeight, SetHeight, size)
        Property(record, "strata", ReadStrata, SetStrata, "MEDIUM")
        Property(record, "level", ReadLevel, SetLevel, buttonPanel:GetFrameLevel() + 1)
        local column, row = math.mod(index - 1, columns), math.floor((index - 1) / columns)
        Property(record, "points", ReadPoints, SetPoints, {{"TOPLEFT", buttonPanel, "TOPLEFT", 6 + column * (size + gap), -6 - row * (size + gap)}})
        Script(record, "OnDragStart", NoDrag); Script(record, "OnDragStop", NoDrag)
        names[index] = record.name
    end
    state.buttonNames = table.concat(names, ", ")
    buttonPanel:Show()
end
function Native.RefreshButtons()
    if not state.active or not store then return false, "Enable BootyMap before refreshing buttons." end
    local ok, reason = Call(Buttons, store.preferences)
    if not ok then return Notify(reason) end
    return true
end
function Native.Stop()
    state.active, state.editing = false, false
    if pingSlot then pingSlot.enabled = false end
    if zoneSlot then zoneSlot.enabled = false end
    if mask then mask.enabled = false end
    local failures = {}
    local function Attempt(callback, ...)
        local ran, ok, reason = Call(callback, unpack(arg))
        if not ran or ok == false then table.insert(failures, tostring(ran and reason or ok)) end
    end
    Attempt(CancelDrag)
    Attempt(Map.Modules.Information.Stop)
    Attempt(StopButtons)
    Attempt(HideOwn, editor); Attempt(HideOwn, surface)
    local env = type(getfenv) == "function" and getfenv(0) or _G
    if pingSlot then
        local ok, reason = ReleaseSlot(env, "Minimap_SetPing", pingSlot.original, pingSlot.guard)
        if ok then pingSlot = nil else table.insert(failures, reason) end
    end
    if zoneSlot then
        local ok, reason = ReleaseSlot(env, "Minimap_Update", zoneSlot.original, zoneSlot.guard)
        if ok then zoneSlot = nil else table.insert(failures, reason) end
    end
    Attempt(ReleaseMask)
    for _, record in pairs(records) do
        if record.visibility then record.visibility.enabled = false end
        for _, lease in pairs(record.scripts) do lease.enabled = false end
        for key in pairs(record.scripts) do Attempt(Script, record, key, nil) end
        for key in pairs(record.leases) do
            if key ~= "clamped" then Attempt(ReleaseProperty, record, key) end
        end
        Attempt(Hidden, record, false)
    end
    -- Re-enable native clamping only after original dimensions and anchors are
    -- restored; early clamping can move an edge anchor and mimic a foreign write.
    for _, record in pairs(records) do Attempt(ReleaseProperty, record, "clamped") end
    state.restorationBlocked = table.getn(failures) > 0
    if state.restorationBlocked then state.failure = table.concat(failures, "; "); return false, state.failure end
    records, store, state.failure = {}, nil, nil
    return true
end
local function ApplyAll()
    CheckOwner()
    -- StartMoving writes transient anchors owned by this drag session. Resolve
    -- them before a settings/profile refresh performs ownership comparisons.
    CancelDrag()
    local options = store.preferences
    state.compatibility = ""
    local map, cluster = Record("Minimap"), Record("MinimapCluster")
    if not map or not cluster then Fail("Native minimap is unavailable.") end
    -- Clamp the visible map in Position, not the larger native cluster with
    -- its zone/button margins. Keep both flags leased for reversible ownership.
    Property(cluster, "clamped", ReadClamp, SetClamp, false)
    Property(map, "clamped", ReadClamp, SetClamp, false)
    local originalSize = map.leases.width and map.leases.width.original or Minimap:GetWidth()
    -- Capture texture geometry before changing the map that owns its anchors.
    local border = Record("MinimapBorder")
    if border then NativeBorder(border, options.size / originalSize) end
    Shape(options); PingCallbacks(options)
    Property(map, "width", ReadWidth, SetWidth, options.size)
    Property(map, "height", ReadHeight, SetHeight, options.size)
    Property(map, "alpha", ReadAlpha, SetAlpha, options.alpha)
    Property(map, "zoom", ReadZoom, SetZoom, options.zoom >= 0 and math.min(options.zoom, Minimap:GetZoomLevels() - 1) or nil)
    if Finite(options.x) and Finite(options.y) then Position(options.x, options.y, options)
    else Property(cluster, "points", ReadPoints, SetPoints, nil) end
    Border(options); Zone(options); Widgets(options)
    Map.Modules.Information.Apply(options)
    Buttons(options)
    if options.shape == "square" and (Global("pfQuest") or Global("pfDB")) then
        Note("pfQuest corner clipping may remain circular; BootyMap does not modify pfQuest or pfUI globals.")
    end
    RefreshEditor()
end
function Native.Apply(value)
    if not state.active then return false, "Native minimap is not active." end
    local valid, failure = Map.Services.Configuration.Validate(value)
    if not valid then return false, failure end
    if not value or type(value.preferences) ~= "table" then return false, "Minimap preferences are unavailable." end
    store = value
    local ok, reason = Call(ApplyAll)
    if not ok then return Notify(reason) end
    state.failure = nil
    return true
end
function Native.Start(value)
    local valid, failure = Map.Services.Configuration.Validate(value)
    if not valid then return false, failure end
    if not value or type(value.preferences) ~= "table" then return false, "Minimap preferences are unavailable." end
    if state.restorationBlocked then local ok, reason = Native.Stop(); if not ok then return false, reason end end
    state.active = true
    local ok, reason = Native.Apply(value)
    if not ok and state.active then return Notify(reason) end
    return ok, reason
end
function Native.GetState() return state end
function Native.ReportInformationFailure(reason) return Notify(reason) end
function Native.SetFailureObserver(callback) failureObserver = type(callback) == "function" and callback or nil end
function Native.SetPositionObserver(callback) positionObserver = type(callback) == "function" and callback or nil end
