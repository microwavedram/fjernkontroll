local VER = "v0.0.1"
local LANG = "en_us"

local modem = assert(peripheral.find("modem"), "no modem")
local lang = (function ()
    local path = LANG + ".json"
    if fs.exists(path) then
        local file = fs.open(path, "r")

        local language = textutils.unserialiseJSON(file.readAll())

        file.close()

        return language
    else

    end
end)()

local frame
do
    local w, h = term.getSize()
    frame = window.create(term.current(), 1, 1, w - 2, h - 2)
end

function render()
    term.clear()
    term.setCursorPos(1, 1)
    term.blit(string.format("fjernkontroll %s", VER))
end

while true do
    render()
end