//
//  ACDDppDelegate.m
//  ACDemo
//
//  Created by Casey Fleser on 6/7/10.
//

#import "ACDAppDelegate.h"
#import "ACDManager.h"

@implementation ACDAppDelegate

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[[ACDManager sharedManager] start];
}

@end
