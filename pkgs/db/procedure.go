package db

import (
	"context"
	"fmt"
	"sadbhavana/tree-project/pkgs/utils"
	"strings"

	"github.com/jackc/pgx/v5"
)

func callProcedureWithJSON[I, O any](ctx context.Context, q *Queries, schemaName string, procedureName string, input I) (O, error) {
	var output O
	err := utils.ValidateStruct(input)
	if err != nil {
		return output, fmt.Errorf("failed to validate input for procedure %s.%s: %w", schemaName, procedureName, err)
	}

	if schemaName == "" {
		schemaName = "public"
	}

	sanitizedSchemaName := pgx.Identifier{strings.ToLower(schemaName)}.Sanitize()
	sanitizedProcedureName := pgx.Identifier{strings.ToLower(procedureName)}.Sanitize()

	query := fmt.Sprintf("CALL %s.%s($1::jsonb, NULL);", sanitizedSchemaName, sanitizedProcedureName)

	err = q.db.QueryRow(ctx, query, input).Scan(&output)
	if err != nil {
		return output, fmt.Errorf("failed to call procedure %s.%s: %w", schemaName, procedureName, err)
	}

	err = utils.ValidateStruct(output)
	if err != nil {
		return output, fmt.Errorf("failed to validate output for procedure %s.%s: %w", schemaName, procedureName, err)
	}

	return output, nil
}
