package service

import (
	"context"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/internal/repository"
)

type LocationService struct {
	repo  *repository.Repository
	redis *repository.RedisClient
}

func NewLocationService(repo *repository.Repository, redis *repository.RedisClient) *LocationService {
	return &LocationService{repo: repo, redis: redis}
}

// RecordLocation saves coordinate and evaluates geofence breaches
func (s *LocationService) RecordLocation(ctx context.Context, deviceID uuid.UUID, payload domain.LocationPayload) (*domain.LocationLog, []domain.GeofenceEvent, error) {
	recTime := time.Now()
	if payload.Timestamp > 0 {
		recTime = time.UnixMilli(payload.Timestamp)
	}

	logEntry := &domain.LocationLog{
		DeviceID:   deviceID,
		Latitude:   payload.Latitude,
		Longitude:  payload.Longitude,
		Accuracy:   payload.Accuracy,
		Altitude:   payload.Altitude,
		Speed:      payload.Speed,
		Bearing:    payload.Bearing,
		RecordedAt: recTime,
	}

	if err := s.repo.SaveLocation(ctx, logEntry); err != nil {
		return nil, nil, err
	}

	// Geofence evaluation
	var triggeredEvents []domain.GeofenceEvent

	dev, err := s.repo.GetDeviceByID(ctx, deviceID)
	if err == nil && dev != nil && dev.ChildID != nil {
		geofences, err := s.repo.GetGeofencesByChild(ctx, *dev.ChildID)
		if err == nil {
			for _, gf := range geofences {
				distMeters := haversineDistance(payload.Latitude, payload.Longitude, gf.Latitude, gf.Longitude)
				isInside := distMeters <= float64(gf.RadiusMeters)

				// Check previous state in Redis
				stateKey := "geofence_state:" + gf.ID.String() + ":" + deviceID.String()
				var wasInside bool
				if s.redis != nil && s.redis.Client != nil {
					val, _ := s.redis.Client.Get(ctx, stateKey).Result()
					wasInside = (val == "inside")

					if isInside && !wasInside && gf.AlertOnEntry {
						event := domain.GeofenceEvent{
							GeofenceID:  gf.ID,
							DeviceID:    deviceID,
							EventType:   "ENTER",
							TriggeredAt: time.Now(),
						}
						_ = s.repo.RecordGeofenceEvent(ctx, &event)
						triggeredEvents = append(triggeredEvents, event)
						s.redis.Client.Set(ctx, stateKey, "inside", 24*time.Hour)
					} else if !isInside && wasInside && gf.AlertOnExit {
						event := domain.GeofenceEvent{
							GeofenceID:  gf.ID,
							DeviceID:    deviceID,
							EventType:   "EXIT",
							TriggeredAt: time.Now(),
						}
						_ = s.repo.RecordGeofenceEvent(ctx, &event)
						triggeredEvents = append(triggeredEvents, event)
						s.redis.Client.Set(ctx, stateKey, "outside", 24*time.Hour)
					}
				}
			}
		}
	}

	return logEntry, triggeredEvents, nil
}

// haversineDistance calculates the great-circle distance between two points in meters
func haversineDistance(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadius = 6371000 // in meters

	dLat := (lat2 - lat1) * (math.Pi / 180.0)
	dLon := (lon2 - lon1) * (math.Pi / 180.0)

	rLat1 := lat1 * (math.Pi / 180.0)
	rLat2 := lat2 * (math.Pi / 180.0)

	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(rLat1)*math.Cos(rLat2)*math.Sin(dLon/2)*math.Sin(dLon/2)

	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return earthRadius * c
}
