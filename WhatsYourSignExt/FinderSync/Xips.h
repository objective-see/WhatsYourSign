//
//  Xips.h
//  WhatsYourSign
//
//  Created by Patrick Wardle on 5/7/18.
//  Copyright (c) 2018 Objective-See. All rights reserved.
//

#ifndef Xips_h
#define Xips_h

#import <Foundation/Foundation.h>

/* FUNCTIONS */

//process a XIP
NSMutableDictionary* checkXIP(NSString* archive);

//check if a file has a cert that has been revoked
// exec 'spctl --assess <path to file>' and looks for 'CSSMERR_TP_CERT_REVOKED'
BOOL isRevoked(NSString* path);

#endif /* Xips_h */
