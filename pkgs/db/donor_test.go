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
