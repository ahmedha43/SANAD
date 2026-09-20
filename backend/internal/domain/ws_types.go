package domain

import "encoding/json"

// WSMessageType defines standardized message types across Parent, Backend and Kid
type WSMessageType string

const (
	// Heartbeat & Connection
	TypeHeartbeatPing WSMessageType = "HEARTBEAT_PING"
	TypeHeartbeatPong WSMessageType = "HEARTBEAT_PONG"
	TypeDeviceOnline  WSMessageType = "DEVICE_ONLINE"
	TypeDeviceOffline WSMessageType = "DEVICE_OFFLINE"

	// Telemetry & Location
	TypeLocationUpdate  WSMessageType = "LOCATION_UPDATE"
	TypeAppUsageSync    WSMessageType = "APP_USAGE_SYNC"
	TypeNotifForward    WSMessageType = "NOTIFICATION_FORWARD"
	TypeBatteryUpdate   WSMessageType = "BATTERY_UPDATE"

	// Remote Commands
	TypeCommandRequest WSMessageType = "COMMAND_REQUEST"
	TypeCommandAck     WSMessageType = "COMMAND_ACK"

	// WebRTC Signaling & Audio
	TypeRTCOffer           WSMessageType = "RTC_OFFER"
	TypeRTCAnswer          WSMessageType = "RTC_ANSWER"
	TypeRTCIceCandidate    WSMessageType = "RTC_ICE_CANDIDATE"
	TypeStreamStart        WSMessageType = "STREAM_START"
	TypeStreamStop         WSMessageType = "STREAM_STOP"
	TypeStreamError        WSMessageType = "STREAM_ERROR"
	TypeCameraSwitch       WSMessageType = "CAMERA_SWITCH"
	TypeCameraSwitchResult WSMessageType = "CAMERA_SWITCH_RESULT"
	TypePTTStart           WSMessageType = "PTT_START"
	TypePTTStop            WSMessageType = "PTT_STOP"

	// Safety, Anti-Tamper & Rules
	TypeSOSAlert            WSMessageType = "SOS_ALERT"
	TypeLowBatteryAlert     WSMessageType = "LOW_BATTERY_ALERT"
	TypeScreenTimeRuleSync  WSMessageType = "SCREEN_TIME_RULE_SYNC"
	TypeGeofenceAlert       WSMessageType = "GEOFENCE_ALERT"
	TypeRiskAlert           WSMessageType = "RISK_ALERT"
	TypeSafeRiskPatternsSync WSMessageType = "SAFE_RISK_PATTERNS_SYNC"
	TypeRiskAlertSafeUpdated WSMessageType = "RISK_ALERT_SAFE_UPDATED"
	TypeSimSwapAlert        WSMessageType = "SIM_SWAP_ALERT"
	TypeAirplaneModeAlert   WSMessageType = "AIRPLANE_MODE_ALERT"
	TypeDeviceOwnerStatus   WSMessageType = "DEVICE_OWNER_STATUS"
	TypeGetDeviceOwnerStatus WSMessageType = "GET_DEVICE_OWNER_STATUS"

	// Content & Logs
	TypeContactsSync       WSMessageType = "CONTACTS_SYNC"
	TypeSMSSync            WSMessageType = "SMS_SYNC"
	TypeFilesSync          WSMessageType = "FILES_SYNC"
	TypeCallsSync          WSMessageType = "CALLS_SYNC"
	TypeTakeScreenshot     WSMessageType = "TAKE_SCREENSHOT"
	TypeScreenshotCaptured WSMessageType = "SCREENSHOT_CAPTURED"
	TypeFetchFileData      WSMessageType = "FETCH_FILE_DATA"
	TypeFileDataResult     WSMessageType = "FILE_DATA_RESULT"

	// Unpair & Factory Reset
	TypeUnpairAndReset     WSMessageType = "UNPAIR_AND_RESET"
	TypeDeviceUnpaired     WSMessageType = "DEVICE_UNPAIRED"
)

// WSMessage is the standardized envelope for all WebSocket messages
type WSMessage struct {
	Type      WSMessageType   `json:"type"`
	ID        string          `json:"id"`
	From      string          `json:"from"`
	To        string          `json:"to,omitempty"`
	DeviceID  string          `json:"device_id,omitempty"`
	FamilyID  string          `json:"family_id,omitempty"`
	Timestamp int64           `json:"timestamp"`
	Payload   json.RawMessage `json:"payload"`
}

// LocationPayload received from Kid Agent
type LocationPayload struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
	Accuracy  float32 `json:"accuracy"`
	Altitude  float32 `json:"altitude"`
	Speed     float32 `json:"speed"`
	Bearing   float32 `json:"bearing"`
	Timestamp int64   `json:"timestamp"`
}

// BatteryPayload sent during heartbeat
type BatteryPayload struct {
	BatteryLevel int    `json:"battery_level"`
	IsCharging   bool   `json:"is_charging"`
	NetworkType  string `json:"network_type"`
}

// CommandRequestPayload sent from Parent to Kid
type CommandRequestPayload struct {
	CommandID string                 `json:"command_id"`
	Action    string                 `json:"action"` // LOCK, UNLOCK, ALARM, BLOCK_APP, UNBLOCK_APP, SCREENSHOT
	Params    map[string]interface{} `json:"params,omitempty"`
}

// CommandAckPayload sent from Kid back to Parent
type CommandAckPayload struct {
	CommandID string `json:"command_id"`
	Success   bool   `json:"success"`
	Error     string `json:"error,omitempty"`
}

// StreamSessionPayload for WebRTC sessions
type StreamSessionPayload struct {
	SessionID  string `json:"session_id"`
	StreamType string `json:"stream_type"` // "screen" | "camera_back" | "camera_front" | "audio_only"
	SDP        string `json:"sdp,omitempty"`
	Candidate  string `json:"candidate,omitempty"`
	SDPMid     string `json:"sdp_mid,omitempty"`
	SDPMLine   int    `json:"sdp_mline_index,omitempty"`
}
