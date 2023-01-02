require "/scripts/rect.lua"
require "/scripts/vec2.lua"

--[[
  Script that spawns a void projectile at a random starting position and a random ending position and immediately causes
  the current projectile to die.
]]

local targetOffsetRange
local spawnOffsetRange

function init()
  targetOffsetRange = config.getParameter("targetOffsetRange")
  spawnOffsetRange = config.getParameter("spawnOffsetRange")
  
  local targetOffset = rect.randomPoint(targetOffsetRange)
  local spawnOffset = rect.randomPoint(spawnOffsetRange)
  local targetPosition = vec2.add(mcontroller.position(), targetOffset)
  local spawnPosition = vec2.add(mcontroller.position(), spawnOffset)

  world.spawnProjectile(
    "ruin-voidprojectile",
    spawnPosition,
    projectile.sourceEntity(),
    vec2.withAngle(math.random() * 2 * math.pi),  -- Completely random angle
    true,
    {targetPosition = targetPosition, power = projectile.power(), powerMultiplier = projectile.powerMultiplier()}
  )
  
  projectile.die()
end