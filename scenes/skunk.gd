extends CharacterBody2D

## Organic companion that follows the player with a slight delay,
## using a breadcrumb trail so it walks the path the player took.

@export var follow_speed: float = 85.0
@export var stop_distance: float = 20.0
@export var trail_spacing: float = 8.0  # Min distance between breadcrumbs

var _is_idle: bool = false

# Breadcrumb trail — stores player positions we replay through
var _breadcrumbs: Array[Vector2] = []
const MAX_CRUMBS := 200

var _sprite: Sprite2D

func _ready() -> void:
	for child in get_children():
		if child is Sprite2D:
			_sprite = child
			break

func _physics_process(delta: float) -> void:
	var player: Node2D = _find_player()
	if not player:
		return

	_record_breadcrumb(player.global_position)

	var dist_to_player: float = global_position.distance_to(player.global_position)

	if dist_to_player > 400.0:
		# Teleport if too far (e.g. after scene load edge case)
		_teleport_near(player.global_position)
		return

	if _breadcrumbs.size() > 0:
		var target: Vector2 = _breadcrumbs[0]
		var dist_to_crumb: float = global_position.distance_to(target)

		if dist_to_crumb < 4.0:
			_breadcrumbs.remove_at(0)
			if _breadcrumbs.size() == 0:
				_enter_idle(delta)
				return

		# Only follow if we're far enough from the player
		if dist_to_player > stop_distance:
			_is_idle = false
			var direction: Vector2 = (target - global_position).normalized()
			# Speed scales up if falling behind
			var speed_mult: float = clampf(dist_to_player / 80.0, 0.6, 1.8)
			velocity = direction * follow_speed * speed_mult
			_face_direction(direction)
			move_and_slide()
		else:
			_enter_idle(delta)
	else:
		_enter_idle(delta)


func _enter_idle(_delta: float) -> void:
	_is_idle = true
	velocity = Vector2.ZERO



func _record_breadcrumb(player_pos: Vector2) -> void:
	if _breadcrumbs.size() == 0:
		# Only start recording if player is far enough from skunk
		if global_position.distance_to(player_pos) > stop_distance:
			_breadcrumbs.append(player_pos)
		return

	var last: Vector2 = _breadcrumbs[_breadcrumbs.size() - 1]
	if last.distance_to(player_pos) >= trail_spacing:
		_breadcrumbs.append(player_pos)
		if _breadcrumbs.size() > MAX_CRUMBS:
			_breadcrumbs.remove_at(0)


func _face_direction(dir: Vector2) -> void:
	if _sprite and abs(dir.x) > 0.1:
		_sprite.flip_h = dir.x < 0


func _teleport_near(player_pos: Vector2) -> void:
	var offset_angle: float = randf() * TAU
	global_position = player_pos + Vector2(cos(offset_angle), sin(offset_angle)) * stop_distance * 0.8
	_breadcrumbs.clear()
	velocity = Vector2.ZERO


func spawn_near_player() -> void:
	var player: Node2D = _find_player()
	if player:
		_teleport_near(player.global_position)
	_breadcrumbs.clear()


func _find_player() -> Node2D:
	var tree: SceneTree = get_tree()
	if not tree:
		return null
	var current: Node = tree.current_scene
	if not current:
		return null
	return current.find_child("Player") as Node2D
