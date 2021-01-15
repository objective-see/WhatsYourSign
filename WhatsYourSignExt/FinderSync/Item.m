//
//  Item.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Xips.h"
#import "Item.h"
#import "consts.h"
#import "Signing.h"
#import "Packages.h"
#import "utilities.h"
#import "FinderSync.h"

#import <os/log.h>

@implementation Item

@synthesize icon;
@synthesize name;
@synthesize path;
@synthesize type;
@synthesize bundle;
@synthesize hashes;
@synthesize signingInfo;
@synthesize windowController;

//init method
-(id)init:(NSString*)itemPath
{
    //super
    self = [super init];
    if(self)
    {
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"item: %@", itemPath]);
        
        //save path
        self.path = itemPath;
        
        //since path is always full path to binary
        // manaully try to find & load bundle (for .apps)
        self.bundle = findAppBundle(self.path);
        
        /* now we have bundle (maybe), try get name and icon */
        
        //get task's name
        // either from bundle or path's last component
        self.name = [self getName];
        
        //get task's icon
        // either from bundle or just use a system icon
        self.icon = [self getIcon];
        
        //set type
        [self determineType];
        
        //get code signing info
        // do in background cuz it can be slow!
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
        ^{
           //get code signing info
           [self generateSigningInfo];
        
           //no errors?
           // if item is an app, might have to verify its (fat) binary too
           if(YES == [self shouldVerifyBinary])
           {
               //dbg msg
               //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"verifying %@'s main binary", self.name]);
               
               //verify
               [self verifyBinary];
           }
           
           //nap
           // allows 'determining' msg / activity indicator to be shown
           [NSThread sleepForTimeInterval:0.5];
           
           //on main thread
           // tell window to now process signing info
           dispatch_async(dispatch_get_main_queue(), ^{
               
               //process
               [self.windowController processCodeSigningInfo];
               
           });
           
        });
    }
           
bail:
    
    return self;
}

//item is an app (bundle), verify its binary if:
// a) no codesigning issues
// b) has main binary (path)
// c) main binary is fat
-(BOOL)shouldVerifyBinary
{
    //flag
    BOOL shouldVerify = NO;
    
    //app binary
    NSString* binaryPath = nil;
    
    //not an app bundle?
    if(YES != [self.path hasSuffix:@".app"])
    {
        //bail
        goto bail;
    }
    
    //already, any code-signing errors?
    if(noErr != [self.signingInfo[KEY_SIGNATURE_STATUS] intValue])
    {
        //bail
        goto bail;
    }

    //has app binary
    binaryPath = self.bundle.executablePath;
    if(nil == binaryPath)
    {
        //bail
        goto bail;
    }
    
    //binary isn't fat
    if(YES != isBinaryFat(binaryPath))
    {
        //bail
        goto bail;
    }
    
    //binary should be verified
    shouldVerify = YES;
    
bail:
    
    return shouldVerify;
}

//set item type
// use 'typeOfFile' for apps/bundle/packages
// and 'file' cmd for rest (as its somewhat more accurate)
-(void)determineType
{
    //directory flag
    BOOL isDirectory = NO;
    
    //possible type
    NSString* likelyType = nil;
    
    //localized type
    NSString* localizedType = nil;
    
    //results from 'file' cmd
    NSMutableDictionary* results = nil;
    
    //array of parsed results
    NSArray* parsedResults = nil;
    
    //set directory flag
    [NSFileManager.defaultManager fileExistsAtPath:self.path isDirectory:&isDirectory];
    
    //for bundles/disk images/packages, etc...
    // ...use NSWorkspace's 'typeOfFile' method as it produces better results
    if( (YES == isDirectory) ||
        (NSOrderedSame == [self.path.pathExtension caseInsensitiveCompare:@"dmg"]) ||
        (NSOrderedSame == [self.path.pathExtension caseInsensitiveCompare:@"pkg"]) )
    {
        //first try via 'typeOfFile'
        likelyType = [[NSWorkspace sharedWorkspace] typeOfFile:self.path error:nil];
        
        //set localized type
        if(nil != likelyType)
        {
            //set
            localizedType = [[NSWorkspace sharedWorkspace] localizedDescriptionForType:likelyType];
        }
        
        //when blank
        // ...could be a kext
        if( (nil == localizedType) &&
            (YES == [self.path hasSuffix:@".kext"]) )
        {
                //set
                localizedType = @"kernel extension (bundle)";
        }
    }
    //not a directory
    // use the 'file' command, as its more accurate
    else
    {
        //exec 'file' to get file type
        results = execTask(FILE, @[self.path]);
        if( (0 != [results[EXIT_CODE] intValue]) ||
            (0 == [results[STDOUT] length]) )
        {
            //bail
            goto bail;
        }
        
        //parse results
        // ->format: <file path>: <file types>
        parsedResults = [[[NSString alloc] initWithData:results[STDOUT] encoding:NSUTF8StringEncoding] componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":\n"]];
        
        //sanity check
        // should be two items in array, <file path> and <file type>
        if(parsedResults.count < 2)
        {
            //bail
            goto bail;
        }
        
        //file type comes second
        // ->also trim whitespace
        localizedType = [parsedResults[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    
bail:
    
    //default to unknown
    if(nil == localizedType)
    {
        //set
        localizedType = @"unknown type";
    }
    
    //set type
    self.type = localizedType;
    
    return;
}

//get task's name
// either from bundle or path's last component
-(NSString*)getName
{
    //name
    NSString* taskName = nil;
    
    //try to get name from bundle
    // ->key 'CFBundleName'
    if(nil != self.bundle)
    {
        //extract name
        taskName = [self.bundle infoDictionary][@"CFBundleName"];
    }
    
    //no bundle/ or bundle lookup failed
    // ->just use last component of path
    if(nil == taskName)
    {
        //extract name
        taskName = [self.path lastPathComponent];
    }
    
    return taskName;
}

//get an icon for a process
// for apps, this will be app's icon, otherwise just a standard system one
-(NSImage*)getIcon
{
    //icon's file name
    NSString* iconFile = nil;
    
    //icon's path
    NSString* iconPath = nil;
    
    //icon's path extension
    NSString* iconExtension = nil;
    
    //icon
    NSImage* taskIcon = nil;
    
    //for app's
    // extract their icon
    if(nil != self.bundle)
    {
        //get file
        iconFile = self.bundle.infoDictionary[@"CFBundleIconFile"];
        
        //get path extension
        iconExtension = [iconFile pathExtension];
        
        //if its blank (i.e. not specified)
        // ->go with 'icns'
        if(YES == [iconExtension isEqualTo:@""])
        {
            //set type
            iconExtension = @"icns";
        }
        
        //set full path
        iconPath = [self.bundle pathForResource:[iconFile stringByDeletingPathExtension] ofType:iconExtension];
        
        //load it
        taskIcon = [[NSImage alloc] initWithContentsOfFile:iconPath];
    }
    
    //item is not an app or couldn't get icon
    // try to get icon via the shared workspace
    if(nil == taskIcon)
    {
        //extract icon
        taskIcon = [[NSWorkspace sharedWorkspace] iconForFile:self.path];
    }
    
    //resize
    // 'iconForFileType' returns small icons
    [taskIcon setSize:NSMakeSize(128, 128)];
    
    return taskIcon;
}

//get signing info
// call in the background
-(void)generateSigningInfo
{
    //app binary
    NSString* binaryPath = nil;
    
    //directory flag
    BOOL isDirectory = NO;
    
    //dbg msg
    os_log(OS_LOG_DEFAULT, "WYS: generating signing information for %{public}@", self.path);
    
    //xip's are special
    // signing info is appended differently
    if(YES == [self.type isEqualToString:@"XIP Secure Archive"])
    {
        //check
        self.signingInfo = checkXIP(self.path);
    }
    
    //as are .pkgs
    else if(NSOrderedSame == [self.path.pathExtension caseInsensitiveCompare:@"pkg"])
    {
        //check
        self.signingInfo = checkPackage(self.path);
        
        //add hashes
        self.hashes = hashFile(self.path);
    }

    //extract via Sec* APIs
    else
    {
        //extract
        // pass 'YES' to also generate entitlements
        self.signingInfo = extractSigningInfo(self.path, kSecCSDefaultFlags | kSecCSCheckNestedCode | kSecCSCheckAllArchitectures | kSecCSEnforceRevocationChecks, YES);
        
        //if item is app bundle
        // generate hashes of app's executable!
        if(YES == [self.path hasSuffix:@".app"])
        {
            //get app binary
            binaryPath = self.bundle.executablePath;
            if(nil != binaryPath)
            {
                //add app's binary hashes
                self.hashes = hashFile(self.path);
            }
        }
        
        //don't hash directories
        if( (YES == [[NSFileManager defaultManager] fileExistsAtPath:self.path isDirectory:&isDirectory]) &&
            (YES != isDirectory) )
        {
            //add hashes
            self.hashes = hashFile(self.path);
        }
    }
    
    return;
}

//need extra logic to verify app bundle (main) binary
// if there are any errors or different signing auths, binary's info will be used!
-(void)verifyBinary
{
    //app binary
    NSString* binaryPath = nil;
    
    //signing info
    NSMutableDictionary* binarySigningInfo = nil;
    
    //get app binary
    binaryPath = self.bundle.executablePath;
    if(nil == binaryPath)
    {
        //bail
        goto bail;
    }
    
    //get signing info for app binary
    binarySigningInfo = extractSigningInfo(binaryPath, kSecCSDefaultFlags | kSecCSCheckNestedCode | kSecCSCheckAllArchitectures | kSecCSEnforceRevocationChecks, YES);
    
    //error?
    // use binary's signing info
    if(noErr != [binarySigningInfo[KEY_SIGNATURE_STATUS] intValue])
    {
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ has a signing error (%@)", binaryPath, binarySigningInfo[KEY_SIGNATURE_STATUS]]);
        
        //update
        self.signingInfo = binarySigningInfo;
        
        //all set
        goto bail;
    }
    
    //different signing auths?
    // use binary's signing info
    if(YES != [[NSCountedSet setWithArray:self.signingInfo[KEY_SIGNING_AUTHORITIES]] isEqualToSet: [NSCountedSet setWithArray:binarySigningInfo[KEY_SIGNING_AUTHORITIES]]] )
    {
        //dbg msg
        //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"%@ signing auths mismatch (%@ vs. %@)", binaryPath, binarySigningInfo[KEY_SIGNING_AUTHORITIES], self.signingInfo[KEY_SIGNING_AUTHORITIES]]);
        
        //update
        self.signingInfo = binarySigningInfo;
        
        //bail
        goto bail;
    }
    
bail:
    
    return;
}

@end
