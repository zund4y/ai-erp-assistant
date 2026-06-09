package main

import (
	"log"

	"backend-erp/config"
	"backend-erp/internal/pkg/database"

	"github.com/gofiber/fiber/v2"
)

func main() {
	// 1. โหลด Configuration
	cfg := config.LoadConfig()

	// 2. เริ่มต้นเชื่อมต่อ Database และรัน GORM Mapping
	_, err := database.NewPostgresConnection(cfg)
	if err != nil {
		log.Fatalf("Critical Error: %v", err)
	}

	// 3. เริ่มต้นระบบ Web Server (Fiber)
	app := fiber.New(fiber.Config{
		AppName: "SaaS ERP Assistant - Core API v1.0",
	})

	// Health Check Endpoint
	app.Get("/health", func(c *fiber.Ctx) error {
		return c.Status(fiber.StatusOK).JSON(fiber.Map{
			"status":  "healthy",
			"service": "erp-core",
		})
	})

	// สตาร์ท API เซิร์ฟเวอร์ที่พอร์ต 8080
	log.Println("Starting ERP Core Service on port :8080...")
	if err := app.Listen(":8080"); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
