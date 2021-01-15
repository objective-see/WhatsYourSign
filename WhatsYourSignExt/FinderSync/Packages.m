//
//  Packages.m
//  FinderSync
//
//  Created by Patrick Wardle on 12/12/20.
//  Copyright (c) 2020 Objective-See. All rights reserved.
//

#import "consts.h"
#import "Packages.h"
#import "utilities.h"
#import "packageKit.h"

#import <os/log.h>

//check signing info for .pkg
NSMutableDictionary* checkPackage(NSString* package)
{
    //info dictionary
    NSMutableDictionary* info = nil;
    
    //bundle
    NSBundle* packageKit = nil;
    
    //class
    Class PKArchiveCls = nil;
    
    //archive
    PKXARArchive* archive = nil;
    
    //error
    NSError* error = nil;
    
    //signatures
    NSArray* signatures = nil;
    
    //(leaf?) signature
    PKArchiveSignature* signature = nil;
    
    //signature trust ref
    struct __SecTrust* trustRef = NULL;
    
    //class
    Class PKTrustCls = nil;
    
    //trust
    PKTrust* pkTrust = nil;
    
    //certificate name
    CFStringRef certificateName = NULL;
    
    //dbg msg
    os_log(OS_LOG_DEFAULT, "WYS: checking package (.pkg)...");
    
    //init
    info = [NSMutableDictionary dictionary];
    
    //default
    // covers error cases
    info[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:errSecCSInternalError];
    
    //load packagekit framework
    if(YES != [packageKit = [NSBundle bundleWithPath:PACKAGE_KIT] load])
    {
        //bail
        goto bail;
    }
    
    //`PKArchive` class
    if(nil == (PKArchiveCls = NSClassFromString(@"PKArchive")))
    {
        //bail
        goto bail;
    }
    
    //sanity check
    // method: 'archiveWithPath:'
    if(YES != [PKArchiveCls respondsToSelector:@selector(archiveWithPath:)])
    {
        //bail
        goto bail;
    }
    
    //init archive from .pkg
    if(nil == (archive = [PKArchiveCls archiveWithPath:package]))
    {
        //bail
        goto bail;
    }
    
    //sanity check
    // method: 'verifyReturningError:'
    if(YES != [archive respondsToSelector:@selector(verifyReturningError:)])
    {
        //bail
        goto bail;
    }
    
    //basic validation
    // this checks checksum, etc
    if(YES != [archive verifyReturningError:&error])
    {
        //bail
        goto bail;
    }
    
    //sanity check
    // iVar: `archiveSignatures`
    if(YES != [archive respondsToSelector:NSSelectorFromString(@"archiveSignatures")])
    {
        //bail
        goto bail;
    }
    
    //dbg msg
    os_log(OS_LOG_DEFAULT, "WYS: extracting signatures...");
    
    //extract signatures
    signatures = archive.archiveSignatures;
    if(0 == signatures.count)
    {
        //dbg msg
        os_log(OS_LOG_DEFAULT, "WYS: package has no signatures (unsigned)");
        
        //unsigned!
        info[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:errSecCSUnsigned];
        
        //bail
        goto bail;
    }
    
    //extract leaf signature
    signature = signatures.firstObject;
    
    //sanity check
    if(YES != [signature respondsToSelector:@selector(verifySignedDataReturningError:)])
    {
        //bail
        goto bail;
    }
    
    //validate leaf (child?) signature
    if(YES != [signature verifySignedDataReturningError:&error])
    {
        //bail
        goto bail;
    }
    
    //sanity check
    if(YES != [signature respondsToSelector:NSSelectorFromString(@"verificationTrustRef")])
    {
        //bail
        goto bail;
    }
    
    //'PKTrust' class
    PKTrustCls = NSClassFromString(@"PKTrust");
    if(nil == PKTrustCls)
    {
        //bail
        goto bail;
    }
    
    //alloc pk trust
    pkTrust = [PKTrustCls alloc];
    
    //extract signature trust ref
    trustRef = [signature verificationTrustRef];
    
    //validate via trust ref
    if(nil != trustRef)
    {
        //sanity check
        if(YES != [pkTrust respondsToSelector:@selector(initWithSecTrust:usingAppleRoot:signatureDate:)])
        {
            //bail
            goto bail;
        }
        
        //init
        pkTrust = [pkTrust initWithSecTrust:trustRef usingAppleRoot:YES signatureDate:archive.archiveSignatureDate];
        if(NULL == pkTrust)
        {
            //bail
            goto bail;
        }
    }
    //validate via certs
    else
    {
        //sanity check
        if(YES != [pkTrust respondsToSelector:@selector(initWithCertificates:usingAppleRoot:signatureDate:)])
        {
            //bail
            goto bail;
        }
        
        //init
        pkTrust = [pkTrust initWithCertificates:signature.certificateRefs usingAppleRoot:YES signatureDate:archive.archiveSignatureDate];
        if(NULL == pkTrust)
        {
            //bail
            goto bail;
        }
    }
    
    //sanity check
    // object support: `evaluateTrustReturningError`?
    if(YES != [pkTrust respondsToSelector:@selector(evaluateTrustReturningError:)])
    {
        //bail
        goto bail;
    }
    
    //validate
    if(YES != [pkTrust evaluateTrustReturningError:&error])
    {
        //bail
        goto bail;
    }
    
    //happily signed
    info[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:noErr];
    
    //init auths
    info[KEY_SIGNING_AUTHORITIES] = [NSMutableArray array];
    
    //ok happily validated
    // extract signature name(s)
    for(id certificate in signature.certificateRefs)
    {
        //extract name
        if(errSecSuccess == SecCertificateCopyCommonName((__bridge SecCertificateRef)certificate, &certificateName))
        {
            //add
            [info[KEY_SIGNING_AUTHORITIES] addObject:CFBridgingRelease(certificateName)];
        }
    }
    
bail:
    
    return info;
}


