//
//  HashesWindowController.h
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 12/21/17.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

@import Cocoa;

@interface HashesWindowController : NSWindowController

//hashes
@property(nonatomic, retain)NSDictionary* hashes;

//hash text view
@property (unsafe_unretained) IBOutlet NSTextView *hashList;

//close button
@property (weak) IBOutlet NSButton *closeButton;

@end
