//
//  Xips.h
//  WhatsYourSign
//
//  Created by Patrick Wardle on 5/7/18.
//  Copyright (c) 2018 Objective-See. All rights reserved.
//

#ifndef Packages_h
#define Packages_h

@import Foundation;

#import "packageKit.h"

/* FUNCTIONS */

//process a pkg
NSMutableDictionary* checkPackage(NSString* package);

//check if pkg is notarized
OSStatus isNotarized(PKArchiveSignature* signature);

#endif /* Xips_h */
