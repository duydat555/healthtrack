-include .env
export

.PHONY: setup up down logs migrate test lint mobile-setup mobile mobile-test mobile-lint

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

test: ## Test backend
	docker compose exec backend pytest -q

lint:
	docker compose exec backend ruff check .

## ---------- Mobile (Flutter, chạy trực tiếp trên Mac) ----------
mobile-setup: ## Cài package Flutter và CocoaPods
	cd mobile && flutter pub get
	cd mobile/ios && pod install

mobile: ## Chạy app trên iOS Simulator đang mở
	open -a Simulator
	cd mobile && flutter run --dart-define=API_URL=http://localhost:$${BACKEND_PORT:-8000}/api/v1

mobile-test:
	cd mobile && flutter test
	cd mobile/packages/liquid_glass && flutter test

mobile-lint:
	cd mobile && flutter analyze
	cd mobile/packages/liquid_glass && flutter analyze
