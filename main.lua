local Gamestate = require "hump.gamestate"
local Camera = require "hump.camera"
local Vector2 = require "hump.vector"
local Timer = require "hump.timer"
local Rectangle = require "rectangle"
local TouchZone = require "touchZone"

local min, max, floor = math.min, math.max, math.floor

function printHierarchy(root, topLevel)
    local level = topLevel or ""
    level = level.."    "
    print(level..tostring(root))
    for _, child in ipairs(root.children) do
        printHierarchy(child, level)
    end
end

local designResolution = {x = 320, y = 240}
local backgroundSize = {0, 0, designResolution.x, designResolution.y}
local mainShader = nil
local elapsedTime = 0

local previousMousePosition = Vector2(love.mouse.getPosition())
local screenScale

local propagateLeftMouseEvent = {}

local mainCanvas = love.graphics.newCanvas(designResolution.x, designResolution.y)
mainCanvas:setFilter("nearest")

local computerFont = love.graphics.newFont("assets/data-latin.ttf", 12)
local computerFontSmall = love.graphics.newFont("assets/data-latin.ttf", 10)

local selectedRegion = nil

local gameStates = {
    intro = {},
    menu = {},
    createNewFlag = {}
}

function RGBtoHSV(r, g, b)
    if r >= 255 and g >= 255 and b >= 255 then
        return 0, 0, 255
    end
    local valMin, valMax, delta
    local h, s, v
    
    valMin = min(r, min(g, b))
    valMax = max(r, max(g, b))

    v = valMax  -- v
    delta = valMax - valMin
    if valMax > 0  then -- NOTE: if Max is == 0, this divide would cause a crash
        s = (delta / valMax) -- s
    else
        return 0, 0, v
    end
    
    if r >= valMax then                           -- > is bogus, just keeps compilor happy
        h = (g - b) / delta        -- between yellow & magenta
    elseif g >= valMax then
        h = 2.0 + (b - r) / delta  -- between cyan & yellow
    else
        h = 4.0 + (r - g) / delta  -- between magenta & cyan
    end
    
    h = h * 60.0  -- degrees

    if h < 0.0 then
        h = h + 360.0
    end
    
    return h, s, v
end

function HSVtoRGB(h, s, v)
    local hh, p, q, t, ff
    local i
    local r, g, b

    if s <= 0 then       -- < is bogus, just shuts up warnings
        return v, v, v
    end
    hh = h;
    if hh >= 360 then
        hh = 0
    end
    
    hh = hh / 60
    i = floor(hh)
    ff = hh - i
    p = v * (1 - s)
    q = v * (1 - (s * ff))
    t = v * (1 - (s * (1 - ff)))

    if i == 0 then
        return v, t, p
    elseif i == 1 then
        return q, v, p
    elseif i == 2 then
        return p, v, t
    elseif i == 3 then
        return p, q, v
    elseif i ==  4 then
        return t, p, v
    else
        return v, p, q
    end
end

function gameStates.intro:init()
    self.textString = [[user@love: session started
>flagmaker
Welcome to flag maker #2.0
Program made by (c)Crazyrems
loading GUI]]
    self.currentTextDisplay = ""
    Timer.addPeriodic(0.012, function()
        self.currentTextDisplay = self.textString:sub(1, self.currentTextDisplay:len() + 1)
    end, self.textString:len())
    
    Timer.add(5.12, function() Gamestate.switch(gameStates.menu) end)
end

function gameStates.intro:draw()
    love.graphics.setCanvas(mainCanvas)
    mainCanvas:clear()
    love.graphics.setColor(60, 255, 60, 240)
    local mark = ""
    if elapsedTime % 1 < 0.5 then
        mark = "_"
    end
    love.graphics.setFont(computerFont)
    love.graphics.print(self.currentTextDisplay..mark, 15, 15)
    love.graphics.setCanvas()
end

function gameStates.menu:init()
    self.rootTouchZones = {}
    
    self.createFlagButton = TouchZone(15, 35, 80, 15)
    self.createFlagButton.draw = function(self)
        if self.hit then
            love.graphics.setColor(50, 50, 50, 128)
        else
            love.graphics.setColor(50, 50, 50, 255)
        end
        love.graphics.setFont(computerFontSmall)
        love.graphics.setLineWidth(1)
        love.graphics.print("create new flag", self.frame.origin.x + 2, self.frame.origin.y + 2)
        love.graphics.rectangle("line", self.frame.origin.x + 0.5, self.frame.origin.y + 0.5, self.frame.size.x, self.frame.size.y)
    end
    self.createFlagButton.onTouchUpInside = function(self, position, delta)
        Gamestate.push(gameStates.createNewFlag)
    end
    
    self.quitButton = TouchZone(15, 55, 24, 15)
    self.quitButton.draw = function(self)
        if self.hit then
            love.graphics.setColor(50, 50, 50, 128)
        else
            love.graphics.setColor(50, 50, 50, 255)
        end
        love.graphics.setFont(computerFontSmall)
        love.graphics.setLineWidth(1)
        love.graphics.print("quit", self.frame.origin.x + 2, self.frame.origin.y + 2)
        love.graphics.rectangle("line", self.frame.origin.x + 0.5, self.frame.origin.y + 0.5, self.frame.size.x, self.frame.size.y)
    end
    self.quitButton.onTouchUpInside = function(self)
        love.event.quit()
    end
    
    table.insert(self.rootTouchZones, self.createFlagButton)
    table.insert(self.rootTouchZones, self.quitButton)
end

function gameStates.menu:mousepressed(x, y, button)
    local convertedTouchLocation = (Vector2(x, y) * screenScale) - Vector2(((love.window.getWidth() * screenScale) - designResolution.x) / 2, 0)
    if button == "l" then
        local zoneHit = nil
        for _, zone in ipairs(self.rootTouchZones) do
            zoneHit = zone:touchInside(convertedTouchLocation)
            if zoneHit then break end
        end
        if zoneHit then
            zoneHit:onTouchDown(convertedTouchLocation)
            table.insert(propagateLeftMouseEvent, zoneHit)
        end
    end
end

function gameStates.menu:mousereleased(x, y, button)
    local convertedTouchLocation = (Vector2(x, y) * screenScale) - Vector2(((love.window.getWidth() * screenScale) - designResolution.x) / 2, 0)
    if button == "l" then
        for _, zone in ipairs(propagateLeftMouseEvent) do
            zone:onTouchUp(convertedTouchLocation)
        end
        
        propagateLeftMouseEvent = {}
    end
end

function gameStates.menu:draw()
    local convertedTouchLocation = (Vector2(love.mouse.getPosition()) * screenScale) - Vector2(((love.window.getWidth() * screenScale) - designResolution.x) / 2, 0)
    convertedTouchLocation.x = floor(convertedTouchLocation.x)
    convertedTouchLocation.y = floor(convertedTouchLocation.y)
    
    love.graphics.setCanvas(mainCanvas)
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.rectangle("fill", unpack(backgroundSize))
    love.graphics.setFont(computerFont)
    love.graphics.setColor(20, 20, 20, 240)
    love.graphics.print("Welcome to Flag maker 2.0", 10, 10, 0, 1, 1)
    self.createFlagButton:draw()
    self.quitButton:draw()
    
    -- the mouse
    love.graphics.setColor(0, 0, 0, 180)
    love.graphics.rectangle("fill", convertedTouchLocation.x - 4, convertedTouchLocation.y, 3, 1)
    love.graphics.rectangle("fill", convertedTouchLocation.x + 2, convertedTouchLocation.y, 3, 1)
    love.graphics.rectangle("fill", convertedTouchLocation.x, convertedTouchLocation.y - 4, 1, 3)
    love.graphics.rectangle("fill", convertedTouchLocation.x, convertedTouchLocation.y + 2, 1, 3)
    love.graphics.setCanvas()
end

function gameStates.createNewFlag:init()
    self.rootTouchZones = {}
    
    self.backButton = TouchZone(15, 15, 25, 15)
    self.backButton.draw = function(self)
        if self.hit then
            love.graphics.setColor(50, 50, 50, 128)
        else
            love.graphics.setColor(50, 50, 50, 255)
        end
        love.graphics.setFont(computerFontSmall)
        love.graphics.setLineWidth(1)
        love.graphics.print("back", self.frame.origin.x + 2, self.frame.origin.y + 2)
        love.graphics.rectangle("line", self.frame.origin.x + 0.5, self.frame.origin.y + 0.5, self.frame.size.x, self.frame.size.y)
    end
    
    self.backButton.onTouchUpInside = function(self, position, delta)
        Gamestate.pop()
    end
    
    self.colorPicker = TouchZone(280, 55, 12, 120)
    self.colorPicker.script = self
    self.colorPicker.setColor = function(self, r, g, b)
        self.hue, self.sat, self.val = RGBtoHSV(r, g, b)
        if self.script.colorTool.tool == "H" then
            self:renderHueCanvas()
        elseif self.script.colorTool.tool == "S" then
            self:renderSatCanvas()
        elseif self.script.colorTool.tool == "V" then
            self:renderValCanvas()
        end
    end
    self.colorPicker.colorPickerHueCanvas = love.graphics.newCanvas(self.colorPicker.frame.size.x, self.colorPicker.frame.size.y)
    self.colorPicker.colorPickerSatCanvas = love.graphics.newCanvas(self.colorPicker.frame.size.x, self.colorPicker.frame.size.y)
    self.colorPicker.colorPickerValCanvas = love.graphics.newCanvas(self.colorPicker.frame.size.x, self.colorPicker.frame.size.y)
    self.colorPicker.renderHueCanvas = function(self)
        love.graphics.setCanvas(self.colorPickerHueCanvas)
        local row
        for row = 0, 120 do
            local r, g, b = HSVtoRGB(row * 3, self.sat, self.val)
            love.graphics.setColor(r, g, b, 255)
            love.graphics.rectangle("fill", 0, row, self.frame.size.x, row + 1)
        end
        love.graphics.setCanvas()
    end
    self.colorPicker.renderSatCanvas = function(self)
        love.graphics.setCanvas(self.colorPickerSatCanvas)
        for row = 0, 120 do
            local r, g, b = HSVtoRGB(self.hue, row*0.008333333, self.val)
            love.graphics.setColor(r, g, b, 255)
            love.graphics.rectangle("fill", 0, row, self.frame.size.x, row + 1)
        end
        love.graphics.setCanvas()
    end
    self.colorPicker.renderValCanvas = function(self)
        love.graphics.setCanvas(self.colorPickerValCanvas)
        for row = 0, 120 do
            local r, g, b = HSVtoRGB(self.hue, self.sat, row*2.125)
            love.graphics.setColor(r, g, b, 255)
            love.graphics.rectangle("fill", 0, row, self.frame.size.x, row + 1)
        end
        love.graphics.setCanvas()
    end
    
    self.colorPicker.getColor = function(self)
        local r, g, b = HSVtoRGB(self.hue, self.sat, self.val)
        return {r, g, b, 255}
    end
    self.colorPicker.draw = function(self)
        love.graphics.setColor(255, 255, 255, 255)
        local toolCanvas, cursor
        if self.script.colorTool.tool == "H" then
            toolCanvas = self.colorPickerHueCanvas
            cursor = (self.hue / 3) + self.frame.origin.y
        elseif self.script.colorTool.tool == "S" then
            toolCanvas = self.colorPickerSatCanvas
            cursor = (self.sat / 0.008333333) + self.frame.origin.y
        elseif self.script.colorTool.tool == "V" then
            toolCanvas = self.colorPickerValCanvas
            cursor = (self.val / 2.125) + self.frame.origin.y
        end
        love.graphics.draw(toolCanvas, self.frame.origin.x, self.frame.origin.y)
        love.graphics.setColor(255, 255, 255, 128)
        love.graphics.rectangle("line", self.frame.origin.x + 0.5, self.frame.origin.y + 0.5, self.frame.size.x - 1, self.frame.size.y - 1)
        love.graphics.rectangle("fill", self.frame.origin.x, floor(cursor) - 0.5, self.frame.size.x, 1)
        love.graphics.setColor(0, 0, 0, 128)
        love.graphics.rectangle("line", self.frame.origin.x - 0.5, floor(cursor) - 0.5, self.frame.size.x + 1, 2)
    end
    self.colorPicker.onTouchUpInside = function(self, position)
        local selectedRegion = self.script.baseRegion:getSelected()
        if selectedRegion ~= nil then
            if self.script.colorTool.tool == "H" then
                self.hue = math.max(0, math.min(360, ((position.y - self.frame.origin.y) / self.frame.size.y) * 360))
            elseif self.script.colorTool.tool == "S" then
                self.sat = math.max(0, math.min(1, (position.y - self.frame.origin.y) / self.frame.size.y))
            elseif self.script.colorTool.tool == "V" then
                self.val = math.max(0, math.min(255, ((position.y - self.frame.origin.y) / self.frame.size.y) * 255))
            end
            
            selectedRegion.color = self:getColor()
        end
    end
    self.colorPicker.onTouchMove = self.colorPicker.onTouchUpInside
    
    self.colorTool = TouchZone(278, 180, 16, 16)
    self.colorTool.script = self
    self.colorTool.tool = "H"
    self.colorTool.draw = function(self)
        if self.hit then
            love.graphics.setColor(50, 50, 50, 128)
        else
            love.graphics.setColor(50, 50, 50, 255)
        end
        love.graphics.setFont(computerFontSmall)
        love.graphics.setLineWidth(1)
        love.graphics.print(self.tool, self.frame.origin.x + 5, self.frame.origin.y + 2)
        love.graphics.rectangle("line", self.frame.origin.x + 0.5, self.frame.origin.y + 0.5, self.frame.size.x, self.frame.size.y)
    end
    self.colorTool.onTouchUpInside = function(self)
        if self.tool == "H" then
            self.tool = "S"
        elseif self.tool == "S" then
            self.tool = "V"
        elseif self.tool == "V" then
            self.tool = "H"
        end
        
        self.script.colorPicker:renderHueCanvas()
        self.script.colorPicker:renderSatCanvas()
        self.script.colorPicker:renderValCanvas()
    end
    
    self.colorToBufferButton = TouchZone(278, 200, 16, 16)
    self.colorToBufferButton.script = self
    self.colorToBufferButton.draw = function(self)
        if self.hit then
            love.graphics.setColor(50, 50, 50, 128)
        else
            love.graphics.setColor(50, 50, 50, 255)
        end
        love.graphics.setFont(computerFontSmall)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", self.frame.origin.x + 0.5, self.frame.origin.y + 0.5, self.frame.size.x, self.frame.size.y)
        love.graphics.setFont(computerFontSmall)
        love.graphics.print("<", self.frame.origin.x + 5, self.frame.origin.y + 2)
    end
    self.colorToBufferButton.onTouchUpInside = function(self)
        local r, g, b, a = unpack(self.script.colorPicker:getColor())
        self.script.colorBufferButton:setColor(r, g, b)
    end
    
    self.colorBufferButton = TouchZone(258, 200, 16, 16)
    self.colorBufferButton.script = self
    self.colorBufferButton.color = nil
    self.colorBufferButton.draw = function(self)
        local transparent
        if self.hit then
            transparent = 128
        else
            transparent = 255
        end
        love.graphics.setColor(50, 50, 50, transparent)
        love.graphics.setFont(computerFontSmall)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", self.frame.origin.x + 0.5, self.frame.origin.y + 0.5, self.frame.size.x, self.frame.size.y)
        if self.color then
            local r, g, b, a = unpack(self.color)
            love.graphics.setColor(r, g, b, transparent)
            love.graphics.rectangle("fill", self.frame.origin.x + 2, self.frame.origin.y + 2, self.frame.size.x - 3, self.frame.size.y - 3)
        end
    end
    self.colorBufferButton.setColor = function(self, r, g, b)
        self.color = {r, g, b, 255}
    end
    self.colorBufferButton.onTouchUpInside = function(self)
        local selectedRegion = self.script.baseRegion:getSelected()
        if selectedRegion ~= nil and self.color ~= nil then
            selectedRegion.color = self.color
            local r, g, b, a = unpack(self.color)
            self.script.colorPicker:setColor(r, g, b)
        end
    end
    
    self.splitHorizontalButton = TouchZone(60, 190, 22, 16)
    self.splitHorizontalButton.script = self
    self.splitHorizontalButton.draw = function(self)
        if self.hit then
            love.graphics.setColor(50, 50, 50, 128)
        else
            love.graphics.setColor(50, 50, 50, 255)
        end
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", self.frame.origin.x + 0.5, self.frame.origin.y + 0.5, self.frame.size.x, self.frame.size.y)
        love.graphics.rectangle("fill", self.frame.origin.x + 2, self.frame.origin.y + 2, (self.frame.size.x / 2) - 2 , self.frame.size.y - 3)
        love.graphics.rectangle("fill", self.frame.origin.x + 1 + (self.frame.size.x / 2), self.frame.origin.y + 2, (self.frame.size.x / 2) - 2 , self.frame.size.y - 3)
    end
    self.splitHorizontalButton.onTouchUpInside = function (self)
        local selectedRegion = self.script.baseRegion:getSelected()
        if selectedRegion ~= nil then
            local childLeft, childRight = selectedRegion:splitHorizontal()
            --printHierarchy(self.script.baseRegion)
            childLeft.splitHorizontal = selectedRegion.splitHorizontal
            childRight.splitHorizontal = selectedRegion.splitHorizontal
            childLeft.splitVertical = selectedRegion.splitVertical
            childRight.splitVertical = selectedRegion.splitVertical
        end
    end
    
    self.splitVerticalButton = TouchZone(90, 190, 22, 16)
    self.splitVerticalButton.script = self
    self.splitVerticalButton.draw = function(self)
        if self.hit then
            love.graphics.setColor(50, 50, 50, 128)
        else
            love.graphics.setColor(50, 50, 50, 255)
        end
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", self.frame.origin.x + 0.5, self.frame.origin.y + 0.5, self.frame.size.x, self.frame.size.y)
        love.graphics.rectangle("fill", self.frame.origin.x + 2, self.frame.origin.y + 2, self.frame.size.x - 3, (self.frame.size.y / 2) - 2)
        love.graphics.rectangle("fill", self.frame.origin.x + 2, self.frame.origin.y + 1 + (self.frame.size.y / 2), self.frame.size.x - 3, (self.frame.size.y / 2) - 2)
    end
    self.splitVerticalButton.onTouchUpInside = function (self)
        local selectedRegion = self.script.baseRegion:getSelected()
        if selectedRegion ~= nil then
            local childTop, childBottom = selectedRegion:splitVertical()
            --printHierarchy(self.script.baseRegion)
            childTop.splitHorizontal = selectedRegion.splitHorizontal
            childBottom.splitHorizontal = selectedRegion.splitHorizontal
            childTop.splitVertical = selectedRegion.splitVertical
            childBottom.splitVertical = selectedRegion.splitVertical
        end
    end
    
    self.colorPicker:setColor(255, 0, 0) --base init
    
    self.baseRegion = TouchZone(60, 55, 200, 120)
    self.baseRegion.script = self
    self.children = {}
    self.baseRegion.selected = false
    self.baseRegion.color = {255, 0, 0, 255}
    self.baseRegion.getSelected = function(self)
        for _, child in ipairs(self.children) do
            local childSelected = child:getSelected()
            if childSelected ~= nil then
                return childSelected
            end
        end
        if #self.children == 0 and self.selected == true then
            return self
        end
        return nil
    end
    self.baseRegion.draw = function(self)
        if #self.children > 0 then -- draw children
            local child
            for _, child in ipairs(self.children) do
                child:draw()
            end
        else -- draw self
            love.graphics.setColor(unpack(self.color))
            love.graphics.rectangle("fill", self.frame.origin.x, self.frame.origin.y, self.frame.size.x, self.frame.size.y)
            if self.selected and elapsedTime % 1 < 0.5 then
                love.graphics.setColor(255, 255, 255, 128)
            elseif self.selected then
                love.graphics.setColor(0, 0, 0, 128)
            end
            love.graphics.rectangle("line", self.frame.origin.x + 0.5, self.frame.origin.y + 0.5, self.frame.size.x - 1, self.frame.size.y - 1)
        end
    end
    self.baseRegion.onTouchUpInside = function(self)
        local previousSelected = self.script.baseRegion:getSelected()
        if previousSelected then
            previousSelected.selected = false
        end
        if previousSelected ~= self then
            self.selected = not self.selected
        end
        if self.selected then
            local r, g, b, a = unpack(self.color)
            self.script.colorPicker:setColor(r, g, b)
        end
    end
    self.baseRegion.splitHorizontal = function(self)
        local childLeft, childRight
        childLeft = TouchZone(self.frame.origin.x, self.frame.origin.y, self.frame.size.x / 2, self.frame.size.y)
        childLeft.script = self.script
        childLeft.children = {}
        childLeft.selected = true
        childLeft.color = self.color
        childLeft.getSelected = self.script.baseRegion.getSelected
        childLeft.draw = self.script.baseRegion.draw
        childLeft.onTouchUpInside = self.script.baseRegion.onTouchUpInside
        ----
        childRight = TouchZone(self.frame.origin.x + self.frame.size.x / 2, self.frame.origin.y, self.frame.size.x / 2, self.frame.size.y)
        childRight.script = self.script
        childRight.children = {}
        childRight.selected = false
        childRight.color = self.color
        childRight.getSelected = self.script.baseRegion.getSelected
        childRight.draw = self.script.baseRegion.draw
        childRight.onTouchUpInside = self.script.baseRegion.onTouchUpInside
        
        self:addChild(childLeft)
        self:addChild(childRight)
        
        return childLeft, childRight
    end
    self.baseRegion.splitVertical = function(self)
        local childTop, childBottom
        childTop = TouchZone(self.frame.origin.x, self.frame.origin.y, self.frame.size.x, self.frame.size.y / 2)
        childTop.script = self.script
        childTop.children = {}
        childTop.selected = true
        childTop.color = self.color
        childTop.getSelected = self.script.baseRegion.getSelected
        childTop.draw = self.script.baseRegion.draw
        childTop.onTouchUpInside = self.script.baseRegion.onTouchUpInside
        ----
        childBottom = TouchZone(self.frame.origin.x, self.frame.origin.y + self.frame.size.y / 2, self.frame.size.x, self.frame.size.y / 2)
        childBottom.script = self.script
        childBottom.children = {}
        childBottom.selected = false
        childBottom.color = self.color
        childBottom.getSelected = self.script.baseRegion.getSelected
        childBottom.draw = self.script.baseRegion.draw
        childBottom.onTouchUpInside = self.script.baseRegion.onTouchUpInside
        
        self:addChild(childTop)
        self:addChild(childBottom)
        
        return childTop, childBottom
    end
    
    self.unfocus = TouchZone(0, 0, designResolution.x, designResolution.y)
    self.unfocus.script = self
    self.unfocus.onTouchUpInside = function(self)
        local selection = self.script.baseRegion:getSelected()
        if selection then selection.selected = false end
    end
    
    table.insert(self.rootTouchZones, self.backButton)
    table.insert(self.rootTouchZones, self.baseRegion)
    table.insert(self.rootTouchZones, self.colorPicker)
    table.insert(self.rootTouchZones, self.colorTool)
    table.insert(self.rootTouchZones, self.splitHorizontalButton)
    table.insert(self.rootTouchZones, self.splitVerticalButton)
    table.insert(self.rootTouchZones, self.colorToBufferButton)
    table.insert(self.rootTouchZones, self.colorBufferButton)
    
    table.insert(self.rootTouchZones, self.unfocus)
end

function gameStates.createNewFlag:enter()
    self.baseRegion.color = {255, 0, 0, 255}
    self.baseRegion.selected = false
    self.baseRegion.children = {}
    
    self.colorPicker:renderHueCanvas()
    self.colorPicker:renderSatCanvas()
    self.colorPicker:renderValCanvas()
end

function gameStates.createNewFlag:update()
    
end

function gameStates.createNewFlag:draw()
    local convertedTouchLocation = (Vector2(love.mouse.getPosition()) * screenScale) - Vector2(((love.window.getWidth() * screenScale) - designResolution.x) / 2, 0)
    convertedTouchLocation.x = floor(convertedTouchLocation.x)
    convertedTouchLocation.y = floor(convertedTouchLocation.y)
    
    love.graphics.setCanvas(mainCanvas)
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.rectangle("fill", unpack(backgroundSize))
    love.graphics.setFont(computerFont)
    love.graphics.setColor(20, 20, 20, 240)
    self.backButton:draw()
    love.graphics.rectangle("line", self.baseRegion.frame.origin.x - 0.5, self.baseRegion.frame.origin.y - 0.5, self.baseRegion.frame.size.x + 1, self.baseRegion.frame.size.y + 1)
    self.baseRegion:draw()
    local selectedRegion = self.baseRegion:getSelected()
    if selectedRegion ~= nil then
        self.colorPicker:draw()
        self.colorTool:draw()
        self.colorToBufferButton:draw()
        self.colorBufferButton:draw()
        self.splitHorizontalButton:draw()
        self.splitVerticalButton:draw()
    end
    
    -- the mouse
    love.graphics.setColor(0, 0, 0, 180)
    love.graphics.rectangle("fill", convertedTouchLocation.x - 4, convertedTouchLocation.y, 3, 1)
    love.graphics.rectangle("fill", convertedTouchLocation.x + 2, convertedTouchLocation.y, 3, 1)
    love.graphics.rectangle("fill", convertedTouchLocation.x, convertedTouchLocation.y - 4, 1, 3)
    love.graphics.rectangle("fill", convertedTouchLocation.x, convertedTouchLocation.y + 2, 1, 3)
    love.graphics.setCanvas()
end

function gameStates.createNewFlag:mousepressed(x, y, button)
    local convertedTouchLocation = (Vector2(x, y) * screenScale) - Vector2(((love.window.getWidth() * screenScale) - designResolution.x) / 2, 0)
    if button == "l" then
        local zoneHit = nil
        for _, zone in ipairs(self.rootTouchZones) do
            zoneHit = zone:touchInside(convertedTouchLocation)
            if zoneHit then break end
        end
        if zoneHit then
            zoneHit:onTouchDown(convertedTouchLocation)
            table.insert(propagateLeftMouseEvent, zoneHit)
        end
    end
end

function gameStates.createNewFlag:mousereleased(x, y, button)
    local convertedTouchLocation = (Vector2(x, y) * screenScale) - Vector2(((love.window.getWidth() * screenScale) - designResolution.x) / 2, 0)
    if button == "l" then
        for _, zone in ipairs(propagateLeftMouseEvent) do
            zone:onTouchUp(convertedTouchLocation)
        end
        
        propagateLeftMouseEvent = {}
    end
end

function love.load()
    Gamestate.registerEvents()
    Gamestate.switch(gameStates.menu)
    --modes = love.window.getFullscreenModes()
    --table.sort(modes, function(a, b) return a.width * a.height < b.width * b.height end)
    love.window.setMode(designResolution.x * 2, designResolution.y * 2, {resizable = true, fullscreen = false, minwidth = designResolution.x, minheight = designResolution.y})
    love.window.setTitle("Flag maker 2.0")
    love.mouse.setVisible(false)
    
    sceneCamera = Camera()
    sceneCamera:zoomTo(love.window.getHeight() / designResolution.y)
    sceneCamera:lookAt(designResolution.x / 2, designResolution.y / 2)
    screenScale = designResolution.y / love.window.getHeight()
    
    mainShader = love.graphics.newShader("shader.frag")
    mainShader:send("screen_size", {love.window.getWidth(), love.window.getHeight()})
    mainShader:send("elapsed_time", elapsedTime)
end

function love.resize(w, h)
    sceneCamera:zoomTo(h / designResolution.y)
    sceneCamera:lookAt(designResolution.x / 2, designResolution.y / 2)
    lineWidthRatio = 1 / love.window.getHeight()
    love.graphics.setLineWidth(lineWidthRatio)
    mainShader:send("screen_size", {love.window.getWidth(), love.window.getHeight()})
    screenScale = designResolution.y / h
end

function love.update(dt)
    Timer.update(dt)
    elapsedTime = elapsedTime + dt;
    mainShader:send("elapsed_time", elapsedTime)
    
    local mousePosition = Vector2(love.mouse.getPosition())
    local delta = mousePosition - previousMousePosition
    previousMousePosition = mousePosition
    
    if love.mouse.isDown("l") and (delta.x ~= 0 or delta.y ~= 0) then
        for i, shape in ipairs(propagateLeftMouseEvent) do
            shape:onTouchMove(mousePosition * screenScale, delta * screenScale)
        end
    end
end

function love.draw()
    sceneCamera:attach()
    love.graphics.setShader(mainShader)
    love.graphics.setColor(15, 30, 15, 255)
    love.graphics.rectangle("fill", unpack(backgroundSize))
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.draw(mainCanvas)
    
    love.graphics.setShader()
    sceneCamera:detach()
end

function love.keypressed(key, isrepeat)
    if key == "return" then
        if love.keyboard.isDown("lalt") then
            success = love.window.setFullscreen(not love.window.getFullscreen())
        end
   end
end

function love.mousepressed(x, y, button)
    
end

function love.mousereleased(x, y, button)
    
end
