local cjson = require "cjson"

local _M = {}

-- 加入黑名单
function _M.addBlackList(appId,redis_client,processedRule,server_name,ip)
   
   if type(processedRule.ProcessMethod) == "string" then 

      --加入黑名单
      if processedRule.ProcessMethod == "0" then 
         
	 local black_list_time=os.time()
         local black_key=appId..":".."blacklist:"..server_name

	 if ip ~= '' then
            black_key=black_key..":"..ip
	 end 
          
	 redis_client:set(black_key, tonumber(black_list_time)+processedRule.LimitAccessLength)
         redis_client:expire(black_key,processedRule.LimitAccessLength+300) 
      end
   elseif type(processedRule.ReturnMessage) == "string" then 
        local return_message = processedRule.ReturnMessage
        ngx.say(return_message)
   else 
	local api_returnMessage='{"result":false,"msg":"Request exceeds set number"}';
        ngx.say(api_returnMessage)
   end
end

-- 校验请求是否在黑名单内
function _M.limitProcessed(appId,redis_client,processedRule,server_name,ip)
    
    local black_result=false
    local black_list_time=os.time()  
    local black_key=appId..":".."blacklist:"..server_name;
    
    if ip ~= '' then
       black_key=black_key..":"..ip
    end
    
    local res, err = redis_client:get(black_key)
    
    if type(res) == "string" then 
       if tonumber(res) > tonumber(black_list_time) then 

	    if type(processedRule.BlacklistMessage) == "string" then
               local blacklist_message = processedRule.BlacklistMessage
               ngx.say(blacklist_message)
	       black_result=true
	    else 
	       local blacklist_message='{"result":false,"msg":"request is restricted"}';
               ngx.say(blacklist_message)
	       black_result=true
	    end
             
        end
    end

    return black_result
end

--全站-Ip-限流
function _M.limitRequest(appId,redis_client,rule,server_name,ip)

   if rule.SecondRequest>0 then

      local secondTime=os.date("%Y%m%d%H%M%S", os.time())

      local limit_key=appId..":".."Second:"..server_name..":"..secondTime..":"..rule.RuleId
      if ip ~= '' then
        limit_key=appId..":".."Second:"..server_name..":"..ip..":"..secondTime..":"..rule.RuleId
      end

      local res, err = redis_client:incr(limit_key)
      if not res then
         ngx.log(ngx.ERR, "connect redis error : ",err)
         return err
      end

      local res_number = tonumber(res)
      if res_number == 1 then
         redis_client:expire(limit_key,"120") 
      end

      if res_number >= rule.SecondRequest then
         _M.addBlackList(appId,redis_client,rule,server_name,ip)
      end

   end

   if rule.MinuteRequest>0 then
                
      local minuteTime=os.date("%Y%m%d%H%M", os.time())

      local limit_key=appId..":".."Minute:"..server_name..":"..minuteTime..":"..rule.RuleId
      if ip ~= '' then
        limit_key=appId..":".."Minute:"..server_name..":"..ip..":"..minuteTime..":"..rule.RuleId
      end

      local res, err = redis_client:incr(limit_key)     
      if not res then
         ngx.log(ngx.ERR, "connect redis error : ",err)
         return err
      end

      local res_number = tonumber(res)
      if res_number == 1 then
         redis_client:expire(limit_key,"600") 
      end

      if tonumber(res)>=rule.MinuteRequest then
         _M.addBlackList(appId,redis_client,rule,server_name,ip)
      end

   end
end

return _M

