//
//  AppDelegate.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 9/25/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Utilities.h"
#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

//automatically called when nib is loaded
// center window
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    return;
}

//center window on main screen
// also make it key window and in forefront
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //center
    [self.window center];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //activate
    if(@available(macOS 14.0, *)) {
        [NSApp activate];
    }
    else
    {
        [NSApp activateIgnoringOtherApps:YES];
    }
    
    //make 'close' first responder
    // calling this without a timeout sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        //and make it first responder
        [self.window makeFirstResponder:self.closeButton];
    
    });
    
    return;
}

//automatically close app
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

//'got' it button handler
// ->just exit application
-(IBAction)close:(id)sender
{
    //good bye!
    [NSApp terminate:self];

    return;
}

@end
