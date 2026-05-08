// Adapted from github.com/charlie0129/batt (GPL-2.0).

package smc

import "fmt"

func (c *AppleSMC) GetBatteryCharge() (int, error) {
	v, err := c.read(BatteryChargeKey)
	if err != nil {
		return 0, err
	}
	if len(v.Bytes) != 1 {
		return 0, fmt.Errorf("battery charge: unexpected data length %d", len(v.Bytes))
	}
	return int(v.Bytes[0]), nil
}
