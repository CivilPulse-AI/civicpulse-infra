PROTO_DIR := proto
SERVER_DIR := ../civicpulse-server
AI_DIR := ../civicpulse-ai-service
TEL_DIR := ../civicpulse-telephony-service

.PHONY: proto proto-go proto-python up down logs

proto: proto-go proto-python

proto-go:
	mkdir -p $(SERVER_DIR)/internal/pb
	protoc -I $(PROTO_DIR) \
		--go_out=$(SERVER_DIR) --go_opt=module=github.com/CivilPulse-AI/civicpulse-server \
		--go-grpc_out=$(SERVER_DIR) --go-grpc_opt=module=github.com/CivilPulse-AI/civicpulse-server \
		$(PROTO_DIR)/ai/v1/ai.proto $(PROTO_DIR)/core/v1/core.proto

proto-python:
	mkdir -p $(AI_DIR)/app/pb $(TEL_DIR)/app/pb
	python3 -m grpc_tools.protoc -I $(PROTO_DIR) \
		--python_out=$(AI_DIR)/app/pb --grpc_python_out=$(AI_DIR)/app/pb \
		$(PROTO_DIR)/ai/v1/ai.proto
	python3 -m grpc_tools.protoc -I $(PROTO_DIR) \
		--python_out=$(TEL_DIR)/app/pb --grpc_python_out=$(TEL_DIR)/app/pb \
		$(PROTO_DIR)/core/v1/core.proto
	touch $(AI_DIR)/app/pb/__init__.py $(AI_DIR)/app/pb/ai/__init__.py $(AI_DIR)/app/pb/ai/v1/__init__.py
	touch $(TEL_DIR)/app/pb/__init__.py $(TEL_DIR)/app/pb/core/__init__.py $(TEL_DIR)/app/pb/core/v1/__init__.py

up:
	docker compose up --build

down:
	docker compose down

logs:
	docker compose logs -f
