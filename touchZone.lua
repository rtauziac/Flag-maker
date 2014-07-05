--touchZone

Rectangle = require "rectangle"

local touchZone = {}
touchZone.__index = touchZone

local function new(x, y, width, height)
    return setmetatable({
        frame = Rectangle(x or 0, y or 0, width or 0, height or 0),
        children = {}},
        touchZone)
end

function touchZone:touchInside(v)
    local hit = self.frame:vectorIsInside(v)
    if hit then
        for _, child in ipairs(self.children) do
            local childHit = child:touchInside(v)
            if childHit then return child end
        end
        return self
    end
    return nil
end

function touchZone:addChild(c)
    table.insert(self.children, c)
end

return setmetatable({new = new},
    {__call = function(_, ...) return new(...) end})
