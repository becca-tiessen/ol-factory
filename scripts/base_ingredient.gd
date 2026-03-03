extends Resource
class_name BaseIngredient

# General Info
@export var display_name: String = "New Ingredient"
@export var icon: Texture2D
@export var description: String = ""

# Mixing Stats
@export var liquid_color: Color = Color.WHITE
@export var density: float = 1.0 # Could affect how fast it fills the beaker

# Scent Profile (The "Logic" for your accords)
# Using a Vector3 is a clever way to store Top, Heart, and Base notes
# X = Top Note, Y = Heart Note, Z = Base Note (scaled 0.0 to 1.0)
@export var scent_profile: Vector3 = Vector3.ZERO

# Quality Calculation Properties
@export var scent_family: String = ""         # e.g. "woody", "sweet", "floral", "citrus", "green", "spicy"
@export var intensity: float = 5.0            # How dominant this ingredient is (1.0–10.0)
@export var note_position: String = "middle"  # Evaporation rate: "top", "middle", or "base"

# Optional: What does it turn into when pressed?
@export var result_item: Resource # You can link the 'Essential Oil' version here
