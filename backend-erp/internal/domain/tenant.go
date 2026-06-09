package domain

type Tenant struct {
	GlobalBase
	Name         string `gorm:"type:varchar(255);not null"`
	Domain       string `gorm:"type:varchar(255);uniqueIndex;not null"`
	Status       string `gorm:"type:varchar(50);not null;default:'active'"`
	Subscription string `gorm:"type:varchar(50);not null;default:'free'"`
	Users        []User `gorm:"foreignKey:TenantID"`
}
