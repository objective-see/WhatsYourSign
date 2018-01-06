//
//  Configure.m
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Consts.h"
#import "Logging.h"
#import "Configure.h"
#import "Utilities.h"

@implementation Configure

//invokes appropriate install || uninstall logic
-(BOOL)configure:(NSUInteger)parameter
{
    //return var
    BOOL wasConfigured = NO;
    
    //install extension
    if(ACTION_INSTALL_FLAG == parameter)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"installing...");
        
        //already installed?
        // uninstall everything first
        if(YES == [self isInstalled])
        {
            //dbg msg
            logMsg(LOG_DEBUG, @"already installed, so uninstalling...");
            
            //uninstall
            // no need to relaunch Finder though
            if(YES != [self uninstall:NO])
            {
                //bail
                goto bail;
            }
            
            //dbg msg
            logMsg(LOG_DEBUG, @"uninstalled");
        }
        
        //install
        if(YES != [self install])
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"installed!");
    
        //start app after a bit
        // macOS sierra+ this ensures plugin is activated
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            //relaunch
            // ->use 'open' since allows two instances of app to be run
            execTask(OPEN, @[@"-n", @"-a", APP_LOCATION]);
            
        });
    }
    //uninstall extension
    else if(ACTION_UNINSTALL_FLAG == parameter)
    {
        //dbg msg
        logMsg(LOG_DEBUG, @"uninstalling...");
        
        //uninstall
        // and relaunch Finder
        if(YES != [self uninstall:YES])
        {
            //bail
            goto bail;
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, @"uninstalled!");
    }

    //no errors
    wasConfigured = YES;
    
bail:
    
    return wasConfigured;
}

//determine if installed
// ->simply checks if extension binary exists
-(BOOL)isInstalled
{
    //flag
    BOOL installed = NO;
    
    //first check for older versions
    // had no 'app', just an extension folder
    installed = [[NSFileManager defaultManager] fileExistsAtPath:[OLD_LOCATION stringByExpandingTildeInPath]];
    
    //not found there?
    // check for newer versions
    if(NO == installed)
    {
        //check for app
        installed =  [[NSFileManager defaultManager] fileExistsAtPath:NEW_LOCATION];
    }
    
    //check if extension exists
    return installed;
}

//install
// a) copy extension /Applications
// b) add extension: 'pluginkit -a /path/2/WhatsYourSign.appex'
// c) enable extension: 'pluginkit -e use -i com.objective-see.WhatsYourSignExt.FinderSync'
-(BOOL)install
{
    //return/status var
    BOOL wasInstalled = NO;
    
    //error
    NSError* error = nil;
    
    //path to app (src)
    NSString* pathSrc = nil;
    
    //path to app (dest)
    NSString* pathDest = nil;
    
    //extension path
    NSString* extension = nil;
    
    //results from 'pluginkit' cmd
    NSMutableDictionary* results = nil;
    
    //enable attempts
    NSUInteger attempts = 0;
    
    //set src path
    // ->orginally stored in installer app's /Resource bundle
    pathSrc = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:APP_NAME];
    
    //set dest path
    pathDest = APP_LOCATION;
    
    //move app into persistent location
    if(YES != [[NSFileManager defaultManager] copyItemAtPath:pathSrc toPath:pathDest error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to copy %@ -> %@ (%@)", pathSrc, pathDest, error]);
        
        //bail
        goto bail;
    }

    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"copied %@ -> %@", pathSrc, pathDest]);
    
    //remove xattrs
    execTask(XATTR, @[@"-cr", pathDest]);
    
    //dbg msg
    logMsg(LOG_DEBUG, @"removed xattrz");
    
    //init path to (now) installed extension
    extension = [[APP_LOCATION stringByAppendingPathComponent:@"Contents/PlugIns"] stringByAppendingPathComponent:EXTENSION_NAME];
    
    //install
    // try a few times since sometimes fails!?
    for(attempts = 0; attempts < MAX_ENABLE_ATTEMPTS; attempts++)
    {
        //install extension via 'pluginkit -a <path 2 ext>
        results = execTask(PLUGIN_KIT, @[@"-a", extension]);
        if(0 != [results[EXIT_CODE] intValue])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"pluginkit failed to install extension (%@)",  results]);
            
            //bail
            goto bail;
        }
        
        //was installed?
        // query plugin db, and look for response
        results = execTask(PLUGIN_KIT, @[@"-m", @"-i", EXTENSION_BUNDLE_ID]);
        if(0 != [results[STDOUT] length])
        {
            //ok
            break;
        }
        
        //nap
        // seems to sometimes take awhile to 'install'
        [NSThread sleepForTimeInterval:0.25];
    }
    
    //sanity check
    if(attempts == MAX_ENABLE_ATTEMPTS)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to install extension");
        
        //bail
        goto bail;
    }

    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"added extension %@ via 'pluginkit -a'", extension]);

    //now enable
    // try a few times since sometimes fails!?
    for(attempts = 0; attempts < MAX_ENABLE_ATTEMPTS; attempts++)
    {
        //enable extension via 'pluginkit -e use -i <ext bundle id>
        results = execTask(PLUGIN_KIT, @[@"-e", @"use", @"-i", EXTENSION_BUNDLE_ID]);
        if(0 != [results[EXIT_CODE] intValue])
        {
            //err msg
            logMsg(LOG_ERR, [NSString stringWithFormat:@"pluginkit failed to enable extension (%@)", results]);
            
            //bail
            goto bail;
        }
        
        //was enabled?
        // query plugin db, and look for '+'
        results = execTask(PLUGIN_KIT, @[@"-m", @"-i", EXTENSION_BUNDLE_ID]);
        if(YES == [[[NSString alloc] initWithData:results[STDOUT] encoding:NSUTF8StringEncoding] hasPrefix:@"+"])
        {
            //ok
            break;
        }
        
        //nap
        // seems to sometimes take awhile to 'install'
        [NSThread sleepForTimeInterval:0.25];
    }
    
    //sanity check
    if(attempts == MAX_ENABLE_ATTEMPTS)
    {
        //err msg
        logMsg(LOG_ERR, @"failed to enable extension");
        
        //bail
        goto bail;
    }
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"enabled extension %@ via 'pluginkit -e, ...'", EXTENSION_BUNDLE_ID]);
    
    //give it a second to sync out plugin db
    [NSThread sleepForTimeInterval:0.5f];
    
    //relaunch Finder
    // ensures plugin gets loaded, etc
    execTask(KILLALL, @[@"-SIGHUP", @"Finder"]);
    
    //give it a second to restart
    [NSThread sleepForTimeInterval:1.0f];
    
    //tell Finder to activate
    // otherwise it's fully background'd when app exits for some reason!?
    system("osascript -e \"tell application \\\"Finder\\\" to activate\"");
    
    //dbg msg
    logMsg(LOG_DEBUG, @"relaunched Finder.app");

    //no error
    wasInstalled = YES;
    
bail:
    
    return wasInstalled;
}

//uninstall
// a) remove extension (pluginkit -r <path 2 ext>)
// b) delete folder; /Library/WhatsYourSign or /Application/WhatsYourSign.app
-(BOOL)uninstall:(BOOL)relaunchFinder
{
    //return/status var
    BOOL wasUninstalled = NO;
    
    //pid of finder sync
    pid_t processID = -1;
    
    //path to finder sync
    NSString* extension = nil;
    
    //folder where app and/or extension lives
    NSString* folder = nil;

    //error
    NSError* error = nil;

    //init extension/folder for old version
    if(YES == [[NSFileManager defaultManager] fileExistsAtPath:[OLD_LOCATION stringByExpandingTildeInPath]])
    {
        //init path
        extension = [[OLD_LOCATION stringByExpandingTildeInPath] stringByAppendingPathComponent:EXTENSION_NAME];
        
        //init folder
        folder = [OLD_LOCATION stringByExpandingTildeInPath];
    }
    //init extension/folder for new version
    else
    {
        //init path
        extension = [[NEW_LOCATION stringByAppendingPathComponent:@"Contents/PlugIns"] stringByAppendingPathComponent:EXTENSION_NAME];
        
        //init folder
        folder = NEW_LOCATION;
    }

    //find pid of extension instance(s)
    // and if any are found, kill them via SIGKILL!
    do
    {
        //find process by name
        processID = findProcess(@"WhatsYourSign");
        if(-1 != processID)
        {
            //dbg msg
            logMsg(LOG_DEBUG, [NSString stringWithFormat:@"sending SIGKILL to %d", processID]);

            //kill
            kill(processID, SIGKILL);
            
            //nap
            [NSThread sleepForTimeInterval:0.1f];
        }
        
    } while (processID != -1);
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removing extension (%@) via 'pluginkit -r'", extension]);

    //remove extension
    // ->plugin kit prints err, but it still works
    execTask(PLUGIN_KIT, @[@"-r", extension]);
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removing folder (%@)", folder]);

    //delete folder
    if(YES != [[NSFileManager defaultManager] removeItemAtPath:folder error:&error])
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to delete extension directory %@ (%@)", folder, error]);
        
        //bail
        goto bail;
    }

    //relaunch Finder?
    if(YES == relaunchFinder)
    {
        // ensures plugin refs, etc are all removed
        execTask(KILLALL, @[@"-SIGHUP", @"Finder"]);
        
        //give it a second to restart
        [NSThread sleepForTimeInterval:1.0f];
        
        //tell Finder to activate
        // otherwise it's fully background'd when app exits for some reason!?
        system("osascript -e \"tell application \\\"Finder\\\" to activate\"");
        
        //dbg msg
        logMsg(LOG_DEBUG, @"relaunched Finder.app");
    }
    
    //happy
    wasUninstalled = YES;
    
bail:
                         
    return wasUninstalled;
}

@end
