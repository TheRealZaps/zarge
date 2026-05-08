package daemon

import (
	"context"
	"testing"
	"time"
)

func TestRunEventLoopChecksAtStartupAndDelaysEventChecks(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	events := make(chan struct{}, 2)
	steps := make(chan struct{}, 2)

	done := make(chan error, 1)
	go func() {
		done <- runEventLoop(ctx, events, 10*time.Millisecond, func() {
			steps <- struct{}{}
		})
	}()

	waitForStep(t, steps)

	events <- struct{}{}
	assertNoImmediateStep(t, steps)
	waitForStep(t, steps)

	cancel()
	if err := waitForLoop(t, done); err != nil {
		t.Fatalf("runEventLoop returned error: %v", err)
	}
}

func TestRunEventLoopCoalescesBurstEventsIntoOneDelayedCheck(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	events := make(chan struct{}, 2)
	steps := make(chan struct{}, 2)

	done := make(chan error, 1)
	go func() {
		done <- runEventLoop(ctx, events, 20*time.Millisecond, func() {
			steps <- struct{}{}
		})
	}()

	waitForStep(t, steps)

	events <- struct{}{}
	time.Sleep(5 * time.Millisecond)
	events <- struct{}{}
	assertNoImmediateStep(t, steps)
	waitForStep(t, steps)
	assertNoImmediateStep(t, steps)

	cancel()
	if err := waitForLoop(t, done); err != nil {
		t.Fatalf("runEventLoop returned error: %v", err)
	}
}

func waitForStep(t *testing.T, steps <-chan struct{}) {
	t.Helper()

	select {
	case <-steps:
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for step")
	}
}

func assertNoImmediateStep(t *testing.T, steps <-chan struct{}) {
	t.Helper()

	select {
	case <-steps:
		t.Fatal("unexpected immediate step")
	case <-time.After(5 * time.Millisecond):
	}
}

func waitForLoop(t *testing.T, done <-chan error) error {
	t.Helper()

	select {
	case err := <-done:
		return err
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for loop shutdown")
		return nil
	}
}
