//
//  AppDelegate.h
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 9/25/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

@import Cocoa;

@interface AppDelegate : NSObject <NSApplicationDelegate>

/* PROPERTIES */

//update button
@property (weak) IBOutlet NSButton *updateButton;

//update indicator
@property (weak) IBOutlet NSProgressIndicator *updateIndicator;

//close button
@property (weak) IBOutlet NSButton* closeButton;

/* METHODS */

@end

NSModalResponse showAlert(NSAlertStyle style, NSString* messageText, NSString* informativeText, NSArray* buttons);

