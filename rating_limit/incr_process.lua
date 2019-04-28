local shared_client = ngx.shared.cache;
local host =ngx.var.hostname
local _M = {}

-- 总并发限流
function _M.limitRequest(appId,rule,server_name,host_ip,redis_client)

   if rule.TotalRequest>0 then

      local limit_key=appId..":"..server_name..":"..rule.RuleId
      local total_key=appId..":"..server_name..":"..rule.RuleId..":total:"..host
      local total_key_pattern=appId..":"..server_name..":"..rule.RuleId..":total*"

      local res, err = shared_client:incr(limit_key,1)
      if not res and err == "not found" then
         shared_client:set(limit_key,0,10*60)    
	 res, err = shared_client:incr(limit_key,1)
      end
      
      local res_number = tonumber(res)
      
      local total_res,total_err=redis_client:set(total_key,res_number)

      local total_keys_res,total_keys_err = redis_client:keys(total_key_pattern)
      if not total_keys_res then
         return 
      end

      local summary_number=0;
      for key, value in pairs(total_keys_res) do      
          local summary_res,summary_err = redis_client:get(value)
	  if summary_res then
             summary_number=summary_number+tonumber(summary_res)
	  end 
      end 

      ngx.log(ngx.INFO, "summary_value:",summary_number)
      if summary_number>=rule.TotalRequest then
         
	 if type(rule.ReturnMessage) == "string" then 
            local return_message = rule.ReturnMessage
            ngx.say(return_message)
	 else 
	    local return_message='{"result":false,"msg":"Request exceeds set number"}';
            ngx.say(return_message)
	 end

      end
   end
end

return _M