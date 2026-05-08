// Adapted from github.com/charlie0129/batt (GPL-2.0).

package smc

func (c *AppleSMC) IsPluggedIn() (bool, error) {
	v, err := c.read(ACPowerKey)
	if err != nil {
		return false, err
	}
	return len(v.Bytes) == 1 && int8(v.Bytes[0]) > 0, nil
}
