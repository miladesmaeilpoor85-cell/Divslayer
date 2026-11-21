extends Node
## Android-only QA scene. The workflow temporarily selects this scene as the APK entrypoint.
## It exercises the real Mage Starter spell -> cast_done -> Player.cast_front path.

const MainScript = preload("res://tests/mage_cast_runtime_main.gd")

var _frame_sequence: Array[int] = []
var _first_advanced_at_ms := 0
var _animation_finished_received := false
var _animation_finished_at_ms := 0
var _capture_requested := false

func _ready() -> void:
    call_deferred("_run")

func _physics_frames(count: int) -> void:
    for _i in count:
        await get_tree().physics_frame

func _fail(reason: String) -> void:
    push_error("MAGE_CAST_FRONT_RUNTIME_FAIL: " + reason)

func _frame_sequence_text() -> String:
    var values: Array[String] = []
    for frame_index in _frame_sequence:
        values.append(str(frame_index))
    return ",".join(values)

func _on_cast_frame_changed(anim: AnimatedSprite2D, player: Node, started_at_ms: int) -> void:
    if not is_instance_valid(anim) or not is_instance_valid(player):
        return
    # The production animation_finished handler is connected first and turns
    # _mage_cast_front_active off before AnimatedSprite2D resets its stopped frame.
    if not player._mage_cast_front_active or anim.frame <= 0:
        return
    if _frame_sequence.is_empty() or _frame_sequence.back() != anim.frame:
        _frame_sequence.append(anim.frame)
    if anim.frame == 1 and _first_advanced_at_ms == 0:
        _first_advanced_at_ms = Time.get_ticks_msec()
        _capture_requested = true
        print("MAGE_CAST_FRONT_FRAME_ADVANCED frame=1 elapsed_ms=%d" % [
            _first_advanced_at_ms - started_at_ms
        ])
    elif anim.frame > 1:
        print("MAGE_CAST_FRONT_FRAME_STEP frame=%d elapsed_ms=%d" % [
            anim.frame, Time.get_ticks_msec() - started_at_ms
        ])

func _on_cast_animation_finished(anim: AnimatedSprite2D, player: Node, started_at_ms: int) -> void:
    _animation_finished_received = true
    _animation_finished_at_ms = Time.get_ticks_msec()
    print("MAGE_CAST_FRONT_FINISHED_SIGNAL animation=%s elapsed_ms=%d active_after_handler=%s overlay_visible=%s base_visible=%s" % [
        anim.animation,
        _animation_finished_at_ms - started_at_ms,
        player._mage_cast_front_active,
        anim.visible,
        player.anim.visible
    ])

func _run() -> void:
    Game.new_game("mage")
    Game.state["slots"] = ["bolt", "nova"]
    var main = MainScript.new()
    add_child(main)
    await get_tree().process_frame
    Game.mp = Game.max_mp()
    main.start_world()
    await _physics_frames(8)

    var player = main.player
    if player == null or not is_instance_valid(player):
        _fail("Player did not initialize")
        return
    if Game.cls != "mage" or player.sheet != "mage_starter":
        _fail("Expected Mage Starter, got class=%s sheet=%s" % [Game.cls, player.sheet])
        return

    # Remove nearby enemies so auto-aim cannot turn the cast away from the front.
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if is_instance_valid(enemy):
            enemy.queue_free()
    await get_tree().process_frame
    player.joy = Vector2.ZERO
    player.move_dir = Vector2.ZERO
    player.moving = false
    player.facing = "down"
    player.attacking = 0.0
    player.blocking = false
    player.sneaking = false
    player.invuln = 0.0
    Game.mp = Game.max_mp()

    var cast_ok: bool = player.caster.cast("bolt")
    if not cast_ok:
        _fail("The Mage Starter bolt spell did not cast successfully")
        return
    if not player._mage_cast_front_active or player.cast_anim == null:
        _fail("Successful spell did not activate the cast-front overlay")
        return
    if player.facing != "down":
        _fail("The spell did not remain front-facing: %s" % player.facing)
        return

    var anim: AnimatedSprite2D = player.cast_anim
    var frames: SpriteFrames = anim.sprite_frames
    var clip_frames := frames.get_frame_count("cast_front") if frames else -1
    var clip_fps := frames.get_animation_speed("cast_front") if frames else -1.0
    var started_at := Time.get_ticks_msec()
    if clip_frames != 12:
        _fail("Expected exactly 12 cast_front frames, got %d" % clip_frames)
        return
    if not is_equal_approx(clip_fps, 8.0):
        _fail("Expected cast_front at 8 FPS, got %.2f" % clip_fps)
        return
    if frames.get_animation_loop("cast_front"):
        _fail("cast_front must be a one-shot (loop=false) animation")
        return

    _frame_sequence.clear()
    _frame_sequence.append(anim.frame)
    _first_advanced_at_ms = 0
    _animation_finished_received = false
    _animation_finished_at_ms = 0
    _capture_requested = false
    var frame_callback := _on_cast_frame_changed.bind(anim, player, started_at)
    var finish_callback := _on_cast_animation_finished.bind(anim, player, started_at)
    anim.frame_changed.connect(frame_callback)
    anim.animation_finished.connect(finish_callback)

    print("MAGE_CAST_FRONT_DIAG_START playing=%s inside_tree=%s process_internal=%s process_mode=%d frame_count=%d clip_fps=%.2f speed_scale=%.2f frame=%d progress=%.3f engine_time_scale=%.3f tree_paused=%s" % [
        anim.is_playing(), anim.is_inside_tree(), anim.is_processing_internal(), anim.process_mode,
        clip_frames, clip_fps, anim.speed_scale, anim.frame, anim.frame_progress,
        Engine.time_scale, get_tree().paused
    ])

    # Let the one-shot play at its production speed. Do not pause, seek, or
    # manually advance it: this must cover all 12 natural frame changes.
    var shot_path := "user://mage-cast-front-active.png"
    var screenshot_saved := false
    var deadline_ms := Time.get_ticks_msec() + 30000
    while not _animation_finished_received and Time.get_ticks_msec() < deadline_ms:
        await get_tree().process_frame
        if _capture_requested and not screenshot_saved:
            _capture_requested = false
            await get_tree().process_frame
            if is_instance_valid(anim) and player._mage_cast_front_active and anim.visible:
                var shot := get_viewport().get_texture().get_image()
                if shot == null or shot.save_png(shot_path) != OK:
                    _fail("Could not save the active cast-front screenshot")
                    return
                screenshot_saved = true
                print("MAGE_CAST_FRONT_SCREENSHOT_PASS frame=%d path=%s" % [
                    anim.frame, ProjectSettings.globalize_path(shot_path)
                ])

    var elapsed_ms := Time.get_ticks_msec() - started_at
    if anim.frame_changed.is_connected(frame_callback):
        anim.frame_changed.disconnect(frame_callback)
    if anim.animation_finished.is_connected(finish_callback):
        anim.animation_finished.disconnect(finish_callback)

    if not _animation_finished_received:
        _fail("animation_finished did not arrive within 30s; frames=%s current_frame=%d playing=%s active=%s elapsed_ms=%d" % [
            _frame_sequence_text(), anim.frame, anim.is_playing(),
            player._mage_cast_front_active, elapsed_ms
        ])
        return

    if _frame_sequence.size() != clip_frames:
        _fail("Expected 12 naturally observed frames, got %d; sequence=%s" % [
            _frame_sequence.size(), _frame_sequence_text()
        ])
        return
    for expected_frame in range(clip_frames):
        if _frame_sequence[expected_frame] != expected_frame:
            _fail("Frame sequence mismatch at index %d; expected %d, sequence=%s" % [
                expected_frame, expected_frame, _frame_sequence_text()
            ])
            return

    if not screenshot_saved:
        _fail("The active animation screenshot was not captured while the overlay was visible")
        return

    print("MAGE_CAST_FRONT_ALL_FRAMES_PASS sequence=%s total=%d elapsed_ms=%d" % [
        _frame_sequence_text(), _frame_sequence.size(), elapsed_ms
    ])

    # Player._on_mage_cast_front_finished must have run naturally from the
    # animation_finished signal and restored the normal directional sprite.
    if player._mage_cast_front_active or anim.visible or not player.anim.visible:
        _fail("Natural completion did not restore the base sprite; active=%s overlay_visible=%s base_visible=%s" % [
            player._mage_cast_front_active, anim.visible, player.anim.visible
        ])
        return
    if anim.is_playing():
        _fail("The cast overlay is still playing after its natural finish signal")
        return
    print("MAGE_CAST_FRONT_AUTO_FINISH_PASS elapsed_ms=%d active=false overlay_visible=false base_visible=true" % [
        _animation_finished_at_ms - started_at
    ])

    # A second successful cast is interrupted by movement to retain coverage of
    # the existing cancellation path, independently of natural completion.
    player.moving = false
    player.move_dir = Vector2.ZERO
    player.facing = "down"
    player.caster.cds.erase("bolt")
    Game.mp = Game.max_mp()
    var cancel_cast_ok: bool = player.caster.cast("bolt")
    if not cancel_cast_ok or not player._mage_cast_front_active:
        _fail("Could not start the second cast for the movement-cancellation check")
        return
    player.moving = true
    player.move_dir = Vector2.DOWN
    player._animate(Vector2.DOWN)
    if player._mage_cast_front_active or anim.visible or not player.anim.visible:
        _fail("Movement did not cancel the overlay and restore the base sprite")
        return
    print("MAGE_CAST_FRONT_CANCEL_PASS movement=down base_sprite_visible=true")
