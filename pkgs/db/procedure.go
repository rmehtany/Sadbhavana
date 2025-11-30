package db

import (
	"context"
	"fmt"
	"sadbhavana/tree-project/pkgs/utils"
	"strings"

	"github.com/jackc/pgx/v5"
)

func callProcedureWithJSON[I, O any](ctx context.Context, q *Queries, procedureName string, input I) (O, error) {
	var output O
	err := utils.ValidateStruct(input)
	if err != nil {
		return output, fmt.Errorf("failed to validate input for procedure %s: %w", procedureName, err)
	}

	query := fmt.Sprintf("CALL %s($1::jsonb, NULL);", pgx.Identifier{strings.ToLower(procedureName)}.Sanitize())

	err = q.db.QueryRow(ctx, query, input).Scan(&output)
	if err != nil {
		return output, fmt.Errorf("failed to call procedure %s: %w", procedureName, err)
	}

	err = utils.ValidateStruct(output)
	if err != nil {
		return output, fmt.Errorf("failed to validate output for procedure %s: %w", procedureName, err)
	}

	return output, nil
}
