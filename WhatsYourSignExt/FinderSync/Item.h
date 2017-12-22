//
//  Item.h
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

#import "InfoWindowController.h"

@interface Item : NSObject
{
    
}

/* PROPERTIES */

//window controller
@property(nonatomic, retain)InfoWindowController* windowController;

//name
@property(nonatomic, retain)NSString* name;

//path
@property(nonatomic, retain)NSString* path;

//icon
@property(nonatomic, retain)NSImage* icon;

//type
@property(nonatomic, retain)NSString* type;

//bundle
@property(nonatomic, retain)NSBundle* bundle;

//signing info
@property(nonatomic, retain)NSDictionary* signingInfo;

/* METHODS */

//init method
-(id)init:(NSString*)itemPath;

//get item's name
// ->either from bundle or path's last component
-(NSString*)getName;

//get an icon for a item
-(NSImage*)getIcon;

//get signing info (which takes a while to generate)
// ->this method should be called in the background
-(void)generateSigningInfo;

@end
