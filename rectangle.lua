--rectangle

local Class = require "hump.class"
local Vector2 = require "hump.vector"

local rectangle = Class{}

function rectangle:init(x, y, width, height)
    self.origin = Vector2(x or 0, y or 0)
    self.size = Vector2(width or 0, height or 0) 
end

local function isrectangle(v)
    return getmetatable(v) == rectangle
end

local zero = rectangle(0, 0, 0, 0)

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

return setmetatable({isrectangle = isrectangle, zero = zero},
{__call = function(_, ...) return rectangle(...) end})