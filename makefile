.PHONY: db_gen

db_gen:
	cd pkgs && sqlc generate

migration:
	cd pkgs/db/migrations && goose create $(name) sql