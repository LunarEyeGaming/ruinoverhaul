require "/scripts/util.lua"

local fadeColor
local fadeMax
local colorFadeTime
local disappearTime

local damageAmount

local targetStagehandQueryRange
local targetStagehand
local reappearDelay

local state

function init()
  fadeColor = config.getParameter("fadeColor")
  fadeMax = config.getParameter("fadeMax")
  colorFadeTime = config.getParameter("colorFadeTime")
  disappearTime = config.getParameter("disappearTime")

  damageAmount = config.getParameter("damageAmount")
  
  targetStagehandQueryRange = config.getParameter("targetStagehandQueryRange")
  targetStagehand = config.getParameter("targetStagehand")
  reappearDelay = config.getParameter("reappearDelay")

  state = coroutine.create(statusCourse)
end

function update(dt)
  mcontroller.setVelocity({0, 0})
  if coroutine.status(state) == "dead" then
    effect.expire()
  else
    local status, result = coroutine.resume(state)
    if not status then error(result) end
  end
end

function statusCourse()
  -- Apply color fade
  local timer = 0
  util.wait(colorFadeTime, function(dt)
    local fade = (timer / colorFadeTime) * fadeMax
    effect.setParentDirectives(string.format("fade=%s=%.2f", fadeColor, fade))
    timer = timer + dt
  end)
  
  -- Then fade out of existence
  timer = 0
  util.wait(disappearTime, function(dt)
    local alpha = math.max(math.floor(((disappearTime - timer) / disappearTime) * 255), 0)
    effect.setParentDirectives(string.format("?multiply=ffffff%02x?fade=%s=%.2f", alpha, fadeColor, fadeMax))
    timer = timer + dt
  end)
  
  status.applySelfDamageRequest({
    damageType = "IgnoresDef",
    damage = damageAmount,
    damageSourceKind = "plasma",
    sourceEntityId = entity.id()
  })
  
  teleport(targetStagehand)
end

--[[
  Teleports the parent entity to a random stagehand of the given type, if it exists.

  targetStagehand: the stagehand type to use
]]
function teleport(targetStagehand)
  local stagehandId = findStagehand(targetStagehand)
  
  if stagehandId then
    mcontroller.setPosition(world.entityPosition(stagehandId))
    
    util.wait(reappearDelay)
    
    effect.setParentDirectives()
    animator.burstParticleEmitter("teleport")
    animator.playSound("teleport")
  end
end

--[[
  Returns a random stagehand of the given type, if it exists. Otherwise, returns nil.
  
  returns: a stagehand ID, or nil
]]
function findStagehand(target)
  local stagehands = world.entityQuery(mcontroller.position(), targetStagehandQueryRange, 
      {includedTypes = {"stagehand"}, orderBy = "random"})
  
  for _, stagehand in ipairs(stagehands) do
    if world.stagehandType(stagehand) == targetStagehand then
      return stagehand
    end
  end
end