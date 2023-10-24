nova.require "data/lua/gfx/common"

register_gfx_blueprint "exalted_soldier_bayonette"
{
    weapon_fx = {
        advance   = 0.5,
    },
}

register_gfx_blueprint "exalted_tainted_mark"
{
    equip = {},
    "ps_nightmare_1",
}

register_gfx_blueprint "mod_exalted_radioactive_aura"
{
    equip = {},
    persist = true,
    point_generator = {
        type     = "hollow_cylinder",
        position = vec3(0.0,0.1,0.0),
        extents  = vec3(0.6,0.2,0.0),
        iextents = vec3(0.5,0.0,0.0),
    },
    particle_emitter = {
        rate     = 256,
        size     = vec2(0.05,0.3),
        color    = vec4(0.6,0.8,0.2,0.75),
        velocity = 0.2,
        lifetime = 1.5,
    },
    particle_transform = {
        axis       = vec3(6,-0.1,-2.0),
    },
    particle_fade = {
        fade_in  = 0.5,
        fade_out = 1.0,
    },
    particle_animator = {
        range = ivec2(0,63),
        rate  = 64.0,
    },
    particle = {
        material        = "data/texture/particles/fireball_01/C/fireball_01",
        group_id        = "pgroup_enviro",
        localized       = true,
        tiling          = 8,
        orientation     = PS_ORIENTED,
    },
}

register_gfx_blueprint "scorching_smoke"
{
    tag = "scorching_smoke",
    scene = {
        position = vec3( 0.0, 0.5, 0.0 ),
    },
    point_generator = {
        type     = "box",
        position = vec3(0,0.2,0),
        extents  = vec3(0.7,0.8,0.7),
    },
    particle = {
        material        = "data/texture/particles/smoke_02/smoke_02",
        group_id        = "pgroup_enviro",
        tiling          = 8,
        destroy_owner   = true,
    },
    particle_emitter = {
        angle    = 20,
        rate     = 4,
        color    = 0.7,
        size     = { {0.7}, {1.0} },
        velocity = { 0.1, 0.2 },
        lifetime = { 1.5, 2.5 },
        duration = 2,
    },
    particle_animator = {
        range = ivec2(0,63),
        rate  = 24.0,
    },
    particle_transform = {
        force = vec3(0,0.1,0),
        scale = 0.02,
    },
    particle_fade = {
        fade_in   = 0.5,
        fade_out  = 1.5,
    },
}

register_gfx_blueprint "power_up_10" {
    tag = "glow",
    equip = {},
    light = {
        position    = vec3(0,0.8,0),
        color       = vec4(1.0,0.84,0,1.2),
        range       = 1.1,
    }
}
    
register_gfx_blueprint "power_up_20" {
    tag = "glow",
    equip = {},
    light = {
        position    = vec3(0,0.8,0),
        color       = vec4(1.0,0.84,0,1.4),
        range       = 1.2,
    }
}

register_gfx_blueprint "power_up_40" {
    tag = "glow",
    equip = {},
    light = {
        position    = vec3(0,0.8,0),
        color       = vec4(1.0,0.84,0,1.8),
        range       = 1.4,
    }
}

register_gfx_blueprint "power_up_60" {
    tag = "glow",
    equip = {},
    light = {
        position    = vec3(0,0.8,0),
        color       = vec4(1.0,0.84,0,2.2),
        range       = 1.6,
    }
}

register_gfx_blueprint "power_up_80" {
    tag = "glow",
    equip = {},
    light = {
        position    = vec3(0,0.8,0),
        color       = vec4(1.0,0.84,0,2.6),
        range       = 1.8,
    }
}

register_gfx_blueprint "power_up_100" {
    tag = "glow",
    equip = {},
    light = {
        position    = vec3(0,0.8,0),
        color       = vec4(1.0,0.84,0,3),
        range       = 2.0,
    }
}

register_gfx_blueprint "mod_exalted_gatekeeper_elevator_inactive"
{
	equip = {},
	uisprite = {
		icon = "data/texture/ui/icons/ui_tooltip_elevator",
		orientation = "FLOOR",
		offset = 1.5,
		propagate = true,
		color = vec4(1.5,0.75,2.25,1.0),
		visibility = "REVEAL",
	},
	light = {
		position    = vec3(0.5,0,0),
		color       = vec4(1.5,0.75,2.25,2.0),
		range       = 2.5,
	},
}