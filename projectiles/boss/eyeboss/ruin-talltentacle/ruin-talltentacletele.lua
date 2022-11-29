require "/scripts/vec2.lua"

function init()
  message.setHandler("setTarget", function(_, _, entityId)
    self.target = entityId
  end)
  message.setHandler("kill", function()
    shouldFire = false
    projectile.die()
  end)
  shouldFire = true
  self.nextProjectile = projectile.getParameter("nextProjectile")
  self.lockYPos = mcontroller.position()[2]
end

function update()
  if not self.target or not world.entityExists(self.target) or projectile.timeToLive() < 0.5 then return end

  local targetPosition = world.entityPosition(self.target)
  if targetPosition then
    mcontroller.setPosition({targetPosition[1], self.lockYPos})
  end

  if projectile.sourceEntity() and not world.entityExists(projectile.sourceEntity()) then
    projectile.die()
  end
end

function destroy()
  if shouldFire then
    local rotation = mcontroller.rotation()
    local offset = self.nextProjectile.offset
    world.spawnProjectile(self.nextProjectile.type, vec2.add(mcontroller.position(), offset), projectile.sourceEntity(), {math.cos(rotation), math.sin(rotation)}, false, { power = projectile.power(), powerMultiplier = projectile.powerMultiplier()})
    projectile.processAction(projectile.getParameter("explosionAction"))
  end
end