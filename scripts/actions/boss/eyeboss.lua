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
      animator.scaleTransformationGroup(
        "tentacle"..i,
        {1, scale},
        args.tentaclePivots[i]
      )
      animator.rotateTransformationGroup(
        "tentacle"..i,
        angle,
        args.tentaclePivots[i]
      )
      
      table.insert(intermediateScales, scale)
      table.insert(intermediateAngles, angle)
    end
    
    dt = coroutine.yield(nil, {scales = intermediateScales,
                               angles = util.map(intermediateAngles, function(angle) return util.toDegrees(angle) end)})
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
  end

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

-- param center
-- param areaWidth
-- param segmentWidth
-- param projectileCount
-- param power
-- param projectileCount
-- param spawnHeight
-- param teleDuration
-- param postTeleDelay
-- output projectiles
function ruin_spawnFloorProjectiles(args, board)
  local power = args.power * root.evalFunction("monsterLevelPowerMultiplier", monster.level())

  local segmentCount = math.floor(args.areaWidth / args.segmentWidth)
  local segments = {}
  for i = 1, args.projectileCount do
    table.insert(segments, true)
  end
  for i = 1, segmentCount - args.projectileCount do
    table.insert(segments, false)
  end
  shuffle(segments)

  -- Randomize positions
  local spawnPositions = {}
  local start = vec2.add(args.center, {-args.areaWidth / 2, 0})
  local groundLevel = world.collisionBlocksAlongLine(args.center, vec2.add(args.center, {0, -50}))[1][2] + 1.0
  for i, spawnProjectile in ipairs(segments) do
    if spawnProjectile then
      local spawnPosition = vec2.add(start, {i * args.segmentWidth - (args.segmentWidth / 2), 0})
      spawnPosition[2] = groundLevel + args.spawnHeight
      
      table.insert(spawnPositions, spawnPosition)
    end
  end
  shuffle(spawnPositions)

  -- Spawn the projectiles
  local ttl = args.teleDuration + args.postTeleDelay
  local interval = args.teleDuration / args.projectileCount
  local projectiles = {}
  for _, spawnPosition in ipairs(spawnPositions) do
    local params = {
      power = power,
      timeToLive = ttl
    }
    local projectileId = world.spawnProjectile(args.projectileType, spawnPosition, entity.id(), {0, 0}, false, params)
    table.insert(projectiles, projectileId)
    ttl = ttl - interval
    util.run(interval, function() end)
  end

  return true, {projectiles = projectiles}
end

-- An attack that makes giant tentacles drill through sectors of the arena. In phase 1, one tentacle drills. In phase 2,
-- the tentacle re-emerges to drill a larger sector. In phase 3, another tentacle appears on the other side. In phase 4,
-- the other tentacle re-emerges in the same manner as previously described. In addition, the tentacles will complete
-- their attacks faster. All time-based parameters are measured in seconds.
-- param phase1 - The minimum health percentage of phase 1
-- param phase2 - The minimum health percentage of phase 2
-- param phase3 - The minimum health percentage of phase 3
-- param tentacle1 - The unique ID of the tentacle
-- param tentacle2 - The unique ID of the re-emerging component of the tentacle
-- param otherTentacle1 - The unique ID of the tentacle on the other side
-- param otherTentacle2 - The unique ID of the re-emerging component of the tentacle on the other side
-- param windupTime - The windup time of the tentacle
-- param attackTime - The attack time of the tentacle and the re-emerging segment of it
-- param windupSoundPool - The windup sound pool of the tentacle
-- param reEmergeWindupTime - The windup time of the re-emerging segment of the tentacle
-- param reEmergeDelay - The amount of time to wait after emerging the first segment of the tentacle to activate the 
--                       second segment of the tentacle
-- param reEmergeWindupSoundPool - The windup sound pool of the re-emerging segment of the tentacle
-- param retractDelay - The amount of time to wait after drilling before retracting the tentacle
-- param otherTentacleDelay - The amount of time to wait before activating the other tentacle
function ruin_tentacleAttack(args, board)
  -- TODO: Make this not hardcoded
  -- local windupTime = 4.0
  -- local attackTime = 3.0
  -- local windupSoundPool = {"/sfx/npc/boss/tentacleboss_tentacle_windup.ogg"}
  
  -- local reEmergeWindupTime = 2.0
  -- local reEmergeDelay = 0.75
  -- local reEmergeWindupSoundPool = {"/sfx/npc/boss/ruin-tentacleboss_tentacle_windup2.ogg"}
  -- local retractDelay = 1.0

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