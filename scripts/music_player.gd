class_name MusicPlayer
extends Node


# Plays one ambient track per habitat and crossfades whenever the zoo's newest
# pen changes, so the music follows what the player just built without ever
# cutting between tracks.


const MEADOW_TRACK: String = "res://audio/meadow.ogg"
const REEF_TRACK: String = "res://audio/reef.ogg"
const VOID_TRACK: String = "res://audio/void.ogg"
const SILENT_DB: float = -60.0

@export_range(0.5, 12.0, 0.1) var crossfade_time: float = 4.0
## Overall music level on top of the per-track matching gains.
@export_range(-40.0, 6.0, 0.5) var music_volume_db: float = -5.0
@export var autoplay_habitat: CreatureTraits.Habitat = CreatureTraits.Habitat.BASIC
@export var play_on_ready: bool = true

var current_habitat: CreatureTraits.Habitat = CreatureTraits.Habitat.WILD

var _players: Array[AudioStreamPlayer] = []
var _habitats: Array[CreatureTraits.Habitat] = []
var _active: int = -1
var _fade: float = 1.0
var _streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.volume_db = SILENT_DB
		player.bus = &"Master"
		add_child(player)
		_players.append(player)
		_habitats.append(CreatureTraits.Habitat.WILD)
	if play_on_ready:
		play_for_habitat(autoplay_habitat)


# The track a habitat sounds like. WILD keeps whatever is already playing.
static func track_path(habitat: CreatureTraits.Habitat) -> String:
	match habitat:
		CreatureTraits.Habitat.WATER:
			return REEF_TRACK
		CreatureTraits.Habitat.ALIEN:
			return VOID_TRACK
		_:
			return MEADOW_TRACK


# The three source recordings sit at very different levels, so each one carries
# a matching offset that lines them up by measured loudness.
static func track_gain_db(habitat: CreatureTraits.Habitat) -> float:
	match habitat:
		CreatureTraits.Habitat.WATER:
			return 0.0
		CreatureTraits.Habitat.ALIEN:
			return -1.6
		_:
			return -9.5


func play_for_habitat(habitat: CreatureTraits.Habitat) -> void:
	if habitat == CreatureTraits.Habitat.WILD:
		return
	if habitat == current_habitat and _active >= 0 and _players[_active].playing:
		return

	var stream := _load_stream(habitat)
	if stream == null:
		return

	var incoming := 0 if _active != 0 else 1
	_players[incoming].stream = stream
	_players[incoming].volume_db = SILENT_DB
	_players[incoming].play()
	_habitats[incoming] = habitat

	# Starting from scratch should not fade in from silence for four seconds.
	_fade = 0.0 if _active >= 0 else 0.75
	_active = incoming
	current_habitat = habitat
	_apply_fade()


func is_crossfading() -> bool:
	return _fade < 1.0


func _process(delta: float) -> void:
	if _fade >= 1.0:
		return
	_fade = clampf(_fade + delta / maxf(crossfade_time, 0.05), 0.0, 1.0)
	_apply_fade()
	if _fade >= 1.0:
		for i in range(_players.size()):
			if i != _active and _players[i].playing:
				_players[i].stop()


# Equal-power curve: the two tracks sum to a steady level through the swap
# instead of dipping in the middle.
func _apply_fade() -> void:
	for i in range(_players.size()):
		var weight := sin(_fade * PI * 0.5) if i == _active else cos(_fade * PI * 0.5)
		var target := music_volume_db + track_gain_db(_habitats[i])
		_players[i].volume_db = maxf(SILENT_DB, target + linear_to_db(maxf(weight, 0.0001)))


func _load_stream(habitat: CreatureTraits.Habitat) -> AudioStream:
	if _streams.has(habitat):
		return _streams[habitat]

	var path := track_path(habitat)
	if not ResourceLoader.exists(path):
		push_warning("Music track %s is missing; the zoo will run silently." % path)
		return null

	var stream := load(path) as AudioStream
	if stream == null:
		return null
	# Ambient beds run forever; the files already have matched loop points.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	_streams[habitat] = stream
	return stream
