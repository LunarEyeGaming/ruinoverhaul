--[[
  A script designed to extend the bossrightspawner's script to do nothing if the minion cap is reached.
]]

local oldInit = init
local oldUpdate = update

local minionCap

function init()
  oldInit()
  
  minionCap = config.getParameter("minionCap")
end

function update(dt)
  if #self.monsters <= minionCap then
    -- Yes, this filters the monsters twice, but that doesn't have any effect other than very slightly 
    -- reducing efficiency.
    oldUpdate(dt)
  end

  self.monsters = util.filter(self.monsters, world.entityExists)
end

function enableSpawner(spawnerName)
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

  local spawnFn = coroutine.wrap(function()
    local timer = math.random() * spawner.interval
    while true do
      timer = timer + script.updateDt()
      if timer >= spawner.interval then
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

        -- reset
        timer = timer - spawner.interval
      end
      coroutine.yield()
    end
  end)

  self.spawners[spawnerName] = spawnFn
end