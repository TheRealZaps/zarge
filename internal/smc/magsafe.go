// Adapted from github.com/charlie0129/batt (GPL-2.0).

package smc

import "fmt"

type MagSafeLedState uint8

const (
	LEDSystem        MagSafeLedState = 0x00
	LEDOff           MagSafeLedState = 0x01
	LEDGreen         MagSafeLedState = 0x03
	LEDOrange        MagSafeLedState = 0x04
	LEDErrorOnce     MagSafeLedState = 0x05
	LEDErrorPermSlow MagSafeLedState = 0x06
	LEDErrorPermFast MagSafeLedState = 0x07
	LEDErrorPermOff  MagSafeLedState = 0x19
)

func (s MagSafeLedState) String() string {
	switch s {
	case LEDSystem:
		return "system"
	case LEDOff:
		return "off"
	case LEDGreen:
		return "green"
	case LEDOrange:
		return "orange"
	case LEDErrorOnce:
		return "error-once"
	case LEDErrorPermSlow:
		return "error-perm-slow"
	case LEDErrorPermFast:
		return "error-perm-fast"
	case LEDErrorPermOff:
		return "error-perm-off"
	}
	return "unknown"
}

func (c *AppleSMC) SetMagSafeLedState(state MagSafeLedState) error {
	return c.write(MagSafeLedKey, []byte{byte(state)})
}

func (c *AppleSMC) GetMagSafeLedState() (MagSafeLedState, error) {
	v, err := c.read(MagSafeLedKey)
	if err != nil {
		return LEDOrange, err
	}
	if len(v.Bytes) != 1 {
		return LEDOrange, fmt.Errorf("MagSafe LED: unexpected data length %d", len(v.Bytes))
	}
	raw := MagSafeLedState(v.Bytes[0])
	switch raw {
	case LEDSystem, LEDOff, LEDGreen, LEDOrange, LEDErrorOnce, LEDErrorPermSlow, LEDErrorPermFast, LEDErrorPermOff:
		return raw, nil
	case 2:
		return LEDGreen, nil
	}
	return LEDOrange, nil
}

func (c *AppleSMC) HasMagSafeLED() bool {
	_, err := c.read(MagSafeLedKey)
	return err == nil
}
