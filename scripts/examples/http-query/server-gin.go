package main

// HTTP QUERY server — Go + Gin (RFC 10008)
// Gin supports custom HTTP methods via router.Handle()
// Run: go run server-gin.go

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// MethodQuery — string constant until net/http adds MethodQuery (proposal #80058)
const MethodQuery = "QUERY"

func main() {
	r := gin.Default()

	// Gin supports custom HTTP methods via Handle()
	r.Handle(MethodQuery, "/search", func(c *gin.Context) {
		var body map[string]interface{}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid JSON body"})
			return
		}
		c.Header("Accept-Query", "application/json")
		c.JSON(http.StatusOK, gin.H{
			"results": []interface{}{},
			"query":   body,
		})
	})

	r.GET("/search", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "Use QUERY method with JSON body to search",
		})
	})

	r.Run(":8080")
}
