shader_type canvas_item;

// Interaction highlight — traces a hard outline around the opaque pixels of a
// sprite. Used when an object is in reach and can be interacted with.
//
// Hard-edged and 1px by default, because this is pixel art: a soft blurry
// glow reads as mush at 480x270.
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
//
// Note on style: the eight samples below are written out longhand rather
// than wrapped in a neat helper function. That is deliberate — Godot's
// shader language will not let you pass the built-in TEXTURE into a function
// of your own, and doing it anyway logs an error per call while still
// appearing to work. Longhand is the version that runs clean.

// Colour of the outline. Warm pale gold by default, to sit in the same
// family as Pip's calm glow without being mistaken for Pip.
uniform vec4 outline_color : source_color = vec4(1.0, 0.93, 0.72, 1.0);

// Outline width in texture pixels. 1.0 is right for 16x16 objects.
uniform float thickness : hint_range(0.0, 4.0, 0.5) = 1.0;

// A pixel counts as "part of the object" above this alpha. Raise it if
// semi-transparent edges make the outline look furry.
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.1;

// Driven from GDScript so the outline can fade in and out.
// 0.0 = off, 1.0 = full. Anything between is a partial fade.
uniform float strength : hint_range(0.0, 1.0) = 0.0;


void fragment() {
	vec4 base = texture(TEXTURE, UV);

	// Inside the object, or the highlight is off: draw the sprite untouched.
	if (strength <= 0.0 || base.a > alpha_threshold) {
		COLOR = base;
	} else {
		// Outside the object. Look at the eight neighbouring pixels
		// `thickness` away; if any of them is solid, we are sitting just off
		// the silhouette and this pixel is part of the outline.
		// Eight directions rather than four, or diagonal edges break up.
		vec2 o = TEXTURE_PIXEL_SIZE * thickness;
		float found = 0.0;
		found = max(found, texture(TEXTURE, UV + vec2( o.x,  0.0)).a);
		found = max(found, texture(TEXTURE, UV + vec2(-o.x,  0.0)).a);
		found = max(found, texture(TEXTURE, UV + vec2( 0.0,  o.y)).a);
		found = max(found, texture(TEXTURE, UV + vec2( 0.0, -o.y)).a);
		found = max(found, texture(TEXTURE, UV + vec2( o.x,  o.y)).a);
		found = max(found, texture(TEXTURE, UV + vec2( o.x, -o.y)).a);
		found = max(found, texture(TEXTURE, UV + vec2(-o.x,  o.y)).a);
		found = max(found, texture(TEXTURE, UV + vec2(-o.x, -o.y)).a);

		// step() is 1.0 when a solid neighbour was found, 0.0 otherwise.
		float edge = step(alpha_threshold, found);
		COLOR = vec4(outline_color.rgb, outline_color.a * edge * strength);
	}
}
