// Adapted from github.com/charlie0129/batt (GPL-2.0).

package smc

import "github.com/charlie0129/gosmc"

type AppleSMC struct {
	conn gosmc.Connection
}

func New() *AppleSMC {
	return &AppleSMC{conn: gosmc.New()}
}

func (c *AppleSMC) Open() error  { return c.conn.Open() }
func (c *AppleSMC) Close() error { return c.conn.Close() }

func (c *AppleSMC) read(key string) (gosmc.SMCVal, error) {
	return c.conn.Read(key)
}

func (c *AppleSMC) write(key string, value []byte) error {
	return c.conn.Write(key, value)
}
