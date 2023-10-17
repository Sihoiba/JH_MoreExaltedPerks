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
        desc    = "reduces vision range",               
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

register_blueprint "mod_exalted_blinding"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "BLINDING",
        sdesc  = "melee attacks apply blinded status",
    },  
    callbacks = {
        on_activate = [=[
            function( self, entity )                      
                local has_melee = false
                for c in ecs:children( entity ) do
                    if c.weapon and (c.weapon.type == world:hash("melee") ) then
                        c:attach("apply_blinded")
                        has_melee = true
                    end
                end
                if has_melee then
                    entity:attach( "mod_exalted_blinding" )
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

register_blueprint "mod_exalted_blast_shield"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "BLASTGUARD",
        sdesc  = "reduces splash damage by 75%",
    },  
    attributes = {
        splash_mod = 0.25,
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )                
                entity:attach( "mod_exalted_blast_shield" )
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
        sdesc  = "periodically teleports to a new location",
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
        sdesc  = "spreads acid around itself",
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
        sdesc  = "spreads fire around itself",
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
        desc    = "increases reload and consumable use time by 50%, weapon swap time by 25%",               
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
        reload_time = 1.5,
        swap_time = 1.25,
        use_time = 1.5,     
    },
}

register_blueprint "mod_exalted_pressuring"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "PRESSURING",
        sdesc  = "increases players weapon swap, reload and consumable use time",
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
        sdesc  = "more health and raises a alarm when it sees the player",
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

register_blueprint "mod_exalted_crit_defence"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "CRITRESIST",
        sdesc  = "resists first 100% chance of critical hits",
    },  
    attributes = {
        crit_defence = 100,
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )                
                entity:attach( "mod_exalted_crit_defence" )
            end     
        ]=]
    },
}

register_blueprint "mod_exalted_perk_triggerhappy"
{   
    flags = { EF_NOPICKUP }, 
    text = {
        name    = "Triggerhappy",
        desc = "increases shots by 1",
    },
    attributes = {
        shots = 1,
    },
}

register_blueprint "mod_exalted_triggerhappy"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "TRIGGERHAPPY",
        sdesc  = "increases shots fired by 1 on multishot attacks",
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )                      
                local multishot = false
                for c in ecs:children( entity ) do
                    if c.weapon and c.attributes and c.attributes.shots and c.attributes.shots > 1 then                        
                        c:attach("mod_exalted_perk_triggerhappy")
                        multishot = true
                    end
                end
                if multishot then
                    entity:attach( "mod_exalted_triggerhappy" )
                end 
            end     
        ]=],
        on_die = [=[
            function( self, entity, killer, current, weapon, gibbed )
                for c in ecs:children( entity ) do
                    if c.weapon and c.attributes and c.attributes.shots > 1 then
                        for cc in ecs:children( c ) do
                            if cc:get_name() == "Triggerhappy" then
                                world:destroy(cc)
                            end
                        end 
                    end
                end
            end
        ]=]
    },
}

register_blueprint "buff_irradiated"
{
    flags = { EF_NOPICKUP }, 
    text = {
        name    = "Irradiated",
        desc    = "increases damage taken by {!+10%}/level",
    },
    callbacks = {
        on_post_command = [[
            function ( self, actor, cmt, tgt, time )
                world:callback( self )
            end
        ]],
        on_callback = [[
            function ( self )
                local time_left = self.lifetime.time_left               
                local level = math.min( math.floor( time_left / 300 ) + 1, 10 )
                self.attributes.damage_mod = 1.0 + (0.1 * level)
                self.attributes.percentage = level * 10
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
    attributes = {
        damage_mod = 1.1,
        percentage = 10
    },
    ui_buff = {
        color = LIGHTGREEN,
        attribute = "percentage",
    },
}

register_blueprint "mod_exalted_radioactive_aura"
{
    flags = { EF_NOPICKUP },    
    callbacks = {
        on_timer = [[
            function ( self, first )
                if first then return 1 end
                if not self then return 0 end
                local level    = world:get_level()
                local parent   = self:parent()
                if not level:is_alive( parent ) then 
                    world:mark_destroy( self )
                    return 0
                end
                local position = world:get_position( parent )
                local ar       = area.around( position, 1 )
                ar:clamp( level:get_area() )

                for c in ar:coords() do
                    for e in level:entities( c ) do
                        if e and e.data and e.data.ai and (e.data.ai.group == "player" or e.data.ai.group == "cri") then
                            world:add_buff( e, "buff_irradiated", 300 )
                        end
                    end
                end
                return 50
            end
        ]],
    },
}

register_blueprint "mod_exalted_radioactive"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "RADIOACTIVE",
        sdesc  = "increases damage recieved on nearby entities",
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )
                entity:attach( "mod_exalted_radioactive" )
                entity:equip( "mod_exalted_radioactive_aura" )
            end
        ]=],
    },  
}

register_blueprint "mod_exalted_dodge_buff"
{
    flags = { EF_NOPICKUP }, 
    text = {
        name = "DODGE",
        desc = "increases evasion",
    },
    ui_buff = {
        color     = LIGHTBLUE,
        attribute = "evasion",
        priority  = 100,
    },
    attributes = {
        evasion = 0,
    },
    callbacks = {
        on_action = [[
            function ( self, entity, time_passed, last )
                if time_passed > 0 then
                    local evasion = self.attributes.evasion
                    if evasion > 0 then
                        if last >= COMMAND_MOVE and last <= COMMAND_MOVE_F then
                            self.attributes.evasion = math.floor( evasion / 2 )
                        else
                            self.attributes.evasion = 0
                        end
                    end
                end
            end
        ]],
        on_move = [[
            function ( self, entity )
                self.attributes.evasion = math.min( self.attributes.evasion + 50, 100 )
            end
        ]],
    },
}

register_blueprint "mod_exalted_soldier_dodge"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "DODGE",
        sdesc  = "increases evasion on move",
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )
                entity:attach( "mod_exalted_soldier_dodge" )
                entity:equip( "mod_exalted_dodge_buff" )
            end
        ]=],
    },  
}

register_blueprint "apply_vampiric"
{
    text = {
        name    = "Apply Vampiric",
        desc = "heals on damage",
    },
    callbacks = {
        on_damage = [[
            function ( unused, weapon, who, amount, source )
                if who and who.data then                                    
                    local target_max = who.attributes.health
                    local proportion = math.min( 0.2, amount/target_max )
                    local source_max = source.attributes.health
                    source.health.current = source.health.current + math.floor( proportion * source_max )                   
                end             
            end
        ]],
    }
}

register_blueprint "mod_exalted_vampiric"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "VAMPIRIC",
        sdesc  = "attacks heal the attacker based on damage dealt",
    },  
    callbacks = {
        on_activate = [=[
            function( self, entity )                
                entity:attach( "mod_exalted_vampiric" )
                for c in ecs:children( entity ) do
                    if ( c.weapon ) then
                        c:attach("apply_vampiric")
                    end
                end
            end     
        ]=],
        on_die = [=[
            function( self, entity, killer, current, weapon, gibbed )
                for c in ecs:children( entity ) do
                    if c.weapon then
                        for cc in ecs:children( c ) do
                            if cc:get_name() == "Apply Vampiric" then
                                world:destroy(cc)
                            end
                        end 
                    end
                end
            end
        ]=]
    },
}

register_blueprint "mod_exalted_spikey"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "SPIKEY",
        sdesc  = "deals damage when hit in melee",
    }, 
    callbacks = {
        on_activate = [=[
            function( self, entity )                
                entity:attach( "mod_exalted_spikey" )                
            end     
        ]=],
        on_receive_damage = [[
            function ( self, entity, source, weapon, amount )
                if amount == 0 or not weapon then return end
                if weapon.weapon and weapon.weapon.type == world:hash("melee") then
                    if source and source:flag( EF_TARGETABLE ) then
                        world:get_level():apply_damage( entity, source, 10, ivec2(), "pierce" )                 
                    end
                end
            end
        ]],
    }
}

register_blueprint "mod_exalted_adaptive_impact_buff"
{
    flags = { EF_NOPICKUP }, 
    text = {
        name = "ADAPT-IMPACT",
        desc = "+75% impact resistance",
    },
    ui_buff = {
        color     = LIGHTBLUE,
        priority  = 100,
    },
    attributes = {
        resist = {
            impact   = 75,
        },
    },
    data = {
        adaptive_buff = true,
    },
    callbacks = {
        on_attach = [[
            function ( self, target )
                for c in ecs:children( target ) do  
                    if c~= self and c.data and c.data.adaptive_buff then
                        world:mark_destroy( c )
                    end
                end
                world:flush_destroy()
            end
        ]],
    },
}

register_blueprint "mod_exalted_adaptive_slash_buff"
{
    flags = { EF_NOPICKUP }, 
    text = {
        name = "ADAPT-SLASH",
        desc = "+75% slash resistance",
    },
    ui_buff = {
        color     = LIGHTBLUE,
        priority  = 100,
    },
    attributes = {
        resist = {
            slash   = 75,
        },
    },
    data = {
        adaptive_buff = true,
    },
    callbacks = {
        on_attach = [[
            function ( self, target )
                for c in ecs:children( target ) do
                    if c~= self and c.data and c.data.adaptive_buff then
                        world:mark_destroy( c )
                    end
                end
                world:flush_destroy()
            end
        ]],
    },
}

register_blueprint "mod_exalted_adaptive_pierce_buff"
{
    flags = { EF_NOPICKUP }, 
    text = {
        name = "ADAPT-PIERCE",
        desc = "+75% pierce resistance",
    },
    ui_buff = {
        color     = LIGHTBLUE,
        priority  = 100,
    },
    attributes = {
        resist = {
            pierce   = 75,
        },
    },
    data = {
        adaptive_buff = true,
    },
    callbacks = {
        on_attach = [[
            function ( self, target )
                for c in ecs:children( target ) do
                    if c~= self and c.data and c.data.adaptive_buff then
                        world:mark_destroy( c )
                    end
                end
                world:flush_destroy()
            end
        ]],
    },
}

register_blueprint "mod_exalted_adaptive_plasma_buff"
{
    flags = { EF_NOPICKUP }, 
    text = {
        name = "ADAPT-PLASMA",
        desc = "+75% plasma resistance",
    },
    ui_buff = {
        color     = LIGHTBLUE,
        priority  = 100,
    },
    attributes = {
        resist = {
            plasma   = 75,
        },
    },
    data = {
        adaptive_buff = true,
    },
    callbacks = {
        on_attach = [[
            function ( self, target )
                for c in ecs:children( target ) do
                    if c~= self and c.data and c.data.adaptive_buff then
                        world:mark_destroy( c )
                    end
                end
                world:flush_destroy()
            end
        ]],
    },
}

register_blueprint "mod_exalted_adaptive"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "ADAPTIVE",
        sdesc  = "gains damage resistance to last weapon damage type hit by",
    },   
    callbacks = {
        on_activate = [=[
            function( self, entity )                
                entity:attach( "mod_exalted_adaptive" )                
            end     
        ]=],
        on_receive_damage = [[
            function ( self, entity, source, weapon, amount )
                if weapon and weapon.weapon then
                    nova.log("adapting")
                    if weapon.weapon.damage_type == world:hash("impact") then
                        entity:attach("mod_exalted_adaptive_impact_buff")
                    elseif weapon.weapon.damage_type == world:hash("pierce") then                       
                        entity:attach("mod_exalted_adaptive_pierce_buff")       
                    elseif weapon.weapon.damage_type == world:hash("plasma") then
                        entity:attach("mod_exalted_adaptive_plasma_buff")
                    elseif weapon.weapon.damage_type == world:hash("slash") then
                        entity:attach("mod_exalted_adaptive_slash_buff")                    
                    end                    
                else
                    nova.log("non weapon damage adaptation cleared")
                    for c in ecs:children( entity ) do
                        if c.data and c.data.adaptive_buff then
                            world:mark_destroy( c )
                        end
                    end
                    world:flush_destroy()
                end
            end
        ]],
    }
}

register_blueprint "apply_drain"
{
    text = {
        name    = "Apply Drain",
        desc = "drains class skill",
    },
    callbacks = {
        on_damage = [[
            function ( unused, weapon, who, amount, source )
                if who and who.data and who.data.is_player then
                    local klass = gtk.get_klass_id( who )
                    local resource
                    
                    if klass == "marine" then
                        nova.log("is marine")
                        resource = who:child( "resource_fury" )
                    elseif klass == "scout" then
                        resource = who:child( "resource_energy" )
                    elseif klass == "tech" then
                        resource = who:child( "resource_power" )
                    else                
                        local klass_hash = who.progression.klass
                        nova.log(klass_hash)
                        local klass_id   = world:resolve_hash( klass_hash )
                        nova.log(klass_id)
                        local k = blueprints[ klass_id ]
                        if not k or not k.klass or not k.klass.res then
                            return
                        end
                        resource = who:child( k.klass.res )
                    end
                    
                    if not resource then 
                        return
                    end
                    
                    local rattr = resource.attributes
                    if rattr.value > 0 then
                        nova.log("draining resource")
                        rattr.value = math.max( rattr.value - 2, 0 )
                    end
                end 
            end
        ]],
    }
}

register_blueprint "mod_exalted_draining"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "DRAINING",
        sdesc  = "attacks drain class skill resource",
    },  
    callbacks = {
        on_activate = [=[
            function( self, entity )                
                entity:attach( "mod_exalted_draining" )
                for c in ecs:children( entity ) do
                    if ( c.weapon ) then
                        c:attach("apply_drain")
                    end
                end
            end     
        ]=],
        on_die = [=[
            function( self, entity, killer, current, weapon, gibbed )
                for c in ecs:children( entity ) do
                    if c.weapon then
                        for cc in ecs:children( c ) do
                            if cc:get_name() == "Apply Drain" then
                                world:destroy(cc)
                            end
                        end 
                    end
                end
            end
        ]=]
    },
}

register_blueprint "mod_exalted_empowered_buff"
{
    flags = { EF_NOPICKUP }, 
    text = {
        name    = "POWERING UP",
        desc    = "increases damage dealt by {!+10%} and speed by !{5%} every few turns to +100% damage +50% speed",
    },
    callbacks = {
        on_action = [[
            function ( self, entity, time_passed, last )
                local sattr = self.attributes
                if entity.target and entity.target.entity and entity.target.entity == world:get_player() and world:get_level():can_see_entity( entity, entity.target.entity, 8 ) then
                    sattr.encountered = true
                end
                if sattr.encountered then                   
                    if time_passed > 0 and sattr.percentage < 100 then
                        sattr.counter = sattr.counter + time_passed                    
                        if sattr.counter > 500 then
                            sattr.counter = 0                       
                            sattr.damage_mult = sattr.damage_mult + 0.1
                            sattr.move_time = sattr.move_time - 0.05
                            sattr.percentage = sattr.percentage + 10
                        end
                    end
                end 
            end
        ]],         
        on_die = [[
            function ( self )   
                world:mark_destroy( self )
            end
        ]],
    },
    attributes = {
        damage_mult = 1.0,
        move_time = 1.0,
        percentage = 0,
        counter = 0,
        encountered = false,
    },
    ui_buff = {
        color = LIGHTGREEN,
        attribute = "percentage",
    },
}

register_blueprint "mod_exalted_empowered"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "EMPOWERED",
        sdesc  = "increases damage and speed every few turns",
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )
                entity:attach( "mod_exalted_empowered" )
                entity:equip( "mod_exalted_empowered_buff" )
            end
        ]=],
    },  
}

register_blueprint "mod_exalted_gatekeeper_elevator_inactive"
{
    text = {
        short = "inactive",
        failure = "It won't open until an exalted gatekeeper has been slain!",
    },
    callbacks = {
        on_activate = [=[
            function( self, who, level )
                if who == world:get_player() then                   
                    ui:set_hint( self.text.failure, 2001, 0 )
                    world:play_voice( "vo_refuse" )
                end
                return 1
            end
        ]=],
        on_attach = [=[
            function( self, parent )
                parent.flags.data =  { EF_NOSIGHT, EF_NOMOVE, EF_NOFLY, EF_NOSHOOT, EF_BUMPACTION, EF_ACTION }
            end
        ]=],
        on_detach = [=[
            function( self, parent )
                parent.flags.data =  {}
            end
        ]=],
    },
}

register_blueprint "mod_exalted_gatekeeper"
{
    flags = { EF_NOPICKUP }, 
    text = {
        status = "GATEKEEPER",
        sdesc  = "locks main and branch elevators until it has been slain",
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )                
                local level = world:get_level()
                local lock = false
                for e in level:entities() do
                    if world:get_id( e ) == "elevator_01" or world:get_id( e ) == "elevator_01_branch" then
                        if not ( e:child("elevator_inactive") or e:child("elevator_locked") or e:child("elevator_01_off") ) then
                            if not e:child("mod_exalted_gatekeeper_elevator_inactive") then
                                e:attach("mod_exalted_gatekeeper_elevator_inactive")
                            end 
                            lock = true
                        end                         
                    end
                end     
                if lock then
                    entity:attach( "mod_exalted_gatekeeper" )                   
                end 
            end
        ]=],
        on_die = [[
            function ( self )   
                local unlocked = false
                local level = world:get_level()
                for e in level:entities() do
                    if world:get_id( e ) == "elevator_01" or world:get_id( e ) == "elevator_01_branch" then
                        local child = e:child( "mod_exalted_gatekeeper_elevator_inactive" )
                        if child then
                            world:mark_destroy( child )
                            unlocked = true
                        end
                    end
                end
                world:flush_destroy()
                if unlocked then
                    ui:set_hint( "Elevators unlocked", 2001, 0 )
                end 
            end
        ]],
    },  
}

more_exalted_test = {}

function more_exalted_test.on_entity( entity )
    local exalted_traits = {
        { "mod_exalted_adaptive", },
        { "mod_exalted_blast_shield", },
        { "mod_exalted_blinding", },
        { "mod_exalted_crit_defence", },
        { "mod_exalted_draining", },
        { "mod_exalted_empowered", },
        { "mod_exalted_gatekeeper", },
        { "mod_exalted_phasing", },
        { "mod_exalted_polluting", },
        { "mod_exalted_pressuring", },
        { "mod_exalted_radioactive", },
        { "mod_exalted_respawn", },
        { "mod_exalted_scorching", },
        { "mod_exalted_screamer", },
        { "mod_exalted_soldier_bayonette", },
        { "mod_exalted_soldier_dodge", },
        { "mod_exalted_spikey", },
        { "mod_exalted_triggerhappy", },
        { "mod_exalted_vampiric", },
    }
    if entity.data and entity.data.ai then
        make_exalted( entity, 3, exalted_traits )
    end
end

-- world.register_on_entity( more_exalted_test.on_entity )

function make_more_exalted_list( entity, list, nightmare_diff )
    
    table.insert( list, { "mod_exalted_adaptive", min = 4, } )
    table.insert( list, "mod_exalted_blast_shield" )
    table.insert( list, "mod_exalted_crit_defence" )
    table.insert( list, "mod_exalted_draining" )
    table.insert( list, { "mod_exalted_empowered", min = 2, tag = "health" } )
    table.insert( list, "mod_exalted_gatekeeper" )
    table.insert( list, "mod_exalted_phasing" )
    table.insert( list, "mod_exalted_pressuring" )
    table.insert( list, "mod_exalted_radioactive" )
    table.insert( list, { "mod_exalted_vampiric", min = 6, tag = "health" } )
    
    if entity.data and entity.data.ai and entity.data.ai.group == "zombie" then
        table.insert( list, "mod_exalted_soldier_bayonette" )
        table.insert( list, "mod_exalted_soldier_dodge" )
        table.insert( list, { "mod_exalted_screamer", tag = "health" } )
    end

    if entity.data and entity.data.ai and entity.data.ai.group == "demon" then
        table.insert( list, "mod_exalted_polluting" )
        table.insert( list, "mod_exalted_scorching" )
        table.insert( list, "mod_exalted_spikey" )
    end
    
    if entity.data and entity.data.is_mechanical then
        table.insert( list, "mod_exalted_polluting" )
        table.insert( list, { "mod_exalted_screamer", tag = "health" } )
    end

    for c in ecs:children( entity ) do
        if c.weapon and c.attributes and c.attributes.shots and c.attributes.shots > 1 then
            table.insert( list, "mod_exalted_triggerhappy" )
        end
    end 
    
    for c in ecs:children( entity ) do
        if c.weapon and (c.weapon.type == world:hash("melee") ) then
            table.insert( list, "mod_exalted_blinding" )
        end
    end         
    
    if not nightmare_diff and entity.data and not entity.data.is_mechanical then
        table.insert( list, "mod_exalted_respawn" )
    end 
end

function make_exalted( entity, dlevel, params, override )
    local keywords 
    local override  = override or {}
    if params.keywords then keywords = table.icopy( params.keywords ) end
    local count     = override.count or params.count
    local danger    = params.danger or 0
    local nightmare_diff = false

    -- nightmare hack
    if dlevel > 1000 then
        count  = math.floor( dlevel / 1000 )
        dlevel = dlevel - count * 1000
        if count > 3 then count = 3 end
        nightmare_diff = true
    end

    if not keywords then
        keywords = {            
        }
        if not count then
            count = math.floor( ( dlevel - danger ) / 8 ) + 1
            if math.random( 100 ) < ( DIFFICULTY + 1 ) * 10 then
                count = count + 1
            end
            count = math.min( math.max( 1, count ), 3 )
        end

        local list = {}
        make_more_exalted_list( entity, list, nightmare_diff )
        
        for _,k in ipairs( params ) do
            if ((not k.min) or k.min <= dlevel ) then
                table.insert( list, k )
            end
        end

        while count > 0 and #list > 0 do
            local entry = table.remove( list, math.random( #list ) )
            if type( entry ) == "string" then
                table.insert( keywords, entry )
            else
                table.insert( keywords, entry[1] )
                if entry.tag then
                    table.iremove_if( list, function(t,i) return t[i].tag == entry.tag end )
                end     
            end
            count = count - 1
        end
    end
    entity.data.exalted = keywords
    apply_exalted( entity, keywords )
    return keywords
end