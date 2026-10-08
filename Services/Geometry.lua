local Geometry = {}
BootyMap.Services.Geometry = Geometry
function Geometry.Dimensions(options)
    local size = options.size
    if options.shape == "wide" then return size, math.floor(size * 2 / 3 + 0.5) end
    if options.shape == "tall" then return math.floor(size * 2 / 3 + 0.5), size end
    return size, size
end
function Geometry.Contains(shape, width, height, x, y, inset)
    if type(x) ~= "number" or type(y) ~= "number" or x - x ~= 0 or y - y ~= 0 then return false end
    inset = inset or 0
    if type(inset) ~= "number" or inset < 0 or inset - inset ~= 0 then return false end
    local hw, hh = width / 2 - inset, height / 2 - inset
    if hw <= 0 or hh <= 0 then return false end
    if shape == "circle" then return x * x / (hw * hw) + y * y / (hh * hh) <= 1 end
    return math.abs(x) <= hw and math.abs(y) <= hh
end
