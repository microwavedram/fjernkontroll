local modem = assert(peripheral.find("modem"), "has modem")

local tank = peripheral.find("create:creative_fluid_tank")
local engines = {}

for _,name in pairs(peripheral.getNames()) do
    if peripheral.getType(name) == "createdieselgenerators:huge_diesel_engine_block_entity" then
        engines[#engines + 1] = name
    end
end


while true do
    for _, engine in pairs(engines) do
        print(engine)
        peripheral.wrap(engine).pullFluid(peripheral.getName(tank))
    end        
    os.sleep(0)
end
