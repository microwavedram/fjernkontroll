local meshnet = require("meshnet")
local network = meshnet()

network:start()
local DoorController = assert(meshnet:wrap("DoorController"), "Could not find door controller")

local lockdown = false
local input = ""

local allstate = {}

local function gen(c, x)
    if x <= 0 then
        return ""
    end

    local s = ""
    for i = 1,x,1 do
        s = s..c
    end
    return s
end

local function line(text, textColor, background, length)
    local length = math.max(#text, length)

    term.blit(text .. gen(" ", length - #text), gen(textColor, length), gen(background, length))

    return length
end


local function shitFuck()
    DoorController.lockdown()
    lockdown = DoorController.getLockdown()
end

local function safe(tx)
    DoorController.unlockdown(tx)
    lockdown = DoorController.getLockdown()
end

local function textEntered(text)
    if text:lower() == "shit" or text:lower() == "fuck" then
        shitFuck()
        return
    end

    if lockdown then
        safe(text)
    end

    DoorController.toggleDoorState(text)
end

local function render()
    term.clear()

    local function renderMapping(name, x, y, state)
        term.setCursorPos(x, y)
        local l = line(name:sub(1, 6), "0", "8", 8)
        term.setCursorPos(x + l, y)

        if lockdown and state ~= nil then
            if math.floor(os.clock() * 2) % 2 == 0 then
                line("LOCKED", "0", "e", 6) 
            else
                line("LOCKED", "f", "e", 6) 
            end
        elseif state == true then
            line("OPEN", "0", "5", 6)
        elseif state == false then
            line("CLOSED", "0", "e", 6)
        else
            line("ERROR", "0", "1", 6)
        end
    end

    local ind = 1
    for name, state in pairs(allstate) do
        renderMapping(name, 1, ind + 1, state)

        ind = ind + 1
    end



    term.setCursorPos(3, ind + 2)
    term.setCursorBlink(true)
    if lockdown then
        term.write("> "..gen("*", #input))
    else
        term.write("> "..input)
    end
    term.setCursorBlink(false)

    allstate = DoorController.getAllDoors()
    lockdown = DoorController.getLockdown()
end

parallel.waitForAll(function ()
    while true do
        render()
        os.sleep()
    end
end, function ()
    while true do
        local event = {os.pullEvent()}

        if event[1] == "char" then
            input = input .. event[2]
        elseif event[1] == "key" then
            if event[2] == keys.enter then
                textEntered(input)
                input = ""
            elseif event[2] == keys.backspace then
                input = input:sub(1, #input - 1)
            end
        end
    end
end, function ()
    network:loop()
end)