class_name EvoOllamaClient
extends RefCounted

const DEFAULT_OLLAMA_HOST: String = "127.0.0.1"
const DEFAULT_OLLAMA_PORT: int = 11434
const STATUS_TIMEOUT_MS: int = 1500
const EVAL_TIMEOUT_MS: int = 60000
const PULL_STALL_TIMEOUT_MS: int = 60000
const MAX_CONCURRENT_JOBS: int = 8

static var _mutex := Mutex.new()
static var _cached_ollama_status: Dictionary = {}
static var _results_by_deme: Dictionary = {}
static var _pending_jobs: Array[Dictionary] = []
static var _cache_epoch: int = 0
static var _active_worker_epoch: int = -1
static var _worker_task_id: int = -1
static var _worker_running: bool = false
static var _status_probed: bool = false
static var _status_probe_running: bool = false
static var _status_reprobe_requested: bool = false
static var _status_task_id: int = -1
static var _shutdown_requested: bool = false
static var _completed_revision: int = 0
static var _newly_completed: Dictionary = {}

static var _pull_task_id: int = -1
static var _pull_running: bool = false
static var _pull_cancel_requested: bool = false
static var _pull_queue: Array[String] = []
static var _pull_state: Dictionary = {
	"running": false,
	"done": false,
	"failed": false,
	"current_model": "",
	"status_text": "",
	"percent": 0.0
}


static func _default_ollama_status() -> Dictionary:
	var p_tag := EvoUserSettings.primary_model
	var s_tag := EvoUserSettings.secondary_model
	var missing_cmds: Array[String] = ["ollama pull " + p_tag]
	var missing_mods: Array[String] = [p_tag]
	if s_tag != p_tag:
		missing_cmds.append("ollama pull " + s_tag)
		missing_mods.append(s_tag)
	var dec_models: Array[String] = []
	return {
		"probed": false,
		"connected": false,
		"primary_ready": false,
		"secondary_ready": false,
		"both_ready": false,
		"primary_tag": p_tag,
		"secondary_tag": s_tag,
		"decision_models": dec_models,
		"missing_models": missing_mods,
		"missing_commands": missing_cmds
	}


static func clear_cache() -> void:
	_mutex.lock()
	_cache_epoch += 1
	_results_by_deme.clear()
	_pending_jobs.clear()
	_newly_completed.clear()
	_mutex.unlock()


static func check_ollama_status(force_refresh: bool = false) -> Dictionary:
	var task_to_reap: int = -1
	_mutex.lock()
	if _cached_ollama_status.is_empty():
		_cached_ollama_status = _default_ollama_status()
	else:
		_cached_ollama_status["primary_tag"] = EvoUserSettings.primary_model
		_cached_ollama_status["secondary_tag"] = EvoUserSettings.secondary_model
	var should_launch := (not _status_probed or force_refresh) and not _status_probe_running and not _shutdown_requested
	if should_launch:
		_status_probe_running = true
		_status_reprobe_requested = false
		task_to_reap = _status_task_id
		_status_task_id = -1
	elif force_refresh and _status_probe_running and not _shutdown_requested:
		_status_reprobe_requested = true
	var snapshot := _cached_ollama_status.duplicate(true)
	_mutex.unlock()

	if should_launch:
		if task_to_reap != -1:
			WorkerThreadPool.wait_for_task_completion(task_to_reap)
		var new_task_id := WorkerThreadPool.add_task(Callable(EvoOllamaClient, "_probe_ollama_status_worker"))
		_mutex.lock()
		_status_task_id = new_task_id
		_mutex.unlock()

	return snapshot


static func refresh_ollama_status_async() -> void:
	check_ollama_status(true)


static func _probe_ollama_status_worker() -> void:
	_probe_ollama_status_sync()


static func filter_decision_models_from_tags(models: Array) -> Array[String]:
	var decision_models: Array[String] = []
	for m in models:
		if typeof(m) == TYPE_DICTIONARY and m.has("name"):
			var mname := str(m["name"])
			if m.has("capabilities") and typeof(m["capabilities"]) == TYPE_ARRAY:
				var caps: Array = m["capabilities"]
				if caps.has("decision") and not decision_models.has(mname):
					decision_models.append(mname)
	return decision_models


static func _probe_ollama_status_sync() -> Dictionary:
	var status: Dictionary = {}
	while true:
		_mutex.lock()
		var desired_primary: String = EvoUserSettings.primary_model
		var desired_secondary: String = EvoUserSettings.secondary_model
		_mutex.unlock()
		var primary_tag: String = desired_primary
		var secondary_tag: String = desired_secondary
		var primary_ready: bool = false
		var secondary_ready: bool = false
		var connected: bool = false
		var decision_models: Array[String] = []
		var all_model_names: Array[String] = []

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
								decision_models = filter_decision_models_from_tags(models)
								for m in models:
									if typeof(m) == TYPE_DICTIONARY and m.has("name"):
										all_model_names.append(str(m["name"]))
			client.close()

		for mname in all_model_names:
			if mname == desired_primary:
				primary_ready = true
				primary_tag = mname
			if mname == desired_secondary:
				secondary_ready = true
				secondary_tag = mname

		var missing_models: Array[String] = []
		var missing_commands: Array[String] = []
		if not primary_ready:
			missing_models.append(desired_primary)
			missing_commands.append("ollama pull " + desired_primary)
		if not secondary_ready and desired_secondary != desired_primary:
			missing_models.append(desired_secondary)
			missing_commands.append("ollama pull " + desired_secondary)

		status = {
			"probed": true,
			"connected": connected,
			"primary_ready": primary_ready,
			"secondary_ready": secondary_ready,
			"both_ready": connected and primary_ready and secondary_ready,
			"primary_tag": primary_tag,
			"secondary_tag": secondary_tag,
			"decision_models": decision_models,
			"missing_models": missing_models,
			"missing_commands": missing_commands
		}

		_mutex.lock()
		_cached_ollama_status = status
		_status_probed = true
		if _status_reprobe_requested and not _shutdown_requested:
			_status_reprobe_requested = false
			_mutex.unlock()
			continue
		_status_probe_running = false
		_mutex.unlock()
		break
	return status.duplicate(true)


static func start_pull_models(models: Array[String]) -> void:
	if models.is_empty():
		return
	var task_to_reap: int = -1
	_mutex.lock()
	if _pull_running:
		_mutex.unlock()
		return
	_pull_running = true
	_pull_cancel_requested = false
	_pull_queue = models.duplicate()
	_pull_state = {
		"running": true,
		"done": false,
		"failed": false,
		"current_model": models[0],
		"status_text": "Starting download...",
		"percent": 0.0
	}
	task_to_reap = _pull_task_id
	_pull_task_id = -1
	_mutex.unlock()

	if task_to_reap != -1:
		WorkerThreadPool.wait_for_task_completion(task_to_reap)
	var new_task_id := WorkerThreadPool.add_task(Callable(EvoOllamaClient, "_run_pull_worker"))
	_mutex.lock()
	_pull_task_id = new_task_id
	_mutex.unlock()


static func cancel_pull() -> void:
	_mutex.lock()
	_pull_cancel_requested = true
	_mutex.unlock()


static func get_pull_state() -> Dictionary:
	_mutex.lock()
	var snap := _pull_state.duplicate(true)
	_mutex.unlock()
	return snap


static func _run_pull_worker() -> void:
	_mutex.lock()
	var queue: Array[String] = _pull_queue.duplicate()
	_mutex.unlock()

	var all_ok := true
	var total_models := maxi(1, queue.size())

	for idx in range(queue.size()):
		if _shutdown_requested or _pull_cancel_requested:
			all_ok = false
			break
		var model_name: String = str(queue[idx])
		_mutex.lock()
		_pull_state["current_model"] = model_name
		_pull_state["status_text"] = "%s (%d/%d)" % [model_name, idx + 1, total_models]
		_mutex.unlock()

		var ok := _pull_single_model_sync(model_name, idx, total_models)
		if not ok:
			all_ok = false
			break

	if not _shutdown_requested:
		_probe_ollama_status_sync()

	_mutex.lock()
	_pull_running = false
	_pull_state["running"] = false
	_pull_state["done"] = all_ok and not _pull_cancel_requested
	_pull_state["failed"] = not all_ok and not _pull_cancel_requested
	if all_ok:
		_pull_state["percent"] = 100.0
	_mutex.unlock()


static func _pull_single_model_sync(model_name: String, model_idx: int, total_models: int) -> bool:
	var client := HTTPClient.new()
	var err := client.connect_to_host(DEFAULT_OLLAMA_HOST, DEFAULT_OLLAMA_PORT)
	if err != OK:
		client.close()
		return false

	var connect_start := Time.get_ticks_msec()
	while not _shutdown_requested and not _pull_cancel_requested and client.get_status() in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
		client.poll()
		if Time.get_ticks_msec() - connect_start > 5000:
			client.close()
			return false
		OS.delay_msec(5)

	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		client.close()
		return false

	var body := JSON.stringify({"model": model_name, "stream": true})
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	var req_err := client.request(HTTPClient.METHOD_POST, "/api/pull", headers, body)
	if req_err != OK:
		client.close()
		return false

	var req_start := Time.get_ticks_msec()
	while not _shutdown_requested and not _pull_cancel_requested and client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		if Time.get_ticks_msec() - req_start > PULL_STALL_TIMEOUT_MS:
			client.close()
			return false
		OS.delay_msec(10)

	if not client.has_response() or client.get_response_code() != 200:
		client.close()
		return false

	var buffer := ""
	var had_error := false
	var last_progress_ms := Time.get_ticks_msec()
	while not _shutdown_requested and not _pull_cancel_requested and client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			last_progress_ms = Time.get_ticks_msec()
			buffer += chunk.get_string_from_utf8()
			var lines := buffer.split("\n")
			buffer = lines[lines.size() - 1]
			for i in range(lines.size() - 1):
				var line := lines[i].strip_edges()
				if line == "":
					continue
				var parsed = JSON.parse_string(line)
				if typeof(parsed) == TYPE_DICTIONARY:
					var d := parsed as Dictionary
					if d.has("error"):
						had_error = true
					var st_txt := str(d["status"]) if d.has("status") else model_name
					var model_pct := 0.0
					if d.has("total") and d.has("completed") and float(d["total"]) > 0.0:
						model_pct = clampf(float(d["completed"]) / float(d["total"]) * 100.0, 0.0, 100.0)
					elif st_txt == "success":
						model_pct = 100.0
					var global_pct := ((float(model_idx) * 100.0) + model_pct) / float(total_models)
					_mutex.lock()
					_pull_state["status_text"] = "%s: %s" % [model_name, st_txt]
					_pull_state["percent"] = global_pct
					_mutex.unlock()
		else:
			if Time.get_ticks_msec() - last_progress_ms > PULL_STALL_TIMEOUT_MS:
				client.close()
				return false
			OS.delay_msec(10)

	client.close()
	return not had_error and not _shutdown_requested and not _pull_cancel_requested


static func _resolve_ollama_model_for_tag(desired: String, status: Dictionary) -> String:
	var p_tag := str(status["primary_tag"]) if status.has("primary_tag") else EvoUserSettings.primary_model
	var s_tag := str(status["secondary_tag"]) if status.has("secondary_tag") else EvoUserSettings.secondary_model
	var p_ready := bool(status["primary_ready"]) if status.has("primary_ready") else false
	var s_ready := bool(status["secondary_ready"]) if status.has("secondary_ready") else false

	if desired == s_tag:
		if s_ready:
			return s_tag
		return p_tag
	if p_ready:
		return p_tag
	return s_tag


static func _can_enqueue_locked() -> bool:
	if _shutdown_requested:
		return false
	if not _status_probed:
		return true
	return bool(_cached_ollama_status["connected"]) and (
		bool(_cached_ollama_status["primary_ready"])
		or bool(_cached_ollama_status["secondary_ready"])
	)


## Each job: {deme_id, preferred_tag, briefing, instructions, criteria (action key -> forecast)}.
static func enqueue_jobs(jobs: Array[Dictionary]) -> void:
	_mutex.lock()
	var can_enqueue := _can_enqueue_locked()
	if can_enqueue:
		_pending_jobs.append_array(jobs)
	_mutex.unlock()
	if can_enqueue:
		_start_worker_if_needed()


static func seed_deme_result(deme_id: String, entry: Dictionary) -> void:
	_mutex.lock()
	_results_by_deme[deme_id] = entry.duplicate(true)
	_mutex.unlock()


static func take_result(deme_id: String) -> Dictionary:
	_mutex.lock()
	var result: Dictionary = (_results_by_deme[deme_id] as Dictionary).duplicate(true) if _results_by_deme.has(deme_id) else {}
	_mutex.unlock()
	return result


static func pop_newly_completed(last_seen_rev: int) -> Dictionary:
	_mutex.lock()
	var current_rev := _completed_revision
	var newly := {} if current_rev == last_seen_rev else _newly_completed.duplicate(true)
	_newly_completed.clear()
	_mutex.unlock()
	return {"revision": current_rev, "newly_completed": newly}


static func _start_worker_if_needed() -> void:
	var task_to_reap: int = -1
	_mutex.lock()
	var should_start := not _shutdown_requested and not _worker_running and not _pending_jobs.is_empty()
	if should_start:
		_worker_running = true
		_active_worker_epoch = _cache_epoch
		task_to_reap = _worker_task_id
		_worker_task_id = -1
	_mutex.unlock()

	if should_start:
		if task_to_reap != -1:
			WorkerThreadPool.wait_for_task_completion(task_to_reap)
		var new_task_id := WorkerThreadPool.add_task(Callable(EvoOllamaClient, "_run_ollama_worker"))
		_mutex.lock()
		_worker_task_id = new_task_id
		_mutex.unlock()


static func _run_ollama_worker() -> void:
	if not _status_probed:
		_probe_ollama_status_sync()
	while not _shutdown_requested:
		_mutex.lock()
		if _pending_jobs.is_empty() or not _can_enqueue_locked():
			_pending_jobs.clear()
			_worker_running = false
			_active_worker_epoch = -1
			_mutex.unlock()
			return
		var status := _cached_ollama_status.duplicate(true)
		var ctx_len := EvoUserSettings.context_length
		var batch_epoch := _cache_epoch
		_active_worker_epoch = batch_epoch
		var batch: Array[Dictionary] = _pending_jobs.slice(0, MAX_CONCURRENT_JOBS)
		_pending_jobs = _pending_jobs.slice(MAX_CONCURRENT_JOBS)
		_mutex.unlock()

		var batch_results := _evaluate_job_batch_with_ollama(batch, status, ctx_len)
		_mutex.lock()
		if _cache_epoch == batch_epoch:
			for deme_id in batch_results.keys():
				_results_by_deme[deme_id] = batch_results[deme_id]
				_newly_completed[deme_id] = batch_results[deme_id]
			_completed_revision += 1
		_mutex.unlock()

	_mutex.lock()
	_worker_running = false
	_active_worker_epoch = -1
	_mutex.unlock()


static func build_payload(job: Dictionary, model_tag: String, ctx_len: int) -> Dictionary:
	return {
		"model": model_tag,
		"keep_alive": "30m",
		"options": {"num_ctx": ctx_len},
		"state": {"briefing": str(job["briefing"])},
		"questions": {
			"decision": {
				"type": "choice",
				"instructions": str(job["instructions"]),
				"criteria": job["criteria"]
			}
		}
	}


static func normalize_probabilities(raw: Dictionary, keys: Array) -> Dictionary:
	var total := 0.0
	var clean: Dictionary = {}
	for key in keys:
		var val := float(raw.get(key, 0.0))
		clean[key] = val if is_finite(val) and val > 0.0 else 0.0
		total += float(clean[key])
	if total <= 0.0:
		return {}
	for key in keys:
		clean[key] = float(clean[key]) / total
	return clean


static func _evaluate_job_batch_with_ollama(
	batch: Array[Dictionary],
	status: Dictionary,
	ctx_len: int
) -> Dictionary:
	var results_by_deme: Dictionary = {}
	var active_jobs: Array[Dictionary] = []
	for item in batch:
		var model_tag := _resolve_ollama_model_for_tag(str(item["preferred_tag"]), status)
		var client := HTTPClient.new()
		var err := client.connect_to_host(DEFAULT_OLLAMA_HOST, DEFAULT_OLLAMA_PORT)
		active_jobs.append({
			"deme_id": str(item["deme_id"]),
			"keys": (item["criteria"] as Dictionary).keys(),
			"client": client,
			"body": JSON.stringify(build_payload(item, model_tag, ctx_len)),
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
				if st == HTTPClient.STATUS_CONNECTED:
					job["stage"] = "requesting" if client.request(HTTPClient.METHOD_POST, "/v1/systemone", headers, str(job["body"])) == OK else "failed"
				elif st not in [HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
					job["stage"] = "failed"
			elif st == HTTPClient.STATUS_BODY:
				if client.get_response_code() != 200:
					job["stage"] = "failed"
					continue
				var chunk := client.read_response_body_chunk()
				if chunk.size() > 0:
					var rb: PackedByteArray = job["rb"]
					rb.append_array(chunk)
					job["rb"] = rb
				if client.get_status() != HTTPClient.STATUS_BODY:
					job["stage"] = "done" if (job["rb"] as PackedByteArray).size() > 0 else "failed"
			elif st != HTTPClient.STATUS_REQUESTING:
				job["stage"] = "done" if (job["rb"] as PackedByteArray).size() > 0 else "failed"
		if not any_active:
			break
		OS.delay_msec(2)

	for job in active_jobs:
		(job["client"] as HTTPClient).close()
		if str(job["stage"]) != "done":
			continue
		var body_str := (job["rb"] as PackedByteArray).get_string_from_utf8()
		if body_str.is_empty():
			continue
		var parsed = JSON.parse_string(body_str)
		if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("answers") or not (parsed["answers"] as Dictionary).has("decision"):
			continue
		var answer: Dictionary = parsed["answers"]["decision"]
		var probabilities := normalize_probabilities(answer["probabilities"], job["keys"])
		if probabilities.is_empty():
			continue
		results_by_deme[job["deme_id"]] = {
			"probabilities": probabilities,
			"confidence": clampf(float(answer["confidence"]), 0.0, 1.0)
		}
	return results_by_deme


static func has_pending_jobs() -> bool:
	_mutex.lock()
	var pending := not _pending_jobs.is_empty() or (_worker_running and _active_worker_epoch == _cache_epoch)
	_mutex.unlock()
	return pending


static func wait_for_workers() -> void:
	_mutex.lock()
	_shutdown_requested = true
	_pull_cancel_requested = true
	_pending_jobs.clear()
	var s_task := _status_task_id
	var w_task := _worker_task_id
	var p_task := _pull_task_id
	_status_task_id = -1
	_worker_task_id = -1
	_pull_task_id = -1
	_mutex.unlock()

	if s_task != -1:
		WorkerThreadPool.wait_for_task_completion(s_task)
	if w_task != -1:
		WorkerThreadPool.wait_for_task_completion(w_task)
	if p_task != -1:
		WorkerThreadPool.wait_for_task_completion(p_task)

	_mutex.lock()
	_status_probe_running = false
	_status_reprobe_requested = false
	_worker_running = false
	_active_worker_epoch = -1
	_pull_running = false
	_shutdown_requested = false
	_pull_cancel_requested = false
	_mutex.unlock()
