require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

-- The tentacleMovement node has been overridden to make the Ruin's tentacles move more organically, utilizing rotations
-- and scales in lieu of pure vertical translations. It also applies sine easing to the transformations. The tentacles
-- move independently of each other.
-- param timeRange - The range of time to complete each movement of each tentacle
-- param angleRange - The range of angles to use for each tentacle
-- param scaleRange - The range of scaling to use for each tentacle
-- param tentaclePivots - The relative positions to use for rotation and scaling for each tentacle
function tentacleMovement(args, board, _, dt)
  local angleRange = util.map(args.angleRange, function(x) return util.toRadians(x) end)  -- Convert angles to radians.

  -- Times to complete movements
  local times = util.rep(function() return util.randomInRange(args.timeRange) end, args.tentacleCount)

  local timers = util.rep(function() return 0 end, args.tentacleCount)  -- Timers to track movement progress
  
  local oldAngles = util.rep(function() return 0 end, args.tentacleCount)  -- Angles from previous movement
  local angles = util.rep(function() return util.randomInRange(angleRange) end, 6)  -- Target angles

  local oldScales = util.rep(function() return 1 end, args.tentacleCount)  -- Scales from previous movement
  local scales = util.rep(function() return util.randomInRange(args.scaleRange) end, 6)  -- Target scales
  
  while true do
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
      
      animator.resetTransformationGroup("tentacle"..i)
      animator.scaleTransformationGroup(
        "tentacle"..i,
        {1, util.easeInOutSin(timers[i] / times[i], oldScales[i], scales[i] - oldScales[i])},
        args.tentaclePivots[i]
      )
      animator.rotateTransformationGroup(
        "tentacle"..i,
        util.easeInOutSin(timers[i] / times[i], oldAngles[i], angles[i] - oldAngles[i]),
        args.tentaclePivots[i]
      )
    end
    
    dt = coroutine.yield()
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

      world.spawnProjectile("spacemonsterspawner", spawnPosition, entity.id(), world.distance(targetPosition, spawnPosition), false, {
        monsterType = monsterGroup.type,
        monsterLevel = monster.level(),
        targetPosition = targetPosition,
        onGround = monsterGroup.onGround
      })
      coroutine.yield()
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