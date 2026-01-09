//
//  FinderSync.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 7/5/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <os/log.h>

#import "consts.h"
#import "FinderSync.h"

@implementation FinderSync

@synthesize directories;

//init
// watch most the things (not network drives)
-(instancetype)init
{
    //dbg msg
    os_log_debug(OS_LOG_DEFAULT, "WYS: initializing");
    
    self = [super init];
    if(nil != self)
    {
        //init directories set
        self.directories = [NSMutableSet set];
        
        [FIFinderSyncController defaultController].sidebarImage = nil;
        
        //setup prefs change listener
        __weak typeof(self) weakSelf = self;
        self.prefsObserver = [[NSDistributedNotificationCenter defaultCenter]
            addObserverForName:PREFS_CHANGED_NOTIFICATION
                        object:nil
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *notification)
                              {
            
            //dbg msg
            os_log_debug(OS_LOG_DEFAULT, "WYS: preferences changed...");
            
            //capture
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            
            //unmonitor
            [strongSelf unmonitor];
            
            //(re)monitor
            [strongSelf monitor];
            
        }];
    
        //start monitoring
        [self monitor];
    }
    
    return self;
}

//monitor
// get mounted volumes and watch
-(void)monitor {
    
    //get all mounted volumes
    NSArray *volumes = [NSFileManager.defaultManager mountedVolumeURLsIncludingResourceValuesForKeys:@[NSURLVolumeIsRootFileSystemKey, NSURLVolumeIsLocalKey] options:NSVolumeEnumerationSkipHiddenVolumes];
    
    //dbg msg
    os_log_debug(OS_LOG_DEFAULT, "WYS: volumes: %{public}@", volumes);
    
    //monitor all volumes
    // note: monitorVolume method checks settings re: external volumes
    for(NSURL *volume in volumes) {
        
        NSNumber *isRootVolume = nil;
        [volume getResourceValue:&isRootVolume forKey:NSURLVolumeIsRootFileSystemKey error:nil];
        
        //monitor
        [self monitorVolume:volume isRoot:isRootVolume.boolValue];
    }
    
    //dbg msg
    os_log_debug(OS_LOG_DEFAULT, "WYS: will monitor %ld locations", self.directories.count);
    
    //set watched directories
    [FIFinderSyncController defaultController].directoryURLs = self.directories;
    
    //register for volume mount
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector: @selector(volumeEvent:) name:NSWorkspaceDidMountNotification object:nil];
    
    //register for volume unmount
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector: @selector(volumeEvent:) name:NSWorkspaceDidUnmountNotification object:nil];
    
}

//unmonitor
// stop watching and clear directories
-(void)unmonitor {
    
    //unregister for volume events
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
        
    //clear watched directories
    [FIFinderSyncController defaultController].directoryURLs = nil;
    [self.directories removeAllObjects];
        
    //dbg msg
    os_log_debug(OS_LOG_DEFAULT, "WYS: stopped monitoring");
}


// monitor volume
// internal drives: adds the root itself
// external drives: adds the root itself, only if setting set
-(void)monitorVolume:(NSURL *)volume isRoot:(BOOL)isRoot
{
    NSNumber* isLocal = nil;
    [volume getResourceValue:&isLocal forKey:NSURLVolumeIsLocalKey error:nil];
    
    //monitor external drives?
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:APP_GROUP];
    BOOL monitorExternal = [sharedDefaults boolForKey:PREF_ENABLE_ON_EXTERNAL_DRIVES];
    
    //dbg msg
    os_log_debug(OS_LOG_DEFAULT, "WYS: should monitor external drives? %d", monitorExternal);
    
    //skip network drives
    if(!isLocal.boolValue) {
        
        //skip
        os_log_debug(OS_LOG_DEFAULT, "WYS: skipping network volume: %{public}@", volume.path);
        return;
    }

    //skip system "volumes"
    // should already be watching those (if mounted)
    if([volume.path hasPrefix:@"/System/Volumes/"]) {
        
        //skip
        os_log_debug(OS_LOG_DEFAULT, "WYS: skipping system volume: %{public}@", volume.path);
        return;
    }
    
    //root?
    // can just watch entire volume
    if(isRoot) {
        
        //dbg msg
        os_log_debug(OS_LOG_DEFAULT, "WYS: monitoring root volume: %{public}@", volume);
        
        //add
        [self.directories addObject:volume];
    }
    //external drive?
    // watch all, but only if user has enabled that
    else if(monitorExternal) {
        
        //dbg msg
        os_log_debug(OS_LOG_DEFAULT, "WYS: monitoring external volume: %{public}@", volume);
        
        //add
        [self.directories addObject:volume];
    }
     
    return;
}


//unmonitor
-(void)unmonitorVolume:(NSURL*)volume
{
    //remove
    [self.directories removeObject:volume];
    
    //update watched directories
    [FIFinderSyncController defaultController].directoryURLs = self.directories;
    
    return;
}

//automatically invoked
// add 'Signing Info' menu item
-(NSMenu*)menuForMenuKind:(FIMenuKind)whichMenu
{
    //menu
    NSMenu *menu = nil;
    
    //ignore multi-selections
    if([[[FIFinderSyncController defaultController] selectedItemURLs] count] > 1)
    {
        //ignore
        goto bail;
    }
    
    //alloc/init menu
    menu = [[NSMenu alloc] initWithTitle:@""];
    
    //add 'Signing Info'
    [menu addItemWithTitle:NSLocalizedString(@"Code Signing Info", @"Code Signing Info") action:@selector(showSigningInfo:) keyEquivalent:@""];
    
bail:

    return menu;
}

//callback for volume events
-(void)volumeEvent:(NSNotification*)notification
{
    //dbg msg
    os_log_debug(OS_LOG_DEFAULT, "WYS: volume notification: %{public}@", notification);
    
    //mount?
    // monitor volume
    if(YES == [notification.name isEqualToString:NSWorkspaceDidMountNotification])
    {
        //monitor
        [self monitorVolume:notification.userInfo[NSWorkspaceVolumeURLKey] isRoot:NO];
    }
    
    //unmount?
    // unmonitor volume
    else if(YES == [notification.name isEqualToString:NSWorkspaceDidUnmountNotification])
    {
        //unmonitor
        [self unmonitorVolume:notification.userInfo[NSWorkspaceVolumeURLKey]];
    }
    
    return;
}

//show signing info
-(void)showSigningInfo:(id)sender
{
    //selected item
    NSURL* selectedItem = nil;
    
    //info window
    __block InfoWindowController* infoWindowController = nil;
    
    //get selected items
    selectedItem = [[[FIFinderSyncController defaultController] selectedItemURLs] firstObject];
    
    //show window on main thread
    dispatch_async(dispatch_get_main_queue(), ^{

        //init info window
        infoWindowController = [[InfoWindowController alloc] initWithWindowNibName:@"InfoWindow"];
            
        //set item
        infoWindowController.item = [[Item alloc] init:selectedItem.path];
        
        //'save' window controller
        // allows item to call back & update window once code signing checks are completed
        infoWindowController.item.windowController = infoWindowController;
        
        //center window
        [[infoWindowController window] center];
        
        //show it
        [infoWindowController showWindow:self];
        
    });
    
    return;
}

@end
