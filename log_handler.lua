local conf = require "rating_limit.conf";
local cjson = require "cjson"
local shared_client = ngx.shared.cache;

--配置加载
local config=conf.init_conf()
local appId=config.appId
local redis_host = config.redis_host
local redis_port = config.redis_port
local redis_pass = config.redis_pass
local redis_db = config.redis_db

local server_name  = ngx.var.server_name  
local conf_key = appId..":"..server_name
local conf_value,conf_err = shared_client:get(conf_key)

if not conf_value then
   return ''
end

if type(conf_value) == "string" then 
    
   local conf_json = cjson.decode(conf_value)

   for k,rule in ipairs(conf_json.Rules) do 
    
      -- 全站限流
      if rule.LimitType == 2 then

         local limit_key=appId..":"..server_name..":"..rule.RuleId
         local res, err = shared_client:incr(limit_key,-1)

	 ngx.log(ngx.INFO, "now_key:"..limit_key.."minus_one_value:",res)

         if not res and err == "not found" then	    
            shared_client:set(limit_key,0,10*60)  
            return ''
         end 

	 if tonumber(res) < 0 then
            shared_client:set(limit_key,0,10*60)
	 end

      end
   end 
end