extends Node
## v0.19 check: quitting at once, while the music samples are still being synthesised on a worker thread, must not crash
## the engine at exit (it did, signal 11). The runner counts crashes: run it and look for "signal 11".
##   godot --headless --path . -- --test res://tests/quittest.gd

func run(_m: Node) -> void:
	var mus = get_node("/root/Music")
	printerr("PASS quit_during_startup  samples_ready=" + str(mus._ready_samples))
	get_tree().quit()
