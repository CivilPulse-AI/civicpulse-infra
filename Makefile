PROTO_DIR := proto
SERVER_DIR := ../civicpulse-server
AI_DIR := ../civicpulse-ai-service
TEL_DIR := ../civicpulse-telephony-service
PYTHON := $(if $(wildcard .venv/bin/python3),.venv/bin/python3,python3)

.PHONY: proto proto-go proto-python up down logs local local-api local-down demo-on demo-off demo-status

proto: proto-go proto-python

proto-go:
	mkdir -p $(SERVER_DIR)/internal/pb
	PATH="$(CURDIR)/.tools:$(PATH)" protoc -I $(PROTO_DIR) \
		--go_out=$(SERVER_DIR) --go_opt=module=github.com/CivilPulse-AI/civicpulse-server \
		--go-grpc_out=$(SERVER_DIR) --go-grpc_opt=module=github.com/CivilPulse-AI/civicpulse-server \
		$(PROTO_DIR)/ai/v1/*.proto $(PROTO_DIR)/core/v1/*.proto

proto-python:
	mkdir -p $(AI_DIR)/app/pb $(TEL_DIR)/app/pb
	$(PYTHON) -m grpc_tools.protoc -I $(PROTO_DIR) \
		--python_out=$(AI_DIR)/app/pb --grpc_python_out=$(AI_DIR)/app/pb \
		$(PROTO_DIR)/ai/v1/*.proto
	$(PYTHON) -m grpc_tools.protoc -I $(PROTO_DIR) \
		--python_out=$(TEL_DIR)/app/pb --grpc_python_out=$(TEL_DIR)/app/pb \
		$(PROTO_DIR)/core/v1/*.proto
	touch $(AI_DIR)/app/pb/__init__.py $(AI_DIR)/app/pb/ai/__init__.py $(AI_DIR)/app/pb/ai/v1/__init__.py
	touch $(TEL_DIR)/app/pb/__init__.py $(TEL_DIR)/app/pb/core/__init__.py $(TEL_DIR)/app/pb/core/v1/__init__.py

up:
	docker compose up --build

down:
	docker compose down

logs:
	docker compose logs -f

local:
	./scripts/local-up.sh

local-api:
	NO_PORTAL=1 ./scripts/local-up.sh

local-down:
	./scripts/local-down.sh

demo-on:
	./scripts/demo.sh on

demo-off:
	./scripts/demo.sh off

demo-status:
	./scripts/demo.sh status
