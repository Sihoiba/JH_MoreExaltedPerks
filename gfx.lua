nova.require "data/lua/gfx/common"

register_gfx_blueprint "exalted_soldier_bayonette"
{
	weapon_fx = {
		advance   = 0.5,
	},
}

register_gfx_blueprint "exalted_buff_stealth"
{
	equip = {},
	outline = {
		spread = true,
		color = vec4( 0.0, 0.0, 0.3, 1.0 ),
	},
}