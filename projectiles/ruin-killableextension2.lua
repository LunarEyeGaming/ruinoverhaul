--[[
  Script for performing actions after expiring only if they were not forcibly killed. This script exists because there
  are no existing action lists (e.g. actionOnReap, actionOnTimeout) that differentiate between expiring and being killed 
  via entity message. This script also exists so that one can easily add this functionality to a scripted projectile.
  Note: Some actions are not properly networked in the processAction function (bug in vanilla). The workaround is to
  spawn a projectile whose sole purpose is to process the desired actions.
]]

local oldInit = init  -- The old init() function. Called in the new init() to extend rather than override the old init()
local oldDestroy = destroy  -- Used to extend the old destroy() function

local hasExpired  -- True by default, set to false if forcibly killed via entity message.
local actionOnExpire  -- The action to use on expiring naturally. Leave undefined to have no action.

--[[
  Loads the actionOnExpire parameter and initializes a variable and message handler in addition to doing what the
  previous init() function did.
]]
function init()
  if oldInit then
    oldInit()
  end

  actionOnExpire = config.getParameter("actionOnExpire")
  hasExpired = true
  
  message.setHandler("kill", function()
    hasExpired = false
    projectile.die()
  end)
end

--[[
  Processes the actionOnExpire action if it has expired naturally (in other words has not been killed by an entity 
  message).
]]
function destroy()
  if oldDestroy then
    oldDestroy()
  end
  if hasExpired and actionOnExpire then
    projectile.processAction(actionOnExpire)
  end
end
