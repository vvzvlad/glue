local driver = {}
driver.name = "tarantool_stat"
driver.active = true
driver.driver_function = function()
   local fiber = require 'fiber'
   local bus = require 'bus'
   local box = require 'box'
   local system = require 'system'

   local function system_stats()
      fiber.sleep(2)
      while true do
         local stats = box.slab.info()
         local _, arena_used_ratio_number, quota_used_ratio_number
         _, _, arena_used_ratio_number = string.find(stats.arena_used_ratio, "(.+)%%$")
         _, _, quota_used_ratio_number = string.find(stats.quota_used_ratio, "(.+)%%$")
         bus.update_value("/glue/tarantool_arena_used_ratio", tonumber(arena_used_ratio_number))
         bus.update_value("/glue/tarantool_arena_size", system.round((stats.arena_size)/1000/1000), 2)
         bus.update_value("/glue/tarantool_arena_used", system.round((stats.arena_used)/1000/1000), 2)
         bus.update_value("/glue/tarantool_quota_used_ratio", tonumber(quota_used_ratio_number))
         bus.update_value("/glue/max_seq_value", tonumber(bus.max_seq_value))
         bus.update_value("/glue/avg_seq_value", tonumber(bus.avg_seq_value))

         fiber.sleep(5)
      end
   end
   fiber.create(system_stats)
end
return driver
