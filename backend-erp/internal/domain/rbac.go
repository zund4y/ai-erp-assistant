package domain

import "github.com/google/uuid"

type Role struct {
	TenantBase
	Name        string       `gorm:"type:varchar(100);not null;index:idx_tenant_role_name,unique"`
	Description string       `gorm:"type:text"`
	Permissions []Permission `gorm:"many2many:role_permissions;foreignKey:ID;joinForeignKey:RoleID;References:ID;joinReferences:PermissionID"`
}

type Permission struct {
	GlobalBase
	Module      string `gorm:"type:varchar(100);not null;index:idx_mod_act"`
	Action      string `gorm:"type:varchar(100);not null;index:idx_mod_act"`
	Description string `gorm:"type:text"`
}

// Explicit Join Tables เพื่อควบคุม Multi-Tenancy ในความสัมพันธ์แบบ Many-to-Many
type UserRole struct {
	TenantID uuid.UUID `gorm:"type:uuid;not null;index"`
	UserID   uuid.UUID `gorm:"type:uuid;primaryKey"`
	RoleID   uuid.UUID `gorm:"type:uuid;primaryKey"`
}

type RolePermission struct {
	TenantID     uuid.UUID `gorm:"type:uuid;not null;index"`
	RoleID       uuid.UUID `gorm:"type:uuid;primaryKey"`
	PermissionID uuid.UUID `gorm:"type:uuid;primaryKey"`
}
