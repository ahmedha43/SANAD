package main

import (
	"log"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/parental-control/backend/config"
	"github.com/parental-control/backend/internal/handler"
	"github.com/parental-control/backend/internal/middleware"
	"github.com/parental-control/backend/internal/repository"
	"github.com/parental-control/backend/internal/service"
)

func main() {
	cfg := config.LoadConfig()

	// 1. Database & Cache
	db, err := repository.NewPostgresDB(cfg)
	if err != nil {
		log.Printf("Warning: Failed to connect to Postgres (%v). Backend will boot in test-ready configuration.", err)
	}

	redisClient, err := repository.NewRedisClient(cfg)
	if err != nil {
		log.Printf("Warning: Failed to connect to Redis (%v)", err)
	}

	repo := repository.NewRepository(db)

	// 2. Services
	authService := service.NewAuthService(repo, cfg)
	pairingService := service.NewPairingService(repo)
	deviceService := service.NewDeviceService(repo, redisClient)
	locationService := service.NewLocationService(repo, redisClient)
	appService := service.NewAppService(repo)

	// 3. WebSocket Hub
	wsHub := handler.NewWSHub(locationService, deviceService, appService, repo)
	go wsHub.Run()

	// 4. HTTP & WS Handlers
	authHandler := handler.NewAuthHandler(authService, repo)
	deviceHandler := handler.NewDeviceHandler(repo, pairingService, deviceService, locationService, wsHub)
	locationHandler := handler.NewLocationHandler(repo, locationService)
	appHandler := handler.NewAppHandler(repo, appService, deviceService, wsHub)
	webrtcHandler := handler.NewWebRTCHandler(cfg)
	wsHandler := handler.NewWSHandler(wsHub, repo, cfg)

	// 5. Fiber App Setup
	app := fiber.New(fiber.Config{
		AppName:      "Parental Control API v1.0",
		ServerHeader: "ParentalControl-Fiber",
	})

	app.Use(recover.New())
	app.Use(logger.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization",
		AllowMethods: "GET, POST, PUT, DELETE, OPTIONS, PATCH",
	}))

	// Health Check
	app.Get("/healthz", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "healthy",
			"version": "1.0.0",
		})
	})

	// WebSocket Endpoint
	app.Use("/ws", wsHandler.UpgradeCheck())
	app.Get("/ws", wsHandler.HandleWS())

	// API Routes
	api := app.Group("/api/v1")

	// Public Auth
	authRoutes := api.Group("/auth")
	authRoutes.Post("/register", authHandler.Register)
	authRoutes.Post("/login", authHandler.Login)

	// Kid Agent Endpoints (Public/Device Auth)
	webFilterHandler := handler.NewWebFilterHandler(repo, wsHub)
	browserHistoryHandler := handler.NewBrowserHistoryHandler(repo, wsHub)
	devicePublic := api.Group("/devices")
	devicePublic.Post("/pair", deviceHandler.PairDevice)
	devicePublic.Post("/:id/location", locationHandler.PostLocation)
	devicePublic.Post("/:id/apps/sync", appHandler.SyncInstalledApps)
	devicePublic.Post("/:id/usage", appHandler.SyncDailyUsage)
	devicePublic.Post("/:id/notifications", appHandler.PostNotification)
	devicePublic.Post("/:id/sync/offline", deviceHandler.SyncOfflineData)
	devicePublic.Get("/:id/safe-patterns", deviceHandler.GetSafeRiskPatterns)
	api.Get("/agent/:id/blocked-apps", appHandler.GetBlockedApps)
	api.Get("/agent/:id/status", deviceHandler.GetDeviceAgentStatus)
	api.Get("/agent/:id/web-filter", webFilterHandler.GetAgentWebFilter)
	api.Get("/agent/:id/safe-patterns", deviceHandler.GetSafeRiskPatterns)
	api.Post("/agent/:id/notifications", appHandler.PostNotification)
	api.Post("/agent/:id/browser-history", browserHistoryHandler.PostBrowserHistory)

	// WebRTC Config
	api.Get("/webrtc/config", webrtcHandler.GetRTCConfig)

	adminHandler := handler.NewAdminHandler(repo, wsHub)

	// Protected User Profile & Subscription
	api.Get("/auth/me", middleware.Protected(cfg.JWTSecret), authHandler.GetMe)
	api.Get("/subscription/my", middleware.Protected(cfg.JWTSecret), deviceHandler.GetMySubscription)

	requireActiveSub := middleware.RequireActiveSubscription(repo)
	requireRouteReplay := middleware.RequirePlanFeature(repo, "route_replay")
	requireAppBlock := middleware.RequirePlanFeature(repo, "app_blocking")
	requireScreenTime := middleware.RequirePlanFeature(repo, "screen_time")
	requireGeofence := middleware.RequirePlanFeature(repo, "geofencing")
	requireRisk := middleware.RequirePlanFeature(repo, "ai_risk_detection")
	requireFiles := middleware.RequirePlanFeature(repo, "media_gallery")
	requireNotifs := middleware.RequirePlanFeature(repo, "notifications")
	requireContacts := middleware.RequirePlanFeature(repo, "contacts")

	// Device Management for Parents (Protected)
	parentDevices := api.Group("/devices", middleware.Protected(cfg.JWTSecret))
	parentDevices.Get("/", deviceHandler.ListDevices)
	parentDevices.Get("/children", deviceHandler.ListChildren)
	parentDevices.Post("/children", requireActiveSub, deviceHandler.CreateChild)
	parentDevices.Post("/children/:child_id/pair-code", requireActiveSub, deviceHandler.GeneratePairingCode)
	parentDevices.Post("/:id/command", requireActiveSub, deviceHandler.SendCommand)
	parentDevices.Get("/:id/location/latest", requireActiveSub, locationHandler.GetLatestLocation)
	parentDevices.Get("/:id/location/history", requireActiveSub, requireRouteReplay, locationHandler.GetLocationHistory)
	parentDevices.Get("/:id/apps", requireActiveSub, appHandler.GetDeviceApps)
	parentDevices.Post("/:id/apps/block", requireActiveSub, requireAppBlock, appHandler.ToggleBlock)
	parentDevices.Get("/:id/usage", requireActiveSub, appHandler.GetDailyUsage)
	parentDevices.Get("/:id/notifications", requireActiveSub, requireNotifs, appHandler.GetNotifications)
	parentDevices.Get("/:id/screen-time-rules", requireActiveSub, requireScreenTime, deviceHandler.GetScreenTimeRule)
	parentDevices.Post("/:id/screen-time-rules", requireActiveSub, requireScreenTime, deviceHandler.SaveScreenTimeRule)
	parentDevices.Get("/:id/contacts", requireActiveSub, requireContacts, deviceHandler.GetContacts)
	parentDevices.Get("/:id/sms", requireActiveSub, deviceHandler.GetSMS)
	parentDevices.Get("/:id/files", requireActiveSub, requireFiles, deviceHandler.GetFiles)
	parentDevices.Get("/:id/calls", requireActiveSub, deviceHandler.GetCalls)
	parentDevices.Get("/:id/risk-alerts", requireActiveSub, requireRisk, deviceHandler.GetRiskAlerts)
	parentDevices.Post("/:id/risk-alerts/:alertId/mark-safe", requireActiveSub, requireRisk, deviceHandler.MarkRiskAlertSafe)
	parentDevices.Get("/:id/safe-patterns", requireActiveSub, deviceHandler.GetSafeRiskPatterns)
	parentDevices.Delete("/:id", requireActiveSub, deviceHandler.DeleteDevice)

	// Web Filter Management (Protected)
	parentDevices.Get("/:id/web-filter", requireActiveSub, webFilterHandler.GetRules)
	parentDevices.Post("/:id/web-filter", requireActiveSub, webFilterHandler.CreateRule)
	parentDevices.Put("/:id/web-filter/toggle-engine", requireActiveSub, webFilterHandler.ToggleEngine)
	parentDevices.Put("/:id/web-filter/toggle-all", requireActiveSub, webFilterHandler.ToggleAll)
	parentDevices.Put("/:id/web-filter/:rule_id/toggle", requireActiveSub, webFilterHandler.ToggleRule)
	parentDevices.Delete("/:id/web-filter/:rule_id", requireActiveSub, webFilterHandler.DeleteRule)
	parentDevices.Post("/:id/web-filter/seed-defaults", requireActiveSub, webFilterHandler.SeedDefaults)
	parentDevices.Get("/:id/browser-history", requireActiveSub, browserHistoryHandler.GetBrowserHistory)
	parentDevices.Get("/:id/browser-history/stats", requireActiveSub, browserHistoryHandler.GetBrowserHistoryStats)
	parentDevices.Delete("/:id/browser-history", requireActiveSub, browserHistoryHandler.ClearBrowserHistory)
	parentDevices.Post("/:id/browser-history/quick-block", requireActiveSub, browserHistoryHandler.QuickBlockDomain)

	// Geofence Management (Protected - Requires Active Subscription & Geofencing Feature)
	geofenceAPI := api.Group("/geofences", middleware.Protected(cfg.JWTSecret), requireActiveSub, requireGeofence)
	geofenceAPI.Post("/", locationHandler.CreateGeofence)
	geofenceAPI.Get("/child/:child_id", locationHandler.GetGeofences)
	geofenceAPI.Get("/events/:child_id", locationHandler.GetGeofenceEvents)
	geofenceAPI.Delete("/:id", locationHandler.DeleteGeofence)

	// Admin Endpoints (Accessible by Admin Panel & Dashboard)
	adminAPI := api.Group("/admin")
	adminAPI.Get("/overview", adminHandler.GetOverview)
	adminAPI.Get("/stats", adminHandler.GetOverview)
	adminAPI.Get("/users", adminHandler.GetUsers)
	adminAPI.Get("/devices", adminHandler.GetDevices)
	adminAPI.Get("/subscriptions", adminHandler.GetSubscriptions)
	adminAPI.Put("/subscriptions/:id", adminHandler.UpdateSubscription)
	adminAPI.Post("/subscriptions/:id/renew", adminHandler.RenewSubscription)
	adminAPI.Post("/subscriptions/:id/toggle", adminHandler.ToggleSubscription)
	adminAPI.Get("/plans", adminHandler.GetPlans)
	adminAPI.Post("/plans", adminHandler.CreatePlan)
	adminAPI.Put("/plans/:id", adminHandler.UpdatePlan)
	adminAPI.Delete("/plans/:id", adminHandler.DeletePlan)
	adminAPI.Get("/logs", adminHandler.GetLogs)

	// Web Dashboard Static Serving
	app.Static("/dashboard", "./web")
	app.Get("/", func(c *fiber.Ctx) error {
		return c.Redirect("/dashboard")
	})

	log.Printf("Parental Control Server starting on port :%s ...", cfg.ServerPort)
	log.Fatal(app.Listen(":" + cfg.ServerPort))
}
