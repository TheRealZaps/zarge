#ifndef CSMC_H
#define CSMC_H

#include <stdint.h>
#include <mach/mach.h>

// The struct the AppleSMC IOKit user client reads and writes through
// IOConnectCallStructMethod. It must be exactly 80 bytes; ZargeCoreTests checks.

typedef struct {
  uint8_t major;
  uint8_t minor;
  uint8_t build;
  uint8_t reserved;
  uint16_t release;
} SMCVersion;

typedef struct {
  uint16_t version;
  uint16_t length;
  uint32_t cpuPLimit;
  uint32_t gpuPLimit;
  uint32_t memPLimit;
} SMCPLimitData;

typedef struct {
  uint32_t dataSize;
  uint32_t dataType;
  uint8_t dataAttributes;
} SMCKeyInfo;

typedef struct {
  uint32_t key;
  SMCVersion version;
  SMCPLimitData pLimitData;
  SMCKeyInfo keyInfo;
  uint8_t result;
  uint8_t status;
  uint8_t data8;
  uint32_t data32;
  uint8_t bytes[32];
} SMCParamStruct;

// mach_task_self() is a macro over a C global, which Swift 6 rejects as shared mutable state.
static inline mach_port_t csmc_task_self(void) { return mach_task_self(); }

#endif
