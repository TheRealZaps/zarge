#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/ps/IOPowerSources.h>

#include "_cgo_export.h"

static void zargePowerCallback(void *context) {
	zargePowerSourceChanged(context);
}

CFRunLoopSourceRef zargeCreatePowerSource(void *context) {
	return IOPSNotificationCreateRunLoopSource(zargePowerCallback, context);
}

void zargeAddRunLoopSource(CFRunLoopRef loop, CFRunLoopSourceRef source) {
	CFRunLoopAddSource(loop, source, kCFRunLoopDefaultMode);
}

void zargeRemoveRunLoopSource(CFRunLoopRef loop, CFRunLoopSourceRef source) {
	CFRunLoopRemoveSource(loop, source, kCFRunLoopDefaultMode);
}

CFRunLoopRef zargeCurrentRunLoop(void) {
	return CFRunLoopGetCurrent();
}

void zargeRetainRunLoop(CFRunLoopRef loop) {
	CFRetain(loop);
}

void zargeReleaseRunLoop(CFRunLoopRef loop) {
	CFRelease(loop);
}

void zargeReleaseSource(CFRunLoopSourceRef source) {
	CFRelease(source);
}

void zargeRunLoopRun(void) {
	CFRunLoopRun();
}

void zargeRunLoopStop(CFRunLoopRef loop) {
	CFRunLoopStop(loop);
}

