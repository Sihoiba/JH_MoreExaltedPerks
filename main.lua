function insertFlags( flag )
    if entity and entity.flags and entity.flags.data then
        local flags = entity.flags.data
        table.insert(flags, flag)
        entity.flags.data = flags
    end
end

register_blueprint "buff_dazzled_1"
{
    flags = { EF_NOPICKUP },
    text = {
        name    = "Dazzled",
        desc    = "reduces vision range",
    },
    callbacks = {
        on_attach = [[
            function ( self, target )
                local d3 = target:child("buff_dazzled_3")
                if d3 then
                    world:mark_destroy( self )
                else
                    local level = world:get_level()
                    self.attributes.vision = -( target:attribute( "vision" ) - ( level.level_info.light_range -1 ) )
                    self.attributes.min_vision = - ( target:attribute("min_vision" ) - 1 )
                end
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
        attribute = "level",
    },
    attributes = {
        level = 1,
    },
}

register_blueprint "buff_dazzled_3"
{
    flags = { EF_NOPICKUP },
    text = {
        name    = "Dazzled",
        desc    = "reduces vision range",
    },
    callbacks = {
        on_attach = [[
            function ( self, target )
                local level = world:get_level()
                self.attributes.vision = -( target:attribute( "vision" ) - ( level.level_info.light_range -3 ) )
                self.attributes.min_vision = - ( target:attribute("min_vision" ) - 2 )
                local d1 = target:child("buff_dazzled_1")
                if d1 then
                    world:mark_destroy( d1 )
                end
                world:flush_destroy()
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
        attribute = "level",
    },
    attributes = {
        level = 3,
    },
}

register_blueprint "apply_dazzled"
{
    callbacks = {
        on_damage = [[
            function ( unused, weapon, who, amount, source )
                if who and who.data and who.data.is_player then
                    if weapon.weapon and weapon.weapon.type == world:hash("melee") then
                        world:add_buff( who, "buff_dazzled_3", 500 )
                    else
                        world:add_buff( who, "buff_dazzled_1", 200 )
                    end
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
        sdesc  = "attacks reduce vision range",
    },
    data = {
        check_precommand = true,
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )
                nova.log("Attaching blinding")
                for c in ecs:children( entity ) do
                    if c.weapon then
                        c:attach("apply_dazzled")
                    end
                end
                entity:attach( "mod_exalted_blinding" )
            end
        ]=],
        -- attach dazzling to weapons added after this exalted perk
        on_pre_command = [=[
            function ( self, actor, cmt, tgt )
                if self.data.check_precommand then
                    for c in ecs:children( actor ) do
                        if c.weapon and not c:child( "apply_dazzled" )then
                            c:attach( "apply_dazzled" )
                        end
                    end
                    self.data.check_precommand = false
                end
            end
        ]=],
        on_die = [=[
            function( self, entity, killer, current, weapon, gibbed )
                for c in ecs:children( entity ) do
                    local blinding_perk = c:child( "apply_dazzled" )
                    if blinding_perk then
                        world:destroy( blinding_perk )
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

register_blueprint "mod_exalted_soldier_bayonet"
{
    flags = { EF_NOPICKUP },
    text = {
        status = "BAYONET",
        sdesc  = "dangerous melee attack",
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )
                nova.log("Attaching bayonette")
                entity:attach( "mod_exalted_soldier_bayonet" )
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
                nova.log("Attaching blastshield")
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
                -- nova.log("exalted tainted on timer")
                if first then return 500 end
                local level = world:get_level()
                local pos   = world:get_position( self )
                if not level:is_visible( pos ) then
                    self.attributes.counter = self.attributes.counter - 1
                    if self.attributes.counter <= 0 then
                        local ndata = self.data.nightmare
                        if ndata.id then
                            nova.log("add entity with "..(ndata.depth + ndata.tier * 2))
                            local summon = level:add_entity( ndata.id, pos, nil, ndata.depth + ndata.tier * 2 )
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
                        -- nova.log("exalted tainted on done")
                        return 0
                    end
                end
                -- nova.log("exalted tainted on done")
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
                        local ep = world.data.level[ world.data.current ].episode
                        n1.data.nightmare.tier  = ep + 1
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
                nova.log("Attaching phasing")
                entity:attach( "mod_exalted_phasing" )
            end
        ]],
        on_attach = [[
            function ( self, target )
                local random_start = {100, 200, 250}
                self.attributes.counter = table.remove( random_start, math.random( #random_start ) )
            end
        ]],
        on_action = [[
            function ( self, entity, time_passed, last )
                local level = world:get_level()
                local player = world:get_player()
                local enemy_count = level.level_info.enemies * 1
                -- nova.log("on action mod phasing count before: "..enemy_count)
                if time_passed > 0 and entity.target and entity.target.entity and entity.target.entity == player and level:can_see_entity( entity, entity.target.entity, 8 ) then
                    local sattr = self.attributes
                    sattr.counter = sattr.counter + time_passed
                    local entityPos = world:get_position( entity )
                    if sattr.counter >= 250 and ( last < COMMAND_MOVE or last > COMMAND_MOVE_F ) and level:distance( entity, player ) > 2 then
                        sattr.counter = 0
                        local t = gtk.random_near_coord( entityPos, 3 )
                        if t then
                            world:play_sound( "summon", entity )
                            ui:spawn_fx( entity, "fx_teleport", entity )
                            level:hard_place_entity( entity, t )
                            -- nova.log("mod phasing level.level_info.enemies: "..level.level_info.enemies)
                            level.level_info.enemies = enemy_count
                            -- nova.log("adjusted mod phasing level.level_info.enemies: "..level.level_info.enemies)
                        end
                    end
                end
                -- Enemies phasing inside the frozen temple work around
                if time_passed > 0 and level.attributes and level.attributes.temple_open == 0 and entity.target and entity.target.entity and entity.target.entity == player and not level:can_see_entity( entity, entity.target.entity, 8 ) then
                    local sattr = self.attributes
                    sattr.counter = sattr.counter + time_passed
                    local entityPos = world:get_position( entity )
                    if sattr.counter >= 250 then
                        sattr.counter = 0
                        local t = gtk.random_near_coord( entityPos, 3 )
                        if t then
                            world:play_sound( "summon", entity )
                            ui:spawn_fx( entity, "fx_teleport", entity )
                            level:hard_place_entity( entity, t )
                            -- nova.log("mod phasing level.level_info.enemies: "..level.level_info.enemies)
                            level.level_info.enemies = enemy_count
                            -- nova.log("adjusted mod phasing level.level_info.enemies: "..level.level_info.enemies)
                        end
                    end
                end
                -- nova.log("on action mod phasing count after: "..enemy_count)
            end
        ]],
        on_receive_damage = [[
            function ( self, source, weapon, amount )
                if not self then return end

                local entity = self:parent()
                local level = world:get_level()
                local enemy_count = level.level_info.enemies * 1
                local player = world:get_player()
                local eh = entity.health

                if eh.current > 0 and level:can_see_entity( entity, player, 8 ) then
                    local sattr = self.attributes
                    local entityPos = world:get_position( entity )
                    if sattr.counter >= 100 then
                        local t = gtk.random_near_coord( entityPos, 3 )
                        if t then
                            world:play_sound( "summon", entity )
                            ui:spawn_fx( entity, "fx_teleport", entity )
                            level:hard_place_entity( entity, t )
                            level.level_info.enemies = enemy_count
                        end
                    end
                end
                -- nova.log("on damage mod phasing count after: "..enemy_count)
            end
        ]],
    },
}

register_blueprint "buff_pressured"
{
    flags = { EF_NOPICKUP },
    text = {
        name    = "Pressured",
        desc    = "increases reload and consumable use time by 50%, weapon swap time by 200%",
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
        swap_time = 2,
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
                -- nova.log("pressured on post command")
                if actor.data and actor.data.disabled then
                    return
                end
                if actor:child( "disabled" ) or actor:child( "friendly" ) then
                    return
                end
                local level = world:get_level()
                for b in level:targets( actor, 32 ) do
                    if b.data then
                        local data = b.data
                        if data.ai and data.ai.group == "player" then
                            world:add_buff( b, "buff_pressured", 101, true )
                        end
                    end
                end
                -- nova.log("pressured on post command done")
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

register_blueprint "alerted"
{
    flags = { EF_NOPICKUP },
    text = {
        status = "Alerted",
        sdesc  = "Has been alerted to the player",
    },
    callbacks = {
        on_timer = [[
            function ( self, first )
                if first then return 100 end
                local e = ecs:parent( self )
                if (e.data.ai.state ~= "find" or e.data.ai.state ~= "hunt") and e.target.entity ~= world:get_player() and not e:child( "friendly" ) then
                   e.target.entity = world:get_player()
                   e.data.ai.state = "hunt"
                end
                return 0
            end
        ]]
    }
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
                -- nova.log("alerting on post command")
                local level = world:get_level()
                if actor.data and actor.data.disabled then
                    return
                end
                if actor:child( "disabled" ) or actor:child( "friendly" ) then
                    return
                end
                for b in level:targets( actor, 32 ) do
                    if b.data then
                        local data = b.data
                        if data.ai and data.ai.group == "player" then
                            local p   = actor:get_position()
                            local w   = world:create_entity( "scream" )
                            actor:attach( w )
                            world:get_level():fire( actor, p, w )
                            world:destroy( w )

                            for e in level:beings() do
                                if e ~= actor and e.data and actor.data and e.data.ai and actor.data.ai and e.data.ai.group == actor.data.ai.group and e.data.ai.state ~= "find" and e.target.entity ~= world:get_player() and not e:child( "friendly" ) and not e:child( "alerted" ) and world:get_id( entity ) ~= "mimir_sentry_bot" and world:get_id( entity ) ~= "asterius_sentry_bot" then
                                    nova.log("One enemy is alerted and hunting: "..e:get_name())
                                    e.target.entity = world:get_player()
                                    e.data.ai.state = "find"
                                    e:attach( "alerted" )
                                    break
                                end
                            end
                        end
                    end
                end
                -- nova.log("alerting on post command done")
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
        desc = "increases shots by 2",
    },
    attributes = {
        shots = 2,
    },
}

register_blueprint "mod_exalted_triggerhappy"
{
    flags = { EF_NOPICKUP },
    text = {
        status = "TRIGGERHAPPY",
        sdesc  = "increases shots fired by 2 on multishot attacks",
    },
    data = {
        check_precommand = true,
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
        -- attach triggerhappy to weapons added after this exalted perk
        on_pre_command = [=[
            function ( self, actor, cmt, tgt )
                if self.data.check_precommand then
                    for c in ecs:children( actor ) do
                        if c.weapon and c.attributes and c.attributes.shots and c.attributes.shots > 1 and not c:child( "mod_exalted_perk_triggerhappy" )then
                            c:attach( "mod_exalted_perk_triggerhappy" )
                        end
                    end
                    self.data.check_precommand = false
                end
            end
        ]=],
        on_die = [=[
            function( self, entity, killer, current, weapon, gibbed )
                for c in ecs:children( entity ) do
                    local trigger_perk = c:child( "mod_exalted_perk_triggerhappy" )
                    if trigger_perk then
                        world:destroy( trigger_perk )
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
        desc    = "increases damage taken by irradiated percentage",
    },
    callbacks = {
        on_post_command = [[
            function ( self, actor, cmt, tgt, time )
                -- nova.log("radiation on post command")
                world:callback( self )
                -- nova.log("radiation on post command done")
            end
        ]],
        on_callback = [[
            function ( self )
                local time_left = self.lifetime.time_left
                local level = math.min( math.floor( time_left / 200 ) + 1, 10 )
                self.attributes.damage_mod = 1.0 + (0.05 * level)
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
                -- nova.log("radiation on timer")
                if first then return 1 end
                if not self then return 0 end
                local level    = world:get_level()
                local parent   = self:parent()
                if not level:is_alive( parent ) then
                    world:mark_destroy( self )
                    -- nova.log("radiation on done")
                    return 0
                end
                local position = world:get_position( parent )
                local ar       = area.around( position, 2 )
                ar:clamp( level:get_area() )

                for c in ar:coords() do
                    for e in level:entities( c ) do
                        if e and e.data and e.data.ai and (e.data.ai.group == "player" or (e.data.ai.group == "cri" and not e.data.is_mechanical and not e:child(mod_exalted_radioactive) ) ) then
                            world:add_buff( e, "buff_irradiated", (200/level:distance( parent, e )) )
                        end
                    end
                end
                -- nova.log("radiation on done")
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
        sdesc  = "increases damage recieved on nearby entities, movement is {!5%} faster",
    },
    attributes = {
        move_time = 0.95,
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
                -- nova.log("Exalted dodge checking")
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
                -- nova.log("Exalted dodge done")
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
    data = {
        check_precommand = true,
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )
                entity:attach( "mod_exalted_vampiric" )
                for c in ecs:children( entity ) do
                    if ( c.weapon ) then
                        c:attach( "apply_vampiric" )
                    end
                end
            end
        ]=],
        -- attach vampiric to weapons added after this exalted perk
        on_pre_command = [=[
            function ( self, actor, cmt, tgt )
                if self.data.check_precommand then
                    for c in ecs:children( actor ) do
                        if c.weapon and not c:child( "apply_vampiric" )then
                            c:attach( "apply_vampiric" )
                        end
                    end
                    self.data.check_precommand = false
                end
            end
        ]=],
        on_die = [=[
            function( self, entity, killer, current, weapon, gibbed )
                for c in ecs:children( entity ) do
                    local vampiric_perk = c:child( "apply_vampiric" )
                    if vampiric_perk then
                        world:destroy( vampiric_perk )
                    end
                end
            end
        ]=]
    },
}

register_blueprint "mod_exalted_spiky"
{
    flags = { EF_NOPICKUP },
    text = {
        status = "SPIKY",
        sdesc  = "deals damage when hit in melee",
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )
                entity:attach( "mod_exalted_spiky" )
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
    },
    health = {},
    armor = {},
    attributes = {
        armor = {
            2
        },
    },
}

register_blueprint "apply_drain_1"
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
                        resource = who:child( "resource_fury" )
                    elseif klass == "scout" then
                        resource = who:child( "resource_energy" )
                    elseif klass == "tech" then
                        resource = who:child( "resource_power" )
                    else
                        local klass_hash = who.progression.klass
                        local klass_id   = world:resolve_hash( klass_hash )
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
                        rattr.value = math.max( rattr.value - 2, 0 )
                    end
                end
            end
        ]],
    }
}

register_blueprint "apply_drain_4"
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
                        resource = who:child( "resource_fury" )
                    elseif klass == "scout" then
                        resource = who:child( "resource_energy" )
                    elseif klass == "tech" then
                        resource = who:child( "resource_power" )
                    else
                        local klass_hash = who.progression.klass
                        local klass_id   = world:resolve_hash( klass_hash )
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
                        rattr.value = math.max( rattr.value - 5, 0 )
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
    data = {
        check_precommand = true,
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )
                entity:attach( "mod_exalted_draining" )
                for c in ecs:children( entity ) do
                    if ( c.weapon ) then
                        if c.attributes and c.attributes.shots and c.attributes.shots > 1 then
                            c:attach("apply_drain_1")
                        else
                            c:attach("apply_drain_4")
                        end
                    end
                end
            end
        ]=],
        -- attach drain to weapons added after this exalted perk
        on_pre_command = [=[
            function ( self, actor, cmt, tgt )
                if self.data.check_precommand then
                    for c in ecs:children( actor ) do
                        if c.weapon and not ( c:child( "apply_drain_1" ) or c:child( "apply_drain_4" ) ) then
                            if c.attributes and c.attributes.shots and c.attributes.shots > 1 then
                                c:attach("apply_drain_1")
                            else
                                c:attach("apply_drain_4")
                            end
                        end
                    end
                    self.data.check_precommand = false
                end
            end
        ]=],
        on_die = [=[
            function( self, entity, killer, current, weapon, gibbed )
                for c in ecs:children( entity ) do
                    local drain_perk = c:child( "apply_drain_1" )
                    if not drain_perk then
                        drain_perk = c:child( "apply_drain_4" )
                    end
                    if drain_perk then
                        world:destroy( drain_perk )
                    end
                end
            end
        ]=]
    },
}

register_blueprint "power_up_10" {
    flags = { EF_NOPICKUP },
    callbacks = {
        on_die = [[
            function ( self )
                world:mark_destroy( self )
            end
        ]],
    }
}

register_blueprint "power_up_20" {
    flags = { EF_NOPICKUP },
    callbacks = {
        on_die = [[
            function ( self )
                world:mark_destroy( self )
            end
        ]],
    }
}

register_blueprint "power_up_40" {
    flags = { EF_NOPICKUP },
    callbacks = {
        on_die = [[
            function ( self )
                world:mark_destroy( self )
            end
        ]],
    }
}

register_blueprint "power_up_60" {
    flags = { EF_NOPICKUP },
    callbacks = {
        on_die = [[
            function ( self )
                world:mark_destroy( self )
            end
        ]],
    }
}

register_blueprint "power_up_80" {
    flags = { EF_NOPICKUP },
    callbacks = {
        on_die = [[
            function ( self )
                world:mark_destroy( self )
            end
        ]],
    }
}

register_blueprint "power_up_100" {
    flags = { EF_NOPICKUP },
    callbacks = {
        on_die = [[
            function ( self )
                world:mark_destroy( self )
            end
        ]],
    }
}

register_blueprint "mod_exalted_empowered_buff"
{
    flags = { EF_NOPICKUP },
    text = {
        name    = "POWERING UP",
        desc    = "increases damage dealt by {!+10%} and speed by {!5%} every few turns to {!+100%} damage {!+50%} speed",
    },
    callbacks = {
        on_action = [[
            function ( self, entity, time_passed, last )
                nova.log("Empowered on action "..entity:get_name().." "..self.get_name())
                local sattr = self.attributes
                if entity.target and entity.target.entity and entity.target.entity == world:get_player() and world:get_level():can_see_entity( entity, entity.target.entity, 8 ) then
                    nova.log("Empowered encountered player")
                    sattr.encountered = true
                end
                if sattr.encountered then
                    if time_passed > 0 and sattr.percentage < 100 then
                        sattr.counter = sattr.counter + time_passed
                        if sattr.percentage == 0 then
                            sattr.damage_mult = sattr.damage_mult + 0.1
                            sattr.move_time = sattr.move_time - 0.05
                            sattr.percentage = sattr.percentage + 10
                        end
                        if sattr.counter > 300 then
                            sattr.counter = 0
                            sattr.damage_mult = sattr.damage_mult + 0.1
                            sattr.move_time = sattr.move_time - 0.05
                            sattr.percentage = sattr.percentage + 10
                        end
                    end
                    if sattr.percentage == 10 and not entity:child("power_up_10") then
                        entity:equip("power_up_10")
                    elseif sattr.percentage == 20 and not entity:child("power_up_20") then
                        entity:equip("power_up_20")
                        local prev = entity:child("power_up_10")
                        if prev then
                            world:destroy(prev)
                        end
                    elseif sattr.percentage == 40 and not entity:child("power_up_40")  then
                        entity:equip("power_up_40")
                        local prev = entity:child("power_up_20")
                        if prev then
                            world:destroy(prev)
                        end
                    elseif sattr.percentage == 60 and not entity:child("power_up_60") then
                        entity:equip("power_up_60")
                        local prev = entity:child("power_up_40")
                        if prev then
                            world:destroy(prev)
                        end
                    elseif sattr.percentage == 80 and not entity:child("power_up_80") then
                        entity:equip("power_up_80")
                        local prev = entity:child("power_up_60")
                        if prev then
                            world:destroy(prev)
                        end
                    elseif sattr.percentage == 100 and not entity:child("power_up_100") then
                        entity:equip("power_up_100")
                        local prev = entity:child("power_up_80")
                        if prev then
                            world:destroy(prev)
                        end
                    end
                end
                -- nova.log("Empowered done")
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

register_blueprint "mod_exalted_sniper_buff"
{
    flags = { EF_NOPICKUP },
    text = {
        name = "SNIPING",
        desc = "increases accuracy, damage and evasion",
    },
    ui_buff = {
        color     = LIGHTBLUE,
        attribute = "percentage",
        priority  = 100,
    },
    attributes = {
        accuracy = 0,
        damage_mult = 1.0,
        evasion = 0,
        percentage = 0,
    },
    callbacks = {
        on_pre_command = [=[
            function ( self, actor, cmt, tgt )
                local level = world:get_level()
                local player = world:get_player()
                local light_range = level.level_info.light_range
                if level:can_see_entity( actor, player, 8 ) then
                    local distance = math.min( level:distance( actor, player ), light_range )
                    local factor = math.max( ( distance - 2 )/( light_range -2 ), 0 )
                    nova.log("distance: "..distance..", lightrange: "..light_range..", factor: "..factor)
                    self.attributes.accuracy = math.ceil( 25 * factor )
                    self.attributes.damage_mult = 1 + ( 0.50 * factor )
                    self.attributes.evasion = math.ceil( 50 * factor )
                    self.attributes.percentage = math.ceil( 100 * factor )
                end
            end
        ]=],
        on_move = [[
            function ( self, entity )
                local level = world:get_level()
                local player = world:get_player()
                local light_range = level.level_info.light_range
                if level:can_see_entity( entity, player, 8 ) then
                    local distance = math.min( level:distance( entity, player ), light_range )
                    local factor = math.max( ( distance - 2 )/( light_range -2 ), 0 )
                    nova.log("distance: "..distance..", lightrange: "..light_range..", factor: "..factor)
                    self.attributes.accuracy = math.ceil( 25 * factor )
                    self.attributes.damage_mult = 1 + ( 0.50 * factor )
                    self.attributes.evasion = math.ceil( 50 * factor )
                    self.attributes.percentage = math.ceil( 100 * factor )
                end
            end
        ]],
    },
}

register_blueprint "mod_exalted_sniper"
{
    flags = { EF_NOPICKUP },
    text = {
        status = "SNIPER",
        sdesc  = "increased accuracy, damage and evasion the further from the player",
    },
    callbacks = {
        on_activate = [=[
            function( self, entity )
                entity:attach( "mod_exalted_sniper" )
                entity:equip( "mod_exalted_sniper_buff" )
            end
        ]=],
    },
}

more_exalted_test = {}

function more_exalted_test.on_entity( entity )
    local exalted_traits = {
        { "mod_exalted_blast_shield", },
        { "mod_exalted_blinding", },
        { "mod_exalted_crit_defence", },
        { "mod_exalted_draining", },
        { "mod_exalted_empowered", },
        { "mod_exalted_phasing", },
        { "mod_exalted_pressuring", },
        { "mod_exalted_radioactive", },
        { "mod_exalted_respawn", },
        { "mod_exalted_screamer", },
        { "mod_exalted_sniper" },
        { "mod_exalted_soldier_bayonet", },
        { "mod_exalted_soldier_dodge", },
        { "mod_exalted_spiky", },
        { "mod_exalted_triggerhappy", },
        { "mod_exalted_vampiric", },
    }
    local level = world:get_level()
    if entity.data and entity.data.ai and entity.data.ai.group ~= "player"  then
        make_exalted( entity, 1, { "mod_exalted_phasing" } )
    end
end

-- world.register_on_entity( more_exalted_test.on_entity )

function make_more_exalted_list( entity, list, nightmare_diff )

    local level = world:get_level()

    table.insert( list, "mod_exalted_blast_shield" )
    table.insert( list, "mod_exalted_blinding" )
    table.insert( list, "mod_exalted_crit_defence" )
    table.insert( list, "mod_exalted_draining" )
    table.insert( list, { "mod_exalted_empowered", min = 2, tag = "health" } )
    table.insert( list, "mod_exalted_pressuring" )
    table.insert( list, { "mod_exalted_vampiric", min = 6, tag = "health" } )

    if not entity:child("terminal_bot_rexio") and world:get_id( entity ) ~= "mimir_sentry_bot" and world:get_id( entity ) ~= "asterius_sentry_bot" then
        table.insert( list, "mod_exalted_radioactive" )
    end

    if entity.data and entity.data.ai and entity.data.ai.idle ~= "turret_idle" then
        table.insert( list, "mod_exalted_phasing" )
    else
        nova.log("not phasing "..entity:get_name())
    end

    if entity.data and entity.data.ai and entity.data.ai.group == "zombie" then
        table.insert( list, "mod_exalted_soldier_dodge" )
        table.insert( list, { "mod_exalted_screamer", tag = "health" } )
    end

    if entity.data and entity.data.ai and entity.data.ai.group == "zombie" and entity.data.nightmare and entity.data.nightmare.id ~= "human_exalted_paladin" then
        table.insert( list, "mod_exalted_soldier_bayonet" )
    end

    if entity.data and entity.data.ai and entity.data.ai.group == "demon" then
        table.insert( list, "mod_exalted_spiky" )
    end

    if entity.data and entity.data.is_mechanical and world:get_id( entity ) ~= "mimir_sentry_bot" and world:get_id( entity ) ~= "asterius_sentry_bot" then
        table.insert( list, { "mod_exalted_screamer", tag = "health" } )
    end

    for c in ecs:children( entity ) do
        if c.weapon and (c.weapon.type ~= world:hash("melee") ) then
            table.insert( list, { "mod_exalted_sniper", min = 6, } )
        end
        if c.weapon and c.attributes and c.attributes.shots and c.attributes.shots > 1 then
            table.insert( list, "mod_exalted_triggerhappy" )
        end
    end

    for c in ecs:children( entity ) do

    end

    if not nightmare_diff and entity.data and not entity.data.is_mechanical and not entity:child("terminal_bot_rexio") then
        table.insert( list, { "mod_exalted_respawn", tag = "respawn" } )
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
            nova.log("count: "..count.." and #list:"..#list)
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
    nova.log("Applying exalted perks to "..entity:get_name())
    return keywords
end