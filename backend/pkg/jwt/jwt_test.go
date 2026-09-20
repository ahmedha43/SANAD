package jwt_test

import (
	"testing"

	"github.com/google/uuid"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/pkg/jwt"
)

func TestTokenGenerationAndParsing(t *testing.T) {
	secret := "my-very-long-secret-key-1234567890"
	userID := uuid.New()
	familyID := uuid.New()

	user := &domain.User{
		ID:       userID,
		Email:    "test@parent.local",
		FullName: "Test Parent",
		Role:     domain.RoleParent,
	}

	tokens, err := jwt.GenerateTokenPair(user, &familyID, secret, 15, 30)
	if err != nil {
		t.Fatalf("GenerateTokenPair failed: %v", err)
	}

	if tokens.AccessToken == "" || tokens.RefreshToken == "" {
		t.Fatalf("Tokens should not be empty")
	}

	claims, err := jwt.ParseToken(tokens.AccessToken, secret)
	if err != nil {
		t.Fatalf("ParseToken failed: %v", err)
	}

	if claims.UserID != userID {
		t.Errorf("Expected user ID %s, got %s", userID, claims.UserID)
	}

	if claims.Email != user.Email {
		t.Errorf("Expected email %s, got %s", user.Email, claims.Email)
	}

	if claims.Role != domain.RoleParent {
		t.Errorf("Expected role %s, got %s", domain.RoleParent, claims.Role)
	}
}
