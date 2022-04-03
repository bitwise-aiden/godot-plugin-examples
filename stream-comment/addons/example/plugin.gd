tool
extends EditorPlugin

# Private imports

const __APIWrapper = preload("./api_wrapper.gd")


# Private constants

const __BROADCASTER_USER_ID: String = ""
const __CLIENT_ID: String = ""
const __CLIENT_SECRET: String = ""
const __SCOPES: String = "channel:read:subscriptions%20channel:read:redemptions"


# Private variables

var __http_server: HTTPServer


# Lifecyle methods

func _ready() -> void:
	var requester: HTTPRequest = HTTPRequest.new()
	requester.use_threads = true
	add_child(requester)

	var ngrok_url: String = yield(__APIWrapper.ngrok_url_get(requester), "completed")

	if !ngrok_url:
		push_error("ngrok not active. Please start then re-enable plugin")
		return

	# Get an app access token
	var access_token: String = yield(
		__APIWrapper.access_token_get(
			requester,
			__CLIENT_ID,
			__CLIENT_SECRET,
			__SCOPES
		),
		"completed"
	)

	if !access_token:
		push_error("Unable to authenticate")
		return

	print("authenticated")

	var result: int = 0

	# Ensure no active subscriptions.
	#
	# Assumes that this is the sole controller of subscriptions, so this could accidentally
	# delete subscriptions controlled by other sources.
	result = yield(
		__APIWrapper.event_subscription_delete_all(
			requester,
			__CLIENT_ID,
			access_token
		),
		"completed"
	)

	print("cleaned up old event subscriptions")


	# Create channel point subscription
	result = yield(
		__APIWrapper.event_subscription_create(
			requester,
			__CLIENT_ID,
			access_token,
			"channel.channel_points_custom_reward_redemption.add",
			{
				"broadcaster_user_id": __BROADCASTER_USER_ID,
			},
			"%s/notification" % ngrok_url
		),
		"completed"
	)

	print("created redemption subscription")

	# Delete access token as it is no longer needed
	__APIWrapper.access_token_delete(
		requester,
		__CLIENT_ID,
		access_token
	)


func _process(_delta: float) -> void:
	__process_http_connections()


# Private methods


func __process_http_connections() -> void:
	if __http_server == null:
		__start_server()

	__http_server.take_connection()


func __start_server(port: int = 8000) -> void:
	# Create an HTTP server using https://github.com/velopman/godot-http-server
	__http_server = HTTPServer.new()

	__http_server.endpoint(
		HTTPServer.Method.POST,
		"/notification",
		funcref(self, "__handle_notification")
	)

	__http_server.listen(port)


func __handle_notification(
	_request: HTTPServer.Request,
	_response: HTTPServer.Response
) -> void:
	var type: String = _request.header("twitch-eventsub-message-type", "")
	var body: Dictionary = _request.json()

	match type:
		# Respond to the challenge request while establishing subscription
		"webhook_callback_verification":
			_response.data(body["challenge"])

			var notification_type: String = _request.header("twitch-eventsub-subscription-type", "")
			print("Connected event: %s" % notification_type)

		# Handle the notification of subscription event
		"notification":
			var notification_type: String = body["subscription"]["type"]

			print(notification_type)

			match notification_type:
				"channel.channel_points_custom_reward_redemption.add":
					__handle_point_redemption(
						body["event"]["reward"]["title"],
						body["event"]["user_name"],
						body["event"]["user_input"]
					)


func __handle_point_redemption(
	_reward: String,
	_user_name: String,
	_user_input: String
) -> void:
	match _reward:
		"Comment my code!":
			# If you see this, it means it worked! - velopman
			StreamComment.comment("%s - %s" % [_user_input, _user_name])
