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

local SoundManager = class("SoundManager")

SoundManager.static.NUM_SOURCES = 10

SoundManager.static.MUSIC = "avits.ogg"

SoundManager.static.SFX = {
	-- GUI
	button_down = "select.wav",
	button_up = "deselect.wav",
	drawer_opened = "drawer_open.wav",
	drawer_closed = "drawer_close.wav",
	drawer_selected = "select.wav",
	main_menu_opened = "drawer_open.wav",
	main_menu_closed = "drawer_close.wav",
	new_event = "event.wav",
	-- In-world things
	door_opened = "door_open.wav",
	door_closed = "door_close.wav",
	propeller = "propeller.wav",
	selecting = "select.wav",
	clear_selection = "deselect.wav",
	successful_assignment = "affirmative.wav",
	failed_assignment = "negative.wav",
	tile_placed = "big_thud.wav",
	building_placed = "small_thud.wav",
	building_complete = "building_complete.wav",
	building_razed = "collapse.wav",
	placing_cleared = "deselect.wav",
	villager_death = "death.wav",
	-- Workers
	building = "building.wav",
	miner_working = "mining.wav",
	woodcutter_working = "wood-cut.wav",
	iron_gathered = "gathering_stones.wav",
	wood_gathered = "gathering_logs.wav"
}

local function _getVolume(type)
	local volume = type == "sfx" and 0.75 or 0.25

	local file = type .. "_volume"
	if love.filesystem.getInfo(file, "file") then
		volume = tonumber((love.filesystem.read(file))) or volume
	end

	return volume
end

local function _saveVolume(type, volume)
	volume = math.min(1.0, math.max(0.0, volume))
	local file = type .. "_volume"

	love.filesystem.write(file, tostring(volume))

	return volume
end

function SoundManager:initialize()
	self.sources = {}

	for _=1,SoundManager.NUM_SOURCES do
		table.insert(self.sources, love.audio.newQueueableSource(44100, 16, 1, 1))
	end

	for key,file in pairs(SoundManager.SFX) do
		SoundManager.SFX[key] = love.sound.newSoundData("asset/sfx/"..file)
	end

	self.music = love.audio.newSource("asset/sfx/"..SoundManager.MUSIC, "stream")
	self.music:setLooping(true)

	self:setEffectVolume(self:getEffectVolume())
	self:setMusicVolume(self:getMusicVolume())
end

function SoundManager:getEffectVolume()
	return _getVolume("sfx")
end

function SoundManager:setEffectVolume(volume)
	volume = _saveVolume("sfx", volume)
	for _,source in ipairs(self.sources) do
		source:setVolume(volume)
	end
end

function SoundManager:getMusicVolume()
	return _getVolume("music")
end

function SoundManager:setMusicVolume(volume)
	volume = _saveVolume("music", volume)
	self.music:setVolume(volume)
end

function SoundManager:setPositionFunction(func)
	self.positionFunc = func
end

function SoundManager:playEffect(effect, gi, gj)
	if not gj and type(gi) == "table" then
		gi, gj = gi.gi, gi.gj
	end

	local source = self:_getFreeSource()
	if not source then
		--print("Sound effect '"..tostring(effect).."' dropped.")
		return
	end

	local x, y
	if gi and gj then
		local inRange
		inRange, x, y = self.positionFunc(gi, gj)

		if not inRange then
			--print("Sound effect '"..tostring(effect).."' out of range.")
			return
		end
	end

	local sfx = SoundManager.SFX[effect]
	if not sfx then
		print("Sound effect '"..tostring(effect).."' not found.")
		return
	end

	source:queue(sfx)
	source:setPitch(1.166 - love.math.random() / 3)
	if x and y then
		source:setPosition(x, y, 0)
		source:setRelative(false)
	else
		source:setPosition(0, 0, 0)
		source:setRelative(true)
	end
	source:play()
end

function SoundManager:playMusic()
	self.music:play()
end

function SoundManager:pauseMusic()
	self.music:pause()
end

function SoundManager:pauseAll()
	for _,source in ipairs(self.sources) do
		if source:isPlaying() then
			source:pause()
		end
	end
end

function SoundManager:resumeAll()
	for _,source in ipairs(self.sources) do
		if source:isPlaying() then
			source:play()
		end
	end
end

function SoundManager:stopAll()
	for _,source in ipairs(self.sources) do
		if source:isPlaying() then
			source:stop()
		end
	end
end

function SoundManager:_getFreeSource()
	for _,source in ipairs(self.sources) do
		if source:getFreeBufferCount() > 0 then
			return source
		end
	end

	return nil
end

return SoundManager()
