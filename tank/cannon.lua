local meshnet = require("meshnet")

local network = meshnet()

network:device(meshnet.CUSTOM("Cannon"), {
	build = function(v)
		redstone.setOutput("right", v)
	end,
	fire = function(v)
		redstone.setOutput("left", v)
	end,
	fire_autocannon = function(v)
		redstone.setOutput("back", v)
	end,
})

network:allocate("Cannon", meshnet.CUSTOM("Cannon"))
network:allocate("BreachPivot", meshnet.COMMON.GEARSHIFT(13))
network:allocate("Slide", meshnet.COMMON.GEARSHIFT(12))
network:allocate("ShellPivot", meshnet.COMMON.GEARSHIFT(14))

network:start()
parallel.waitForAll(function()
	network:loop()
end)
