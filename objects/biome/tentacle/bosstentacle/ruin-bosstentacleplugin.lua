--[[
  This script makes some changes to the original bosstentacle.lua script. Specifically, it adds a few parameters,
  adds the attackParameterized() function, adds the "attack_var" message handler, and adds a "reset" message handler. It
  also adds a few parameters.
]]

local oldInit = init
local oldSetRotation = setRotation

local retractDelay
local windupTime
local windupSoundPool
local resetAngularVelocity

local currentAngle

local margs

function init()
  oldInit()

  -- Add a few configuration parameters
  retractDelay = config.getParameter("retractDelay")
  windupTime = config.getParameter("windupTime", 4.0)
  windupSoundPool = config.getParameter("windupSoundPool")
  resetAngularVelocity = util.toRadians(config.getParameter("resetAngularVelocity", 720))

  -- New variables
  currentAngle = 0
  margs = {}
  
  -- New handler for a parameterized variant of the "attack" function.
  message.setHandler("attackParameterized", function(_, _, windupTimeParam, attackTimeParam, retractDelayParam,
    attackRotationParam, windupSoundPoolParam)
    windupTimeParam = windupTimeParam or windupTime
    attackTimeParam = attackTimeParam or self.attackTime
    retractDelayParam = retractDelayParam or retractDelay
    attackRotationParam = (attackRotationParam and util.toRadians(attackRotationParam)) or self.attackRotation
    windupSoundPoolParam = windupSoundPoolParam or windupSoundPool
    
    self.state:set(attackParameterized, windupTimeParam, attackTimeParam, retractDelayParam, attackRotationParam,
        windupSoundPoolParam)
  end)
  
  message.setHandler("reset", function()
    self.state:set(reset)
  end)
end

--[[
  An extension of the setRotation() function that sets the currentAngle variable.
]]
function setRotation(angle)
  currentAngle = angle
  oldSetRotation(angle)
end

--[[
  Variant of the attack() function that accepts parameters.
  windupTimeParam: The amount of time to wait before making the tentacle emerge.
  attackTime
]]
function attackParameterized(windupTimeParam, attackTimeParam, retractDelayParam, attackRotationParam,
    windupSoundPoolParam)
  animator.setSoundPool("windupstartParam", windupSoundPoolParam)
  animator.setParticleEmitterActive("windup", true)
  animator.playSound("windupstartParam")
  animator.playSound("winduploop", -1)

  util.wait(windupTimeParam)

  animator.stopAllSounds("winduploop")
  animator.playSound("movestart")
  animator.playSound("moveloop", -1)

  local timer = 0
  util.wait(attackTimeParam, function(dt)
    timer = math.min(timer + dt, attackTimeParam)
    local angle = interp.sin(timer / attackTimeParam, 0, attackRotationParam)
    setRotation(angle)
  end)
  animator.setParticleEmitterActive("floordebris", false)
  animator.setParticleEmitterActive("windup", false)

  animator.stopAllSounds("moveloop")

  util.wait(retractDelayParam)

  animator.playSound("movestart")
  animator.playSound("moveloop", -1)
  
  animator.setParticleEmitterActive("windup", true)
  timer = 0
  util.wait(attackTimeParam, function(dt)
    timer = math.min(timer + dt, attackTimeParam)
    local angle = interp.reverse(interp.sin)(timer / attackTimeParam, 0, attackRotationParam)
    setRotation(angle)
  end)

  setRotation(0)
  animator.setParticleEmitterActive("windup", false)
  animator.stopAllSounds("moveloop")
  util.wait(1.0)

  self.state:set(idle)
end

function reset()
  animator.stopAllSounds("windupstart")
  animator.stopAllSounds("windupstartParam")
  animator.stopAllSounds("winduploop")
  animator.stopAllSounds("movestart")
  animator.stopAllSounds("moveloop")

  local resetDuration = math.abs(currentAngle / resetAngularVelocity)
  local initialAngle = currentAngle

  if resetDuration > 0 then
    animator.playSound("movestart")
    animator.playSound("moveloop", -1)
    animator.setParticleEmitterActive("windup", true)

    local timer = 0
    util.wait(resetDuration, function(dt)
      timer = math.min(timer + dt, resetDuration)
      local angle = interp.reverse(interp.linear)(timer / resetDuration, 0, initialAngle)
      setRotation(angle)
    end)
  end

  setRotation(0)
  animator.setParticleEmitterActive("windup", false)
  animator.stopAllSounds("moveloop")
  
  self.state:set(idle)
end