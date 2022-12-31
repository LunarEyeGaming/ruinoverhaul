function init()
  -- TODO: Remove self references
  self.colorFadeDuration = config.getParameter("colorFadeDuration")
  self.alphaFadeDuration = config.getParameter("alphaFadeDuration")
  self.fadeMax = config.getParameter("fadeMax")
  self.elapsed = 0
  mcontroller.setVelocity({0, 0})
  animator.burstParticleEmitter("disappear")
  animator.playSound("disappear")
end

function update(dt)
  self.elapsed = self.elapsed + dt
  if self.elapsed < self.colorFadeDuration then
    local fade = (self.elapsed / self.colorFadeDuration) * self.fadeMax
    effect.setParentDirectives(string.format("fade=000000=%.1f", fade))
  else
    local alphaElapsed = self.elapsed - self.colorFadeDuration
    local alpha = math.max(math.floor((1 - alphaElapsed / self.alphaFadeDuration) * 255), 0)
    effect.setParentDirectives(string.format("?multiply=ffffff%02x?fade=000000=%.1f", alpha, self.fadeMax))
    mcontroller.controlModifiers({
        facingSuppressed = true,
        movementSuppressed = true
      })
  end

  if self.elapsed > self.alphaFadeDuration + self.colorFadeDuration then
    status.setResource("health", 0)
  end
end

function uninit()
end
