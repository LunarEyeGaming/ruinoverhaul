require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

local shouldSpawn

function init()
  self.travelTime = config.getParameter("travelTime")
  self.travelTimer = self.travelTime

  self.initialPosition = mcontroller.position()
  self.targetPosition = config.getParameter("targetPosition")
  shouldSpawn = true
  
  message.setHandler("kill", function()
    projectile.die()
    shouldSpawn = false
  end)
end

function sourceEntityAlive()
  return world.entityExists(projectile.sourceEntity()) and world.entityHealth(projectile.sourceEntity())[1] > 0
end

function update(dt)
  if not sourceEntityAlive() then
    projectile.die()
    return
  end
  
  if self.travelTimer > 0 then
    self.travelTimer = math.max(0, self.travelTimer - dt)
    local ratio = 1 - (self.travelTimer / self.travelTime)

    mcontroller.setPosition(
      {
        interp.sin(ratio, self.initialPosition[1], self.targetPosition[1]),
        interp.sin(ratio, self.initialPosition[2], self.targetPosition[2])
      }
    )
  end
end

function destroy()
  if not sourceEntityAlive() or not shouldSpawn then
    return
  end

  local monsterType = config.getParameter("monsterType")
  local damageTeam = entity.damageTeam()
  local parameters = {
    level = config.getParameter("monsterLevel", 1),
    aggressive = true,
    level = world.threatLevel(),
    damageTeam = damageTeam.team,
    damageTeamType = damageTeam.type,
    initialStatus = "blackmonsterrelease",
    behaviorConfig = {
      targetQueryRange = 150,
      keepTargetInSight = false,
      keepTargetInRange = 200
    }
  }
  parameters = sb.jsonMerge(parameters, config.getParameter("monsterParameters", {}))
  local entityId = world.spawnMonster(monsterType, mcontroller.position(), parameters)
  world.callScriptedEntity(entityId, "status.addEphemeralEffect", "blackmonsterrelease")
  local position = mcontroller.position()
  if config.getParameter("onGround", false) then
    position = world.callScriptedEntity(entityId, "findGroundPosition", position, -10, 10, false)
  end
  if position then
    mcontroller.setPosition(position)
    world.callScriptedEntity(entityId, "mcontroller.setPosition", position)
  end

  world.sendEntityMessage(projectile.sourceEntity(), "notify", {
    type = "monsterSpawned",
    targetId = entityId  
  })
end
