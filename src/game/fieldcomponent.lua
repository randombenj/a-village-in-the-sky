local class = require "lib.middleclass"

local FieldComponent = class("FieldComponent")

FieldComponent.static.UNCULTIVATED = 0
FieldComponent.static.PLOWED = 1
FieldComponent.static.SEEDED = 2
FieldComponent.static.GROWING = 3
FieldComponent.static.HARVESTING = 4
FieldComponent.static.IN_PROGRESS = 5

FieldComponent.static.STATE_NAMES = {
	[FieldComponent.UNCULTIVATED] = "uncultivated",
	[FieldComponent.PLOWED] = "plowed",
	[FieldComponent.SEEDED] = "seeded",
	[FieldComponent.GROWING] = "growing",
	[FieldComponent.HARVESTING] = "harvesting"
}

function FieldComponent:initialize(enclosure)
	self:setState(FieldComponent.UNCULTIVATED)
	self:setEnclosure(enclosure)
end

function FieldComponent:getState()
	return self.state
end

function FieldComponent:setState(state)
	self.state = state
end

function FieldComponent:getEnclosure()
	return self.enclosure
end

function FieldComponent:setEnclosure(enclosure)
	self.enclosure = enclosure
end

return FieldComponent