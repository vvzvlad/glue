#!/usr/bin/env tarantool
local mqtt = require 'mqtt'
local mqtt_conn
local inspect = require 'inspect'
local json = require 'json'
local base64 = require 'base64'
local fiber = require 'fiber'

local config = {}
config.MQTT_HOST = "impact.iot.nokia.com"
config.MQTT_PORT = 1883
config.MQTT_LOGIN = "TEST_USER"
config.MQTT_PASSWORD = "0wYlg9KJ5E+ksmvt7l2mU6ucSSo/WjRDCdCgd2pQpF0="
config.MQTT_ID = "impact_tarantool_client"
config.MQTT_TOKEN = "trqspu69qcz7"

config.HTTP_PORT = 8080


local http_client = require('http.client')
local http_server = require('http.server').new(nil, config.HTTP_PORT, {charset = "application/json"})

io.stdout:setvbuf("no")

local impact_data = ""


local function create_mqtt_token(username, password, tenant, description)
   local basic = "Basic "..(base64.to_base64(username..":"..password))
   local headers = { ['Content-Type'] = 'application/json', ['Accept'] = 'application/json', ['Authorization'] = basic}
   local data = {description = description, groupName = tenant, username = username}
   local url = 'https://impact.iot.nokia.com/m2m/token/mqtt'
   local r = http_client.put(url, json.encode(data), { headers = headers })
   return r.body
end

local function get_tokens(username, password, tenant)
   local basic = "Basic "..(base64.to_base64(username..":"..password))
   local headers_table = { ['Content-Type'] = 'application/json', ['Accept'] = 'application/json', ['Authorization'] = basic}
   local url = 'https://impact.iot.nokia.com/m2m/token?groupName='..tenant
   local r = http_client.get(url, { headers = headers_table })
   return r.body
end

local function delete_token(username, password, tenant, token)
   local basic = "Basic "..(base64.to_base64(username..":"..password))
   local headers_table = { ['Content-Type'] = 'application/json', ['Accept'] = 'application/json', ['Authorization'] = basic}
   local url = 'https://impact.iot.nokia.com/m2m/token?groupName='..tenant..'&token='..token
   local r = http_client.delete(url, { headers = headers_table })
   return r.body
end



local function get_my_subscriptions(username, password)
   local basic = "Basic "..(base64.to_base64(username..":"..password))
   local headers_table = { ['Content-Type'] = 'application/json', ['Accept'] = 'application/json', ['Authorization'] = basic}
   local url = 'https://impact.iot.nokia.com/m2m/mysubscriptions'
   local r = http_client.get(url, { headers = headers_table })
   return r.body
end

local function delete_subscription(username, password, subscription_id)
   local basic = "Basic "..(base64.to_base64(username..":"..password))
   local headers_table = { ['Content-Type'] = 'application/json', ['Accept'] = 'application/json', ['Authorization'] = basic}
   local url = 'https://impact.iot.nokia.com/m2m/subscriptions/'..subscription_id
   local r = http_client.delete(url, { headers = headers_table })
   return r.body
end

local function new_subscription(username, password, tenant, subscription_topic)
   local basic = "Basic "..(base64.to_base64(username..":"..password))
   local headers_table = { ['Content-Type'] = 'application/json', ['Accept'] = 'application/json', ['Authorization'] = basic}
   local data = {deletionPolicy = 0, groupName = tenant, subscriptionType = "resources", resources = {{resourcePath = subscription_topic}}}
   local url = 'https://impact.iot.nokia.com/m2m/subscriptions?type=resources'
   print(json.encode(data))
   local r = http_client.post(url, json.encode(data), { headers = headers_table })
   return r.body
end









local function set_rest_callback(username, password, callback_url)
   local basic = "Basic "..(base64.to_base64(username..":"..password))
   local headers = { ['Content-Type'] = 'application/json', ['Accept'] = 'application/json', ['Authorization'] = basic}
   local data = {headers = {}, url = callback_url}
   local url = 'https://impact.iot.nokia.com/m2m/applications/registration'
   local r = http_client.put(url, json.encode(data), { headers = headers })
   return r.body
end


local function mqtt_message(message_id, topic, payload, gos, retain)
	print("New message. Topic "..topic..", data: "..payload)
end

local function impact_rest_http_handler(req)
   local body = req:read({delimiter = nil, chunk = 1000}, 10)
   local status, data = pcall(json.decode, body)
   if (status == true and data ~= nil) then
      impact_data = data
   end
   return { status = 200 }
end

local function http_server_data_handler(req)
      local return_object
      if (impact_data ~= "") then
         return_object = req:render{ json = { impact_data } }
      else
         return_object = req:render{ json = { none_data = "true" } }
      end
      impact_data = ""
      return return_object
end

local function http_server_action_handler(req)
   local type_param = req:param("type")

   if (type_param ~= nil) then
      if (type_param == "mqtt_send") then
         local value_param, topic_param = req:param("value"), req:param("topic")
         if (value_param == nil or topic_param == nil) then return nil end
         local ok, err = mqtt_conn:publish(config.MQTT_TOKEN.."/"..topic_param, value_param, mqtt.QOS_0, mqtt.NON_RETAIN)
         if ok then
            print(ok, err)
         end
         return req:render{ json = { mqtt_result = ok } }
      end
      if (type_param == "get_token") then
         --local answer = create_mqtt_token("test_user", "test_pass1", "test_tenant", "test_token2")
         local answer = get_tokens("test_user", "test_pass1", "test_tenant")

         local return_object = req:render{ json = { data = answer } }
         return return_object
      end
      if (type_param == "register_callback") then
         print("register_callback")
      end
      if (type_param == "settings_login") then
         print("settings_login")

      end
      if (type_param == "get_my_subscriptions") then
         local answer = get_my_subscriptions("test_user", "test_pass1")
         --local return_object = req:render{ json = { data = answer } }
         return {status = 200, body = answer}
      end

      if (type_param == "delete_subscription") then
         local answer = delete_subscription("test_user", "test_pass1", req:param("subscription_id"))
         return {status = 200, body = answer}
      end
      if (type_param == "new_subscription") then
         local answer = new_subscription("test_user", "test_pass1", "test_tenant", req:param("subscription_topic"))
         return {status = 200, body = answer}
      end
      return nil
   end

end

local function http_server_root_handler(req)
   return req:redirect_to('/dashboard')
end

local function set_callback()
   fiber.sleep(1)
   local ngrock_url_api = 'http://127.0.0.1:4040/api/tunnels'
   local r = http_client.get(ngrock_url_api)
   local data = json.decode(r.body)
   local url = data.tunnels[1].public_url.."/impact_rest_endpoint"
   print("local url: "..url)
   print(set_rest_callback("test_user", "test_pass1", url))
end


fiber.create(set_callback)

mqtt_conn = mqtt.new(config.MQTT_ID, true)
mqtt_conn:login_set(config.MQTT_LOGIN, config.MQTT_PASSWORD)
local mqtt_ok, mqtt_err = mqtt_conn:connect({host=config.MQTT_HOST,port=config.MQTT_PORT,keepalive=60,log_mask=mqtt.LOG_ALL})
print(inspect(mqtt_ok,mqtt_err))
if (mqtt_ok ~= true) then
   print ("Error mqtt: "..(mqtt_err or "No error"))
   os.exit()
end

mqtt_conn:subscribe('trqspu69qcz7/SK_TEST_DEVICE2/temperature/0/sensorValue', 0)
mqtt_conn:on_message(mqtt_message)


http_server:route({ path = '/impact_rest_endpoint' }, impact_rest_http_handler)
http_server:route({ path = '/data' }, http_server_data_handler)
http_server:route({ path = '/action' }, http_server_action_handler)


http_server:route({ path = '/' }, http_server_root_handler)
http_server:route({ path = '/dashboard', file = 'dashboard.html' })
http_server:route({ path = '/dashboard-subscriptions', file = 'dashboard-subscriptions.html' })
http_server:route({ path = '/dashboard-settings', file = 'dashboard-settings.html' })

http_server:start()
