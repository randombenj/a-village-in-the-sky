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

local class = require "lib.middleclass"

local ResourceComponent = require "src.game.resourcecomponent"

local State = class("State")

local numEventCache

function State:initialize()
	self.mouseCoords = {
		x = 0,
		y = 0
	}
	self.viewport = {
		sx = 0,
		sy = 0,
		ex = 0,
		ey = 0
	}
	self.year = 0.0
	self.yearModifier = 1.0
	self.timeStopped = false
	self.placing = nil
	self.selected = nil
	self.headers = {
		buildings = false,
		villagers = false
	}
	self.available = {
		terrain = nil,
		buildings = nil
	}
	self.events = {}
	numEventCache = nil
	self.lastPopulationEvent = 0
	self.lastEventSeen = 0
	self.resources = {
		[ResourceComponent.WOOD] = 0,
		[ResourceComponent.IRON] = 0,
		[ResourceComponent.TOOL] = 0,
		[ResourceComponent.GRAIN] = 0,
		[ResourceComponent.BREAD] = 0
	}
	self.reservedResources = {
		[ResourceComponent.WOOD] = 0,
		[ResourceComponent.IRON] = 0,
		[ResourceComponent.TOOL] = 0,
		[ResourceComponent.GRAIN] = 0,
		[ResourceComponent.BREAD] = 0
	}
	self.villagers = {
		maleVillagers = 0,
		femaleVillagers = 0,
		maleChildren = 0,
		femaleChildren = 0
	}
end

--
-- Positions in world coordinates.
--

function State:getMousePosition()
	return self.mouseCoords.x, self.mouseCoords.y
end

function State:setMousePosition(x, y)
	self.mouseCoords.x, self.mouseCoords.y = x, y
end

function State:getViewport()
	return self.viewport.sx, self.viewport.sy, self.viewport.ex, self.viewport.ey
end

function State:setViewport(sx, sy, ex, ey)
	self.viewport.sx, self.viewport.sy, self.viewport.ex, self.viewport.ey = sx, sy, ex, ey
end

--
-- Year count
--
function State:getYear()
	return self.year
end

function State:increaseYear(dt)
	self.year = self.year + dt
end

function State:getYearModifier()
	return self.yearModifier
end

function State:setYearModifier(mod)
	self.yearModifier = mod
end

function State:isTimeStopped()
	return self.timeStopped
end

function State:setTimeStopped(stopped)
	self.timeStopped = stopped
end

--
-- Placing
--
function State:isPlacing()
	return self.placing ~= nil
end

function State:getPlacing()
	return self.placing
end

function State:setPlacing(placeable)
	self.placing = placeable
end

function State:clearPlacing()
	self.placing = nil
end

--
-- Selecting
--
function State:hasSelection()
	return self.selected ~= nil
end

function State:getSelection()
	return self.selected
end

function State:setSelection(selected)
	self.selected = selected
end

function State:clearSelection()
	self.selected = nil
end

--
-- Headers
-- (Misplaced?)
--

function State:getShowBuildingHeaders()
	return self.headers.buildings
end

function State:showBuildingHeaders(show)
	self.headers.buildings = show
end

function State:getShowVillagerHeaders()
	return self.headers.villagers
end

function State:showVillagerHeaders(show)
	self.headers.villagers = show
end

--
-- Availabilities
-- (Misplaced?)
--

function State:getAvailableTerrain()
	return self.available.terrain
end

function State:setAvailableTerrain(available)
	self.available.terrain = available
end

function State:getAvailableBuildings()
	return self.available.buildings
end

function State:setAvailableBuildings(available)
	self.available.buildings = available
end

--
-- Events
--

function State:getEvents()
	return self.events
end

function State:getNumEvents()
	numEventCache = numEventCache or #self.events
	return numEventCache
end

function State:addEvent(event)
	table.insert(self.events, event)
	numEventCache = (numEventCache or 0) + 1
end

function State:getLastEventSeen()
	return self.lastEventSeen
end

function State:setLastEventSeen(eventNum)
	self.lastEventSeen = eventNum
end

function State:getLastPopulationEvent()
	return self.lastPopulationEvent
end

function State:setLastPopulationEvent(popNum)
	self.lastPopulationEvent = popNum
end

--
-- Resources
--
function State:getNumResources(resource)
	return assert(self.resources[resource], "Resource " .. tostring(resource) .. " doesn't exist.")
end

function State:getNumReservedResources(resource)
	return assert(self.reservedResources[resource], "Resource " .. tostring(resource) .. " doesn't exist.")
end

function State:getNumAvailableResources(resource)
	return math.max(0, self:getNumResources(resource) - self:getNumReservedResources(resource))
end

function State:reserveResource(resource, amount)
	self.reservedResources[resource] = self.reservedResources[resource] + (amount or 1)
end

function State:removeReservedResource(resource, amount)
	self.reservedResources[resource] = self.reservedResources[resource] - (amount or 1)
	assert(self.reservedResources[resource] >= 0)
end

function State:increaseResource(resource, amount)
	self.resources[resource] = self.resources[resource] + (amount or 1)
end

function State:decreaseResource(resource, amount)
	self.resources[resource] = self.resources[resource] - (amount or 1)
	assert(self.resources[resource] >= 0)
end

function State:getNumWood()
	return self:getNumResources(ResourceComponent.WOOD)
end

function State:increaseNumWood(amount)
	self:increaseResource(ResourceComponent.WOOD, amount)
end

function State:getNumIron()
	return self:getNumResources(ResourceComponent.IRON)
end

function State:increaseNumIron(amount)
	self:increaseResource(ResourceComponent.IRON, amount)
end

function State:getNumTool()
	return self:getNumResources(ResourceComponent.IRON)
end

function State:increaseNumTool(amount)
	self:increaseResource(ResourceComponent.TOOL, amount)
end

function State:getNumGrain()
	return self:getNumResources(ResourceComponent.GRAIN)
end

function State:increaseNumGrain(amount)
	self:increaseResource(ResourceComponent.GRAIN, amount)
end

function State:getNumBread()
	return self:getNumResources(ResourceComponent.BREAD)
end

function State:increaseNumBread(amount)
	self:increaseResource(ResourceComponent.BREAD, amount)
end

--
-- Villagers
--
function State:increaseNumVillagers(gender, isAdult)
	local key = gender .. (isAdult and "Villagers" or "Children")
	self.villagers[key] = self.villagers[key] + 1
end

function State:decreaseNumVillagers(gender, isAdult)
	local key = gender .. (isAdult and "Villagers" or "Children")
	self.villagers[key] = self.villagers[key] - 1
end

function State:getNumMaleVillagers()
	return self.villagers.maleVillagers
end

function State:getNumFemaleVillagers()
	return self.villagers.femaleVillagers
end

function State:getNumMaleChildren()
	return self.villagers.maleChildren
end

function State:getNumFemaleChildren()
	return self.villagers.femaleChildren
end

return State()
