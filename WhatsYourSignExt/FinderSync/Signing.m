//
//  File: Signing.m
//  Project: Proc Info
//
//  Created by: Patrick Wardle
//  Copyright:  2017 Objective-See
//  License:    Creative Commons Attribution-NonCommercial 4.0 International License
//

#import "Consts.h"
#import "Signing.h"
#import "Utilities.h"
#import "AppReceipt.h"

#import <mach-o/fat.h>
#import <mach-o/arch.h>
#import <mach-o/swap.h>

#import <sys/sysctl.h>

@import OSLog;
@import Security;
@import CommonCrypto;
@import SystemConfiguration;

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
        
    //not fat?
    // can just return offset:0
    if(YES != isBinaryFat(path))
    {
        //bail
        goto bail;
    }
    
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
NSMutableDictionary* extractSigningInfo(NSString* path, SecCSFlags flags, BOOL entitlements)
{
    //info dictionary
    NSMutableDictionary* signingInfo = nil;
    
    //offset of best architecture
    // for universal/fat binary, need to check correct arch
    uint32_t offset = 0;
    
    //code
    SecStaticCodeRef staticCode = NULL;
    
    //status
    OSStatus status = -1;
    
    //signing information
    CFDictionaryRef signingDetails = NULL;
    
    //cert chain
    NSArray* certificateChain = nil;
 
    //index
    NSUInteger index = 0;
    
    //cert
    SecCertificateRef certificate = NULL;
    
    //common name on chert
    CFStringRef commonName = NULL;
    
    //token
    static dispatch_once_t onceToken = 0;
    
    //is notarized requirement
    static SecRequirementRef isNotarized = nil;
    
    //dbg msg
    os_log_debug(OS_LOG_DEFAULT, "WYS: extracting code signing information for: %{public}@", path);
    
    //only once
    // init notarization requirements
    dispatch_once(&onceToken, ^{
        
        //init
        SecRequirementCreateWithString(CFSTR("notarized"), kSecCSDefaultFlags, &isNotarized);

    });
    
    //init signing status
    signingInfo = [NSMutableDictionary dictionary];
    
    //sanity check
    if(nil == path)
    {
        //set err
        signingInfo[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInteger:errSecCSObjectRequired];
        
        //bail
        goto bail;
    }
    
    //get offset of 'best' architecute
    // this is what loader will run, and thus, what we should validate!
    offset = bestArchOffset(path);
    
    //create static code
    status = SecStaticCodeCreateWithPathAndAttributes((__bridge CFURLRef)([NSURL fileURLWithPath:path]), kSecCSDefaultFlags, (__bridge CFDictionaryRef)@{(__bridge NSString *)kSecCodeAttributeUniversalFileOffset : [NSNumber numberWithUnsignedInt:offset]}, &staticCode);
    
    //save signature status
    signingInfo[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInteger:status];
    if(errSecSuccess != status)
    {
        //bail
        goto bail;
    }
    
    //check signature
    status = SecStaticCodeCheckValidity(staticCode, flags, NULL);
    
    //(re)save signature status
    signingInfo[KEY_SIGNATURE_STATUS] = [NSNumber numberWithInteger:status];

    //if file is validly signed (or was signed, but revoked)
    // grab entitlements, signing authorities, notarization status, etc.
    if( (errSecSuccess == status) ||
        (CSSMERR_TP_CERT_REVOKED == status) )
    {
        //grab signing informaation
        status = SecCodeCopySigningInformation(staticCode, kSecCSSigningInformation, &signingDetails);
        if(errSecSuccess != status)
        {
            //bail
            goto bail;
        }
        
        //grab flags
        if( (nil != [(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoFlags]) )
        {
            //extract/save
            signingInfo[KEY_SIGNING_FLAGS] = [(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoFlags];
        }
        
        //extract cd hashes
        for(NSData* hash in [((__bridge NSDictionary*)signingDetails)[@"cdhashes-full"] allObjects])
        {
            //sanity check
            if([hash isKindOfClass:[NSData class]])
            {
                //SHA1?
                if(CC_SHA1_DIGEST_LENGTH == hash.length)
                {
                    signingInfo[KEY_SIGNING_CDHASH_SHA1] = hash;
                }
                //SHA256 hash
                else if(CC_SHA256_DIGEST_LENGTH == hash.length)
                {
                    signingInfo[KEY_SIGNING_CDHASH_SHA256] = hash;
                }
            }
        }
        
        //also try 'kSecCodeInfoUnique' for cd hash
        if(!signingInfo[KEY_SIGNING_CDHASH_SHA1] && !signingInfo[KEY_SIGNING_CDHASH_SHA256])
        {
            NSData* hash = ((__bridge NSDictionary*)signingDetails)[(__bridge NSString *)kSecCodeInfoUnique];
            if ([hash isKindOfClass:[NSData class]] && hash.length == CC_SHA1_DIGEST_LENGTH) {
                signingInfo[KEY_SIGNING_CDHASH_SHA1] = hash;
            }
        }
        
        //add entitlements?
        if( (YES == entitlements) &&
            (nil != [(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoEntitlementsDict]) )
        {
                //extract/save
                signingInfo[KEY_SIGNING_ENTITLEMENTS] = [(__bridge NSDictionary*)signingDetails objectForKey:(__bridge NSString*)kSecCodeInfoEntitlementsDict];
        }
        
        //determine if binary is signed by Apple
        signingInfo[KEY_SIGNING_IS_APPLE] = [NSNumber numberWithBool:isApple(path, flags)];
        
        //not apple proper
        // is signed with Apple Dev ID?
        if(YES != [signingInfo[KEY_SIGNING_IS_APPLE] boolValue])
        {
            //determine if binary is Apple Dev ID
            signingInfo[KEY_SIGNING_IS_APPLE_DEV_ID] = [NSNumber numberWithBool:isSignedDevID(path, flags)];
            
            //if dev id
            // from app store?
            if(YES == [signingInfo[KEY_SIGNING_IS_APPLE_DEV_ID] boolValue])
            {
                //from app store?
                signingInfo[KEY_SIGNING_IS_APP_STORE] = [NSNumber numberWithBool:fromAppStore(path)];
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
    signingInfo[KEY_SIGNING_AUTHORITIES] = [NSMutableArray array];
    
    //get cert chain
    certificateChain = ((__bridge NSDictionary*)signingDetails)[(__bridge NSString*)kSecCodeInfoCertificates];
    
    //get name of all certs
    // add each cert to list
    for(index = 0; index < certificateChain.count; index++)
    {
        //extract cert
        certificate = (__bridge SecCertificateRef)([certificateChain objectAtIndex:index]);
        
        //get common name
        status = SecCertificateCopyCommonName(certificate, &commonName);
        
        //add (valid ones)
        if( (errSecSuccess == status) &&
            (NULL != commonName) )
        {
            //save
            [signingInfo[KEY_SIGNING_AUTHORITIES] addObject:(__bridge NSString*)commonName];
        }
        
        //cleanup
        if(NULL != commonName)
        {
            //release name
            CFRelease(commonName);
            
            //unset
            commonName = NULL;
        }
    }
    
    //check notarization status
    // note: force online checks (revocation)
    if(errSecSuccess == SecStaticCodeCheckValidity(staticCode, kSecCSEnforceRevocationChecks, isNotarized))
    {
        //notarized
        signingInfo[KEY_SIGNING_IS_NOTARIZED] = [NSNumber numberWithInteger:errSecSuccess];
    }
    //failed
    // but maybe cuz it's revoked?
    else
    {
        //check hashes
        for(NSData* hash in [((__bridge NSDictionary*)signingDetails)[@"cdhashes-full"] allObjects])
        {
            //error
            CFErrorRef error = nil;
            
            //truncated hash
            // this is what Apple uses
            NSData* truncatedHash = nil;
            
            //hash type
            SecCSDigestAlgorithm hashType = 0;
            
            //sanity check
            if(YES != [hash isKindOfClass:[NSData class]])
            {
                //skip
                continue;
            }
            
            //SHA1?
            if(CC_SHA1_DIGEST_LENGTH == hash.length)
            {
                //SHA1
                hashType = kSecCodeSignatureHashSHA1;
                
                //use as is
                truncatedHash = hash;
            }
            //SHA256 hash
            else if(CC_SHA256_DIGEST_LENGTH == hash.length)
            {
                //SHA256
                hashType = kSecCodeSignatureHashSHA256;
                
                //truncate, first 20 bytes
                // this is what the notarization checks requires
                truncatedHash = [hash subdataWithRange:NSMakeRange(0, CC_SHA1_DIGEST_LENGTH)];
            }
            //unknown
            // just ignore for now
            else
            {
                //skip
                continue;
            }
            
            //notarization check
            // do online ('kSecAssessmentTicketFlagForceOnlineCheck') to detect revocations
            if(YES != SecAssessmentTicketLookup((__bridge CFDataRef)(truncatedHash), hashType, kSecAssessmentTicketFlagForceOnlineCheck, NULL, &error))
            {
                //EACCES: means revoked
                if(EACCES == CFErrorGetCode(error))
                {
                    //set
                    signingInfo[KEY_SIGNING_IS_NOTARIZED] = [NSNumber numberWithInteger:errSecCSRevokedNotarization];
                }
            }
        }
    }
    
bail:
    
    //free signing info
    if(NULL != signingDetails)
    {
        //free
        CFRelease(signingDetails);
        
        //unset
        signingDetails = NULL;
    }
    
    //free static code
    if(NULL != staticCode)
    {
        //free
        CFRelease(staticCode);
        
        //unset
        staticCode = NULL;
    }
    
    return signingInfo;
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
    if(errSecSuccess != status)
    {
        //bail
        goto bail;
    }
    
    //create req string w/ 'anchor apple'
    // (3rd party: 'anchor apple generic')
    status = SecRequirementCreateWithString(CFSTR("anchor apple"), kSecCSDefaultFlags, &requirementRef);
    if( (errSecSuccess != status) ||
        (requirementRef == NULL) )
    {
        //bail
        goto bail;
    }
    
    //check if file is signed by apple by checking if it conforms to req string
    // note: ignore 'errSecCSBadResource' as lots of signed apple files return this issue :/
    status = SecStaticCodeCheckValidity(staticCode, flags, requirementRef);
    if( (errSecSuccess != status) &&
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
NSData* getGUID(void)
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
    if(errSecSuccess != status)
    {
        //bail
        goto bail;
    }
    
    //create req string w/ 'anchor apple generic'
    status = SecRequirementCreateWithString(CFSTR("anchor apple generic"), kSecCSDefaultFlags, &requirementRef);
    if( (errSecSuccess != status) ||
        (requirementRef == NULL) )
    {
        //bail
        goto bail;
    }
    
    //check if file is signed w/ apple dev id by checking if it conforms to req string
    status = SecStaticCodeCheckValidity(staticCode, flags, requirementRef);
    if(errSecSuccess != status)
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
        requirementRef = NULL;
    }
    
    //free static code
    if(NULL != staticCode)
    {
        //free
        CFRelease(staticCode);
        staticCode = NULL;
    }
    
    return signedOK;
}

//determine if a file is from the app store
// gotta be signed w/ Apple Dev ID & have valid app receipt
// note: here, assume this function is only called on Apps signed with Apple Dev ID!
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
