package html

import (
	"bytes"
	"context"
	"fmt"
	"mime/multipart"
	"reflect"
	"strconv"

	"github.com/a-h/templ"
)

type HTMLResponse struct {
	Body        []byte
	ContentType string
}

func CreateHTMLResponse(ctx context.Context, component templ.Component) (*HTMLResponse, error) {
	htmlBytes, err := renderTemplToBytes(ctx, component)
	if err != nil {
		return nil, fmt.Errorf("failed to render template: %w", err)
	}

	return &HTMLResponse{
		ContentType: "text/html; charset=utf-8",
		Body:        htmlBytes,
	}, nil
}

func renderTemplToBytes(ctx context.Context, component templ.Component) ([]byte, error) {
	var buf bytes.Buffer

	err := component.Render(ctx, &buf)
	if err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

// ParseForm parses a multipart.Form into a struct of type T
// Returns the parsed struct and an error if parsing fails
func ParseForm[T any](rawBody *multipart.Form) (*T, error) {
	var result T
	resultValue := reflect.ValueOf(&result).Elem()
	resultType := resultValue.Type()

	// Iterate through all struct fields
	for i := 0; i < resultType.NumField(); i++ {
		field := resultType.Field(i)
		fieldValue := resultValue.Field(i)

		// Skip unexported fields
		if !fieldValue.CanSet() {
			continue
		}

		// Get the form tag or use field name
		fieldName := field.Tag.Get("form")
		if fieldName == "" {
			fieldName = field.Name
		}

		// Get values from the form
		values, exists := rawBody.Value[fieldName]
		if !exists || len(values) == 0 {
			continue
		}

		// Parse based on field type
		switch fieldValue.Kind() {
		case reflect.String:
			fieldValue.SetString(values[0])

		case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
			intVal, err := strconv.ParseInt(values[0], 10, 64)
			if err != nil {
				return nil, fmt.Errorf("failed to parse int for field %s: %w", fieldName, err)
			}
			fieldValue.SetInt(intVal)

		case reflect.Float32, reflect.Float64:
			floatVal, err := strconv.ParseFloat(values[0], 64)
			if err != nil {
				return nil, fmt.Errorf("failed to parse float for field %s: %w", fieldName, err)
			}
			fieldValue.SetFloat(floatVal)

		case reflect.Slice:
			if err := parseSlice(fieldValue, values, fieldName); err != nil {
				return nil, err
			}

		default:
			return nil, fmt.Errorf("unsupported field type: %s for field %s", fieldValue.Kind(), fieldName)
		}
	}

	return &result, nil
}

// parseSlice handles slice parsing for []string, []int, and []float
func parseSlice(fieldValue reflect.Value, values []string, fieldName string) error {
	elemType := fieldValue.Type().Elem()

	switch elemType.Kind() {
	case reflect.String:
		fieldValue.Set(reflect.ValueOf(values))

	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		intSlice := make([]int, len(values))
		for j, v := range values {
			intVal, err := strconv.Atoi(v)
			if err != nil {
				return fmt.Errorf("failed to parse int slice for field %s at index %d: %w", fieldName, j, err)
			}
			intSlice[j] = intVal
		}
		fieldValue.Set(reflect.ValueOf(intSlice))

	case reflect.Float32, reflect.Float64:
		floatSlice := make([]float64, len(values))
		for j, v := range values {
			floatVal, err := strconv.ParseFloat(v, 64)
			if err != nil {
				return fmt.Errorf("failed to parse float slice for field %s at index %d: %w", fieldName, j, err)
			}
			floatSlice[j] = floatVal
		}
		fieldValue.Set(reflect.ValueOf(floatSlice))

	default:
		return fmt.Errorf("unsupported slice element type: %s for field %s", elemType.Kind(), fieldName)
	}

	return nil
}
