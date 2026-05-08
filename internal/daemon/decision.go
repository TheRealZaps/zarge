package daemon

import "zarge/internal/smc"

type Status struct {
	BatteryPercent int
	PluggedIn      bool
	CurrentLED     smc.MagSafeLedState
}

type Decision struct {
	ShouldWrite bool
	State       smc.MagSafeLedState
}

// DesiredLEDState returns whether the LED should be written and to what state.
func DesiredLEDState(s Status, threshold int) Decision {
	var desired smc.MagSafeLedState
	switch {
	case !s.PluggedIn:
		desired = smc.LEDSystem
	case s.BatteryPercent >= threshold:
		desired = smc.LEDGreen
	default:
		desired = smc.LEDSystem
	}

	if s.CurrentLED == desired {
		return Decision{}
	}
	return Decision{ShouldWrite: true, State: desired}
}
