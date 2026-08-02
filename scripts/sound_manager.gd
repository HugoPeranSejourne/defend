extends Node
class_name SoundManager

static var instance: SoundManager

func _ready() -> void:
	instance = self
	add_to_group("sound_managers")

static func play_rifle_shot(parent: Node, pos: Vector3 = Vector3.ZERO) -> void:
	_play_synth_audio(parent, pos, 0.08, 650.0, 150.0, 0.45)

static func play_flashball_shot(parent: Node, pos: Vector3 = Vector3.ZERO) -> void:
	_play_synth_audio(parent, pos, 0.12, 300.0, 80.0, 0.35)

static func play_explosion(parent: Node, pos: Vector3 = Vector3.ZERO) -> void:
	_play_synth_audio(parent, pos, 0.35, 120.0, 30.0, 0.75)

static func play_footstep(parent: Node, pos: Vector3 = Vector3.ZERO) -> void:
	_play_synth_audio(parent, pos, 0.04, 400.0, 200.0, 0.12)

static func _play_synth_audio(parent: Node, pos: Vector3, duration: float, freq_start: float, freq_end: float, volume: float) -> void:
	if not is_instance_valid(parent):
		return
		
	var player: Node = AudioStreamPlayer3D.new() if pos != Vector3.ZERO else AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 22050.0
	generator.buffer_length = duration + 0.05
	
	if player is AudioStreamPlayer3D:
		(player as AudioStreamPlayer3D).stream = generator
		(player as AudioStreamPlayer3D).volume_db = linear_to_db(volume)
		(player as AudioStreamPlayer3D).unit_size = 15.0
		(player as AudioStreamPlayer3D).max_distance = 180.0
	elif player is AudioStreamPlayer:
		(player as AudioStreamPlayer).stream = generator
		(player as AudioStreamPlayer).volume_db = linear_to_db(volume)
		
	parent.add_child(player)
	if player is AudioStreamPlayer3D:
		(player as AudioStreamPlayer3D).global_position = pos
		(player as AudioStreamPlayer3D).play()
	elif player is AudioStreamPlayer:
		(player as AudioStreamPlayer).play()
	
	var playback: AudioStreamGeneratorPlayback = null
	if player is AudioStreamPlayer3D:
		playback = (player as AudioStreamPlayer3D).get_stream_playback() as AudioStreamGeneratorPlayback
	elif player is AudioStreamPlayer:
		playback = (player as AudioStreamPlayer).get_stream_playback() as AudioStreamGeneratorPlayback

	if playback:
		var frames := int(22050.0 * duration)
		for i in range(frames):
			var t := float(i) / 22050.0
			var progress := t / duration
			var freq: float = lerp(freq_start, freq_end, progress)
			var sample_val: float = sin(2.0 * PI * freq * t) * (1.0 - progress) * (randf() * 0.4 + 0.6)
			playback.push_frame(Vector2(sample_val, sample_val))
			
	var timer := parent.get_tree().create_timer(duration + 0.1)
	timer.timeout.connect(player.queue_free)
