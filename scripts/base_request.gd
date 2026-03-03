extends Resource
class_name BaseRequest

@export var id: String = ""
@export var tier: int = 1
@export var npc_id: String = ""
@export var request_name: String = ""
@export var description: String = ""

# Requirements — all must be met to fulfill the request
@export var required_families: Dictionary = {}  # e.g. { "woody": 2 } = at least 2 woody drops
@export var required_notes: Dictionary = {}     # e.g. { "base": 1 } = at least 1 base-note ingredient
@export var min_quality: float = 0.0
@export var min_drops: int = 0
@export var requires_accord: bool = false
@export var requires_aged: bool = false

# Reward
@export var reward_text: String = ""
@export var reward_type: String = "coin"  # "coin", "ingredient", "hint"
@export var reward_ingredient_path: String = ""
@export var reward_amount: int = 0

# Feedback on failed delivery
@export var failure_feedback: String = ""


static func from_dict(data: Dictionary) -> BaseRequest:
	var req := BaseRequest.new()
	req.id = data.get("id", "")
	req.tier = int(data.get("tier", 1))
	req.npc_id = data.get("npc_id", "")
	req.request_name = data.get("request_name", "")
	req.description = data.get("description", "")
	req.required_families = data.get("required_families", {})
	req.required_notes = data.get("required_notes", {})
	req.min_quality = float(data.get("min_quality", 0.0))
	req.min_drops = int(data.get("min_drops", 0))
	req.requires_accord = bool(data.get("requires_accord", false))
	req.requires_aged = bool(data.get("requires_aged", false))
	req.reward_text = data.get("reward_text", "")
	req.reward_type = data.get("reward_type", "coin")
	req.reward_ingredient_path = data.get("reward_ingredient_path", "")
	req.reward_amount = int(data.get("reward_amount", 0))
	req.failure_feedback = data.get("failure_feedback", "")
	return req
