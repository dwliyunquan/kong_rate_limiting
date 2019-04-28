
local _M = {}

function _M.init_conf()

  local config                = {
    host_ip                   = "192.168.5.212",
    appId                     = "IS00009",
    redis_host                = "192.168.5.2",
    redis_port                = 6379,
    redis_pass                = "",
    redis_db                  = 10,
    redis_timeout             = 1000
  }

  return config
end

return _M