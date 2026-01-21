local range = 20

local checkerboard = function(pos)
	return (pos.x + pos.y + pos.z) % 2
end


minetest.register_node("mini_sun:glow", {
    description = "Air glow",
	air_equivalent = true,
    drawtype = "airlike",           -- рисуется как воздух (невидимый)
    paramtype = "light",            -- пропускает свет
    sunlight_propagates = true,     -- пропускает солнечный свет
    walkable = false,               -- сквозь него можно ходить
    pointable = false,              -- нельзя выделить курсором
    diggable = false,               -- нельзя копать
    buildable_to = true,            -- можно заменить другим блоком
    floodable = true,               -- можно затопить жидкостью
    drop = "",                      -- ничего не дропает
    groups = {
        not_in_creative_inventory = 1,
        immortal = 1,
        air = 1,
    },
    sounds = nil,                   -- без звуков
    light_source = 14,               -- светится
})


minetest.register_craft({
	output = 'mini_sun:source 1',
	recipe = {
		{'default:copper_ingot', 'default:glass', 'default:copper_ingot'},
		{'default:glass', 'default:mese_crystal', 'default:glass'},
		{'default:copper_ingot', 'default:glass', 'default:copper_ingot'},
	}
})

minetest.register_node("mini_sun:source", {
	description = "Mini-Sun",
	inventory_image = minetest.inventorycube("mini_sun.png", "mini_sun.png", "mini_sun.png"),
	tiles = { "mini_sun.png" },
	drawtype = "glasslike",
	groups = { snappy=3, oddly_breakable_by_hand=3 },
	sounds = default.node_sound_glass_defaults(),
	drop = "mini_sun:source",
	light_source = 14,
	paramtype = "light",
	on_construct = function(pos)
		local minp = vector.subtract(pos, range)
		local maxp = vector.add(pos, range)

		local pmod = checkerboard(pos)

		local c_air = minetest.get_content_id("air")
		local c_sun = minetest.get_content_id("mini_sun:glow")

		local manip = minetest.get_voxel_manip()
		local emin, emax = manip:read_from_map(minp, maxp)
		local area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})
		local data = manip:get_data()
		for x = minp.x, maxp.x do
			for y = minp.y, maxp.y do
				for z = minp.z, maxp.z do
					local vi = area:index(x, y, z)
					if data[vi] == c_air then
						if (x + y + z) % 2 == pmod then -- 3d checkerboard pattern
								data[vi] = c_sun
						end
					end
				end
			end
		end
		manip:set_data(data)
		manip:write_to_map()
		manip:update_map()

		local glow_nodes = minetest.find_nodes_in_area(minp, maxp, "mini_sun:glow")
		for _, npos in pairs(glow_nodes) do
			if checkerboard(npos) == pmod then -- 3d checkerboard pattern
				local meta = minetest.get_meta(npos)

				local src_str = meta:get_string("sources")
				local src_tbl = minetest.deserialize(src_str)
				if not src_tbl then src_tbl = {} end

				src_tbl[minetest.pos_to_string(pos)] = true
				src_str = minetest.serialize(src_tbl)

				meta:set_string("sources", src_str)
			end
		end
	end,
	on_destruct = function(pos)
		local minp = vector.subtract(pos, range)
		local maxp = vector.add(pos, range)

		local positions = {}

		local pmod = checkerboard(pos)

		local glow_nodes = minetest.find_nodes_in_area(minp, maxp, "mini_sun:glow")
		for _, npos in pairs(glow_nodes) do
			if checkerboard(npos) == pmod then -- 3d checkerboard pattern
				local meta = minetest.get_meta(npos)

				local src_str = meta:get_string("sources")
				local src_tbl = minetest.deserialize(src_str)
				if not src_tbl then src_tbl = {} end

				src_tbl[minetest.pos_to_string(pos)] = nil
				if next(src_tbl) == nil then
					table.insert(positions, npos)
				end
				src_str = minetest.serialize(src_tbl)
				meta:set_string("sources", src_str)
			end
		end

		minp = vector.subtract(minp, 3)
		maxp = vector.add(maxp, 3)

		local c_air = minetest.get_content_id("air")
		local c_sun = minetest.get_content_id("mini_sun:glow")

		local manip = minetest.get_voxel_manip()
		local emin, emax = manip:read_from_map(minp, maxp)
		local area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})
		local data = manip:get_data()
		for _, npos in ipairs(positions) do
			local vi = area:indexp(npos)
			if data[vi] == c_sun then
				data[vi] = c_air
			end
		end
		manip:set_data(data)
		manip:write_to_map()
		manip:update_map()
	end,
})

minetest.register_on_dignode(function(pos)
	local minp = vector.subtract(pos, range)
	local maxp = vector.add(pos, range)

	local pmod = checkerboard(pos)
	local sun_nodes = minetest.find_nodes_in_area(minp, maxp, "mini_sun:source")

	if next(sun_nodes) then
		for nx = -1, 1, 2 do
			for ny = -1, 1, 2 do
				for nz = -1, 1, 2 do
					local npos = { x=pos.x+nx, y=pos.y+ny, z=pos.z+nz }
					local name = minetest.get_node(npos).name
					if name == "mini_sun:glow" then
						minetest.set_node(npos, {name="air"})
					end
				end
			end
		end
	end

	local lit = false

	for _, npos in pairs(sun_nodes) do
		if checkerboard(npos) == pmod then -- 3d checkerboard pattern
			if not lit then -- against lightable surfaces
				minetest.set_node(pos, {name = "mini_sun:glow"})
				lit = true
			end
			if lit then
				local meta = minetest.get_meta(pos)

				local src_str = meta:get_string("sources")
				local src_tbl = minetest.deserialize(src_str)
				if not src_tbl then src_tbl = {} end

				src_tbl[minetest.pos_to_string(npos)] = true
				src_str = minetest.serialize(src_tbl)

				meta:set_string("sources", src_str)
			end
		end
	end
end)
--[[
minetest.register_abm({
	label = "Wash away glow",
	nodenames = { "mini_sun:glow" },
	interval = 1,
	chance = 1,
	action = function(pos)
	minetest.remove_node(pos)
	end,
})
--]]
minetest.register_on_placenode(function(pos, newnode, _, oldnode)

	if oldnode.name == "air" and newnode.name ~= "mini_sun:source" then

		local minp = vector.subtract(pos, range+1)
		local maxp = vector.add(pos, range+1)

		local sun_nodes = minetest.find_nodes_in_area(minp, maxp, "mini_sun:source")

		if next(sun_nodes) then
			local rpos
			for nx = -1, 1, 2 do
				for ny = -1, 1, 2 do
					for nz = -1, 1, 2 do
						rpos = { x=pos.x+nx, y=pos.y+ny, z=pos.z+nz }
						local name = minetest.get_node(rpos).name
						if name == "air" then

							local pmod = checkerboard(rpos)
							local lit = false

							for _, npos in pairs(sun_nodes) do

								if checkerboard(npos) == pmod then -- 3d checkerboard pattern
									if not lit then -- against lightable surfaces
										minetest.set_node(rpos, {name = "mini_sun:glow"})
										lit = true
									end
									if lit then
										local meta = minetest.get_meta(rpos)

										local src_str = meta:get_string("sources")
										local src_tbl = minetest.deserialize(src_str)
										if not src_tbl then src_tbl = {} end

										src_tbl[minetest.pos_to_string(npos)] = true
										src_str = minetest.serialize(src_tbl)

										meta:set_string("sources", src_str)
									end
								end
							end
						end
					end
				end
			end
		end
	end
end)

minetest.register_chatcommand("ms_clear", {
	func = function(name)
		local pos = minetest.get_player_by_name(name):getpos()

		local minp = vector.subtract(pos, range+3)
		local maxp = vector.add(pos, range+3)

		for x = minp.x, maxp.x do
			for y = minp.y, maxp.y do
				for z = minp.z, maxp.z do
					minetest.get_meta({ x, y, z }):set_string("sources", nil)
				end
			end
		end

		local c_air = minetest.get_content_id("air")
		local c_sun = minetest.get_content_id("mini_sun:glow")

		local manip = minetest.get_voxel_manip()
		local emin, emax = manip:read_from_map(minp, maxp)
		local area = VoxelArea:new({MinEdge=emin, MaxEdge=emax})
		local data = manip:get_data()
		for x = minp.x, maxp.x do
			for y = minp.y, maxp.y do
				for z = minp.z, maxp.z do
					local vi = area:index(x, y, z)
					if data[vi] == c_sun then
						data[vi] = c_air
					end
				end
			end
		end
		manip:set_data(data)
		manip:write_to_map()
		manip:update_map()
	end
})

-- Добавьте этот код в конец вашего init.lua в моде mini_sun

-- Перехватываем функции после загрузки всех модов
minetest.register_on_mods_loaded(function()
    -- Перехватываем minetest.spawn_tree
    local original_spawn_tree = minetest.spawn_tree

    minetest.spawn_tree = function(pos, model, ...)
        -- Определяем область для временной замены mini_sun:glow
        local radius = 15  -- Увеличил радиус для больших деревьев
        local height = 25

        -- Если модель содержит параметры размера, используем их
        if model and model.radius then
            radius = model.radius
        end
        if model and model.height then
            height = model.height
        end

        local minp = {
            x = pos.x - radius,
            y = pos.y,
            z = pos.z - radius
        }
        local maxp = {
            x = pos.x + radius,
            y = pos.y + height,
            z = pos.z + radius
        }

        -- Запоминаем и временно заменяем mini_sun:glow на air
        local glow_nodes = minetest.find_nodes_in_area(minp, maxp, {"mini_sun:glow"})
        local glow_map = {}

        for _, glow_pos in ipairs(glow_nodes) do
            glow_map[minetest.pos_to_string(glow_pos)] = true
            minetest.set_node(glow_pos, {name = "air"})
        end

        -- Отладочный вывод
        minetest.log("action", "[mini_sun] Temporarily replaced " .. #glow_nodes ..
                    " mini_sun:glow nodes with air for tree growth at " ..
                    minetest.pos_to_string(pos))

        -- Вызываем оригинальную функцию
        local success, result = pcall(original_spawn_tree, pos, model, ...)

        -- Восстанавливаем mini_sun:glow там, где остался air
        local restored_count = 0
        for str_pos, _ in pairs(glow_map) do
            local glow_pos = minetest.string_to_pos(str_pos)
            local node = minetest.get_node(glow_pos)
            if node.name == "air" then
                minetest.set_node(glow_pos, {name = "mini_sun:glow"})
                restored_count = restored_count + 1
            end
        end

        minetest.log("action", "[mini_sun] Restored " .. restored_count ..
                    " mini_sun:glow nodes after tree growth")

        if not success then
            error(result)
        end

        return result
    end

    -- Переопределяем конкретные функции роста в moretrees
    if minetest.get_modpath("moretrees") then
        -- Получаем ссылку на таблицу moretrees
        local moretrees = minetest.get_modpath("moretrees") and rawget(_G, "moretrees")

        if moretrees then
            -- Сохраняем оригинальные функции
            local original_grow_birch = moretrees.grow_birch
            local original_grow_spruce = moretrees.grow_spruce
            local original_grow_jungletree = moretrees.grow_jungletree
            local original_grow_fir = moretrees.grow_fir
            local original_grow_fir_snow = moretrees.grow_fir_snow

            -- Обертка для функций роста
            local function wrap_grow_function(original_func)
                return function(pos)
                    -- Определяем область для этой функции
                    local radius = 15
                    local height = 25

                    local minp = {
                        x = pos.x - radius,
                        y = pos.y,
                        z = pos.z - radius
                    }
                    local maxp = {
                        x = pos.x + radius,
                        y = pos.y + height,
                        z = pos.z + radius
                    }

                    -- Временно заменяем mini_sun:glow
                    local glow_nodes = minetest.find_nodes_in_area(minp, maxp, {"mini_sun:glow"})
                    local glow_map = {}

                    for _, glow_pos in ipairs(glow_nodes) do
                        glow_map[minetest.pos_to_string(glow_pos)] = true
                        minetest.set_node(glow_pos, {name = "air"})
                    end

                    minetest.log("action", "[mini_sun] Calling wrapped grow function at " ..
                                minetest.pos_to_string(pos) ..
                                ", temporarily replaced " .. #glow_nodes .. " glow nodes")

                    -- Вызываем оригинальную функцию
                    original_func(pos)

                    -- Восстанавливаем mini_sun:glow
                    local restored_count = 0
                    for str_pos, _ in pairs(glow_map) do
                        local glow_pos = minetest.string_to_pos(str_pos)
                        local node = minetest.get_node(glow_pos)
                        if node.name == "air" then
                            minetest.set_node(glow_pos, {name = "mini_sun:glow"})
                            restored_count = restored_count + 1
                        end
                    end

                    minetest.log("action", "[mini_sun] Restored " .. restored_count ..
                                " glow nodes after tree growth")
                end
            end

            -- Переопределяем функции
            moretrees.grow_birch = wrap_grow_function(original_grow_birch)
            moretrees.grow_spruce = wrap_grow_function(original_grow_spruce)
            moretrees.grow_jungletree = wrap_grow_function(original_grow_jungletree)
            moretrees.grow_fir = wrap_grow_function(original_grow_fir)
            moretrees.grow_fir_snow = wrap_grow_function(original_grow_fir_snow)

            minetest.log("action", "[mini_sun] Successfully wrapped moretrees grow functions")
        end
    end

    -- Также перехватываем place_schematic для других деревьев
    local original_place_schematic = minetest.place_schematic

    minetest.place_schematic = function(pos, schematic, rotation, replacements, force_placement, flags, ...)
        -- Определяем тип schematic (путь или таблица)
        local schem_data
        if type(schematic) == "string" then
            schem_data = minetest.read_schematic(schematic, {})
        elseif type(schematic) == "table" then
            schem_data = schematic
        end

        -- Если не удалось получить данные схемы, используем оригинальную функцию
        if not schem_data or not schem_data.size then
            return original_place_schematic(pos, schematic, rotation, replacements, force_placement, flags, ...)
        end

        local size = schem_data.size

        -- Определяем область схемы
        local minp = {x = pos.x, y = pos.y, z = pos.z}
        local maxp = {x = pos.x + size.x - 1, y = pos.y + size.y - 1, z = pos.z + size.z - 1}

        -- Обрабатываем флаги центрирования
        if flags then
            if flags:find("place_center_x") then
                minp.x = pos.x - math.floor(size.x / 2)
                maxp.x = minp.x + size.x - 1
            end
            if flags:find("place_center_y") then
                minp.y = pos.y - math.floor(size.y / 2)
                maxp.y = minp.y + size.y - 1
            end
            if flags:find("place_center_z") then
                minp.z = pos.z - math.floor(size.z / 2)
                maxp.z = minp.z + size.z - 1
            end
        end

        -- Запоминаем позиции mini_sun:glow
        local glow_nodes = minetest.find_nodes_in_area(minp, maxp, {"mini_sun:glow"})
        local glow_map = {}

        -- Временно заменяем mini_sun:glow на air
        for _, glow_pos in ipairs(glow_nodes) do
            glow_map[minetest.pos_to_string(glow_pos)] = true
            minetest.set_node(glow_pos, {name = "air"})
        end

        minetest.log("action", "[mini_sun] place_schematic: temporarily replaced " ..
                    #glow_nodes .. " glow nodes")

        -- Вызываем оригинальную функцию
        local result = original_place_schematic(pos, schematic, rotation, replacements, force_placement, flags, ...)

        -- Восстанавливаем mini_sun:glow там, где остался air
        local restored_count = 0
        for str_pos, _ in pairs(glow_map) do
            local glow_pos = minetest.string_to_pos(str_pos)
            local node = minetest.get_node(glow_pos)
            if node.name == "air" then
                minetest.set_node(glow_pos, {name = "mini_sun:glow"})
                restored_count = restored_count + 1
            end
        end

        minetest.log("action", "[mini_sun] place_schematic: restored " ..
                    restored_count .. " glow nodes")

        return result
    end
end)

-- Добавляем отладочный ABM для проверки саженцев
minetest.register_abm({
    label = "Debug tree growth",
    nodenames = {"moretrees:birch_sapling", "moretrees:spruce_sapling", "moretrees:jungletree_sapling"},
    interval = 1,
    chance = 1,
    action = function(pos, node)
        minetest.log("action", "[mini_sun] Found sapling at " ..
                    minetest.pos_to_string(pos) .. ": " .. node.name)

        -- Проверяем, есть ли mini_sun:glow рядом
        local minp = {x = pos.x - 5, y = pos.y, z = pos.z - 5}
        local maxp = {x = pos.x + 5, y = pos.y + 10, z = pos.z + 5}
        local glow_nodes = minetest.find_nodes_in_area(minp, maxp, {"mini_sun:glow"})

        minetest.log("action", "[mini_sun] Found " .. #glow_nodes ..
                    " mini_sun:glow nodes near sapling")
    end
})
