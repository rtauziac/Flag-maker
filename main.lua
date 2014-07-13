local Gamestate = require "hump.gamestate"
local Camera = require "hump.camera"
local Vector2 = require "hump.vector"
local Timer = require "hump.timer"
local Rectangle = require "rectangle"
local TouchZone = require "touchZone"

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
	local h, v, s
	local valMin, valMax, delta
	valMin = math.min(r, math.min(g, b))
	valMax = math.max(r, math.max(g, b))
	v = valMax
	delta = valMax - valMin
	if valMax ~= 0 then
		s = delta / valMax		-- s
	else
		-- r = g = b = 0		-- s = 0, v is undefined
		return 0, v, 0
	end
	
	if r == valMax then
		h = ( g - b ) / delta		-- between yellow & magenta
	elseif g == valMax then
		h = 2 + ( b - r ) / delta	-- between cyan & yellow
	else
		h = 4 + ( r - g ) / delta	-- between magenta & cyan
		h = h *60				-- degrees
	end
	
	if h < 0 then
		h = h + 360
	end
	
	return h, s, v
end

function HSVtoRGB(h, s, v)
	if s == 0 then -- achromatic (grey)
		return v, v, v
	end
	
	local r, g, b
	local i
	local f, p, q, t
	
	h = h / 60			-- sector 0 to 5
	i = math.floor(h)
	f = h - i			-- factorial part of h
	p = v * ( 1 - s )
	q = v * ( 1 - s * f )
	t = v * ( 1 - s * ( 1 - f ) )
	if i == 0 then
		r = v
		g = t
		b = p
	elseif i == 1 then
		r = q
		g = v
		b = p
	elseif i == 2 then
		r = p
		g = v
		b = t
	elseif i == 3 then
		r = p
		g = q
		b = v
	elseif i == 4 then
		r = t
		g = p
		b = v
	else
		r = v
		g = p
		b = q
	end
	
	return r, g, b
end

function gameStates.intro:init()
    self.textString = [[Mounting file system...
Loading boot routine...
Configuring kernel parameters...
Hardware check:
* HDD
* RAM

Input methods:
* keyboard - OK
* mouse - OK

loading GUI]]
    self.currentTextDisplay = ""
    Timer.addPeriodic(0.012, function()
        self.currentTextDisplay = self.textString:sub(1, self.currentTextDisplay:len() + 1)
    end, self.textString:len())
    
    Timer.add(5, function() Gamestate.switch(gameStates.menu) end)
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
        Gamestate.switch(gameStates.createNewFlag)
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
        Gamestate.switch(gameStates.menu)
    end
    
	self.hueSelector = TouchZone(280, 55, 12, 120)
	self.hueSelector.hueSelectorCanvas = love.graphics.newCanvas(self.hueSelector.frame.size.x, self.hueSelector.frame.size.y)
	love.graphics.setCanvas(self.hueSelector.hueSelectorCanvas)
	local row
	for row = 0, 120 do
		local r, g, b = HSVtoRGB(row * 3, 1, 1)
		love.graphics.setColor(r * 255, g * 255, b * 255, 255)
		love.graphics.rectangle("fill", 0, row, self.hueSelector.frame.size.x, row + 1)
	end
	love.graphics.setCanvas()
	self.hueSelector.draw = function(self)
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.draw(self.hueSelectorCanvas, self.frame.origin.x, self.frame.origin.y)
		love.graphics.setColor(255, 255, 255, 128)
        love.graphics.rectangle("line", self.frame.origin.x + 0.5, self.frame.origin.y + 0.5, self.frame.size.x - 1, self.frame.size.y - 1)
	end
	self.hueSelector.onTouchUpInside = function(self, position)
		local hue = math.max(0, math.min(359, ((position.y / self.frame.size.y) - 1) * 180))
		local selectedRegion = self.baseRegion:getSelected()
		if selectedRegion then
			local r, g, b = HSVtoRGB(hue, 1, 1)
			selectedRegion.color = {r * 255, g * 255, b * 255, 255}
		end
	end
	self.hueSelector.onTouchMove = self.hueSelector.onTouchUpInside
	
    self.baseRegion = TouchZone(60, 55, 200, 120)
	self.hueSelector.baseRegion = self.baseRegion
    self.baseRegion.selected = false
    self.baseRegion.color = {255, 0, 0, 255}
	self.baseRegion.getSelected = function(self)
		if self.selected == true then
			return self
		end
		for _, child in ipairs(self.children) do
			local childSelected = child:getSelected()
			if childSelected ~= nil then
				return childSelected
			end
		end
		return nil
	end
    self.baseRegion.draw = function(self)
        love.graphics.setColor(unpack(self.color))
        love.graphics.rectangle("fill", self.frame.origin.x, self.frame.origin.y, self.frame.size.x, self.frame.size.y)
        if self.selected and elapsedTime % 1.5 < 0.5 then
            if elapsedTime % 1.5 < 0.25 then
                love.graphics.setColor(255, 255, 255, 64)
            else
                love.graphics.setColor(0, 0, 0, 64)
            end
            love.graphics.rectangle("fill", self.frame.origin.x, self.frame.origin.y, self.frame.size.x, self.frame.size.y)
        end
    end
    self.baseRegion.onTouchUpInside = function(self)
        self.selected = not self.selected
    end
    
    table.insert(self.rootTouchZones, self.backButton)
    table.insert(self.rootTouchZones, self.baseRegion)
	table.insert(self.rootTouchZones, self.hueSelector)
end

function gameStates.createNewFlag:update()
	
end

function gameStates.createNewFlag:draw()
    local convertedTouchLocation = (Vector2(love.mouse.getPosition()) * screenScale) - Vector2(((love.window.getWidth() * screenScale) - designResolution.x) / 2, 0)
    
    love.graphics.setCanvas(mainCanvas)
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.rectangle("fill", unpack(backgroundSize))
    love.graphics.setFont(computerFont)
    love.graphics.setColor(20, 20, 20, 240)
    self.backButton:draw()
    self.baseRegion:draw()
	self.hueSelector:draw()
    
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
    
    if love.mouse.isDown("l") then
        for i, shape in ipairs(propagateLeftMouseEvent) do
            shape:onTouchMove(mousePosition, delta * screenScale)
        end
    end
end

function love.draw()
    sceneCamera:attach()
    --love.graphics.setShader(mainShader)
    love.graphics.setColor(15, 30, 15, 255)
    love.graphics.rectangle("fill", unpack(backgroundSize))
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.draw(mainCanvas)
    
    --love.graphics.setShader()
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