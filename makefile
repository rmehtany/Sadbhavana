SHELL := /bin/bash
.PHONY: db_gen migration

db_gen:
	cd pkgs && sqlc generate

migration:
	cd pkgs/db/migrations && goose create $(name) sql