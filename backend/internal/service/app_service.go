package service

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/internal/repository"
)

type AppService struct {
	repo *repository.Repository
}

func NewAppService(repo *repository.Repository) *AppService {
	return &AppService{repo: repo}
}

type SyncAppsRequest struct {
	DeviceID uuid.UUID          `json:"device_id"`
	Apps     []domain.DeviceApp `json:"apps"`
}

func (s *AppService) SyncApps(ctx context.Context, deviceID uuid.UUID, apps []domain.DeviceApp) error {
	for i := range apps {
		apps[i].DeviceID = deviceID
		if apps[i].ID == uuid.Nil {
			apps[i].ID = uuid.New()
		}
	}
	return s.repo.UpsertDeviceApps(ctx, apps)
}

func (s *AppService) ToggleAppBlock(ctx context.Context, deviceID uuid.UUID, packageName string, blocked bool) error {
	return s.repo.SetAppBlocked(ctx, deviceID, packageName, blocked)
}

func (s *AppService) RecordDailyUsage(ctx context.Context, usage *domain.AppUsageDaily) error {
	return s.repo.UpsertDailyUsage(ctx, usage)
}

func (s *AppService) SaveNotification(ctx context.Context, deviceID uuid.UUID, appName, packageName, title, content string, receivedAt time.Time) error {
	notif := &domain.KidNotification{
		DeviceID:    deviceID,
		AppName:     appName,
		PackageName: packageName,
		Title:       title,
		Content:     content,
		ReceivedAt:  receivedAt,
	}
	return s.repo.SaveKidNotification(ctx, notif)
}
