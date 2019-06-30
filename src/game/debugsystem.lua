local lovetoys = require "lib.lovetoys.lovetoys"

local state = require "src.game.state"

local DebugSystem = lovetoys.System:subclass("DebugSystem")

function DebugSystem.requires()
	return {"SpriteComponent"}
end

function DebugSystem:initialize(map)
	lovetoys.System.initialize(self)
	self.map = map
end

function DebugSystem:draw()
	love.graphics.setLineWidth(1)
	love.graphics.setPointSize(8)

	for _,entity in pairs(self.targets) do
		if entity == state:getSelection() then
			love.graphics.setColor(0.25, 0, 0.75)
		else
			love.graphics.setColor(0.75, 0, 0.75)
		end
		if entity:has("InteractiveComponent") then
			local interactive = entity:get("InteractiveComponent")
			love.graphics.rectangle("line",
					interactive.x, interactive.y,
					interactive.w, interactive.h)

			self.font2 = self.font2 or love.graphics.newFont(13)
			love.graphics.setFont(self.font2)
			love.graphics.setColor(0, 0, 0, 1)
			local index = entity:get("SpriteComponent"):getDrawIndex()
			if not index then
				print("Index for entity missing!")
				print(entity)
				for _,component in pairs(entity:getComponents()) do
					print("", component.class.name)
				end
				index = "nil"
			end
			love.graphics.print(index, interactive.x, interactive.y)
			self.font = self.font or love.graphics.newFont(12)
			love.graphics.setFont(self.font)
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.print(index, interactive.x, interactive.y)
		end
		if entity:has("PositionComponent") then
			local fromGrid = entity:get("PositionComponent"):getFromGrid()
			local toGrid = entity:get("PositionComponent"):getToGrid()
			love.graphics.points(self.map:gridToWorldCoords(fromGrid.gi + 0.5, fromGrid.gj + 0.5))
			if fromGrid ~= toGrid then
				love.graphics.points(self.map:gridToWorldCoords(toGrid.gi + 0.5, toGrid.gj + 0.5))
			end
		end
		if entity:has("VillagerComponent") then
			if entity:has("WalkingComponent") then
				local path = entity:get("WalkingComponent"):getPath()
				-- Backwards:
				local prevx, prevy
				for _,grid in ipairs(path or {}) do
					if prevx and prevy then
						love.graphics.line(prevx, prevy, self.map:gridToWorldCoords(grid.gi + 0.5, grid.gj + 0.5))
					end
					prevx, prevy = self.map:gridToWorldCoords(grid.gi + 0.5, grid.gj + 0.5)
				end
				if prevx and prevy then
					local grid = entity:get("PositionComponent"):getGrid()
					love.graphics.line(prevx, prevy, self.map:gridToWorldCoords(grid.gi + 0.5, grid.gj + 0.5))
					grid = path[1]
					love.graphics.points(self.map:gridToWorldCoords(grid.gi + 0.5, grid.gj + 0.5))
				end
			end

			--[[ Dot the direction
			local vector = require "lib.hump.vector"
			local v = vector(0,-3):rotateInplace(math.rad(entity:get("VillagerComponent"):getDirection()))
			local gx, gy = entity:get("GroundComponent"):getPosition()
			v = v + vector((gx - gy) / 2, (gx + gy) / 4)
			love.graphics.points(v.x, v.y)
			--]]
		end
	end

	love.graphics.setColor(1, 1, 1)
end

return DebugSystem
