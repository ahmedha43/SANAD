package repository

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/parental-control/backend/config"
	"github.com/redis/go-redis/v9"
)

type RedisClient struct {
	Client *redis.Client
}

func NewRedisClient(cfg *config.Config) (*RedisClient, error) {
	rdb := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%s", cfg.RedisHost, cfg.RedisPort),
		Password: cfg.RedisPassword,
		DB:       0,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Printf("Warning: Redis connection failed (%v). Will proceed with in-memory fallback where applicable.", err)
		return &RedisClient{Client: rdb}, nil
	}

	log.Println("Connected to Redis successfully")
	return &RedisClient{Client: rdb}, nil
}

// SetDeviceOnline marks a device online in Redis with a 90 second TTL
func (r *RedisClient) SetDeviceOnline(ctx context.Context, deviceID string) error {
	key := fmt.Sprintf("presence:device:%s", deviceID)
	return r.Client.Set(ctx, key, "online", 90*time.Second).Err()
}

// SetDeviceOffline marks a device offline
func (r *RedisClient) SetDeviceOffline(ctx context.Context, deviceID string) error {
	key := fmt.Sprintf("presence:device:%s", deviceID)
	return r.Client.Del(ctx, key).Err()
}

// IsDeviceOnline checks if device presence key exists
func (r *RedisClient) IsDeviceOnline(ctx context.Context, deviceID string) bool {
	key := fmt.Sprintf("presence:device:%s", deviceID)
	val, err := r.Client.Get(ctx, key).Result()
	return err == nil && val == "online"
}
