shader_type spatial;
render_mode cull_disabled;

uniform sampler2D overlay_texture;
uniform vec2 position_in_atlas;
uniform vec2 size_in_atlas;
uniform uint atlas_index;
uniform bool lock_front_wing = false;
uniform bool lock_rear_wing = false;
uniform bool lock_bargeboards = false;
uniform bool is_bargeboard = false;
varying vec3 model_world_position;
uniform sampler2D vinyl_atlas : source_color, filter_linear;
uniform int vinyl_count = 0;
uniform vec4 vinyl_origins[64];
uniform vec4 vinyl_rights[64];
uniform vec4 vinyl_ups[64];
uniform vec4 vinyl_protections[64];

void vertex() {
	model_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 atlas_uv = UV2 * size_in_atlas + position_in_atlas;

	// if cull mask layer 21 is enabled, the camera acts as a brush
	bool is_camera_brush = (CAMERA_VISIBLE_LAYERS & (1u << uint(20))) != 0u;
    if(is_camera_brush){
		// store UV in R and G channels
		// store distance and index in B channel
		// distance and index are packed into a 32 bit float as follows,
		// to survive 16bit floatconversion:
		// unchanged bit ids: 31(sign), 23-25(exponent), 13-22(mantissa)

		// needs to be in exponent form to survive 16bit float conversion
		uint exponential_bit = 1u << 30u;

		// save distance in 13-23 -> 11 bits truncated
		float distance = -VERTEX.z;
		uint distance_bits = (packHalf2x16(vec2(distance, 0)) & 0xFFE0u) << uint(13 - 5);

		// save index in sign bit and exponent bits
		uint index_sign_bit = (atlas_index & 0x4u) << uint(31 - 2); // in sign bit 31
		uint index_exp_bits = (atlas_index & 0x3u) << 24u; // in exponent bits 24-25

		// combine bits into B Channel
		float b = uintBitsToFloat(exponential_bit | distance_bits | index_sign_bit | index_exp_bits);

		// display as EMISSION to avoid shading
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		bool protected_part = (lock_bargeboards && is_bargeboard)
            || (lock_front_wing && model_world_position.z < -1.73 && model_world_position.y < 0.32)
            || (lock_rear_wing && model_world_position.z > 1.55 && model_world_position.y > 0.29);
        EMISSION = protected_part ? vec3(-2.0, -2.0, 0.0) : vec3(atlas_uv - vec2(0.5), b);
    }
	else{
		vec4 atlas_color = texture(overlay_texture, atlas_uv);
		for (int i = 0; i < vinyl_count; i++) {
            vec4 origin = vinyl_origins[i];
            if (origin.w < 0.0) continue;
            vec3 protection = vinyl_protections[i].xyz;
            if ((protection.x > 0.5 && model_world_position.z < -1.73 && model_world_position.y < 0.32)
                || (protection.y > 0.5 && model_world_position.z > 1.55 && model_world_position.y > 0.29)
                || (protection.z > 0.5 && is_bargeboard)) continue;
            vec3 right = vinyl_rights[i].xyz;
            vec3 up = vinyl_ups[i].xyz;
            vec3 delta = model_world_position - origin.xyz;
            if (abs(dot(delta, cross(right, up))) > origin.w) continue;
            vec2 uv = vec2(dot(delta, right) / vinyl_rights[i].w + 0.5,
                           0.5 - dot(delta, up) / vinyl_ups[i].w);
            if (any(lessThan(uv, vec2(0.0))) || any(greaterThanEqual(uv, vec2(1.0)))) continue;
            vec2 cell = vec2(float(i % 8), float(i / 8));
            vec4 color = texture(vinyl_atlas, (cell + uv) / 8.0);
            float alpha = color.a + atlas_color.a * (1.0 - color.a);
            atlas_color.rgb = alpha > 0.0 ? (color.rgb * color.a + atlas_color.rgb * atlas_color.a * (1.0 - color.a)) / alpha : vec3(0.0);
            atlas_color.a = alpha;
        }
        ALBEDO = atlas_color.rgb;
        ALPHA = atlas_color.a;
	}
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
