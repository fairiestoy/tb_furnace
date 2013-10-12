--[[
Special Furnace

This furnace follows a few different rules then
the builtin ones. Instead of waiting on ABMs,
it works with time based calculations.

Version: 70160
Author: fairiestoy
]]

tb_furnaces = {}

tb_furnaces.furnace_formspec_inactive = "size[8,9]"..
	"image[2,2;1,1;default_furnace_fire_bg.png]"..
	"list[current_name;fuel;2,3;2,2;]"..
	"list[current_name;src;2,1;2,2;]"..
	"list[current_name;dst;5,1;4,4;]"..
	"list[current_player;main;0,5;8,4;]"

tb_furnaces.furnace_formspec_active = "size[8,9]"..
	"image[2,2;1,1;default_furnace_fire_bg.png^default_furnace_fire_fg.png]"..
	"list[current_name;fuel;2,3;2,2;]"..
	"list[current_name;src;2,1;2,2;]"..
	"list[current_name;dst;5,1;4,4;]"..
	"list[current_player;main;0,5;8,4;]"

tb_furnaces.furnace_is_ready = function( meta, inv, listname, stack )
	local return_value = {}
	if listname == 'fuel' then
		if minetest.get_craft_result( {method='fuel', width=1, items={stack}}).time ~= 0 then
			if inv:is_empty( 'src' ) then
				meta:set_string( 'infotext', 'Furnace is empty' )
			end
			return_value[1] = true
		else
			return_value[1] = false
		end
	elseif listname == 'src' then
		return_value[1] = true
	elseif listname == 'dst' then
		return_value[1] = false
	end
	-- check if furnace is ready to start
	if not inv:is_empty( 'fuel' ) and not inv:is_empty( 'src' ) and minetest.get_craft_result( {method='fuel', width=1, items={stack}}).time ~= 0 then
		-- looks like all conditions are OK
		return_value[2] = true
	else
		return_value[2] = false
	end
	return return_value
end

minetest.register_node("tb_furnace:furnace", {
	description = "Furnace",
	tiles = {"default_furnace_top.png", "default_furnace_bottom.png", "default_furnace_side.png",
		"default_furnace_side.png", "default_furnace_side.png", "default_furnace_front.png"},
	paramtype2 = "facedir",
	groups = {cracky=2},
	legacy_facedir_simple = true,
	sounds = default.node_sound_stone_defaults(),
	on_rightclick = function( pos, node, clicker, itemstack )
		local meta = minetest.get_meta( pos )
		if meta:get_int( 'cooking_state' ) == 0 then
			-- Looks like we not have been busy up to now
			minetest.show_formspec(  clicker:get_player_name() , 'tb_furnace:unused', tb_furnaces.furnace_formspec_inactive )
		else
			-- pass
		end
	end,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Furnace")
		meta:set_int( 'cooking_state', 0 )
		local inv = meta:get_inventory()
		inv:set_size("fuel", 4)
		inv:set_size("src", 4)
		inv:set_size("dst", 8)
	end,
	can_dig = function(pos,player)
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		if not inv:is_empty("fuel") then
			return false
		elseif not inv:is_empty("dst") then
			return false
		elseif not inv:is_empty("src") then
			return false
		end
		return true
	end,
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		local return_value = s_furnaces.furnace_is_ready( meta, inv, listname, stack )
		if return_value[1] then
			return stack:get_count()
		else
			return 0
		end
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		local stack = inv:get_stack(from_list, from_index)
		local return_value = s_furnaces.furnace_is_ready( meta, inv, to_list, stack )
		if return_value[1] then
			return count
		else
			return 0
		end
	end,
	allow_metadata_inventory_take = function( pos, listname, index, stack, player )
		local meta = minetest.get_meta( pos )
		if listname == 'fuel' or listname == 'src' then
			meta:set_int( 'cooking_state', 0 )
		end
		return stack:get_count()
	end,
})

minetest.register_craft({
	output = 'tb_furnace:furnace',
	recipe = {
		{'default:iron_lump', 'group:stone', 'default:iron_lump'},
		{'group:stone', '', 'group:stone'},
		{'group:stone', 'default:gold_lump', 'group:stone'},
	}
})

--[[
minetest.register_abm({
	nodenames = {"p_furnace:furnace","p_furnace:furnace_active"},
	interval = 1.0,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local meta = minetest.get_meta(pos)
		for i, name in ipairs({
				"fuel_totaltime",
				"fuel_time",
				"src_totaltime",
				"src_time"
		}) do
			if meta:get_string(name) == "" then
				meta:set_float(name, 0.0)
			end
		end

		local inv = meta:get_inventory()

		local srclist = inv:get_list("src")
		local cooked = nil
		local aftercooked

		if srclist then
			cooked, aftercooked = minetest.get_craft_result({method = "cooking", width = 1, items = srclist})
		end

		local was_active = false

		if meta:get_float("fuel_time") < meta:get_float("fuel_totaltime") then
			was_active = true
			meta:set_float("fuel_time", meta:get_float("fuel_time") + 1)
			meta:set_float("src_time", meta:get_float("src_time") + 1)
			if cooked and cooked.item and meta:get_float("src_time") >= cooked.time then
				-- check if there's room for output in "dst" list
				if inv:room_for_item("dst",cooked.item) then
					-- Put result in "dst" list
					inv:add_item("dst", cooked.item)
					-- take stuff from "src" list
					inv:set_stack("src", 1, aftercooked.items[1])
				else
					print("Could not insert '"..cooked.item:to_string().."'")
				end
				meta:set_string("src_time", 0)
			end
		end

		if meta:get_float("fuel_time") < meta:get_float("fuel_totaltime") then
			local percent = math.floor(meta:get_float("fuel_time") /
					meta:get_float("fuel_totaltime") * 100)
			meta:set_string("infotext","Furnace active: "..percent.."%")
			hacky_swap_node(pos,"p_furnace:furnace_active")
			meta:set_string("formspec",
				"size[8,9]"..
				"image[2,2;1,1;default_furnace_fire_bg.png^[lowpart:"..
						(100-percent)..":default_furnace_fire_fg.png]"..
				"list[current_name;fuel;2,3;1,1;]"..
				"list[current_name;src;2,1;1,1;]"..
				"list[current_name;dst;5,1;2,2;]"..
				"list[current_player;main;0,5;8,4;]")
			return
		end

		local fuel = nil
		local afterfuel
		local cooked = nil
		local fuellist = inv:get_list("fuel")
		local srclist = inv:get_list("src")

		if srclist then
			cooked = minetest.get_craft_result({method = "cooking", width = 1, items = srclist})
		end
		if fuellist then
			fuel, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = fuellist})
		end

		if fuel.time <= 0 then
			meta:set_string("infotext","Furnace out of fuel")
			hacky_swap_node(pos,"p_furnace:furnace")
			meta:set_string("formspec", default.furnace_inactive_formspec)
			return
		end

		if cooked.item:is_empty() then
			if was_active then
				meta:set_string("infotext","Furnace is empty")
				hacky_swap_node(pos,"p_furnace:furnace")
				meta:set_string("formspec", default.furnace_inactive_formspec)
			end
			return
		end

		meta:set_string("fuel_totaltime", fuel.time)
		meta:set_string("fuel_time", 0)

		inv:set_stack("fuel", 1, afterfuel.items[1])
	end,
})
]]
