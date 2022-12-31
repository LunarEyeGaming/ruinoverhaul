require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

local travelDelay
local travelDelayTimer

local travelTime
local travelTimer

local initialPosition
local targetPosition

local interpFunc

function init()
  travelDelay = config.getParameter("travelDelay")
  travelDelayTimer = travelDelay

  travelTime = config.getParameter("travelTime")
  travelTimer = travelTime

  initialPosition = mcontroller.position()
  targetPosition = config.getParameter("targetPosition")
  
  interpFunc = interp.reverse(interp.sin)
end

function sourceEntityAlive()
  return world.entityExists(projectile.sourceEntity()) and world.entityHealth(projectile.sourceEntity())[1] > 0
end

function update(dt)
  if not sourceEntityAlive() then
    projectile.die()
    return
  end
  
  -- Wait a certain amount of time, then move toward the target position.
  if travelDelayTimer > 0 then
    travelDelayTimer = math.max(0, travelDelayTimer - dt)
  elseif travelTimer > 0 then
    updatePos(dt)
  end
end

function updatePos(dt)
  travelTimer = math.max(0, travelTimer - dt)
  local ratio = 1 - (travelTimer / travelTime)

  mcontroller.setPosition(
    {
      interpFunc(ratio, targetPosition[1], initialPosition[1]),
      interpFunc(ratio, targetPosition[2], initialPosition[2])
    }
  )
end