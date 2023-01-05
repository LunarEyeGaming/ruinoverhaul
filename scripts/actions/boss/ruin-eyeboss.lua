require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/status.lua"
--[[
  A node that makes the Ruin's tentacles move more organically, utilizing rotations and scales in lieu of pure vertical
  translations. It also applies sine easing to the transformations. The tentacles move independently of each other.
  param initialScales - The initial scales to use for the tentacles
  param initialAngles - The initial angles to use for the tentacles in degrees
  param timeRange - The range of time to complete each movement of each tentacle
  param angleRange - The range of angles to use for each tentacle in degrees
  param scaleRange - The range of scaling to use for each tentacle
  param tentaclePivots - The relative positions to use for rotation and scaling for each tentacle
  output scales - A list of the scales used for each tentacle as of the current tick. Use in conjunction with the
     initialScales parameter to prevent sudden changes in movement between calls of this function (e.g. when changing 
     phases).
  output angles - A list of the angles used for each tentacle as of the current tick (in degrees). Use in conjunction
     with the initialAngles parameter for the aforementioned reason.
]]
function ruin_tentacleMovement(args, board, _, dt)
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

  -- Target angles
  local angles = util.rep(function() return util.randomInRange(angleRange) end, args.tentacleCount)

  -- Scales from previous movement
  local oldScales = args.initialScales or util.rep(function() return 1 end, args.tentacleCount)
  -- Target scales
  local scales = util.rep(function() return util.randomInRange(args.scaleRange) end, args.tentacleCount)
  
  while true do
    local intermediateScales = {}
    local intermediateAngles = {}
  
    for i = 1, args.tentacleCount do
      if timers[i] >= times[i] then
        -- Reset timers; randomize times, angles and scales; and save old angles and scales.
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

--[[
  A variant of the spawnMonsterGroup node that allows for a more controlled method of spawning monsters.
  param offsetRegion - The area relative to the boss to spawn the projectiles
  param defaultTargetOffsetRegion - The offset region to which the projectiles will move as a failsafe for a monster
      group being a string
  param windup - The amount of time to wait before spawning the monsters
]]
function ruin_spawnMonsterGroup(args, board, _, dt)
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
    world.sendEntityMessage(args.tentacle1, "attackParameterized", args.windupTime, args.attackTime 
        + args.reEmergeWindupTime + args.reEmergeDelay, args.retractDelay, -1440, args.windupSoundPool)

    util.run(args.windupTime + args.reEmergeDelay, function() end)
    
    world.sendEntityMessage(args.tentacle2, "attackParameterized", args.reEmergeWindupTime, args.attackTime,
        args.retractDelay, nil, args.reEmergeWindupSoundPool)
    
    if status.resourcePercentage("health") < args.phase2 then
      util.run(args.otherTentacleDelay, function() end)

      if status.resourcePercentage("health") >= args.phase3 then
        world.sendEntityMessage(args.otherTentacle1, "attack")
      else
        -- -1440 = 2 * -720 (b/c it attacks for about two times longer)
        world.sendEntityMessage(args.otherTentacle1, "attackParameterized", args.windupTime, args.attackTime 
            + args.reEmergeWindupTime + args.reEmergeDelay, nil, -1440, args.windupSoundPool)

        util.run(args.windupTime + args.reEmergeDelay, function() end)
        
        world.sendEntityMessage(args.otherTentacle2, "attackParameterized", args.reEmergeWindupTime, args.attackTime,
            args.retractDelay, nil, args.reEmergeWindupSoundPool)
      end
    end
  end
  
  util.run(args.windupTime + args.attackTime * 2 + args.retractDelay)
  
  return true
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
  Spawns tentacles along the ceiling of the arena. This node would be used to act against using the spike sphere to
  cheese certain sections of the fight.

  param center - The center of the arena; the position to which to aim the tentacles
  param arenaWidth - The width of the entire arena
  param tentacleWidth - The spacing between each projectile
  param maxSpawnHeight - The maximum height at which to spawn the projectiles relative to the center
  param projectileType - The type of projectile to spawn
  param projectileParameters - The parameters to use for the projectiles
  param tentacleInterval - The time interval between each projectile
  param tentacleCooldown - The amount of time to wait after spawning all the tentacles.
]]
function ruin_ceilingTentacles(args, board)
  local ownPosition = mcontroller.position()
  local halfArenaWidth = args.arenaWidth / 2
  local numTentacles = math.floor(halfArenaWidth / args.tentacleWidth)
  
  local params = copy(args.projectileParameters)
  params.power = (params.power or 10) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())

  for i = 0, numTentacles do
    local leftXPos = (-halfArenaWidth + i * args.tentacleWidth) + args.center[1]

    local leftPos = world.lineCollision({leftXPos, args.center[2]}, {leftXPos, args.center[2] + args.maxSpawnHeight})
    if not leftPos then
      leftPos = {leftXPos, args.center[2] + args.maxSpawnHeight}
    end
    
    local aimVectorLeft = world.distance(ownPosition, leftPos)
    
    world.spawnProjectile(args.projectileType, leftPos, entity.id(), aimVectorLeft, false, params)

    local rightXPos = halfArenaWidth - i * args.tentacleWidth + args.center[1]

    local rightPos = world.lineCollision({rightXPos, args.center[2]}, {rightXPos, args.center[2] +
        args.maxSpawnHeight})
    if not rightPos then
      rightPos = {rightXPos, args.center[2] + args.maxSpawnHeight}
    end
    
    local aimVectorRight = world.distance(ownPosition, rightPos)
    
    world.spawnProjectile(args.projectileType, rightPos, entity.id(), aimVectorRight, false,
        params)
    
    util.run(args.tentacleInterval, function() end)
  end
  
  util.run(args.tentacleCooldown, function() end)
  
  return true
end

--[[
  Rotates a transformation group at a constant rate.
  
  param transformationGroup - The name of the transformation group to rotate
  param rotateRate - How many full rotations the portal image completes in one second
  param rotationCenter - The rotation pivot to use
]]
function ruin_rotatePortalImage(args, board, _, dt)
  local angularVelocity = args.rotateRate * 2 * math.pi
  local timer = 0
  
  while true do
    animator.resetTransformationGroup(args.transformationGroup)
    animator.rotateTransformationGroup(args.transformationGroup, angularVelocity * timer, args.rotationCenter)
    timer = timer + dt
    coroutine.yield()
  end
end