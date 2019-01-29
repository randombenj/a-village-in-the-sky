local class = require "lib.middleclass"

local BuildingComponent = class("BuildingComponent")

BuildingComponent.static.DWELLING = 0
BuildingComponent.static.BLACKSMITH = 1
BuildingComponent.static.FIELD = 2
BuildingComponent.static.BAKERY = 3

BuildingComponent.static.BUILDING_NAME = {
	[BuildingComponent.static.DWELLING] = "dwelling",
	[BuildingComponent.static.BLACKSMITH] = "blacksmith",
	[BuildingComponent.static.FIELD] = "field",
	[BuildingComponent.static.BAKERY] = "bakery"
}

function BuildingComponent:initialize(type, ti, tj)
	self:setType(type)
	self:setPosition(ti, tj)
end

function BuildingComponent:setType(type)
	self.type = type
end

function BuildingComponent:getType()
	return self.type
end

function BuildingComponent:getPosition()
	return self.ti, self.tj
end

function BuildingComponent:setPosition(ti, tj)
	self.ti, self.tj = ti, tj
end

return BuildingComponent
