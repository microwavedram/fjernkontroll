local meshnet = require("meshnet")

local network = meshnet()

local deployerL = peripheral.wrap("create:deployer_5")
local deployerR = peripheral.wrap("create:deployer_6")
local shell_barrel = peripheral.wrap(meshnet.COMMON.BARREL(1))

network:device(meshnet.CUSTOM("ShellLoader"), {
	clean = function()
		deployerL.pushItems(peripheral.getName(shell_barrel), 1)
		deployerR.pushItems(peripheral.getName(shell_barrel), 1)
	end,
	push_thing = function(thing)
		print(thing)
		local function pushOne(deployer, item_id)
			for slot = 1, shell_barrel.size(), 1 do
				local item = shell_barrel.getItemDetail(slot)
				if item then
					if item.name == item_id then
						deployer.pullItems(peripheral.getName(shell_barrel), slot, 1)
						return
					end
				end
			end
		end

		pushOne(deployerL, thing)
		pushOne(deployerR, thing)
	end,
})

network:allocate("ShellLoader", meshnet.CUSTOM("ShellLoader"))

local Reloader = {}
Reloader.__index = Reloader

function Reloader.new()
	local self = setmetatable({}, Reloader)

	self.cannon = assert(meshnet:wrap("Cannon"), "Could not find cannon")
	self.breach_unlocker = assert(meshnet:wrap("BreachUnlock"), "Could not find breach unlock")
	self.breach_pivot = assert(meshnet:wrap("BreachPivot"), "Could not find breach pivot")
	self.shell_loader = assert(meshnet:wrap("ShellLoader"), "Could not find shell loader")
	self.shell_pivot = assert(meshnet:wrap("ShellPivot"), "Could not find shell pivot")
	self.slide = assert(meshnet:wrap("Slide"), "Could not find slide")

	self.shell_loader.clean()

	self.breach_unlocker.unlock_breach(false)
	os.sleep(0.1)
	self.cannon.build(true)

	return self
end

function Reloader:shuffle_load(type)
	self.shell_loader.push_thing(type)
	os.sleep(0.1)

	parallel.waitForAll(function()
		self.slide.move(1, -1)
	end, function()
		os.sleep(0.2)
		self.shell_pivot.rotate(90, 1)
	end)
	os.sleep(0.25)
	parallel.waitForAll(function()
		self.slide.move(1, 1)
	end, function()
		os.sleep(0.2)
		self.shell_pivot.rotate(90, -1)
	end)
end

function Reloader:reload()
	print("Reloading!!")
	self.cannon.build(false)
	os.sleep(0.2)
	self.breach_unlocker.unlock_breach(true)
	os.sleep(0.5)
	self.breach_pivot.rotate(23, 1)
	os.sleep(0.1)
	self.slide.move(3, 1)
	for i = 1, 9, 1 do
		if i == 1 then
			self:shuffle_load("createbigcannons:solid_shot")
		else
			self:shuffle_load("createbigcannons:powder_charge")
		end
	end
	os.sleep(0.25)
	self.slide.move(3, -1)
	os.sleep(0.1)
	self.breach_pivot.rotate(23, -1)
	os.sleep(0.5)
	self.breach_unlocker.unlock_breach(false)
	os.sleep(0.2)
	self.cannon.build(true)
end

network:start()
parallel.waitForAll(function()
	network:loop()
end, function()
	Reloader.new():reload()
end)
