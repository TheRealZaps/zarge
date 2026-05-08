package daemon

import (
	"testing"

	"zarge/internal/smc"
)

func TestDesiredLEDState(t *testing.T) {
	tests := []struct {
		name      string
		status    Status
		threshold int
		wantWrite bool
		wantState smc.MagSafeLedState
	}{
		{
			name:      "unplugged restores system control",
			status:    Status{BatteryPercent: 95, PluggedIn: false, CurrentLED: smc.LEDGreen},
			threshold: 90,
			wantWrite: true, wantState: smc.LEDSystem,
		},
		{
			name:      "unplugged already system skips write",
			status:    Status{BatteryPercent: 95, PluggedIn: false, CurrentLED: smc.LEDSystem},
			threshold: 90,
		},
		{
			name:      "at threshold forces green",
			status:    Status{BatteryPercent: 90, PluggedIn: true, CurrentLED: smc.LEDOrange},
			threshold: 90,
			wantWrite: true, wantState: smc.LEDGreen,
		},
		{
			name:      "above threshold forces green",
			status:    Status{BatteryPercent: 91, PluggedIn: true, CurrentLED: smc.LEDOrange},
			threshold: 90,
			wantWrite: true, wantState: smc.LEDGreen,
		},
		{
			name:      "already green skips write",
			status:    Status{BatteryPercent: 95, PluggedIn: true, CurrentLED: smc.LEDGreen},
			threshold: 90,
		},
		{
			name:      "below threshold restores system",
			status:    Status{BatteryPercent: 89, PluggedIn: true, CurrentLED: smc.LEDGreen},
			threshold: 90,
			wantWrite: true, wantState: smc.LEDSystem,
		},
		{
			name:      "well below threshold restores system",
			status:    Status{BatteryPercent: 50, PluggedIn: true, CurrentLED: smc.LEDGreen},
			threshold: 90,
			wantWrite: true, wantState: smc.LEDSystem,
		},
		{
			name:      "below threshold but already system skips write",
			status:    Status{BatteryPercent: 50, PluggedIn: true, CurrentLED: smc.LEDSystem},
			threshold: 90,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := DesiredLEDState(tt.status, tt.threshold)
			if got.ShouldWrite != tt.wantWrite {
				t.Fatalf("ShouldWrite: got %v, want %v (decision=%+v)", got.ShouldWrite, tt.wantWrite, got)
			}
			if tt.wantWrite && got.State != tt.wantState {
				t.Fatalf("State: got %v, want %v", got.State, tt.wantState)
			}
		})
	}
}
