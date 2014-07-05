Camera = require "hump.camera"
Vector2 = require "hump.vector"
Rectangle = require "rectangle"
TouchZone = require "touchZone"

local designResolution = {x = 800, y = 600}
local backgroundSize = {0, 0, designResolution.x, designResolution.y}--{-designResolution.x, 0, designResolution.x * 3, designResolution.y}
local mainShader = nil
local shaderElapsedTime = 0

local previousMousePosition = Vector2(love.mouse.getPosition())
local screenScale = 1

local propagateLeftMouseEvent = {}
local rootTouchZones = {}
local redShape = TouchZone(100, 100, 300, 300)
local yellowShape = TouchZone(200, 200, 80, 80)
table.insert(rootTouchZones, yellowShape)
table.insert(rootTouchZones, redShape)

local mainCanvas = love.graphics.newCanvas(designResolution.x, designResolution.y)
mainCanvas:setFilter("nearest")

local computerFont = love.graphics.newFont("assets/data-latin.ttf", 40)

function love.load()
    love.window.setMode(designResolution.x, designResolution.y, {resizable = true})
    love.window.setTitle("Flag maker terminal")
    
    sceneCamera = Camera()
    sceneCamera:zoomTo(love.window.getHeight() / designResolution.y)
    sceneCamera:lookAt(designResolution.x / 2, designResolution.y / 2)
    
    mainShader = love.graphics.newShader("shaderTest.fs")
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
            shape.frame.origin = shape.frame.origin + (delta * screenScale)
        end
    end
end

function love.draw()
    love.graphics.setCanvas(mainCanvas)
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.rectangle("fill", unpack(backgroundSize))
    love.graphics.setColor(255, 0, 0, 255)
    love.graphics.rectangle("fill", redShape.frame.origin.x, redShape.frame.origin.y, redShape.frame.size.x, redShape.frame.size.y)
    love.graphics.setColor(255, 255, 0, 255)
    love.graphics.rectangle("fill", yellowShape.frame.origin.x, yellowShape.frame.origin.y, yellowShape.frame.size.x, yellowShape.frame.size.y)
    love.graphics.setColor(0, 0, 0, 150)
    love.graphics.print("Welcome to Flag maker 2.0", 10, 10, 0, 1, 1)
    love.graphics.setCanvas()
    
    sceneCamera:attach()
    love.graphics.setShader(mainShader)
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.draw(mainCanvas)
    love.graphics.setShader()
    sceneCamera:detach()
end

function love.mousepressed(x, y, button)
    if button == "l" then
        local zoneHit = nil
        for _, zone in ipairs(rootTouchZones) do
            zoneHit = zone:touchInside((Vector2(x, y) * screenScale) - Vector2(((love.window.getWidth() * screenScale) - designResolution.x) / 2, 0))
            if zoneHit then break end
        end
        if zoneHit then
            table.insert(propagateLeftMouseEvent, zoneHit)
        end
    end
end

function love.mousereleased(x, y, button)
    if button == "l" then
        table.remove(propagateLeftMouseEvent)
    end
end