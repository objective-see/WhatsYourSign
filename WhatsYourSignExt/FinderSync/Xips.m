//
//  Xips.m
//  FinderSync
//
//  Created by Patrick Wardle on 5/7/18.
//  Copyright (c) 2018 Objective-See. All rights reserved.
//

#import "Xips.h"
#import "Consts.h"
#import "Utilities.h"

/* apple XIP
 
 $ pkgutil --check-signature ~/Downloads/Xcode_8_beta_5.xip
 Package "Xcode_8_beta_5.xip":
 Status: signed Apple Software
 Certificate Chain:
 1. Software Update
 SHA1 fingerprint: 1E 34 E3 91 C6 44 37 DD 24 BE 57 B1 66 7B 2F DA 09 76 E1 FD
 ------------------------
 ...
 
 */

/* apple dev-ID XIP
 
 $ pkgutil --check-signature /Users/patrickw/Downloads/Mac.Linux.USB.Loader.xip
 Package "Mac.Linux.USB.Loader.xip":
 Status: signed by a certificate trusted by Mac OS X
 Certificate Chain:
 1. Developer ID Installer: Ryan Bowring (8PA6GA85US)
 SHA1 fingerprint: 8D EE 85 79 AB E7 CD AE 59 66 80 46 DE 86 75 D1 B8 02 B9 6E
 -----------------------------------------------------------------------------
 2. Developer ID Certification Authority
 ...
 
 */

/* non-apple XIP
 
 $ pkgutil --check-signature ~/Downloads/thisisatest.xip
 Package "thisisatest.xip":
 Status: signed by untrusted certificate
 Certificate Chain:
 1. LCARS
 SHA1 fingerprint: C7 72 90 60 72 22 1E 5F 7C 4E 31 BF 8E 0B 83 A7 D1 8E F8 3D
 -----------------------------------------------------------------------------
 ...
 
 */

//process a XIP
NSMutableDictionary* checkXIP(NSString* archive)
{
    //info dictionary
    NSMutableDictionary* signingStatus = nil;
    
    //results from 'pkgutil' cmd
    NSMutableDictionary* results = nil;
    
    //array of parsed results
    NSArray* parsedResults = nil;
    
    //result
    NSString* result = nil;
    
    //line number
    NSUInteger lineNumber = 0;
    
    //trusted flag
    BOOL trusted = NO;
    
    //init signing status
    signingStatus = [NSMutableDictionary dictionary];
    
    //exec 'pkgutil --check-signature' to check XIP signature
    results = execTask(PKG_UTIL, @[@"--check-signature", archive]);
    if( (0 != [results[EXIT_CODE] intValue]) ||
       (0 == [results[STDOUT] length]) )
    {
        //bail
        goto bail;
    }
    
    //parse results
    // ->format: <file path>: <file types>
    parsedResults = [[[NSString alloc] initWithData:results[STDOUT] encoding:NSUTF8StringEncoding] componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\n"]];
    
    //sanity check
    // ->should be two items in array, <file path> and <file type>
    if(parsedResults.count < 2)
    {
        //bail
        goto bail;
    }
    
    //signing status comes second
    // ->also trim whitespace
    result = [parsedResults[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    //parse result
    // ->first check if from apple
    if(YES == [result containsString:@"signed Apple Software"])
    {
        //signed
        signingStatus[KEY_SIGNATURE_STATUS] = STATUS_SUCCESS;
        
        //by apple
        signingStatus[KEY_SIGNING_IS_APPLE] = @YES;
        
        //set flag
        trusted = YES;
    }
    //not apple
    // ->but signed with trusted cert
    else if(YES == [result containsString:@"signed by a certificate trusted by Mac OS X"])
    {
        //signed
        signingStatus[KEY_SIGNATURE_STATUS] = STATUS_SUCCESS;
        
        //not apple
        signingStatus[KEY_SIGNING_IS_APPLE] = @NO;
        
        //trusted
        trusted = YES;
    }
    //not apple
    // ->but signed with untrusted cert
    else if(YES == [result containsString:@"signed by untrusted certificate"])
    {
        //signed
        signingStatus[KEY_SIGNATURE_STATUS] = STATUS_SUCCESS;
        
        //not apple
        signingStatus[KEY_SIGNING_IS_APPLE] = @NO;
    }
    
    //error
    // not signed, or something else, just bail
    else
    {
        //signed
        signingStatus[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInteger:errSecCSInternalError];
        
        //bail
        goto bail;
    }
    
    //one more sanity check
    // ->should be at least 3 lines for cert chain
    if(parsedResults.count < 3)
    {
        //bail
        goto bail;
    }
    
    //init array for certificate names
    signingStatus[KEY_SIGNING_AUTHORITIES] = [NSMutableArray array];
    
    //extract cert chain
    // format: <digit>. auth
    // for example: 1. Software Update
    for(__strong NSString* line in parsedResults)
    {
        //skip first three lines
        if(lineNumber < 3)
        {
            //inc
            lineNumber++;
            
            //next
            continue;
        }
        
        //trim line
        line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        //skip blank/too short lines
        if( (nil == line) ||
           (line.length < 4) )
        {
            //skip
            continue;
        }
        
        //start with <digit>.
        if( (YES == [[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[line characterAtIndex:0]]) &&
           ('.' == [line characterAtIndex:1]) )
        {
            //add
            [signingStatus[KEY_SIGNING_AUTHORITIES] addObject:[line substringFromIndex:3]];
        }
    }
    
    //check for developer ID?
    // ->XIP has to be trusted and have certain strings
    if(YES == trusted)
    {
        //check signing auths
        if( (YES == [signingStatus[KEY_SIGNING_AUTHORITIES] containsObject:@"Apple Root CA"]) &&
           (YES == [signingStatus[KEY_SIGNING_AUTHORITIES] containsObject:@"Developer ID Certification Authority"]) )
        {
            //set
            signingStatus[KEY_SIGNING_IS_APPLE_DEV_ID] = @YES;
        }
    }
    
    //finally check if its revoked
    // other APIs might not detect/catch this
    if(YES == isRevoked(archive))
    {
        //update status
        signingStatus[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInteger:CSSMERR_TP_CERT_REVOKED];
        
        //bail
        goto bail;
    }
    
bail:
    
    return signingStatus;
}

//check if a file has a cert that has been revoked
// exec 'spctl --assess <path to file>' and looks for 'CSSMERR_TP_CERT_REVOKED'
BOOL isRevoked(NSString* path)
{
    //flag
    BOOL revoked = NO;
    
    //results
    NSMutableDictionary* results = nil;
    
    //exec 'spctl --assess <path to file>'
    results = execTask(SPCTL, @[@"--assess", path]);
    if(YES == [[[NSString alloc] initWithData:results[STDERR] encoding:NSUTF8StringEncoding] containsString:@"CSSMERR_TP_CERT_REVOKED"])
    {
        //revoked
        revoked = YES;
    }
    
bail:
    
    return revoked;
}


