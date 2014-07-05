--rectangle

Vector2 = require "hump.vector"

rectangle = {}
rectangle.__index = rectangle

local function new(x, y, width, height)
    return setmetatable({origin = Vector2(x or 0, y or 0), size = Vector2(width or 0, height or 0)}, rectangle)
end

local function isrectangle(v)
    return getmetatable(v) == rectangle
end

local zero = new(Vector2.zero, Vector2.zero)

function rectangle:unpack()
    return self.origin:unpack(), self.size:unpack()
end

function rectangle:vectorIsInside(v)
    return v.x > self.origin.x and v.x < (self.origin.x+self.size.x) and
    v.y > self.origin.y and v.y < (self.origin.y+self.size.y)
end

function rectangle:__tostring()
    return tostring(self.origin)..","..tostring(self.size)
end

return setmetatable({new = new, isrectangle = isrectangle, zero = zero},
{__call = function(_, ...) return new(...) end})