//
//  AppDelegate.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 9/25/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//
#import <os/log.h>

#import "consts.h"
#import "Update.h"
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
    //set 'external drives' button state
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP];
    self.enableExtDrivesButton.state = [sharedDefaults boolForKey:PREF_ENABLE_ON_EXTERNAL_DRIVES] ? NSControlStateValueOn : NSControlStateValueOff;
    
    //install launch?
    // don't show 'check for update' button
    if([NSProcessInfo.processInfo.arguments containsObject:@"install"]) {
        self.updateButton.hidden = YES;
    }
    //user launched
    // show 'check for update' button
    else
    {
        self.updateButton.hidden = NO;
    }
    
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

//check for update
- (IBAction)checkForUpdate:(id)sender {
    
    //update obj
    Update* update = nil;
    
    //disable update button
    self.updateButton.enabled = NO;
    
    //show/start spinner
    [self.updateIndicator startAnimation:self];
    
    //init update obj
    update = [[Update alloc] init];
    
    //check for update
    [update checkForUpdate:^(NSUInteger result, NSString* newVersion) {
            
        //process response
        [self updateResponse:result newVersion:newVersion];
            
    }];

    return;
}

//process update response
// error, no update, update/new version
-(void)updateResponse:(NSInteger)result newVersion:(NSString*)newVersion
{
    //re-enable button
    self.updateButton.enabled = YES;
    
    //stop/hide spinner
    [self.updateIndicator stopAnimation:self];
    
    switch(result)
    {
        //error
        case Update_Error:
            
            //show alert
            showAlert(NSAlertStyleWarning, NSLocalizedString(@"ERROR: Update Check Failed", @"ERROR: Update Check Failed"), nil, @[NSLocalizedString(@"OK", @"OK")]);
            
            break;
            
        //no updates
        case Update_None:
            
            //show alert
            showAlert(NSAlertStyleWarning, NSLocalizedString(@"No Update Available", @"No Update Available"), [NSString stringWithFormat:NSLocalizedString(@"Installed version (%@),\r\nis the latest.", @"Installed version (%@),\r\nis the latest."), getAppVersion()], @[NSLocalizedString(@"OK", @"OK")]);
    
            break;
            
        //update is not compatible
        case Update_NotSupported:
            
            //show alert
            showAlert(NSAlertStyleWarning, NSLocalizedString(@"Update Available", @"Update available"), [NSString stringWithFormat:NSLocalizedString(@"...but isn't supported on macOS %ld.%ld", @"...but isn't supported on macOS %ld.%ld"), NSProcessInfo.processInfo.operatingSystemVersion.majorVersion, NSProcessInfo.processInfo.operatingSystemVersion.minorVersion], @[NSLocalizedString(@"OK", @"OK")]);

            break;
         
        //new version
        case Update_Available:
        {
            //show alert
            NSModalResponse response = showAlert(NSAlertStyleWarning, NSLocalizedString(@"Update available!", @"Update available!"), nil, @[NSLocalizedString(@"Update", @"Update"), NSLocalizedString(@"Ignore", @"Ignore")]);
            
            //open link to tool page w/ update
            if(NSAlertFirstButtonReturn == response)
            {
                //open
                [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:PRODUCT_PAGE]];
            }
            
            break;
        }
    }
    
    return;
}

//show an alert
NSModalResponse showAlert(NSAlertStyle style, NSString* messageText, NSString* informativeText, NSArray* buttons)
{
    //alert
    NSAlert* alert = nil;
    
    //response
    NSModalResponse response = 0;
    
    //init alert
    alert = [[NSAlert alloc] init];
    
    //set style
    alert.alertStyle = style;
    
    //main text
    alert.messageText = messageText;
    
    //add details
    if(nil != informativeText)
    {
        //details
        alert.informativeText = informativeText;
    }
    
    //add buttons
    for(NSString* title in buttons)
    {
        //add button
        [alert addButtonWithTitle:title];
    }

    //make first button, first responder
    alert.buttons[0].keyEquivalent = @"\r";

    //make alert window front
    [alert.window makeKeyAndOrderFront:nil];
    
    //center
    [alert.window center];
    
    //show
    response = [alert runModal];
    
    return response;
}

//automatically close app
-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

//'ok' button handler
// save settings and close
-(IBAction)close:(id)sender
{
    //set
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP];
    [sharedDefaults setBool:(self.enableExtDrivesButton.state == NSControlStateValueOn) forKey:PREF_ENABLE_ON_EXTERNAL_DRIVES];
    
    //dbg msg
    os_log_debug(OS_LOG_DEFAULT, "WYS: sharedDefaults: %{public}@", sharedDefaults);
    os_log_debug(OS_LOG_DEFAULT, "WYS: sharedDefaults: %d", [sharedDefaults boolForKey:PREF_ENABLE_ON_EXTERNAL_DRIVES]);
    
    //broadcast
    // maybe prefs changed
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:PREFS_CHANGED_NOTIFICATION object:nil userInfo:nil deliverImmediately:YES];
    
    //good bye!
    [NSApp terminate:self];

    return;
}

@end
