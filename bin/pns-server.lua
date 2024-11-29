local Server = require "pns.server"
local DEFAULT_LOGGER = require "mb.log.default_logger"

local strings = require "cc.strings"

-- start rednet
peripheral.find("modem", rednet.open)

local server = Server.new{
  log = DEFAULT_LOGGER
}

local function main_loop()
  local terminate = false
  local commands = {
    ["add"] = function (symbolic_name, real_name) server:add_entry(symbolic_name, real_name) end,
    ["remove"] = function (symbolic_name) server:remove_entry(symbolic_name) end,
    ["get"] = function (symbolic_name) write(server:look_up(symbolic_name)) end,
    ["save"] = function () server:save() end,
    ["load"] = function () server:load() end,
    ["stop"] = function () server:stop(); terminate = true end
  }

  while not terminate do
    write("pns> ")
    local cmd = read()
    local tokens = strings.split(cmd, " ")

    local command = commands[tokens[1]]
    if command then
      local expected_args = debug.getinfo(command).nparams
      local got_args = #tokens - 1
      if expected_args == got_args then
        command(table.unpack(tokens, 2))
      else
        DEFAULT_LOGGER:warning(("`%s` expects %d arguments, got %d."):format(tokens[1], expected_args, got_args))
      end
    else
      DEFAULT_LOGGER:warning(("Unknown command `%s`."):format(tokens[1]))
    end
  end
end

parallel.waitForAll(main_loop, function () server:run() end)

rednet.close()
