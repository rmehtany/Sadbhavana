package db

import (
	"encoding/json"
	"sadbhavana/tree-project/pkgs/conf"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestDbApiDonorLifecycle_Integration(t *testing.T) {
	ctx := t.Context()
	conf.LoadEnvFromFile("../../.env.test")

	q, err := NewQueries(ctx)
	if err != nil {
		t.Fatalf("failed to create queries: %v", err)
	}

	// 1. Save - Create new donors
	saveInput := []SaveDonorInput{
		{
			DonorName:    "Test Donor One",
			MobileNumber: "+91-9999999991",
			City:         "Test City",
			Country:      "India",
			EmailAddr:    "test1@example.com",
			BirthDt:      "1990-01-01",
		},
		{
			DonorName:    "Test Donor Two",
			MobileNumber: "+91-9999999992",
			City:         "Test City",
			Country:      "India",
			EmailAddr:    "test2@example.com",
			BirthDt:      "1990-01-01",
		},
	}

	saveInputJson, err := json.Marshal(saveInput)
	if err != nil {
		t.Fatalf("failed to marshal save input: %v", err)
	}
	t.Logf("save input: %s", string(saveInputJson))

	savedDonors, err := callDbApi[[]SaveDonorInput, []DbDonor](ctx, q, "SaveDonor", saveInput)
	if err != nil {
		t.Fatalf("failed to save donors: %v", err)
	}

	if len(savedDonors) != 2 {
		t.Fatalf("expected 2 donors saved, got %d", len(savedDonors))
	}

	// 2. Get - Verify created donors can be found
	getInput := GetDonorInput{
		DonorPattern: "Test Donor",
	}

	foundDonors, err := GetDonor(ctx, q, getInput)
	if err != nil {
		t.Fatalf("failed to get donors: %v", err)
	}

	// Verify we found at least our 2 new donors
	assert.GreaterOrEqual(t, len(foundDonors), 2)

	// 3. Delete - Clean up the created donors
	deleteInput := DeleteDonorRequest{
		Cascade: false,
		Donors:  make([]DeleteDonorInput, len(savedDonors)),
	}
	for i, d := range savedDonors {
		deleteInput.Donors[i] = DeleteDonorInput{DonorIdn: d.DonorIdn}
	}

	deletedDonors, err := DeleteDonor(ctx, q, deleteInput)
	if err != nil {
		t.Fatalf("failed to delete donors: %v", err)
	}

	assert.Equal(t, 2, len(deletedDonors))
	t.Logf("lifecycle test passed: saved, found, and deleted %d donors", len(deletedDonors))
}
