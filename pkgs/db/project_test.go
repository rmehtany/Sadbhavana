package db

import (
	"sadbhavana/tree-project/pkgs/conf"
	"strconv"
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

func TestDbApiProjectLifecycle_Integration(t *testing.T) {
	ctx := t.Context()
	conf.LoadEnvFromFile("../../.env.test")

	q, err := NewQueries(ctx)
	if err != nil {
		t.Fatalf("failed to create queries: %v", err)
	}

	// 1. Save - Create new projects
	saveInput := []SaveProjectInput{
		{
			ProjectId:      "TEST_PROJ_1",
			ProjectName:    "Test Forest One",
			TreeCntPledged: 100,
			TreeCntPlanted: 0,
			Latitude:       10.0,
			Longitude:      20.0,
		},
		{
			ProjectId:      "TEST_PROJ_2",
			ProjectName:    "Test Forest Two",
			TreeCntPledged: 200,
			TreeCntPlanted: 50,
			Latitude:       30.0,
			Longitude:      40.0,
		},
	}

	savedProjects, err := callDbApi[[]SaveProjectInput, []DbProject](ctx, q, "SaveProject", saveInput)
	if err != nil {
		t.Fatalf("failed to save projects: %v", err)
	}

	if len(savedProjects) != 2 {
		t.Fatalf("expected 2 projects saved, got %d", len(savedProjects))
	}

	// 2. Get - Verify created projects can be found
	getInput := GetProjectInput{
		ProjectPattern: "Test Forest",
	}

	foundProjects, err := callDbApi[GetProjectInput, []DbProject](ctx, q, "GetProject", getInput)
	if err != nil {
		t.Fatalf("failed to get projects: %v", err)
	}

	// Verify we found at least our 2 new projects
	count := 0
	for _, p := range foundProjects {
		if p.ProjectId == "TEST_PROJ_1" || p.ProjectId == "TEST_PROJ_2" {
			count++
		}
	}
	if count < 2 {
		t.Fatalf("expected to find at least 2 test projects, found %d", count)
	}

	// 3. Delete - Clean up the created projects
	deleteInput := DeleteProjectRequest{
		Cascade:  false,
		Projects: make([]DeleteProjectInput, len(savedProjects)),
	}
	for i, p := range savedProjects {
		deleteInput.Projects[i] = DeleteProjectInput{
			ProjectIdn: strconv.Itoa(p.ProjectIdn),
		}
	}

	deletedProjects, err := DeleteProject(ctx, q, deleteInput)
	if err != nil {
		t.Fatalf("failed to delete projects: %v", err)
	}

	if len(deletedProjects) < 2 {
		t.Fatalf("expected at least 2 projects deleted, got %d", len(deletedProjects))
	}
	t.Logf("lifecycle test passed: saved, found, and deleted %d projects", len(deletedProjects))
}
