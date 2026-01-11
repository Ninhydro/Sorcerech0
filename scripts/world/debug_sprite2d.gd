# safety_clamp.gd - Attach to ALL your Sprite2D nodes
extends Sprite2D

func _set(property: StringName, value: Variant) -> bool:
	if property == "frame":
		var max_frames = hframes * vframes
		if max_frames > 0 and value >= max_frames:
			# Clamp to valid range
			print("⚠️ Safety clamp: %s frame %s -> %s" % [
				get_path(), value, max_frames - 1
			])
			set("frame", max_frames - 1)
			return true
	return false
