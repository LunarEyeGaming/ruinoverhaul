require "/scripts/vec2.lua"

--[[
  Script for spawning a shockwave every time the projectile bounces. mcontroller.onGround() is unreliable for detecting
  when a projectile has bounced on the ground on any given tick, so I have decided to make it so that it spawns a
  shockwave on the first tick that it is close enough to the ground that it will actually bounce within the next few
  ticks.
  
  The current projectile is considered to have "exited" a bounce when hasTriggeredBounce is true and its height is
  greater than the bounceMargin (plus the distance from the lower part of the bound box to its center).
]]

local bounceMargin  -- How far below the projectile's bound box to check for collision geometry, in blocks.
local shockwaveSpawnHeight  -- The height at which the shockwave will be spawned from the ground level, in blocks.
local shockwaveType  -- The projectile type of the shockwave (spawns in both directions)
local shockwaveParams  -- The configuration parameters to override for the shockwave projectile
local shockwaveBurstType  -- The explosion projectile type
local shockwaveBurstParams  -- The configuration parameters to override for the explosion projectile

local minPostBounceAngle  -- The minimum angle that the projectile should have after exiting a bounce

-- Whether or not the current projectile was close enough to the ground on the previous tick. This is to keep it from
-- spawning multiple shockwaves within the same bounce.
local hasTriggeredBounce
local hasBounced  -- Whether or not the projectile has exited a bounce.

-- Loads some configuration parameters.
function init()
  bounceMargin = config.getParameter("bounceMargin")
  shockwaveSpawnHeight = config.getParameter("shockwaveSpawnHeight")
  shockwaveType = config.getParameter("shockwaveType")
  shockwaveParams = config.getParameter("shockwaveParams")
  shockwaveParams.power = projectile.power() * config.getParameter("shockwaveDamageMultiplier", 1.0)
  shockwaveParams.powerMultiplier = projectile.powerMultiplier()
  shockwaveBurstType = config.getParameter("shockwaveBurstType")
  shockwaveBurstParams = config.getParameter("shockwaveBurstParams")
  shockwaveBurstParams.power = projectile.power() * config.getParameter("shockwaveBurstDamageMultiplier", 1.0)
  shockwaveBurstParams.powerMultiplier = projectile.powerMultiplier()
  
  minPostBounceAngle = math.pi * config.getParameter("minPostBounceAngle", 0) / 180  -- Convert to radians
  
  hasTriggeredBounce = false
  hasBounced = false
end

--[[
  On every tick, tests for whether or not the projectile is close enough to the ground and if so, spawns a shockwave 
  projectile in both directions <shockwaveSpawnHeight> from the ground once. Waits until it got away from the ground
  again to repeat the same process.
]]
function update(dt)
  local groundPos = bounceGroundPosition()
  if groundPos then
    if not hasTriggeredBounce then
      local projPos = {groundPos[1], groundPos[2] + shockwaveSpawnHeight}
      world.spawnProjectile(shockwaveType, projPos, projectile.sourceEntity(), {1, 0}, false, shockwaveParams)
      world.spawnProjectile(shockwaveType, projPos, projectile.sourceEntity(), {-1, 0}, false, shockwaveParams)
      world.spawnProjectile(shockwaveBurstType, projPos, projectile.sourceEntity(), {0, 0}, false, shockwaveBurstParams)
      hasTriggeredBounce = true
    end
  elseif hasTriggeredBounce then
    hasTriggeredBounce = false
    hasBounced = true
  end
  
  -- There is the possibility that the current projectile has a maximum height lower than the bounceMargin, in which
  -- case this code will never trigger.
  if hasBounced then
    hasBounced = false
    correctPostBounceAngle()
  end
end

--[[
  Returns the ground position directly below the projectile, if it will bounce within the next few ticks. Whether it
  will bounce is determined by whether or not there is collision geometry slightly below the projectile's bound box. 
  How far below is determined by the bounceMargin configuration parameter.
]]
function bounceGroundPosition()
  local boundBox = mcontroller.localBoundBox()
  -- The lowest vertical point of the collision poly is the second entry of the bound box
  local testAltitude = boundBox[2] - bounceMargin
  
  local ownPos = mcontroller.position()
  local testPos = {ownPos[1], ownPos[2] + testAltitude}
  
  return world.lineCollision(ownPos, testPos)
end

-- Note: The lowest value for the maximum height (relative to the bottom of the circle) should be about 8 blocks.
--[[
  Makes it so that the current projectile does not end up having such a low maximum height that it is nearly impossible
  to clear over the shockwave without bumping yourself on the head with the projectile. It does this by forcing it to
  have a higher velocity angle relative to the ground if it ends up being too low. The threshold is determined by the 
  minPostBounceAngle configuration parameter.
  
  Precondition: mcontroller.yVelocity() > 0
]]
function correctPostBounceAngle()
  local velAngle = vec2.angle(mcontroller.velocity())
  local speed = vec2.mag(mcontroller.velocity())
  
  local groundAngle  -- Smallest angle relative to the ground
  local isFlipped  -- true if the x-direction is left, false otherwise
  if velAngle < math.pi / 2 then
    groundAngle = velAngle
    isFlipped = false
  else
    groundAngle = math.pi - velAngle
    isFlipped = true
  end
  
  if groundAngle < minPostBounceAngle then
    if isFlipped then
      mcontroller.setVelocity(vec2.withAngle(math.pi - minPostBounceAngle, speed))
    else
      mcontroller.setVelocity(vec2.withAngle(minPostBounceAngle, speed))
    end
  end
end