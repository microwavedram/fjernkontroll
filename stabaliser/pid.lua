local pid = {}

local function clamp(x, min, max)
  if x > max then
    return max
  elseif x < min then
    return min
  else
    return x
  end
end

local seconds = os.clock

-- all values of the PID controller
-- values with '_' at beginning are considered private and should not be changed.
pid = {
  kp = 1,
  ki = 1,
  kd = 1,
  input = nil,
  target = nil,
  output = nil,
  
  minout = -math.huge,
  maxout = math.huge,
  
  _lasttime = nil,
  _lastinput = nil,
  _Iterm = 0
}

function pid:new(save)
  assert(save == nil or type(save) == "table", "If save is specified the it has to be table.")
  
  save = save or {}
  setmetatable(save, self)
  self.__index = self
  return save
end

-- Exports calibration variables and targeted value.
function pid:save()
  return {kp = self.kp, ki = self.ki, kd = self.kd, target = self.target, minout = self.minout, maxout = self.maxout}
end

function pid:compute(waspaused)
  assert(self.input and self.target, "You have to sepecify current input and target before running compute()")
  
  -- reset values if PID was paused for prolonegd period of time
  if waspaused or self._lasttime == nil or self._lastinput == nil then
    self._lasttime = seconds()
    self._lastinput = self.input
    self._Iterm = self.output or 0
    return
  end
  
  local err = self.target - self.input
  local dtime = seconds() - self._lasttime
  
  if dtime == 0 then
    return
  end

  self._Iterm = self._Iterm + self.ki * err * dtime
  self._Iterm = clamp(self._Iterm, self.minout, self.maxout)
  
  local dinput = (self.input - self._lastinput) / dtime
  
  self.output = self.kp * err + self._Iterm - self.kd * dinput
  self.output = clamp(self.output, self.minout, self.maxout)
  
  self._lasttime = seconds()
  self._lastinput = self.input
end

return pid
