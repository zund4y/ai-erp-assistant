package domain

type User struct {
	TenantBase
	Email        string `gorm:"type:varchar(255);not null;index:idx_tenant_email,unique"`
	PasswordHash string `gorm:"type:varchar(255);not null"`
	FirstName    string `gorm:"type:varchar(100);not null"`
	LastName     string `gorm:"type:varchar(100);not null"`
	Status       string `gorm:"type:varchar(50);not null;default:'active'"`
	IsAdmin      bool   `gorm:"not null;default:false"`
	Roles        []Role `gorm:"many2many:user_roles;foreignKey:ID;joinForeignKey:UserID;References:ID;joinReferences:RoleID"`
}
