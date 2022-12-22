require "/scripts/vec2.lua"

--[[
  Script for spawning a shockwave every time the projectile bounces on the ground. mcontroller.onGround() is unreliable
  for detecting when a projectile has bounced on the ground on any given tick, so I have decided to make it so that it
  spawns a shockwave on the first tick that it is close enough to the ground that it will actually bounce within the
  next few ticks. It also corrects the trajectory so that the current projectile does not end up having such a low
  maximum height that it is humanly impossible to clear over the shockwave without bumping yourself on the head with the
  projectile.
  
  The current projectile is considered to have "exited" a bounce when hasTriggeredBounce is true and its height is
  greater than the bounceMargin (plus the distance from the lower part of the bound box to its center).
]]

local bounceMargin  -- How far below the projectile's bound box to check for collision geometry, in blocks.
local shockwaveSpawnHeight  -- The height at which the shockwave will be spawned from the ground level, in blocks.
local shockwaveType  -- The projectile type of the shockwave (spawns in both directions)
local shockwaveParams  -- The configuration parameters to override for the shockwave projectile
local shockwaveBurstType  -- The explosion projectile type
local shockwaveBurstParams  -- The configuration parameters to override for the explosion projectile

local explodingProjType  -- The projectile type to use after expiring
local explodingProjParams  -- The parameters of the projectile to use after expiring

local minPostBounceAngle  -- The minimum angle that the projectile should have after exiting a bounce

-- Whether or not the current projectile was close enough to the ground on the previous tick. This is to keep it from
-- spawning multiple shockwaves within the same bounce.
local hasTriggeredBounce
local hasBounced  -- Whether or not the projectile has exited a bounce.
local shouldSpawn  -- True by default, set to false if forcibly killed via entity message.

-- Loads some configuration parameters; performs some initial calculations; and initializes some variables as well as
-- setting a message handler.
function init()
  -- Load relevant parameters
  bounceMargin = config.getParameter("bounceMargin")
  shockwaveSpawnHeight = config.getParameter("shockwaveSpawnHeight")
  shockwaveType = config.getParameter("shockwaveType")
  shockwaveParams = config.getParameter("shockwaveParams")
  shockwaveParams.power = projectile.power() * config.getParameter("shockwaveDamageMultiplier", 1.0)
  shockwaveParams.powerMultiplier = projectile.powerMultiplier()
  shockwaveBurstType = config.getParameter("shockwaveBurstType")
  shockwaveBurstParams = config.getParameter("shockwaveBurstParams", {})
  shockwaveBurstParams.power = projectile.power() * config.getParameter("shockwaveBurstDamageMultiplier", 1.0)
  shockwaveBurstParams.powerMultiplier = projectile.powerMultiplier()
  
  explodingProjType = config.getParameter("explodingProjType")
  explodingProjParams = config.getParameter("explodingProjParams", {})
  explodingProjParams.power = projectile.power()
  explodingProjParams.powerMultiplier = projectile.powerMultiplier()
  explodingProjParams.speed = vec2.mag(mcontroller.velocity())
  
  -- Calculates the minimum post-bounce angle based on the minimum bounce apex -- or the smallest maximum height of the
  -- ball's trajectory allowed. This assumes that the gravity will never change throughout the lifespan of the
  -- projectile.
  minPostBounceAngle = calculateMinPostBounceAngle(config.getParameter("minBounceApex"))
  
  hasTriggeredBounce = false
  hasBounced = false
  shouldSpawn = true
  
  message.setHandler("kill", function()
    shouldSpawn = false
    projectile.die()
  end)
end

--[[
  On every tick, tests for whether or not the projectile is close enough to the ground and if so, spawns a shockwave 
  projectile in both directions <shockwaveSpawnHeight> from the ground once. Waits until it got away from the ground
  again to repeat the same process. Also corrects the trajectory on exiting a bounce so that the projectile is not too
  close to the ground.
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
  
  -- Correct trajectory on exiting a bounce.
  -- There is the possibility that the current projectile has a maximum height lower than the bounceMargin, in which
  -- case this code will never trigger. Would be nice if there is a solution to this problem.
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

--[[
  Forces the current projectile to have a higher velocity angle relative to the ground if it ends up being too low. The
  threshold is determined by the minPostBounceAngle variable derived from the minBounceApex configuration parameter.
  
  Precondition: mcontroller.yVelocity() > 0
]]
function correctPostBounceAngle()
  local velAngle = vec2.angle(mcontroller.velocity())
  local speed = vec2.mag(mcontroller.velocity())
  
  local groundAngle  -- Smallest angle relative to the ground
  local isFlipped  -- true if the x-direction is left, false otherwise
  
  -- Get the angle relative to the ground less than pi / 2 radians. This process gets rid of the x-direction part of the
  -- angle, so isFlipped serves the original x-direction.
  if velAngle < math.pi / 2 then
    groundAngle = velAngle
    isFlipped = false
  else
    groundAngle = math.pi - velAngle
    isFlipped = true
  end
  
  -- Correct the angle if necessary.
  if groundAngle < minPostBounceAngle then
    if isFlipped then
      mcontroller.setVelocity(vec2.withAngle(math.pi - minPostBounceAngle, speed))
    else
      mcontroller.setVelocity(vec2.withAngle(minPostBounceAngle, speed))
    end
  end
end

--[[
  Returns the minimum post-bounce angle based on the minimum bounce apex using a derived mathematical formula.
  
  minBounceApex: The minimum bounce apex to use in the calculation.
]]
function calculateMinPostBounceAngle(minBounceApex)
  local params = mcontroller.parameters()
  local gravity = world.gravity(mcontroller.position()) * params.gravityMultiplier
  local speed = vec2.mag(mcontroller.velocity())
  local initialVerticalVelocity = gravity * math.sqrt(2 * minBounceApex / gravity)
  
  return math.atan(initialVerticalVelocity / math.sqrt(speed ^ 2 - initialVerticalVelocity ^ 2))
end

--[[
  Spawns the variant of the current projectile that is about to explode if it has expired naturally (in other words has 
  not been killed by an entity message).
]]
function destroy()
  if shouldSpawn then
    world.spawnProjectile(explodingProjType, mcontroller.position(), projectile.sourceEntity(), mcontroller.velocity(),
        false, explodingProjParams)
  end
end