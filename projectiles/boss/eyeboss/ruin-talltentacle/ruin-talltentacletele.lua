require "/scripts/vec2.lua"

local target
local nextProjectile
local lockYPos

function init()
  message.setHandler("setTarget", function(_, _, entityId)
    target = entityId
  end)
  message.setHandler("kill", function()
    shouldFire = false
    projectile.die()
  end)
  shouldFire = true
  nextProjectile = projectile.getParameter("nextProjectile")
  lockYPos = mcontroller.position()[2]
end

function update()
  if not target or not world.entityExists(target) or projectile.timeToLive() < 0.5 then return end

  local targetPosition = world.entityPosition(target)
  if targetPosition then
    mcontroller.setPosition({targetPosition[1], lockYPos})
  end

  if projectile.sourceEntity() and not world.entityExists(projectile.sourceEntity()) then
    projectile.die()
  end
end

function destroy()
  if shouldFire then
    local rotation = mcontroller.rotation()
    local offset = nextProjectile.offset
    world.spawnProjectile(nextProjectile.type, vec2.add(mcontroller.position(), offset), projectile.sourceEntity(), {math.cos(rotation), math.sin(rotation)}, false, { power = projectile.power(), powerMultiplier = projectile.powerMultiplier()})
    projectile.processAction(projectile.getParameter("explosionAction"))
  end
end