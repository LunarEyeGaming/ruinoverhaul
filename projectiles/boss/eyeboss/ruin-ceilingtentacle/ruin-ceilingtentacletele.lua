require "/scripts/vec2.lua"

local nextProjectile
local lockYPos

function init()
  message.setHandler("kill", function()
    shouldFire = false
    projectile.die()
  end)
  shouldFire = true
  nextProjectile = projectile.getParameter("nextProjectile")
  lockYPos = mcontroller.position()[2]
end

function destroy()
  if shouldFire then
    local rotation = mcontroller.rotation()
    local offset = nextProjectile.offset
    world.spawnProjectile(nextProjectile.type, vec2.add(mcontroller.position(), vec2.rotate(offset, rotation)),
        projectile.sourceEntity(), vec2.withAngle(rotation), false, {power = projectile.power(),
        powerMultiplier = projectile.powerMultiplier()})
    projectile.processAction(projectile.getParameter("explosionAction"))
  end
end