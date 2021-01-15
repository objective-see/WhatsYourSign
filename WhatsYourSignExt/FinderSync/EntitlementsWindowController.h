//
//  EntitlementsWindowController.h
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 12/19/17.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface EntitlementsWindowController : NSWindowController

/* PROPERTIES */

//close button
@property (weak) IBOutlet NSButton *closeButton;

//signing info
@property(nonatomic, retain)NSDictionary* signingInfo;

//entitlements
@property (unsafe_unretained) IBOutlet NSTextView *entitlements;

@end
