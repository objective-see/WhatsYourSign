//
//  ConfigureWindowController.h
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/7/2016.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

@import Cocoa;

@interface ConfigureWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */
@property BOOL isUninstalling;
@property (weak) IBOutlet NSProgressIndicator *activityIndicator;
@property (weak) IBOutlet NSTextField *statusMsg;
@property (weak) IBOutlet NSButton *installButton;
@property (weak) IBOutlet NSButton *uninstallButton;
@property (weak) IBOutlet NSButton *moreInfoButton;

//support view
@property (strong) IBOutlet NSView *supportView;

//support button
@property (weak) IBOutlet NSButton *supportButton;

/* METHODS */

//install/uninstall button handler
-(IBAction)buttonHandler:(id)sender;

//(more) info button handler
-(IBAction)info:(id)sender;

//configure window/buttons
// ->also brings to front
-(void)configure:(BOOL)isInstalled;

//display (show) window
-(void)display;

@end
