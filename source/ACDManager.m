//
//  ACDManager.m
//  ACDemo
//
//  Created by Casey Fleser on 6/7/10.
//

#import "ACDManager.h"
#import "ACDDevice.h"
//#import "ACDEvent.h"

#include <IOKit/IOKitLib.h>
#include <IOKit/hid/IOHIDKeys.h>

static ACDManager		*sSharedManager = nil;

@interface ACDManager (Private)

- (void)		matchDevices;

@end

static void DeviceAdded(
	void			*inRefCon,
	io_iterator_t   inIterator)
{
	ACDManager		*manager = (ACDManager *)inRefCon;
	ACDDevice		*device;
	mach_timespec_t	waitTime;
	io_service_t	obj;
	kern_return_t	result;
	
	waitTime.tv_sec = 5;
	waitTime.tv_nsec = 0;
	
	while ((obj = IOIteratorNext(inIterator))) {
		result = IOServiceWaitQuiet(obj, &waitTime);		// fix for radar://5474691
		if (result != kIOReturnSuccess || (device = [[ACDDevice alloc] initWithService: obj]) == nil) {
			// TODO: this does seem to happen on occasion even after the IOKit dictionary is stable 
			NSLog(@"Failed to create object for devce");
			IOObjectRelease(obj);
		}
		else {
			[manager addDevice: device];
			[device release];
		}
	}
}

static void DeviceRemoved(
	void			*inRefCon,
	io_iterator_t   inIterator)
{
	ACDManager		*manager = (ACDManager *) inRefCon;
	ACDDevice		*device;
	io_service_t	obj;
	
	while ((obj = IOIteratorNext(inIterator))) {
		if ((device = [manager deviceWithService: obj]) != nil)
			[manager removeDevice: device];
	}
}


@implementation ACDManager

@synthesize lastEvent = _lastEvent;
@synthesize eventActive = _eventActive;

+ (ACDManager *) sharedManager
{
	@synchronized(self) {
		if (sSharedManager == nil)
			[[self alloc] init];
	}
	
	return sSharedManager;
}

+ (id) allocWithZone: (NSZone *) inZone
{
	ACDManager	*manager = sSharedManager;

	@synchronized(self) {
		if (manager == nil)
		manager = sSharedManager = [super allocWithZone: inZone];
	}

	return manager;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"AirClick Manager %ld devices", [_devices count]];
}

- (id) init
{
	if ((self = [super init]) != nil) {
		_lock = [[NSRecursiveLock alloc] init];
		_devices = [[NSMutableArray array] retain];
	}

	return self;
}

- (id) copyWithZone: (NSZone *) inZone
{
    return self;
}
 
- (id) retain
{
    return self;
}
 
- (NSUInteger) retainCount
{
    return NSUIntegerMax;
}
 
- (void) release
{
}
 
- (id) autorelease
{
    return self;
}

- (void) start
{
	[NSThread detachNewThreadSelector: @selector(startAirClickRunLoop:) toTarget: self withObject: self];
}

- (void) startAirClickRunLoop: (id) inObj
{
	NSAutoreleasePool	*ourPool = [[NSAutoreleasePool alloc] init];
	BOOL				running = YES;
	
	_airclickLoop = [NSRunLoop currentRunLoop];
	[self matchDevices];
	[ourPool release];
	
	while (running) {
		ourPool = [[NSAutoreleasePool alloc] init];
		
		// we stop every now and again to clear the autorelease pool
		running = [_airclickLoop runMode: NSDefaultRunLoopMode beforeDate: [NSDate dateWithTimeIntervalSinceNow: 2]];
		
		[ourPool release];
	}
}

- (void) matchDevices
{
	CFMutableDictionaryRef  matchingDict;
	CFRunLoopSourceRef 		runLoopSource;
	IOReturn				result;
	
	matchingDict = IOServiceMatching(kIOHIDDeviceKey);
	NSAssert(matchingDict != nil, @"IOServiceMatching kIOHIDDeviceKey failed");
	
	CFRetain(matchingDict);		// IOServiceAddMatchingNotification will consume a reference and it will be called twice, hence the extra retain
	CFDictionarySetValue(matchingDict, [NSString stringWithCString: kIOHIDProductIDKey encoding: NSUTF8StringEncoding], [NSNumber numberWithLong: kAirClickProductID]);
	CFDictionarySetValue(matchingDict, [NSString stringWithCString: kIOHIDVendorIDKey encoding: NSUTF8StringEncoding], [NSNumber numberWithLong: kAirClickVendorID]);
	_notifyPort = IONotificationPortCreate(kIOMasterPortDefault);
	
	result = IOServiceAddMatchingNotification(_notifyPort, kIOFirstMatchNotification, matchingDict, &DeviceAdded, self, &_deviceIterator);
	NSAssert1(result == kIOReturnSuccess, @"IOServiceAddMatchingNotification kIOFirstMatchNotification failed: %08x", result);
	DeviceAdded((void *)self, _deviceIterator);			// check matching devices suplied by iterator
	
	result = IOServiceAddMatchingNotification(_notifyPort, kIOTerminatedNotification, matchingDict, &DeviceRemoved, self, &_deviceIterator);
	NSAssert1(result == kIOReturnSuccess, @"IOServiceAddMatchingNotification kIOTerminatedNotification failed: %08x", result);
	DeviceRemoved((void *)self, _deviceIterator);		// check matching devices suplied by iterator
				
	runLoopSource = IONotificationPortGetRunLoopSource(_notifyPort);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
}

- (NSRunLoop *) runLoop
{
	return _airclickLoop;
}

- (NSArray *) devices
{
	return _devices;
}

- (NSUInteger) countOfDevices
{
	return [_devices count];
}

- (ACDDevice *) objectInDevicesAtIndex: (NSUInteger) inIndex
{
	return inIndex < [_devices count] ? [_devices objectAtIndex: inIndex] : nil;
}

- (void) insertObject: (ACDDevice *) inDevice
	inDevicesAtIndex: (NSUInteger) inIndex
{	
	[_lock lock];

		[_devices insertObject: inDevice atIndex: inIndex];
		
	[_lock unlock];
}

- (void) removeObjectFromDevicesAtIndex: (NSUInteger) inIndex
{
	[_lock lock];

		[_devices removeObjectAtIndex: inIndex];
		
	[_lock unlock];
}

- (ACDDevice *) deviceWithService: (io_service_t) inServiceID
{
	return [self deviceWithLocation: [ACDDevice locationOfServiceID: inServiceID]];
}

- (ACDDevice *) deviceWithLocation: (UInt32) inLocation
{
	ACDDevice	*theDevice = nil;
	
	[_lock lock];

		if (inLocation == 0)		// location 0 designants any device
			theDevice = [self objectInDevicesAtIndex: 0];
		else {
			for (ACDDevice *device in _devices) {
				if ([device locationID] == inLocation) {
					theDevice = device;
					break;
				}
			}
		}
		
	[_lock unlock];
	
	return theDevice;
}


- (void) addDevice: (ACDDevice *) inDevice
{
	[_lock lock];
		
		[self insertObject: inDevice inDevicesAtIndex: [self countOfDevices]];
		
	[_lock unlock];
}

- (void) removeDevice: (ACDDevice *) inDevice
{
	NSUInteger		deviceIndex;
	
	[_lock lock];

		deviceIndex = [_devices indexOfObject: inDevice];
		if (deviceIndex != NSNotFound) {
			[inDevice shutdown];
			[self removeObjectFromDevicesAtIndex: deviceIndex];
		}
		
	[_lock unlock];
}


- (void) handleEvent: (ACDEvent *) inEvent
{
	self.eventActive = YES;
	
	self.lastEvent = [inEvent description];

	self.eventActive = NO;
}

@end
 
