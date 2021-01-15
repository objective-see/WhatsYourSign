//
//  Xips.h
//  WhatsYourSign
//
//  Created by Patrick Wardle on 5/7/18.
//  Copyright (c) 2018 Objective-See. All rights reserved.
//

#ifndef Packages_h
#define Packages_h

//TODO: change to this type
@import Foundation;

/* FUNCTIONS */

//process a pkg
NSMutableDictionary* checkPackage(NSString* package);

//TODO:
//check if a file has a cert that has been revoked
// exec 'spctl --assess <path to file>' and looks for 'CSSMERR_TP_CERT_REVOKED'
BOOL isRevoked(NSString* path);

#endif /* Xips_h */
