class_name ScentCompatibility

# ---------------------------------------------------------------------------
# Compatibility table for scent family pairs.
# Keys are "family_a+family_b" with families sorted alphabetically so
# "floral+woody" and "woody+floral" both resolve to the same entry.
# Scores range from 0.0 (clash) to 1.0 (perfect harmony).
#
# To add more rules, just add a new entry here — no other file changes needed.
# ---------------------------------------------------------------------------

const DEFAULT_COMPATIBILITY := 0.3

const COMPATIBILITY_TABLE: Dictionary = {
	# --- High compatibility (~0.85–0.90) ---
	"citrus+floral":  0.9,   # fresh florals like bergamot + rose
	"floral+woody":   0.9,   # classic chypre backbone
	"sweet+woody":    0.9,   # vanilla + sandalwood / cedar

	# --- Medium-high (~0.70–0.85) ---
	"floral+sweet":   0.85,  # rose + vanilla
	"spicy+woody":    0.85,  # pepper + cedar
	"citrus+green":   0.75,  # bergamot + peppermint / grass
	"floral+green":   0.70,  # rose + green stem accord

	# --- Medium (~0.55–0.65) ---
	"green+woody":    0.60,  # forest / fougère vibes
	"citrus+sweet":   0.60,  # lemon + vanilla
	"spicy+sweet":    0.60,  # cinnamon + vanilla

	# --- Medium-low (~0.35–0.55) ---
	"floral+spicy":   0.55,  # interesting but tricky
	"citrus+woody":   0.50,  # needs careful balancing
	"citrus+spicy":   0.40,  # sharp contrast
	"green+sweet":    0.40,  # can smell odd without balance

	# --- Low (~0.30–0.35) ---
	"green+spicy":    0.35,  # usually clashing
	# Anything not listed falls back to DEFAULT_COMPATIBILITY (0.3)
}


# Returns the compatibility score (0.0–1.0) for two scent families.
# A same-family pairing always returns 1.0.
static func get_compatibility(family_a: String, family_b: String) -> float:
	if family_a.is_empty() or family_b.is_empty():
		return DEFAULT_COMPATIBILITY
	if family_a == family_b:
		return 1.0
	return COMPATIBILITY_TABLE.get(_make_key(family_a, family_b), DEFAULT_COMPATIBILITY)


# Builds a canonical key by sorting the two families alphabetically.
static func _make_key(family_a: String, family_b: String) -> String:
	if family_a < family_b:
		return family_a + "+" + family_b
	return family_b + "+" + family_a
