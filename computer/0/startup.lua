local REPO = "https://raw.githubusercontent.com/microwavedram/fjernkontroll"
local VER = "v0.0.1"
local LANG = "no-NO"

local CHANNEL = 12742

local GEARS = {
    0,
    8,
    16,
    32,
    96,
    128,
    256
}

local modem = assert(peripheral.find("modem"), "no modem")
local lang = (function ()
    local path = LANG .. ".json"
    if fs.exists(path) then
        local file = fs.open(path, "r")

        local language = textutils.unserialiseJSON(file.readAll())

        file.close()

        return language
    else
        print("Fetching language file")
        local response = http.get(REPO .. "/refs/heads/main/src/lang/" .. path)

        local success, result = pcall(function()
            local data = response.readAll()
            
            local decoded = textutils.unserialiseJSON(data)

            local file = fs.open(path, "w")
            file.write(data)
            file.close()

            return decoded
        end)
        
        if success then
            return result
        end

        error("Failed to fetch language file " .. path)
    end
end)()

local lerper = {}
lerper.__index = lerper

function lerper.new(initial, alpha)
    local self = setmetatable({}, lerper)

    self.at = initial
    self.target = initial
    self.alpha = alpha

    return self
end

function lerper:update()
    self.at = self.at + (self.target - self.at) * self.alpha    
end

local frame
do
    local w, h = term.getSize()
    frame = window.create(term.current(), 2, 2, w - 1, h - 1)
end

local held = {}
local k_events = {}
local debounce = {}

local send_cache = {}

local controllers = {}

local vertical = lerper.new(0, 0.05)
local horizontal = lerper.new(0, 0.05)

local gear = 1
local target_rpm = 0

local l_track_throttle = 0
local r_track_throttle = 0

local function gen(c, i)
    local o = ""

    for _ = 1,i,1 do
        o = o..c
    end

    return o
end

local function blit(frame, text, fg, bg)
    frame.blit(text, gen(fg, #text), gen(bg, #text))
end

local function toGear(id)
    gear = id
    target_rpm = GEARS[id]
end

local function gearExists(id)
    return GEARS[id] ~= nil
end

local function reset()
    held = {}
    debounce = {}
    vertical.at = 0
    horizontal.at = 0
end

local function key_down(key, h)
    if keys.getName(key) == "x" then
        reset()
    end

    if h then return end

    if keys.getName(key) == "e" then
        if gearExists(gear + 1) then
            toGear(gear + 1)
        end
    end
    if keys.getName(key) == "q" then
        if gearExists(gear - 1) then
            toGear(gear - 1)
        end
    end
    if keys.getName(key) == "i" or keys.getName(key) == "o"  then
        if keys.getName(key) == "i" then
            frame.setCursorPos(1, 13)
            frame.write("i")
            send_cache["suspension_forward"] = 360
        elseif keys.getName(key) == "o" then
            frame.setCursorPos(1, 13)
            frame.write("o")
            send_cache["suspension_forward"] = -360
        end
    end

    if held[keys.getName(key)] then return end
    if (debounce[keys.getName(key)] or 0) > os.clock() then return end
    debounce[keys.getName(key)] = os.clock() + 0.1

    k_events[#k_events+1] = {keys.getName(key), true}
end

local function key_up(key)
    k_events[#k_events+1] = {keys.getName(key), false}
end

local function noblock_loop()
    local w, h = frame.getSize()
    frame.clear()

    local n_held = {}

    for key, v in pairs(held) do
        if v then
            n_held[key] = true
        end
    end

    for _, event in pairs(k_events) do
        if event[2] == true then
            if n_held[event[1]] == nil then
                n_held[event[1]] = true
            end
        elseif event[2] == false then
            n_held[event[1]] = false
        end
    end
    
    k_events = {}

    for code, v in pairs(n_held) do
        held[code] = v
    end


    local v_net = 0
    local h_net = 0
    if held["w"] then
        v_net = v_net + 1
    end
    if held["s"] then
        v_net = v_net - 1
    end
    if held["d"] then
        h_net = h_net + 1
    end
    if held["a"] then
        h_net = h_net - 1
    end

    vertical.target = v_net
    horizontal.target = h_net

    vertical:update()
    horizontal:update()

    local n_x = math.abs(horizontal.at)
    local n_y = math.abs(vertical.at)

    local g_left = math.max(n_x, n_y)
    local g_right = n_y - n_x

    if horizontal.at < 0 then
        g_left, g_right = g_right, g_left
    end

    if vertical.at < 0 then
        g_left = -g_left
        g_right = -g_right
    end

    l_track_throttle = g_left * target_rpm
    r_track_throttle = g_right * target_rpm

    for controllerid, controller in pairs(controllers) do
        if #controller > 0 then
            local speeds, rotations = {}, {}
            for _,motor in pairs(controller) do
                if motor == "left_track" then
                    speeds[motor] = l_track_throttle
                elseif motor == "right_track" then
                    speeds[motor] = r_track_throttle
                elseif motor == "suspension_forward" then
                    if send_cache[motor] then
                        rotations[motor] = send_cache[motor]
                        send_cache[motor] = nil
                    end
                end 
            end

            modem.transmit(CHANNEL, CHANNEL, textutils.serialiseJSON({
                id = "SET",
                controller = controllerid,
                speeds = speeds,
                rotations = rotations
            }))
        end
    end

    

    frame.setCursorPos(1, 1)
    frame.write(string.format("%s %s", lang["fjernkontroll.name"], VER))
    
    frame.setCursorPos(1, 3)
    frame.write(string.format("%s %.0f%%", lang["fjernkontroll.vertical"], vertical.at * 100))
    frame.setCursorPos(1, 4)
    frame.write(string.format("%s %.0f%%", lang["fjernkontroll.horizontal"], horizontal.at * 100))
    frame.setCursorPos(1, 6)
    frame.write(string.format("%s %.0frpm", lang["fjernkontroll.left_track"], l_track_throttle))
    frame.setCursorPos(1, 7)
    frame.write(string.format("%s %.0frpm", lang["fjernkontroll.right_track"], r_track_throttle))
    frame.setCursorPos(1, 9)
    frame.write(string.format("%s %s", lang["fjernkontroll.gear"], lang["fjernkontroll.gear."..gear]))
    frame.setCursorPos(1, 11)
    frame.write(textutils.serialiseJSON(send_cache))
end

local function main()
    print("Finding Motor Nodes")
    modem.open(CHANNEL)
    modem.transmit(CHANNEL, CHANNEL, textutils.serialiseJSON({ id = "FIND" }))

    parallel.waitForAny(function()
        while true do
            local _, _, channel, _, message, _ = os.pullEvent("modem_message")

            if channel == CHANNEL then
                local success, parsed = pcall(textutils.unserialiseJSON, message)

                if parsed.id == "ADVERTISE" then
                    if success then
                        local controller_id = parsed.controller

                        if controller_id and parsed.motors then
                            print("Found Controller "..controller_id)

                            controllers[controller_id] = parsed.motors
                            
                            for _, motor in pairs(parsed.motors) do
                                print(" - "..motor)
                            end
                        end
                    end
                end
            end
        end
    end, function ()
        os.sleep(2)
    end)

    term.clear()

    parallel.waitForAll(function()
        while true do
            noblock_loop()
            os.sleep(0)
        end
    end,
    function ()
        while true do
            local event, key, h = os.pullEvent()

            if event == "key" then
                key_down(key , h)
            elseif event == "key_up" then
                key_up(key)
            end
        end
    end)
end

main()
