//
//  ConfigureWindowController.m
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Configure.h"
#import "utilities.h"
#import "ConfigureWindowController.h"

@implementation ConfigureWindowController

@synthesize statusMsg;
@synthesize moreInfoButton;

//automatically called when nib is loaded
// ->just center window
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    //indicate title bar is transparent (too)
    self.window.titlebarAppearsTransparent = YES;
    
    //make first responder
    // calling this without a timeout sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        //and make it first responder
        [self.window makeFirstResponder:self.installButton];
        
    });

    return;
}

//configure window/buttons
// also brings window to front
-(void)configure:(BOOL)isInstalled
{
    //set window title
    [self window].title = [NSString stringWithFormat:@"WYS v%@", getAppVersion()];
    
    //emoji support, 10.11+
    if(@available(macOS 10.11, *))
    {
        //init status msg
        [self.statusMsg setStringValue:@"Code-signing info via the UI 🔏"];
    }
    //no emoji support :(
    else
    {
        //init status msg
        [self.statusMsg setStringValue:@"Code-signing info via the UI."];
    }
    
    //app already installed?
    // enable 'uninstall' button
    // change install button to say 'upgrade'
    if(YES == isInstalled)
    {
        //enable 'uninstall'
        self.uninstallButton.enabled = YES;
        
        //set to 'upgrade'
        self.installButton.title = ACTION_UPGRADE;
    }
    //otherwise disable
    else
    {
        //disable
        self.uninstallButton.enabled = NO;
    }
    
    //set delegate
    [self.window setDelegate:self];

    return;
}

//display (show) window
// ->center, make front, set bg to white, etc
-(void)display
{
    //center window
    [[self window] center];
    
    //show (now configured) windows
    [self showWindow:self];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }

    return;
}

//button handler for uninstall/install
-(IBAction)buttonHandler:(id)sender
{
    //action
    NSUInteger action = 0;
    
    //uninstall flag
    __block BOOL uninstalled = NO;
    
    //dbg msg
    //#ifdef DEBUG
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"handling action click: %@", ((NSButton*)sender).title]);
    //#endif
    
    //grab tag
    action = ((NSButton*)sender).tag;
    
    //'close'?
    // close window to trigger exit logic
    if(ACTION_CLOSE_FLAG == action)
    {
        //close
        [self.window close];
        
        //bail
        goto bail;
    }
    
    //'restart'?
    // restart Finder, and then exit (uninstall) or update UI (install)
    else if(ACTION_RESTART_FLAG == action)
    {
        //relaunch in background
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            //relaunch
            restartFinder();
        });
        
        //set flag
        // need to know if user uninstalled (to exit app now)
        uninstalled = [self.statusMsg.stringValue containsString:@"uninstall"];
        
        //update button tag
        self.installButton.enabled = NO;
        
        //show spinner
        self.activityIndicator.hidden = NO;
        
        //start spinning
        [self.activityIndicator startAnimation:nil];
        
        //set font back to normal
        self.statusMsg.font = [NSFont fontWithName:@"Menlo" size:13];
        
        //set message
        self.statusMsg.stringValue = @"...restarting Finder.app";
        
        //after a bit
        // on uninstall: close app
        // on install:   update UI to complete install
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            //check if we're here cuz of an uninstall
            // and if so, close the app
            if(YES == uninstalled)
            {
                //set message
                self.statusMsg.stringValue = @"...now exiting, goodbye!";
                
                //close app after 1 second
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    
                    //close app
                    [NSApp terminate:self];
                    
                    //done
                    return;
                });
            }
            
            //installed
            // update UI
            else
            {
                //update button tag
                self.installButton.enabled = YES;
                
                //stop spinning
                [self.activityIndicator stopAnimation:nil];
                
                //hide spinner
                self.activityIndicator.hidden = YES;
                
                //set to bold
                self.statusMsg.font = [NSFont fontWithName:@"Menlo-Bold" size:13];
                
                //set msg
                self.statusMsg.stringValue = @"WhatsYourSign installed!";
                
                //update button tag
                self.installButton.tag = ACTION_NEXT_FLAG;
                
                //update button title
                self.installButton.title = ACTION_NEXT;
                
                //and make it first responder
                [self.window makeFirstResponder:self.installButton];
            }
        });
        
        //bail
        goto bail;
    }

    //'next'?
    // show 'Support Us' view
    else if(ACTION_NEXT_FLAG == action)
    {
        //unset window title
        self.window.title = @"";
        
        //set content view size
        self.window.contentSize = self.supportView.frame.size;
        
        //update config view
        self.window.contentView = self.supportView;

        //not in dark mode?
        // set view color to white
        if(YES != isDarkMode())
        {
            //set view color to white
            self.supportView.layer.backgroundColor = NSColor.whiteColor.CGColor;
        }
        
        //force redraw of status msg
        self.window.contentView.needsDisplay = YES;
        
        //nap for UI purposes
        [NSThread sleepForTimeInterval:0.10f];
        
        //...and also make it first responder
        // calling this without a timeout sometimes fails :/
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            //and make it first responder
            [self.window makeFirstResponder:self.supportButton];
            
        });
        
        //ok to re-enable 'x' button
        [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:YES];
        
        //bail
        goto bail;
    }
    
    //'yes'?'
    // load supprt in URL
    else if(ACTION_SUPPORT_FLAG == action)
    {
        //open URL
        // invokes user's default browser
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:PATREON_URL]];
        
        //close
        [self.window close];
        
        //bail
        goto bail;
    }
    
    //install/uninstall logic handlers
    else
    {
        //hide 'get more info' button
        self.moreInfoButton.hidden = YES;
        
        //disable 'x' button
        // don't want user killing app during install/upgrade
        [[self.window standardWindowButton:NSWindowCloseButton] setEnabled:NO];
        
        //clear status msg
        self.statusMsg.stringValue = @"";
        
        //force redraw of status msg
        // ->sometime doesn't refresh (e.g. slow VM)
        [self.statusMsg setNeedsDisplay:YES];
        
        //invoke logic to install/uninstall
        // ->do in background so UI doesn't block
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
            //install/uninstall
            [self lifeCycleEvent:action];
        });
    }
    
bail:
    
    return;
}

//button handler for '?' button (on an error)
// ->load objective-see's documentation for error(s) in default browser
-(IBAction)info:(id)sender
{
    //url
    NSURL *helpURL = nil;
    
    //build help URL
    helpURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@#errors", PRODUCT_URL]];
    
    //open URL
    // ->invokes user's default browser
    [[NSWorkspace sharedWorkspace] openURL:helpURL];
    
    return;
}

//perform install | uninstall via Control obj
// ->invoked on background thread so that UI doesn't block
-(void)lifeCycleEvent:(NSUInteger)event
{
    //status var
    BOOL status = NO;
    
    //configure object
    Configure* configureObj = nil;
    
    //alloc control object
    configureObj = [[Configure alloc] init];
    
    //begin event
    // ->updates ui on main thread
    dispatch_sync(dispatch_get_main_queue(),
    ^{
        //complete
        [self beginEvent:event];
    });
    
    //sleep
    // ->allow 'install' || 'uninstall' msg to show up
    sleep(0.5);
    
    //perform action (install | uninstall)
    // ->perform background actions
    if(YES == [configureObj configure:event])
    {
        //set flag
        status = YES;
    }
    
    //error occurred
    else
    {
        //set flag
        status = NO;
    }
    
    //complet event
    // ->updates ui on main thread
    dispatch_async(dispatch_get_main_queue(),
    ^{
        //complete
        [self completeEvent:status event:event];
    });
    
    return;
}

//begin event
// ->basically just update UI
-(void)beginEvent:(NSUInteger)event
{
    //status msg frame
    CGRect statusMsgFrame = {0};
    
    //grab exiting frame
    statusMsgFrame = self.statusMsg.frame;
    
    //avoid activity indicator
    // ->shift frame shift delta
    statusMsgFrame.origin.x += FRAME_SHIFT;
    
    //update frame to align
    self.statusMsg.frame = statusMsgFrame;
    
    //align text left
    [self.statusMsg setAlignment:NSLeftTextAlignment];
    
    //install msg
    if(ACTION_INSTALL_FLAG == event)
    {
        //update status msg
        [self.statusMsg setStringValue:@"Installing..."];
    }
    //uninstall msg
    else
    {
        //update status msg
        [self.statusMsg setStringValue:@"Uninstalling..."];
    }
    
    //disable action button
    self.uninstallButton.enabled = NO;
    
    //disable cancel button
    self.installButton.enabled = NO;
    
    //show spinner
    [self.activityIndicator setHidden:NO];
    
    //start spinner
    [self.activityIndicator startAnimation:nil];
    
    return;
}

//complete event
// ->update UI after background event has finished
-(void)completeEvent:(BOOL)success event:(NSUInteger)event
{
    //status msg frame
    CGRect statusMsgFrame = {0};
    
    //result msg
    NSString* resultMsg = nil;
    
    //generally want centered text
    [self.statusMsg setAlignment:NSCenterTextAlignment];
    
    //success?
    if(YES == success)
    {
        //install?
        if(ACTION_INSTALL_FLAG == event)
        {
            //set result msg
            resultMsg = @"WhatsYourSign installed!\nRestart 'Finder.app' to complete.";
        }
        //uninstall?
        else
        {
            //set result msg
            resultMsg = @"WhatsYourSign uninstalled!\nRestart 'Finder.app' to complete.";
        }
    }
    //failure
    else
    {
        //set font to red
        self.statusMsg.textColor = NSColor.redColor;
        
        //install failed?
        if(ACTION_INSTALL_FLAG == event)
        {
            //set result msg
            resultMsg = @"Error: install failed.";
        }
        //uninstall failed?
        else
        {
            //set result msg
            resultMsg = @"Error: uninstall failed.";
        }
    
        //show 'get more info' button
        self.moreInfoButton.hidden = NO;
    }
    
    //stop/hide spinner
    [self.activityIndicator stopAnimation:nil];
    
    //hide spinner
    [self.activityIndicator setHidden:YES];
    
    //grab exiting frame
    statusMsgFrame = self.statusMsg.frame;
    
    //shift back since activity indicator is gone
    statusMsgFrame.origin.x -= FRAME_SHIFT;
    
    //update frame to align
    self.statusMsg.frame = statusMsgFrame;
    
    //set font to bold
    self.statusMsg.font = [NSFont fontWithName:@"Menlo-Bold" size:13];
    
    //set status msg
    self.statusMsg.stringValue = resultMsg;
    
    //update button
    // no errors, change button to 'Restart'
    if(YES == success)
    {
        //update button title
        self.installButton.title = ACTION_RESTART;
        
        //update button tag
        self.installButton.tag = ACTION_RESTART_FLAG;
        
        //enable
        self.installButton.enabled = YES;
        
        //and make it first responder
        [self.window makeFirstResponder:self.installButton];
    }
    //update button
    // on error, change button to 'Close'
    else
    {
        //set button title
        self.installButton.title = ACTION_CLOSE;
        
        //update button tag
        self.installButton.tag = ACTION_CLOSE_FLAG;
        
        //disable other button
        self.uninstallButton.enabled = NO;
        
        //...and highlighted
        [self.window makeFirstResponder:self.installButton];
    }
    
    //(re)make window window key
    [self.window makeKeyAndOrderFront:self];
    
    //(re)make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//automatically invoked when window is closing
// just exit application
-(void)windowWillClose:(NSNotification *)notification
{
    //exit
    [NSApp terminate:self];
    
    return;
}

@end
