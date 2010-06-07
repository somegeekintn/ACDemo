//
//  ACDEvent.h
//  ACDemo
//
//  Created by Casey Fleser on 6/7/10.
//

#import <Cocoa/Cocoa.h>

typedef enum {
	eAirClickButton_Huh = 0x00,
	eAirClickButton_PlayPause = 0x01,
	eAirClickButton_VolumeUp = 0x02,
	eAirClickButton_VolumeDown = 0x04,
	eAirClickButton_NextTrack = 0x08,
	eAirClickButton_PrevTrack = 0x10,
} eAirClickButtonID;

@interface ACDEvent : NSObject
{
	NSTimeInterval		_eventTime;
	UInt64				_eventID;
	NSUInteger			_deviceLocation;
	NSUInteger			_modifiers;
	eAirClickButtonID	_buttonID;
	BOOL				_pressed;
}

+ (NSString *)		stringForButtonID: (eAirClickButtonID) inButtonID;
+ (NSString *)		stringForModifiers: (NSUInteger) inModifiers;

+ (id)				createEventWithLocation: (NSUInteger) inDeviceLocation
						identifier: (eAirClickButtonID) inIdentifier
						pressed: (BOOL) inPressed
						modifiers: (NSUInteger) inModifiers;
- (id)				initWithLocation:  (NSUInteger) inDeviceLocation
						identifier: (eAirClickButtonID) inIdentifier
						pressed: (BOOL) inPressed
						modifiers: (NSUInteger) inModifiers;

@property (readonly) UInt64				eventID;
@property (readonly) eAirClickButtonID	buttonID;
@property (readonly) NSUInteger			deviceLocation, modifiers;
@property (readonly) NSTimeInterval		eventTime;
@property (readonly) BOOL				pressed;

@end
