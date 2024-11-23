//
//  File: Signing.h
//  Project: Proc Info
//
//  Created by: Patrick Wardle
//  Copyright:  2017 Objective-See
//  License:    Creative Commons Attribution-NonCommercial 4.0 International License
//

#ifndef Signing_h
#define Signing_h

@import AppKit;
@import Foundation;

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

//check if file is (likely) fat binary
BOOL isBinaryFat(NSString* path);

//get the signing info of a file
NSMutableDictionary* extractSigningInfo(NSString* path, SecCSFlags flags, BOOL entitlements);

//determine if a file is signed by Apple proper
BOOL isApple(NSString* path, SecCSFlags flags);

//determine if file is signed with Apple Dev ID/cert
BOOL isSignedDevID(NSString* path, SecCSFlags flags);

//determine if a file is from the app store
// gotta be signed w/ Apple Dev ID & have valid app receipt
BOOL fromAppStore(NSString* path);

//get GUID (really just computer's MAC address)
// from Apple's 'Get the GUID in OS X' (see: 'Validating Receipts Locally')
NSData* getGUID(void);

#endif
