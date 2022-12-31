require "/scripts/vec2.lua"

local angle
local radialSpeed
local radialAcceleration
local angularVelocity

local radius
local center

function init()
  angle = config.getParameter("initialAngle")
  radialSpeed = config.getParameter("radialSpeed")
  radialAcceleration = config.getParameter("radialAcceleration")
  angularVelocity = config.getParameter("angularVelocity")

  radius = 0
  center = mcontroller.position()
end

function update(dt)
  -- Advance the curve one step
  angle = angle + angularVelocity * dt
  radius = radius + radialSpeed * dt
  radialSpeed = radialSpeed + radialAcceleration * dt
  
  -- Update position and rotation
  local prevPosition = mcontroller.position()
  local nextPosition = vec2.add(center, vec2.withAngle(angle, radius))
  mcontroller.setPosition(nextPosition)
  mcontroller.setRotation(vec2.angle(world.distance(nextPosition, prevPosition)))
end