package db

import (
	"sadbhavana/tree-project/pkgs/conf"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestDbApiGetDonor_Integration(t *testing.T) {
	ctx := t.Context()
	conf.LoadEnvFromFile("../../.env.test")

	q, err := NewQueries(ctx)
	if err != nil {
		t.Fatalf("failed to create queries: %v", err)
	}

	input := GetDonorInput{
		DonorPattern: "Sharma",
	}

	output, err := callDbApi[GetDonorInput, []DbDonor](ctx, q, "GetDonor", input)
	if err != nil {
		t.Fatalf("failed to call db api: %v", err)
	}

	if len(output) != 1 {
		t.Fatalf("expected 1 result, got %d", len(output))
	}

	assert.Equal(t, 1, output[0].DonorIdn)
	assert.Equal(t, "Rajesh Kumar Sharma", output[0].DonorName)
	assert.Equal(t, "+91-9876543210", output[0].MobileNumber)
	assert.Equal(t, "Mumbai", output[0].City)
	assert.Equal(t, "rajesh.sharma@example.com", output[0].EmailAddr)
	assert.Equal(t, "India", output[0].Country)
	assert.Equal(t, "", output[0].BirthDt)
	assert.Equal(t, map[string]any{"vip_status": true}, output[0].PropertyList)
}

func TestDbApiSaveDonor_Integration(t *testing.T) {
	ctx := t.Context()
	conf.LoadEnvFromFile("../../.env.test")

	q, err := NewQueries(ctx)
	if err != nil {
		t.Fatalf("failed to create queries: %v", err)
	}

	input := []SaveDonorInput{
		{
			DonorName:    "Rajesh Kumar Sharma",
			MobileNumber: "+91-9876543210",
			City:         "Mumbai",
			Country:      "India",
		},
		{
			DonorName:    "Priya Patel",
			MobileNumber: "+91-9123456789",
			City:         "Ahmedabad",
			Country:      "India",
		},
	}

	output, err := callDbApi[[]SaveDonorInput, []DbDonor](ctx, q, "SaveDonor", input)
	if err != nil {
		t.Fatalf("failed to call db api: %v", err)
	}

	if len(output) != 2 {
		t.Fatalf("expected 2 result, got %d", len(output))
	}
}

func TestDbApiDeleteDonor_Integration(t *testing.T) {
	ctx := t.Context()
	conf.LoadEnvFromFile("../../.env.test")

	q, err := NewQueries(ctx)
	if err != nil {
		t.Fatalf("failed to create queries: %v", err)
	}

	input := DeleteDonorRequest{
		Cascade: false,
		Donors: []DeleteDonorInput{
			{
				DonorIdn: 9,
			},
			{
				DonorIdn: 10,
			},
		},
	}

	output, err := DeleteDonor(ctx, q, input)
	if err != nil {
		t.Fatalf("failed to call db api: %v", err)
	}

	if len(output) >= 0 {
		t.Logf("deleted %d donors", len(output))
	}
}

func TestDbApiDonorUpdate_Integration(t *testing.T) {
	ctx := t.Context()
	conf.LoadEnvFromFile("../../.env.test")

	q, err := NewQueries(ctx)
	if err != nil {
		t.Fatalf("failed to create queries: %v", err)
	}

	// 1. Get pending updates
	getInput := GetDonorUpdateInput{
		BatchSize: 10,
	}

	updates, err := GetDonorUpdate(ctx, q, getInput)
	if err != nil {
		t.Fatalf("failed to get donor updates: %v", err)
	}

	t.Logf("found %d pending updates", len(updates))

	if len(updates) > 0 {
		// 2. Post progress for the first update
		postInput := []PostDonorUpdateInput{
			{
				Idn:        updates[0].Idn,
				SendStatus: "sent",
			},
		}

		resp, err := PostDonorUpdate(ctx, q, postInput)
		if err != nil {
			t.Fatalf("failed to post donor update: %v", err)
		}

		t.Logf("updated %d records, new hwm: %v", resp.UpdatedCount, resp.NewHighWaterMark)
		assert.GreaterOrEqual(t, resp.UpdatedCount, 1)
	}
}
