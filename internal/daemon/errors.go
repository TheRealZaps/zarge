package daemon

import "errors"

var errMissingMagSafe = errors.New("MagSafe LED key (ACLC) not present on this hardware")
