package config

import (
	"os"
	"strconv"
)

type Config struct {
	ServerPort string
	Env        string

	// Postgres
	DBHost     string
	DBPort     string
	DBUser     string
	DBPassword string
	DBName     string
	DBSSLMode  string

	// Redis
	RedisHost     string
	RedisPort     string
	RedisPassword string

	// JWT
	JWTSecret           string
	JWTAccessTTLMinutes int
	JWTRefreshTTLDays   int

	// WebRTC & Coturn
	TurnStunURL    string
	TurnURL        string
	TurnUsername   string
	TurnCredential string

	// Push Notifications
	FCMServerKey string
}

func LoadConfig() *Config {
	return &Config{
		ServerPort: getEnv("SERVER_PORT", "8080"),
		Env:        getEnv("ENV", "development"),

		DBHost:     getEnv("DB_HOST", "127.0.0.1"),
		DBPort:     getEnv("DB_PORT", "5432"),
		DBUser:     getEnv("DB_USER", "pc_admin"),
		DBPassword: getEnv("DB_PASSWORD", "pc_secret_db_password_2026"),
		DBName:     getEnv("DB_NAME", "parental_control_db"),
		DBSSLMode:  getEnv("DB_SSLMODE", "disable"),

		RedisHost:     getEnv("REDIS_HOST", "127.0.0.1"),
		RedisPort:     getEnv("REDIS_PORT", "6379"),
		RedisPassword: getEnv("REDIS_PASSWORD", "pc_redis_secret_password_2026"),

		JWTSecret:           getEnv("JWT_SECRET", "018f45a0b9e87d6a5c4b3a2f1e0d9c8b7a654321fedcba0987654321abcdef01"),
		JWTAccessTTLMinutes: getEnvAsInt("JWT_ACCESS_TTL_MINUTES", 60*24), // 24 hours for dev
		JWTRefreshTTLDays:   getEnvAsInt("JWT_REFRESH_TTL_DAYS", 30),

		TurnStunURL:    getEnv("TURN_STUN_URL", "stun:127.0.0.1:3478"),
		TurnURL:        getEnv("TURN_URL", "turn:127.0.0.1:3478"),
		TurnUsername:   getEnv("TURN_USERNAME", "parentalctl"),
		TurnCredential: getEnv("TURN_CREDENTIAL", "SecureTurnSecretPass2026"),

		FCMServerKey: getEnv("FCM_SERVER_KEY", ""),
	}
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}

func getEnvAsInt(key string, fallback int) int {
	valStr := os.Getenv(key)
	if valStr == "" {
		return fallback
	}
	val, err := strconv.Atoi(valStr)
	if err != nil {
		return fallback
	}
	return val
}
