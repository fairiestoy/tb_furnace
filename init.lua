--[[
Special Furnace

This furnace follows a few different rules then
the builtin ones. Instead of waiting on ABMs,
it works with time based calculations.

Version: 135696
Author: fairiestoy
]]

tb_furnaces = {}

tb_furnaces.furnace_is_ready = function( meta, inv, listname, stack )
	local return_value = {}
	if listname == 'fuel' then
		if minetest.get_craft_result( {method='fuel', width=1, items={stack}}).time ~= 0 then
			if inv:is_empty( 'src' ) then
				meta:set_string( 'infotext', 'Furnace is empty' )
			else
				meta:set_string( 'infotext', 'Furnace' )
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
	if not inv:is_empty( 'fuel' ) and not inv:is_empty( 'src' ) then
		local temp_stack = nil
		for index = 1, 4, 1 do
			temp_stack = inv:get_stack( 'fuel', index )
			if not temp_stack:is_empty() then
				if minetest.get_craft_result({method = "fuel", width = 1, items = {temp_stack}}).time ~= 0 then
					return_value[2] = true
					break
				end
			end
		end
	else
		return_value[2] = false
	end
	return return_value
end

minetest.register_node("tb_furnace:s_furnace", {
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
			local pos_string = pos.x..','..pos.y..','..pos.z
			local formspec = "size[9,9]"..
				"image[3,3;1,1;default_furnace_fire_bg.png]"..
				"list[nodemeta:"..pos_string..";fuel;1,4;2,2;]"..
				"list[nodemeta:"..pos_string..";src;1,1;2,2;]"..
				"list[nodemeta:"..pos_string..";dst;5,1;4,4;]"..
				"list[current_player;main;0,6;8,4;]"
			-- Looks like we not have been busy up to now
			minetest.show_formspec(  clicker:get_player_name() , 'tb_furnace:unused', formspec )
		else
			local pos_string = pos.x..','..pos.y..','..pos.z
			local formspec = "size[9,9]"..
				"image[3,3;1,1;default_furnace_fire_bg.png^default_furnace_fire_fg.png]"..
				"list[nodemeta:"..pos_string..";fuel;1,4;2,2;]"..
				"list[nodemeta:"..pos_string..";src;1,1;2,2;]"..
				"list[nodemeta:"..pos_string..";dst;5,1;4,4;]"..
				"list[current_player;main;0,6;8,4;]"
			-- Collect time information
			local last_time = meta:get_int( 'src_time' )
			local inv = meta:get_inventory()
			local current_time = os.time()
			local src_diff = current_time - last_time
			last_time = meta:get_int( 'fuel_time' )
			local fuel_diff = current_time - last_time
			if ( not src_diff or src_diff == 0 ) and ( not fuel_diff or fuel_diff == 0 ) then
				minetest.show_formspec(  clicker:get_player_name() , 'tb_furnace:unused', formspec )
				return
			end
			-- First, gather necessary informations
			-- src
			local src_list_results = {}
			local srclist = inv:get_list("src")
			local cooked, aftercooked = nil
			cooked, aftercooked = minetest.get_craft_result({method = "cooking", width = 1, items = srclist})
			src_list_results['amount'] = math.floor( cooked.time / src_diff )
			src_list_results['time'] = cooked.time
			src_list_results['total_time'] = cooked.time * src_list_results['amount']
			local temp_stack, total_items = nil, 0
			for index = 1, 4, 1 do
				temp_stack = inv:get_stack( 'src', index )
				if not temp_stack:is_empty() then
					total_items = total_items + temp_stack:get_count()
				end
			end
			src_list_results['item_amount'] = total_items
			if src_list_results.item_amount < src_list_results.amount then
				-- we don't have enough items, so manipulate items a bit
				src_list_results.amount = src_list_results.item_amount
				-- disable cooking due to missing source items
				meta:set_int( 'cooking_state', 0 )
			end
			-- fuel
			local fuel_list_results = {}
			local fuellist = inv:get_list('fuel')
			local fuel, afterfuel = nil
			fuel, afterfuel = minetest.get_craft_result({method = "fuel", width = 1, items = fuellist})
			fuel_list_results['amount'] = math.floor( fuel.time / fuel_diff )
			fuel_list_results['time'] = fuel.time
			fuel_list_results['total_time'] = fuel.time * fuel_list_results['amount']
			temp_stack, total_items = nil, 0
			for index = 1, 4, 1 do
				temp_stack = inv:get_stack( 'src', index )
				if not temp_stack:is_empty() then
					total_items = total_items + temp_stack:get_count()
				end
			end
			fuel_list_results['item_amount'] = total_items
			if fuel_list_results.item_amount < fuel_list_results.amount then
				-- we don't have enough items, so manipulate items a bit
				fuel_list_results.amount = fuel_list_results.item_amount
				meta:set_int( 'cooking_state', 0 )
			end
			-- dst
			local dst_list = {}
			temp_stack, total_items = nil, 0
			for index = 1, inv:get_size( 'dst' ), 1 do
				temp_stack = inv:get_stack( 'dst', index )
				if not temp_stack:is_empty() then
					total_items = total_items + temp_stack:get_free_space()
				end
			end
			dst_list['free_space'] = total_items
			-- Time to see how much results we cooked
			if fuel_list_results['total_time'] < src_list_results['total_time'] then
				-- we didn't had enough fuel to cook all items, correct value
				src_list_results['total_time'] = fuel_list_results['total_time']
				src_list_results['amount'] = math.floor( src_list_results['total_time'] / src_list_results['time'] )
			else
				-- there was more fuel than needed
				fuel_list_results['total_time'] = src_list_results['total_time']
				fuel_list_results['amount'] = math.floor( fuel_list_results['total_time'] / fuel_list_results['time'] )
			end
			if dst_list.free_space < ( src_list_results['amount'] * cooked.item:get_count() ) then
				-- we also have to correct the free space amount -_-
				src_list_results['amount'] = math.floor( total_items / cooked.item:get_count() )
				src_list_results['total_time'] = src_list_results['amount'] * src_list_results['time']
				fuel_list_results['total_time'] = src_list_results['total_time']
				fuel_list_results['amount'] = fuel_list_results['total_time'] * fuel_list_results['time']
				meta:set_int( 'cooking_state', 0 )
				print( 'Switched to inactive state...4' )
			end
			if ( src_diff > cooked.time ) then
				temp_stack, total_items = nil, 0
				total_items = cooked.item:get_count() * src_list_results['amount']
				temp_stack = cooked.item:to_table()
				temp_stack.count = total_items
				temp_stack = ItemStack( temp_stack )
				inv:add_item( 'dst', temp_stack )
				temp_stack = cooked.item:to_table()
				temp_stack.count = src_list_results['amount']
				temp_stack = ItemStack( temp_stack )
				inv:remove_item( 'src', temp_stack )
				meta:set_int( 'src_time', os.time() )
			end
			if ( fuel_diff > fuel.time ) then
				temp_stack = fuel.item:to_table()
				temp_stack.count = fuel_list_results['amount'] - 1
				temp_stack = ItemStack( temp_stack )
				inv:remove_item( 'fuel', temp_stack )
				meta:set_int( 'fuel_time' , os.time() )
			end
			local pos_string = pos.x..','..pos.y..','..pos.z
			local formspec = "size[9,9]"..
				"image[3,3;1,1;default_furnace_fire_bg.png^default_furnace_fire_fg.png]"..
				"list[nodemeta:"..pos_string..";fuel;1,4;2,2;]"..
				"list[nodemeta:"..pos_string..";src;1,1;2,2;]"..
				"list[nodemeta:"..pos_string..";dst;5,1;4,4;]"..
				"list[current_player;main;0,6;8,4;]"
			minetest.show_formspec(  clicker:get_player_name() , 'tb_furnace:unused', formspec )
		end
	end,
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("infotext", "Furnace inactive")
		meta:set_int( 'cooking_state', 0 )
		local inv = meta:get_inventory()
		inv:set_size("fuel", 4)
		inv:set_size("src", 4)
		inv:set_size("dst", 8)
	end,
	can_dig = function(pos,player)
		local meta = minetest.get_meta(pos);
		local inv = meta:get_inventory()
		if inv:is_empty( 'fuel' ) and inv:is_empty( 'src' ) and inv:is_empty( 'dst' ) then
			return true
		end
		return false
	end,
	on_metadata_inventory_move = function( pos, from_list )
		local meta = minetest.get_meta( pos )
		local inv = meta:get_inventory()
		local stack = nil
		for index = 1, 4, 1 do
			stack = inv:get_stack( 'fuel', index )
			if not stack:is_empty() then
				if tb_furnaces.furnace_is_ready( meta, inv, from_list, stack )[2] then
					meta:set_int( 'cooking_state', 1 )
					meta:set_int( 'src_time', os.time() )
					meta:set_int( 'fuel_time', os.time() )
					meta:set_string( 'infotext', 'Furnace active' )
				end
			end
		end
	end,
	on_metadata_inventory_put = function( pos, listname, index, stack )
		local meta = minetest.get_meta( pos )
		local inv = meta:get_inventory()
		local stack = inv:get_stack( listname, index )
		if tb_furnaces.furnace_is_ready( meta, inv, listname, stack )[2] then
			meta:set_int( 'cooking_state', 1 )
			meta:set_int( 'src_time', os.time() )
			meta:set_int( 'fuel_time', os.time() )
			meta:set_string( 'infotext', 'Furnace active' )
		end
	end,
	on_metadata_inventory_take = function( pos, listname, index, stack, player )
		if listname == 'fuel' or listname == 'src' then
			local meta = minetest.get_meta( pos )
			meta:set_int( 'cooking_state', 0 )
			meta:set_string( 'infotext', 'Furnace inactive' )
		end
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
