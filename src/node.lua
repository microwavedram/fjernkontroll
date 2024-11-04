-- controller
local CHANNEL = 12742

local BINDING = {
    left_track = "Create_RotationSpeedController_0",
    right_track = "Create_RotationSpeedController_1",
}

local MODIFIER = {
    left_track = -1,
    right_track = -1,
}

local modem = assert(peripheral.find("modem"), "no modem")
modem.open(CHANNEL)

local speed_controllers = {}
for _,port in pairs(BINDING) do
    speed_controllers[port] = peripheral.wrap(port)
end

local function keys(t)
    local kt = {}
    for k,_ in pairs(t) do
        kt[#kt+1] = k
    end
    return kt
end

while true do
    local event, _, channel, _, message, _ = os.pullEvent()

    if event == "modem_message" then
        if channel == CHANNEL then
            local success, parsed = pcall(textutils.unserialiseJSON, message)
    
            if success then
                if parsed.id == "FIND" then
                    print("Advertisement recieved")
                    modem.transmit(CHANNEL, CHANNEL, textutils.serialiseJSON({
                        id = "ADVERTISE",
                        controller = os.getComputerID(),
                        motors = keys(BINDING)
                    }))
                elseif parsed.id == "SET" then
                    if parsed.controller == os.getComputerID() then
                        for motor, speed in pairs(parsed.speeds) do
                            local speed_controller = speed_controllers[BINDING[motor]]
    
                            if speed_controller then
                                speed_controller.setTargetSpeed(speed * MODIFIER[motor])
                            else
                                print("Unknown speed controller: "..tostring(motor))
                            end
                        end
                    end
                end
            end
        end
    end
end