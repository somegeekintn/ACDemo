//
//  ACDDevice.h
//  ACDemo
//
//  Created by Casey Fleser on 6/7/10.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/hid/IOHIDLib.h>

#define kAirClickReportBufferSize		6

@interface ACDDevice : NSObject
{
	io_service_t				_serviceID;
	UInt32						_locationID;
	IOUSBDeviceInterface		**_usbDevice;
	IOHIDDeviceInterface122		**_hidDevice;
	IOHIDQueueInterface			**_hidQueue;
	
	UInt8						_buffer[kAirClickReportBufferSize];
	
	NSString					*_name;
	NSUInteger					_buttonMap;
	NSUInteger					_modifiers;
	BOOL						_initComplete;
}

+ (UInt32)			locationOfServiceID: (io_service_t) inServiceID;

- (id)				initWithService: (io_service_t) inServiceID;
- (void)			shutdown;

- (io_service_t)	serviceID;
- (UInt32)			locationID;
- (NSString *)		locationName;

- (BOOL)			playPressed;
- (BOOL)			volUpPressed;
- (BOOL)			volDownPressed;
- (BOOL)			nextTrackPressed;
- (BOOL)			prevTrackPressed;

@property (copy) NSString		*name;
@property (assign) NSUInteger	buttonMap;

@end
