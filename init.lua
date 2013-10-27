--[[
Special Furnace

This furnace follows a few different rules then
the builtin ones. Instead of waiting on ABMs,
it works with time based calculations.

Version: 206608
Author: fairiestoy
]]

tb_furnaces = {}

local function show_formspec( pos, player_name , form_index )
	local pos_string = pos.x..','..pos.y..','..pos.z
	local form_table = {
		"size[9,9]"..
			"image[3,3;1,1;default_furnace_fire_bg.png]"..
			"list[nodemeta:"..pos_string..";fuel;1,4;2,2;]"..
			"list[nodemeta:"..pos_string..";src;1,1;2,2;]"..
			"list[nodemeta:"..pos_string..";dst;5,1;4,4;]"..
			"list[current_player;main;0,6;8,4;]",
		"size[9,9]"..
			"image[3,3;1,1;default_furnace_fire_bg.png^default_furnace_fire_fg.png]"..
			"list[nodemeta:"..pos_string..";fuel;1,4;2,2;]"..
			"list[nodemeta:"..pos_string..";src;1,1;2,2;]"..
			"list[nodemeta:"..pos_string..";dst;5,1;4,4;]"..
			"list[current_player;main;0,6;8,4;]",
		}
	minetest.show_formspec( player_name, 'tb_furnace:formspec', form_table[ form_index ] )
end

local function gather_time_information( meta_data )
	-- Collect time information
	local current_time = os.time()
	local last_time = meta_data:get_int( 'src_time' )
	local src_diff = current_time - last_time
	last_time = meta_data:get_int( 'fuel_time' )
	local fuel_diff = current_time - last_time
	return src_diff, fuel_diff
end

local function detect_slot_item( inv, slot )
	local fuellist = inv:get_list( slot )
	for index = 1, inv:get_size( slot ), 1 do
		temp_stack = inv:get_stack( slot, index )
		if not temp_stack:is_empty() then
			return index
		end
	end
	return 0 -- No item found
end

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
			show_formspec( pos, clicker:get_player_name(), 1 )
		elseif meta:get_int( 'cooking_state' ) == 1 then
			local src_diff, fuel_diff = gather_time_information( meta )
			if src_diff == 0 and fuel_diff == 0 then
				show_formspec( pos, clicker:get_player_name(), 2 )
				return
			end
			local security_trigger = 0
			local loop_trigger = true
			while loop_trigger do
				-- Since we have more than one slot and therefore
				-- more than one possible item, iterate through
				-- the slots
				local inv = meta:get_inventory()
				src_index = detect_slot_item( inv, 'src' )
				fuel_index = detect_slot_item( inv, 'fuel' )
				if src_index == 0 or fuel_index == 0 then
					show_formspec( pos, clicker:get_player_name(), 1 )
					return
				end
				-- material calculations
				local tmp_list = {
					{},
					{}
				}
				local map_list = {
					'src',
					'fuel',
					'cooking',
					'fuel',
					src_index,
					fuel_index
				}
				for index = 1, 2 ,1 do
					local mtr_list_results = {}
					local mtr_list = inv:get_list( map_list[index] )
					local cooked, aftercooked = minetest.get_craft_result({method = map_list[index + 2], width = 1, items = {mtr_list[map_list[index + 4]]}})
					mtr_list_results['amount'] = math.floor( src_diff / cooked.time )
					mtr_list_results['time'] = cooked.time
					mtr_list_results['total_time'] = cooked.time * mtr_list_results['amount']
					mtr_list_results['item_amount'] = inv:get_stack( map_list[index], map_list[index + 4] ):get_count()
					mtr_list_results['item'] = cooked.item
					mtr_list_results['aitem'] = aftercooked.item
					if mtr_list_results.item_amount < mtr_list_results.amount then
						-- we don't have enough items, so manipulate items a bit
						mtr_list_results.amount = mtr_list_results.item_amount
						-- disable cooking due to missing source items
						meta:set_int( 'cooking_state', 0 )
					end
					tmp_list[index] = mtr_list_results
				end
				-- dst
				local src, fuel = 1,2
				local dst_list = {}
				local temp_stack, total_items = nil, 0
				for index = 1, inv:get_size( 'dst' ), 1 do
					temp_stack = inv:get_stack( 'dst', index )
					if not temp_stack:is_empty() then
						total_items = total_items + temp_stack:get_free_space()
					end
				end
				total_items = ( tmp_list[src]['item']:get_stack_max() * inv:get_size( 'dst' ) ) - total_items
				dst_list['free_space'] = total_items
				-- Time to see how much results we cooked
				if tmp_list[src]['total_time'] < tmp_list[fuel]['total_time'] and tmp_list[fuel].total_time ~= 0 then
					-- we didn't had enough fuel to cook all items, correct value
					tmp_list[src]['total_time'] = tmp_list[fuel]['total_time']
					tmp_list[src]['amount'] = math.floor( tmp_list[src]['total_time'] / tmp_list[src]['time'] )
				else
					-- there was more fuel than needed
					tmp_list[fuel]['total_time'] = tmp_list[src]['total_time']
					tmp_list[fuel]['amount'] = math.floor( tmp_list[fuel]['total_time'] / tmp_list[fuel]['time'] )
				end
				if dst_list.free_space < ( tmp_list[src]['amount'] * tmp_list[src]['item']:get_count() ) then
					-- we also have to correct the free space amount -_-
					tmp_list[src]['amount'] = math.floor( total_items / tmp_list[src]['item']:get_count() )
					tmp_list[src]['total_time'] = tmp_list[src]['amount'] * tmp_list[src]['time']
					tmp_list[fuel]['total_time'] = tmp_list[src]['total_time']
					tmp_list[fuel]['amount'] = tmp_list[fuel]['total_time'] * tmp_list[fuel]['time']
					meta:set_int( 'cooking_state', 0 )
					print( 'Switched to inactive state...4' )
				end
				if ( src_diff > tmp_list[src]['time'] ) then
					temp_stack, total_items = nil, 0
					total_items = tmp_list[src]['amount']
					temp_stack = tmp_list[src]['item']:to_table()
					temp_stack.count = total_items
					temp_stack = ItemStack( temp_stack )
					inv:add_item( 'dst', temp_stack )
					temp_stack = inv:get_stack( 'src', src_index ):to_table()
					temp_stack.count = tmp_list[src]['amount']
					temp_stack = ItemStack( temp_stack )
					inv:remove_item( 'src', temp_stack )
					meta:set_int( 'src_time', os.time() )
					src_diff = src_diff - tmp_list[src]['total_time']
				end
				if ( fuel_diff > tmp_list[fuel]['time'] ) then
					temp_stack = inv:get_stack( 'fuel', fuel_index ):to_table()
					if not temp_stack == nil then
						temp_stack.count = tmp_list[fuel]['amount'] - 1
						temp_stack = ItemStack( temp_stack )
						inv:remove_item( 'fuel', temp_stack )
						fuel_diff = fuel_diff - tmp_list[fuel]['total_time']
					end
					meta:set_int( 'fuel_time' , os.time() )
				end
				if fuel_diff == 0 or src_diff == 0 then
					loop_trigger = false
					break
				elseif security_trigger >= 5 then
					loop_trigger = false
				end
				security_trigger = security_trigger + 1
			end
			show_formspec( pos, clicker:get_player_name(), 2 )
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
