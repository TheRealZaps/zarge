package smc

import (
	"testing"

	"github.com/charlie0129/gosmc"
)

func TestGetMagSafeLedStateRejectsMalformedRead(t *testing.T) {
	conn := gosmc.NewMockConnection()
	if err := conn.Write(MagSafeLedKey, []byte{byte(LEDGreen), byte(LEDOrange)}); err != nil {
		t.Fatalf("write mock LED: %v", err)
	}

	c := &AppleSMC{conn: conn}
	if _, err := c.GetMagSafeLedState(); err == nil {
		t.Fatal("GetMagSafeLedState returned nil error for malformed LED read")
	}
}
