require "/scripts/util.lua"
require "/scripts/vec2.lua"

local extension
local ownPosition

function init()
  extension = config.getParameter("extension")
  ownPosition = mcontroller.position()
  
  for i = 1, extension.count do
    local angle = util.lerp(i / extension.count, 0, math.pi * 2)
    local offset = vec2.rotate(extension.offset, angle)
    local aimVector = vec2.rotate({1, 0}, angle)
    world.spawnProjectile(extension.type, vec2.add(ownPosition, offset), projectile.sourceEntity(), aimVector, false, {power = projectile.power()})
  end
end

function update(dt)
  
end