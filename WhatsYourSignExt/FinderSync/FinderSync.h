//
//  FinderSync.h
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 7/5/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//


@import Cocoa;
@import FinderSync;

#import "Item.h"
#import "InfoWindowController.h"

@interface FinderSync : FIFinderSync

/* PROPERTIES */

//preferences listener
@property (strong) id<NSObject> prefsObserver;

//directories to watch
@property(nonatomic, retain)NSMutableSet* directories;

@end

