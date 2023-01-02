require "/scripts/vec2.lua"

--[[
  Performs two corrections to the targetPos to prevent Asra Nox from getting stuck in a wall during a dash attack.
  param fromPos
  param toPos
  output position
]]
function ruin_correctPosition(args, board)
  if not args.fromPos then
    sb.logInfo("Argument fromPos not defined")
    return false
  end
  
  if not args.toPos then
    sb.logInfo("Argument targetPos not defined")
    return false
  end
  
  local position = args.toPos
  position = world.lineCollision(args.fromPos, position) or position

  -- Worst-case scenario, we end up having to correct the poly by a distance equivalent to that of the farthest point
  -- from the center. Using the distance from the center to a corner of the bound box as the maximum correction
  -- (hopefully) guarantees that collision resolution succeeds.
  local boundBox = mcontroller.boundBox()
  local maxCorrection = vec2.mag({boundBox[1], boundBox[2]})  -- Distance from center to a corner of the bound box
  position = world.resolvePolyCollision(mcontroller.collisionPoly(), position, maxCorrection)
  
  return true, {position = position}
end

function ruin_spawnBeamProjectiles(args, board)
  for i = 1, args.projectileCount do
    local params = copy(args.projectileParameters)
    params.power = (params.power or 10) * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
    params.targetPosition = vec2.add(args.center, {i * args.gapWidth * args.direction, 0})
    world.spawnProjectile(args.projectileType, args.center, entity.id(), {args.direction, 0}, false, params)

    util.run(args.projectileInterval, function() end)
  end
  
  return true
end