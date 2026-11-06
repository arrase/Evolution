class_name EvoOllamaClient
extends RefCounted

const DEFAULT_OLLAMA_HOST: String = "127.0.0.1"
const DEFAULT_OLLAMA_PORT: int = 11434
const DEFAULT_SYSTEM_ONE_MODEL: String = "d3:4b"
const SECONDARY_SYSTEM_ONE_MODEL: String = "tev1:4b"
const STATUS_TIMEOUT_MS: int = 1500
const EVAL_TIMEOUT_MS: int = 4500
const SYSTEM_ONE_INSTRUCTIONS: String = "Evaluate the ecological, energetic, and social state of the deme and its passable neighbors to score each behavioral decision."

static var _mutex := Mutex.new()
static var _cached_ollama_status: Dictionary = {}
static var _live_signature_cache: Dictionary = {}
static var _pending_jobs_by_sig: Dictionary = {}
static var _worker_task_id: int = -1
static var _worker_running: bool = false
static var _status_probed: bool = false
static var _status_probe_running: bool = false
static var _status_task_id: int = -1
static var _shutdown_requested: bool = false
static var _completed_revision: int = 0
static var _newly_completed_sigs: Dictionary = {}


static func _default_ollama_status() -> Dictionary:
	return {
		"connected": false,
		"primary_ready": false,
		"secondary_ready": false,
		"both_ready": false,
		"primary_tag": DEFAULT_SYSTEM_ONE_MODEL,
		"secondary_tag": SECONDARY_SYSTEM_ONE_MODEL,
		"missing_commands": [
			"ollama pull " + DEFAULT_SYSTEM_ONE_MODEL,
			"ollama pull " + SECONDARY_SYSTEM_ONE_MODEL
		]
	}


static func check_ollama_status(force_refresh: bool = false) -> Dictionary:
	var task_to_reap: int = -1
	_mutex.lock()
	if _cached_ollama_status.is_empty():
		_cached_ollama_status = _default_ollama_status()
	var should_launch := (not _status_probed or force_refresh) and not _status_probe_running and not _shutdown_requested
	if should_launch:
		_status_probe_running = true
		task_to_reap = _status_task_id
		_status_task_id = -1
	var snapshot := _cached_ollama_status.duplicate(true)
	_mutex.unlock()

	if should_launch:
		if task_to_reap != -1 and WorkerThreadPool.is_task_completed(task_to_reap):
			WorkerThreadPool.wait_for_task_completion(task_to_reap)
		var new_task_id := WorkerThreadPool.add_task(Callable(EvoOllamaClient, "_probe_ollama_status_worker"))
		_mutex.lock()
		_status_task_id = new_task_id
		_mutex.unlock()

	return snapshot


static func _probe_ollama_status_worker() -> void:
	_probe_ollama_status_sync()


static func _probe_ollama_status_sync() -> Dictionary:
	var primary_tag: String = DEFAULT_SYSTEM_ONE_MODEL
	var secondary_tag: String = SECONDARY_SYSTEM_ONE_MODEL
	var primary_ready: bool = false
	var secondary_ready: bool = false
	var connected: bool = false

	if not _shutdown_requested:
		var client := HTTPClient.new()
		var err := client.connect_to_host(DEFAULT_OLLAMA_HOST, DEFAULT_OLLAMA_PORT)
		if err == OK:
			var start_ms := Time.get_ticks_msec()
			while not _shutdown_requested and client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
				client.poll()
				if Time.get_ticks_msec() - start_ms > STATUS_TIMEOUT_MS:
					break
				OS.delay_msec(2)

			if not _shutdown_requested and client.get_status() == HTTPClient.STATUS_CONNECTED:
				var req_err := client.request(HTTPClient.METHOD_GET, "/api/tags", ["Accept: application/json"])
				if req_err == OK:
					while not _shutdown_requested and client.get_status() == HTTPClient.STATUS_REQUESTING:
						client.poll()
						if Time.get_ticks_msec() - start_ms > STATUS_TIMEOUT_MS:
							break
						OS.delay_msec(2)

					if not _shutdown_requested and client.has_response() and client.get_response_code() == 200:
						var rb := PackedByteArray()
						while not _shutdown_requested and client.get_status() == HTTPClient.STATUS_BODY:
							client.poll()
							var chunk := client.read_response_body_chunk()
							if chunk.size() > 0:
								rb.append_array(chunk)
							else:
								if Time.get_ticks_msec() - start_ms > STATUS_TIMEOUT_MS:
									break
								OS.delay_msec(1)
						var parsed = JSON.parse_string(rb.get_string_from_utf8())
						if typeof(parsed) == TYPE_DICTIONARY and parsed.has("models"):
							connected = true
							var models: Array = parsed["models"]
							for m in models:
								if typeof(m) == TYPE_DICTIONARY and m.has("name"):
									var mname := str(m["name"])
									if mname == DEFAULT_SYSTEM_ONE_MODEL:
										primary_ready = true
										primary_tag = mname
									elif not primary_ready and mname.begins_with("d3:"):
										primary_ready = true
										primary_tag = mname
									if mname == SECONDARY_SYSTEM_ONE_MODEL:
										secondary_ready = true
										secondary_tag = mname
									elif not secondary_ready and mname.begins_with("tev1:"):
										secondary_ready = true
										secondary_tag = mname
		client.close()

	var missing_commands: Array[String] = []
	if not primary_ready:
		missing_commands.append("ollama pull " + DEFAULT_SYSTEM_ONE_MODEL)
	if not secondary_ready:
		missing_commands.append("ollama pull " + SECONDARY_SYSTEM_ONE_MODEL)

	var status := {
		"connected": connected,
		"primary_ready": primary_ready,
		"secondary_ready": secondary_ready,
		"both_ready": connected and primary_ready and secondary_ready,
		"primary_tag": primary_tag,
		"secondary_tag": secondary_tag,
		"missing_commands": missing_commands
	}

	_mutex.lock()
	_cached_ollama_status = status
	_status_probed = true
	_status_probe_running = false
	_mutex.unlock()
	return status.duplicate(true)


static func _resolve_ollama_model_for_tag(desired: String, status: Dictionary) -> String:
	if desired == SECONDARY_SYSTEM_ONE_MODEL or desired.begins_with("tev1:"):
		if bool(status.get("secondary_ready", false)):
			return str(status.get("secondary_tag", SECONDARY_SYSTEM_ONE_MODEL))
		return str(status.get("primary_tag", DEFAULT_SYSTEM_ONE_MODEL))
	if bool(status.get("primary_ready", false)):
		return str(status.get("primary_tag", DEFAULT_SYSTEM_ONE_MODEL))
	return str(status.get("secondary_tag", SECONDARY_SYSTEM_ONE_MODEL))


static func build_live_job(sig: String, rep: EvoTypes.Deme, state: EvoTypes.WorldState) -> Dictionary:
	if not state.cells.has(rep.hex_id):
		return {}
	var eligible_decisions := EvoHeuristicScorer.get_eligible_decisions(rep, state.decisions_catalog)
	var eligible_ids: Array[String] = []
	for dec in eligible_decisions:
		eligible_ids.append(dec.id)
	if eligible_ids.is_empty():
		return {}
	var preferred_tag := rep.decision_model_tag if rep.decision_model_tag != "" else EvoHeuristicScorer.resolve_deme_decision_model_tag(rep.id)
	return {
		"sig": sig,
		"preferred_tag": preferred_tag,
		"briefing": EvoHeuristicScorer.build_compact_system_one_state(rep, state),
		"criteria": EvoHeuristicScorer.build_compact_decision_criteria(eligible_decisions),
		"eligible_ids": eligible_ids
	}


static func lookup_or_enqueue_single_deme(
	sig: String,
	deme: EvoTypes.Deme,
	state: EvoTypes.WorldState
) -> Dictionary:
	var cached_entry: Dictionary = {}
	var need_enqueue := false
	_mutex.lock()
	if _live_signature_cache.has(sig):
		cached_entry = (_live_signature_cache[sig] as Dictionary).duplicate(true)
	elif not _pending_jobs_by_sig.has(sig) and not _shutdown_requested:
		need_enqueue = true
	_mutex.unlock()

	if not cached_entry.is_empty():
		return cached_entry

	if need_enqueue:
		var job := build_live_job(sig, deme, state)
		if not job.is_empty():
			_mutex.lock()
			if not _live_signature_cache.has(sig) and not _pending_jobs_by_sig.has(sig):
				_pending_jobs_by_sig[sig] = job
			_mutex.unlock()
			_start_worker_if_needed()

	return {}


static func sync_and_enqueue_batch(buckets: Dictionary, state: EvoTypes.WorldState) -> Dictionary:
	var live_results: Dictionary = {}
	var missing_sigs: Array[String] = []
	if state.use_live_decision_models and not buckets.is_empty():
		_mutex.lock()
		for pending_sig in _pending_jobs_by_sig.keys():
			if not buckets.has(pending_sig):
				_pending_jobs_by_sig.erase(pending_sig)
		for sig in buckets.keys():
			if _live_signature_cache.has(sig):
				live_results[sig] = (_live_signature_cache[sig] as Dictionary).duplicate(true)
			elif not _pending_jobs_by_sig.has(sig) and not _shutdown_requested:
				missing_sigs.append(str(sig))
		_mutex.unlock()

	var new_jobs: Array[Dictionary] = []
	for sig in missing_sigs:
		var rep_deme: EvoTypes.Deme = buckets[sig]["representative"]
		var job := build_live_job(sig, rep_deme, state)
		if not job.is_empty():
			new_jobs.append(job)

	if not new_jobs.is_empty():
		_mutex.lock()
		for job in new_jobs:
			var s := str(job["sig"])
			if not _live_signature_cache.has(s) and not _pending_jobs_by_sig.has(s):
				_pending_jobs_by_sig[s] = job
		_mutex.unlock()
		_start_worker_if_needed()

	return live_results


static func prefetch_for_reps(reps_by_sig: Dictionary, state: EvoTypes.WorldState) -> void:
	var missing_sigs: Array[String] = []
	_mutex.lock()
	if not _shutdown_requested:
		for pending_sig in _pending_jobs_by_sig.keys():
			if not reps_by_sig.has(pending_sig):
				_pending_jobs_by_sig.erase(pending_sig)
		for sig in reps_by_sig.keys():
			if not _live_signature_cache.has(sig) and not _pending_jobs_by_sig.has(sig):
				missing_sigs.append(str(sig))
	_mutex.unlock()

	if missing_sigs.is_empty():
		return

	var new_jobs: Array[Dictionary] = []
	for sig in missing_sigs:
		var job := build_live_job(sig, reps_by_sig[sig], state)
		if not job.is_empty():
			new_jobs.append(job)

	if not new_jobs.is_empty():
		_mutex.lock()
		for job in new_jobs:
			var s := str(job["sig"])
			if not _live_signature_cache.has(s) and not _pending_jobs_by_sig.has(s):
				_pending_jobs_by_sig[s] = job
		_mutex.unlock()
		_start_worker_if_needed()


static func pop_newly_completed(last_seen_rev: int, enabled: bool) -> Dictionary:
	_mutex.lock()
	var current_rev := _completed_revision
	if current_rev == last_seen_rev or not enabled or _newly_completed_sigs.is_empty():
		_mutex.unlock()
		return {"revision": current_rev, "newly_completed": {}}
	var newly_completed := _newly_completed_sigs.duplicate(true)
	_newly_completed_sigs.clear()
	_mutex.unlock()
	return {"revision": current_rev, "newly_completed": newly_completed}


static func _start_worker_if_needed() -> void:
	var task_to_reap: int = -1
	_mutex.lock()
	var should_start := not _shutdown_requested and not _worker_running and not _pending_jobs_by_sig.is_empty()
	if should_start:
		_worker_running = true
		task_to_reap = _worker_task_id
		_worker_task_id = -1
	_mutex.unlock()

	if should_start:
		if task_to_reap != -1 and WorkerThreadPool.is_task_completed(task_to_reap):
			WorkerThreadPool.wait_for_task_completion(task_to_reap)
		var new_task_id := WorkerThreadPool.add_task(Callable(EvoOllamaClient, "_run_ollama_worker"))
		_mutex.lock()
		_worker_task_id = new_task_id
		_mutex.unlock()


static func _run_ollama_worker() -> void:
	var need_probe := false
	_mutex.lock()
	if not _status_probed and not _status_probe_running and not _shutdown_requested:
		_status_probe_running = true
		need_probe = true
	_mutex.unlock()

	if need_probe:
		_probe_ollama_status_sync()
	else:
		while not _shutdown_requested:
			_mutex.lock()
			var done_probing := _status_probed or not _status_probe_running
			_mutex.unlock()
			if done_probing:
				break
			OS.delay_msec(2)

	while not _shutdown_requested:
		var batch: Array[Dictionary] = []
		var status: Dictionary = {}

		_mutex.lock()
		if _pending_jobs_by_sig.is_empty() or _shutdown_requested:
			_worker_running = false
			_mutex.unlock()
			return
		status = _cached_ollama_status.duplicate(true)
		var can_eval := bool(status.get("connected", false)) and (bool(status.get("primary_ready", false)) or bool(status.get("secondary_ready", false)))
		if not can_eval:
			_pending_jobs_by_sig.clear()
			_worker_running = false
			_mutex.unlock()
			return
		var keys := _pending_jobs_by_sig.keys()
		var count := mini(4, keys.size())
		for i in range(count):
			var k := str(keys[i])
			batch.append(_pending_jobs_by_sig[k])
			_pending_jobs_by_sig.erase(k)
		_mutex.unlock()

		var batch_results := _evaluate_job_batch_with_ollama(batch, status)
		if not batch_results.is_empty():
			_mutex.lock()
			for sig_key in batch_results.keys():
				_live_signature_cache[sig_key] = batch_results[sig_key]
				_newly_completed_sigs[sig_key] = batch_results[sig_key]
			_completed_revision += 1
			_mutex.unlock()

	_mutex.lock()
	_worker_running = false
	_mutex.unlock()


static func _evaluate_job_batch_with_ollama(
	batch: Array[Dictionary],
	status: Dictionary
) -> Dictionary:
	var results_by_sig: Dictionary = {}
	var active_jobs: Array[Dictionary] = []

	for item in batch:
		if _shutdown_requested:
			break
		var model_tag := _resolve_ollama_model_for_tag(str(item["preferred_tag"]), status)
		var payload := {
			"model": model_tag,
			"keep_alive": "30m",
			"state": {
				"briefing": str(item["briefing"])
			},
			"questions": {
				"decision": {
					"type": "choice",
					"instructions": SYSTEM_ONE_INSTRUCTIONS,
					"criteria": item["criteria"]
				}
			}
		}
		var body_str := JSON.stringify(payload)
		var client := HTTPClient.new()
		var err := client.connect_to_host(DEFAULT_OLLAMA_HOST, DEFAULT_OLLAMA_PORT)
		active_jobs.append({
			"sig": str(item["sig"]),
			"client": client,
			"body": body_str,
			"eligible_ids": item["eligible_ids"],
			"stage": "connecting" if err == OK else "failed",
			"rb": PackedByteArray()
		})

	var start_ms := Time.get_ticks_msec()
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])

	while not _shutdown_requested and Time.get_ticks_msec() - start_ms <= EVAL_TIMEOUT_MS:
		var any_active := false
		for job in active_jobs:
			var stage := str(job["stage"])
			if stage in ["done", "failed"]:
				continue
			any_active = true
			var client: HTTPClient = job["client"]
			client.poll()
			var st := client.get_status()

			if stage == "connecting":
				if st in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
					continue
				elif st == HTTPClient.STATUS_CONNECTED:
					var req_err := client.request(HTTPClient.METHOD_POST, "/v1/systemone", headers, str(job["body"]))
					job["stage"] = "requesting" if req_err == OK else "failed"
				else:
					job["stage"] = "failed"
			elif stage == "requesting":
				if st == HTTPClient.STATUS_REQUESTING:
					continue
				elif client.has_response() and client.get_response_code() == 200:
					if st == HTTPClient.STATUS_BODY:
						var chunk := client.read_response_body_chunk()
						if chunk.size() > 0:
							var rb: PackedByteArray = job["rb"]
							rb.append_array(chunk)
							job["rb"] = rb
					if client.get_status() == HTTPClient.STATUS_BODY:
						job["stage"] = "reading_body"
					else:
						job["stage"] = "done" if (job["rb"] as PackedByteArray).size() > 0 else "failed"
				else:
					job["stage"] = "failed"
			elif stage == "reading_body":
				if st == HTTPClient.STATUS_BODY:
					var chunk := client.read_response_body_chunk()
					if chunk.size() > 0:
						var rb: PackedByteArray = job["rb"]
						rb.append_array(chunk)
						job["rb"] = rb
				if client.get_status() != HTTPClient.STATUS_BODY:
					job["stage"] = "done" if (job["rb"] as PackedByteArray).size() > 0 else "failed"

		if not any_active:
			break
		OS.delay_msec(2)

	for job in active_jobs:
		var client: HTTPClient = job["client"]
		client.close()
		if _shutdown_requested or str(job["stage"]) != "done":
			continue
		var raw_text := (job["rb"] as PackedByteArray).get_string_from_utf8()
		var parsed = JSON.parse_string(raw_text)
		if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("answers"):
			continue
		var answers = parsed["answers"]
		if typeof(answers) != TYPE_DICTIONARY or not answers.has("decision"):
			continue
		var dec_ans = answers["decision"]
		if typeof(dec_ans) != TYPE_DICTIONARY or not dec_ans.has("probabilities"):
			continue
		var raw_probs = dec_ans["probabilities"]
		if typeof(raw_probs) != TYPE_DICTIONARY:
			continue

		var eligible_ids: Array[String] = job["eligible_ids"]
		var normalized := EvoHeuristicScorer.normalize_decision_probabilities(raw_probs, eligible_ids)
		var raw_conf: float = float(dec_ans["confidence"]) if dec_ans.has("confidence") else 0.75
		var clean_conf: float = snappedf(clampf(raw_conf, 0.0, 1.0), 0.0001) if (not is_nan(raw_conf) and not is_inf(raw_conf)) else 0.75
		results_by_sig[str(job["sig"])] = {
			"probabilities": normalized["probabilities"],
			"dominant_decision_id": str(normalized["dominant_decision_id"]),
			"confidence": clean_conf
		}

	return results_by_sig


static func has_pending_jobs() -> bool:
	_mutex.lock()
	var pending := _worker_running or not _pending_jobs_by_sig.is_empty()
	_mutex.unlock()
	return pending


static func wait_for_workers() -> void:
	_mutex.lock()
	_shutdown_requested = true
	_pending_jobs_by_sig.clear()
	var s_task := _status_task_id
	var w_task := _worker_task_id
	_status_task_id = -1
	_worker_task_id = -1
	_mutex.unlock()

	if s_task != -1:
		WorkerThreadPool.wait_for_task_completion(s_task)
	if w_task != -1:
		WorkerThreadPool.wait_for_task_completion(w_task)

	_mutex.lock()
	_status_probe_running = false
	_worker_running = false
	_shutdown_requested = false
	_mutex.unlock()
