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

//type def for 'SecAssessmentTicketFlags'
typedef uint64_t SecAssessmentTicketFlags;
enum {
    kSecAssessmentTicketFlagDefault = 0,
    kSecAssessmentTicketFlagForceOnlineCheck = 1 << 0,
    kSecAssessmentTicketFlagLegacyListCheck = 1 << 1,
};

//function def for 'SecAssessmentTicketLookup'
Boolean SecAssessmentTicketLookup(CFDataRef hash, SecCSDigestAlgorithm hashType, SecAssessmentTicketFlags flags, double *date, CFErrorRef *errors);

/* FUNCTIONS */

//process a pkg
NSMutableDictionary* checkPackage(NSString* package);

//check if pkg is notarized
BOOL isNotarized(PKArchiveSignature* signature);

//check if a file has a cert that has been revoked
// exec 'spctl --assess <path to file>' and looks for 'CSSMERR_TP_CERT_REVOKED'
BOOL isRevoked(NSString* path);

#endif /* Xips_h */
