package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"zarge/internal/daemon"
	"zarge/internal/launchd"
	"zarge/internal/smc"
)

func main() {
	log.SetFlags(log.LstdFlags)
	log.SetPrefix("")

	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}

	cmd, args := os.Args[1], os.Args[2:]
	switch cmd {
	case "run":
		os.Exit(runCmd(args))
	case "status":
		os.Exit(statusCmd(args))
	case "install":
		os.Exit(simpleCmd(launchd.Install))
	case "uninstall":
		os.Exit(simpleCmd(launchd.Uninstall))
	case "purge":
		os.Exit(simpleCmd(launchd.Purge))
	case "-h", "--help", "help":
		usage()
		os.Exit(0)
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n\n", cmd)
		usage()
		os.Exit(2)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, `zarge — keep the MagSafe LED green when battery is full.

Usage:
  zarge run [--threshold=90]
  zarge status
  zarge install      (requires sudo)
  zarge uninstall    (requires sudo)
  zarge purge        (requires sudo; uninstall + remove log)`)
}

func runCmd(args []string) int {
	fs := flag.NewFlagSet("run", flag.ContinueOnError)
	threshold := fs.Int("threshold", 90, "battery percent at which and above the LED is forced green")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if *threshold < 1 || *threshold > 100 {
		log.Printf("zarge: --threshold must be 1..100")
		return 2
	}

	c := smc.New()
	if err := c.Open(); err != nil {
		log.Printf("zarge: open SMC: %v", err)
		return 1
	}
	defer c.Close()

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	if err := daemon.Run(ctx, c, daemon.Options{
		Threshold: *threshold,
	}); err != nil {
		log.Printf("zarge: %v", err)
		return 1
	}
	return 0
}

func statusCmd(args []string) int {
	fs := flag.NewFlagSet("status", flag.ContinueOnError)
	threshold := fs.Int("threshold", 90, "threshold for the engaged check")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	c := smc.New()
	if err := c.Open(); err != nil {
		log.Printf("zarge: open SMC: %v", err)
		return 1
	}
	defer c.Close()

	pct, errPct := c.GetBatteryCharge()
	plugged, errPlug := c.IsPluggedIn()
	led, errLed := c.GetMagSafeLedState()

	fmt.Printf("battery:    %s\n", intOrErr(pct, errPct, "%d%%"))
	fmt.Printf("plugged-in: %s\n", boolOrErr(plugged, errPlug))
	fmt.Printf("led:        %s\n", ledOrErr(led, errLed))
	fmt.Printf("magsafe:    %s\n", boolStr(errLed == nil, "available", "unavailable"))
	fmt.Printf("threshold:  %d%% (engaged: %v)\n", *threshold, statusEngaged(pct, plugged, *threshold, errPct, errPlug))
	if errPct != nil || errPlug != nil || errLed != nil {
		return 1
	}
	return 0
}

func simpleCmd(fn func() error) int {
	if err := fn(); err != nil {
		log.Printf("zarge: %v", err)
		return 1
	}
	return 0
}

func intOrErr(v int, err error, format string) string {
	if err != nil {
		return "error: " + err.Error()
	}
	return fmt.Sprintf(format, v)
}

func boolOrErr(v bool, err error) string {
	if err != nil {
		return "error: " + err.Error()
	}
	return fmt.Sprintf("%v", v)
}

func ledOrErr(v smc.MagSafeLedState, err error) string {
	if err != nil {
		return "error: " + err.Error()
	}
	return v.String()
}

func boolStr(v bool, t, f string) string {
	if v {
		return t
	}
	return f
}

func statusEngaged(pct int, plugged bool, threshold int, errPct, errPlug error) bool {
	return errPct == nil && errPlug == nil && plugged && pct >= threshold
}

