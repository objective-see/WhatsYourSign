//
//  InfoWindowController.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Item.h"
#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "InfoWindowController.h"

@implementation InfoWindowController

@synthesize icon;
@synthesize name;
@synthesize path;
@synthesize hashes;
@synthesize signingIcon;
@synthesize entitlements;
@synthesize signingStatus;
@synthesize activityIndicator;
@synthesize entitlementsWindowController;

//automatically called when nib is loaded
// ->center window
-(void)awakeFromNib
{
    //center
    [self.window center];
    
    return;
}

//automatically invoked when window is loaded
// ->set to white
-(void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //indicate title bar is transparent (too)
    self.window.titlebarAppearsTransparent = YES;
    
    //make white
    [self.window setBackgroundColor: NSColor.whiteColor];
    
    //set name
    self.name.stringValue = self.item.name;
    
    //set path
    self.path.stringValue = self.item.path;
    
    //set icon
    self.icon.image = [self.item getIcon];
    
    //set type
    self.type.stringValue = self.item.type;
    
    //show spinner
    [self.activityIndicator setHidden:NO];
    
    //start spinner
    [self.activityIndicator startAnimation:nil];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    return;
}

//process item's code signing info
// ->sets code signing icon, summary, and formats signing auths
-(void)processCodeSigningInfo
{
    //signing icon
    NSImage* csIcon = nil;
    
    //summary (top)
    NSMutableString* csSummary = nil;
    
    //signing details (bottom)
    NSMutableString* csDetails = nil;
    
    //directory flag
    BOOL isDirectory = NO;
    
    //alloc string for summary
    csSummary = [NSMutableString string];
    
    //stop/hide spinner
    [self.activityIndicator stopAnimation:nil];
    
    //hide spinner
    [self.activityIndicator setHidden:YES];
    
    //start summary with item name
    [csSummary appendString:[self.item.name stringByDeletingPathExtension]];

    //process
    switch([self.item.signingInfo[KEY_SIGNATURE_STATUS] intValue])
    {
        //happily signed
        case noErr:
            
            //append to summary
            [csSummary appendFormat:@" is validly signed"];
            
            //item signed by apple
            if(YES == [self.item.signingInfo[KEY_SIGNING_IS_APPLE] boolValue])
            {
                //set icon
                csIcon = [NSImage imageNamed:@"signedApple"];
                
                //append to summary
                [csSummary appendFormat:@" (Apple)"];
            }
            //item signed, third party/ad hoc, etc
            else
            {
                //set
                csIcon = [NSImage imageNamed:@"signed"];
                
                //from app store?
                if(YES == [self.item.signingInfo[KEY_SIGNING_IS_APP_STORE] boolValue])
                {
                    //append to summary
                    [csSummary appendFormat:@" (Mac App Store)"];
                }
                //developer id?
                // ->but not from app store
                else if(YES == [self.item.signingInfo[KEY_SIGNING_IS_APPLE_DEV_ID] boolValue])
                {
                    //append to summary
                    [csSummary appendFormat:@" (Apple Dev-ID)"];
                }
                //something else
                // ad hoc? 3rd-party?
                else
                {
                    //append to summary
                    [csSummary appendFormat:@" (3rd-party)"];
                }
            }
            
            //init string for details
            csDetails = [NSMutableString string];
            
            //no signing auths
            // ->usually (always?) adhoc
            if(0 == [self.item.signingInfo[KEY_SIGNING_AUTHORITIES] count])
            {
                //append to details
                [csDetails appendString:@"signed, but no signing authorities (adhoc?)"];
            }
            
            //add each signing auth
            else
            {
                //add signing auth
                for(NSString* signingAuthority in self.item.signingInfo[KEY_SIGNING_AUTHORITIES])
                {
                    //append to details
                    [csDetails appendString:[NSString stringWithFormat:@"› %@ \n", signingAuthority]];
                }
            }
            
            break;
            
        //unsigned
        case errSecCSUnsigned:
            
            //set image
            csIcon = [NSImage imageNamed:@"unsigned"];
            
            //append to summary
            [csSummary appendFormat:@" is not signed"];
            
            //set details
            csDetails = [NSMutableString stringWithString:@"unsigned ('errSecCSUnsigned')"];
            
            break;
            
        //revoked
        case CSSMERR_TP_CERT_REVOKED:
            
            //set image
            csIcon = [NSImage imageNamed:@"unsigned"];
            
            //append to summary
            [csSummary appendFormat:@" signed, but certificate has been revoked!"];
            
            //init string for details
            csDetails = [NSMutableString string];
            
            //no signing auths
            // ->usually (always?) adhoc
            if(0 == [self.item.signingInfo[KEY_SIGNING_AUTHORITIES] count])
            {
                //append to details
                [csDetails appendString:@"signed, but no signing authorities (adhoc?)"];
            }
            
            //add each signing auth
            else
            {
                //add signing auth
                for(NSString* signingAuthority in self.item.signingInfo[KEY_SIGNING_AUTHORITIES])
                {
                    //append to details
                    [csDetails appendString:[NSString stringWithFormat:@"› %@ \n", signingAuthority]];
                }
            }

            break;
 
        //everything else
        // other signing errors
        default:
            
            //set image
            csIcon = [NSImage imageNamed:@"unknown"];
            
            //append to summary
            [csSummary appendFormat:@" has a signing issue"];
            
            //set details
            csDetails = [NSMutableString stringWithFormat:@"unknown (status/error: %ld)", (long)[self.item.signingInfo[KEY_SIGNATURE_STATUS] integerValue]];
            
            break;
    }
    
    //assign icon to outlet
    self.signingIcon.image = csIcon;
    
    //assign summary to outlet
    self.summary.stringValue = csSummary;
    
    //no hashes?
    if(nil == self.item.signingInfo[KEY_SIGNING_HASHES])
    {
        //bundle?
        // give a more specific error msg
        if( (YES == [[NSFileManager defaultManager] fileExistsAtPath:self.item.path isDirectory:&isDirectory]) &&
            (YES == isDirectory) )
        {
            //set
            self.hashes.stringValue = @"none (item is a directory)";
        }
        //generic error msg
        else
        {
            //set
            self.hashes.stringValue = @"none";
        }
    }
    //create clickable 'show hashes' label
    else
    {
        //create/set attributes string
        self.hashes.attributedStringValue = [[NSMutableAttributedString alloc] initWithString:@"view hashes" attributes:@{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:11], NSLinkAttributeName:[NSURL URLWithString:@"#"], NSForegroundColorAttributeName:[NSColor blueColor], NSUnderlineStyleAttributeName:[NSNumber numberWithInt:NSSingleUnderlineStyle]}];
        
        //add click event handler
        [self.hashes addGestureRecognizer:[[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(showHashes:)]];
    }
    
    //no entitlements?
    if(nil == self.item.signingInfo[KEY_SIGNING_ENTITLEMENTS])
    {
        //set
        self.entitlements.stringValue = @"none";
    }
    //create clickable 'show entitlements' label
    else
    {
        //create/set attributes string
        self.entitlements.attributedStringValue = [[NSMutableAttributedString alloc] initWithString:@"view entitlements" attributes:@{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:11], NSLinkAttributeName:[NSURL URLWithString:@"#"], NSForegroundColorAttributeName:[NSColor blueColor], NSUnderlineStyleAttributeName:[NSNumber numberWithInt:NSSingleUnderlineStyle]}];
        
        //add click event handler
        [self.entitlements addGestureRecognizer:[[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(showEntitlements:)]];
    }

    //assign code-signing auths to outlet
    self.signingStatus.stringValue = csDetails;
    
    return;
}

//invoked when user clicks 'show entitlements'
// display entitlements window pane w/ dictionary
- (void)showHashes:(id)sender
{
    //dbg msg
    logMsg(LOG_DEBUG, @"showing hashes");
    
    //alloc sheet
    self.hashesWindowController = [[HashesWindowController alloc] initWithWindowNibName:@"HashesWindow"];
    
    //save signing info into iVar
    self.hashesWindowController.signingInfo = self.item.signingInfo;
    
    //show hashes
    [self.window beginSheet:self.hashesWindowController.window completionHandler:^(NSModalResponse returnCode) {
        
        //unset window controller
        self.hashesWindowController = nil;
        
    }];
    
    return;
}

//invoked when user clicks 'show hashes'
// display hashe window pane w/ dictionary
- (void)showEntitlements:(id)sender
{
    //dbg msg
    logMsg(LOG_DEBUG, @"showing entitlements");
    
    //alloc sheet
    self.entitlementsWindowController = [[EntitlementsWindowController alloc] initWithWindowNibName:@"EntitlementsWindow"];
    
    //save signing info into iVar
    self.entitlementsWindowController.signingInfo = self.item.signingInfo;
    
    //show entitlements
    [self.window beginSheet:self.entitlementsWindowController.window completionHandler:^(NSModalResponse returnCode) {
        
        //unset window controller
        self.entitlementsWindowController = nil;
        
    }];
    
    return;
}

//invoked when user clicks button
// ->trigger action such as opening product website, updating, etc
-(IBAction)closeButtonHandler:(id)sender
{
    //always close window
    [[self window] close];
        
    return;
}
@end
