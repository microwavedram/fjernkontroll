local meshnet = require("meshnet")
local network = meshnet()

local monitor = peripheral.find("monitor")
local keyboard = peripheral.find("tm_keyboard")

local PASSWORD = "purple"

keyboard.setFireNativeEvents(true)

local mapping = {}
local lockdown = false
local input = ""

local cooldown = {}

if fs.exists(".mapping") then
    local fh = fs.open(".mapping", "r")
    mapping = textutils.unserialiseJSON(fh.readAll())
end

term.setCursorPos(1, 1)
term.clear()
term.write("Door Management...")
local index = 2
for _, side in pairs(peripheral.getNames()) do
    if peripheral.getType(side) == "redstone_relay" then
        term.setCursorPos(1, index)
        term.write(("%s -> %s"):format(side, mapping[side]))
        index = index + 1
        if mapping[side] == nil then
            term.setCursorPos(1, index)
            term.write("PROVIDE ID > ")
            mapping[side] = read()
            index = index + 1
        end
    end
    os.sleep(0.05)
end

if fs.exists(".mapping") then
    fs.delete(".mapping")
end
local fh = fs.open(".mapping", "w")
fh.write(textutils.serialiseJSON(mapping))

function makeReverseIndex(tbl)
    local reverse = {}
    for key, value in pairs(tbl) do
        reverse[value] = key
    end
    return reverse
end

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

    monitor.blit(text .. gen(" ", length - #text), gen(textColor, length), gen(background, length))

    return length
end

local function isOpen(name)
    local s, p = pcall(peripheral.wrap, makeReverseIndex(mapping)[name])

    if s and p then
        return p.getOutput("top")
    end
end

local function setOpen(name, v)
    local s, p = pcall(peripheral.wrap, makeReverseIndex(mapping)[name])

    if s and p then
        p.setOutput("top", v)
    end
end

local function shitFuck()
    lockdown = true
    for id, name in pairs(mapping) do
        setOpen(name, false)

        local p = peripheral.wrap(id)

        if p then
            p.setOutput("front", false)
        end
    end
end

local function safe()
    lockdown = false
    for id, name in pairs(mapping) do
        local p = peripheral.wrap(id)

        if p then
            p.setOutput("front", false)
        end
    end
end

local function textEntered(text)
    if text:lower() == "shit" or text:lower() == "fuck" then
        shitFuck()
        return
    end

    if text == PASSWORD and lockdown then
        safe()
        return
    end

    if makeReverseIndex(mapping)[text] ~= nil and not lockdown then
        setOpen(text, not isOpen(text)) 
    end
end

local function render()
    monitor.clear()

    if redstone.getInput("top") and not lockdown then
        shitFuck()
    end

    for id, name in pairs(mapping) do
        local p = peripheral.wrap(id)

        if p then
            if p.getInput("back") and (cooldown[id] == nil or cooldown[id] < os.clock()) then
                setOpen(name, not isOpen(name))
                cooldown[id] = os.clock() + 1
            end
        end
    end

    local function renderMapping(name, x, y)
        monitor.setCursorPos(x, y)
        local l = line(name:sub(1, 6), "0", "8", 8)
        monitor.setCursorPos(x + l, y)

        local state = isOpen(name)

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
    for side, name in pairs(mapping) do
        renderMapping(name, 1, ind + 1)

        ind = ind + 1
    end

    monitor.setCursorPos(3, ind + 2)
    monitor.setCursorBlink(true)
    if lockdown then
        monitor.write("> "..gen("*", #input))
    else
        monitor.write("> "..input)
    end
    monitor.setCursorBlink(false)
end

network:device(meshnet.CUSTOM("DoorController"), {
	setDoorState = function(name, v)
		setOpen(name, v)
	end,
    getDoorState = function(name)
		return isOpen(name)
	end,
    toggleDoorState = function(name)
		setOpen(name, not isOpen(name))
	end,
    getAllDoors = function()
		local t = {}

        for _, name in pairs(mapping) do
            t[name] = isOpen(name)
        end

        return t
	end,
    lockdown = function ()
        shitFuck()
        return lockdown
    end,
    unlockdown = function (t)
        if t == PASSWORD then
            safe()
            return lockdown
        end
    end,
    getLockdown = function()
        return lockdown
    end
})

network:allocate("DoorController", meshnet.CUSTOM("DoorController"))

network:start()
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
        elseif event[1] == "monitor_touch" then
            if event[2] == peripheral.getName(monitor) then
                if event[3] >= 1 and event[3] <= 14 then
                    local i = 2
                    for _, v in pairs(mapping) do
                        if i == event[4] and not lockdown then
                            setOpen(v, not isOpen(v))
                            break
                        end
                        i = i + 1
                    end
                end
            end
        end
    end
end, function ()
    network:loop()
end)