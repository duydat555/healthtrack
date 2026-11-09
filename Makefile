-include .env
export

.PHONY: setup up down logs migrate seed backup test lint mobile-setup mobile mobile-dev mobile-test mobile-lint

## ---------- Backend (Docker) ----------
setup: ## Lần đầu: tạo .env và build image backend
	@test -f .env || cp .env.example .env
	docker compose build

up: ## Chạy db, backend, adminer
	docker compose up -d
	@echo "API:     http://localhost:$${BACKEND_PORT:-8000}/docs"
	@echo "Adminer: http://localhost:$${ADMINER_PORT:-8080}"

down:
	docker compose down

logs:
	docker compose logs -f backend

migrate: ## Tạo migration: make migrate m="them bang users"
	docker compose exec backend alembic revision --autogenerate -m "$(m)"
	docker compose exec backend alembic upgrade head

seed: ## Nạp dữ liệu demo (tài khoản demo@healthtrack.example / demo12345)
	docker compose exec backend python -m app.seed

backup: ## Sao lưu CSDL ra backups/healthtrack-<thời gian>.sql
	@mkdir -p backups
	docker compose exec -T db pg_dump -U healthtrack healthtrack > backups/healthtrack-$$(date +%Y%m%d-%H%M%S).sql
	@echo "Đã sao lưu vào thư mục backups/"

test: ## Test backend
	docker compose exec backend pytest -q

lint:
	docker compose exec backend ruff check .

## ---------- Mobile (Flutter, chạy trực tiếp trên Mac) ----------
mobile-setup: ## Cài package Flutter (plugin iOS dùng Swift Package Manager, không cần pod install)
	cd mobile && flutter pub get

mobile: ## Chạy app trên iOS Simulator đang mở
	open -a Simulator
	cd mobile && flutter run --dart-define=API_URL=http://localhost:$${BACKEND_PORT:-8000}/api/v1

DEVICE ?= iPhone 13
mobile-dev: ## Chạy app trên Simulator và tự hot reload khi lưu file Dart
	./scripts/dev-mobile.sh "$(DEVICE)"

mobile-test:
	cd mobile && flutter test
	cd mobile/packages/liquid_glass && flutter test

mobile-lint:
	cd mobile && flutter analyze
	cd mobile/packages/liquid_glass && flutter analyze
