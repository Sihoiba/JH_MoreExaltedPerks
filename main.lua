function insertFlags( flag )
    if entity and entity.flags and entity.flags.data then
        local flags = entity.flags.data
        table.insert(flags, flag)
        entity.flags.data = flags
    end
end

function safe_phase_coord_spiral_out( self, start_coord, min_range, max_range )
    local max_range = max_range or 6
    local min_range = min_range or 1
    
    local floor_id = self:get_nid( "floor" )
    local function can_spawn( p, c )
        if self:raw_get_cell( c ) ~= floor_id then return false end
        if self:get_cell_flags( c )[ EF_NOSPAWN ] then return false end
        if self:get_cell_flags( c )[ EF_NOMOVE ] then return false end
        local being = world:get_level():get_being( c )              
        if being then return false end
        for e in world:get_level():entities( c ) do
            if e.flags and e.flags.data and e.flags.data [ EF_NOMOVE ] then 
                return false 
            end
            if e.data and e.data.is_player then 
                return false 
            end
        end
        if not p then return true end

        local pc = p - c
        if pc.x < 0 then pc.x = -pc.x end
        if pc.y < 0 then pc.y = -pc.y end
        return pc.x <= max_range or pc.y <= max_range
    end
    
    local function spiral_get_values(min_dist, max_dist)
        local cx = 0
        local cy = 0
        local d = 1
        local m = min_dist
        local spiral_coords = {}
        while cx <= max_dist and cy <= max_dist do
            while (2 * cx * d) < m do
                table.insert(spiral_coords, {x=cx, y=cy})
                cx = cx + d
            end
            while (2 * cy * d) < m do
                table.insert(spiral_coords, {x=cx, y=cy})
                cy = cy + d
            end
            d = -1 * d
            m = m + 1           
        end
        return spiral_coords
    end
    
    local p = start_coord
    if can_spawn( p, p ) then
        return p
    end
    
    local spawn_coords = spiral_get_values(min_range, max_range)
    local abort = 0
    while next(spawn_coords) ~= nil do
        if abort > 256 then
            return
        end 
        local coord = table.remove( spawn_coords, math.random( #spawn_coords ) ) 
        p.x = start_coord.x + coord.x
        p.y = start_coord.y + coord.y
        nova.log("Checking "..tostring(p.x)..","..tostring(p.y))
        if can_spawn( start_coord, p ) then
            return p
        end
        abort = abort + 1
    end
end

register_blueprint "buff_blinded"
{
    flags = { EF_NOPICKUP }, 
    text = {
        name    = "Blinded",
        desc    = "Reduces vision range",               
    },
    callbacks = {
        on_attach = [[
            function ( self, target )
                local level = world:get_level()
                self.attributes.vision = -( target:attribute( "vision" ) - ( level.level_info.light_range -3 ) ) 
                self.attributes.min_vision = - ( target:attribute("min_vision" ) - 2 )
            end
        ]], 
        on_die = [[
            function ( self )   
                world:mark_destroy( self )
            end
        ]],
        on_enter_level = [[
            function ( self )           
                world:mark_destroy( self )
            end
        ]],
    },
    ui_buff = {
        color = WHITE,      
        style = 1,
    },
    attributes = {      
    },
}

register_blueprint "apply_blinded"
{
    callbacks = {
        on_damage = [[
            function ( unused, weapon, who, amount, source )
                if who and who.data and who.data.is_player then                 
                    world:add_buff( who, "buff_blinded", 500 )
                end             
            end
        ]],
    }
}

register_blueprint "mod_exalted_kw_blinding"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "BLINDING",
        sdesc  = "Attacks apply blinded status",
    },  
    callbacks = {
        on_activate = [=[
            function( self, entity )                
                entity:attach( "mod_exalted_kw_blinding" )
                for c in ecs:children( entity ) do
                    if ( c.weapon ) then
                        c:attach("apply_blinded")
                    end
                end
            end     
        ]=]
    },
}

register_blueprint "runtime_drop_weapon_on_death"
{
    flags = { EF_NOPICKUP },
    callbacks = {       
        on_die = [[
            function( self, killer, current, weapon )
                for c in ecs:children( ecs:parent( self ) ) do
                    if ( c.weapon ) then
                        world:get_level():drop_item( ecs:parent( self ), c )
                    end
                end
                return 0
            end
        ]],
    }
}

register_blueprint "mod_exalted_soldier_bayonette"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "BAYONETTE",
        sdesc  = "dangerous melee attack",
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )                
                entity:attach( "mod_exalted_soldier_bayonette" )
                entity:attach( "runtime_drop_weapon_on_death" )
            end     
        ]=],
    },
    weapon = {
        group = "melee",
        type  = "melee",
        natural = true,
        damage_type = "pierce",
        fire_sound = "knife_swing",
    },
    attributes = {
        damage    = 20,
    }
}

register_blueprint "mod_exalted_soldier_blast_shield"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "BLASTGUARD",
        sdesc  = "Reduces splash damage by 75%",
    },  
    attributes = {
        splash_mod = 0.25,
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )                
                entity:attach( "mod_exalted_soldier_blast_shield" )
            end     
        ]=]
    },
}

register_blueprint "exalted_tainted_mark"
{
    flags = { EF_NOPICKUP, EF_MARK }, 
    attributes = {
        counter = 0,
    },
    data = {
        nightmare_marker = true,
        nightmare = {},
    },    
    minimap = {
        color    = tcolor( MAGENTA, ivec3( 100, 0, 100 ) ),
        vision   = true,
        priority = 80,
    },
    callbacks = {
        on_timer = [[
            function ( self, first )
                if first then return 500 end
                local level = world:get_level()
                local pos   = world:get_position( self )
                if not level:is_visible( pos ) then
                    self.attributes.counter = self.attributes.counter - 1
                    if self.attributes.counter <= 0 then
                        local ndata = self.data.nightmare
                        if ndata.id then
                            local summon = level:add_entity( ndata.id, pos, nil, ndata.tier * 1000 + ndata.depth + ndata.tier * 2 )
                            summon.data.resurrected = true
                            summon.attributes.experience_value = ndata.xp
                            summon.data.exalted = nil
                            local hmul = math.min( 1.0, 0.5 + 0.02 * ( ndata.depth + ndata.tier * 3 - 3 ) )
                            summon.attributes.health = math.ceil( summon.attributes.health * hmul )
                            summon.health.current    = math.ceil( summon.health.current * hmul )
                            summon:equip( self )
                            if ndata.track then
                                summon:equip("tracker")
                                summon.minimap.always = true
                            end                   
                        end
                        return 0
                    end
                end
                return 500
            end
        ]],
        on_die = [[
            function( self, e, k, r, w, gibbed )
                local entity = ecs:parent( self )
                world:wipe_inventory( entity )
                world:mark_destroy( self )
            end
        ]],
    },  
}

register_blueprint "mod_exalted_respawn"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "TAINTED",
        sdesc  = "this enemy will respawn as an exalted variant some time after death",
    }, 
    callbacks = {
        on_activate = [=[
            function( self, entity )                
                entity:attach( "mod_exalted_respawn" )
            end     
        ]=],
        on_die = [=[
            function( self, entity, killer, current, weapon, gibbed )
                if not gibbed and entity.data and entity.data.nightmare then
                    local c     = world:get_position( entity )
                    local level = world:get_level()
                    entity.flags.data[ EF_NOMOVE ] = false
                    local drop  = level:drop_coord( c, EF_MARK )
                    local n1    = level:place_entity( "exalted_tainted_mark", drop )
                    if n1 then
                        n1.data.nightmare.id    = entity.data.nightmare.id
                        n1.data.nightmare.tier  = 1
                        n1.data.nightmare.depth = level.level_info.dlevel
                        n1.data.nightmare.xp    = 0
                        local mod = 1
                        n1.attributes.counter   = ( 20 + math.random( 10 ) ) * mod
                        if entity:child("tracker") then
                            n1.data.nightmare.track = true
                            n1.minimap.always       = true
                        end
                    end
                end
            end
        ]=],
    },  
}

register_blueprint "mod_exalted_phasing"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "PHASING",
        sdesc  = "Periodically teleports to a new location",
    },  
    attributes = {      
        counter = 0,
    },
    callbacks = {
        on_activate = [[
            function( self, entity )                
                entity:attach( "mod_exalted_phasing" )              
            end     
        ]],     
        on_action = [[
            function ( self, entity, time_passed, last )
				local level = world:get_level()
				local player = world:get_player()
                if time_passed > 0 and entity.target and entity.target.entity and entity.target.entity == player and level:can_see_entity( entity, entity.target.entity, 8 ) then
                    local sattr = self.attributes
                    sattr.counter = sattr.counter + time_passed
					local entityPos = world:get_position( entity )
                    if sattr.counter > 500 and ( last < COMMAND_MOVE or last > COMMAND_MOVE_F ) and level:distance( entity, player ) > 2 then
                        sattr.counter = 0
                        local t = safe_phase_coord_spiral_out( level, entityPos, 2, 3 )
                        if t then
                            world:play_sound( "summon", entity )
                            ui:spawn_fx( entity, "fx_teleport", entity )
                            level:hard_place_entity( entity, t )                            
                            level.level_info.enemies = level.level_info.enemies - 1 
                        end 
                    end
                end
            end
        ]],
    },
}

register_blueprint "mod_exalted_polluting"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "POLLUTING",
        sdesc  = "Spreads acid around itself",
    },  
    attributes = {      
        counter = 0,
		resist = {
			acid   = 100,		
		},
    },
    callbacks = {
        on_activate = [[
            function( self, entity )                
                entity:attach( "mod_exalted_polluting" )              
            end     
        ]],     
        on_action = [[
            function ( self, entity, time_passed, last )
				local level = world:get_level()
				local player = world:get_player()
                if time_passed > 0 then
                    local sattr = self.attributes
                    sattr.counter = sattr.counter + time_passed
					local entityPos = world:get_position( entity )
                    if sattr.counter > 150 then
                        sattr.counter = 0
                        local t = safe_phase_coord_spiral_out( level, entityPos, 1, 2 )
                        if t then
							ui:spawn_fx( entity, "ps_broken_sparks", entity )
                            local pool = level:get_entity( t, "acid_pool" )
							if not pool then
								pool = level:place_entity( "acid_pool", t )
							end
							pool.attributes.acid_amount = 10
							pool.lifetime.time_left = math.max( pool.lifetime.time_left, 1000 + math.random(100) )
                        end 
                    end
                end
            end
        ]],
    },
}

register_blueprint "mod_exalted_scorching"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "SCORCHING",
        sdesc  = "Spreads fire around itself",
    },  
    attributes = {      
        counter = 0,
		resist = {			
			ignite = 100,
			cold   = -100
		},
    },
    callbacks = {
        on_activate = [[
            function( self, entity )                
                entity:attach( "mod_exalted_scorching" )              
            end     
        ]],     
        on_action = [[
            function ( self, entity, time_passed, last )
				local level = world:get_level()
				local player = world:get_player()
                if time_passed > 0 then
                    local sattr = self.attributes
                    sattr.counter = sattr.counter + time_passed
					local entityPos = world:get_position( entity )
                    if sattr.counter > 150 then
                        sattr.counter = 0
                        local t = safe_phase_coord_spiral_out( level, entityPos, 1, 2 )
                        if t then
							ui:spawn_fx( entity, "burning_smoke", entity )					
                            gtk.place_flames( t, 10, 1000 + math.random(100) )							
                        end 
                    end
                end
            end
        ]],
    },
}

register_blueprint "buff_pressured"
{
    flags = { EF_NOPICKUP }, 
    text = {
        name    = "Pressured",
        desc    = "Increases reload and consumable use time by 50%, weapon swap time by 25%",               
    },
    callbacks = {
        on_die = [[
            function ( self )   
                world:mark_destroy( self )
            end
        ]],
        on_enter_level = [[
            function ( self )           
                world:mark_destroy( self )
            end
        ]],
    },
    ui_buff = {
        color = LIGHTRED,
		priority = -1,
    },
    attributes = {
		reload_time	= 1.5,
		swap_time = 1.25,
		use_time = 1.5,		
    },
}

register_blueprint "mod_exalted_pressuring"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "PRESSURING",
        sdesc  = "Increases players weapon swap, reload and consumable use time",
    },  
    callbacks = {
        on_activate = [[
            function( self, entity )                
                entity:attach( "mod_exalted_pressuring" )              
            end     
        ]],   
		on_post_command = [=[
			function ( self, actor, cmt, tgt, time )
				local level = world:get_level()
				for b in level:targets( actor, 32 ) do 
					if b.data then
						local data = b.data
						if data.ai and data.ai.group == "player" then
							world:add_buff( b, "buff_pressured", 101, true )
						end
					end
				end
			end
		]=],
	}
}

register_blueprint "scream"
{
	attributes = {
		damage     = 0,
		explosion  = -1,		
		gib_factor = 0.0,
	},
	weapon = {
		group       = "env",
		damage_type = "impact",
		natural     = true,
		fire_sound  = "scream",
	},
	noise = {
		use = 25,
	},
}

register_blueprint "mod_exalted_screamer"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "ALERTING",
        sdesc  = "More health and raises a alarm when it sees the player",
    },  
    callbacks = {
        on_activate = [[
            function( self, entity )
				local attr = entity.attributes
		        entity.health.current = math.ceil( attr.health * 1.25 )
                entity:attach( "mod_exalted_screamer" )              
            end     
        ]],   
		on_post_command = [=[
			function ( self, actor, cmt, tgt, time )
				local level = world:get_level()
				for b in level:targets( actor, 32 ) do 
					if b.data then
						local data = b.data
						if data.ai and data.ai.group == "player" then
							local p   = actor:get_position()
							local w   = world:create_entity( "scream" )
							actor:attach( w )
							world:get_level():fire( actor, p, w )
							world:destroy( w )
						end
					end
				end
			end
		]=],
	}
}

more_exalted_test = {}

function more_exalted_test.on_entity( entity )
    local exalted_traits = {
        -- { "mod_exalted_soldier_bayonette", },
        -- { "mod_exalted_soldier_blast_shield", },
        -- { "mod_exalted_kw_blinding", },
        -- { "mod_exalted_respawn", },
        -- { "mod_exalted_phasing", },
		-- { "mod_exalted_polluting", },
		-- { "mod_exalted_scorching", },
		-- { "mod_exalted_pressuring", }
		{ "mod_exalted_screamer", }
    }
    if entity.data and entity.data.ai and entity.data.ai.group == "zombie" then
        make_exalted( entity, 1, exalted_traits )
    end
end

world.register_on_entity( more_exalted_test.on_entity )