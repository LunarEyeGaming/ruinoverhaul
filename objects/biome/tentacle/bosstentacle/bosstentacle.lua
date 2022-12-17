require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/interp.lua"

function init()
  -- Ew yucky self references.
  self.rotationOffset = util.toRadians(config.getParameter("rotationOffset"))
  self.partAngles = config.getParameter("partAngles")
  self.attackRotation = util.toRadians(config.getParameter("attackRotation"))
  self.attackTime = config.getParameter("attackTime")
  self.windupTime = config.getParameter("windupTime", 4.0)
  self.retractDelay = config.getParameter("retractDelay")
  self.windupSoundPool = config.getParameter("windupSoundPool")
  
  self.resetAngularVelocity = util.toRadians(config.getParameter("resetAngularVelocity", 720))

  self.floorDebrisAngle = util.toRadians(config.getParameter("floorDebrisAngle"))
  self.damageAngle = util.toRadians(config.getParameter("damageAngle"))
  
  self.damageSource = config.getParameter("damageConfig")
  self.damageSource.damage = self.damageSource.damage * root.evalFunction("monsterLevelPowerMultiplier", world.threatLevel())
  self.damageSource.knockback = vec2.mul(self.damageSource.knockback, {object.direction(), 1})
  self.damageSource.sourceEntityId = entity.id()
  
  self.partAngles = config.getParameter("partAngles")
  for partName, partAngle in pairs(self.partAngles) do
    self.partAngles[partName] = util.toRadians(partAngle)
  end

  self.state = FSM:new()
  self.state:set(idle)
  
  self.currentAngle = 0

  message.setHandler("attack", function(_, _, windupTime, attackTime, retractDelay, attackRotation, windupSoundPool)
    margs = {
      windupTime = windupTime or self.windupTime,
      attackTime = attackTime or self.attackTime,
      retractDelay = retractDelay or self.retractDelay,
      attackRotation = (attackRotation and util.toRadians(attackRotation)) or self.attackRotation,
      windupSoundPool = windupSoundPool or self.windupSoundPool
    }
    self.state:set(attack)
  end)
  
  message.setHandler("reset", function()
    self.state:set(reset)
  end)
  
  margs = {}
end

function setRotation(angle)
  self.currentAngle = angle
  animator.resetTransformationGroup("tentacle")
  animator.rotateTransformationGroup("tentacle", self.rotationOffset + angle)

  for partName,partAngle in pairs(self.partAngles) do
    if math.abs(angle) >= partAngle then
      animator.setAnimationState(partName, "visible")
    else
      animator.setAnimationState(partName, "invisible")
    end
  end

  if math.abs(angle) > self.floorDebrisAngle then
    animator.setParticleEmitterActive("floordebris", true)
  else
    animator.setParticleEmitterActive("floordebris", false)
  end

  if math.abs(angle) > self.damageAngle then
    object.setDamageSources({self.damageSource})
  else
    object.setDamageSources(nil)
  end
end

function update(dt)
  self.state:update()
end

function idle()
  while true do
    coroutine.yield()
  end
end

function attack()
  animator.setSoundPool("windupstart", margs.windupSoundPool)
  animator.setParticleEmitterActive("windup", true)
  animator.playSound("windupstart")
  animator.playSound("winduploop", -1)

  util.wait(margs.windupTime)

  animator.stopAllSounds("winduploop")
  animator.playSound("movestart")
  animator.playSound("moveloop", -1)

  local timer = 0
  util.wait(margs.attackTime, function(dt)
    timer = math.min(timer + dt, margs.attackTime)
    local angle = interp.sin(timer / margs.attackTime, 0, margs.attackRotation)
    setRotation(angle)
  end)
  animator.setParticleEmitterActive("floordebris", false)
  animator.setParticleEmitterActive("windup", false)

  animator.stopAllSounds("moveloop")

  util.wait(margs.retractDelay)

  animator.playSound("movestart")
  animator.playSound("moveloop", -1)
  
  animator.setParticleEmitterActive("windup", true)
  timer = 0
  util.wait(margs.attackTime, function(dt)
    timer = math.min(timer + dt, margs.attackTime)
    local angle = interp.reverse(interp.sin)(timer / margs.attackTime, 0, margs.attackRotation)
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
  animator.stopAllSounds("winduploop")
  animator.stopAllSounds("movestart")
  animator.stopAllSounds("moveloop")

  local resetDuration = math.abs(self.currentAngle / self.resetAngularVelocity)
  local initialAngle = self.currentAngle

  if resetDuration > 0 then
    animator.playSound("movestart")
    animator.playSound("moveloop", -1)
    animator.setParticleEmitterActive("windup", true)

    local timer = 0
    util.wait(resetDuration, function(dt)
      timer = math.min(timer + dt, resetDuration)
      local angle = interp.reverse(interp.linear)(timer / resetDuration, 0, initialAngle)
      -- sb.logInfo("timer: %s, resetDuration: %s, angle: %s, initialAngle: %s", timer, resetDuration, angle, initialAngle)
      setRotation(angle)
    end)
  end

  setRotation(0)
  animator.setParticleEmitterActive("windup", false)
  animator.stopAllSounds("moveloop")
  
  self.state:set(idle)
end
