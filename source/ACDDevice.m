//
//  ACDDevice.m
//  ACDemo
//
//  Created by Casey Fleser on 6/7/10.
//

#import "ACDDevice.h"
#import "ACDManager.h"
#import "ACDEvent.h"

#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>

#define kRemoteButtonStateCookie	((IOHIDElementCookie)6)
#define kDeviceQueueSize			50

@interface ACDDevice (Private)

- (void)		initHIDInterface;
- (void)		initDeviceInterface;
- (IOReturn)	openAndQueue;

- (void)		processQueueEvents;
- (void)		processAnEvent: (int32_t) inButtonMap;

@end

void AirClickQueueUpdate(
	void		*inTarget,
	IOReturn	inResult,
	void		*inRefcon,
	void		*inSender)
{
	if (inResult == kIOReturnSuccess) {
		ACDDevice		*device = (ACDDevice *)inTarget;
	
		UpdateSystemActivity(UsrActivity);		// wakie wake

		[device processQueueEvents];

	}
}

@implementation ACDDevice

@synthesize name = _name;
@synthesize buttonMap = _buttonMap;

+ (UInt32) locationOfServiceID: (io_service_t) inServiceID
{
	CFMutableDictionaryRef	properties;
	CFNumberRef				location;
	IOReturn				result;
	UInt32					locationValue = 0;
	
	result = IORegistryEntryCreateCFProperties(inServiceID, &properties, kCFAllocatorDefault, kNilOptions);
	NSAssert1(result == kIOReturnSuccess, @"Failed to retrieve device properties: %08x", result);
	
	location = CFDictionaryGetValue(properties, CFSTR(kIOHIDLocationIDKey));
	NSAssert(location != NULL, @"Unable to determine device location");
	
	CFNumberGetValue(location, kCFNumberIntType, &locationValue);

	CFRelease(properties);
	
	return locationValue;
}

+ (NSSet *) keyPathsForValuesAffectingValueForKey: (NSString *) inKey
{
	NSSet *paths = [super keyPathsForValuesAffectingValueForKey: inKey];
	
	if ([inKey isEqualToString: @"playPressed"])
		paths = [paths setByAddingObject: @"buttonMap"];
	else if ([inKey isEqualToString: @"volUpPressed"])
		paths = [paths setByAddingObject: @"buttonMap"];
	else if ([inKey isEqualToString: @"volDownPressed"])
		paths = [paths setByAddingObject: @"buttonMap"];
	else if ([inKey isEqualToString: @"nextTrackPressed"])
		paths = [paths setByAddingObject: @"buttonMap"];
	else if ([inKey isEqualToString: @"prevTrackPressed"])
		paths = [paths setByAddingObject: @"buttonMap"];
		
	return paths;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"AirClick Device location: %08x service: %08x", _locationID, _serviceID];
}

- (id) initWithService: (io_service_t) inServiceID
{
	if ((self = [super init]) != nil) {
		_serviceID = inServiceID;
		_locationID = [ACDDevice locationOfServiceID: _serviceID];

		[self initHIDInterface];
		[self initDeviceInterface];

		if (_usbDevice != NULL && _hidDevice != NULL) {
			if ([self openAndQueue] == kIOReturnSuccess) {
				self.name = [NSString stringWithFormat: @"AirClick %ld", [[ACDManager sharedManager] countOfDevices] + 1];

				_initComplete = YES;
			}
		}
		
		if (!_initComplete) {
			if (_hidQueue != NULL) {
				(*_hidQueue)->Release(_hidQueue);
				_hidQueue = NULL;
			}
			if (_usbDevice != NULL) {
				(*_usbDevice)->Release(_usbDevice);
				_usbDevice = NULL;
			}
			if (_hidDevice != NULL) {
				(*_hidDevice)->Release(_hidDevice);
				_hidDevice = NULL;
			}
			
			IOObjectRelease(_serviceID);
			self = nil;
		}
	}
	
	return self;
}

- (void) initHIDInterface
{
    IOCFPlugInInterface		**iodev = NULL;
	IOReturn				result;
    SInt32					score;
	
	result = IOCreatePlugInInterfaceForService(_serviceID, kIOHIDDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
	
	if (result == kIOReturnSuccess) {
		IOHIDDeviceInterface122		**hidDeviceInterface;

		if ((*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOHIDDeviceInterfaceID122), (LPVOID) &hidDeviceInterface) == kIOReturnSuccess)
			_hidDevice = hidDeviceInterface;

		if (iodev != NULL)
			(*iodev)->Release(iodev);
	}
}

- (void) initDeviceInterface
{
	CFMutableDictionaryRef  matchingDict;
	IOCFPlugInInterface		**iodev = NULL;
	io_iterator_t			deviceIterator;
	io_object_t				usbDevice;
	IOReturn				result;
	SInt32					score;
	
	matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
	NSAssert(matchingDict != NULL, @"IOServiceMatching kIOHIDDeviceKey failed");

	CFDictionarySetValue(matchingDict, CFSTR(kUSBProductID), [NSNumber numberWithShort: kAirClickProductID]);
	CFDictionarySetValue(matchingDict, CFSTR(kUSBVendorID), [NSNumber numberWithShort: kAirClickVendorID]);

	result = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &deviceIterator);
	NSAssert1(result == kIOReturnSuccess, @"IOServiceGetMatchingServices failed: %08x", result);
	
	while (IOIteratorIsValid(deviceIterator) && (usbDevice = IOIteratorNext(deviceIterator)) && _usbDevice == NULL) {
		result = IOCreatePlugInInterfaceForService(usbDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
		if (result == kIOReturnSuccess) {
			IOUSBDeviceInterface		**usbDeviceInterface;

			result = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID) &usbDeviceInterface);
			if (result == kIOReturnSuccess) {
				UInt32			deviceLocationID;
				
				result = (*usbDeviceInterface)->GetLocationID(usbDeviceInterface, &deviceLocationID);
				if (result == kIOReturnSuccess) {
					if (deviceLocationID == _locationID) {
						_usbDevice = usbDeviceInterface;
					}
				}
			}
			
			if (_usbDevice == NULL)
				IOObjectRelease(usbDevice);

			if (iodev != NULL) {
				(*iodev)->Release(iodev);
				iodev = NULL;
			}
		}
	}

	IOObjectRelease(deviceIterator);
}

- (IOReturn) openAndQueue
{
	IOReturn				result;
 	
	if ((result = (*_hidDevice)->open(_hidDevice, 0)) == kIOReturnSuccess) {
		if ((_hidQueue = (*_hidDevice)->allocQueue(_hidDevice)) != NULL) {
			if ((result = (*_hidQueue)->create(_hidQueue, 0, kDeviceQueueSize)) != kIOReturnSuccess) {
				NSAssert1(result == kIOReturnSuccess, @"Failed to create queue for device: %08x", result);

				result = (*_hidQueue)->dispose(_hidQueue);
				result = (*_hidQueue)->Release(_hidQueue);
				_hidQueue = NULL;
			}
		}
	}
	
	if (_hidQueue != NULL) {
		CFRunLoopSourceRef		eventSource;
		
		if ((result = (*_hidQueue)->stop(_hidQueue)) != kIOReturnSuccess)
			NSLog(@"Failed to stop queue for device: %08x", result);
		
		result = (*_hidQueue)->createAsyncEventSource(_hidQueue, &eventSource);
		NSAssert1(result == kIOReturnSuccess, @"Could not create event source for device: %08x", result);
		
		CFRunLoopAddSource([[[ACDManager sharedManager] runLoop] getCFRunLoop], eventSource, kCFRunLoopDefaultMode);
		
		result = (*_hidQueue)->setEventCallout(_hidQueue, AirClickQueueUpdate, self, nil);
		NSAssert1(result == kIOReturnSuccess, @"Could not set HID queue callback for device: %08x", result);
		
		(*_hidQueue)->addElement(_hidQueue, kRemoteButtonStateCookie, 0);
		result = (*_hidQueue)->start(_hidQueue);
		NSAssert1(result == kIOReturnSuccess, @"Could not start queue for device: %08x", result);
	}
	
	return result;
}

- (void) dealloc
{
	[self shutdown];
	
	IOObjectRelease(_serviceID);
	
	[_name release];
	
	[super dealloc];
}

- (void) shutdown
{
	if (_hidQueue != NULL) {
		(*_hidQueue)->stop(_hidQueue);
		(*_hidQueue)->dispose(_hidQueue);
		(*_hidQueue)->Release(_hidQueue);
		_hidQueue = NULL;
	}
	if (_hidDevice != NULL) {
		(*_hidDevice)->close(_hidDevice);
		(*_hidDevice)->Release(_hidDevice);
		_hidDevice = NULL;
	}
	if (_usbDevice != NULL) {
		(*_usbDevice)->Release(_usbDevice);
		_usbDevice = NULL;
	}
}

- (NSScriptObjectSpecifier *) objectSpecifier
{
	NSScriptClassDescription	*containerDescription = [NSScriptClassDescription classDescriptionForClass: [NSApp class]];
	
	return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription: containerDescription containerSpecifier: nil key: @"devices" uniqueID: [self locationName]] autorelease];
}

- (io_service_t) serviceID
{
	return _serviceID;
}

- (UInt32) locationID
{
	return _locationID;
}

- (NSString *) locationName
{
	return [NSString stringWithFormat: @"%08x", _locationID];
}

- (void) setName: (NSString *) inName
{
    if (_name != inName) {
		[_name release];
		_name = [inName copy];
	}
}

- (BOOL) playPressed
{
	return _buttonMap & eAirClickButton_PlayPause;
}

- (void) setPlayPressed: (BOOL) inPressed
{
	// no-op
}

- (BOOL) volUpPressed
{
	return _buttonMap & eAirClickButton_VolumeUp;
}

- (void) setVolUpPressed: (BOOL) inPressed
{
	// no-op
}

- (BOOL) volDownPressed
{
	return _buttonMap & eAirClickButton_VolumeDown;
}

- (void) setVolDownPressed: (BOOL) inPressed
{
	// no-op
}

- (BOOL) nextTrackPressed
{
	return _buttonMap & eAirClickButton_NextTrack;
}

- (void) setNextTrackPressed: (BOOL) inPressed
{
	// no-op
}

- (BOOL) prevTrackPressed
{
	return _buttonMap & eAirClickButton_PrevTrack;
}

- (void) setPrevTrackPressed: (BOOL) inPressed
{
	// no-op
}

- (void) processQueueEvents
{
	IOHIDEventStruct		event;
	AbsoluteTime			zeroTime = {0,0};
	IOReturn				result;
	
	while ((result = (*_hidQueue)->getNextEvent(_hidQueue, &event, zeroTime, 0)) == noErr) {
		if (event.elementCookie == kRemoteButtonStateCookie) {
			[self processAnEvent: event.value];
		}
	}
}

- (void) processAnEvent: (int32_t) inButtonMap
{
	NSUInteger		changedStates = inButtonMap ^ _buttonMap;
	
	if (changedStates) {
		UInt32		idx;
		
		if (!(changedStates & inButtonMap))	// released button
			_modifiers = inButtonMap;
		else
			_modifiers = inButtonMap ? _buttonMap : 0x00;
			
		self.buttonMap = inButtonMap;

		for (idx = 0x01; changedStates; idx <<= 1) {
			if (changedStates & idx) {
				[[ACDManager sharedManager] handleEvent:
					[ACDEvent createEventWithLocation: [self locationID] identifier: idx pressed: (_buttonMap & idx) ? YES : NO modifiers: _modifiers]];

				changedStates &= ~idx;
			}
		}
	}
}

@end
