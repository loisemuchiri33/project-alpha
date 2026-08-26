FROM golang:1.22-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git ca-certificates
COPY go.mod go.sum* ./
RUN go mod download || true
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /zeni-api ./cmd/api/

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
ENV TZ=Africa/Nairobi
WORKDIR /app
COPY --from=builder /zeni-api .
COPY migrations ./migrations
EXPOSE 8080
USER nobody
CMD ["./zeni-api"]
