local fnode = minetest.registered_entities["__builtin:falling_node"]
local attacknode = table.copy(fnode)

attacknode.initial_properties.collide_with_objects = false

function attacknode:update_node()
	local def = minetest.registered_nodes[self.node.name]
	self.description = def and minetest.strip_colors(def.description or ""):split("\n")[1] or self.node.name
	self.hp_max = math.floor((def and def._mcl_hardness or 1) * 15)
	self.object:set_hp(self.hp_max)
	self.object:set_properties{nametag = self.description, hp_max = self.hp_max}
end

function attacknode:set_node(node, meta)
	fnode.set_node(self, node, meta)

	self:update_node()
end

function attacknode:on_activate(staticdata)
	fnode.on_activate(self, staticdata)

	self.object:set_armor_groups({fleshy = 100})
	self.object:set_acceleration({x = 0, y = 0, z = 0})

	self:update_node()
end

function attacknode:on_step(dtime)
	self.health = self.object:get_hp()
	mcl_bossbars.update_boss(self.object, self.description, "yellow")
	local pos = self.object:get_pos()

	if not self.attack_timer then
		self.attack_timer = 0.5
	end

	if self.attack_timer <= 0 then
		for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 1.0)) do
			if obj:is_player() then
				self.attack_timer = 0.5
				mcl_death_messages.player_damage(obj, obj:get_player_name() .. " was slain by " .. self.description .. ".")
				obj:punch(self.object, 0.5, {full_punch_interval = 0.5, damage_groups = {fleshy = 5}}, vector.direction(pos, obj:get_pos()))
				break
			end
		end
	else
		self.attack_timer = self.attack_timer - dtime
	end

	if self.target then
		local target_pos = self.target:get_pos()
		if self.target:get_hp() <= 0 or vector.distance(pos, target_pos) > 48 then
			self.target = nil
		else
			self.object:set_velocity(vector.multiply(vector.direction(pos, target_pos), 3))
		end
	else
		for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 48)) do
			if obj:is_player() then
				self.target = obj
				break
			end
		end
	end
end

function attacknode:on_death(killer)
	local pos = vector.round(self.object:get_pos())
	minetest.set_node(pos, self.node)
	minetest.handle_node_drops(pos, minetest.get_node_drops(self.node, killer:get_wielded_item():get_name()), killer)
	minetest.remove_node(pos)
end

minetest.register_entity("attacking_nodes:node", attacknode)

minetest.register_on_punchnode(function(pos, node)
	minetest.add_entity(pos, "attacking_nodes:node"):get_luaentity():set_node(node, minetest.get_meta(pos))
	minetest.after(0.1, minetest.remove_node, pos)
end)
