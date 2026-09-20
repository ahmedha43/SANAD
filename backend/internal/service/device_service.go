package service

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/internal/repository"
)

type DeviceService struct {
	repo  *repository.Repository
	redis *repository.RedisClient
}

func NewDeviceService(repo *repository.Repository, redis *repository.RedisClient) *DeviceService {
	return &DeviceService{repo: repo, redis: redis}
}

// UpdateHeartbeat records telemetry from Kid device
func (s *DeviceService) UpdateHeartbeat(ctx context.Context, deviceID uuid.UUID, battery domain.BatteryPayload) error {
	_ = s.redis.SetDeviceOnline(ctx, deviceID.String())
	return s.repo.UpdateDeviceStatus(ctx, deviceID, domain.StatusOnline, battery.BatteryLevel, battery.IsCharging, battery.NetworkType)
}

// QueueCommand stores an async command
func (s *DeviceService) QueueCommand(ctx context.Context, deviceID uuid.UUID, action string, params map[string]interface{}) (*domain.DeviceCommand, error) {
	payloadBytes, err := json.Marshal(params)
	if err != nil {
		return nil, err
	}

	cmd := &domain.DeviceCommand{
		ID:          uuid.New(),
		DeviceID:    deviceID,
		CommandType: action,
		Payload:     string(payloadBytes),
		Status:      domain.CommandPending,
		CreatedAt:   time.Now(),
	}

	if err := s.repo.CreateCommand(ctx, cmd); err != nil {
		return nil, err
	}

	return cmd, nil
}

// AcknowledgeCommand marks command executed or failed
func (s *DeviceService) AcknowledgeCommand(ctx context.Context, cmdID uuid.UUID, success bool, errMsg string) error {
	status := domain.CommandExecuted
	if !success {
		status = domain.CommandFailed
	}
	return s.repo.UpdateCommandStatus(ctx, cmdID, status, errMsg)
}

// ValidateDeviceSecret validates incoming device requests
func (s *DeviceService) ValidateDeviceSecret(ctx context.Context, deviceID uuid.UUID, secret string) (*domain.Device, error) {
	dev, err := s.repo.GetDeviceByID(ctx, deviceID)
	if err != nil || dev == nil {
		return nil, errors.New("device not found")
	}
	if dev.PairingSecret != secret {
		return nil, errors.New("invalid device credentials")
	}
	return dev, nil
}
