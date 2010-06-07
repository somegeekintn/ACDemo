//
//  ACDEvent.m
//  ACDemo
//
//  Created by Casey Fleser on 6/7/10.
//  Copyright 2010 Griffin Technology, Inc. All rights reserved.
//

#import "ACDEvent.h"

static UInt64	sActiveEventID = 0;

@implementation ACDEvent

@synthesize eventID = _eventID;
@synthesize deviceLocation = _deviceLocation;
@synthesize buttonID = _buttonID;
@synthesize modifiers = _modifiers;
@synthesize eventTime = _eventTime;
@synthesize pressed = _pressed;


+ (NSString *) stringForButtonID: (eAirClickButtonID) inButtonID
{
	NSString	*eventName = nil;
	
	switch (inButtonID) {
		case eAirClickButton_PlayPause:		eventName = @"Play/Pause  ";	break;
		case eAirClickButton_VolumeUp:		eventName = @"Volume Up   ";	break;
		case eAirClickButton_VolumeDown:	eventName = @"Volume Down ";	break;
		case eAirClickButton_NextTrack:		eventName = @"Next Track  ";	break;
		case eAirClickButton_PrevTrack:		eventName = @"Prev Track  ";	break;
		default:							eventName = @"Unknown     ";	break;
	}
	
	return eventName;
}

+ (NSString *) stringForModifiers: (NSUInteger) inModifiers
{
	return [NSString stringWithFormat: @"%c%c%c%c%c",
		inModifiers & eAirClickButton_PlayPause		? 'P' : '-',
		inModifiers & eAirClickButton_VolumeUp		? '^' : '-',
		inModifiers & eAirClickButton_VolumeDown	? 'v' : '-',
		inModifiers & eAirClickButton_NextTrack		? '>' : '-',
		inModifiers & eAirClickButton_PrevTrack		? '<' : '-'];
}

+ (id) createEventWithLocation: (NSUInteger) inDeviceLocation
	identifier: (eAirClickButtonID) inIdentifier
	pressed: (BOOL) inPressed
	modifiers: (NSUInteger) inModifiers;
{
	return [[[ACDEvent alloc] initWithLocation: inDeviceLocation
								identifier: inIdentifier pressed: inPressed modifiers: inModifiers] autorelease];
}

- (id) initWithLocation: (NSUInteger) inDeviceLocation
	identifier: (eAirClickButtonID) inIdentifier
	pressed: (BOOL) inPressed
	modifiers: (NSUInteger) inModifiers;
{
    if ((self = [super init]) != NULL) {
		_eventTime = [NSDate timeIntervalSinceReferenceDate];
		_eventID = ++sActiveEventID;
		_deviceLocation = inDeviceLocation;
		_buttonID = inIdentifier;
		_modifiers = inModifiers;
		_pressed = inPressed;
    }

    return self;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"ACDEvent (%ld) [%ld] %@ %@ %@ ",
			_deviceLocation, _eventID, [ACDEvent stringForButtonID: _buttonID],
			_pressed ? @"pressed " : @"released", [ACDEvent stringForModifiers: _modifiers]];
}

@end
