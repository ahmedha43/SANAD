package service

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/internal/repository"
	"github.com/parental-control/backend/pkg/crypto"
)

type PairingService struct {
	repo *repository.Repository
}

func NewPairingService(repo *repository.Repository) *PairingService {
	return &PairingService{repo: repo}
}

// GeneratePairingCode generates a 6-digit code valid for 15 minutes
func (s *PairingService) GeneratePairingCode(ctx context.Context, familyID, childID uuid.UUID) (*domain.PairingCode, error) {
	// 1. Verify subscription validity
	sub, err := s.repo.GetSubscriptionByFamilyID(ctx, familyID)
	if err != nil || sub == nil {
		return nil, errors.New("لا يوجد اشتراك مفعل لهذه العائلة، يرجى تفعيل الاشتراك أولاً")
	}

	if !sub.IsActive {
		return nil, errors.New("اشتراك العائلة معلق حالياً، يرجى التواصل مع الإدارة للتفعيل")
	}

	if sub.ExpiresAt != nil && time.Now().After(*sub.ExpiresAt) {
		return nil, errors.New("انتهت صلاحية باقة اشتراكك، يرجى التجديد لتتمكن من إضافة أجهزة جديدة")
	}

	// 2. Check maximum devices quota
	devices, _ := s.repo.GetDevicesByFamilyID(ctx, familyID)
	if len(devices) >= sub.MaxDevices {
		return nil, errors.New("لقد استهلكت الحد الأقصى للأجهزة المسموح بها في باقتك. يرجى ترقية باقتك لإضافة المزيد من الأجهزة.")
	}

	code, err := crypto.GenerateNumericCode(6)
	if err != nil {
		return nil, err
	}

	pc := &domain.PairingCode{
		Code:      code,
		FamilyID:  familyID,
		ChildID:   childID,
		ExpiresAt: time.Now().Add(15 * time.Minute),
		IsUsed:    false,
	}

	if err := s.repo.SavePairingCode(ctx, pc); err != nil {
		return nil, err
	}

	return pc, nil
}

type PairDeviceRequest struct {
	Code        string `json:"code"`
	DeviceUID   string `json:"device_uid"`
	DeviceName  string `json:"device_name"`
	Model       string `json:"model"`
	OSVersion   string `json:"os_version"`
	AppVersion  string `json:"app_version"`
	FCMToken    string `json:"fcm_token"`
	OSType      string `json:"os_type"`
}

type PairDeviceResponse struct {
	DeviceID      uuid.UUID `json:"device_id"`
	FamilyID      uuid.UUID `json:"family_id"`
	ChildID       uuid.UUID `json:"child_id"`
	PairingSecret string    `json:"pairing_secret"`
	ServerTime    int64     `json:"server_time"`
}

// PairKidDevice validates pairing code and registers the child's Android or Windows device
func (s *PairingService) PairKidDevice(ctx context.Context, req PairDeviceRequest) (*PairDeviceResponse, error) {
	cleanCode := normalizePairingCode(req.Code)
	pc, err := s.repo.GetValidPairingCode(ctx, cleanCode)
	if err != nil || pc == nil {
		return nil, errors.New("كود الاقتران غير صالح أو منتهي الصلاحية")
	}

	// Determine OS Type
	osType := strings.ToLower(req.OSType)
	if osType == "" {
		lowerModel := strings.ToLower(req.Model)
		lowerOS := strings.ToLower(req.OSVersion)
		if strings.Contains(lowerModel, "windows") || strings.Contains(lowerOS, "windows") {
			osType = "windows"
		} else {
			osType = "android"
		}
	}

	// Check subscription validity & device limit
	sub, _ := s.repo.GetSubscriptionByFamilyID(ctx, pc.FamilyID)
	if sub != nil {
		if !sub.IsActive {
			return nil, errors.New("اشتراك العائلة غير مفعل حالياً")
		}
		if sub.ExpiresAt != nil && time.Now().After(*sub.ExpiresAt) {
			return nil, errors.New("انتهت صلاحية اشتراك هذه العائلة")
		}

		devices, _ := s.repo.GetDevicesByFamilyID(ctx, pc.FamilyID)
		if len(devices) >= sub.MaxDevices {
			return nil, errors.New("تم الوصول للحد الأقصى لعدد الأجهزة المسموحة في باقة هذه العائلة")
		}
	}

	pairingSecret, err := crypto.GenerateRandomHex(32)
	if err != nil {
		return nil, err
	}

	// Check if device already exists by UID
	existing, _ := s.repo.GetDeviceByUID(ctx, req.DeviceUID)
	var deviceID uuid.UUID

	if existing != nil {
		deviceID = existing.ID
		existing.ChildID = &pc.ChildID
		existing.FamilyID = pc.FamilyID
		existing.DeviceName = req.DeviceName
		existing.Model = req.Model
		existing.OSVersion = req.OSVersion
		existing.OSType = osType
		existing.AppVersion = req.AppVersion
		existing.PairingSecret = pairingSecret
		existing.FCMToken = req.FCMToken
		existing.Status = domain.StatusOnline
		now := time.Now()
		existing.LastSeenAt = &now
		if err := s.repo.CreateDevice(ctx, existing); err != nil {
			// Update fallback
		}
	} else {
		deviceID = uuid.New()
		dev := &domain.Device{
			ID:            deviceID,
			ChildID:       &pc.ChildID,
			FamilyID:      pc.FamilyID,
			DeviceUID:     req.DeviceUID,
			DeviceName:    req.DeviceName,
			Model:         req.Model,
			OSVersion:     req.OSVersion,
			OSType:        osType,
			AppVersion:    req.AppVersion,
			Status:        domain.StatusOnline,
			PairingSecret: pairingSecret,
			FCMToken:      req.FCMToken,
		}
		if err := s.repo.CreateDevice(ctx, dev); err != nil {
			return nil, err
		}
	}

	// Mark pairing code as used
	_ = s.repo.MarkPairingCodeUsed(ctx, cleanCode)

	return &PairDeviceResponse{
		DeviceID:      deviceID,
		FamilyID:      pc.FamilyID,
		ChildID:       pc.ChildID,
		PairingSecret: pairingSecret,
		ServerTime:    time.Now().UnixMilli(),
	}, nil
}

func normalizePairingCode(code string) string {
	var b strings.Builder
	for _, r := range strings.TrimSpace(code) {
		if r >= '0' && r <= '9' {
			b.WriteRune(r)
		} else if r >= '\u0660' && r <= '\u0669' {
			b.WriteRune('0' + (r - '\u0660'))
		} else if r >= '\u06F0' && r <= '\u06F9' {
			b.WriteRune('0' + (r - '\u06F0'))
		}
	}
	return b.String()
}
