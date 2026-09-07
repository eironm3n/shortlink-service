.PHONY: install dev test lint fmt docker up down clean

install:
	python -m venv .venv && .venv/bin/pip install -r requirements-dev.txt

dev:
	uvicorn app.main:app --reload

test:
	pytest

lint:
	ruff check .
	ruff format --check .
	mypy app

fmt:
	ruff check --fix .
	ruff format .

docker:
	docker build -t shortlink-service:local .

up:
	docker compose up --build

down:
	docker compose down

clean:
	rm -rf .venv .pytest_cache .ruff_cache .mypy_cache **/__pycache__ *.db .coverage
