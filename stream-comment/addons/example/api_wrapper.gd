static func access_token_get(
	_requester: HTTPRequest,
	_client_id: String,
	_client_secret: String,
	_scopes: String
) -> String:
	var result: int = _requester.request(
		"https://id.twitch.tv/oauth2/token?" +
		"client_id=%s&" % _client_id +
		"client_secret=%s&" % _client_secret +
		"grant_type=client_credentials&" +
		"scope=%s" % _scopes,
		[],
		true,
		HTTPClient.METHOD_POST
	)

	if result != OK:
		return ""

	var data: Dictionary = yield(__response_json(_requester), "completed")

	return data.get("access_token", "")


static func access_token_delete(
	_requester: HTTPRequest,
	_client_id: String,
	_token: String
) -> void:
	var __: int = _requester.request(
		"https://id.twitch.tv/oauth2/token?" +
		"client_id=%s&" % _client_id +
		"token=%s&" % _token,
		[],
		true,
		HTTPClient.METHOD_POST
	)

	# Don't worry about the result


static func event_subscription_create(
	_requester: HTTPRequest,
	_client_id: String,
	_access_token: String,
	_type: String,
	_condition: Dictionary,
	_callback: String
) -> int:
	var result: int = _requester.request(
		"https://api.twitch.tv/helix/eventsub/subscriptions",
		[
			"Authorization: Bearer %s" % _access_token,
			"Client-Id: %s" % _client_id,
			"Content-Type: application/json",
		],
		true,
		HTTPClient.METHOD_POST,
		to_json({
			"type": _type,
			"version": 1,
			"condition": _condition,
			"transport": {
				"method": "webhook",
				"callback": _callback,
				"secret": "Lumikkode is the best",
			},
		})
	)

	if result != OK:
		return FAILED

	var data: Dictionary = yield(__response_json(_requester), "completed")

	if !data:
		return FAILED

	return OK


static func event_subscription_get(
	_requester: HTTPRequest,
	_client_id: String,
	_access_token: String
) -> Array:
	var result: int = _requester.request(
		"https://api.twitch.tv/helix/eventsub/subscriptions",
		[
			"Authorization: Bearer %s" % _access_token,
			"Client-Id: %s" % _client_id,
		]
	)

	if result != OK:
		return []

	var data: Dictionary =  yield(__response_json(_requester), "completed")

	return data.get("data", [])


static func event_subscription_delete(
	_requester: HTTPRequest,
	_client_id: String,
	_access_token: String,
	_event_subscription_id: String
) -> int:
	var result: int = _requester.request(
		"https://api.twitch.tv/helix/eventsub/subscriptions?" +
		"id=%s" % _event_subscription_id,
		[
			"Authorization: Bearer %s" % _access_token,
			"Client-Id: %s" % _client_id,
		],
		true,
		HTTPClient.METHOD_DELETE
	)

	if result != OK:
		push_warning("Couldn't delete event: %s" % _event_subscription_id)
		return FAILED

	var response: Array = yield(_requester, "request_completed")

	if response[1] != 204:
		print(response[3].get_string_from_utf8())
		return FAILED

	return OK


static func event_subscription_delete_all(
	_requester: HTTPRequest,
	_client_id: String,
	_access_token: String
) -> int:
	var event_subscriptions: Array = yield(
		event_subscription_get(
			_requester,
			_client_id,
			_access_token
		),
		"completed"
	)

	for event_subscription in event_subscriptions:
		var result: int = yield(
			event_subscription_delete(
				_requester,
				_client_id,
				_access_token,
				event_subscription.get("id")
			),
			"completed"
		)

		if result != OK:
			return FAILED

	return OK


static func ngrok_url_get(
	_requester: HTTPRequest
) -> String:
	var result: int = _requester.request(
		"http://127.0.0.1:4040/api/tunnels",
		[],
		false
	)

	if result != OK:
		return ""

	var data: Dictionary = yield(__response_json(_requester), "completed")

	if !data:
		return ""

	return data \
		.get('tunnels')[0] \
		.get('public_url') \
		.replace("http://", "https://")


# Private methods

static func __response_json(
	_requester: HTTPRequest
) -> Dictionary:
	var response: Array = yield(_requester, "request_completed")

	if response[1] != 200:
		print(response[3].get_string_from_utf8())
		return {}

	return parse_json(response[3].get_string_from_utf8())
