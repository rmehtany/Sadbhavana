package db

import (
	"sadbhavana/tree-project/pkgs/conf"
	"testing"
)

func TestDbApiGetProject_Integration(t *testing.T) {
	ctx := t.Context()
	conf.LoadEnvFromFile("../../.env.test")

	q, err := NewQueries(ctx)
	if err != nil {
		t.Fatalf("failed to create queries: %v", err)
	}

	input := GetProjectInput{
		ProjectPattern: "PROJ001",
	}

	output, err := callDbApi[GetProjectInput, []DbProject](ctx, q, "GetProject", input)
	if err != nil {
		t.Fatalf("failed to call db api: %v", err)
	}

	if len(output) >= 0 {
		t.Logf("got %d projects", len(output))
	}
}

func TestDbApiSaveProject_Integration(t *testing.T) {
	ctx := t.Context()
	conf.LoadEnvFromFile("../../.env.test")

	q, err := NewQueries(ctx)
	if err != nil {
		t.Fatalf("failed to create queries: %v", err)
	}

	input := []SaveProjectInput{
		{
			ProjectIdn:     6,
			ProjectId:      "PROJ001",
			ProjectName:    "Forest Restoration Alpha",
			TreeCntPledged: 1000,
			TreeCntPlanted: 500,
			Latitude:       40.7128,
			Longitude:      -74.0060,
		},
		{
			ProjectIdn:     7,
			ProjectId:      "PROJ002",
			ProjectName:    "Coastal Mangrove Initiative-edit",
			TreeCntPledged: 2000,
			TreeCntPlanted: 750,
			Latitude:       25.7617,
			Longitude:      -80.1918,
		},
	}

	output, err := callDbApi[[]SaveProjectInput, []DbProject](ctx, q, "SaveProject", input)
	if err != nil {
		t.Fatalf("failed to call db api: %v", err)
	}

	if len(output) >= 0 {
		t.Logf("saved %d projects", len(output))
	}
}

func TestDbApiDeleteProject_Integration(t *testing.T) {
	ctx := t.Context()
	conf.LoadEnvFromFile("../../.env.test")

	q, err := NewQueries(ctx)
	if err != nil {
		t.Fatalf("failed to create queries: %v", err)
	}

	input := []DeleteProjectInput{
		{
			ProjectIdn: "6",
		},
		{
			ProjectIdn: "7",
		},
	}

	output, err := callDbApi[[]DeleteProjectInput, []DbProject](ctx, q, "DeleteProject", input)
	if err != nil {
		t.Fatalf("failed to call db api: %v", err)
	}

	if len(output) >= 0 {
		t.Logf("deleted %d projects", len(output))
	}
}
