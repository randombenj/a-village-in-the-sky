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

--- This class includes functions to help with managing different screen sizes.
-- Code taken from Jasoco @ https://love2d.org/forums/viewtopic.php?f=4&t=9636&p=59471#p59471
-- @author Albert Diserholt
-- @license GPLv3+

local class = require("lib.middleclass")

local Screen = class("Screen")

--- The preferences available to a screen.
-- @table pref
-- @tfield number drawWidth The width of the draw area.
-- @tfield number drawHeight The height of the draw area.
-- @tfield[opt=drawWidth] number screenWidth The width of the screen.
-- @tfield[opt=drawHeight] number screenHeight The height of the screen.
-- @tfield[opt=false] bool overrideDraw Whether to override the `love.draw()` function
-- with a custom function to draw the screen. The old `love.draw()` function
-- will be called within the screen's context.
-- @tfield[opt="linear"] FilterMode minFilter Filter mode to use when minifying.
-- @tfield[opt="nearest"] FilterMode magFilter Filter mode to use when
-- magnifying.
-- @tfield table flags Any extra flags to pass to `love.window.setMode()`.

--- Create a new screen object.
-- @tparam table pref Preferences for the new screen. See @{pref} for
-- understood preferences.
-- @raise Asserts that the specified screen width and high is supported if
-- going into fullscreen mode.
function Screen:setUp(pref)
	assert(type(pref) == "table", "The preference must be a table.")
	setmetatable(pref, { __index = {
		screenWidth = pref.drawWidth,
		screenHeight = pref.drawHeight,
		overrideDraw = false,
		flags = {}
	}})

	if pref.flags.fullscreen then
		assert(self:isValidFullscreenMode(pref.screenWidth, pref.screenHeight),
			"Fullscreen mode " .. tostring(pref.screenWidth) .. "x" .. tostring(pref.screenHeight) .. " is not supported.")
	end

	love.window.setMode(pref.screenWidth, pref.screenHeight, pref.flags)

	self.verticalScale = pref.screenHeight / pref.drawHeight
	self.horizontalScale = self.verticalScale

	self.offsetX = (pref.screenWidth - (pref.drawWidth * self.verticalScale)) / 2
	self.offsetY = (pref.screenHeight - (pref.drawHeight * self.horizontalScale)) / 2

	self.canvas = love.graphics.newCanvas(pref.drawWidth, pref.drawHeight, { msaa = pref.flags.msaa })
	self.canvas:setFilter(pref.minFilter, pref.magFilter)

	if pref.overrideDraw then
		assert(love.draw, "love.draw() was not defined before Screen:new() was called with overrideDraw = true.")
		self.oldDraw = love.draw
		love.draw = function()
			self:prepare()
			self.oldDraw()
			self:present()
		end
	end

	return true
end

function Screen:isValidFullscreenMode(width, height)
	local modes = love.window.getFullscreenModes()
	for _,mode in ipairs(modes) do
		if mode.width == width and mode.height == height then
			return true
		end
	end

	return false
end

--- Prepare to draw to the screen. This function should be called before
-- drawing anything. It is automatically invoked if `overrideDraw` was enabled.
function Screen:prepare()
	love.graphics.setCanvas({self.canvas, stencil = true})
	love.graphics.clear(0, 0, 0, 0, true)
end

--- Present the contents to the screen. This function should be called after
-- everything has been drawn. It is automatically invoked if `overrideDraw` was
-- enabled.
function Screen:present()
	love.graphics.setCanvas()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(self.canvas, self.offsetX, self.offsetY, 0,
	                   self.verticalScale, self.horizontalScale)
	love.graphics.setBlendMode("alpha")
end

function Screen:getDrawArea()
	return love.window.fromPixels(self.offsetX),
	       love.window.fromPixels(self.offsetY),
	       love.window.fromPixels(self.canvas:getDimensions())
end

--- Converts screen coordinates depending on scaling and offset.
-- @tparam number x The screen x-coordinate to translate to the draw area.
-- @tparam number y The screen y-coordinate to translate to the draw area.
-- @treturn number The x-coordinate in the draw area.
-- @treturn number The y-coordinate in the draw area.
function Screen:getCoordinate(x, y)
	x = math.max(x - self.offsetX, 0) / self.verticalScale
	y = math.max(y - self.offsetY, 0) / self.horizontalScale

	return x, y
end

--- Zoom the screen by a factor.
-- @tparam number x The zoom factor for the horizontal scale.
-- @tparam[opt] number y The zoom factor for the vertical scale, or the same as
-- the horizontal one if omitted.
function Screen:zoomBy(x, y)
	y = y or x
	self.verticalScale = self.verticalScale + x
	self.horizontalScale = self.horizontalScale + y
end

return Screen
