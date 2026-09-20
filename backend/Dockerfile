FROM alpine:3.20

WORKDIR /app

RUN apk add --no-cache ca-certificates tzdata

COPY server /app/server
COPY web /app/web
RUN chmod +x /app/server

EXPOSE 8080

ENTRYPOINT ["/app/server"]
