local process = require "rating_limit.process";
local api_process = require "rating_limit.api_process";
local incr_process = require "rating_limit.incr_process";
local conf = require "rating_limit.conf";
local utils = require "rating_limit.utils";
local shared_client = ngx.shared.cache;

local function close_redis(redis_client)
    if not redis_client then
        return
    end
    --释放连接
    local pool_max_idle_time = 10000 --毫秒
    local pool_size = 3 --连接池大小
    local ok, err = redis_client:set_keepalive(pool_max_idle_time, pool_size)

    if not ok then
        ngx.log(ngx_ERR, "set redis keepalive error : ", err)
    end
end

local config=conf.init_conf()
local cjson = require "cjson"
local redis = require("resty.redis");

local appId=config.appId
local redis_client = redis:new()
local redis_host = config.redis_host
local redis_port = config.redis_port
local redis_pass = config.redis_pass
local redis_db = config.redis_db
local host_ip = config.host_ip
redis_client:set_timeout(config.redis_timeout)
local ok, err = redis_client:connect(redis_host,redis_port)


if redis_pass ~= '' then
   redis_client:auth(redis_pass)
end

ngx.header.content_type = "text/html";

if not ok then
     ngx.log(ngx.ERR, "connect redis error : ",err)
     ngx.header.content_type = "application/xml";
     return err
end

redis_client:select(redis_db)

local server_name  = ngx.var.server_name  
local conf_key = appId..":"..server_name
local conf_value,conf_err = redis_client:get(conf_key)

if type(conf_value) == "string" then 
    
   local set_global_config_ok, set_global_config_err  = shared_client:set(conf_key,conf_value,120*60)
   if not set_global_config_ok then
      ngx.log(ngx.ERR, "设置全局配置异常: ", set_global_config_err)
      return set_global_config_err
   end

   local confJson = cjson.decode(conf_value)

   for k,rule in ipairs(confJson.Rules) do 

      ngx.header.content_type = "text/html";
      local start_time_number=rule.StartTimeNumber
      local end_time_number=rule.EndTimeNumber
      local now_time_number=tonumber(os.time())

      if now_time_number>start_time_number and now_time_number<end_time_number then

         -- 全站限流
	 if rule.LimitType == 0 then
           
            -- ip限流
	    if rule.RuleType == 0 then

	        local ip = ngx.var.remote_addr
                local is_white_ip = utils.ValidateWhitelist(rule,ip)
		if is_white_ip == true then
                   return ''
		end

                local black_result=process.limitProcessed(appId,redis_client,rule,server_name,ip)
	        if black_result==true then
	           return ''
	        end

                process.limitRequest(appId,redis_client,rule,server_name,ip)

	     end

             -- 全局限流
	     if rule.RuleType == 1 then 

                local black_result=process.limitProcessed(appId,redis_client,rule,server_name,'')
	        if black_result==true then
	           return ''
	        end
                process.limitRequest(appId,redis_client,rule,server_name,'')

	     end
	  end

	 -- 接口限流
	 if rule.LimitType ==1 then

             local api_address=ngx.var.uri

	     -- ip限流
             if rule.RuleType == 0 then
	   
	        local ip = ngx.var.remote_addr
                local is_white_ip = utils.ValidateWhitelist(rule,ip)
		if is_white_ip == true then
                   return ''
		end

                local black_result=api_process.limitApiProcessed(appId,redis_client,rule,server_name,api_address,ip)
	        if black_result==true then
	           return ''
	        end

	        api_process.limitApiRequest(appId,redis_client,rule,server_name,api_address,ip)

	     end

             -- 全局限流
             if rule.RuleType == 1 then 

                local black_result=api_process.limitApiProcessed(appId,redis_client,rule,server_name,api_address,'')
	        if black_result==true then
	           return ''
	        end

	        api_process.limitApiRequest(appId,redis_client,rule,server_name,api_address,'')

	    end

	 end

         -- 总并发量限流
	 if rule.LimitType == 2 then
            incr_process.limitRequest(appId,rule,server_name,host_ip,redis_client)
	 end

      end

   end 

end
close_redis(redis_client)
