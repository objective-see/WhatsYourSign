//
//  AppDelegate.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 9/25/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

//center on main screen
-(void)centerOnMainScreen
{
    //x position
    CGFloat xPos = {0};
    
    //y position
    CGFloat yPos = {0};
    
    //init x position
    xPos = NSWidth([[NSScreen mainScreen] frame])/2 - NSWidth([self.window frame])/2;
    
    //init y position
    yPos = NSHeight([[NSScreen mainScreen] frame])/2 - NSHeight([self.window frame])/2;
    
    //center window on main screen
    [self.window setFrame:NSMakeRect(xPos, yPos, NSWidth([self.window frame]), NSHeight([self.window frame])) display:YES];

    return;
}

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self centerOnMainScreen];

    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];

    return;
}

//center window on main screen
// ->also make it key window and in forefront
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //center
    [self centerOnMainScreen];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//automatically close app
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

//'got' it button handler
// ->just exit application
-(IBAction)quit:(id)sender
{
    //good bye!
    [NSApp terminate:self];

    return;
}

@end
