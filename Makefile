.PHONY: test lint shellcheck
test:
	docker compose run --rm tests

lint:
	docker compose run --rm lint

shellcheck:
	docker compose run --rm shellcheck
