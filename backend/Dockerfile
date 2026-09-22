# Multi-stage Docker build for Go Fiber Backend
FROM golang:1.22-alpine AS builder

WORKDIR /app

RUN apk add --no-cache git ca-certificates

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /app/server cmd/server/main.go

# Minimal runner container
FROM alpine:3.20

WORKDIR /app

RUN apk add --no-cache ca-certificates tzdata

COPY --from=builder /app/server /app/server
COPY web /app/web
RUN chmod +x /app/server

EXPOSE 8080

ENTRYPOINT ["/app/server"]
