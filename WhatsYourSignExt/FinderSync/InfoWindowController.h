//
//  InfoWindowController.h
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//


#import <Cocoa/Cocoa.h>

#import "ClickableTextField.h"
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

//entitlements
@property (weak) IBOutlet NSTextField *entitlements;

//signing status
@property (weak) IBOutlet NSTextField *signingStatus;

//activity indicator
@property (weak) IBOutlet NSProgressIndicator *activityIndicator;

//entitlements popup controller
@property (strong) EntitlementsWindowController *entitlementsWindowController;

/* METHODS */

//process item's code signing info
// ->sets code signing icon, summary, and formats signing auths
-(void)processCodeSigningInfo;

//invoked when user clicks button
// ->trigger action such as opening product website, updating, etc
-(IBAction)closeButtonHandler:(id)sender;

@end
