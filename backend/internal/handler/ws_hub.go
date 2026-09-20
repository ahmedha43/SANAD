package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/gofiber/contrib/websocket"
	"github.com/google/uuid"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/internal/repository"
	"github.com/parental-control/backend/internal/service"
)

type ClientRole string

const (
	ClientRoleParent ClientRole = "parent"
	ClientRoleKid    ClientRole = "kid"
)

type Client struct {
	ID        string // UserID or DeviceID (or unique ConnID for parents)
	UserID    string // Parent UserID (when Role is parent)
	FamilyID  string
	Role      ClientRole
	Conn      *websocket.Conn
	Send      chan []byte
	closeOnce sync.Once
}

func (c *Client) SafeClose() {
	c.closeOnce.Do(func() {
		close(c.Send)
	})
}

type WSHub struct {
	sync.RWMutex
	// kids map[deviceID]*Client
	kids map[string]*Client
	// parents map[familyID]map[userID]*Client
	parents map[string]map[string]*Client

	register   chan *Client
	unregister chan *Client

	// Services for persisting telemetry & checking geofences
	locationService *service.LocationService
	deviceService   *service.DeviceService
	appService      *service.AppService
	repo            *repository.Repository
}

func NewWSHub(locSvc *service.LocationService, devSvc *service.DeviceService, appSvc *service.AppService, repo *repository.Repository) *WSHub {
	return &WSHub{
		kids:            make(map[string]*Client),
		parents:         make(map[string]map[string]*Client),
		register:        make(chan *Client),
		unregister:      make(chan *Client),
		locationService: locSvc,
		deviceService:   devSvc,
		appService:      appSvc,
		repo:            repo,
	}
}

func (h *WSHub) GetOnlineDeviceCount() int {
	h.RLock()
	defer h.RUnlock()
	return len(h.kids)
}

func (h *WSHub) SendCommandToKid(deviceID string, cmd *domain.DeviceCommand, action string, params map[string]interface{}) bool {
	h.RLock()
	client, ok := h.kids[deviceID]
	h.RUnlock()
	if !ok || client == nil {
		return false
	}

	payloadMap := map[string]interface{}{
		"command_id": cmd.ID.String(),
		"action":     action,
		"params":     params,
	}
	payloadBytes, err := json.Marshal(payloadMap)
	if err != nil {
		return false
	}

	msg := domain.WSMessage{
		Type:      domain.TypeCommandRequest,
		From:      "server",
		To:        deviceID,
		Payload:   payloadBytes,
		Timestamp: time.Now().UnixMilli(),
	}
	raw, err := json.Marshal(msg)
	if err != nil {
		return false
	}

	select {
	case client.Send <- raw:
		log.Printf("[WS Hub] Real-time command dispatched: %s to device %s (cmdID: %s)", action, deviceID, cmd.ID)
		return true
	default:
		log.Printf("[WS Hub] Failed to send command %s to device %s: queue full", action, deviceID)
		return false
	}
}

// SyncSafePatternsToKid sends updated whitelisted patterns to a kid device
func (h *WSHub) SyncSafePatternsToKid(deviceID uuid.UUID, patterns []string) bool {
	h.RLock()
	client, ok := h.kids[deviceID.String()]
	h.RUnlock()
	if !ok || client == nil {
		return false
	}

	payloadMap := map[string]interface{}{
		"patterns": patterns,
	}
	payloadBytes, err := json.Marshal(payloadMap)
	if err != nil {
		return false
	}

	msg := domain.WSMessage{
		Type:      domain.TypeSafeRiskPatternsSync,
		From:      "server",
		To:        deviceID.String(),
		Payload:   payloadBytes,
		Timestamp: time.Now().UnixMilli(),
	}
	raw, err := json.Marshal(msg)
	if err != nil {
		return false
	}

	select {
	case client.Send <- raw:
		log.Printf("[WS Hub] Synced %d safe patterns to kid %s", len(patterns), deviceID)
		return true
	default:
		log.Printf("[WS Hub] Failed to send safe patterns to kid %s: queue full", deviceID)
		return false
	}
}

// BroadcastToFamily broadcasts a message to parents in a family
func (h *WSHub) BroadcastToFamily(familyID string, msg domain.WSMessage) {
	h.Lock()
	defer h.Unlock()
	h.broadcastToFamilyParents(familyID, msg)
}

func (h *WSHub) Run() {
	for {
		select {
		case client := <-h.register:
			h.Lock()
			if client.Role == ClientRoleKid {
				if old, ok := h.kids[client.ID]; ok && old != client {
					old.SafeClose()
				}
				h.kids[client.ID] = client
				log.Printf("[WS Hub] Kid Device connected: %s (Family: %s)", client.ID, client.FamilyID)
				// Broadcast online status to parents in same family
				h.broadcastToFamilyParents(client.FamilyID, domain.WSMessage{
					Type:      domain.TypeDeviceOnline,
					From:      client.ID,
					FamilyID:  client.FamilyID,
					Timestamp: time.Now().UnixMilli(),
				})
				// Push any whitelisted safe patterns
				if devUID, err := uuid.Parse(client.ID); err == nil && h.repo != nil {
					go func(dID uuid.UUID, c *Client) {
						rules, err := h.repo.GetSafeRules(context.Background(), dID)
						if err == nil && len(rules) > 0 {
							patterns := make([]string, 0, len(rules))
							for _, r := range rules {
								patterns = append(patterns, r.Pattern)
							}
							payloadBytes, _ := json.Marshal(map[string]any{"patterns": patterns})
							msg := domain.WSMessage{
								Type:      domain.TypeSafeRiskPatternsSync,
								From:      "server",
								To:        dID.String(),
								Payload:   payloadBytes,
								Timestamp: time.Now().UnixMilli(),
							}
							raw, _ := json.Marshal(msg)
							select {
							case c.Send <- raw:
								log.Printf("[WS Hub] Pushed %d initial safe patterns to kid %s", len(patterns), dID)
							default:
							}
						}
					}(devUID, client)
				}
			} else {
				if _, ok := h.parents[client.FamilyID]; !ok {
					h.parents[client.FamilyID] = make(map[string]*Client)
				}
				h.parents[client.FamilyID][client.ID] = client
				log.Printf("[WS Hub] Parent connected: ConnID=%s, UserID=%s (Family: %s, TotalConnsInFamily: %d)",
					client.ID, client.UserID, client.FamilyID, len(h.parents[client.FamilyID]))
			}
			h.Unlock()

		case client := <-h.unregister:
			h.Lock()
			if client.Role == ClientRoleKid {
				if existing, ok := h.kids[client.ID]; ok && existing == client {
					delete(h.kids, client.ID)
					client.SafeClose()
					log.Printf("[WS Hub] Kid Device disconnected: %s", client.ID)
					// Broadcast offline status to parents
					h.broadcastToFamilyParents(client.FamilyID, domain.WSMessage{
						Type:      domain.TypeDeviceOffline,
						From:      client.ID,
						FamilyID:  client.FamilyID,
						Timestamp: time.Now().UnixMilli(),
					})
				}
			} else {
				if familyParents, ok := h.parents[client.FamilyID]; ok {
					if existing, ok := familyParents[client.ID]; ok && existing == client {
						delete(familyParents, client.ID)
						client.SafeClose()
						log.Printf("[WS Hub] Parent disconnected: ConnID=%s, UserID=%s (Family: %s, RemainingConns: %d)",
							client.ID, client.UserID, client.FamilyID, len(familyParents))
					}
				}
			}
			h.Unlock()
		}
	}
}

// broadcastToFamilyParents sends a message to all parents belonging to the family
func (h *WSHub) broadcastToFamilyParents(familyID string, msg domain.WSMessage) {
	bytes, err := json.Marshal(msg)
	if err != nil {
		return
	}

	if familyParents, ok := h.parents[familyID]; ok {
		for _, parentClient := range familyParents {
			select {
			case parentClient.Send <- bytes:
			default:
			}
		}
	}
}

// RouteMessage handles incoming messages and dispatches them
func (h *WSHub) RouteMessage(fromClient *Client, rawMsg []byte) {
	var msg domain.WSMessage
	if err := json.Unmarshal(rawMsg, &msg); err != nil {
		log.Printf("Invalid WS message format: %v", err)
		return
	}

	if fromClient.Role == ClientRoleParent && fromClient.UserID != "" {
		msg.From = fromClient.UserID
	} else {
		msg.From = fromClient.ID
	}
	msg.FamilyID = fromClient.FamilyID
	if msg.To == "" && msg.DeviceID != "" {
		msg.To = msg.DeviceID
	}
	if msg.Timestamp == 0 {
		msg.Timestamp = time.Now().UnixMilli()
	}

	ctx := context.Background()

	switch msg.Type {
	case domain.TypeHeartbeatPing:
		// Send pong back safely without blocking
		pong := domain.WSMessage{
			Type:      domain.TypeHeartbeatPong,
			ID:        msg.ID,
			Timestamp: time.Now().UnixMilli(),
		}
		pongBytes, _ := json.Marshal(pong)
		select {
		case fromClient.Send <- pongBytes:
		default:
		}

		// If from kid, update battery and status
		if fromClient.Role == ClientRoleKid {
			var battery domain.BatteryPayload
			if err := json.Unmarshal(msg.Payload, &battery); err == nil {
				devUID, err := uuid.Parse(fromClient.ID)
				if err == nil {
					_ = h.deviceService.UpdateHeartbeat(ctx, devUID, battery)
				}
				// Forward battery update to parents
				h.Lock()
				h.broadcastToFamilyParents(fromClient.FamilyID, msg)
				h.Unlock()
			}
		}

	case domain.TypeLocationUpdate:
		if fromClient.Role == ClientRoleKid {
			var locPayload domain.LocationPayload
			if err := json.Unmarshal(msg.Payload, &locPayload); err == nil {
				devUID, err := uuid.Parse(fromClient.ID)
				if err == nil {
					_, events, _ := h.locationService.RecordLocation(ctx, devUID, locPayload)
					if len(events) > 0 {
						// Geofence breached alert
						for _, ev := range events {
							alertBytes, _ := json.Marshal(ev)
							alertMsg := domain.WSMessage{
								Type:      "GEOFENCE_ALERT",
								From:      fromClient.ID,
								FamilyID:  fromClient.FamilyID,
								Timestamp: time.Now().UnixMilli(),
								Payload:   alertBytes,
							}
							h.Lock()
							h.broadcastToFamilyParents(fromClient.FamilyID, alertMsg)
							h.Unlock()
						}
					}
				}
			}
			// Broadcast live location to parents
			h.Lock()
			h.broadcastToFamilyParents(fromClient.FamilyID, msg)
			h.Unlock()
		}

	case domain.TypeCommandRequest, "DEVICE_COMMAND":
		// Parent sending command to Kid (e.g. LOCK, UNLOCK, ALARM, BLOCK_APP)
		targetID := msg.To
		if targetID == "" {
			targetID = msg.DeviceID
		}
		if fromClient.Role == ClientRoleParent && targetID != "" {
			h.Lock()
			if kidClient, ok := h.kids[targetID]; ok {
				var outBytes []byte
				if msg.Type == "DEVICE_COMMAND" || len(msg.Payload) == 0 {
					var rawMap map[string]interface{}
					_ = json.Unmarshal(rawMsg, &rawMap)
					cmdReq := map[string]interface{}{
						"command_id": fmt.Sprintf("%d", time.Now().UnixMilli()),
						"action":     rawMap["action"],
						"params":     rawMap["params"],
					}
					payloadBytes, _ := json.Marshal(cmdReq)
					normMsg := domain.WSMessage{
						Type:      domain.TypeCommandRequest,
						From:      fromClient.ID,
						To:        targetID,
						FamilyID:  fromClient.FamilyID,
						Timestamp: time.Now().UnixMilli(),
						Payload:   payloadBytes,
					}
					outBytes, _ = json.Marshal(normMsg)
				} else {
					outBytes = rawMsg
				}

				select {
				case kidClient.Send <- outBytes:
					log.Printf("[WS Hub] Dispatched parent command to kid device %s", targetID)
				default:
					log.Printf("Kid queue full for command: %s", targetID)
				}
			}
			h.Unlock()
		}

	case domain.TypeCommandAck:
		// Kid confirming command execution back to Parents
		if fromClient.Role == ClientRoleKid {
			var ack domain.CommandAckPayload
			if err := json.Unmarshal(msg.Payload, &ack); err == nil {
				cmdUID, err := uuid.Parse(ack.CommandID)
				if err == nil {
					_ = h.deviceService.AcknowledgeCommand(ctx, cmdUID, ack.Success, ack.Error)
				}
			}
			h.Lock()
			h.broadcastToFamilyParents(fromClient.FamilyID, msg)
			h.Unlock()
		}

	case "APPS_INVENTORY_SYNC":
		if fromClient.Role == ClientRoleKid {
			var apps []domain.DeviceApp
			if err := json.Unmarshal(msg.Payload, &apps); err == nil {
				devUID, err := uuid.Parse(fromClient.ID)
				if err == nil {
					_ = h.appService.SyncApps(ctx, devUID, apps)
					log.Printf("[WS Hub] Synced %d apps for kid device %s", len(apps), fromClient.ID)
				}
			}
		}

	case "APP_USAGE_SYNC":
		if fromClient.Role == ClientRoleKid {
			var items []domain.AppUsageDaily
			if err := json.Unmarshal(msg.Payload, &items); err == nil {
				devUID, err := uuid.Parse(fromClient.ID)
				if err == nil {
					for _, item := range items {
						item.DeviceID = devUID
						_ = h.appService.RecordDailyUsage(ctx, &item)
					}
					log.Printf("[WS Hub] Synced %d usage items for kid device %s", len(items), fromClient.ID)
				}
			}
		}

	case domain.TypeNotifForward:
		// Kid forwarding incoming notification to parents
		if fromClient.Role == ClientRoleKid {
			var notif struct {
				AppName     string `json:"app_name"`
				PackageName string `json:"package_name"`
				Title       string `json:"title"`
				Content     string `json:"content"`
			}
			if err := json.Unmarshal(msg.Payload, &notif); err == nil {
				devUID, err := uuid.Parse(fromClient.ID)
				if err == nil {
					_ = h.appService.SaveNotification(ctx, devUID, notif.AppName, notif.PackageName, notif.Title, notif.Content, time.Now())
				}
			}
			h.Lock()
			h.broadcastToFamilyParents(fromClient.FamilyID, msg)
			h.Unlock()
		}

	case domain.TypeSOSAlert:
		// Urgent emergency alert from kid
		log.Printf("[WS Hub] URGENT SOS ALERT from kid device %s", fromClient.ID)
		h.Lock()
		h.broadcastToFamilyParents(fromClient.FamilyID, msg)
		h.Unlock()

	case domain.TypeLowBatteryAlert:
		// Low battery notification from kid
		log.Printf("[WS Hub] Low battery alert from kid device %s", fromClient.ID)
		h.Lock()
		h.broadcastToFamilyParents(fromClient.FamilyID, msg)
		h.Unlock()

	case domain.TypeScreenTimeRuleSync:
		// Screen time rule forwarded to kid device
		if fromClient.Role == ClientRoleParent && msg.To != "" {
			h.Lock()
			if kidClient, ok := h.kids[msg.To]; ok {
				select {
				case kidClient.Send <- rawMsg:
				default:
				}
			}
			h.Unlock()
		}

	case domain.TypeContactsSync:
		if fromClient.Role == ClientRoleKid {
			var contacts []domain.KidContact
			if err := json.Unmarshal(msg.Payload, &contacts); err == nil {
				devUID, err := uuid.Parse(fromClient.ID)
				if err == nil && h.repo != nil {
					_ = h.repo.UpsertKidContacts(ctx, devUID, contacts)
					log.Printf("[WS Hub] Synced %d contacts for kid device %s", len(contacts), fromClient.ID)
				}
			}
			h.Lock()
			h.broadcastToFamilyParents(fromClient.FamilyID, msg)
			h.Unlock()
		}

	case domain.TypeSMSSync:
		if fromClient.Role == ClientRoleKid {
			var messages []domain.KidSMS
			if err := json.Unmarshal(msg.Payload, &messages); err == nil {
				devUID, err := uuid.Parse(fromClient.ID)
				if err == nil && h.repo != nil {
					_ = h.repo.SaveKidSMSList(ctx, devUID, messages)
					log.Printf("[WS Hub] Synced %d SMS messages for kid device %s", len(messages), fromClient.ID)
				}
			}
			h.Lock()
			h.broadcastToFamilyParents(fromClient.FamilyID, msg)
			h.Unlock()
		}

	case domain.TypeFilesSync:
		if fromClient.Role == ClientRoleKid {
			var files []domain.KidFile
			if err := json.Unmarshal(msg.Payload, &files); err == nil {
				devUID, err := uuid.Parse(fromClient.ID)
				if err == nil && h.repo != nil {
					_ = h.repo.SaveKidFilesList(ctx, devUID, files)
					log.Printf("[WS Hub] Synced %d files for kid device %s", len(files), fromClient.ID)
				}
			}
			h.Lock()
			h.broadcastToFamilyParents(fromClient.FamilyID, msg)
			h.Unlock()
		}

	case domain.TypeCallsSync:
		if fromClient.Role == ClientRoleKid {
			var calls []domain.KidCallLog
			if err := json.Unmarshal(msg.Payload, &calls); err == nil {
				devUID, err := uuid.Parse(fromClient.ID)
				if err == nil && h.repo != nil {
					_ = h.repo.SaveKidCallLogs(ctx, devUID, calls)
					log.Printf("[WS Hub] Synced %d call logs for kid device %s", len(calls), fromClient.ID)
				}
			}
			h.Lock()
			h.broadcastToFamilyParents(fromClient.FamilyID, msg)
			h.Unlock()
		}

	case domain.TypeRiskAlert:
		log.Printf("[WS Hub AI] RISK ALERT from kid device %s", fromClient.ID)
		if fromClient.Role == ClientRoleKid {
			var alert domain.RiskAlert
			if err := json.Unmarshal(msg.Payload, &alert); err == nil {
				devUID, err := uuid.Parse(fromClient.ID)
				if err == nil && h.repo != nil {
					alert.DeviceID = devUID
					_ = h.repo.SaveRiskAlert(ctx, &alert)
				}
			}
		}
		h.Lock()
		h.broadcastToFamilyParents(fromClient.FamilyID, msg)
		h.Unlock()

	case domain.TypeTakeScreenshot:
		if fromClient.Role == ClientRoleParent && msg.To != "" {
			if !h.isFamilySubscriptionValid(fromClient.FamilyID) {
				log.Printf("[WS Hub] Blocked TAKE_SCREENSHOT: Subscription expired/inactive for family %s", fromClient.FamilyID)
				h.Lock()
				h.broadcastToFamilyParents(fromClient.FamilyID, domain.WSMessage{
					Type:    domain.TypeScreenshotCaptured,
					From:    msg.To,
					Payload: json.RawMessage(`{"error":"الاشتراك غير مفعّل أو منتهي الصلاحية"}`),
				})
				h.Unlock()
				return
			}
			if !h.hasFamilyFeature(fromClient.FamilyID, "silent_screenshot") {
				log.Printf("[WS Hub] Blocked TAKE_SCREENSHOT: Feature silent_screenshot not in family %s plan", fromClient.FamilyID)
				h.Lock()
				h.broadcastToFamilyParents(fromClient.FamilyID, domain.WSMessage{
					Type:    domain.TypeScreenshotCaptured,
					From:    msg.To,
					Payload: json.RawMessage(`{"error":"ميزة التقاط الشاشة غير متضمنة في باقة الاشتراك الحالية"}`),
				})
				h.Unlock()
				return
			}
			h.Lock()
			if kidClient, ok := h.kids[msg.To]; ok {
				select {
				case kidClient.Send <- rawMsg:
					log.Printf("[WS Hub] Forwarded TAKE_SCREENSHOT to kid %s", msg.To)
				default:
				}
			} else {
				log.Printf("[WS Hub] Failed to forward TAKE_SCREENSHOT: kid %s not online", msg.To)
				h.broadcastToFamilyParents(fromClient.FamilyID, domain.WSMessage{
					Type:    domain.TypeScreenshotCaptured,
					From:    msg.To,
					Payload: json.RawMessage(`{"error":"جهاز الطفل غير متصل حالياً بالإنترنت أو غير متصل بالسيرفر"}`),
				})
			}
			h.Unlock()
		}

	case domain.TypeScreenshotCaptured:
		h.Lock()
		h.broadcastToFamilyParents(fromClient.FamilyID, msg)
		h.Unlock()

	case domain.TypeFetchFileData:
		if fromClient.Role == ClientRoleParent && msg.To != "" {
			if !h.isFamilySubscriptionValid(fromClient.FamilyID) {
				log.Printf("[WS Hub] Blocked FETCH_FILE_DATA: Subscription expired/inactive for family %s", fromClient.FamilyID)
				return
			}
			if !h.hasFamilyFeature(fromClient.FamilyID, "media_gallery") {
				log.Printf("[WS Hub] Blocked FETCH_FILE_DATA: Feature media_gallery not in family %s plan", fromClient.FamilyID)
				return
			}
			h.Lock()
			if kidClient, ok := h.kids[msg.To]; ok {
				select {
				case kidClient.Send <- rawMsg:
				default:
				}
			}
			h.Unlock()
		}

	case domain.TypeFileDataResult:
		h.Lock()
		h.broadcastToFamilyParents(fromClient.FamilyID, msg)
		h.Unlock()

	case domain.TypeGetDeviceOwnerStatus:
		if fromClient.Role == ClientRoleParent && msg.To != "" {
			h.Lock()
			if kidClient, ok := h.kids[msg.To]; ok {
				select {
				case kidClient.Send <- rawMsg:
					log.Printf("[WS Hub] Forwarded GET_DEVICE_OWNER_STATUS to kid %s", msg.To)
				default:
				}
			}
			h.Unlock()
		}

	// Anti-Tamper & Security Alerts (SIM Swap, Airplane Mode, Device Owner Status)
	case domain.TypeSimSwapAlert, domain.TypeAirplaneModeAlert, domain.TypeDeviceOwnerStatus:
		log.Printf("[WS Hub] Anti-Tamper/Security event (%s) from kid device %s (Family: %s)", msg.Type, fromClient.ID, fromClient.FamilyID)
		h.Lock()
		h.broadcastToFamilyParents(fromClient.FamilyID, msg)
		h.Unlock()

	// WebRTC Signaling: SDP Offer / Answer / ICE Candidates / Camera Switch / Stream Error / PTT
	case domain.TypeRTCOffer, domain.TypeRTCAnswer, domain.TypeRTCIceCandidate, domain.TypeStreamStart, domain.TypeStreamStop, domain.TypeStreamError, domain.TypeCameraSwitch, domain.TypeCameraSwitchResult, domain.TypePTTStart, domain.TypePTTStop:
		h.routeSignaling(fromClient, &msg, rawMsg)
	}
}

// isFamilySubscriptionValid verifies whether the family has an active and non-expired subscription
func (h *WSHub) isFamilySubscriptionValid(familyIDStr string) bool {
	if h.repo == nil || familyIDStr == "" {
		return true
	}
	fid, err := uuid.Parse(familyIDStr)
	if err != nil {
		return false
	}
	sub, err := h.repo.GetSubscriptionByFamilyID(context.Background(), fid)
	if err != nil || sub == nil {
		return false
	}
	if !sub.IsActive || (sub.ExpiresAt != nil && time.Now().After(*sub.ExpiresAt)) {
		return false
	}
	return true
}

// hasFamilyFeature verifies whether the family plan includes a specific feature slug
func (h *WSHub) hasFamilyFeature(familyIDStr string, featureKey string) bool {
	if h.repo == nil || familyIDStr == "" {
		return true
	}
	fid, err := uuid.Parse(familyIDStr)
	if err != nil {
		return false
	}
	sub, err := h.repo.GetSubscriptionByFamilyID(context.Background(), fid)
	if err != nil || sub == nil {
		return false
	}
	if !sub.IsActive || (sub.ExpiresAt != nil && time.Now().After(*sub.ExpiresAt)) {
		return false
	}

	tierStr := string(sub.Tier)
	if strings.EqualFold(tierStr, "family_unlimited") || strings.EqualFold(tierStr, "unlimited") {
		return true
	}

	plans, err := h.repo.GetAllPlans(context.Background())
	if err != nil {
		return false
	}
	for _, p := range plans {
		if strings.EqualFold(p.Tier, tierStr) || strings.EqualFold(p.ID, tierStr) {
			var features []string
			if err := json.Unmarshal([]byte(p.Features), &features); err == nil {
				for _, f := range features {
					if strings.EqualFold(f, featureKey) {
						return true
					}
				}
			}
			break
		}
	}
	return false
}

// routeSignaling relays WebRTC signaling packets directly to the targeted recipient
func (h *WSHub) routeSignaling(sender *Client, msg *domain.WSMessage, raw []byte) {
	h.Lock()
	defer h.Unlock()

	if sender.Role == ClientRoleParent {
		// Defensive recipient resolution if To is missing
		if msg.To == "" {
			if msg.DeviceID != "" {
				msg.To = msg.DeviceID
			} else {
				var pMap map[string]interface{}
				if err := json.Unmarshal(msg.Payload, &pMap); err == nil {
					if toVal, ok := pMap["to"].(string); ok && toVal != "" {
						msg.To = toVal
					} else if devVal, ok := pMap["device_id"].(string); ok && devVal != "" {
						msg.To = devVal
					}
				}
			}
			// If still empty, find connected kid in this parent's family
			if msg.To == "" {
				for kidID, kidCl := range h.kids {
					if kidCl.FamilyID == sender.FamilyID {
						msg.To = kidID
						break
					}
				}
			}
		}

		msg.From = sender.ID
		if updatedRaw, err := json.Marshal(msg); err == nil {
			raw = updatedRaw
		}

		log.Printf("[WS Hub Signaling] Type: %s, Sender: %s (%s), To: %s, Family: %s", msg.Type, sender.ID, sender.Role, msg.To, sender.FamilyID)

		// Verify subscription before allowing live stream or WebRTC signaling
		if !h.isFamilySubscriptionValid(sender.FamilyID) {
			log.Printf("[WS Hub Signaling] Blocked %s from Parent %s: Subscription expired or inactive for family %s", msg.Type, sender.ID, sender.FamilyID)
			return
		}

		// Feature Gating: Verify live_camera, webrtc_stream, live_audio or walkie_talkie permission
		if msg.Type == domain.TypeStreamStart || msg.Type == domain.TypeRTCOffer || msg.Type == domain.TypePTTStart {
			if !h.hasFamilyFeature(sender.FamilyID, "live_camera") &&
				!h.hasFamilyFeature(sender.FamilyID, "webrtc_stream") &&
				!h.hasFamilyFeature(sender.FamilyID, "live_audio") &&
				!h.hasFamilyFeature(sender.FamilyID, "walkie_talkie") {
				log.Printf("[WS Hub Signaling] Blocked %s from Parent %s: Streaming/Audio feature not in plan", msg.Type, sender.ID)
				return
			}
		}

		// Parent signaling Kid
		if kidClient, ok := h.kids[msg.To]; ok {
			select {
			case kidClient.Send <- raw:
				log.Printf("[WS Hub Signaling] Successfully forwarded %s from Parent %s to Kid %s", msg.Type, sender.ID, msg.To)
			default:
				log.Printf("[WS Hub Signaling] Kid %s send buffer full, failed to send %s", msg.To, msg.Type)
			}
		} else {
			log.Printf("[WS Hub Signaling] Target Kid %s NOT connected in h.kids map! (Total connected kids: %d)", msg.To, len(h.kids))
		}
	} else if sender.Role == ClientRoleKid {
		msg.From = sender.ID
		if updatedRaw, err := json.Marshal(msg); err == nil {
			raw = updatedRaw
		}

		log.Printf("[WS Hub Signaling] Type: %s, Sender: %s (%s), To: %s, Family: %s", msg.Type, sender.ID, sender.Role, msg.To, sender.FamilyID)

		// Kid answering Parent
		if msg.To != "" {
			if familyParents, ok := h.parents[sender.FamilyID]; ok {
				sent := false
				for _, parentClient := range familyParents {
					if parentClient.ID == msg.To || parentClient.UserID == msg.To {
						select {
						case parentClient.Send <- raw:
							sent = true
							log.Printf("[WS Hub Signaling] Successfully forwarded %s from Kid %s to Parent Conn %s (User %s)", msg.Type, sender.ID, parentClient.ID, parentClient.UserID)
						default:
							log.Printf("[WS Hub Signaling] Parent %s send buffer full", parentClient.ID)
						}
					}
				}
				if sent {
					return
				}
			}
		}
		// Or broadcast to all parents in family if specific parent ID wasn't targeted
		h.broadcastToFamilyParents(sender.FamilyID, *msg)
		log.Printf("[WS Hub Signaling] Broadcasted %s from Kid %s to all parents in family %s", msg.Type, sender.ID, sender.FamilyID)
	}
}
