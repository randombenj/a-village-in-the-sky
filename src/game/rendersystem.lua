local lovetoys = require "lib.lovetoys.lovetoys"

local spriteSheet = require "src.game.spritesheet"
local state = require "src.game.state"

local RenderSystem = lovetoys.System:subclass("RenderSystem")

RenderSystem.static.OLD_OUTLINE_COLOR = { 0.0, 0.0, 0.0, 1.0 }
RenderSystem.static.NEW_OUTLINE_COLOR = { 0.15, 0.15, 0.15, 1.0 }
RenderSystem.static.SELECTED_OUTLINE_COLOR = { 0.15, 0.70, 0.15, 1.0 }
RenderSystem.static.BEHIND_OUTLINE_COLOR = { 0.70, 0.70, 0.70, 1.0 }
RenderSystem.static.SELECTED_BEHIND_OUTLINE_COLOR = { 0.60, 0.95, 0.60, 1.0 }

RenderSystem.static.COLOR_OUTLINE_SHADER = love.graphics.newShader([[
extern bool noShadow;
extern bool shadowOnly;
extern bool outlineOnly;
extern vec4 oldOutlineColor;
extern vec4 newOutlineColor;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec4 texturecolor = Texel(texture, texture_coords);

	if(texturecolor.a == 0.0)
		discard; // Don't count for stencil tests.
	if(shadowOnly && texturecolor.a > 0.5)
		discard;
	if(texturecolor == oldOutlineColor)
		return newOutlineColor; // * color;
	if(outlineOnly || (noShadow && texturecolor.a < 0.5))
		discard;

	return texturecolor * color;
}
]])

--[[
RenderSystem.static.CREATE_OUTLINE_SHADER = love.graphics.newShader([-[
extern vec2 stepSize;
extern vec4 outlineColor;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	number alpha = 4 * Texel(texture, texture_coords).a;
	alpha -= Texel(texture, texture_coords + vec2( stepSize.x, 0.0f)).a;
	alpha -= Texel(texture, texture_coords + vec2(-stepSize.x, 0.0f)).a;
	alpha -= Texel(texture, texture_coords + vec2(0.0f,  stepSize.y)).a;
	alpha -= Texel(texture, texture_coords + vec2(0.0f, -stepSize.y)).a;
	return vec4(outlineColor.r, outlineColor.g, outlineColor.b, outlineColor.a * alpha);
}
]-])
--]]

function RenderSystem:initialize()
	lovetoys.System.initialize(self)

	self.font = love.graphics.newFont("asset/font/Norse-Bold.otf", 16)

	RenderSystem.COLOR_OUTLINE_SHADER:send("noShadow", false)
	RenderSystem.COLOR_OUTLINE_SHADER:send("shadowOnly", false)
	RenderSystem.COLOR_OUTLINE_SHADER:send("outlineOnly", false)
	RenderSystem.COLOR_OUTLINE_SHADER:send("oldOutlineColor", RenderSystem.OLD_OUTLINE_COLOR)
	RenderSystem.COLOR_OUTLINE_SHADER:send("newOutlineColor", RenderSystem.NEW_OUTLINE_COLOR)

	-- NOTE: Global
	love.graphics.setShader(RenderSystem.COLOR_OUTLINE_SHADER)
end

function RenderSystem.requires()
	return {"SpriteComponent"}
end

function RenderSystem:draw()
	love.graphics.setColor(1, 1, 1)
	local ground = {}
	local objects = {}

	-- TODO: Can be optimized (spritebatched)
	for _,entity in pairs(self.targets) do
		if entity:has("TileComponent") then
			table.insert(ground, entity)
			table.sort(ground, function(a, b)
				local ai, aj = a:get("TileComponent"):getPosition()
				local bi, bj = b:get("TileComponent"):getPosition()
				if aj < bj then
					return true
				elseif aj == bj then
					return ai < bi
				else
					return false
				end
			end)
		end
	end

	-- TODO: Can probably cache (overwrite addEntity/removeEntity?)
	for _,entity in pairs(self.targets) do
		if entity:has("PositionComponent") then
			table.insert(objects, entity)
			table.sort(objects, function(a, b)
				local agrid = a:get("PositionComponent"):getPosition()
				local bgrid = b:get("PositionComponent"):getPosition()
				--if aj < bj then
					--return false
				--elseif aj == bj then
					--return ai > bi
				--else
					--return false
				--end
				if agrid.gi == bgrid.gi then
					return agrid.gj < bgrid.gj
				end
				return agrid.gi < bgrid.gi
			end)
		end
	end

	if state:isPlacing() then
		table.insert(objects, state:getPlacing())
	end

	for _,entity in ipairs(ground) do
		local sprite = entity:get("SpriteComponent")
		love.graphics.setColor(sprite:getColor())
		spriteSheet:draw(sprite:getSprite(), sprite:getDrawPosition())
	end

	for _,entity in ipairs(objects) do
		local sprite = entity:get("SpriteComponent")
		local dx, dy = sprite:getDrawPosition()

		if state:getSelection() == entity then
			RenderSystem.COLOR_OUTLINE_SHADER:send("newOutlineColor", RenderSystem.SELECTED_OUTLINE_COLOR)
		elseif entity:has("BlinkComponent") and entity:get("BlinkComponent"):isActive() then
			RenderSystem.COLOR_OUTLINE_SHADER:send("newOutlineColor", entity:get("BlinkComponent"):getColor())
		end

		RenderSystem.COLOR_OUTLINE_SHADER:send("noShadow", true)

		-- Transparent background for buildings under construction, and setup for the non-transparent part.
		if entity:has("ConstructionComponent") then
			love.graphics.setColor(1, 1, 1, 0.5)
			spriteSheet:draw(sprite:getSprite(), dx, dy)

			local percent = entity:get("ConstructionComponent"):getPercentDone()
			local quad = sprite:getSprite():getQuad()
			local x, y, w, h = quad:getViewport()
			sprite.oldViewport = { x, y, w, h }
			local _, ty, _, th = sprite:getSprite():getTrimmedDimensions()

			local deficit = th - th * percent / 100
			quad:setViewport(x, y + ty + deficit, w, th - deficit)
			dy = dy + ty + deficit
		end

		love.graphics.setColor(sprite:getColor())

		if entity:has("VillagerComponent") then
			-- Get rid of any previous stencil values on that position.
			love.graphics.stencil(function()
				love.graphics.setColorMask()
				spriteSheet:draw(sprite:getSprite(), dx, dy)
			end, "replace", 0, true)
		elseif entity:has("ResourceComponent") and entity:get("ResourceComponent"):isUsable() then
			spriteSheet:draw(sprite:getSprite(), dx, dy)
		else
			-- Increase the stencil value for non-villager, non-resource things.
			love.graphics.stencil(function()
				love.graphics.setColorMask()
				spriteSheet:draw(sprite:getSprite(), dx, dy)
			end, "replace", 1, true)
		end

		-- Draw the shadow separately
		RenderSystem.COLOR_OUTLINE_SHADER:send("noShadow", false)
		RenderSystem.COLOR_OUTLINE_SHADER:send("shadowOnly", true)
		-- The colour mask makes it so that the shadow doesn't "stick out" from the tiles.
		love.graphics.setColorMask(true, true, true, false)
		spriteSheet:draw(sprite:getSprite(), dx, dy)

		-- Reset
		love.graphics.setColorMask()
		RenderSystem.COLOR_OUTLINE_SHADER:send("shadowOnly", false)
		RenderSystem.COLOR_OUTLINE_SHADER:send("newOutlineColor", RenderSystem.NEW_OUTLINE_COLOR)

		-- Text overlay
		if entity:has("ConstructionComponent") then
			-- Reset quad
			local quad = sprite:getSprite():getQuad()
			quad:setViewport(unpack(sprite.oldViewport))
			sprite.oldViewport = nil

			-- Prepare text
			local percent = entity:get("ConstructionComponent"):getPercentDone()
			love.graphics.setFont(self.font)
			local grid = entity:get("PositionComponent"):getPosition()
			local gi, gj = grid.gi, grid.gj
			-- TODO
			local ox, oy = 4, 2
			local Fx, Fy = (gi - gj) * ox, (gi + gj) * oy
			Fy = Fy - oy * 2 - self.font:getHeight()

			-- Drop shadow
			love.graphics.setColor(0, 0, 0, 0.5)
			love.graphics.print(percent .. "%", Fx + 1, Fy + 1)
			-- Text
			love.graphics.setColor(1, 1, 1, 1)
			love.graphics.print(percent .. "%", Fx, Fy)
		end
	end

	do -- Behind outline.
		love.graphics.setStencilTest("greater", 0)
		RenderSystem.COLOR_OUTLINE_SHADER:send("outlineOnly", true)

		for _,entity in ipairs(objects) do
			if state:getSelection() == entity then
				RenderSystem.COLOR_OUTLINE_SHADER:send("newOutlineColor", RenderSystem.SELECTED_BEHIND_OUTLINE_COLOR)
			else
				RenderSystem.COLOR_OUTLINE_SHADER:send("newOutlineColor", RenderSystem.BEHIND_OUTLINE_COLOR)
			end

			if entity:has("VillagerComponent") then
				local sprite = entity:get("SpriteComponent")
				spriteSheet:draw(sprite:getSprite(), sprite:getDrawPosition())
			end
		end

		love.graphics.setStencilTest()
		RenderSystem.COLOR_OUTLINE_SHADER:send("outlineOnly", false)
		RenderSystem.COLOR_OUTLINE_SHADER:send("newOutlineColor", RenderSystem.NEW_OUTLINE_COLOR)
	end

	love.graphics.setColor(1, 1, 1, 1)

	-- Headers
	for _,entity in ipairs(objects) do
		local sprite = entity:get("SpriteComponent")

		if entity:has("VillagerComponent") then
			local villager = entity:get("VillagerComponent")

			if not villager:getHome() then
				local header = spriteSheet:getSprite("headers", "no-home-icon")
				local w, _ = header:getDimensions()

				local x, y = entity:get("GroundComponent"):getIsometricPosition()
				x = x - w / 2
				y = y - 28 -- TODO: Guesswork, not true for children.
				spriteSheet:draw(header, x, y)
			end

			--[[
			local header = spriteSheet:getSprite("headers", "person-header")
			local x, y = sprite:getDrawPosition()
			x = x - 5
			if villager:isAdult() then
				y = y - 10
			else
				y = y - 8
			end
			--self.font = love.graphics.newFont("asset/font/Norse-Bold.otf", 16)
			local font = love.graphics.newFont("asset/font/Norse.otf", 14)
			font:setFilter("linear", "linear", 1)
			--print(font:getFilter())
			love.graphics.setFont(font)
			spriteSheet:draw(header, x, y)
			love.graphics.print("Lars Larsson", x, y)
			--]]
		elseif entity:has("ConstructionComponent") then
			local header = spriteSheet:getSprite("headers", "4-spot-building-header")
			local x, y = sprite:getOriginalDrawPosition()
			local w, h = header:getDimensions()
			local tw = sprite:getSprite():getWidth()

			x = x + (tw - w) / 2
			y = y - h / 2
			spriteSheet:draw(header, x, y)

			local icon = spriteSheet:getSprite("headers", "occupied-icon")
			for i=1,#entity:get("ConstructionComponent"):getAssignedVillagers() do
				-- TODO: Value
				spriteSheet:draw(icon, 9 + x + ((i - 1) * (icon:getWidth() + 1)), y + 1)
			end
		elseif entity:has("DwellingComponent") then
			local dwelling = entity:get("DwellingComponent")
			local header = spriteSheet:getSprite("headers", "dwelling-header")
			local x, y = sprite:getOriginalDrawPosition()
			local w, h = header:getDimensions()
			local tw = sprite:getSprite():getWidth()

			x = x + (tw - w) / 2
			y = y - h / 2
			spriteSheet:draw(header, x, y)

			local headerData = spriteSheet:getData("dwelling-header")
			for _,type in ipairs({ "boys", "girls", "food" }) do
				local data = spriteSheet:getData(type .. "-count")
				local Fx, Fy = x + data.bounds.x - headerData.bounds.x, y + data.bounds.y - headerData.bounds.y

				if type == "food" then
					love.graphics.setFont(love.graphics.newFont("asset/font/Norse.otf", data.bounds.h))
				else
					love.graphics.setFont(love.graphics.newFont(data.bounds.h))
				end

				-- Drop shadow
				--love.graphics.setColor(0, 0, 0, 0.5)
				love.graphics.setColor(RenderSystem.NEW_OUTLINE_COLOR)
				love.graphics.print("0", Fx + 1, Fy + 1)
				-- Text
				love.graphics.setColor(RenderSystem.BEHIND_OUTLINE_COLOR)
				love.graphics.print("0", Fx, Fy)
			end

			local maleIcon = spriteSheet:getSprite("headers", "male-icon")
			local femaleIcon = spriteSheet:getSprite("headers", "female-icon")
			local villagers = dwelling:getAssignedVillagers()
			for i=1,#villagers do
				local icon = villagers[i]:get("VillagerComponent"):getGender() == "male" and maleIcon or femaleIcon
				spriteSheet:draw(icon, 10 + x + ((i - 1) * (icon:getWidth() + 1)), y + 1)
			end
		end
	end
end

return RenderSystem
