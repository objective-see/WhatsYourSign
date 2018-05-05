//
//  Signing.m
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Signing.h"
#import "Logging.h"
#import "Utilities.h"
#import "AppReceipt.h"

#import <signal.h>
#import <unistd.h>
#import <libproc.h>
#import <sys/sysctl.h>
#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <Security/Security.h>

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
NSDictionary* checkXIP(NSString* archive)
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
    // ->not signed, or something else, just bail
    else
    {
        //signed
        signingStatus[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:errSecCSInternalError];
        
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

//determine the offset (if any)
// of the 'best' architecture in a (fat) binary
uint32_t bestArchOffset(NSString* path)
{
    //offset of best architecture
    uint32_t offset = 0;
    
    //pool
    @autoreleasepool
    {
        
    //binary
    NSMutableData* binary = nil;
    
    //le bytez
    const void* binaryBytes = NULL;
    
    //fat header
    struct fat_header* fatHeader = NULL;
    
    //number of fat architectures
    uint32_t fatArchitectureCount = 0;
    
    //fat architectures
    void *fatArchitectures = NULL;
    
    //local architecture
    const NXArchInfo *localArchitecture = NULL;
    
    //best matching architecture
    struct fat_arch *bestArchitecture = NULL;
    
    //load binary into memory
    binary = [NSMutableData dataWithContentsOfFile:path];
    if(binary.length < sizeof(struct fat_header))
    {
        //bail
        goto bail;
    }
    
    //grab bytes
    binaryBytes = binary.bytes;
    
    //not universal (fat)
    if( (FAT_MAGIC != *(const uint32_t *)binaryBytes) &&
        (FAT_CIGAM != *(const uint32_t *)binaryBytes) )
    {
        //bail
        goto bail;
    }
    
    //binary is fat
    // init pointer to fat header
    fatHeader = (struct fat_header*)binaryBytes;
    
    //swap size?
    if(fatHeader->magic == OSSwapHostToBigInt32(FAT_MAGIC))
    {
        //swap
        fatArchitectureCount = OSSwapBigToHostInt32(fatHeader->nfat_arch);
    }
    
    //sanity check
    if(binary.length <= sizeof(struct fat_header) + fatArchitectureCount * sizeof(struct fat_arch))
    {
        //bail
        goto bail;
    }
    
    //init pointer to fat architectures
    fatArchitectures = (char*)binaryBytes + sizeof(struct fat_header);
    
    //get local architecture
    localArchitecture = NXGetLocalArchInfo();
    
    //swap fat architectures?
    if(fatHeader->magic == OSSwapHostToBigInt32(FAT_MAGIC))
    {
        //swap
        swap_fat_arch(fatArchitectures, fatArchitectureCount, localArchitecture->byteorder);
    }
    
    //find best architecture
    bestArchitecture = NXFindBestFatArch(localArchitecture->cputype, localArchitecture->cpusubtype, fatArchitectures, fatArchitectureCount);
    if(NULL == bestArchitecture)
    {
        //bail
        goto bail;
    }
    
    //init offset
    offset = bestArchitecture->offset;
        
bail:
      ;
        
    }//autorelease
    
    return offset;
}

//get the signing info of a item
NSDictionary* extractSigningInfo(NSString* path, SecCSFlags flags)
{
    //info dictionary
    NSMutableDictionary* signingStatus = nil;
    
    //offset of best architecture
    // for universal/fat binary, need to check correct arch
    uint32_t offset = 0;
    
    //code
    SecStaticCodeRef staticCode = NULL;
    
    //status
    OSStatus status = -1;
    
    //signing information
    CFDictionaryRef signingInformation = NULL;
    
    //cert chain
    NSArray* certificateChain = nil;
    
    //index
    NSUInteger index = 0;
    
    //cert
    SecCertificateRef certificate = NULL;
    
    //common name on chert
    CFStringRef commonName = NULL;
    
    //init signing status
    signingStatus = [NSMutableDictionary dictionary];
    
    //sanity check
    if(nil == path)
    {
        //set err
        signingStatus[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:errSecCSObjectRequired];
        
        //bail
        goto bail;
    }
    
    //get offset of 'best' architecute
    // this is what loader will run, and thus, what we should validate!
    offset = bestArchOffset(path);
    
    //create static code
    status = SecStaticCodeCreateWithPathAndAttributes((__bridge CFURLRef)([NSURL fileURLWithPath:path]), kSecCSDefaultFlags, (__bridge CFDictionaryRef)@{(__bridge NSString *)kSecCodeAttributeUniversalFileOffset : [NSNumber numberWithUnsignedInt:offset]}, &staticCode);
    
    //save signature status
    signingStatus[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:status];
    if(noErr != status)
    {
        //bail
        goto bail;
    }
    
    //check signature
    status = SecStaticCodeCheckValidity(staticCode, flags, NULL);
    
    //(re)save signature status
    signingStatus[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInt:status];
    
    //if file is signed
    // grab signing authorities
    if(noErr == status)
    {
        //grab signing authorities
        status = SecCodeCopySigningInformation(staticCode, kSecCSSigningInformation, &signingInformation);
        if(noErr != status)
        {
            //bail
            goto bail;
        }
        
        //determine if binary is signed by Apple
        signingStatus[KEY_SIGNING_IS_APPLE] = [NSNumber numberWithBool:isApple(path, flags)];
        
        //not apple proper
        // is signed with Apple Dev ID?
        if(YES != [signingStatus[KEY_SIGNING_IS_APPLE] boolValue])
        {
            //determine if binary is Apple Dev ID
            signingStatus[KEY_SIGNING_IS_APPLE_DEV_ID] = [NSNumber numberWithBool:isSignedDevID(path, flags)];
            
            //if dev id
            // from app store?
            if(YES == [signingStatus[KEY_SIGNING_IS_APPLE_DEV_ID] boolValue])
            {
                //from app store?
                signingStatus[KEY_SIGNING_IS_APP_STORE] = [NSNumber numberWithBool:fromAppStore(path)];
            }
        }
    }
    //error
    // not signed, or something else, so no need to check cert's names
    else
    {
        //bail
        goto bail;
    }
    
    //init array for certificate names
    signingStatus[KEY_SIGNING_AUTHORITIES] = [NSMutableArray array];
    
    //get cert chain
    certificateChain = [(__bridge NSDictionary*)signingInformation objectForKey:(__bridge NSString*)kSecCodeInfoCertificates];
    
    //get name of all certs
    // add each to list
    for(index = 0; index < certificateChain.count; index++)
    {
        //extract cert
        certificate = (__bridge SecCertificateRef)([certificateChain objectAtIndex:index]);
        
        //get common name
        status = SecCertificateCopyCommonName(certificate, &commonName);
        
        //skip ones that error out
        if( (noErr != status) ||
           (NULL == commonName))
        {
            //skip
            continue;
        }
        
        //save
        [signingStatus[KEY_SIGNING_AUTHORITIES] addObject:(__bridge NSString*)commonName];
        
        //release name
        CFRelease(commonName);
    }
    
bail:
    
    //free signing info
    if(NULL != signingInformation)
    {
        //free
        CFRelease(signingInformation);
        
        //unset
        signingInformation = NULL;
    }
    
    //free static code
    if(NULL != staticCode)
    {
        //free
        CFRelease(staticCode);
        
        //unset
        staticCode = NULL;
    }
    
    return signingStatus;
}

//determine if a file is signed by Apple proper
BOOL isApple(NSString* path, SecCSFlags flags)
{
    //flag
    BOOL isApple = NO;
    
    //code
    SecStaticCodeRef staticCode = NULL;
    
    //signing reqs
    SecRequirementRef requirementRef = NULL;
    
    //status
    OSStatus status = -1;
    
    //create static code
    status = SecStaticCodeCreateWithPath((__bridge CFURLRef)([NSURL fileURLWithPath:path]), kSecCSDefaultFlags, &staticCode);
    if(noErr != status)
    {
        //bail
        goto bail;
    }
    
    //create req string w/ 'anchor apple'
    // (3rd party: 'anchor apple generic')
    status = SecRequirementCreateWithString(CFSTR("anchor apple"), kSecCSDefaultFlags, &requirementRef);
    if( (noErr != status) ||
       (requirementRef == NULL) )
    {
        //bail
        goto bail;
    }
    
    //check if file is signed by apple by checking if it conforms to req string
    // note: ignore 'errSecCSBadResource' as lots of signed apple files return this issue :/
    status = SecStaticCodeCheckValidity(staticCode, flags, requirementRef);
    if( (noErr != status) &&
       (errSecCSBadResource != status) )
    {
        //bail
        // just means isn't signed by apple
        goto bail;
    }
    
    //ok, happy (SecStaticCodeCheckValidity() didn't fail)
    // file is signed by Apple
    isApple = YES;
    
bail:
    
    //free req reference
    if(NULL != requirementRef)
    {
        //free
        CFRelease(requirementRef);
        
        //unset
        requirementRef = NULL;
    }
    
    //free static code
    if(NULL != staticCode)
    {
        //free
        CFRelease(staticCode);
        
        //unset
        staticCode = NULL;
    }
    
    return isApple;
}

//verify the receipt
// check bundle ID, app version, and receipt's hash
BOOL verifyReceipt(NSBundle* appBundle, AppReceipt* receipt)
{
    //flag
    BOOL verified = NO;
    
    //guid
    NSData* guid = nil;
    
    //hash data
    NSMutableData *digestData = nil;
    
    //hash buffer
    unsigned char digestBuffer[CC_SHA1_DIGEST_LENGTH] = {0};
    
    //check guid
    guid = getGUID();
    if(nil == guid)
    {
        //bail
        goto bail;
    }
    
    //create data obj
    digestData = [NSMutableData data];
    
    //add guid to data obj
    [digestData appendData:guid];
    
    //add receipt's 'opaque value' to data obj
    [digestData appendData:receipt.opaqueValue];
    
    //add receipt's bundle id data to data obj
    [digestData appendData:receipt.bundleIdentifierData];
    
    //CHECK 1:
    // app's bundle ID should match receipt's bundle ID
    if(YES != [receipt.bundleIdentifier isEqualToString:appBundle.bundleIdentifier])
    {
        //bail
        goto bail;
    }
    
    //CHECK 2:
    // app's version should match receipt's version
    if(YES != [receipt.appVersion isEqualToString:appBundle.infoDictionary[@"CFBundleShortVersionString"]])
    {
        //bail
        goto bail;
    }
    
    //CHECK 3:
    // verify receipt's hash (UUID)
    
    //init SHA 1 hash
    CC_SHA1(digestData.bytes, (CC_LONG)digestData.length, digestBuffer);
    
    //check for hash match
    if(0 != memcmp(digestBuffer, receipt.receiptHash.bytes, CC_SHA1_DIGEST_LENGTH))
    {
        //hash check failed
        goto bail;
    }
    
    //happy
    verified = YES;
    
bail:
    
    return verified;
}

//get GUID (really just computer's MAC address)
// from Apple's 'Get the GUID in OS X' (see: 'Validating Receipts Locally')
NSData* getGUID()
{
    //status var
    __block kern_return_t kernResult = -1;
    
    //master port
    __block mach_port_t  masterPort = 0;
    
    //matching dictionar
    __block CFMutableDictionaryRef matchingDict = NULL;
    
    //iterator
    __block io_iterator_t iterator = 0;
    
    //service
    __block io_object_t service = 0;
    
    //registry property
    __block CFDataRef registryProperty = NULL;
    
    //guid (MAC addr)
    static NSData* guid = nil;
    
    //once token
    static dispatch_once_t onceToken = 0;
    
    //only init guid once
    dispatch_once(&onceToken,
    ^{
      
      //get master port
      kernResult = IOMasterPort(MACH_PORT_NULL, &masterPort);
      if(KERN_SUCCESS != kernResult)
      {
          //bail
          goto bail;
      }
      
      //get matching dictionary for 'en0'
      matchingDict = IOBSDNameMatching(masterPort, 0, "en0");
      if(NULL == matchingDict)
      {
          //bail
          goto bail;
      }
      
      //get matching services
      kernResult = IOServiceGetMatchingServices(masterPort, matchingDict, &iterator);
      if(KERN_SUCCESS != kernResult)
      {
          //bail
          goto bail;
      }
      
      //iterate over services, looking for 'IOMACAddress'
      while((service = IOIteratorNext(iterator)) != 0)
      {
          //parent
          io_object_t parentService = 0;
          
          //get parent
          kernResult = IORegistryEntryGetParentEntry(service, kIOServicePlane, &parentService);
          if(KERN_SUCCESS == kernResult)
          {
              //release prev
              if(NULL != registryProperty)
              {
                  //release
                  CFRelease(registryProperty);
              }
              
              //get registry property for 'IOMACAddress'
              registryProperty = (CFDataRef) IORegistryEntryCreateCFProperty(parentService, CFSTR("IOMACAddress"), kCFAllocatorDefault, 0);
              
              //release parent
              IOObjectRelease(parentService);
          }
          
          //release service
          IOObjectRelease(service);
      }
      
      //release iterator
      IOObjectRelease(iterator);
      
      //convert guid to NSData*
      // also release registry property
      if(NULL != registryProperty)
      {
          //convert
          guid = [NSData dataWithData:(__bridge NSData *)registryProperty];
          
          //release
          CFRelease(registryProperty);
      }
                      
bail:
          ;
        
      });//only once
    
    return guid;
}

//determine if file is signed with Apple Dev ID/cert
BOOL isSignedDevID(NSString* path, SecCSFlags flags)
{
    //flag
    BOOL signedOK = NO;
    
    //code
    SecStaticCodeRef staticCode = NULL;
    
    //signing reqs
    SecRequirementRef requirementRef = NULL;
    
    //status
    OSStatus status = -1;
    
    //create static code
    status = SecStaticCodeCreateWithPath((__bridge CFURLRef)([NSURL fileURLWithPath:path]), kSecCSDefaultFlags, &staticCode);
    if(noErr != status)
    {
        //bail
        goto bail;
    }
    
    //create req string w/ 'anchor apple generic'
    status = SecRequirementCreateWithString(CFSTR("anchor apple generic"), kSecCSDefaultFlags, &requirementRef);
    if( (noErr != status) ||
       (requirementRef == NULL) )
    {
        //bail
        goto bail;
    }
    
    //check if file is signed w/ apple dev id by checking if it conforms to req string
    status = SecStaticCodeCheckValidity(staticCode, flags, requirementRef);
    if(noErr != status)
    {
        //bail
        // just means app isn't signed by apple dev id
        goto bail;
    }
    
    //ok, happy
    // file is signed by Apple Dev ID
    signedOK = YES;
    
bail:
    
    //free req reference
    if(NULL != requirementRef)
    {
        //free
        CFRelease(requirementRef);
        
        //unset
        requirementRef = NULL;
    }
    
    //free static code
    if(NULL != staticCode)
    {
        //free
        CFRelease(staticCode);
        
        //unset
        staticCode = NULL;
    }
    
    return signedOK;
}

//determine if a file is from the app store
// gotta be signed w/ Apple Dev ID & have valid app receipt
//   note: here, assume this function is only called on Apps signed with Apple Dev ID!
BOOL fromAppStore(NSString* path)
{
    //flag
    BOOL appStoreApp = NO;
    
    //app receipt
    AppReceipt* appReceipt = nil;
    
    //path to app bundle
    // just have binary
    NSBundle* appBundle = nil;
    
    //if it's an app
    // can directly load app bundle
    appBundle = [NSBundle bundleWithPath:path];
    if(nil == appBundle)
    {
        //find app bundle from binary
        // likely not an application if this fails
        appBundle = findAppBundle(path);
        if(nil == appBundle)
        {
            //bail
            goto bail;
        }
    }
    
    //bail if it doesn't have an receipt
    // done here, since checking signature is expensive!
    if( (nil == appBundle.appStoreReceiptURL) ||
        (YES != [[NSFileManager defaultManager] fileExistsAtPath:appBundle.appStoreReceiptURL.path]) )
    {
        //bail
        goto bail;
    }
    
    //init
    // will parse/decode, etc
    appReceipt = [[AppReceipt alloc] init:appBundle];
    if(nil == appReceipt)
    {
        //bail
        goto bail;
    }
    
    //verify
    if(YES != verifyReceipt(appBundle, appReceipt))
    {
        //bail
        goto bail;
    }
    
    //happy
    // app is signed w/ dev ID & its receipt is solid
    appStoreApp = YES;
    
bail:
    
    return appStoreApp;
}

//extract entitlements
NSDictionary* extractEntitlements(NSString* path)
{
    //entitlements
    NSDictionary* entitlements = nil;
    
    //results
    NSMutableDictionary* results = nil;
    
    //entitlements at bytes
    unsigned char* entitlementBytes = nil;
    
    //entitlements as data
    NSData* entitlementsData = nil;
    
    //entitlements as xml
    NSString* entitlementsXML = nil;

    //exec 'codesign'
    results = execTask(CODE_SIGN, @[@"-d", @"--entitlements", @"-", path]);
    if(noErr != [results[EXIT_CODE] intValue])
    {
        //bail
        goto bail;
    }
    
    //not entitled?
    // could just check for nil, but use offset below
    if([results[STDOUT] length] < 0x10)
    {
        //bail
        goto bail;
    }
    
    //grab bytes
    entitlementBytes = (unsigned char*)[results[STDOUT] bytes];
    
    //codesign has a bug where it returns some (encoding?) bytes first
    // check for that here, and if found, start string conversion at offset 0x8
    if(0xFA == entitlementBytes[0])
    {
        //convert to string
        entitlementsXML = [[NSString alloc] initWithData:[results[STDOUT] subdataWithRange:NSMakeRange(0x8, [results[STDOUT] length] - 0x8)] encoding:NSUTF8StringEncoding];
    }
   
    //other just convert as is
    else
    {
        //convert to string
        entitlementsXML = [[NSString alloc] initWithData:results[STDOUT] encoding:NSUTF8StringEncoding];
    }
    
    //sanity check
    // make sure conversion to string ok
    if(0 == [entitlementsXML length])
    {
        //bail
        goto bail;
    }
    
    //convert to data
    entitlementsData = [entitlementsXML dataUsingEncoding:NSUTF8StringEncoding];
    if(nil == entitlementsData)
    {
        //bail
        goto bail;
    }
    
    //convert to dictionary
    entitlements = [NSPropertyListSerialization propertyListWithData:entitlementsData options:NSPropertyListImmutable format:nil error:nil];
    
bail:
    
    return entitlements;
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
