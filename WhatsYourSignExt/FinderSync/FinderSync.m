//
//  FinderSync.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 7/5/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Logging.h"
#import "FinderSync.h"

@implementation FinderSync

@synthesize volumes;

//init
-(instancetype)init
{
    self = [super init];
    if(nil != self)
    {
        //init
        volumes = [NSMutableSet set];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"extension (%@) off and running", [[NSBundle mainBundle] bundlePath]]);
        
        //watch all volumes
        for(NSURL* volume in [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:nil options:NSVolumeEnumerationSkipHiddenVolumes])
        {
            //add to set
            [self.volumes addObject:volume];
        }
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"mounted volumes: %@", self.volumes]);
        
        //set directories
        [FIFinderSyncController defaultController].directoryURLs = self.volumes;
        
        //register for volume mount
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector: @selector(volumeEvent:) name:NSWorkspaceDidMountNotification object:nil];
        
        //register for volume unmount
        [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector: @selector(volumeEvent:) name:NSWorkspaceDidUnmountNotification object:nil];
    }
    
    return self;
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
    [menu addItemWithTitle:@"Signing Info" action:@selector(showSigningInfo:) keyEquivalent:@""];
    
bail:

    return menu;
}

//callback for volume events
-(void)volumeEvent:(NSNotification*)notification
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"volume notification: %@", notification]);
    
    //mount?
    // add volume
    if(YES == [notification.name isEqualToString:NSWorkspaceDidMountNotification])
    {
        //dbg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"adding %@", [notification.userInfo[NSWorkspaceVolumeURLKey] path]]);
        
        //add to set
        [self.volumes addObject:notification.userInfo[NSWorkspaceVolumeURLKey]];
    }
    
    //unmount?
    // remove volume
    else if(YES == [notification.name isEqualToString:NSWorkspaceDidUnmountNotification])
    {
        //dbg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removing %@", [notification.userInfo[NSWorkspaceVolumeURLKey] path]]);
        
        //remove from set
        [self.volumes removeObject:notification.userInfo[NSWorkspaceVolumeURLKey]];
    }
    
    //update watched directories
    [FIFinderSyncController defaultController].directoryURLs = self.volumes;
    
    return;
}


//show signing info
-(void)showSigningInfo:(id)sender
{
    //selected item
    NSURL* selectedItem = nil;
    
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
