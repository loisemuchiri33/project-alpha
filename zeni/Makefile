
.PHONY: up down api worker test tidy logs

up:
	docker compose up -d

down:
	docker compose down

api:
	cd backend && go run ./cmd/api/

worker:
	cd backend && go run ./cmd/worker/

test:
	cd backend && go test ./...

tidy:
	cd backend && go mod tidy

logs:
	docker compose logs -f
