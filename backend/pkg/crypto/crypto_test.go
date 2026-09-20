package crypto_test

import (
	"testing"

	"github.com/parental-control/backend/pkg/crypto"
)

func TestHashAndCheckPassword(t *testing.T) {
	password := "SecretParentPassword2026!"
	hash, err := crypto.HashPassword(password)
	if err != nil {
		t.Fatalf("Failed to hash password: %v", err)
	}

	if !crypto.CheckPasswordHash(password, hash) {
		t.Errorf("Password hash check failed for valid password")
	}

	if crypto.CheckPasswordHash("WrongPassword", hash) {
		t.Errorf("Password hash check returned true for incorrect password")
	}
}

func TestGenerateNumericCode(t *testing.T) {
	code, err := crypto.GenerateNumericCode(6)
	if err != nil {
		t.Fatalf("Failed to generate numeric code: %v", err)
	}

	if len(code) != 6 {
		t.Errorf("Expected 6 digits, got %d (code: %s)", len(code), code)
	}
}
