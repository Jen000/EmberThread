shader_type canvas_item;

// Interaction highlight — traces a hard outline around the opaque pixels of a
// sprite. Used when an object is in reach and can be interacted with.
//
// Hard-edged and 1px by default, because this is pixel art: a soft blurry
// glow reads as mush at 480x270. `softness` exists for a gentler halo on
// larger objects, but keep it low.
//
// Applied from code (see scenes/interactable/highlight.gd), never checked
// into a scene, so the highlight can be swapped or removed in one place.
//
// TWO THINGS THAT WILL CATCH YOU OUT:
//
// 1. The outline is drawn INSIDE the texture's own rectangle. Art that runs
//    to the very edge of its frame has nowhere to put the outline and gets
//    clipped on that side. Fix it in the art, not here: leave 1px of empty
//    space around anything meant to be highlighted (worth adding to
//    docs/art-pipeline.md while the artist is still working).
//
// 2. On an AtlasTexture (a frame sliced out of a spritesheet, like the
//    player layers) UV covers the region but TEXTURE is the WHOLE sheet, so
//    sampling a neighbouring pixel at the frame border reads the frame next
//    door and outlines it. Interactable objects built from individual frame
//    files (what AssetRegistry.get_frames returns) are unaffected. If you
//    ever need this on a sheet-sliced sprite, pad each cell by 1px.

// Colour of the outline. Warm pale gold by default, to sit in the same
// family as Pip's calm glow without being mistaken for Pip.
uniform vec4 outline_color : source_color = vec4(1.0, 0.93, 0.72, 1.0);

// Outline width in texture pixels. 1.0 is right for 16x16 objects.
uniform float thickness : hint_range(0.0, 4.0, 0.5) = 1.0;

// A pixel counts as "part of the object" above this alpha. Raise it if
// semi-transparent edges make the outline look furry.
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.1;

// 0.0 = hard pixel-art edge (default). Above 0, the outline fades out with
// distance for a softer halo. Keep it under ~0.5 or it turns to mush.
uniform float softness : hint_range(0.0, 1.0) = 0.0;

// Driven from GDScript so one material can be shared and toggled. Multiplied
// into the outline's alpha, so it also tweens: 0.0 = off, 1.0 = full.
uniform float strength : hint_range(0.0, 1.0) = 0.0;


// Highest alpha found among the 8 neighbours at `dist` texels away.
// 8 directions (not 4) keeps diagonal edges from breaking up.
float neighbour_alpha(sampler2D tex, vec2 uv, vec2 texel, float dist) {
	vec2 offset = texel * dist;
	float a = 0.0;
	a = max(a, texture(tex, uv + vec2( offset.x, 0.0)).a);
	a = max(a, texture(tex, uv + vec2(-offset.x, 0.0)).a);
	a = max(a, texture(tex, uv + vec2(0.0,  offset.y)).a);
	a = max(a, texture(tex, uv + vec2(0.0, -offset.y)).a);
	a = max(a, texture(tex, uv + vec2( offset.x,  offset.y)).a);
	a = max(a, texture(tex, uv + vec2( offset.x, -offset.y)).a);
	a = max(a, texture(tex, uv + vec2(-offset.x,  offset.y)).a);
	a = max(a, texture(tex, uv + vec2(-offset.x, -offset.y)).a);
	return a;
}


void fragment() {
	vec4 base = texture(TEXTURE, UV);

	// Inside the object, or highlight switched off: draw the sprite as-is.
	if (strength <= 0.0 || base.a > alpha_threshold) {
		COLOR = base;
	} else {
		// Outside the object: light this pixel up if a solid pixel is within
		// `thickness` of it — i.e. we are sitting just off the silhouette.
		float found = neighbour_alpha(TEXTURE, UV, TEXTURE_PIXEL_SIZE, thickness);
		float edge = step(alpha_threshold, found);

		if (softness > 0.0) {
			// Fade with distance instead of a hard cut. Sampling at half
			// thickness tells us how close the silhouette really is.
			float near = neighbour_alpha(TEXTURE, UV, TEXTURE_PIXEL_SIZE, thickness * 0.5);
			edge = mix(edge, max(edge * (1.0 - softness), step(alpha_threshold, near)), softness);
		}

		COLOR = vec4(outline_color.rgb, outline_color.a * edge * strength);
	}
}
