//
//  InfoWindowController.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Item.h"
#import "Consts.h"
#import "Utilities.h"
#import "AppDelegate.h"
#import "InfoWindowController.h"

@implementation InfoWindowController

@synthesize icon;
@synthesize name;
@synthesize path;
@synthesize hashes;
@synthesize closeButton;
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
    
    //not in dark mode?
    // make window white
    if(YES != isDarkMode())
    {
        //make white
        self.window.backgroundColor = NSColor.whiteColor;
    }
    
    //set name
    self.name.stringValue = self.item.name;
    
    //set path
    self.path.stringValue = self.item.path;
    
    //set icon
    self.icon.image = [self.item getIcon];
    
    //set type
    self.type.stringValue = self.item.type.capitalizedString;
    
    //show spinner
    [self.activityIndicator setHidden:NO];
    
    //start spinner
    [self.activityIndicator startAnimation:nil];
    
    //make it key window
    [self.window makeKeyAndOrderFront:self];
    
    //make window front
    [NSApp activateIgnoringOtherApps:YES];
    
    //make 'close' first responder
    // calling this without a timeout sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        //and make it first responder
        [self.window makeFirstResponder:self.closeButton];
        
    });
    
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
        case errSecSuccess:
            
            //init string for details
            csDetails = [NSMutableString string];
            
            //append to summary
            [csSummary appendFormat:@" is validly signed"];
            
            //no signing auths
            // usually (always?) adhoc
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
            
            //disk images/packages
            // don't have much info about who signed it
            if( (NSOrderedSame == [self.item.path.pathExtension caseInsensitiveCompare:@"dmg"]) ||
                (NSOrderedSame == [self.item.path.pathExtension caseInsensitiveCompare:@"pkg"]) )
            {
                //set icon to default (signed)
                csIcon = [NSImage imageNamed:@"signed"];
                
                //notarized ok
                if(errSecSuccess == [self.item.signingInfo[KEY_SIGNING_IS_NOTARIZED] integerValue])
                {
                    //append to summary
                    [csSummary appendFormat:@" & notarized"];
                }
                //notarization revoked
                else if(errSecCSRevokedNotarization == [self.item.signingInfo[KEY_SIGNING_IS_NOTARIZED] integerValue])
                {
                    //append to summary
                    [csSummary appendFormat:@", but notarization revoked!"];
                }
                
                //done
                break;
            }
            
            //item signed by apple
            if(YES == [self.item.signingInfo[KEY_SIGNING_IS_APPLE] boolValue])
            {
                //set icon
                csIcon = [NSImage imageNamed:@"signedApple"];
                
                //set summary details
                self.summaryDetails.stringValue = @"(Signer: Apple)";
            }
            //item signed, third party/ad hoc, etc
            else
            {
                //set
                csIcon = [NSImage imageNamed:@"signed"];
                
                //from app store?
                if(YES == [self.item.signingInfo[KEY_SIGNING_IS_APP_STORE] boolValue])
                {
                    //set summary details
                    self.summaryDetails.stringValue = @"(Signer: Mac App Store)";
                }
                //developer id?
                // but not from app store
                else if(YES == [self.item.signingInfo[KEY_SIGNING_IS_APPLE_DEV_ID] boolValue])
                {
                    //is/was notarized?
                    if(nil != self.item.signingInfo[KEY_SIGNING_IS_NOTARIZED])
                    {
                        //notarized ok
                        if(errSecSuccess == [self.item.signingInfo[KEY_SIGNING_IS_NOTARIZED] integerValue])
                        {
                            //append to summary
                            [csSummary appendFormat:@" & notarized"];
                        }
                        //notarization revoked
                        else if(errSecCSRevokedNotarization == [self.item.signingInfo[KEY_SIGNING_IS_NOTARIZED] integerValue])
                        {
                            //append to summary
                            [csSummary appendFormat:@", but notarization revoked!"];
                        }
                    }
        
                    //set summary details
                    self.summaryDetails.stringValue = @"(Signer: Apple Dev-ID)";
                }
                //something else
                // ad hoc? 3rd-party?
                else
                {
                    //set summary details
                    self.summaryDetails.stringValue = @"(Signer 3rd-party (adhoc?))";
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
            csDetails = [NSMutableString stringWithString:@"Unsigned ('errSecCSUnsigned')"];
            
            break;
            
        //revoked
        case CSSMERR_TP_CERT_REVOKED:
            
            //set image
            csIcon = [NSImage imageNamed:@"unsigned"];
            
            //append to summary
            [csSummary appendFormat:@" signed, but certificate revoked!"];
            
            //init string for details
            csDetails = [NSMutableString string];
            
            //no signing auths
            // usually (always?) adhoc
            if(0 == [self.item.signingInfo[KEY_SIGNING_AUTHORITIES] count])
            {
                //append to details
                [csDetails appendString:@"Unavailable, as certificate has been revoked"];
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
            
        //access denied
        case kPOSIXErrorEACCES:
            
            //set image
            csIcon = [NSImage imageNamed:@"unknown"];
            
            //append to summary
            [csSummary appendFormat:@" could not be accessed"];
            
            //details
            csDetails = [@"" mutableCopy];
        
            break;
 
        //everything else
        // other signing errors
        default:
            
            //set image
            csIcon = [NSImage imageNamed:@"unknown"];
            
            //append to summary
            [csSummary appendFormat:@" has a signing issue"];
            
            //set details
            csDetails = [NSMutableString stringWithFormat:@"Unknown (status/error: %ld)", (long)[self.item.signingInfo[KEY_SIGNATURE_STATUS] integerValue]];
            
            break;
    }
    
    //assign icon to outlet
    self.signingIcon.image = csIcon;
    
    //assign summary to outlet
    if(0 != csSummary.length)
    {
        //set
        self.summary.stringValue = csSummary;
    }
    
    //no hashes?
    if(nil == self.item.hashes)
    {
        //bundle?
        // give a more specific error msg
        if( (YES == [[NSFileManager defaultManager] fileExistsAtPath:self.item.path isDirectory:&isDirectory]) &&
            (YES == isDirectory) )
        {
            //set
            self.hashes.stringValue = @"None (item is a directory)";
        }
        //generic error msg
        else
        {
            //set
            self.hashes.stringValue = @"?";
        }
    }
    //create clickable 'show hashes' label
    else
    {
        //create/set attributes string
        self.hashes.attributedStringValue = [[NSMutableAttributedString alloc] initWithString:@"View Hashes" attributes:@{NSLinkAttributeName:[NSURL URLWithString:@"#"], NSForegroundColorAttributeName:[NSColor blueColor], NSUnderlineStyleAttributeName:[NSNumber numberWithInt:NSSingleUnderlineStyle]}];
        
        //add click event handler
        [self.hashes addGestureRecognizer:[[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(showHashes:)]];
    }
    
    //no entitlements?
    if(0 == [self.item.signingInfo[KEY_SIGNING_ENTITLEMENTS] count])
    {
        //couldn't access?
        if(kPOSIXErrorEACCES == [self.item.signingInfo[KEY_SIGNATURE_STATUS] intValue])
        {
            self.entitlements.stringValue = @"?";
        }
        //none for real
        else
        {
            //set
            self.entitlements.stringValue = @"None";
        }
    }
    //create clickable 'show entitlements' label
    else
    {
        //create/set attributes string
        self.entitlements.attributedStringValue = [[NSMutableAttributedString alloc] initWithString:@"View Entitlements" attributes:@{NSLinkAttributeName:[NSURL URLWithString:@"#"], NSForegroundColorAttributeName:[NSColor blueColor], NSUnderlineStyleAttributeName:[NSNumber numberWithInt:NSSingleUnderlineStyle]}];
        
        //add click event handler
        [self.entitlements addGestureRecognizer:[[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(showEntitlements:)]];
    }
    
    //have signing auths?
    if(0 != csDetails.length)
    {
        //set
        self.signingStatus.stringValue = csDetails;
    }
    //none
    else
    {
        //set signing auths
        if(kPOSIXErrorEACCES == [self.item.signingInfo[KEY_SIGNATURE_STATUS] intValue])
        {
            self.signingStatus.stringValue = @"?";
        }
        //none for real
        else
        {
            self.signingStatus.stringValue = @"None";
        }
    }
    
    //runtime
    NSNumber* signFlags = self.item.signingInfo[KEY_SIGNING_FLAGS];
    BOOL hardened = (signFlags != nil) &&
		((signFlags.integerValue & kSecCodeSignatureRuntime) != 0);
	NSDictionary* entitlements = self.item.signingInfo[KEY_SIGNING_ENTITLEMENTS];
	BOOL sandboxed = (entitlements != nil) &&
		[entitlements[@"com.apple.security.app-sandbox"] boolValue];
	if (sandboxed)
	{
		if (hardened)
		{
			self.runtime.stringValue = @"Sandboxed, Hardened";
		}
		else
		{
			self.runtime.stringValue = @"Sandboxed";
		}
	}
	else
	{
		if (hardened)
		{
			self.runtime.stringValue = @"Hardened";
		}
		else
		{
			self.runtime.stringValue = @"None";
		}
	}

    return;
}

//invoked when user clicks 'show entitlements'
// display entitlements window pane w/ dictionary
- (void)showHashes:(id)sender
{
    //dbg msg
    //logMsg(LOG_DEBUG, @"showing hashes");
    
    //alloc sheet
    self.hashesWindowController = [[HashesWindowController alloc] initWithWindowNibName:@"HashesWindow"];
    
    //save signing info into iVar
    self.hashesWindowController.hashes = self.item.hashes;
    
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
    //logMsg(LOG_DEBUG, @"showing entitlements");
    
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
// trigger action such as opening product website, updating, etc
-(IBAction)closeButtonHandler:(id)sender
{
    //always close window
    [[self window] close];
        
    return;
}
@end
