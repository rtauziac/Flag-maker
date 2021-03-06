﻿--touchZone

local Class = require "hump.class"
local Rectangle = require "rectangle"

local touchZone = Class{}

function touchZone:init(x, y, width, height)
    self.frame = Rectangle(x or 0, y or 0, width or 0, height or 0)
    self.children = {}
    self.hit = false
end

function touchZone:touchInside(v)
    local justHit = self.frame:vectorIsInside(v)
    if justHit then
        for _, child in ipairs(self.children) do
            local childHit = child:touchInside(v)
            if childHit then return childHit end
        end
        return self
    end
    return nil
end

function touchZone:addChild(c)
    table.insert(self.children, c)
end

function touchZone:onTouchDown(position)
    self.hit = true
end

function touchZone:onTouchMove(position, delta) end

function touchZone:onTouchUp(position)
    local elementTouched = self:touchInside(position)
    if self.hit and elementTouched then
        elementTouched:onTouchUpInside(position)
    end
    self.hit = false
end

function touchZone:onTouchUpInside(position) end

return setmetatable({},
    {__call = function(_, ...) return touchZone(...) end})
