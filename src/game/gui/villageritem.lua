local babel = require "lib.babel"

local InfoPanelItem = require "src.game.gui.infopanelitem"

local ScaledSprite = require "src.game.scaledsprite"

local spriteSheet = require "src.game.spritesheet"

local VillagerItem = InfoPanelItem:subclass("VillagerItem")

VillagerItem.static.DETAILS = {
	{ "Name", "getName" },
	{ "Age", "getAge" },
	{ "Hunger", "getHunger" },
	{ "Sleepiness", "getSleepiness" },
	{},
	{ "Occupation", "getOccupationName", true },
	{ "Strength", "getStrength" },
	{ "Craftsmanship", "getCraftsmanship" }
}

function VillagerItem:initialize(x, y, h, fontNormal, fontBold, entity)
	InfoPanelItem.initialize(self, x, y, 160, h)

	local sprite
	if entity:has("AdultComponent") then
		local hairy = entity:get("VillagerComponent"):isHairy() and "(Hairy) " or ""
		sprite = spriteSheet:getSprite("villagers "..hairy.."0",
			entity:get("VillagerComponent"):getGender() .. " - S")
	else
		sprite = spriteSheet:getSprite("children 0",
			(entity:get("VillagerComponent"):getGender() == "male" and "boy" or "girl") .. " - S")
	end

	self.sprite = ScaledSprite:fromSprite(sprite, 4)
	self.fontNormal = fontNormal
	self.fontBold = fontBold
	self.entity = entity
end

function VillagerItem:drawOverride(offset)
	local colorSwap = self.entity:get("ColorSwapComponent")
	local oldColors = colorSwap:getReplacedColors()
	local newColors = colorSwap:getReplacingColors()
	local shader = love.graphics.getShader()

	local RenderSystem = require "src.game.rendersystem"

	-- Draw image of villager
	-- FIXME: Maybe DRY it up?
	shader:send("oldColor", RenderSystem.OLD_OUTLINE_COLOR, unpack(oldColors))
	shader:send("numColorReplaces", #newColors + 1)
	shader:send("newColor", RenderSystem.NEW_OUTLINE_COLOR, unpack(newColors or {}))
	shader:send("noShadow", true)

	spriteSheet:draw(self.sprite, self.x + offset + 2, self.y + 2)

	shader:send("numColorReplaces", 1)
	shader:send("noShadow", false)

	-- Draw text
	local sx, sy = self.x + offset, self.y + 5
	local oy = 2
	-- FIXME: Maybe DRY it up?
	local villager = self.entity:get("VillagerComponent")
	local adult = self.entity:has("AdultComponent") and self.entity:get("AdultComponent")
	for _,details in ipairs(VillagerItem.DETAILS) do
		local key, value, adultComp = details[1], details[2], details[3]
		if key == "Hunger" or key == "Sleepiness" then
			-- TODO: Experimental
			local icon = key == "Sleepiness" and spriteSheet:getSprite("headers", "sleepy-icon") or
			                                     spriteSheet:getSprite("headers", "hungry-icon")
			local w = 100
			local dh = -6
			value = villager[value](villager)
			local limit = math.floor(w * value)

			local bx = sx + self.w - w
			local by = sy + oy - dh / 2

			love.graphics.setColor(spriteSheet:getWoodPalette().outline)
			love.graphics.rectangle("fill", bx, by, w, icon:getHeight() + dh)

			love.graphics.setColor(1 * value, 1 - value, 0, 1)
			love.graphics.rectangle("fill", bx, by, limit, icon:getHeight() + dh)

			love.graphics.setColor(1, 1, 1, 1)
			spriteSheet:draw(icon, math.min(sx + self.w - icon:getWidth(), bx + limit - icon:getWidth() / 2), sy + oy)

			oy = oy + icon:getHeight() + 1
		elseif not key then
			if not adult then
				break
			end
		else
			key = babel.translate(key) .. ":"
			if adultComp then
				value = adult[value](adult)
			else
				value = villager[value](villager)
			end
			if type(value) == "number" then
				value = string.format("%.2f", value)
			end

			love.graphics.setColor(spriteSheet:getOutlineColor())

			local w = self.fontNormal:getWidth(value) + 2
			love.graphics.setFont(self.fontNormal)
			love.graphics.print(value, sx + self.w - w, sy + oy)

			love.graphics.setFont(self.fontBold)
			love.graphics.printf(key, sx, sy + oy, self.w - w - 1, "right")

			oy = oy + self.fontBold:getHeight() + 1
		end
	end
	love.graphics.setColor(1, 1, 1, 1)
end

function VillagerItem:select()
	InfoPanelItem.select(self)

	return self.entity
end

return VillagerItem