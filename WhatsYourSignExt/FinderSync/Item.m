//
//  Item.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Item.h"
#import "Consts.h"
#import "Logging.h"
#import "Signing.h"
#import "Utilities.h"
#import "FinderSync.h"

@implementation Item

@synthesize icon;
@synthesize name;
@synthesize path;
@synthesize type;
@synthesize bundle;
@synthesize signingInfo;
@synthesize windowController;

//init method
-(id)init:(NSString*)itemPath
{
    //super
    self = [super init];
    if(self)
    {
        //save path
        self.path = itemPath;
        
        //since path is always full path to binary
        // ->manaully try to find & load bundle (for .apps)
        self.bundle = findAppBundle(self.path);
        
        /* now we have bundle (maybe), try get name and icon */
        
        //get task's name
        // ->either from bundle or path's last component
        self.name = [self getName];
        
        //get task's icon
        // ->either from bundle or just use system icon
        self.icon = [self getIcon];
        
        //set type
        [self determineType];
        
        //get code signing info
        // ->do in background cuz it can be slow!
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
           ^{
               //get code signing info
               [self generateSigningInfo];
               
               //nap
               // ->allows 'determining' msg / activity indicator to be shown
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

//set item type
// use 'typeOfFile' for apps/bundle and 'file' cmd for rest (as its more accurate)
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
    
    //path is a directory?
    // ...might be a app/bundle, etc so use NSWorkspace's 'typeOfFile' method
    if( (YES == [[NSFileManager defaultManager] fileExistsAtPath:self.path isDirectory:&isDirectory]) &&
        (YES == isDirectory) )
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
        // ->should be two items in array, <file path> and <file type>
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
// ->either from bundle or path's last component
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
// ->for apps, this will be app's icon, otherwise just a standard system one
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
    // ->extract their icon
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
    // ->try to get it via shared workspace
    if(nil == taskIcon)
    {
        //extract icon
        // ->
        taskIcon = [[NSWorkspace sharedWorkspace] iconForFile:self.path];
    }
    
    //'iconForFileType' returns small icons
    // ->so set size to 128
    [taskIcon setSize:NSMakeSize(128, 128)];
    
    return taskIcon;
}

//get signing info (which takes a while to generate)
// ->this method should be called in the background
-(void)generateSigningInfo
{
    //xip's are special
    // ->signing info is appended differently
    if(YES == [self.type isEqualToString:@"XIP Secure Archive"])
    {
        //check
        self.signingInfo = checkXIP(self.path);
    }
    //extract via Sec* APIs
    else
    {
        //extract
        self.signingInfo = extractSigningInfo(self.path);
    }
    
    return;
}

@end
