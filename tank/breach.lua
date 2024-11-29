local meshnet = require("meshnet")

local network = meshnet()

network:device(meshnet.CUSTOM("BreachUnlock"), {
	unlock_breach = function(v)
		redstone.setOutput("right", v)
	end,
})

network:allocate("BreachUnlock", meshnet.CUSTOM("BreachUnlock"))

network:start()
parallel.waitForAll(function()
	network:loop()
end)
