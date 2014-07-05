local Camera = require "hump.camera"
local Vector2 = require "hump.vector"
local Rectangle = require "rectangle"
local TouchZone = require "touchZone"

local designResolution = {x = 320, y = 240}
local backgroundSize = {0, 0, designResolution.x, designResolution.y}
local mainShader = nil
local shaderElapsedTime = 0

local previousMousePosition = Vector2(love.mouse.getPosition())
local screenScale

local propagateLeftMouseEvent = {}
local rootTouchZones = {}
local redShape = TouchZone(15, 35, 70, 15)
function redShape:onTouchMove(position, delta)
    self.frame.origin = self.frame.origin + (delta)
end
local yellowShape = TouchZone(15, 55, 50, 15)
yellowShape.onTouchUpInside = function(self)
    print("lksjdlkgj")
    love.event.quit()
end
table.insert(rootTouchZones, yellowShape)
table.insert(rootTouchZones, redShape)

local mainCanvas = love.graphics.newCanvas(designResolution.x, designResolution.y)
mainCanvas:setFilter("nearest")

local gameStates = {
    intro = {},
    menu = {}
}

local computerFont = love.graphics.newFont("assets/data-latin.ttf", 12)

function love.load()
    modes = love.window.getFullscreenModes()
    table.sort(modes, function(a, b) return a.width * a.height < b.width * b.height end)
    love.window.setMode(modes[#modes].width, modes[#modes].height, {resizable = true, fullscreen = true, minwidth = designResolution.x, minheight = designResolution.y})
    love.window.setTitle("Flag maker terminal")
    love.mouse.setVisible(false)
    
    sceneCamera = Camera()
    sceneCamera:zoomTo(love.window.getHeight() / designResolution.y)
    sceneCamera:lookAt(designResolution.x / 2, designResolution.y / 2)
    screenScale = designResolution.y / love.window.getHeight()
    
    mainShader = love.graphics.newShader("shader.fs")
    mainShader:send("screen_size", {love.window.getWidth(), love.window.getHeight()})
    mainShader:send("elapsed_time", shaderElapsedTime)
    love.graphics.setFont(computerFont)
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
    shaderElapsedTime = shaderElapsedTime + dt;
    mainShader:send("elapsed_time", shaderElapsedTime)
    
    local mousePosition = Vector2(love.mouse.getPosition())
    local delta = mousePosition - previousMousePosition
    previousMousePosition = mousePosition
    
    if love.mouse.isDown("l") then
        for i, shape in ipairs(propagateLeftMouseEvent) do
            --shape.frame.origin = shape.frame.origin + (delta * screenScale)
            shape:onTouchMove(mousePosition, delta * screenScale)
        end
    end
end

function love.draw()
    local convertedTouchLocation = (Vector2(love.mouse.getPosition()) * screenScale) - Vector2(((love.window.getWidth() * screenScale) - designResolution.x) / 2, 0)
    
    love.graphics.setCanvas(mainCanvas)
    love.graphics.setColor(15, 30, 15, 255)
    --love.graphics.setColor(255, 255, 255, 255)
    love.graphics.rectangle("fill", unpack(backgroundSize))
    love.graphics.setColor(255, 0, 0, 255)
    love.graphics.rectangle("fill", redShape.frame.origin.x, redShape.frame.origin.y, redShape.frame.size.x, redShape.frame.size.y)
    love.graphics.setColor(255, 255, 0, 255)
    love.graphics.rectangle("fill", yellowShape.frame.origin.x, yellowShape.frame.origin.y, yellowShape.frame.size.x, yellowShape.frame.size.y)
    love.graphics.setColor(60, 255, 60, 240)
    love.graphics.print("Welcome to Flag maker 2.0", 10, 10, 0, 1, 1)
    
    love.graphics.rectangle("fill", convertedTouchLocation.x - 4, convertedTouchLocation.y, 3, 1)
    love.graphics.rectangle("fill", convertedTouchLocation.x + 2, convertedTouchLocation.y, 3, 1)
    love.graphics.rectangle("fill", convertedTouchLocation.x, convertedTouchLocation.y - 4, 1, 3)
    love.graphics.rectangle("fill", convertedTouchLocation.x, convertedTouchLocation.y + 2, 1, 3)
    
    love.graphics.setCanvas()
    
    sceneCamera:attach()
    love.graphics.setShader(mainShader)
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.draw(mainCanvas)
    
    --draw mouse
    love.graphics.setColor(60, 255, 60, 200)
    
    love.graphics.setShader()
    sceneCamera:detach()
end

function love.keypressed(key, isrepeat)
    if key == "return" then
        if love.keyboard.isDown("lalt") then
            success = love.window.setFullscreen(not love.window.getFullscreen())
        end
    elseif key == 'escape' then
      love.event.quit()
   end
end

function love.mousepressed(x, y, button)
    local convertedTouchLocation = (Vector2(x, y) * screenScale) - Vector2(((love.window.getWidth() * screenScale) - designResolution.x) / 2, 0)
    if button == "l" then
        local zoneHit = nil
        for _, zone in ipairs(rootTouchZones) do
            zoneHit = zone:touchInside(convertedTouchLocation)
            if zoneHit then break end
        end
        if zoneHit then
            zoneHit:onTouchDown(convertedTouchLocation)
            table.insert(propagateLeftMouseEvent, zoneHit)
        end
    end
end

function love.mousereleased(x, y, button)
    local convertedTouchLocation = (Vector2(x, y) * screenScale) - Vector2(((love.window.getWidth() * screenScale) - designResolution.x) / 2, 0)
    if button == "l" then
        for _, zone in ipairs(propagateLeftMouseEvent) do
            zone:onTouchUp(convertedTouchLocation)
            --table.remove(propagateLeftMouseEvent)
        end
        
        propagateLeftMouseEvent = {}
    end
end