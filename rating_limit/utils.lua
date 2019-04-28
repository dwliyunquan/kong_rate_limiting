local cjson = require "cjson"

local _M = {}

function _M.ValidateWhitelist(rule,ip)
    local is_white_ip=false
    for k,white_ip in ipairs(rule.Whites) do     
        if white_ip == ip then 
	   is_white_ip = true
	   break 
	end
    end

    return is_white_ip
end

return _M