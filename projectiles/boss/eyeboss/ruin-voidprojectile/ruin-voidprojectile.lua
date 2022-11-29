require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.travelTime = config.getParameter("travelTime")
  self.travelTimer = self.travelTime

  self.initialPosition = mcontroller.position()
  self.targetPosition = config.getParameter("targetPosition")
end

function update(dt)
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
