require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.targetOffsetRange = config.getParameter("targetOffsetRange")
  self.spawnOffsetRange = config.getParameter("spawnOffsetRange")
  
  local targetOffset = {
    util.randomIntInRange({self.targetOffsetRange[1], self.targetOffsetRange[3]}), 
    util.randomIntInRange({self.targetOffsetRange[2], self.targetOffsetRange[4]})
  }
  local spawnOffset = {
    util.randomIntInRange({self.spawnOffsetRange[1], self.spawnOffsetRange[3]}), 
    util.randomIntInRange({self.spawnOffsetRange[2], self.spawnOffsetRange[4]})
  }
  local targetPosition = vec2.add(mcontroller.position(), targetOffset)
  local spawnPosition = vec2.add(mcontroller.position(), spawnOffset)

  world.spawnProjectile(
    "ruin-voidprojectile",
    spawnPosition,
    projectile.sourceEntity(),
    world.distance(targetPosition, spawnPosition),
    true,
    {targetPosition = targetPosition, power = projectile.power(), powerMultiplier = projectile.powerMultiplier()}
  )
  
  projectile.die()
end