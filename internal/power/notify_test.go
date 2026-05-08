package power

import "testing"

func TestEnqueueEventCoalescesWhenChannelIsFull(t *testing.T) {
	events := make(chan struct{}, 1)

	enqueueEvent(events)
	enqueueEvent(events)

	if got := len(events); got != 1 {
		t.Fatalf("event channel length = %d, want 1", got)
	}
}
