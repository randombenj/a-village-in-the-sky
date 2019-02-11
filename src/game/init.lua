-- Directive:
--  - Get the game play in, taking time to fix other things around when the need or fancy arises.
-- TODO:
--  - Bugs:
--    * Villagers always reserve two grids when walking. Problem?
--    * Villagers can get stuck in a four-grid gridlock.
--    * Villagers can be assigned a workplace, but don't make their way there.
--  - Next:
--    * Open/close door when going in/out.
--    * Allow changing profession.
--      Changing workplace mid-work makes it look really wacky (will start building the other building)
--  - Refactoring:
--    * There is little reason to have the VillagerComponent be called "VillagerComponent", other than symmetry.
--    * Map:reserve() is a bad name for something that doesn't use COLL_RESERVED
--      We could rename COLL_RESERVED to COLL_SPECIAL, and COLL_DYNAMIC to COLL_RESERVED,
--      but it needs to make sense if a spot to drop a resource is reserved, and the villager
--      assumes that there is a villager in the way and tries to tell it to move or something.
--      Maybe it would need to check "how" it is reserved, or we simply split it up further...
--      reserve() for resources, occupy() for villagers?
--    * Either consolidate work/production/construction components (wrt assigning), or maybe add an "assign" component?
--    * Either consolidate production/construction components (wrt input), or maybe add an "input" component?
--    * Either consolidate dwelling/production component (wrt entrance), or maybe add an "entrance" component?
--  - Draw order:
--    * Update sprites to be square.
--  - Particles:
--    * "Button is next" for the tutorial.
--    * When villager hits tree/stone/building
--  - More sprites:
--    * Event button has a new event (maybe just want to add a text number?).
--    * Clouds
--    * Woman animations
--    * Investigate and fix (or work around) aseprite sprite sheet bug
--  - Controls
--    * Zoom (less smooth, to avoid uneven pixels)
--    * Drag (with min/max, to avoid getting lost in space)
--    * Assigning/selecting through double tap or hold?
--      The details panel must have a "Deselect/Cancel/Close" button/icon so
--      that villagers can be easily deselected.
--  - Placing:
--    * Indicators of valid positions (blue)
--    * Draw tiles behind other tiles? (Not really a requirement though)
--    * Effects ((small drop) + dust clouds + (screen shake))
--    * Limit placement depending on runestones
--    * Placing runestones
--    * Placing buildings
--  - Optimization:
--    * Quads are being (re)created each frame.
--  - Info panel updates:
--    * Make the info panel title bar thicker, and put the name there + a button to
--      minimize/maximize.
--  - Details panel:
--    * Fill up details panel with correct information
--      Villager stuff, Monolith, wait with other things.
--  - Localization:
--    * Refrain from using hardcoded strings, and consult a library instead.
--      https://github.com/martin-damien/babel
--  - Nice to have:
--    * Don't increase opacity for overlapping shadows.

local Camera = require "lib.hump.camera"
local Timer = require "lib.hump.timer"
local lovetoys = require "lib.lovetoys.lovetoys"

local GUI = require "src.game.gui"
local Map = require "src.game.map"
local DefaultLevel = require "src.game.level.default"
-- Components
local BlinkComponent = require "src.game.blinkcomponent"
local ConstructionComponent = require "src.game.constructioncomponent"
local InteractiveComponent = require "src.game.interactivecomponent"
local PositionComponent = require "src.game.positioncomponent"
local WorkComponent = require "src.game.workcomponent"
-- Systems
local DebugSystem
local PlacingSystem
local PositionSystem
local RenderSystem
local SpriteSystem
local TimerSystem
local VillagerSystem
local WalkingSystem
local WorkSystem

local blueprint = require "src.game.blueprint"
local screen = require "src.screen"
local soundManager = require "src.soundmanager"
local state = require "src.game.state"

local Game = {}

Game.CAMERA_EPSILON = 0.025

function Game:init()
	lovetoys.initialize({ debug = true, middleclassPath = "lib.middleclass" })

	-- Needs to be created after initialization.
	DebugSystem = require "src.game.debugsystem"
	PlacingSystem = require "src.game.placingsystem"
	PositionSystem = require "src.game.positionsystem"
	RenderSystem = require "src.game.rendersystem"
	SpriteSystem = require "src.game.spritesystem"
	TimerSystem = require "src.game.timersystem"
	VillagerSystem = require "src.game.villagersystem"
	WalkingSystem = require "src.game.walkingsystem"
	WorkSystem = require "src.game.worksystem"
end

function Game:enter()
	love.graphics.setBackgroundColor(0.1, 0.5, 1)

	self.speed = 1

	self.map = Map()
	self.level = DefaultLevel()

	-- Set up the camera.
	self.camera = Camera()
	self.camera:lookAt(0, 0)
	self.camera:zoom(3)

	self.engine = lovetoys.Engine()
	self.eventManager = lovetoys.EventManager()

	local villagerSystem = VillagerSystem(self.engine, self.map)
	local workSystem = WorkSystem(self.engine, self.map)

	self.engine:addSystem(PlacingSystem(self.map), "update")
	self.engine:addSystem(workSystem, "update") -- Must be before the sprite system
	self.engine:addSystem(villagerSystem, "update")
	self.engine:addSystem(WalkingSystem(self.engine, self.eventManager, self.map), "update")
	self.engine:addSystem(SpriteSystem(self.eventManager), "update")
	self.engine:addSystem(TimerSystem(), "update")
	self.engine:addSystem(RenderSystem(), "draw")
	self.engine:addSystem(DebugSystem(self.map), "draw")

	-- Not enabled by default.
	self.engine:toggleSystem("DebugSystem")

	-- Currently only listens to events.
	self.engine:addSystem(PositionSystem(self.map), "update")
	self.engine:stopSystem("PositionSystem")

	self.eventManager:addListener("TargetReachedEvent", villagerSystem, villagerSystem.targetReachedEvent)
	self.eventManager:addListener("TargetUnreachableEvent", villagerSystem, villagerSystem.targetUnreachableEvent)
	self.eventManager:addListener("WorkEvent", workSystem, workSystem.workEvent)

	self.gui = GUI(self.engine)

	self.level:initiate(self.engine, self.map)
end

function Game:update(dt)
	local mx, my = screen:getCoordinate(love.mouse.getPosition())
	local drawArea = screen:getDrawArea()
	state:setMousePosition(self.camera:worldCoords(mx, my, drawArea.x, drawArea.y, drawArea.width, drawArea.height))

	if self.dragging and self.dragging.dragged then
		self.camera:lockPosition(
				self.dragging.cx,
				self.dragging.cy,
				Camera.smooth.damped(15))
		if self.dragging.released and
		   math.abs(self.dragging.cx - self.camera.x) <= Game.CAMERA_EPSILON and
		   math.abs(self.dragging.cy - self.camera.y) <= Game.CAMERA_EPSILON then
			-- Clear and release the dragging table, to avoid subpixel camera movement which looks choppy.
			self.dragging = nil
		end
	end

	for _=1,self.speed do
		Timer.update(dt)
		self.gui:update(dt)
		self.engine:update(dt)
	end
end

function Game:draw()
	local drawArea = screen:getDrawArea()
	self.camera:draw(drawArea.x, drawArea.y, drawArea.width, drawArea.height, function()
		self.engine:draw()

		if self.debug then
			self.map:drawDebug()

			love.graphics.setPointSize(4)
			love.graphics.setColor(1, 0, 0, 1)
			love.graphics.points(0, 0)
			love.graphics.setColor(1, 1, 1, 1)
		end
	end)

	self.gui:draw()
end

--
-- Input handling
--

function Game:keyreleased(key, scancode)
	if scancode == "d" then
		self.engine:toggleSystem("DebugSystem")
	elseif scancode == "g" then
		self.debug = not self.debug
	elseif scancode == "escape" then
		self.gui:back()
	elseif scancode == "`" then
		self.speed = 0
	elseif scancode == "1" then
		self.speed = 1
	elseif scancode == "2" then
		self.speed = 2
	elseif scancode == "3" then
		self.speed = 5
	elseif scancode == "4" then
		self.speed = 10
	end
end

function Game:mousepressed(x, y)
	local origx, origy = self.camera:position()
	local sx, sy = screen:getCoordinate(x, y)

	-- Don't allow dragging the camera when it starts on a GUI element.
	if self.gui:handlePress(sx, sy, true) then
		return
	end

	self.dragging = {
		-- Original camera coordinates where mouse was pressed (don't change).
		ox = origx, oy = origy,
		-- Original coordinates in screen space.
		sx = sx, sy = sy,
		-- Current camera coordinates.
		cx = origx, cy = origy,
		-- Whether dragging or simply pressing.
		dragged = false,
		-- Whether the mouse has been released.
		released = false
	}
end

function Game:mousemoved(x, y)
	if self.dragging and not self.dragging.released then
		local ex, ey = screen:getCoordinate(x, y)
		local newx, newy = self.dragging.sx - ex, self.dragging.sy - ey
		newx, newy = newx / self.camera.scale, newy / self.camera.scale

		local tolerance = 20
		if not self.dragging.dragged and
		   (self.dragging.sx - ex)^2 + (self.dragging.sy - ey)^2 >= tolerance then
			self.dragging.dragged = true
		end

		self.dragging.cx = self.dragging.ox + newx
		self.dragging.cy = self.dragging.oy + newy
	end
end

function Game:mousereleased(x, y)
	x, y = screen:getCoordinate(x, y)

	if not self.dragging or not self.dragging.dragged or self.dragging.released then
		if not self.gui:handlePress(x, y) then
			if state:isPlacing() then
				local placing = state:getPlacing()
				if placing:has("TileComponent") then
					self:_placeTile(placing)
				elseif placing:has("BuildingComponent") then
					self:_placeBuilding(placing)
				end
			else
				self:_handleClick(state:getMousePosition())
			end
		end
	end

	if self.dragging then
		self.dragging.released = true
	end
end

function Game:wheelmoved(_, y)
	if y < 0 then
		if self.camera.scale >= 0.2 then
			self.camera:zoom(0.9)
		end
	elseif y > 0 then
		if self.camera.scale <= 10.0 then
			self.camera:zoom(1.1)
		end
	end
end

--
-- Internal functions
--

function Game:_handleClick(x, y)
	local clicked, clickedIndex = nil, 0
	for _,entity in pairs(self.engine:getEntitiesWithComponent("InteractiveComponent")) do
		local index = entity:get("SpriteComponent"):getDrawIndex()
		if index > clickedIndex and entity:get("InteractiveComponent"):isWithin(x, y) then
			clicked = entity
			clickedIndex = index
		end
	end

	if not clicked then
		soundManager:playEffect("clearSelection")
		state:clearSelection()
		return
	end

	local selected = state:getSelection()
	if selected and selected:has("VillagerComponent") and selected:has("AdultComponent") and
	   (clicked:has("WorkComponent") or
	    clicked:has("ConstructionComponent") or
	    clicked:has("DwellingComponent") or
		clicked:has("ProductionComponent")) then
		-- TODO: Should probably be an event or similar.

		-- Whether that there is room to work there.
		-- FIXME: Reassignment not handled!
		local valid

		-- TODO: lol... fix logic.
		if clicked:has("ConstructionComponent") then
			if #clicked:get("ConstructionComponent"):getAssignedVillagers() >= 4 then
				valid = false
			else
				local alreadyAdded = false
				for _,villager in ipairs(clicked:get("ConstructionComponent"):getAssignedVillagers()) do
					if villager == selected then
						alreadyAdded = true
						break
					end
				end
				if not alreadyAdded then
					-- For things being built, update the places where builders can stand, so that rubbish can
					-- be cleared around the build site after placing the building.
					local adjacent = self.map:getAdjacentGrids(clicked)
					clicked:get("ConstructionComponent"):updateWorkGrids(adjacent)
				end
				valid = true
				selected:get("AdultComponent"):setOccupation(WorkComponent.BUILDER)
			end
		elseif clicked:has("WorkComponent") then
			if #clicked:get("WorkComponent"):getAssignedVillagers() >= 1 or
			   not selected:get("VillagerComponent"):getHome() then
				valid = false
			else
				local alreadyAdded = false
				for _,villager in ipairs(clicked:get("WorkComponent"):getAssignedVillagers()) do
					if villager == selected then
						alreadyAdded = true
						break
					end
				end
				if not alreadyAdded then
					clicked:get("WorkComponent"):assign(selected)
				end
				valid = true
				selected:get("AdultComponent"):setOccupation(clicked:get("WorkComponent"):getType())
			end
		elseif clicked:has("DwellingComponent") then
			if #clicked:get("DwellingComponent"):getAssignedVillagers() >= 2 then
				valid = false
			else
				local alreadyAdded = false
				for _,villager in ipairs(clicked:get("DwellingComponent"):getAssignedVillagers()) do
					if villager == selected then
						alreadyAdded = true
						break
					end
				end
				if not alreadyAdded then
					clicked:get("DwellingComponent"):assign(selected)
				end
				valid = true
			end
		elseif clicked:has("ProductionComponent") then
			local prod = clicked:get("ProductionComponent")
			if #prod:getAssignedVillagers() >= prod:getMaxWorkers() then
				valid = false
			else
				local alreadyAdded = false
				for _,villager in ipairs(prod:getAssignedVillagers()) do
					if villager == selected then
						alreadyAdded = true
						break
					end
				end
				if not alreadyAdded then
					prod:assign(selected)
				end
				valid = true
				selected:get("AdultComponent"):setOccupation(WorkComponent.BLACKSMITH) -- TODO!
			end
		end

		if valid then
			if clicked:has("DwellingComponent") then
				selected:get("VillagerComponent"):setHome(clicked)
			else
				selected:get("AdultComponent"):setWorkArea(clicked:get("PositionComponent"):getTile())
				selected:get("AdultComponent"):setWorkPlace(clicked)
			end
			soundManager:playEffect("successfulAssignment") -- TODO: Different sounds per assigned occupation?
			BlinkComponent:makeBlinking(clicked, { 0.15, 0.70, 0.15, 1.0 }) -- TODO: Colour value
		else
			soundManager:playEffect("failedAssignment")
			BlinkComponent:makeBlinking(clicked, { 0.70, 0.15, 0.15, 1.0 }) -- TODO: Colour value
		end
	else
		soundManager:playEffect("selecting") -- TODO: Different sounds depending on what is selected.
		state:setSelection(clicked)
	end
end

function Game:_placeTile(placing)
	soundManager:playEffect("tilePlaced") -- TODO: Type?

	placing:remove("PlacingComponent")
	local ti, tj = placing:get("TileComponent"):getPosition()
	self.map:addTile(ti, tj)

	local trees, iron = self.level:getResources(placing:get("TileComponent"):getType())

	--print("Will spawn "..tostring(trees).." trees and "..tostring(iron).." iron")

	local sgi, sgj = ti * self.map.gridsPerTile, tj * self.map.gridsPerTile
	local egi, egj = sgi + self.map.gridsPerTile, sgj + self.map.gridsPerTile

	local resources = {}

	if self.level:shouldPlaceRunestone() then
		local runestone = blueprint:createRunestone()
		local ax, ay, grid = self.map:addObject(runestone, ti, tj)
		assert(ax and ay and grid, "Could not add runestone to empty tile.")
		runestone:get("SpriteComponent"):setDrawPosition(ax, ay)
		runestone:get("PositionComponent"):setGrid(grid)
		runestone:get("PositionComponent"):setTile(ti, tj)
		InteractiveComponent:makeInteractive(runestone, ax, ay)
		self.engine:addEntity(runestone)
		table.insert(resources, runestone)
	end

	-- Resources
	for i=1,trees+iron do
		local resource
		if i <= trees then
			resource = blueprint:createTree()
		else
			resource = blueprint:createIron()
		end
		for _=1,1000 do -- lol
			local gi, gj = love.math.random(sgi + 1, egi - 1), love.math.random(sgj + 1, egj - 1)
			local ax, ay, grid = self.map:addObject(resource, gi, gj)
			if ax then
				resource:get("SpriteComponent"):setDrawPosition(ax, ay)
				resource:get("PositionComponent"):setGrid(grid)
				resource:get("PositionComponent"):setTile(ti, tj)
				InteractiveComponent:makeInteractive(resource, ax, ay)
				self.engine:addEntity(resource)
				table.insert(resources, resource)
				resource = nil
				break
			end
		end

		if resource then
			print("Could not add object.")
		end
	end

	-- DROP
	for _,resource in ipairs(resources) do
		local sprite = resource:get("SpriteComponent")
		local dest = sprite.y
		sprite.y = sprite.y - 10
		Timer.tween(0.15, sprite, { y = dest }, "in-bounce")
	end

	local sprite = placing:get("SpriteComponent")
	sprite:resetColor()
	local dest = sprite.y
	sprite.y = sprite.y - 10

	Timer.tween(0.15, sprite, { y = dest }, "in-bounce", function()
		-- Screen shake
		local orig_x, orig_y = self.camera:position()
		Timer.during(0.10, function()
			self.camera:lookAt(orig_x + math.random(-2,2), orig_y + math.random(-4,4))
		end, function()
			-- reset camera position
			self.camera:lookAt(orig_x, orig_y)
		end)
	end)

	-- Notify GUI to update its state.
	self.gui:placed()
end

function Game:_placeBuilding(placing)
	soundManager:playEffect("buildingPlaced") -- TODO: Type?

	local ax, ay, grid = self.map:addObject(placing, placing:get("BuildingComponent"):getPosition())
	assert(ax and ay and grid, "Could not add building with building component.")
	placing:get("SpriteComponent"):setDrawPosition(ax, ay)
	placing:get("SpriteComponent"):resetColor()
	placing:set(PositionComponent(grid, self.map:gridToTileCoords(grid.gi, grid.gj)))
	placing:add(ConstructionComponent(placing:get("PlacingComponent"):getType()))
	InteractiveComponent:makeInteractive(placing, ax, ay)

	placing:remove("PlacingComponent")

	-- DROP
	local sprite = placing:get("SpriteComponent")
	sprite:resetColor()
	local dest = sprite.y
	sprite.y = sprite.y - 4
	Timer.tween(0.11, sprite, { y = dest }, "in-back")

	-- Notify GUI to update its state.
	self.gui:placed()
end

return Game
