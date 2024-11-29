local modem = assert(peripheral.find("modem"), "no modem")

local PORT = 199

function draw()
	term.clear()

	local m = ship.getRotationMatrix()

	for i = 1, 4, 1 do
		for j = 1, 4, 1 do
			term.setCursorPos((j - 1) * 8 + 1, i)
			term.write(string.format("%.2f", m[i][j]))
		end
	end

	modem.transmit(PORT, PORT, m)
end

while true do
	draw()
	os.sleep(0)
end
