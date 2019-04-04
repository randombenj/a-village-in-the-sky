local class = require "lib.middleclass"

local ColorSwapComponent = class("ColorSwapComponent")

function ColorSwapComponent:initialize()
	self.groups = {}
	self.oldColors = {}
	self.newColors = {}
end

function ColorSwapComponent:add(group, oldColors, newColors)
	assert(#oldColors == #newColors)
	assert(not self.groups[group], "Overwriting color group: "..tostring(group))

	self.groups[group] = { #self.oldColors, #oldColors }

	for i=1,#oldColors do
		table.insert(self.oldColors, oldColors[i])
		table.insert(self.newColors, newColors[i])
	end
end

function ColorSwapComponent:replace(group, newColors)
	assert(self.groups[group], "No such color group: "..tostring(group))

	local offset, count = unpack(self.groups[group])
	assert(count == #newColors,
		"Group "..tostring(group).." uses "..tonumber(count).." colors. "..tonumber(#newColors).." received.")

	for i=1,count do
		self.newColors[i+offset] = newColors[i]
	end
end

function ColorSwapComponent:getReplacedColors()
	return self.oldColors
end

function ColorSwapComponent:getReplacingColors()
	return self.newColors
end

return ColorSwapComponent
