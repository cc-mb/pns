local Client = require "pns.client"

local args = {...}
if #args ~= 1 then
  error("expected 1 argument, got " .. #args)
end

local modems = peripheral.find("modem")
if #modems < 1 then
  error("No modem found.")
end

for _, modem in pairs(modems) do
  rednet.open(peripheral.getName(modem))
  break
end

local client = Client.new{}
local response = client:look_up(args[1])
write(response)

rednet.close()
