package middleware

import (
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/parental-control/backend/internal/domain"
	"github.com/parental-control/backend/pkg/jwt"
)

// Protected requires a valid JWT Bearer token
func Protected(secret string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		authHeader := c.Get("Authorization")
		if authHeader == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "Authorization header missing",
			})
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "Invalid authorization token format",
			})
		}

		claims, err := jwt.ParseToken(parts[1], secret)
		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "Invalid or expired token",
			})
		}

		// Store user details in fiber context
		c.Locals("user_id", claims.UserID)
		c.Locals("email", claims.Email)
		c.Locals("role", claims.Role)
		if claims.FamilyID != nil {
			c.Locals("family_id", *claims.FamilyID)
		}

		return c.Next()
	}
}

// RequireRole checks if user has one of allowed roles
func RequireRole(roles ...domain.UserRole) fiber.Handler {
	return func(c *fiber.Ctx) error {
		userRole, ok := c.Locals("role").(domain.UserRole)
		if !ok {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"error": "Forbidden: insufficient permissions",
			})
		}

		for _, r := range roles {
			if userRole == r {
				return c.Next()
			}
		}

		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"error": "Forbidden: role not permitted",
		})
	}
}
