package db

import (
	"context"
	"fmt"
	"sadbhavana/tree-project/pkgs/utils"
	"strings"
)

func callProcedureWithJSON[I, O any](ctx context.Context, q *Queries, schemaName, procedureName string, input I) (O, error) {
	type inputWrapper struct {
		SchemaName  string `json:"schema_name" validate:"required"`
		HandlerName string `json:"handler_name" validate:"required"`
		Request     I      `json:"request" validate:"required"`
	}

	if schemaName == "" {
		schemaName = "public"
	}

	wrappedInput := inputWrapper{
		SchemaName:  strings.ToLower(schemaName),
		HandlerName: strings.ToLower(procedureName),
		Request:     input,
	}

	err := utils.ValidateStruct(wrappedInput)

	type outputWrapper struct {
		Response O `json:"response" validate:"required"`
	}

	var output outputWrapper

	if err != nil {
		return output.Response, fmt.Errorf("failed to validate input for procedure %s.%s: %w", schemaName, procedureName, err)
	}

	err = q.db.QueryRow(ctx, "CALL core.P_Envelope($1::jsonb, NULL);", wrappedInput).Scan(&output)
	if err != nil {
		return output.Response, fmt.Errorf("failed to call procedure %s.%s: %w", schemaName, procedureName, err)
	}

	err = utils.ValidateStruct(output)
	if err != nil {
		return output.Response, fmt.Errorf("failed to validate output for procedure %s.%s: %w", schemaName, procedureName, err)
	}

	return output.Response, nil
}
