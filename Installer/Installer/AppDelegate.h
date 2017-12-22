//
//  AppDelegate.h
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/5/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "AboutWindowController.h"
#import "ErrorWindowController.h"
#import "ConfigureWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate>
{
    
}

/* PROPERTIES */

//about window controller
@property(nonatomic, retain)AboutWindowController* aboutWindowController;

//configure window controller
@property(nonatomic, retain)ConfigureWindowController* configureWindowController;

//error window controller
@property(nonatomic, retain)ErrorWindowController* errorWindowController;


/* METHODS */

//display configuration window w/ 'install' || 'uninstall' button
-(void)displayConfigureWindow:(BOOL)isInstalled;

//display error window
-(void)displayErrorWindow:(NSDictionary*)errorInfo;

@end


