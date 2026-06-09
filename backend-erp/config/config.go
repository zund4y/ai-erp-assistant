package config

import (
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	DBHost     string
	DBUser     string
	DBPassword string
	DBName     string
	DBPort     string
	DBSSLMode  string
	JWTSecret  string
}

func LoadConfig() *Config {
	// ถอยหลัง 1 ชั้นไปหา Root Folder เพื่ออ่านไฟล์ .env ตัวจริงที่เพิ่งเปลี่ยนชื่อ
	_ = godotenv.Load("../.env")

	return &Config{
		DBHost:     getEnv("DB_HOST", "127.0.0.1"),
		DBUser:     getEnv("DB_USER", "admin_erp"),  // ปรับตามรูป .env ของคุณ
		DBPassword: getEnv("DB_PASSWORD", "kalonz"), // ปรับตามรูป .env ของคุณ
		DBName:     getEnv("DB_NAME", "erpdb"),      // ปรับให้ตรงกับ POSTGRES_DB ใน docker-compose
		DBPort:     getEnv("DB_PORT", "5432"),
		DBSSLMode:  getEnv("DB_SSLMODE", "disable"),
		JWTSecret:  getEnv("JWT_SECRET", "your-super-secret-key"),
	}
}

func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}
