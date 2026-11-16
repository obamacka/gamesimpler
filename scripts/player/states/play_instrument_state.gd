## PlayInstrument (spec 7.4): note_1..8 play the major scale (generated tones until samples
## exist), polyphony 4 per note. No score, no fail. Moving or the wheel button exits.
extends PlayerState

const RATE := 22050
const LENGTH := 0.45

var instrument: InstrumentDef
var players: Array[AudioStreamPlayer3D] = []


func enter(_msg: Dictionary = {}) -> void:
	instrument = Database.instruments.get(player.pending_instrument)
	player.pending_instrument = &""
	if instrument == null:
		instrument = Database.instruments.values()[0]
	for i in 8:
		var p := AudioStreamPlayer3D.new()
		p.stream = tone(instrument, i)
		p.max_polyphony = 4
		player.add_child(p)
		players.append(p)


func physics_tick(_delta: float, f: InputFrame) -> void:
	for i in 8:
		if f.notes_pressed & (1 << i):
			play(i)


func play(i: int) -> void:
	if i < players.size():
		players[i].play()
	EventBus.note_played.emit(instrument.id, i)


func exit() -> void:
	for p in players:
		p.queue_free()
	players.clear()


func locks_tool() -> bool:
	return true


func move_speed() -> float:
	return 0.0


static func tone(inst: InstrumentDef, note: int) -> AudioStreamWAV:
	var hz := inst.note_hz(note)
	var n := int(RATE * LENGTH)
	var data := PackedByteArray()
	data.resize(n * 2)
	var seed_v := 12345
	for k in n:
		var t := float(k) / RATE
		var env := exp(-t * (9.0 if inst.wave == &"pluck" else 4.0))
		var v := 0.0
		match inst.wave:
			&"noise":
				seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
				v = (float(seed_v % 2000) / 1000.0 - 1.0) * exp(-t * 18.0) + sin(TAU * hz * t) * env
			_:
				v = sin(TAU * hz * t) * env
		data.encode_s16(k * 2, int(clampf(v * 0.5, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
