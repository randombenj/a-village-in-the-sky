local lovetoys = require "lib.lovetoys.lovetoys"
local table = require "lib.table"

local BuildingComponent = require "src.game.buildingcomponent"
local FieldComponent = require "src.game.fieldcomponent"
local InteractiveComponent = require "src.game.interactivecomponent"
local ResourceComponent = require "src.game.resourcecomponent"
local VillagerComponent = require "src.game.villagercomponent"
local WorkComponent = require "src.game.workcomponent"

local WorkEvent = require "src.game.workevent"

local spriteSheet = require "src.game.spritesheet"

local SpriteSystem = lovetoys.System:subclass("SpriteSystem")

SpriteSystem.static.ANIMATIONS = {
	idle = {},
	walking = {
		nothing = {},
		[ResourceComponent.WOOD] = {},
		[ResourceComponent.IRON] = {},
		[ResourceComponent.TOOL] = {},
		[ResourceComponent.GRAIN] = {},
		[ResourceComponent.BREAD] = {}
	},
	walking_to_work = {
		[WorkComponent.WOODCUTTER] = {},
		[WorkComponent.MINER] = {},
		[WorkComponent.BLACKSMITH] = {},
		[WorkComponent.FARMER] = {},
		[WorkComponent.BAKER] = {},
		[WorkComponent.BUILDER] = {}
	},
	working = {
		[WorkComponent.WOODCUTTER] = {},
		[WorkComponent.MINER] = {},
		[WorkComponent.BUILDER] = {},
		[WorkComponent.FARMER] = {}
	}
}

SpriteSystem.static.SENIOR_MODIFIER = 0.85

function SpriteSystem.requires()
	return {"SpriteComponent"}
end

function SpriteSystem:initialize(eventManager)
	lovetoys.System.initialize(self)

	self.eventManager = eventManager

	-- Make sure to clone the table since we want to change things in it.
	SpriteSystem.ANIMATIONS.idle = table.clone(spriteSheet:getFrameTag("Emptyhanded"), true)
	SpriteSystem.ANIMATIONS.idle.to = SpriteSystem.ANIMATIONS.idle.from

	local walking = SpriteSystem.ANIMATIONS.walking
	walking.nothing = spriteSheet:getFrameTag("Emptyhanded")

	for resource,name in pairs(ResourceComponent.RESOURCE_NAME) do
		-- TODO: Consolidate!!
		if resource == ResourceComponent.IRON then
			name = "ore"
		elseif resource == ResourceComponent.GRAIN then
			name = "wheat"
		end

		walking[resource] = {
			[1] = spriteSheet:getFrameTag("1 "..name),
			[2] = spriteSheet:getFrameTag("2 "..(resource == ResourceComponent.TOOL and name .. "s" or name)),
			[3] = spriteSheet:getFrameTag("3 "..(resource == ResourceComponent.TOOL and name .. "s" or name))
		}
	end

	local toWork = SpriteSystem.ANIMATIONS.walking_to_work
	toWork[WorkComponent.WOODCUTTER] = spriteSheet:getFrameTag("Axe")
	toWork[WorkComponent.MINER] = spriteSheet:getFrameTag("Pickaxe")
	toWork[WorkComponent.BLACKSMITH] = spriteSheet:getFrameTag("Hammer")
	toWork[WorkComponent.FARMER] = spriteSheet:getFrameTag("Sickle")
	toWork[WorkComponent.BAKER] = spriteSheet:getFrameTag("Rolling pin")
	toWork[WorkComponent.BUILDER] = spriteSheet:getFrameTag("Hammer")

	local working = SpriteSystem.ANIMATIONS.working
	working[WorkComponent.WOODCUTTER] = {
		E = spriteSheet:getFrameTag("Woodcutter left"),
		W = spriteSheet:getFrameTag("Woodcutter right")
	}
	working[WorkComponent.MINER] = {
		E = spriteSheet:getFrameTag("Miner left"),
		W = spriteSheet:getFrameTag("Miner right")
	}
	working[WorkComponent.BUILDER] = {
		NE = spriteSheet:getFrameTag("Builder left"),
		NW = spriteSheet:getFrameTag("Builder right")
	}
	working[WorkComponent.FARMER] = {
		[FieldComponent.UNCULTIVATED] = {
			NW = spriteSheet:getFrameTag("Plowing")
		},
		[FieldComponent.PLOWED] = {
			NW = spriteSheet:getFrameTag("Seeding")
		},
		[FieldComponent.SEEDED] = {
			NW = spriteSheet:getFrameTag("Watering")
		},
		[FieldComponent.GROWING] = {
			NW = spriteSheet:getFrameTag("Watering")
		},
		[FieldComponent.HARVESTING] = {
			NW = spriteSheet:getFrameTag("Reaping")
		}
	}
end

function SpriteSystem:update(dt)
	for _,entity in pairs(self.targets) do
		if entity:has("VillagerComponent") then
			self:updateVillager(dt, entity)
		elseif entity:has("AnimationComponent") then
			self:updateAnimation(dt, entity)
		elseif entity:get("SpriteComponent"):needsRefresh() then
			if entity:has("ResourceComponent") then
				local resource = entity:get("ResourceComponent")
				local type = resource:getResource()
				local name = ResourceComponent.RESOURCE_NAME[type]
				local sprite = spriteSheet:getSprite(name.."-resource "..tostring(resource:getResourceAmount() - 1))

				entity:get("SpriteComponent"):setSprite(sprite)
			end
			if entity:has("BuildingComponent") and entity:has("EntranceComponent") then
				local name = BuildingComponent.BUILDING_NAME[entity:get("BuildingComponent"):getType()]
				local sprite = spriteSheet:getSprite(name .. (entity:get("EntranceComponent"):isOpen() and " 1" or " 0"))

				entity:get("SpriteComponent"):setSprite(sprite)
			end

			entity:get("SpriteComponent"):setNeedsRefresh(false)
		end
	end
end

function SpriteSystem:updateVillager(dt, entity)
	local villager = entity:get("VillagerComponent")
	local adult = entity:has("AdultComponent") and entity:get("AdultComponent")
	local sprite = entity:get("SpriteComponent")
	local animation = entity:get("AnimationComponent")

	-- Figure out the cardinal direction.
	local cardinalDir = villager:getCardinalDirection()

	-- Figure out the animation.
	local targetAnimation
	local animated = true
	local walking = false
	local working = false
	if adult and entity:has("CarryingComponent") then
		local carrying = entity:get("CarryingComponent")
		targetAnimation = SpriteSystem.ANIMATIONS.walking[carrying:getResource()][carrying:getAmount()]
		walking = true
		assert(targetAnimation, "Missing carrying animation for villager")
	elseif entity:has("WorkingComponent") then
		if entity:has("WalkingComponent") or not entity:get("WorkingComponent"):getWorking() then
			targetAnimation = SpriteSystem.ANIMATIONS.walking_to_work[adult:getOccupation()]
			assert(targetAnimation, "Missing walking animation")
			walking = true
			-- XXX: Didn't want to make a check like this, but here we are.
			if villager:getGoal() == VillagerComponent.GOALS.WAIT then
				animated = false
			end
		else
			local occupation = adult:getOccupation()
			local animations = assert(SpriteSystem.ANIMATIONS.working[occupation],
			                          "No animation for "..adult:getOccupationName())
			if occupation == WorkComponent.FARMER then
				-- Train-wreck anti-pattern?
				animations = animations[entity:get("AdultComponent"):getWorkPlace():get("FieldComponent"):getState()]
			end
			targetAnimation = animations[cardinalDir]
			working = true
			assert(targetAnimation, "Missing working animation. " ..
			       "Occupation: "..adult:getOccupationName()..", Direction: "..cardinalDir)
		end
	elseif entity:has("WalkingComponent") then
		targetAnimation = SpriteSystem.ANIMATIONS.walking.nothing
		walking = true
	else
		targetAnimation = SpriteSystem.ANIMATIONS.idle
		animated = false
	end

	-- Modify the animation speed based on certain criteria.
	local durationModifier = 1.0
	if working then
		-- t(0.0) = 20
		-- t(0.5) = 10
		-- t(1.0) = 5
		-- t = 2^(2 - x) * 5
		--
		-- x = 2^(2 - y) / 2
		-- TODO: Is this really what I want?
		local attribute
		if adult and adult:getOccupation () == WorkComponent.BUILDER then
			-- Builders use craftsmanship instead.
			attribute = villager:getCraftsmanship()
		else
			attribute = villager:getStrength()
		end
		durationModifier = 2^(2 - attribute) / 2
		if entity:has("SeniorComponent") then
			durationModifier = durationModifier * SpriteSystem.SENIOR_MODIFIER
		end
	elseif walking then
		if entity:has("WalkingComponent") then
			durationModifier = 1 / entity:get("WalkingComponent"):getSpeedModifier()
		else
			-- "Walking" in place to simulate some kind of movement when picking up/dropping off stuff.
			durationModifier = 0.8
		end
	end

	-- Figure out the animation frame.
	local frame, newFrame
	if animation:getAnimation() ~= targetAnimation then
		newFrame = true
		animation:setAnimation(targetAnimation)
	elseif animated then
		local t = animation:getTimer() - dt
		if t <= 0 then
			newFrame = true
			animation:advance()
		else
			animation:setTimer(t)
		end
	end
	frame = animation:getCurrentFrame()

	-- Figure out the sprite.
	local slice, sliceFrame, targetSprite, duration
	local hairy = villager:isHairy() and "(Hairy) " or ""
	if working then
		slice = "Working"
		sliceFrame = animation:getAnimation().from
		targetSprite, duration = spriteSheet:getSprite("villagers-action "..hairy..frame, slice, targetAnimation.from)
	else
		if adult then
			slice = villager:getGender() .. " - " .. cardinalDir
			targetSprite, duration = spriteSheet:getSprite("villagers "..hairy..frame, slice)
		else
			slice = (villager:getGender() == "male" and "Boy" or "Girl") .. " - " .. cardinalDir
			if entity:has("CarryingComponent") then
				-- TODO: Convert to using the frames as the adults.
				slice = slice .. " - Bread"
			end
			targetSprite, duration = spriteSheet:getSprite("children "..frame, slice)
		end
	end

	if newFrame then
		animation:setTimer(duration / 1000 * durationModifier)
	end

	-- TODO: Improve?
	if working and newFrame then
		-- Note: Zero indexed
		local frameNum = frame - animation:getAnimation().from
		if adult:getOccupation() == WorkComponent.BUILDER then
			if frameNum == 1 then
				self.eventManager:fireEvent(WorkEvent(entity, adult:getWorkPlace()))
			end
		elseif frameNum == 2 then
			self.eventManager:fireEvent(WorkEvent(entity, adult:getWorkPlace()))
		end
	end

	sprite:setSprite(targetSprite)

	local data = spriteSheet:getData(slice, sliceFrame)

	local x, y = entity:get("GroundComponent"):getIsometricPosition()
	local dx, dy = x - data.pivot.x - 1, y - data.pivot.y - 1
	sprite:setDrawPosition(dx, dy)

	if not entity:has("InteractiveComponent") then
		InteractiveComponent:makeInteractive(entity, dx, dy)
	elseif newFrame then
		-- TODO: Moving doesn't work (sprite size changes drastically) :(
		--entity:get("InteractiveComponent"):move(dx - prevDrawX, dy - prevDrawY)
		entity:remove("InteractiveComponent")
		InteractiveComponent:makeInteractive(entity, dx, dy)
	end
end

function SpriteSystem:updateAnimation(dt, entity)
	local sprite = entity:get("SpriteComponent")
	local animation = entity:get("AnimationComponent")

	local newFrame
	local t = animation:getTimer() - dt
	if t <= 0 then
		newFrame = true
		animation:advance()
	else
		animation:setTimer(t)
	end

	if newFrame then
		local frame = animation:getCurrentFrame()
		local targetSprite = animation:getFrames()[frame][1]
		local duration = animation:getFrames()[frame][2]

		animation:setTimer(duration / 1000)

		sprite:setSprite(targetSprite)
	end
end

return SpriteSystem
