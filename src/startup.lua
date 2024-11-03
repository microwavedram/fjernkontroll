local REPO = "https://raw.githubusercontent.com/microwavedram/fjernkontroll"
local VER = "v0.0.1"
local LANG = "en_us"

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

local frame
do
    local w, h = term.getSize()
    frame = window.create(term.current(), 1, 1, w - 2, h - 2)
end

function render()
    frame.clear()
    frame.setCursorPos(1, 1)
    frame.blit(string.format("fjernkontroll %s", VER))
end

function main()
    while true do
        render()
        os.sleep(0)
    end
end

main()