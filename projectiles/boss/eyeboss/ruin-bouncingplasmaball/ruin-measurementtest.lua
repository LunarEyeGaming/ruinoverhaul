require "/scripts/vec2.lua"

local oldVelocity

function init()
  oldVelocity = mcontroller.velocity()
end

function update(dt)
  local velocity = mcontroller.velocity()
  
  sb.logInfo("velocity: %s, change in velocity: %s", velocity, vec2.sub(oldVelocity, velocity))
  
  oldVelocity = velocity
end