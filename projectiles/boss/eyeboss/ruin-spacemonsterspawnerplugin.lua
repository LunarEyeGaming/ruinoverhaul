--[[
  Script plugin that adds an init() function to do nothing on destruction if the projectile was forcibly killed via an
  entity message. It also overrides the destroy() function to add more configuration options.
]]

require "/scripts/interp.lua"

local shouldSpawn

function init()
  shouldSpawn = true
  
  message.setHandler("kill", function()
    projectile.die()
    shouldSpawn = false
  end)
end

--[[
  Overridden to add the following functionality:
    * Increased aggro range is only set when instantAggro is true
    * onGround defaults to false instead of true
    * keepTargetInSight can be set to true with the keepTargetInSight configuration parameter
]]
function destroy()
  if not sourceEntityAlive() or not shouldSpawn then
    return
  end

  local monsterType = config.getParameter("monsterType")
  local damageTeam = entity.damageTeam()
  local parameters = {
    -- Might as well fix this since I'm overriding the function
    level = config.getParameter("monsterLevel", world.threatLevel()),
    aggressive = true,
    damageTeam = damageTeam.team,
    damageTeamType = damageTeam.type,
    initialStatus = "blackmonsterrelease",
    behaviorConfig = {}
  }

  if config.getParameter("instantAggro", true) then
    parameters.behaviorConfig.targetQueryRange = 150
    parameters.behaviorConfig.keepTargetInRange = 200
  end
  
  parameters.behaviorConfig.keepTargetInSight = config.getParameter("keepTargetInSight", false)

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