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

local Timer = require "lib.hump.timer"

local Widget = require "src.game.gui.widget"

local spriteSheet = require "src.game.spritesheet"

local ObjectivesPanel = Widget:subclass("ObjectivesPanel")

ObjectivesPanel.static.uniqueID = 0

function ObjectivesPanel:initialize(eventManager, x, y)
	self.eventManager = eventManager
	self.panels = {}
	self.font = love.graphics.newFont("asset/font/Norse.otf", 15)
	self.panelSprite1 = spriteSheet:getSprite("objectives-panel")
	self.panelSprite2 = spriteSheet:getSprite("objectives-panel2")
	self.panelData1 = spriteSheet:getData("objectives-panel-text")
	self.panelData2 = spriteSheet:getData("objectives-panel2-text")

	-- Widget:
	self.x, self.y = x, y
	self.ox, self.oy = 0, 0
	self.w, self.h = self.panelSprite1:getWidth(), 0
end

function ObjectivesPanel:draw()
	for i,panel in ipairs(self.panels) do
		panel:draw()

		-- Soften the harsh colour between the panels.
		if i ~= 1 then
			love.graphics.setColor(spriteSheet:getWoodPalette().dark)
			love.graphics.rectangle("fill", panel.x + 1, panel.y - 1, panel.w - 2, 2)
			love.graphics.setColor(1, 1, 1, 1)
		end
	end
end

function ObjectivesPanel:addObjective(objective, skipTween)
	local numPanels = #self.panels

	local panel
	if self.font:getWidth(objective.text) > self.panelData1.bounds.w then
		self.font:setLineHeight(1.2)
		panel = Widget(self.x, self.y + self.h - 1, 0, 0, self.panelSprite2)
		panel:addText(objective.text, self.font, spriteSheet:getOutlineColor(),
		              self.panelData2.bounds.x, self.panelData2.bounds.y, self.panelData2.bounds.w)
	else
		panel = Widget(self.x, self.y + self.h - 1, 0, 0, self.panelSprite1)
		panel:addText(objective.text, self.font, spriteSheet:getOutlineColor(),
		              self.panelData1.bounds.x, self.panelData1.bounds.y, self.panelData1.bounds.w)
	end

	panel.objective = objective
	self.h = self.h + panel:getHeight()
	table.insert(self.panels, panel)
	panel.uniqueID = ObjectivesPanel.uniqueID
	ObjectivesPanel.static.uniqueID = ObjectivesPanel.uniqueID + 1

	if not skipTween then
		-- Create a nice tween effect (reverse of the remove one).
		local panelNum = numPanels + 1
		local oldX = self.panels[panelNum].x
		self.panels[panelNum].x = -panel:getWidth()

		local time = 2.0
		local tween = "out-elastic"

		self.panels[panelNum].timers = {
			Timer.tween(time, self.panels[panelNum], { x = oldX }, tween)
		}
	end

	return panel.uniqueID
end

function ObjectivesPanel:removeObjective(uniqueID)
	local panelNum
	for i,panel in ipairs(self.panels) do
		if panel.uniqueID == uniqueID then
			panelNum = i
			break
		end
	end
	assert(panelNum, "Unique objective ID not found.")
	assert(not self.panels[panelNum].removed, "Objective already removed")

	for _,timer in ipairs(self.panels[panelNum].timers) do
		Timer.cancel(timer)
	end

	local time = 2.0
	local tween = "out-sine"

	Timer.tween(time, self.panels[panelNum], { x = -self.panels[panelNum]:getWidth() }, tween, function()
		-- Another objective might have been removed since last time, so calculate the panel number again
		local newPanelNum
		for i,panel in ipairs(self.panels) do
			if panel.uniqueID == uniqueID then
				newPanelNum = i
				break
			end
		end
		self.h = self.h - self.panels[newPanelNum]:getHeight()
		table.remove(self.panels, newPanelNum)
		local nextY = self.y
		for i=newPanelNum,#self.panels do
			Timer.tween(0.5, self.panels[i], { y = nextY }, tween)
			nextY = nextY + self.panels[i].h
		end
	end)

	self.panels[panelNum].removed = true
end

function ObjectivesPanel:isWithin(x, y)
	if next(self.panels) then
		return Widget.isWithin(self, x, y)
	else
		return false
	end
end

function ObjectivesPanel:handlePress(x, y, released)
	if not released then
		return
	end

	for _,panel in ipairs(self.panels) do
		if panel:isWithin(x, y) then
			if not panel.objective.completed and panel.objective.onClick then
				panel.objective:onClick()
			end
			return
		end
	end
end

return ObjectivesPanel
