package domain

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// TenantBase สำหรับ Tables ที่ต้องทำการแยกข้อมูลแยกตาม Tenant (Multi-Tenant)
type TenantBase struct {
	ID        uuid.UUID      `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	TenantID  uuid.UUID      `gorm:"type:uuid;not null;index"` // Discriminator Column
	CreatedAt time.Time      `gorm:"not null;default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time      `gorm:"not null;default:CURRENT_TIMESTAMP"`
	DeletedAt gorm.DeletedAt `gorm:"index"`
}

// GlobalBase สำหรับ Tables ส่วนกลางของระบบ ไม่แยกตาม Tenant
type GlobalBase struct {
	ID        uuid.UUID      `gorm:"type:uuid;primaryKey;default:gen_random_uuid()"`
	CreatedAt time.Time      `gorm:"not null;default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time      `gorm:"not null;default:CURRENT_TIMESTAMP"`
	DeletedAt gorm.DeletedAt `gorm:"index"`
}
