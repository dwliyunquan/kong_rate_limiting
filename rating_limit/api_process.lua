local cjson = require "cjson"

local _M = {}

-- 加入黑名单
function _M.addApiBlackList(appId,redis_client,processedRule,server_name,api_address,ip)
   
   if type(processedRule.ProcessMethod) == "string" then 

      --加入黑名单
      if processedRule.ProcessMethod == "0" then 
         
	 local black_list_time=os.time()
         local api_black_key=appId..":".."blacklist:"..server_name..":"..api_address

	 if ip ~= '' then
            api_black_key=api_black_key..":"..ip
	 end 
          
	 redis_client:set(api_black_key, tonumber(black_list_time)+processedRule.LimitAccessLength)
	 redis_client:expire(api_black_key,processedRule.LimitAccessLength+300) 
      end

   elseif type(processedRule.ReturnMessage) == "string" then 
        local return_message= processedRule.ReturnMessage
        ngx.say(return_message)
   else 
	local api_returnMessage='{"result":false,"msg":"Request exceeds set number"}';
        ngx.say(api_returnMessage)
   end

end

--全站-Api-Ip限流
function _M.limitApiRequest(appId,redis_client,rule,server_name,api_address,ip)

    local is_have_api=false
    for k,api in ipairs(rule.Apis) do 
        if api.ApiAddress == api_address then 
	   is_have_api = true
	   break 
	end
    end

    if is_have_api == false then 
       return false
    end

   if rule.SecondRequest>0 then

      local secondTime=os.date("%Y%m%d%H%M%S", os.time())

      local api_limit_key=appId..":".."Second:"..server_name..":"..api_address..":"..secondTime..":"..rule.RuleId
      if ip ~= '' then
         api_limit_key=appId..":".."Second:"..server_name..":"..ip..":"..api_address..":"..secondTime..":"..rule.RuleId
      end

      local res, err = redis_client:incr(api_limit_key)
      if not res then
         ngx.log(ngx.ERR, "connect redis error : ",err)
         return err
      end

      local res_number = tonumber(res)
      if res_number == 1 then
         redis_client:expire(api_limit_key,"120") 
      end

      if res_number >= rule.SecondRequest then
         _M.addApiBlackList(appId,redis_client,rule,server_name,api_address,ip)
      end

   end

   if rule.MinuteRequest>0 then
                
      local minuteTime=os.date("%Y%m%d%H%M", os.time())

      local api_limit_key=appId..":".."Minute:"..server_name..":"..api_address..":"..minuteTime..":"..rule.RuleId
      if ip ~= '' then
         api_limit_key=appId..":".."Minute:"..server_name..":"..ip..":"..api_address..":"..minuteTime..":"..rule.RuleId
      end

      local res, err = redis_client:incr(api_limit_key)
      if not res then
         ngx.log(ngx.ERR, "connect redis error : ",err)
         return err
      end

      local res_number = tonumber(res)
      if res_number == 1 then
         redis_client:expire(api_limit_key,"600") 
      end

      if res_number >= rule.MinuteRequest then
         _M.addApiBlackList(appId,redis_client,rule,server_name,api_address,ip)
      end

   end
end

-- 校验Api请求是否在黑名单内
function _M.limitApiProcessed(appId,redis_client,processedRule,server_name,api_address,ip)
    
    local api_black_result=false
    local api_black_list_time=os.time()  
    local api_black_key=appId..":".."blacklist:"..server_name..":"..api_address;
    
    if ip ~= '' then
       api_black_key=api_black_key..":"..ip
    end
    
    local res, err = redis_client:get(api_black_key)
    
    if type(res) == "string" then 
       if tonumber(res) > tonumber(api_black_list_time) then 

	    if type(processedRule.BlacklistMessage) == "string" then
               local blacklist_message = processedRule.BlacklistMessage
               ngx.say(blacklist_message)
	       api_black_result=true
	    else 
	       local api_blacklist_message='{"result":false,"msg":"request is restricted"}';
               ngx.say(api_blacklist_message)
	       api_black_result=true
	    end
             
        end
    end

    return api_black_result
end

return _M