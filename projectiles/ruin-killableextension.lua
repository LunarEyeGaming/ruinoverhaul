--[[
  Variant of vanilla's killable.lua script that extends the old init() function instead of overridding it. This script
  can be loaded with other scripts (assuming that later scripts extend init() also).
]]

local oldInit = init

function init()
  if oldInit then
    oldInit()
  end
  message.setHandler("kill", projectile.die)
end
