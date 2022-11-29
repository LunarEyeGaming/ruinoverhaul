require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.spawners = {}
  self.spawnerConfig = config.getParameter("spawnPoints")
  self.width = config.getParameter("objectWidth")
  self.monsters = {}

  message.setHandler("triggerSpawner", function(arg1, arg2, spawnerName) triggerSpawner(spawnerName) end)
  message.setHandler("reset", reset)
end

function update(dt)
  for spawnerName, spawn in pairs(self.spawners) do
    if spawn ~= nil and coroutine.status(spawn) == "dead" then
      self.spawners[spawnerName] = nil
      animator.setAnimationState(spawnerName, "idle")
    else
      local status, result = coroutine.resume(spawn)
      if not status then error(result) end
    end
  end

  self.monsters = util.filter(self.monsters, world.entityExists)
end

function reset()
  self.spawners = {}
  for spawnerName,_ in pairs(self.spawnerConfig) do
    animator.setAnimationState(spawnerName, "idle")
  end
  for _,monsterId in pairs(self.monsters) do
    world.sendEntityMessage(monsterId, "despawn")
  end
end

function absolutePosition(offset, width) 
  if object.direction() > 0 then
    return vec2.add(entity.position(), offset)
  else
    return vec2.add(vec2.add(entity.position(), {width, 0}), {-offset[1], offset[2]})
  end
end

function triggerSpawner(spawnerName)
  local spawner = self.spawnerConfig[spawnerName]
  local position = absolutePosition(spawner.offset, self.width)
  animator.setAnimationState(spawnerName, "pulse")

  local parameters = {
    aggressive = true,
    level = world.threatLevel(),
    behaviorConfig = {
      targetQueryRange = config.getParameter("monsterQueryRange"),
      keepTargetInSight = false,
      keepTargetInRange = 200
    }
  }

  local spawnThread = coroutine.create(function()
    -- telegraph
    for i=1, 6 do
      util.wait(0.25)
      animator.burstParticleEmitter(spawnerName)
      animator.playSound("spawn")
    end

    -- spawn
    for i = 1, spawner.count or 1 do
      local monsterId = world.spawnMonster(spawner.monster, position, parameters)
      table.insert(self.monsters, monsterId)
    end
    animator.burstParticleEmitter(spawnerName)
    animator.playSound("spawn")
  end)

  self.spawners[spawnerName] = spawnThread
end
