package main

import "testing"

func TestStatusEngagedRequiresPluggedInAboveThreshold(t *testing.T) {
	tests := []struct {
		name      string
		pct       int
		plugged   bool
		threshold int
		want      bool
	}{
		{name: "plugged in above threshold", pct: 91, plugged: true, threshold: 90, want: true},
		{name: "plugged in at threshold", pct: 90, plugged: true, threshold: 90, want: true},
		{name: "unplugged at threshold", pct: 90, plugged: false, threshold: 90, want: false},
		{name: "plugged in below threshold", pct: 89, plugged: true, threshold: 90, want: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := statusEngaged(tt.pct, tt.plugged, tt.threshold, nil, nil)
			if got != tt.want {
				t.Fatalf("statusEngaged returned %v, want %v", got, tt.want)
			}
		})
	}
}
