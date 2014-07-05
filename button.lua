-- button

local Class = require "hump.class"
local Rectangle = require "rectangle"
local TouchZone = require "touchZone"

local button = Class{}
--button.__index = button
button:include(TouchZone)

function button:init(x, y, width, height)
    self.frame = Rectangle(x or 0, y or 0, width or 0, height or 0)
    self.children = {}
end

return setmetatable({new = new},
    {__call = function(_, ...) return button(...) end})
