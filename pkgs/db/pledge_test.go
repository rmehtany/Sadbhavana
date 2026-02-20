package db

import (
	"encoding/json"
	"fmt"
	"sadbhavana/tree-project/pkgs/conf"
	"strconv"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestDbApiPledgeLifecycle_Integration(t *testing.T) {
	ctx := t.Context()
	conf.LoadEnvFromFile("../../.env.test")

	q, err := NewQueries(ctx)
	if err != nil {
		t.Fatalf("failed to create queries: %v", err)
	}

	// 0. Setup - Create a project and a donor for the pledge
	projectInput := []SaveProjectInput{
		{
			ProjectId:   "TEST-PROJ-PLEDGE",
			ProjectName: "Test Project for Pledge",
			Latitude:    12.9716,
			Longitude:   77.5946,
			StartDt:     "2026-01-01",
		},
	}
	fmt.Println("Setup: Creating project...")
	savedProjects, err := SaveProject(ctx, q, projectInput)
	if err != nil {
		fmt.Printf("SaveProject failed: %v\n", err)
		t.Fatalf("failed to save project: %v", err)
	}
	project := savedProjects[0]
	fmt.Printf("Setup: Created project %d\n", project.ProjectIdn)

	fmt.Println("Setup: Creating donor...")
	donorInput := []SaveDonorInput{
		{
			DonorName:    "Test Donor for Pledge",
			MobileNumber: "+91-8888888888",
			City:         "Test City",
			Country:      "India",
			EmailAddr:    "test-pledge@example.com",
			BirthDt:      "1990-01-01",
		},
	}
	savedDonors, err := SaveDonor(ctx, q, donorInput)
	if err != nil {
		fmt.Printf("SaveDonor failed: %v\n", err)
		t.Fatalf("failed to save donor: %v", err)
	}
	donor := savedDonors[0]
	fmt.Printf("Setup: Created donor %d\n", donor.DonorIdn)

	// Cleanup dependencies at the end
	defer func() {
		// Cleanup Project
		DeleteProject(ctx, q, DeleteProjectRequest{
			Cascade: true,
			Projects: []DeleteProjectInput{
				{ProjectIdn: strconv.Itoa(project.ProjectIdn)},
			},
		})
		// Cleanup Donor
		DeleteDonor(ctx, q, DeleteDonorRequest{
			Cascade: true,
			Donors: []DeleteDonorInput{
				{DonorIdn: donor.DonorIdn},
			},
		})
	}()

	fmt.Println("1. Save: Creating pledge...")
	saveInput := []SavePledgeInput{
		{
			ProjectIdn:     project.ProjectIdn,
			DonorIdn:       donor.DonorIdn,
			TreeCntPledged: 100,
			TreeCntPlanted: 0,
		},
	}

	savedPledges, err := SavePledge(ctx, q, saveInput)
	if err != nil {
		fmt.Printf("SavePledge failed: %v\n", err)
		t.Fatalf("failed to save pledges: %v", err)
	}
	fmt.Printf("1. Save: Created %d pledges\n", len(savedPledges))

	if len(savedPledges) != 1 {
		t.Fatalf("expected 1 pledge saved, got %d", len(savedPledges))
	}

	// 2. Get - Verify created pledge can be found
	fmt.Println("2. Get: Finding pledge...")
	getInput := GetPledgeInput{
		DonorIdn: donor.DonorIdn,
	}

	foundPledges, err := GetPledge(ctx, q, getInput)
	if err != nil {
		fmt.Printf("GetPledge failed: %v\n", err)
		t.Fatalf("failed to get pledges: %v", err)
	}
	fmt.Printf("2. Get: Found %d pledges\n", len(foundPledges))

	assert.Equal(t, 1, len(foundPledges))
	assert.Equal(t, 100, foundPledges[0].TreeCntPledged)

	// 3. Delete - Clean up the created pledges
	deleteInput := DeletePledgeRequest{
		Cascade: false,
		Pledges: make([]DeletePledgeInput, len(savedPledges)),
	}
	for i, p := range savedPledges {
		deleteInput.Pledges[i] = DeletePledgeInput{PledgeIdn: p.PledgeIdn}
	}

	deletedPledges, err := DeletePledge(ctx, q, deleteInput)
	if err != nil {
		t.Fatalf("failed to delete pledges: %v", err)
	}

	// Check if cascade output matches
	deleteJson, _ := json.Marshal(deletedPledges)
	t.Logf("Deleted pledges: %s", string(deleteJson))

	// Note: DeletePledge procedure returns the deleted records before deletion
	assert.Equal(t, 1, len(deletedPledges))
	t.Logf("lifecycle test passed: saved, found, and deleted %d pledges", len(deletedPledges))
}
