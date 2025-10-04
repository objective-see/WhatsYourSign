//
//  FinderSync.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 7/5/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import <os/log.h>
#import "FinderSync.h"

@implementation FinderSync

@synthesize directories;

//init
// watch all the things, though logic is a bit nuances due to a badging issue on macOS (impacting external drives)
-(instancetype)init
{
    self = [super init];
    if(nil != self)
    {
        //init directories set
        self.directories = [NSMutableSet set];

        //get all mounted volumes
        NSArray *volumes = [NSFileManager.defaultManager mountedVolumeURLsIncludingResourceValuesForKeys:@[NSURLVolumeIsRootFileSystemKey] options:NSVolumeEnumerationSkipHiddenVolumes];
        
        //for each volume
        // add to watched directories
        for(NSURL *volume in volumes) {
            [self monitorVolume:volume];
        }

        //now set directories
        [FIFinderSyncController defaultController].directoryURLs = self.directories;
    
        //register for volume mount
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector: @selector(volumeEvent:) name:NSWorkspaceDidMountNotification object:nil];
        
        //register for volume unmount
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector: @selector(volumeEvent:) name:NSWorkspaceDidUnmountNotification object:nil];
    }
    
    return self;
}

// monitor volume
// internal drives: adds the root itself
// external drives: adds all items at root (avoids badging)
-(void)monitorVolume:(NSURL *)volume
{
    NSNumber *isRootVolume = nil;
    
    //get 'is root' key
    [volume getResourceValue:&isRootVolume forKey:NSURLVolumeIsRootFileSystemKey error:nil];

    //root?
    // can just watch entire volume
    if([isRootVolume boolValue]) {
        
        //dbg msg
        //os_log_debug(OS_LOG_DEFAULT, "WYS: monitoring root volume: %@", volume);
        
        //add
        [self.directories addObject:volume];
    }
    //external drive?
    // add subdirectories AND files at root (avoids badging)
    // but also need logic to manually find / add contents of bundles
    else
    {
        //get top-level contents
        NSArray* contents = [NSFileManager.defaultManager contentsOfDirectoryAtURL:volume
                             includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsPackageKey]
                             options:NSDirectoryEnumerationSkipsHiddenFiles
                             error:nil];
        
        //add each top-level item
        for(NSURL* item in contents) {
            
            //dbg msg
            //os_log_debug(OS_LOG_DEFAULT, "WYS: adding top-level item: %{public}@", item);
            
            [self.directories addObject:item];
        }
        
        //recursively find all bundles
        // and add their contents, cuz for some reason this isn't done by default
        [self addBundles:volume];
    }
    
    //update watched directories
    [FIFinderSyncController defaultController].directoryURLs = self.directories;
    
    return;
}

//find/add bundles
- (void)addBundles:(NSURL*)directoryURL {
    
    NSDirectoryEnumerator* enumerator = [NSFileManager.defaultManager
        enumeratorAtURL:directoryURL
        includingPropertiesForKeys:@[NSURLIsPackageKey]
        options:NSDirectoryEnumerationSkipsHiddenFiles
        errorHandler:nil];
    
    for (NSURL* item in enumerator) {
        
        //add bundles
        NSNumber* isPackage;
        [item getResourceValue:&isPackage forKey:NSURLIsPackageKey error:nil];
        
        if (isPackage.boolValue) {
            
            //add bundle's (top-level) items
            [self addBundle:item];
        }
    }
}

//add bundle's items
- (void)addBundle:(NSURL*)bundle {

    //add
    [self.directories addObject:bundle];
    
    //add only top-level items inside the package (non-recursive)
    NSArray* contents = [NSFileManager.defaultManager
        contentsOfDirectoryAtURL:bundle
        includingPropertiesForKeys:@[NSURLIsDirectoryKey]
        options:0
        error:nil];
    
    for (NSURL* item in contents) {
        
        //dbg msg
        //os_log_debug(OS_LOG_DEFAULT, "WYS: adding top-level package item: %{public}@", item);
        
        //add
        [self.directories addObject:item];
    }
}


//unmonitor
-(void)unmonitorVolume:(NSURL *)volume
{
    NSNumber *isRootVolume = nil;
    
    //get 'is root' key
    [volume getResourceValue:&isRootVolume forKey:NSURLVolumeIsRootFileSystemKey error:nil];

    //root?
    // can just remove volume
    if([isRootVolume boolValue]) {
        
        //dbg msg
        //os_log_debug(OS_LOG_DEFAULT, "WYS: unmonitoring root volume: %{public}@", volume);
        
        //remove
        [self.directories removeObject:volume];
    }
    //external drive?
    // remove subdirectories AND files at root (avoids badging)
    else
    {
        //dbg msg
        //os_log_debug(OS_LOG_DEFAULT, "WYS: unmonitoring non-root volume: %{public}@", volume.path);
        
        //find all directories that start with this volume's path
        NSSet* unwatch = [self.directories objectsPassingTest:^BOOL(NSURL *url, BOOL *stop) {
            return [url.path hasPrefix:volume.path];
        }];
        
        //remove
        [self.directories minusSet:unwatch];
    }
    
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
        [self monitorVolume:notification.userInfo[NSWorkspaceVolumeURLKey]];
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
