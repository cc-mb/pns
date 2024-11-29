
--- PNS client
---@class Client
---@field PROTOCOL string PNS protocol.
---@field TIMEOUT number PNS timeout. [s]
---@field private _server number Server ID.
local Client = {
  PROTOCOL = "pns",
  HOSTNAME = "pns",
  TIMEOUT = 5
}
Client.__index = Client

--- Client creation parameters.
---@class ClientCreationParams

--- Constructor.
---@param params ClientCreationParams
function Client.new(params)
  local self = setmetatable({}, Client)

  if not rednet.isOpen() then
    error("Rednet is not open.", 2)
  end

  self._server = rednet.lookup(Client.PROTOCOL, Client.HOSTNAME)
  if not self._server then
    error(("Server [protocol: %s, hostname: %s] doesn't exist."):format(Client.PROTOCOL, Client.HOSTNAME))
  end

  return self
end

--- Look up PNS name.
---@param symbolic_name string Symbolic name to look up.
---@return string real_name Real name found.
function Client:look_up(symbolic_name)
  if (not rednet.isOpen()) or (not self._server) then
    error("Server not connected.", 2)
  end

  rednet.send(self._server, symbolic_name, Client.PROTOCOL)
  local id, response = rednet.receive(Client.PROTOCOL, Client.TIMEOUT)
  if not id then
    error("Timed out.")
  elseif id ~= self._server then
    error("Malicious response.")
  end

  return response
end

return Client