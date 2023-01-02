require "/scripts/interp.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

--[[
  Script that causes the projectile to smoothly move to the given position within a specified timespan. This can be a
  standalone script or one that extends an existing script.
]]

local oldInit = init
local oldUpdate = update

local travelTime
local travelTimer

local initialPosition
local targetPosition

function init()
  if oldInit then
    oldInit()
  end

  travelTime = config.getParameter("travelTime")
  travelTimer = travelTime

  initialPosition = mcontroller.position()
  targetPosition = config.getParameter("targetPosition")
end

function update(dt)
  if oldUpdate then
    oldUpdate(dt)
  end

  if not targetPosition then
    return
  end

  travelTimer = math.max(0, travelTimer - dt)
  local ratio = 1 - (travelTimer / travelTime)

  mcontroller.setPosition(
    {
      interp.sin(ratio, initialPosition[1], targetPosition[1]),
      interp.sin(ratio, initialPosition[2], targetPosition[2])
    }
  )
end
