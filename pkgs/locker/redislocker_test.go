package locker

import (
	"context"
	"sadbhavana/tree-project/pkgs/conf"
	"testing"
	"time"
)

func setupTestLocker(t *testing.T) *RedisLocker {
	// load env from repo .env so conf.GetConfig() can pick up Redis settings
	err := conf.LoadEnvFromFile("../../.env")
	if err != nil {
		t.Fatalf("failed to load env file: %v", err)
	}
	return NewRedisLocker(context.Background(), "testlock:")
}

func TestObtainReleaseLock(t *testing.T) {
	locker := setupTestLocker(t)
	ctx := context.Background()
	key := "mykey"

	// ensure we can obtain a lock
	expiry := 10 * time.Second
	lck, err := locker.Obtain(ctx, key, &expiry)
	if err != nil {
		t.Fatalf("Obtain failed: %v", err)
	}
	if lck == nil {
		t.Fatalf("expected lock but got nil")
	}

	// second obtain should not succeed while lock is held
	lck2, err := locker.Obtain(ctx, key, &expiry)
	if err != nil {
		t.Fatalf("second Obtain returned error: %v", err)
	}
	if lck2 != nil {
		// cleanup if unexpected
		_ = lck2.Release(ctx)
		t.Fatalf("expected second Obtain to return nil when lock already held")
	}

	// release first lock
	if err := lck.Release(ctx); err != nil {
		t.Fatalf("Release failed: %v", err)
	}

	// after release, obtain should succeed again
	lck3, err := locker.Obtain(ctx, key, &expiry)
	if err != nil {
		t.Fatalf("Obtain after release failed: %v", err)
	}
	if lck3 == nil {
		t.Fatalf("expected lock after release but got nil")
	}
	_ = lck3.Release(ctx)
}

func TestObtainWithNilExpiry(t *testing.T) {
	locker := setupTestLocker(t)
	ctx := context.Background()
	key := "mykey_nil_expiry"

	// Obtain with nil expiry should use default expiry and succeed
	lck, err := locker.Obtain(ctx, key, nil)
	if err != nil {
		t.Fatalf("Obtain with nil expiry failed: %v", err)
	}
	if lck == nil {
		t.Fatalf("expected lock with nil expiry but got nil")
	}
	_ = lck.Release(ctx)
}
