local PORT = 199
local LAG_CORRECT = 0
local ERROR_LENGTH = 60

local V_FIX = math.rad(75) / (32 / 60 * math.pi * 2)

local pid = require("pid")
local modem = assert(peripheral.find("modem"), "no modem")

local yawMotor = peripheral.wrap("Create_RotationSpeedController_12")
local pitchMotor = peripheral.wrap("Create_RotationSpeedController_13")

modem.open(PORT)

yawMotor.setTargetSpeed(0)
pitchMotor.setTargetSpeed(0)

local target_look = { 1, 0, 1 }
local error_queue = {}

local yaw_pid = pid:new({
	kp = 500,
	ki = 0.1,
	kd = 800,
	target = 0,

	minout = -256 * 4,
	maxout = 256 * 4,
})

local pitch_pid = pid:new({
	kp = 150,
	ki = 0,
	kd = 200,
	target = 0,

	minout = -256,
	maxout = 256,
})

local atMatrix = {
	{ 1, 0, 0, 0 },
	{ 0, 1, 0, 0 },
	{ 0, 0, 1, 0 },
	{ 0, 0, 0, 1 },
}

local function calculate_yaw_pitch(vector)
	local yaw = -math.atan2(vector[1], vector[3])
	local pitch = math.atan2(-vector[2], math.sqrt(vector[1] * vector[1] + vector[3] * vector[3]))
	return yaw, pitch
end

local function get_forward_vector(rotation_matrix)
	return { rotation_matrix[1][3], rotation_matrix[2][3], rotation_matrix[3][3] }
end

local function wrapAngle(a)
	if a > math.pi then
		return a - math.pi * 2
	elseif a < -math.pi then
		return a + math.pi * 2
	end

	return a
end

local function compute_errors(look_vector, rotation_matrix)
	local forward_vector = get_forward_vector(rotation_matrix)

	local look_yaw, look_pitch = calculate_yaw_pitch(look_vector)
	local forward_yaw, forward_pitch = calculate_yaw_pitch(forward_vector)

	local yaw_error = look_yaw - forward_yaw
	local pitch_error = look_pitch - forward_pitch

	return wrapAngle(yaw_error), wrapAngle(pitch_error)
end

local function update()
	local yaw_error, pitch_error = compute_errors(target_look, atMatrix)

	local yawErrorDegrees = math.deg(yaw_error)
	local pitchErrorDegrees = math.deg(pitch_error)

	term.clear()
	term.setCursorPos(1, 1)

	local avg = 0
	for _, v in pairs(error_queue) do
		avg = avg + v
	end
	avg = avg / math.max(1, #error_queue)

	if #error_queue > ERROR_LENGTH then
		table.remove(error_queue, 1)
	end
	error_queue[#error_queue + 1] = yaw_error

	print("")
	print("Yaw Error (degrees):", yawErrorDegrees)
	print("Pitch Error (degrees):", pitchErrorDegrees)
	print("Avg Err (degrees):", math.deg(avg))

	-- yaw_error = yaw_error + avg * LAG_CORRECT
	yaw_error = LAG_CORRECT * avg
		+ yaw_error
		+ V_FIX * (ship or {
			getOmega = function()
				return { y = 0 }
			end,
		}).getOmega().y

	yaw_pid.input = yaw_error
	yaw_pid:compute()

	pitch_pid.input = pitch_error
	pitch_pid:compute()

	print("Target", textutils.serialiseJSON(target_look))
	print("Yaw Pid:", yaw_pid.output)
	print("Pitch Pid:", pitch_pid.output)

	yawMotor.setTargetSpeed((yaw_pid.output or 0))
	pitchMotor.setTargetSpeed((pitch_pid.output or 0))
end

parallel.waitForAll(function()
	while true do
		local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

		if channel == replyChannel then
			atMatrix = message
		end
	end
end, function()
	while true do
		update()
		os.sleep(0)
	end
end, function()
	while true do
		--     target_look[1] = math.random(-100, 100) / 100
		--     target_look[2] = math.random(-50, 50) / 100
		--     target_look[3] = math.random(-100, 100) / 100

		target_look[1] = -target_look[1]
		-- target_look[2] = -target_look[2]
		os.sleep(10)
		print("switch")
	end
end)
