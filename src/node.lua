-- controller
local CHANNEL = 12742

local BINDING = {
    left_track = "Create_RotationSpeedController_0",
    right_track = "Create_RotationSpeedController_1",
    suspension_forward = "Create_SequencedGearshift_0"
}

local MODIFIER = {
    left_track = -1,
    right_track = -1,
}

local modem = assert(peripheral.find("modem"), "no modem")
modem.open(CHANNEL)

local bound_devices = {}
for _,port in pairs(BINDING) do
    bound_devices[port] = peripheral.wrap(port)
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
                            local speed_controller = bound_devices[BINDING[motor]]
    
                            if speed_controller then
                                speed_controller.setTargetSpeed(speed * (MODIFIER[motor] or 1))
                            else
                                print("Unknown speed controller: "..tostring(motor))
                            end
                        end
                        for gearshift_id, instruction in pairs(parsed.rotations) do
                            local gearshift = bound_devices[BINDING[gearshift_id]]
    
                            if gearshift then
                                local d = instruction * (MODIFIER[gearshift] or 1)

                                if d > 0 then
                                    gearshift.rotate(math.abs(d), 1)
                                else
                                    gearshift.rotate(math.abs(d), -1)
                                end
                            else
                                print("Unknown sequenced gearshift: "..tostring(gearshift))
                            end
                        end
                    end
                else
                    print("unkown packet id ".. parsed.id)
                end
            else
                print("Parse Failed")
            end
        end
    end
end