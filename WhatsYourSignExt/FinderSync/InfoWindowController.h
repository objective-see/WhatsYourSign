//
//  InfoWindowController.h
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

@import Cocoa;

#import "ClickableTextField.h"
#import "HashesWindowController.h"
#import "EntitlementsWindowController.h"

@class Item;

@interface InfoWindowController : NSWindowController <NSWindowDelegate>
{
    
}

/* PROPERTIES */

//item object
@property (nonatomic, retain)Item* item;

//top summary
@property (weak) IBOutlet NSTextField *summary;

//top summary details
@property (weak) IBOutlet NSTextField *summaryDetails;

//item's icon
@property (weak) IBOutlet NSImageView *icon;

//item's name
@property (weak) IBOutlet NSTextField *name;

//item's path
@property (weak) IBOutlet NSTextField *path;

//signing icon
@property (weak) IBOutlet NSImageView *signingIcon;

//type
@property (weak) IBOutlet NSTextField *type;

//hashes
@property (weak) IBOutlet ClickableTextField *hashes;

//entitlements
@property (weak) IBOutlet ClickableTextField *entitlements;

//runtime
@property (weak) IBOutlet NSTextField *runtime;

//signing status
@property (weak) IBOutlet NSTextField *signingStatus;

//activity indicator
@property (weak) IBOutlet NSProgressIndicator *activityIndicator;

//hashes popup controller
@property (strong) HashesWindowController *hashesWindowController;

//entitlements popup controller
@property (strong) EntitlementsWindowController *entitlementsWindowController;

//close button
@property (weak) IBOutlet NSButton *closeButton;

/* METHODS */

//process item's code signing info
// ->sets code signing icon, summary, and formats signing auths
-(void)processCodeSigningInfo;

//invoked when user clicks button
// ->trigger action such as opening product website, updating, etc
-(IBAction)closeButtonHandler:(id)sender;

@end
