package db

import (
	"sadbhavana/tree-project/pkgs/conf"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestDbApiSample_Integration(t *testing.T) {
	ctx := t.Context()
	conf.LoadEnvFromFile("../../.env.test")

	q, err := NewQueries(ctx)
	if err != nil {
		t.Fatalf("failed to create queries: %v", err)
	}

	type testInput struct {
		TestParam string `json:"test_param"`
	}

	type testOutput struct {
		Id   int    `json:"id"`
		Name string `json:"name"`
	}

	input := testInput{
		TestParam: "Hello",
	}

	output, err := callDbApi[testInput, []testOutput](ctx, q, "SampleDbApi", input)
	if err != nil {
		t.Fatalf("failed to call db api: %v", err)
	}

	if len(output) != 3 {
		t.Fatalf("expected 3 results, got %d", len(output))
	}

	assert.Equal(t, 1, output[0].Id)
	assert.Equal(t, "one", output[0].Name)
	assert.Equal(t, 2, output[1].Id)
	assert.Equal(t, "two", output[1].Name)
	assert.Equal(t, 3, output[2].Id)
	assert.Equal(t, "three", output[2].Name)
}
