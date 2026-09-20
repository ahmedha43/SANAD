package domain

import (
	"net/url"
	"strings"
	"time"

	"github.com/google/uuid"
)

// BrowserHistory represents a web browsing record or search query performed on a monitored device
type BrowserHistory struct {
	ID              int64     `gorm:"primaryKey;autoIncrement" json:"id"`
	DeviceID        uuid.UUID `gorm:"type:uuid;not null;index:idx_browser_hist_dev" json:"device_id"`
	Browser         string    `gorm:"type:varchar(50);not null" json:"browser"` // chrome, edge, firefox, samsung, safari
	URL             string    `gorm:"type:text;not null" json:"url"`
	Title           string    `gorm:"type:text" json:"title"`
	Domain          string    `gorm:"type:varchar(255);index:idx_browser_hist_domain" json:"domain"`
	VisitCount      int       `gorm:"default:1" json:"visit_count"`
	DurationSeconds int       `gorm:"default:0" json:"duration_seconds"`
	IsSearch        bool      `gorm:"default:false;index:idx_browser_hist_search" json:"is_search"`
	SearchQuery     string    `gorm:"type:varchar(500);default:''" json:"search_query"`
	SearchEngine    string    `gorm:"type:varchar(50);default:''" json:"search_engine"` // google, youtube, bing, yahoo, duckduckgo
	Category        string    `gorm:"type:varchar(50);default:'general'" json:"category"` // education, entertainment, social, gaming, shopping, adult
	IsBlocked       bool      `gorm:"default:false" json:"is_blocked"`
	VisitTime       time.Time `gorm:"index:idx_browser_hist_time" json:"visit_time"`
	CreatedAt       time.Time `json:"created_at"`
}

// BrowserHistoryPayload represents the incoming batch record from agents (Windows or Android)
type BrowserHistoryPayload struct {
	Browser         string `json:"browser"`
	URL             string `json:"url"`
	Title           string `json:"title"`
	VisitCount      int    `json:"visit_count"`
	DurationSeconds int    `json:"duration_seconds"`
	Timestamp       int64  `json:"timestamp"` // Unix epoch seconds or ms
}

// BrowserHistoryBatchRequest payload for agent POST /agent/:id/browser-history
type BrowserHistoryBatchRequest struct {
	Items []BrowserHistoryPayload `json:"items"`
}

// ExtractDomainAndSearch parses raw URL to determine clean domain and any search query
func ExtractDomainAndSearch(rawURL string) (domain string, isSearch bool, engine string, query string) {
	if rawURL == "" {
		return "", false, "", ""
	}

	parsed, err := url.Parse(rawURL)
	if err != nil {
		return "", false, "", ""
	}

	host := strings.ToLower(parsed.Hostname())
	host = strings.TrimPrefix(host, "www.")
	domain = host

	q := parsed.Query()

	if strings.Contains(host, "google.") && strings.Contains(parsed.Path, "/search") {
		searchParam := q.Get("q")
		if searchParam != "" {
			return domain, true, "google", searchParam
		}
	} else if strings.Contains(host, "youtube.com") && (strings.Contains(parsed.Path, "/results") || strings.Contains(parsed.Path, "/search")) {
		searchParam := q.Get("search_query")
		if searchParam != "" {
			return domain, true, "youtube", searchParam
		}
	} else if strings.Contains(host, "bing.com") && strings.Contains(parsed.Path, "/search") {
		searchParam := q.Get("q")
		if searchParam != "" {
			return domain, true, "bing", searchParam
		}
	} else if strings.Contains(host, "yahoo.com") && strings.Contains(parsed.Path, "/search") {
		searchParam := q.Get("p")
		if searchParam != "" {
			return domain, true, "yahoo", searchParam
		}
	} else if strings.Contains(host, "duckduckgo.com") {
		searchParam := q.Get("q")
		if searchParam != "" {
			return domain, true, "duckduckgo", searchParam
		}
	}

	return domain, false, "", ""
}
