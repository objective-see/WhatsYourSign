//
//  AboutWindowController.m
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/15/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Utilities.h"
#import "AboutWindowController.h"

@implementation AboutWindowController

@synthesize patrons;
@synthesize supportUs;
@synthesize versionLabel;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
}

//automatically invoked when window is loaded
// ->set to white
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    //set version sting
    self.versionLabel.stringValue =  [NSString stringWithFormat:@"Version: %@", getAppVersion()];
    
    //load patrons
    self.patrons.string = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"patrons" ofType:@"txt"] encoding:NSUTF8StringEncoding error:NULL];
    
    //make first responder
    // calling this without a timeout sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        //and make it first responder
        [self.window makeFirstResponder:self.supportUs];
        
    });
    
    return;
}

//automatically invoked when window is closing
// ->make ourselves unmodal
-(void)windowWillClose:(NSNotification *)notification
{
    //make un-modal
    [[NSApplication sharedApplication] stopModal];
    
    return;
}

//automatically invoked when user clicks any of the buttons
// ->load patreon or products webpage in user's default browser
-(IBAction)buttonHandler:(id)sender
{
    //support us button
    if(((NSButton*)sender).tag == BUTTON_SUPPORT_US)
    {
        //open URL
        // ->invokes user's default browser
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PATREON_URL]];
    }
    
    //more info button
    else if(((NSButton*)sender).tag == BUTTON_MORE_INFO)
    {
        //open URL
        // ->invokes user's default browser
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PRODUCT_URL]];
    }

    return;
}
@end
