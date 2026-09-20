package middleware

import (
	"encoding/json"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/internal/repository"
)

// RequireActiveSubscription ensures that the authenticated family has an active, non-expired subscription
func RequireActiveSubscription(repo *repository.Repository) fiber.Handler {
	return func(c *fiber.Ctx) error {
		familyID, ok := c.Locals("family_id").(uuid.UUID)
		if !ok {
			// If role is superadmin, bypass subscription check
			role, okRole := c.Locals("role").(domain.UserRole)
			if okRole && role == domain.RoleSuperAdmin {
				return c.Next()
			}
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error":   "family_not_found",
				"message": "لم يتم العثور على العائلة المرتبطة بحسابك",
			})
		}

		sub, err := repo.GetSubscriptionByFamilyID(c.Context(), familyID)
		if err != nil || sub == nil {
			return c.Status(fiber.StatusPaymentRequired).JSON(fiber.Map{
				"error":   "subscription_not_found",
				"message": "لا يوجد ترخيص أو اشتراك مسجل لهذه العائلة، يرجى الاشتراك للبدء",
			})
		}

		// Check if subscription is explicitly suspended or inactive
		if !sub.IsActive {
			return c.Status(fiber.StatusPaymentRequired).JSON(fiber.Map{
				"error":      "subscription_suspended",
				"message":    "تم تعليق اشتراكك مؤقتاً، يرجى مراجعة إدارة المنصة أو تجديد الترخيص",
				"tier":       string(sub.Tier),
				"status":     "suspended",
				"expires_at": sub.ExpiresAt,
			})
		}

		// Check if subscription has expired
		if sub.ExpiresAt != nil && time.Now().After(*sub.ExpiresAt) {
			return c.Status(fiber.StatusPaymentRequired).JSON(fiber.Map{
				"error":      "subscription_expired",
				"message":    "انتهت صلاحية باقة اشتراكك، يرجى تجديد الترخيص لمتابعة المراقبة والحماية",
				"tier":       string(sub.Tier),
				"status":     "expired",
				"expires_at": sub.ExpiresAt,
			})
		}

		// Store subscription in locals for downstream handlers
		c.Locals("subscription", sub)
		return c.Next()
	}
}

// RequirePlanFeature checks if the family's subscription tier/plan supports a specific feature
// Features e.g.: "live_camera", "live_stream", "live_gps", "geofencing", "app_blocking", "ai_risk"
func RequirePlanFeature(repo *repository.Repository, featureKey string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		// If role is superadmin, allow all features
		role, okRole := c.Locals("role").(domain.UserRole)
		if okRole && role == domain.RoleSuperAdmin {
			return c.Next()
		}

		var sub *domain.Subscription
		if s, ok := c.Locals("subscription").(*domain.Subscription); ok {
			sub = s
		} else {
			familyID, ok := c.Locals("family_id").(uuid.UUID)
			if !ok {
				return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "family_not_found"})
			}
			var err error
			sub, err = repo.GetSubscriptionByFamilyID(c.Context(), familyID)
			if err != nil || sub == nil {
				return c.Status(fiber.StatusPaymentRequired).JSON(fiber.Map{"error": "subscription_not_found"})
			}
		}

		// Family Unlimited tier has all features by default
		tierStr := string(sub.Tier)
		if strings.EqualFold(tierStr, "family_unlimited") || strings.EqualFold(tierStr, "unlimited") {
			return c.Next()
		}

		// Look up plan in repository to inspect JSON features
		plans, err := repo.GetAllPlans(c.Context())
		if err == nil {
			for _, p := range plans {
				if strings.EqualFold(p.Tier, tierStr) || strings.EqualFold(p.ID, tierStr) {
					var features []string
					if err := json.Unmarshal([]byte(p.Features), &features); err == nil {
						for _, f := range features {
							if strings.EqualFold(f, featureKey) {
								return c.Next()
							}
						}
					}
					break
				}
			}
		}

		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"error":        "feature_not_supported",
			"message":      "هذه الميزة غير متاحة في باقتك الحالية. يرجى ترقية الباقة لتفعيلها.",
			"feature":      featureKey,
			"current_tier": tierStr,
		})
	}
}
