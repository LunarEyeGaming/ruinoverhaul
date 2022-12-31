require "/scripts/util.lua"

local projectileType
local projectileParameters
local projectileDamageFactor
local rings

function init()
  projectileType = config.getParameter("projectileType")
  projectileParameters = config.getParameter("projectileParameters", {})
  projectileDamageFactor = config.getParameter("projectileDamageFactor", 1.0)
  rings = config.getParameter("projectileRings")
end

function destroy()
  for _, ring in ipairs(rings) do
    for i = 1, ring.count do
      local initialAngle = util.lerp(i / ring.count, 0, 2 * math.pi)

      local params = sb.jsonMerge(projectileParameters, {
        initialAngle = initialAngle,
        radialSpeed = ring.radialSpeed,
        radialAcceleration = ring.radialAcceleration,
        angularVelocity = util.toRadians(ring.angularVelocity),
        power = projectile.power() * projectileDamageFactor,
        powerMultiplier = projectile.powerMultiplier(),
        timeToLive = ring.timeToLive
      })

      world.spawnProjectile(projectileType, mcontroller.position(), entity.id(), {0, 0}, false, params)
    end
  end
end