require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/status.lua"

-- The tentacleMovement node has been overridden to make the Ruin's tentacles move more organically, utilizing rotations
-- and scales in lieu of pure vertical translations. It also applies sine easing to the transformations. The tentacles
-- move independently of each other.
-- param initialScales - The initial scales to use for the tentacles
-- param initialAngles - The initial angles to use for the tentacles in degrees
-- param timeRange - The range of time to complete each movement of each tentacle
-- param angleRange - The range of angles to use for each tentacle in degrees
-- param scaleRange - The range of scaling to use for each tentacle
-- param tentaclePivots - The relative positions to use for rotation and scaling for each tentacle
-- output scales - A list of the scales used for each tentacle as of the current tick. Use in conjunction with the
--    initialScales parameter to prevent sudden changes in movement between calls of this function (e.g. when changing 
--    phases).
-- output angles - A list of the angles used for each tentacle as of the current tick (in degrees). Use in conjunction
--    with the initialAngles parameter for the aforementioned reason.
function tentacleMovement(args, board, _, dt)
  -- Convert angles to radians.
  local angleRange = util.map(args.angleRange, function(angle) return util.toRadians(angle) end)

  -- Amount of time it should take to complete movements for each tentacle
  local times = util.rep(function() return util.randomInRange(args.timeRange) end, args.tentacleCount)

  local timers = util.rep(function() return 0 end, args.tentacleCount)  -- Timers to track movement progress
  
  local oldAngles  -- Angles from previous movement
  if args.initialAngles then
    -- Convert angles to radians.
    oldAngles = util.map(args.initialAngles, function(angle) return util.toRadians(angle) end)
  else
    oldAngles = util.rep(function() return 0 end, args.tentacleCount)
  end

  local angles = util.rep(function() return util.randomInRange(angleRange) end, 6)  -- Target angles

  -- Scales from previous movement
  local oldScales = args.initialScales or util.rep(function() return 1 end, args.tentacleCount)
  local scales = util.rep(function() return util.randomInRange(args.scaleRange) end, 6)  -- Target scales
  
  while true do
    local intermediateScales = {}
    local intermediateAngles = {}
  
    for i = 1, args.tentacleCount do
      if timers[i] >= times[i] then
        -- Reset timers, randomize times and angles, and save old angles.
        times[i] = util.randomInRange(args.timeRange)
        timers[i] = 0

        oldAngles[i] = angles[i]
        angles[i] = util.randomInRange(angleRange)

        oldScales[i] = scales[i]
        scales[i] = util.randomInRange(args.scaleRange)
      end

      timers[i] = timers[i] + dt
      
      local scale = util.easeInOutSin(timers[i] / times[i], oldScales[i], scales[i] - oldScales[i])
      local angle = util.easeInOutSin(timers[i] / times[i], oldAngles[i], angles[i] - oldAngles[i])
      
      animator.resetTransformationGroup("tentacle"..i)
      animator.scaleTransformationGroup("tentacle"..i, {1, scale}, args.tentaclePivots[i])
      animator.rotateTransformationGroup("tentacle"..i, angle, args.tentaclePivots[i])
      
      table.insert(intermediateScales, scale)
      table.insert(intermediateAngles, angle)
    end
    
    dt = coroutine.yield(nil, {scales = intermediateScales, angles = util.map(intermediateAngles, function(angle)
        return util.toDegrees(angle) end)})
  end
end

function heartBeat(args, board, _, dt)
  local moveTime = args.moveTime + args.moveDelays.right
  local movement = {
    left = {0.375, -0.375},
    middle = {0.0, -0.375},
    right = {-0.375, -0.375}
  }

  animator.playSound("heartin")
  local timer = 0
  while timer <= (moveTime + args.moveDelays.right) do
    timer = timer + dt

    for tentacle,offset in pairs(movement) do
      animator.resetTransformationGroup("heart"..tentacle)

      local delay = args.moveDelays[tentacle]
      if timer > delay then
        local ratio = math.min(1.0, (timer - delay) / moveTime)
        local multiply = interp.ranges(ratio, {
          {0.5, interp.linear, 0, 1},
          {1.0, interp.linear, 1, 0}
        })

        animator.translateTransformationGroup("heart"..tentacle, vec2.mul(offset, multiply))
      end
    end

    coroutine.yield()
  end
  animator.playSound("heartout")

  return true
end

-- Overridden to allow for more orderly spawning of monster groups.
function spawnMonsterGroup(args, board, _, dt)
  local spawnGroup = util.randomFromList(config.getParameter("monsterSpawnGroups"))

  animator.setGlobalTag("biome", spawnGroup.biome)

  local timer = args.windup
  while timer > 0 do
    timer = timer - dt
    dt = coroutine.yield()
  end

  for _, monsterGroup in pairs(spawnGroup.monsters) do
    if type(monsterGroup) == "table" then
      for i = 1, monsterGroup.count do
        -- TODO: Allow for old monster group selection
        local spawnOffset = rect.randomPoint(args.offsetRegion)
        local targetOffset = rect.randomPoint(monsterGroup.offsetRegion)

        local spawnPosition = vec2.add(mcontroller.position(), spawnOffset)
        local targetPosition = vec2.add(mcontroller.position(), targetOffset)

        world.spawnProjectile("spacemonsterspawner", spawnPosition, entity.id(), world.distance(targetPosition,
              spawnPosition), false, {
          monsterType = monsterGroup.type,
          monsterLevel = monster.level(),
          targetPosition = targetPosition,
          onGround = monsterGroup.onGround,
          instantAggro = monsterGroup.instantAggro,
          keepTargetInSight = monsterGroup.keepTargetInSight
        })

        coroutine.yield()  -- So that the spawners burst one by one
      end
    else
      local spawnOffset = rect.randomPoint(args.offsetRegion)
      local targetOffset = rect.randomPoint(args.defaultTargetOffsetRegion)

      local spawnPosition = vec2.add(mcontroller.position(), spawnOffset)
      local targetPosition = vec2.add(mcontroller.position(), targetOffset)
      

      world.spawnProjectile("spacemonsterspawner", spawnPosition, entity.id(), world.distance(targetPosition,
            spawnPosition), false, {
        monsterType = monsterGroup,
        monsterLevel = monster.level(),
        targetPosition = targetPosition,
        onGround = true,
        instantAggro = true,
        keepTargetInSight = false
      })

      coroutine.yield()  -- So that the spawners burst one by one
    end
  end

  return true
end

--[[
  Variant of the spawnMonsterGroup node that spawns Asra Nox.
  
  param biome
  param monsterType
  param windup
  param spawnOffset
  param targetOffset
]]
function ruin_spawnCultistBoss(args, board, _, dt)
  animator.setGlobalTag("biome", args.biome)

  local timer = args.windup
  while timer > 0 do
    timer = timer - dt
    dt = coroutine.yield()
  end

  local spawnPosition = vec2.add(mcontroller.position(), args.spawnOffset)
  local targetPosition = vec2.add(mcontroller.position(), args.targetOffset)

  world.spawnProjectile("spacemonsterspawner", spawnPosition, entity.id(), world.distance(targetPosition,
        spawnPosition), false, {
    monsterType = args.monsterType,
    monsterLevel = monster.level(),
    targetPosition = targetPosition,
    onGround = true
  })

  return true
end

function eyeWiggle(args, board, _, dt)
  while true do
    local timer = 0
    while timer < args.time do
      timer = timer + dt
      local ratio = (args.time - timer) / args.time
      local rotation = interp.ranges(ratio, {
        {0.25, interp.linear, 0, args.rotation},
        {0.75, interp.linear, args.rotation, -args.rotation},
        {1.0, interp.linear, -args.rotation, 0}
      })
      animator.resetTransformationGroup("eye")
      animator.rotateTransformationGroup("eye", rotation, animator.partPoint("eye", "rotationCenter"))

      dt = coroutine.yield()
    end
  end
end

function spawnLightShaft(args, board)
  local rotation = math.random() * math.pi*2
  animator.resetTransformationGroup("shaftemitter")
  animator.rotateTransformationGroup("shaftemitter", rotation)
  animator.translateTransformationGroup("shaftemitter", config.getParameter("eyeCenterOffset"))
  animator.burstParticleEmitter("shaftemitter")
  return true
end

--[[
  An attack that makes giant tentacles drill through sectors of the arena. In phase 1, one tentacle drills. In phase 2,
  the tentacle re-emerges to drill a larger sector. In phase 3, another tentacle appears on the other side. In phase 4,
  the other tentacle re-emerges in the same manner as previously described. In addition, the tentacles will complete
  their attacks faster. All time-based parameters are measured in seconds.
  param phase1 - The minimum health percentage of phase 1
  param phase2 - The minimum health percentage of phase 2
  param phase3 - The minimum health percentage of phase 3
  param tentacle1 - The unique ID of the tentacle
  param tentacle2 - The unique ID of the re-emerging component of the tentacle
  param otherTentacle1 - The unique ID of the tentacle on the other side
  param otherTentacle2 - The unique ID of the re-emerging component of the tentacle on the other side
  param windupTime - The windup time of the tentacle
  param attackTime - The attack time of the tentacle and the re-emerging segment of it
  param windupSoundPool - The windup sound pool of the tentacle
  param reEmergeWindupTime - The windup time of the re-emerging segment of the tentacle
  param reEmergeDelay - The amount of time to wait after emerging the first segment of the tentacle to activate the 
                        second segment of the tentacle
  param reEmergeWindupSoundPool - The windup sound pool of the re-emerging segment of the tentacle
  param retractDelay - The amount of time to wait after drilling before retracting the tentacle
  param otherTentacleDelay - The amount of time to wait before activating the other tentacle
]]
function ruin_tentacleAttack(args, board)

  if status.resourcePercentage("health") >= args.phase1 then
    world.sendEntityMessage(args.tentacle1, "attack")
  else
    -- -1440 = 2 * -720 (b/c it attacks for about two times longer)
    world.sendEntityMessage(args.tentacle1, "attack", args.windupTime, args.attackTime + args.reEmergeWindupTime 
        + args.reEmergeDelay, args.retractDelay, -1440, args.windupSoundPool)

    util.run(args.windupTime + args.reEmergeDelay, function() end)
    
    world.sendEntityMessage(args.tentacle2, "attack", args.reEmergeWindupTime, args.attackTime, args.retractDelay, nil,
        args.reEmergeWindupSoundPool)
    
    if status.resourcePercentage("health") < args.phase2 then
      util.run(args.otherTentacleDelay, function() end)

      if status.resourcePercentage("health") >= args.phase3 then
        world.sendEntityMessage(args.otherTentacle1, "attack")
      else
        -- -1440 = 2 * -720 (b/c it attacks for about two times longer)
        world.sendEntityMessage(args.otherTentacle1, "attack", args.windupTime, args.attackTime 
            + args.reEmergeWindupTime + args.reEmergeDelay, nil, -1440, args.windupSoundPool)

        util.run(args.windupTime + args.reEmergeDelay, function() end)
        
        world.sendEntityMessage(args.otherTentacle2, "attack", args.reEmergeWindupTime, args.attackTime,
            args.retractDelay, nil, args.reEmergeWindupSoundPool)
      end
    end
  end
  
  util.run(args.windupTime + args.attackTime * 2 + args.retractDelay)
  
  return true
end

--[[
  Makes the shield flash upon taking a weak hit (in other words damage of the element to which the Ruin is resistant).
  This node is an infinite loop.
  param shieldState - the state to which to set the shield upon taking a weak hit
]]
function ruin_elementalShieldEffect(args, board)
  local listener = damageListener("damageTaken", function(notifications)
    for _, notification in ipairs(notifications) do
      if notification.hitType == "WeakHit" then  -- WeakHit = resistant
        animator.setAnimationState("shield", args.shieldState)  -- startNew being true hurts my eyes
        animator.playSound("shieldblock")
      end
    end
  end)
  
  while true do
    listener:update()
    coroutine.yield()
  end
end

--[[
  Spawns a projectile that flies toward the center from a distance at a random angle.
  param spawnDistance - The distance from the center to spawn the projectile
  param speed - The speed of the projectile
  param center - The center toward which the projectile flies
  param projectileType - The type of projectile to spawn
  param projectileParameters - The parameters of the projectile to spawn
]]
function ruin_spawnPlasmaOrb(args, board)
  local angle = util.randomInRange({0, 2 * math.pi})
  local timeToLive = args.spawnDistance / args.speed
  local pos = vec2.add(args.center, vec2.withAngle(angle, args.spawnDistance))
  local aimVec = vec2.withAngle(angle + math.pi)  -- Point toward the center relative to spawn location
  
  local params = copy(args.projectileParameters)
  params.power = (params.power or 10) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  params.timeToLive = timeToLive
  params.speed = args.speed
  
  world.spawnProjectile(args.projectileType, pos, entity.id(), aimVec, false, params)
  
  return true
end

--[[
  Plays the Ruin's part of the Asra Nox despawn animation. The Ruin opens up a portal, notifies Asra Nox to begin her
  disappear animation, waits for Asra Nox to send a notification back, and then spawns a projectile at her place that 
  moves toward the center of the Ruin's portal. The Ruin then closes the portal at the end.
  
  param target - The entity ID of Asra Nox
  param finishedNotification - The name of the notification to receive
  param biomeTag - The global tag to use for the biome part during the portal animation
  param cultistDespawnDelay - How long to wait after opening the portal to notify Asra Nox to disappear
  param cultistDespawnNotification - The name of the notification to send to Asra Nox
  param despawnerProjectileType - The type of projectile to spawn at Asra Nox's position
  param despawnerProjectileParams - The parameters to override for the projectile to spawn at Asra Nox's position
  param portalCenter - The position of the portal's center
  param despawnerTravelDelay - The amount of time to wait before moving the projectile
  param despawnerTravelTime - The amount of time it takes for the projectile to move to the destination
]]
function ruin_retrieveCultistBoss(args, board)
  animator.setAnimationState("eye", "spawnwindup")
  animator.setGlobalTag("biome", args.biomeTag)
  
  util.run(args.cultistDespawnDelay, function() end)

  world.sendEntityMessage(args.target, "notify", {type = args.cultistDespawnNotification, sourceId = entity.id()})
  
  -- Placed here b/c Asra Nox will die before we can spawn the projectile.
  local targetPos = world.entityPosition(args.target)
  
  _ruin_awaitNotification(args.finishedNotification)
  
  local portalCloseDelay = args.despawnerTravelDelay + args.despawnerTravelTime
  
  local params = copy(args.despawnerProjectileParams)
  params.targetPosition = args.portalCenter
  params.timeToLive = portalCloseDelay
  params.travelDelay = args.despawnerTravelDelay
  params.travelTime = args.despawnerTravelTime
  
  world.spawnProjectile(args.despawnerProjectileType, targetPos, entity.id(), world.distance(targetPos,
      args.portalCenter), false, params)
  
  util.run(portalCloseDelay, function() end)
  
  animator.setAnimationState("eye", "spawnwinddown")
  
  return true
end

--[[
  Spawns tentacles along the ceiling of the arena. This node would be used to act against using the spike sphere to
  cheese certain sections of the fight.

  param arenaWidth - The width of the entire arena
  param tentacleWidth - The spacing between each projectile
  param maxSpawnHeight - The maximum height at which to spawn the projectiles relative to the center of the boss
  param projectileType - The type of projectile to spawn
  param projectileParameters - The parameters to use for the projectiles
  param tentacleInterval - The time interval between each projectile
  param tentacleDirection - The aim vector of the projectile
  param tentacleCooldown - The amount of time to wait after spawning all the tentacles.
]]
function ruin_ceilingTentacles(args, board)
  local ownPosition = mcontroller.position()
  local halfArenaWidth = args.arenaWidth / 2
  local numTentacles = math.floor(halfArenaWidth / args.tentacleWidth)
  
  local params = copy(args.projectileParameters)
  params.power = (params.power or 10) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())

  for i = 0, numTentacles do
    local leftXPos = (-halfArenaWidth + i * args.tentacleWidth) + ownPosition[1]

    local leftPos = world.lineCollision({leftXPos, ownPosition[2]}, {leftXPos, ownPosition[2] + args.maxSpawnHeight})
    if not leftPos then
      leftPos = {leftXPos, ownPosition[2] + args.maxSpawnHeight}
    end
    
    world.spawnProjectile(args.projectileType, leftPos, entity.id(), args.tentacleDirection, false, params)

    local rightXPos = halfArenaWidth - i * args.tentacleWidth + ownPosition[1]

    local rightPos = world.lineCollision({rightXPos, ownPosition[2]}, {rightXPos, ownPosition[2] +
        args.maxSpawnHeight})
    if not rightPos then
      rightPos = {rightXPos, ownPosition[2] + args.maxSpawnHeight}
    end
    
    world.spawnProjectile(args.projectileType, rightPos, entity.id(), args.tentacleDirection, false,
        params)
    
    util.run(args.tentacleInterval, function() end)
  end
  
  util.run(args.tentacleCooldown, function() end)
  
  return true
end

-- Coroutine function that waits until it receives <count> notifications of the specified type <type_> (default count is
-- 1).
-- Borrowed from the Prison's code in Voided.
function _ruin_awaitNotification(type_, count)
  count = count or 1
  local notifications = {}
  while count > 0 do
    -- Collect notifications
    local i = 1
    while i <= #self.notifications do
      local notification = self.notifications[i]
      if notification.type == type_ then
        --sb.logInfo("self.notifications = %s, i = %s", self.notifications, i)
        table.remove(self.notifications, i)
        table.insert(notifications, notification)

        count = count - 1
      else
        i = i + 1
      end
    end
    coroutine.yield()
  end

  return notifications
end