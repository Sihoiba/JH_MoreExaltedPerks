register_blueprint "runtime_inventory_check"
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

register_blueprint "exalted_soldier_bayonette"
{
	flags = { EF_NOPICKUP }, 
	text = {
		status = "BAYONETTE",
		sdesc  = "dangerous melee attack",
	},
	callbacks = {
		on_activate = [=[
			function( self, entity )				
				entity:attach( "exalted_soldier_bayonette" )
				entity:attach( "runtime_inventory_check" )
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

register_blueprint "exalted_soldier_blast_shield"
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
				entity:attach( "perk_he_blast_shield" )
			end		
		]=],
	},
}



more_exalted_test = {}

function more_exalted_test.on_entity( entity )
	local exalted_traits = {
		--{ "exalted_soldier_bayonette", },
		-- { "exalted_soldier_blast_shield", },
	}
	if entity.data and entity.data.ai and entity.data.ai.group == "zombie" then
		make_exalted( entity, 1, exalted_traits )
	end
end

world.register_on_entity( more_exalted_test.on_entity )