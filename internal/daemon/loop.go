package daemon

import (
	"context"
	"log"
	"time"

	"zarge/internal/power"
	"zarge/internal/smc"
)

const ledSettleDelay = 750 * time.Millisecond

type Options struct {
	Threshold int
}

// Run watches macOS power-source notifications and writes the MagSafe LED state
// according to DesiredLEDState. It returns when ctx is cancelled.
func Run(ctx context.Context, c *smc.AppleSMC, opts Options) error {
	if !c.HasMagSafeLED() {
		return errMissingMagSafe
	}

	log.Printf("zarge: threshold=%d mode=event-driven", opts.Threshold)

	events, err := power.Watch(ctx)
	if err != nil {
		return err
	}

	return runEventLoop(ctx, events, ledSettleDelay, func() {
		step(c, opts)
	})
}

func runEventLoop(ctx context.Context, events <-chan struct{}, settleDelay time.Duration, step func()) error {
	step()
	var settle <-chan time.Time
	var timer *time.Timer
	defer func() {
		if timer != nil {
			timer.Stop()
		}
	}()

	for {
		select {
		case <-ctx.Done():
			return nil
		case _, ok := <-events:
			if !ok {
				return nil
			}
			if settleDelay > 0 {
				if timer == nil {
					timer = time.NewTimer(settleDelay)
				} else {
					if !timer.Stop() {
						select {
						case <-timer.C:
						default:
						}
					}
					timer.Reset(settleDelay)
				}
				settle = timer.C
			}
		case <-settle:
			settle = nil
			step()
		}
	}
}

func step(c *smc.AppleSMC, opts Options) {
	pct, err := c.GetBatteryCharge()
	if err != nil {
		log.Printf("zarge: read battery: %v", err)
		return
	}
	plugged, err := c.IsPluggedIn()
	if err != nil {
		log.Printf("zarge: read AC: %v", err)
		return
	}
	led, err := c.GetMagSafeLedState()
	if err != nil {
		log.Printf("zarge: read LED: %v", err)
		return
	}

	d := DesiredLEDState(Status{BatteryPercent: pct, PluggedIn: plugged, CurrentLED: led}, opts.Threshold)
	if !d.ShouldWrite {
		return
	}

	log.Printf("zarge: battery=%d%% plugged=%v led=%s -> %s", pct, plugged, led, d.State)
	if err := c.SetMagSafeLedState(d.State); err != nil {
		log.Printf("zarge: write LED: %v", err)
	}
}
