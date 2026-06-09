package domain

import (
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// JWTCustomClaims เก็บข้อมูลสำคัญที่จะฝังไปกับ Access Token (Stateless JWT)
type JWTCustomClaims struct {
	UserID   uuid.UUID `json:"user_id"`
	TenantID uuid.UUID `json:"tenant_id"`
	Email    string    `json:"email"`
	IsAdmin  bool      `json:"is_admin"`
	jwt.RegisteredClaims
}

// RefreshToken เก็บสถานะ Token อายุยาวในฐานข้อมูลเพื่อทำ Token Rotation และ Revocation
type RefreshToken struct {
	TenantBase           // สืบทอด TenantID และ ID (UUID) อัตโนมัติ เพื่อควบคุม Multi-Tenant
	UserID     uuid.UUID `gorm:"type:uuid;not null;index"`
	Token      string    `gorm:"type:varchar(500);not null;uniqueIndex"`
	ExpiresAt  time.Time `gorm:"not null"`
	IsRevoked  bool      `gorm:"not null;default:false"`
	UserAgent  string    `gorm:"type:varchar(255)"`
	ClientIP   string    `gorm:"type:varchar(100)"`
}
