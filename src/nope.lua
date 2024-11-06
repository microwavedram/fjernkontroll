for _, v in pairs(peripheral.getNames()) do
    if peripheral.getType(v) == "Create_RotationSpeedController" then
        peripheral.wrap(v).setTargetSpeed(0)
    end
end