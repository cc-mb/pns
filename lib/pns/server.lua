local PrefixedLogger = require "mb.log.prefixed_logger"
local VOID_LOGGER = require "mb.log.void_logger"

--- PNS server.
---@class Server
---@field DATABASE string PNS database file.
---@field HOSTNAME string PNS hostname.
---@field PROTOCOL string PNS protocol.
---@field TIMEOUT number PNS timeout to keep the server responsive to termination. [s]
---@field private _database table PNS runtime database.
---@field private _log Logger Logger.
---@field private _terminate boolean If set, the server should terminate.
local Server = {
  DATABASE = "/etc/pns.db",
  HOSTNAME = "pns",
  PROTOCOL = "pns",
  TIMEOUT = 5,
  RC_OK = 0,
  RC_REDNET_FAILURE = -1
}
Server.__index = Server


--- Server creation parameters.
---@class ServerParams
---@field log Logger? Logger.
local ServerParams = {}

--- Constructor
---@param params ServerParams?
function Server.new(params)
  local self = setmetatable({}, Server)

  params = params or {}

  if params.log then
    self._log = PrefixedLogger.new(params.log, "[pns]")
  else
    self._log = VOID_LOGGER
  end

  self._log:trace("Creating PNS server.")

  self._database = {}
  self:load()

  return self
end

--- Add new PNS entry.
--- This change is not persistent if save is not called.
function Server:add_entry(symbolic_name, real_name)
  self._log:info(("Adding PNS entry [\"%s\"] -> \"%s\"."):format(symbolic_name, real_name))
  self._database[symbolic_name] = real_name
end

--- Remove PNS entry.
--- This change is not persistent if save is not called.
function Server:remove_entry(symbolic_name)
  self._log:info(("Removing PNS entry [\"%s\"] -> \"%s\"."):format(symbolic_name, self._database[symbolic_name]))
  self._database[symbolic_name] = nil
end

--- Look up PNS entry.
function Server:look_up(symbolic_name)
  local real_name = self._database[symbolic_name]
  self._log:trace(("Looking up PNS entry [\"%s\"] -> \"%s\"."):format(symbolic_name, real_name))
  return self._database[symbolic_name]
end

--- Save PNS database to make it persistent.
function Server:save()
  self._log:info("Saving PNS database.")
  fs.makeDir("/etc")
  if not fs.exists("/etc") then
    self._log:error(("File %s cannot be created."):format(Server.DATABASE))
    return
  end

  local f = fs.open(Server.DATABASE, "w")
  if not f then
    self._log:error(("File %s cannot be written."):format(Server.DATABASE))
    return
  end

  f.write(textutils.serialise(self._database))
  f.close()
  self._log:debug("PNS database saved.")
end

--- Load PNS database overriding the current one.
function Server:load()
  self._log:info("Loading PNS database.")
  local f = fs.open(Server.DATABASE, "r")
  if not f then
    self._log:warning(("File %s cannot be read."):format(Server.DATABASE))
    return
  end

  self._database = textutils.unserialise(f.readAll())
  f.close()
  self._log:debug("PNS database loaded.")
end

--- Run PNS server. Blocking call.
function Server:run()
  self._log:info("Starting PNS server.")
  if not rednet.isOpen() then
    self._log:error("Rednet is not open.")
    return Server.RC_REDNET_FAILURE
  end

  self._log:debug(("Hosting %s protocol with %s hostname."):format(Server.PROTOCOL, Server.HOSTNAME))
  rednet.host(Server.PROTOCOL, Server.HOSTNAME)

  self._terminate = false
  while not self._terminate do
    self._log:trace(("Tick @ %f."):format(os.clock()))
    local id, message = rednet.receive(Server.PROTOCOL, Server.TIMEOUT)
    if id then
      self._log:debug(("Received request from #%d for \"%s\"."):format(id, message))
      local response = self:look_up(message) or ""
      self._log:debug(("Responding with \"%s\"."):format(response))
      rednet.send(id, response, Server.PROTOCOL)
    end
  end

  self._log:debug(("Unhosting %s protocol."):format(Server.PROTOCOL))
  rednet.unhost(Server.PROTOCOL)

  self._log:info("PNS server stopped.")

  return Server.RC_OK
end

--- Stop PNS server.
function Server:stop()
  self._log:debug("Termination requested.")
  self._terminate = true
end

return Server