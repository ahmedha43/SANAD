package service

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/parental-control/backend/config"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/internal/repository"
	"github.com/parental-control/backend/pkg/crypto"
	"github.com/parental-control/backend/pkg/jwt"
)

type AuthService struct {
	repo *repository.Repository
	cfg  *config.Config
}

func NewAuthService(repo *repository.Repository, cfg *config.Config) *AuthService {
	return &AuthService{repo: repo, cfg: cfg}
}

type RegisterRequest struct {
	Email       string `json:"email"`
	Password    string `json:"password"`
	FullName    string `json:"full_name"`
	PhoneNumber string `json:"phone_number"`
	FamilyName  string `json:"family_name"`
}

type AuthResponse struct {
	User   *domain.User   `json:"user"`
	Family *domain.Family `json:"family,omitempty"`
	Tokens *jwt.TokenPair `json:"tokens"`
}

func (s *AuthService) Register(ctx context.Context, req RegisterRequest) (*AuthResponse, error) {
	if req.Email == "" || req.Password == "" || req.FullName == "" {
		return nil, errors.New("email, password, and full name are required")
	}

	// Check existing user
	existing, _ := s.repo.GetUserByEmail(ctx, req.Email)
	if existing != nil {
		return nil, errors.New("an account with this email already exists")
	}

	hash, err := crypto.HashPassword(req.Password)
	if err != nil {
		return nil, err
	}

	userID := uuid.New()
	user := &domain.User{
		ID:           userID,
		Email:        req.Email,
		PasswordHash: hash,
		FullName:     req.FullName,
		PhoneNumber:  req.PhoneNumber,
		Role:         domain.RoleParent,
		IsActive:     true,
	}

	if err := s.repo.CreateUser(ctx, user); err != nil {
		return nil, err
	}

	// Create default Family
	familyName := req.FamilyName
	if familyName == "" {
		familyName = req.FullName + "'s Family"
	}
	family := &domain.Family{
		ID:      uuid.New(),
		Name:    familyName,
		OwnerID: user.ID,
	}
	if err := s.repo.CreateFamily(ctx, family); err != nil {
		return nil, err
	}

	// Create Free Subscription
	sub := &domain.Subscription{
		ID:         uuid.New(),
		FamilyID:   family.ID,
		Tier:       domain.TierFree,
		MaxDevices: 2,
		StartsAt:   time.Now(),
		IsActive:   true,
	}
	_ = s.repo.CreateSubscription(ctx, sub)
	family.Subscription = sub

	tokens, err := jwt.GenerateTokenPair(user, &family.ID, s.cfg.JWTSecret, s.cfg.JWTAccessTTLMinutes, s.cfg.JWTRefreshTTLDays)
	if err != nil {
		return nil, err
	}

	return &AuthResponse{
		User:   user,
		Family: family,
		Tokens: tokens,
	}, nil
}

func (s *AuthService) Login(ctx context.Context, email, password string) (*AuthResponse, error) {
	user, err := s.repo.GetUserByEmail(ctx, email)
	if err != nil || user == nil {
		return nil, errors.New("invalid email or password")
	}

	if !crypto.CheckPasswordHash(password, user.PasswordHash) {
		return nil, errors.New("invalid email or password")
	}

	if !user.IsActive {
		return nil, errors.New("account is disabled")
	}

	// Fetch primary family
	var familyID *uuid.UUID
	var primaryFamily *domain.Family
	families, err := s.repo.GetFamiliesByOwnerID(ctx, user.ID)
	if err == nil && len(families) > 0 {
		familyID = &families[0].ID
		primaryFamily = &families[0]
	} else {
		// Auto-provision a family if missing (e.g. seeded admin)
		newFamily := &domain.Family{
			ID:      uuid.New(),
			Name:    user.FullName + "'s Family",
			OwnerID: user.ID,
		}
		if createErr := s.repo.CreateFamily(ctx, newFamily); createErr == nil {
			sub := &domain.Subscription{
				ID:         uuid.New(),
				FamilyID:   newFamily.ID,
				Tier:       domain.TierFamilyUnlimited,
				MaxDevices: 10,
				StartsAt:   time.Now(),
				IsActive:   true,
			}
			_ = s.repo.CreateSubscription(ctx, sub)
			newFamily.Subscription = sub
			familyID = &newFamily.ID
			primaryFamily = newFamily
		}
	}

	tokens, err := jwt.GenerateTokenPair(user, familyID, s.cfg.JWTSecret, s.cfg.JWTAccessTTLMinutes, s.cfg.JWTRefreshTTLDays)
	if err != nil {
		return nil, err
	}

	return &AuthResponse{
		User:   user,
		Family: primaryFamily,
		Tokens: tokens,
	}, nil
}
