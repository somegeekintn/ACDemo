//
//  ACDManager.h
//  ACDemo
//
//  Created by Casey Fleser on 6/7/10.
//

#import <Cocoa/Cocoa.h>

#define kAirClickVendorID		0x077d
#define kAirClickProductID		0x1016

@class ACDDevice;
@class ACDEvent;

@interface ACDManager : NSObject
{
	NSRecursiveLock			*_lock;
	NSMutableArray			*_devices;
	
	NSRunLoop				*_airclickLoop;
	IONotificationPortRef 	_notifyPort;
	io_iterator_t			_deviceIterator;
	
	NSString				*_lastEvent;
	BOOL					_eventActive;
}

+ (ACDManager *)	sharedManager;

- (void)			start;
- (NSRunLoop *)		runLoop;

- (NSArray *)		devices;
- (NSUInteger)		countOfDevices;
- (ACDDevice *)		objectInDevicesAtIndex: (NSUInteger) inIndex;
- (void)			insertObject: (ACDDevice *) inDevice
						inDevicesAtIndex: (NSUInteger) inIndex;
- (void)			removeObjectFromDevicesAtIndex: (NSUInteger) inIndex;
- (ACDDevice *)		deviceWithService: (io_service_t) inServiceID;
- (ACDDevice *)		deviceWithLocation: (UInt32) inLocation;
- (void)			addDevice: (ACDDevice *) inDevice;
- (void)			removeDevice: (ACDDevice *) inDevice;

- (void)			handleEvent: (ACDEvent *) inEvent;

@property (assign) BOOL			eventActive;
@property (copy) NSString		*lastEvent;

@end
