--[[
Copyright (C) 2019  Albert Diserholt (@Drauthius)

This file is part of A Village in the Sky.

A Village in the Sky is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

A Village in the Sky is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with A Village in the Sky. If not, see <http://www.gnu.org/licenses/>.
--]]

local lovetoys = require "lib.lovetoys.lovetoys"

local Level = require "src.game.level"

local AssignmentComponent = require "src.game.assignmentcomponent"
local BuildingComponent = require "src.game.buildingcomponent"
local ConstructionComponent = require "src.game.constructioncomponent"
local GroundComponent = require "src.game.groundcomponent"
local InteractiveComponent = require "src.game.interactivecomponent"
local PositionComponent = require "src.game.positioncomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local SpriteComponent = require "src.game.spritecomponent"
local TileComponent = require "src.game.tilecomponent"

local HallwayLevel = Level:subclass("HallwayLevel")

local blueprint = require "src.game.blueprint"
local spriteSheet = require "src.game.spritesheet"

HallwayLevel.static.NUM_VILLAGERS = 10
HallwayLevel.static.SIZE = 2

function HallwayLevel:initial()
	local tile = lovetoys.Entity()
	tile:add(TileComponent(TileComponent.GRASS, 0, 0))
	tile:add(SpriteComponent(spriteSheet:getSprite("grass-tile"), -self.map.halfTileWidth))
	self.engine:addEntity(tile)
	self.map:addTile(TileComponent.GRASS, 0, 0)

	local villagers = HallwayLevel.NUM_VILLAGERS
	for gi=0,self.map.gridsPerTile - 1 do
		for gj=0,self.map.gridsPerTile - 1 do
			if math.floor(self.map.gridsPerTile/2) >= gi and math.floor(self.map.gridsPerTile/2) < gi + HallwayLevel.SIZE then
				if gj % 2 == 1 and villagers > 0 then
					local villager = blueprint:createVillager(nil, nil, "male", 20)

					villager:add(PositionComponent(self.map:getGrid(gi, gj), nil, 0, 0))
					villager:add(GroundComponent(self.map:gridToGroundCoords(gi + 0.5, gj + 0.5)))

					self.engine:addEntity(villager)
					villagers = villagers - 1
				end
			else
				local type = math.floor(self.map.gridsPerTile / 2) > gi and ResourceComponent.WOOD or ResourceComponent.TOOL
				local resource = blueprint:createResourcePile(type, 3)

				self.map:addResource(resource, self.map:getGrid(gi, gj))
				resource:add(PositionComponent(self.map:getGrid(gi, gj), nil, 0, 0))
				self.engine:addEntity(resource)
			end
		end
	end

	tile = lovetoys.Entity()
	tile:add(TileComponent(TileComponent.GRASS, 0, -1))
	tile:add(SpriteComponent(spriteSheet:getSprite("grass-tile"), 0, -self.map.halfTileHeight))
	self.engine:addEntity(tile)
	self.map:addTile(TileComponent.GRASS, 0, -1)

	local dwelling = blueprint:createPlacingBuilding(BuildingComponent.DWELLING)
	local ax, ay, minGrid, maxGrid = self.map:addObject(dwelling, 0, -1)
	dwelling:get("SpriteComponent"):setDrawPosition(ax, ay)
	dwelling:add(PositionComponent(minGrid, maxGrid, 0, -1))
	dwelling:add(ConstructionComponent(BuildingComponent.DWELLING))
	dwelling:add(AssignmentComponent(4))
	InteractiveComponent:makeInteractive(dwelling, ax, ay)
	dwelling:remove("PlacingComponent")
	self.engine:addEntity(dwelling)
end

return HallwayLevel
