extends CharacterBody2D

signal voice_detected
signal repeat_started
signal repeat_finished
signal ate_food

const CAPTURE_BUS_NAME := "Fancy Microphone"
const VOICE_BUS_NAME := "Fancy Voice"
const EATING_SOUND := preload("res://sounds/roblox-eating-nom-nom-nom.mp3")
const EXPLOSION_SOUND := preload("res://sounds/roblox-explosion-sound.mp3")
const DEATH_SOUND := preload("res://sounds/roblox-death-sound_1.mp3")
const YES_SOUND := preload("res://sounds/talking-ben-saying-yes.mp3")
const NO_SOUND := preload("res://sounds/talking-ben-saying-no.mp3")
const VOICE_PITCH := 2.0
const VOICE_THRESHOLD := 0.025
const SILENCE_TO_REPEAT := 0.65
const MAX_PHRASE_SECONDS := 10.0
const PLAYBACK_DRAIN_SECONDS := 0.25
const CAKE_CRAWL_SPEED := 35.0
const CAKE_SPRINT_SPEED := 220.0
const CAKE_STOP_DISTANCE := 24.0
const CAKE_SPRINT_DURATION := 0.65
const CAKE_SPRINT_COOLDOWN_MIN := 1.5
const CAKE_SPRINT_COOLDOWN_MAX := 3.5
const CAKE_JUMP_HEIGHT := 80.0
const CAKE_JUMP_MIN_VERTICAL_DISTANCE := 45.0
const CAKE_JUMP_MAX_HORIZONTAL_DISTANCE := 180.0
const CAKE_JUMP_HORIZONTAL_SPEED := 100.0
const CAKE_JUMP_COOLDOWN := 1.5
const ROAM_SPEED_MIN := 18.0
const ROAM_SPEED_MAX := 32.0
const ROAM_TURN_INTERVAL_MIN := 2.0
const ROAM_TURN_INTERVAL_MAX := 4.5
const MOUSE_FEAR_RADIUS := 190.0
const MOUSE_FLEE_SPEED := 240.0
const TRUST_MAX := 100
const INITIAL_TRUST := 50
const TRUST_NEUTRAL_THRESHOLD := 50
const TRUST_PER_CAKE := 20
const TRUST_LOST_PER_HIT := 30
const CAKE_GROWTH_STEP := 0.15
const MAX_GROWTH_SCALE := 2.2
const NORMAL_TEXTURE := preload("res://sprites/FancyStandart.png")
const HAPPY_TEXTURE := preload("res://sprites/FancyHappy.png")
const TALKING_TEXTURE := preload("res://sprites/FancyTalking.png")

enum AudioState { LISTENING, PLAYING }

var microphone_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var response_player: AudioStreamPlayer
var eating_player: AudioStreamPlayer
var explosion_player: AudioStreamPlayer
var death_player: AudioStreamPlayer
var capture_effect: AudioEffectCapture
var voice_playback: AudioStreamGeneratorPlayback
var sample_rate := 44100.0
var audio_state := AudioState.LISTENING
var is_recording_phrase := false
var silence_duration := 0.0
var phrase_frames := PackedVector2Array()
var playback_index := 0
var playback_drain_timer := 0.0
var yes_no_mode := false
var is_playing_response := false
var cake_sprint_timer := 0.0
var cake_sprint_cooldown := 2.0
var cake_jump_cooldown_timer := 0.0
var roam_direction := 1.0
var roam_speed := 24.0
var roam_turn_timer := 0.0
var growth_multiplier := 1.0
var growth_tween: Tween
var trust := INITIAL_TRUST

var sprite: Sprite2D
var sprite_base_scale := Vector2.ONE
var fancy_base_scale := Vector2.ONE
var talking_tween: Tween
var happy_time_remaining := 0.0
var is_happy := false
var is_dragging := false
var drag_offset := Vector2.ZERO


func _ready() -> void:
	sprite = $Sprite2D
	sprite_base_scale = sprite.scale
	fancy_base_scale = scale
	cake_sprint_cooldown = randf_range(
		CAKE_SPRINT_COOLDOWN_MIN,
		CAKE_SPRINT_COOLDOWN_MAX
	)
	roam_direction = -1.0 if randf() < 0.5 else 1.0
	roam_speed = randf_range(ROAM_SPEED_MIN, ROAM_SPEED_MAX)
	roam_turn_timer = randf_range(ROAM_TURN_INTERVAL_MIN, ROAM_TURN_INTERVAL_MAX)
	$Area2D.area_entered.connect(_on_area_entered)
	explosion_player = AudioStreamPlayer.new()
	explosion_player.stream = EXPLOSION_SOUND
	explosion_player.max_polyphony = 8
	add_child(explosion_player)

	death_player = AudioStreamPlayer.new()
	death_player.stream = DEATH_SOUND
	death_player.max_polyphony = 8
	add_child(death_player)

	eating_player = AudioStreamPlayer.new()
	eating_player.stream = EATING_SOUND
	add_child(eating_player)
	_setup_audio()
	_set_listening_animation()


func _process(delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset

	if happy_time_remaining > 0.0:
		happy_time_remaining -= delta
		if happy_time_remaining <= 0.0:
			is_happy = false
			if audio_state == AudioState.LISTENING:
				_set_listening_animation()
			else:
				_set_talking_animation()

	if audio_state == AudioState.LISTENING:
		_process_microphone()
	elif is_playing_response:
		pass
	else:
		_process_playback(delta)


func _physics_process(delta: float) -> void:
	if is_dragging:
		velocity = Vector2.ZERO
		return

	cake_jump_cooldown_timer = maxf(cake_jump_cooldown_timer - delta, 0.0)
	var is_wandering := false
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		var mouse_offset := get_global_mouse_position() - global_position
		if (
			trust < TRUST_NEUTRAL_THRESHOLD
			and mouse_offset.length() < MOUSE_FEAR_RADIUS
		):
			if absf(mouse_offset.x) > 1.0:
				velocity.x = -signf(mouse_offset.x) * MOUSE_FLEE_SPEED
			else:
				velocity.x = signf(velocity.x) * MOUSE_FLEE_SPEED
				if is_zero_approx(velocity.x):
					velocity.x = MOUSE_FLEE_SPEED
			cake_sprint_timer = 0.0
		else:
			var target_cake := _get_nearest_released_cake()
			if target_cake:
				cake_sprint_cooldown -= delta
				var horizontal_distance := target_cake.global_position.x - global_position.x
				var vertical_distance := global_position.y - target_cake.global_position.y
				if (
					vertical_distance >= CAKE_JUMP_MIN_VERTICAL_DISTANCE
					and absf(horizontal_distance) <= CAKE_JUMP_MAX_HORIZONTAL_DISTANCE
					and cake_jump_cooldown_timer <= 0.0
				):
					var gravity := get_gravity().y
					velocity.y = -sqrt(2.0 * gravity * CAKE_JUMP_HEIGHT)
					if absf(horizontal_distance) > CAKE_STOP_DISTANCE:
						velocity.x = signf(horizontal_distance) * CAKE_JUMP_HORIZONTAL_SPEED
					cake_jump_cooldown_timer = CAKE_JUMP_COOLDOWN
				elif absf(horizontal_distance) > CAKE_STOP_DISTANCE:
					if cake_sprint_timer <= 0.0 and cake_sprint_cooldown <= 0.0:
						cake_sprint_timer = CAKE_SPRINT_DURATION
						cake_sprint_cooldown = randf_range(
							CAKE_SPRINT_COOLDOWN_MIN,
							CAKE_SPRINT_COOLDOWN_MAX
						)
					if cake_sprint_timer > 0.0:
						cake_sprint_timer = maxf(cake_sprint_timer - delta, 0.0)
						velocity.x = signf(horizontal_distance) * CAKE_SPRINT_SPEED
					else:
						velocity.x = signf(horizontal_distance) * CAKE_CRAWL_SPEED
				else:
					cake_sprint_timer = 0.0
					velocity.x = move_toward(velocity.x, 0.0, 300.0)
			else:
				cake_sprint_timer = 0.0
				cake_sprint_cooldown = maxf(cake_sprint_cooldown, 0.0)
				roam_turn_timer -= delta
				if roam_turn_timer <= 0.0:
					roam_direction *= -1.0
					roam_speed = randf_range(ROAM_SPEED_MIN, ROAM_SPEED_MAX)
					roam_turn_timer = randf_range(
						ROAM_TURN_INTERVAL_MIN,
						ROAM_TURN_INTERVAL_MAX
					)
				velocity.x = roam_direction * roam_speed
				is_wandering = true
	move_and_slide()
	if is_wandering and is_on_wall():
		roam_direction *= -1.0
		roam_turn_timer = randf_range(
			ROAM_TURN_INTERVAL_MIN,
			ROAM_TURN_INTERVAL_MAX
		)


func _get_nearest_released_cake() -> Area2D:
	var nearest_cake: Area2D
	var nearest_distance := INF
	for food in get_tree().get_nodes_in_group("food"):
		var cake := food as Area2D
		if not is_instance_valid(cake) or cake.get("is_dragging"):
			continue
		if not cake.get("has_been_released"):
			continue

		var distance := global_position.distance_squared_to(cake.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_cake = cake
	return nearest_cake


func _input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.keycode == KEY_SPACE
		and event.pressed
		and not event.echo
		and _mouse_is_over_fancy()
	):
		hit()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _mouse_is_over_fancy():
			is_dragging = true
			drag_offset = get_global_mouse_position() - global_position
			velocity = Vector2.ZERO
			get_viewport().set_input_as_handled()
		elif not event.pressed and is_dragging:
			is_dragging = false
			get_viewport().set_input_as_handled()


func _mouse_is_over_fancy() -> bool:
	var shape := $CollisionShape2D.shape as RectangleShape2D
	var local_mouse: Vector2 = $CollisionShape2D.to_local(get_global_mouse_position())
	return Rect2(-shape.size / 2.0, shape.size).has_point(local_mouse)


func _setup_audio() -> void:
	var capture_bus_index := AudioServer.get_bus_index(CAPTURE_BUS_NAME)
	if capture_bus_index == -1:
		AudioServer.add_bus()
		capture_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(capture_bus_index, CAPTURE_BUS_NAME)

	var voice_bus_index := AudioServer.get_bus_index(VOICE_BUS_NAME)
	if voice_bus_index == -1:
		AudioServer.add_bus()
		voice_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(voice_bus_index, VOICE_BUS_NAME)

	var pitch_shift: AudioEffectPitchShift
	for effect_index in range(AudioServer.get_bus_effect_count(voice_bus_index)):
		var effect := AudioServer.get_bus_effect(voice_bus_index, effect_index)
		if effect is AudioEffectPitchShift:
			pitch_shift = effect as AudioEffectPitchShift
			break
	if pitch_shift == null:
		pitch_shift = AudioEffectPitchShift.new()
		AudioServer.add_bus_effect(voice_bus_index, pitch_shift)
	pitch_shift.pitch_scale = VOICE_PITCH

	capture_effect = AudioEffectCapture.new()
	AudioServer.add_bus_effect(capture_bus_index, capture_effect)
	AudioServer.set_bus_mute(capture_bus_index, true)

	microphone_player = AudioStreamPlayer.new()
	microphone_player.stream = AudioStreamMicrophone.new()
	microphone_player.bus = CAPTURE_BUS_NAME
	add_child(microphone_player)

	sample_rate = AudioServer.get_input_mix_rate()
	if sample_rate <= 0.0:
		sample_rate = AudioServer.get_mix_rate()

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = sample_rate
	generator.buffer_length = 0.2
	voice_player = AudioStreamPlayer.new()
	voice_player.stream = generator
	voice_player.bus = VOICE_BUS_NAME
	add_child(voice_player)

	response_player = AudioStreamPlayer.new()
	add_child(response_player)
	response_player.finished.connect(_finish_playback)

	capture_effect.clear_buffer()
	microphone_player.play()


func _process_microphone() -> void:
	var available_frames := capture_effect.get_frames_available()
	if available_frames <= 0:
		return

	var frames := capture_effect.get_buffer(mini(available_frames, 2048))
	var duration := float(frames.size()) / sample_rate
	if _get_rms(frames) >= VOICE_THRESHOLD:
		if not is_recording_phrase:
			is_recording_phrase = true
			phrase_frames.clear()
			voice_detected.emit()
		silence_duration = 0.0
		phrase_frames.append_array(frames)
	elif is_recording_phrase:
		silence_duration += duration
		phrase_frames.append_array(frames)

	if is_recording_phrase and (
		silence_duration >= SILENCE_TO_REPEAT
		or float(phrase_frames.size()) / sample_rate >= MAX_PHRASE_SECONDS
	):
		if yes_no_mode:
			_start_yes_no_response()
		else:
			_start_playback()


func _get_rms(frames: PackedVector2Array) -> float:
	if frames.is_empty():
		return 0.0

	var sum_of_squares := 0.0
	for frame in frames:
		sum_of_squares += frame.x * frame.x + frame.y * frame.y
	return sqrt(sum_of_squares / (frames.size() * 2.0))


func _start_playback() -> void:
	microphone_player.stop()
	capture_effect.clear_buffer()
	is_recording_phrase = false
	silence_duration = 0.0
	audio_state = AudioState.PLAYING

	voice_player.play()
	voice_playback = voice_player.get_stream_playback() as AudioStreamGeneratorPlayback
	playback_index = 0
	playback_drain_timer = 0.0
	_set_talking_animation()
	repeat_started.emit()


func _start_yes_no_response() -> void:
	microphone_player.stop()
	capture_effect.clear_buffer()
	is_recording_phrase = false
	silence_duration = 0.0
	phrase_frames.clear()
	audio_state = AudioState.PLAYING
	is_playing_response = true
	response_player.stream = YES_SOUND if randf() < 0.5 else NO_SOUND
	response_player.play()
	_set_talking_animation()


func _process_playback(delta: float) -> void:
	var frames_to_write := voice_playback.get_frames_available()
	var remaining_frames := phrase_frames.size() - playback_index
	var frame_count := mini(frames_to_write, remaining_frames)
	if frame_count > 0:
		voice_playback.push_buffer(
			phrase_frames.slice(playback_index, playback_index + frame_count)
		)
		playback_index += frame_count
	elif playback_index >= phrase_frames.size():
		playback_drain_timer += delta
		if playback_drain_timer >= PLAYBACK_DRAIN_SECONDS:
			_finish_playback()


func _finish_playback() -> void:
	var was_response := is_playing_response
	is_playing_response = false
	voice_player.stop()
	voice_playback = null
	phrase_frames.clear()
	capture_effect.clear_buffer()
	audio_state = AudioState.LISTENING
	microphone_player.play()
	_set_listening_animation()
	if not was_response:
		repeat_finished.emit()


func _set_talking_animation() -> void:
	if talking_tween and talking_tween.is_running():
		talking_tween.kill()
	sprite.texture = TALKING_TEXTURE
	sprite.scale = sprite_base_scale
	talking_tween = create_tween().set_loops()
	talking_tween.tween_property(
		sprite,
		"scale",
		sprite_base_scale * Vector2(1.035, 0.965),
		0.18
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	talking_tween.tween_property(
		sprite,
		"scale",
		sprite_base_scale * Vector2(0.98, 1.025),
		0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_listening_animation() -> void:
	if talking_tween and talking_tween.is_running():
		talking_tween.kill()
	sprite.scale = sprite_base_scale
	sprite.texture = HAPPY_TEXTURE if is_happy else NORMAL_TEXTURE


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("food"):
		return

	if area.get("is_dragging"):
		if not area.is_connected("drag_released", _on_food_released.bind(area)):
			area.connect(
				"drag_released",
				_on_food_released.bind(area),
				CONNECT_ONE_SHOT
			)
		return

	if not area.get("has_been_released"):
		return
	_consume_food(area)


func _on_food_released(area: Area2D) -> void:
	_consume_food_after_release.call_deferred(area)


func _consume_food_after_release(area: Area2D) -> void:
	await get_tree().physics_frame
	if is_instance_valid(area) and $Area2D.get_overlapping_areas().has(area):
		_consume_food(area)


func _consume_food(area: Area2D) -> void:
	if not is_instance_valid(area) or not area.is_in_group("food"):
		return

	area.queue_free()
	eating_player.play()
	_grow_after_eating()
	_change_trust(TRUST_PER_CAKE)
	is_happy = true
	happy_time_remaining = 2.0
	if audio_state == AudioState.LISTENING:
		_set_listening_animation()
	ate_food.emit()


func _grow_after_eating() -> void:
	growth_multiplier = minf(growth_multiplier + CAKE_GROWTH_STEP, MAX_GROWTH_SCALE)
	if growth_tween and growth_tween.is_running():
		growth_tween.kill()

	growth_tween = create_tween()
	growth_tween.tween_property(
		self,
		"scale",
		fancy_base_scale * growth_multiplier,
		0.25
	)
	growth_tween.tween_interval(0.35)
	growth_tween.tween_property(self, "scale", fancy_base_scale, 3.0)
	growth_tween.tween_callback(_reset_growth_multiplier)


func _reset_growth_multiplier() -> void:
	growth_multiplier = 1.0


func _change_trust(amount: int) -> void:
	var updated_trust := clampi(trust + amount, 0, TRUST_MAX)
	if updated_trust == trust:
		return
	trust = updated_trust


func set_yes_no_mode(enabled: bool) -> void:
	yes_no_mode = enabled


func hit() -> void:
	_change_trust(-TRUST_LOST_PER_HIT)
	_spawn_blood_splatter()
	velocity = Vector2(randf_range(-350.0, 350.0), -650.0)
	is_happy = true
	happy_time_remaining = 1.0
	_set_listening_animation()
	explosion_player.play()
	death_player.play()


func _spawn_blood_splatter() -> void:
	var blood := CPUParticles2D.new()
	blood.texture = _create_blood_droplet_texture()
	blood.position = Vector2(0.0, -20.0)
	blood.emitting = false
	blood.one_shot = true
	blood.amount = 120
	blood.lifetime = 0.9
	blood.explosiveness = 1.0
	blood.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	blood.emission_sphere_radius = 20.0
	blood.direction = Vector2.UP
	blood.spread = 180.0
	blood.gravity = Vector2(0.0, 520.0)
	blood.initial_velocity_min = 160.0
	blood.initial_velocity_max = 420.0
	blood.scale_amount_min = 0.8
	blood.scale_amount_max = 2.2
	blood.color = Color(0.78, 0.015, 0.04)
	blood.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blood.finished.connect(blood.queue_free)
	add_child(blood)
	blood.emitting = true


func _create_blood_droplet_texture() -> ImageTexture:
	var rows := [
		"00010000",
		"00111000",
		"01111100",
		"11111110",
		"11111110",
		"01111100",
		"00111000",
		"00010000",
	]
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			if rows[y][x] == "1":
				image.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)
