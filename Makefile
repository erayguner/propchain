# Property Upkeep Records - Development Environment
.PHONY: help build up down restart logs clean test seed-data reset-db

# Colors for terminal output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Property Upkeep Records - Local Development Environment$(NC)"
	@echo ""
	@echo "$(GREEN)Available commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

build: ## Build all containers
	@echo "$(BLUE)Building containers...$(NC)"
	docker-compose -f docker-compose.local.yml build

up: ## Start all services
	@echo "$(BLUE)Starting local development environment...$(NC)"
	docker-compose -f docker-compose.local.yml up -d
	@echo "$(GREEN)Services starting up...$(NC)"
	@echo "Frontend: http://localhost:3001"
	@echo "API: http://localhost:3000"
	@echo "Auth Mock: http://localhost:3002"
	@echo "Grafana: http://localhost:3003 (admin/admin123)"
	@echo "Prometheus: http://localhost:9090"
	@echo "Adminer: http://localhost:8080"
	@echo "MailCatcher: http://localhost:1080"
	@echo "MinIO Console: http://localhost:9001 (minioadmin/minioadmin123)"

down: ## Stop all services
	@echo "$(BLUE)Stopping all services...$(NC)"
	docker-compose -f docker-compose.local.yml down

restart: down up ## Restart all services

logs: ## Show logs for all services
	docker-compose -f docker-compose.local.yml logs -f

logs-api: ## Show API server logs
	docker-compose -f docker-compose.local.yml logs -f api_server

logs-worker: ## Show worker logs
	docker-compose -f docker-compose.local.yml logs -f worker

logs-db: ## Show database logs
	docker-compose -f docker-compose.local.yml logs -f postgres

clean: ## Remove all containers, volumes, and images
	@echo "$(RED)Cleaning up all containers, volumes, and images...$(NC)"
	docker-compose -f docker-compose.local.yml down -v --remove-orphans
	docker system prune -f
	docker volume prune -f

reset-db: ## Reset database with fresh schema and seed data
	@echo "$(YELLOW)Resetting database...$(NC)"
	docker-compose -f docker-compose.local.yml exec -T -e PGPASSWORD=dev_password_123 postgres psql -U propchain -d propchain_dev -c "DROP SCHEMA IF EXISTS propchain CASCADE; CREATE SCHEMA propchain;"
	$(MAKE) seed-data

seed-data: ## Load test data into database
	@echo "$(BLUE)Loading seed data...$(NC)"
	docker-compose -f docker-compose.local.yml exec -T -e PGPASSWORD=dev_password_123 postgres psql -U propchain -d propchain_dev < database/seed/01_schema.sql
	docker-compose -f docker-compose.local.yml exec -T -e PGPASSWORD=dev_password_123 postgres psql -U propchain -d propchain_dev < database/seed/02_test_data.sql
	@echo "$(GREEN)Seed data loaded successfully$(NC)"

test: ## Run all tests
	@echo "$(BLUE)Running tests...$(NC)"
	docker-compose -f docker-compose.local.yml exec api_server npm test

test-api: ## Run API tests
	docker-compose -f docker-compose.local.yml exec api_server npm run test:api

test-integration: ## Run integration tests
	docker-compose -f docker-compose.local.yml exec api_server npm run test:integration

shell-api: ## Open shell in API container
	docker-compose -f docker-compose.local.yml exec api_server sh

shell-db: ## Open PostgreSQL shell
	docker-compose -f docker-compose.local.yml exec -e PGPASSWORD=dev_password_123 postgres psql -U propchain -d propchain_dev

shell-worker: ## Open shell in worker container
	docker-compose -f docker-compose.local.yml exec worker sh

setup-local: ## Initial setup of local environment
	@echo "$(BLUE)Setting up local development environment...$(NC)"
	@if [ ! -f .env.local ]; then cp .env.example .env.local; fi
	$(MAKE) build
	$(MAKE) up
	@echo "$(YELLOW)Waiting for services to start...$(NC)"
	sleep 30
	$(MAKE) setup-localstack
	$(MAKE) seed-data
	@echo "$(GREEN)Local development environment ready!$(NC)"

setup-localstack: ## Configure LocalStack resources
	@echo "$(BLUE)Setting up LocalStack resources...$(NC)"
	# Create S3 bucket
	docker-compose -f docker-compose.local.yml exec localstack awslocal s3 mb s3://propchain-dev-documents
	# Create SQS queue
	docker-compose -f docker-compose.local.yml exec localstack awslocal sqs create-queue --queue-name propchain-dev-tasks
	# Create DLQ
	docker-compose -f docker-compose.local.yml exec localstack awslocal sqs create-queue --queue-name propchain-dev-dlq
	@echo "$(GREEN)LocalStack resources created$(NC)"

health: ## Check health of all services
	@echo "$(BLUE)Checking service health...$(NC)"
	@docker-compose -f docker-compose.local.yml ps

status: ## Show status of all services
	@docker-compose -f docker-compose.local.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

install-deps: ## Install dependencies in all services
	@echo "$(BLUE)Installing dependencies...$(NC)"
	docker-compose -f docker-compose.local.yml exec api_server npm install
	docker-compose -f docker-compose.local.yml exec frontend npm install

dev-api: ## Start API in development mode with hot reload
	docker-compose -f docker-compose.local.yml exec api_server npm run dev

dev-frontend: ## Start frontend in development mode
	docker-compose -f docker-compose.local.yml exec frontend npm start

benchmark: ## Run performance benchmarks
	@echo "$(BLUE)Running benchmarks...$(NC)"
	docker-compose -f docker-compose.local.yml exec api_server npm run benchmark

backup-db: ## Create database backup
	@echo "$(BLUE)Creating database backup...$(NC)"
	mkdir -p backups
	docker-compose -f docker-compose.local.yml exec postgres pg_dump -U propchain propchain_dev > backups/backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)Database backup created in backups/ directory$(NC)"

restore-db: ## Restore database from backup (usage: make restore-db BACKUP=backup_file.sql)
	@echo "$(BLUE)Restoring database from $(BACKUP)...$(NC)"
	docker-compose -f docker-compose.local.yml exec -T postgres psql -U propchain -d propchain_dev < backups/$(BACKUP)
	@echo "$(GREEN)Database restored from $(BACKUP)$(NC)"

monitor: ## Open monitoring dashboard
	@echo "$(BLUE)Opening monitoring dashboards...$(NC)"
	@echo "Grafana: http://localhost:3003"
	@echo "Prometheus: http://localhost:9090"
	@if command -v open >/dev/null 2>&1; then \
		open http://localhost:3003; \
		open http://localhost:9090; \
	fi

docs: ## Generate API documentation
	docker-compose -f docker-compose.local.yml exec api_server npm run docs

curl-test: ## Test API endpoints with curl
	@echo "$(BLUE)Testing API endpoints...$(NC)"
	@echo "Health check:"
	curl -s http://localhost:3000/health | jq .
	@echo "\nAPI info:"
	curl -s http://localhost:3000/api/v1/info | jq .

load-test: ## Run load tests against local API
	@echo "$(BLUE)Running load tests...$(NC)"
	docker run --rm --network propchain_network \
		grafana/k6 run --vus 10 --duration 30s - <<< \
		'import http from "k6/http"; export default function() { http.get("http://propchain_nginx/api/v1/health"); }'

full-reset: ## Complete environment reset
	@echo "$(RED)Performing full reset...$(NC)"
	$(MAKE) down
	docker system prune -af
	docker volume prune -f
	$(MAKE) setup-local