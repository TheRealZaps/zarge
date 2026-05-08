package power

/*
#cgo LDFLAGS: -framework CoreFoundation -framework IOKit
#include <CoreFoundation/CoreFoundation.h>

CFRunLoopSourceRef zargeCreatePowerSource(void *context);
void zargeAddRunLoopSource(CFRunLoopRef loop, CFRunLoopSourceRef source);
void zargeRemoveRunLoopSource(CFRunLoopRef loop, CFRunLoopSourceRef source);
CFRunLoopRef zargeCurrentRunLoop(void);
void zargeRetainRunLoop(CFRunLoopRef loop);
void zargeReleaseRunLoop(CFRunLoopRef loop);
void zargeReleaseSource(CFRunLoopSourceRef source);
void zargeRunLoopRun(void);
void zargeRunLoopStop(CFRunLoopRef loop);
*/
import "C"

import (
	"context"
	"errors"
	"runtime"
	"runtime/cgo"
	"unsafe"
)

// Watch returns a channel that receives an event whenever macOS reports a
// power-source change (battery percentage, charging state, or AC state).
func Watch(ctx context.Context) (<-chan struct{}, error) {
	events := make(chan struct{}, 1)
	ready := make(chan watcherStart, 1)
	done := make(chan struct{})

	go runWatcher(events, ready, done)

	start := <-ready
	if start.err != nil {
		return nil, start.err
	}

	go func() {
		select {
		case <-ctx.Done():
			C.zargeRunLoopStop(start.loop)
		case <-done:
		}
	}()

	return events, nil
}

type watcherStart struct {
	loop C.CFRunLoopRef
	err  error
}

func runWatcher(events chan<- struct{}, ready chan<- watcherStart, done chan<- struct{}) {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	defer close(done)

	handle := cgo.NewHandle(events)
	defer handle.Delete()

	loop := C.zargeCurrentRunLoop()
	C.zargeRetainRunLoop(loop)
	defer C.zargeReleaseRunLoop(loop)

	source := C.zargeCreatePowerSource(unsafe.Pointer(handle))
	if source == 0 {
		ready <- watcherStart{err: errors.New("create power-source notification")}
		return
	}
	defer C.zargeReleaseSource(source)

	C.zargeAddRunLoopSource(loop, source)
	defer C.zargeRemoveRunLoopSource(loop, source)

	ready <- watcherStart{loop: loop}
	C.zargeRunLoopRun()
}

func enqueueEvent(events chan<- struct{}) {
	select {
	case events <- struct{}{}:
	default:
	}
}

//export zargePowerSourceChanged
func zargePowerSourceChanged(context unsafe.Pointer) {
	handle := cgo.Handle(context)
	events := handle.Value().(chan<- struct{})
	enqueueEvent(events)
}
