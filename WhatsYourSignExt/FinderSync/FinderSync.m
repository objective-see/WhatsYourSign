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

@synthesize directories;

//init
-(instancetype)init
{
    self = [super init];
    if(nil != self)
    {
        //init
        directories = [NSMutableSet set];
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"extension (%@) off and running", [[NSBundle mainBundle] bundlePath]]);
        
        
        /*
        NSArray* dirs = [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:@[] options:0];
        int count = 0;
        for(NSURL* dir in dirs)
        {
            NSLog(@"OMG: dir: %@", dir);
            //if(YES == [dir.path isEqualToString:@"/"]) continue;
            
            //add to set
            [self.directories addObject:dir];
            
            
            
            //Create App directory if not exists:
            NSFileManager* fileManager = [[NSFileManager alloc] init];
            NSString* bundleID = [[NSBundle mainBundle] bundleIdentifier];
            NSArray* urlPaths = [fileManager URLsForDirectory:NSApplicationSupportDirectory
                                                    inDomains:NSUserDomainMask];

            NSURL* appDirectory = [[urlPaths objectAtIndex:0] URLByAppendingPathComponent:bundleID isDirectory:YES];
            if (![fileManager fileExistsAtPath:[appDirectory path]]) {
                [fileManager createDirectoryAtURL:appDirectory withIntermediateDirectories:NO attributes:nil error:nil];
            }
            
            
            NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:dir.path];
            NSLog(@"OMG: icon for %@ is %@", dir.path, icon);
            
            NSString* path = [NSString stringWithFormat:@"%@/%d.tif", appDirectory.path, count++];
            
            // Write to TIF
            if(YES != [[icon TIFFRepresentation] writeToFile:path atomically:YES])
            {
                NSLog(@"OMG: failed to write %@ to file", path);
            }
            else
            {
                NSLog(@"OMG: wrote file to %@", path);
            }
        }
        */
        
        self.directories = [NSMutableSet setWithArray: [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:@[] options:0]];
        
        //dbg msg
        NSLog(@"OMG: initializing 'watch' directories with: %@", self.directories);
        
        //catalina?
        // watch all mounted volumes
        //if(YES == [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 15, 0}])
        //{
            //watch all
            //self.directories = [NSMutableSet setWithArray:@[@"/Users/patrick/Downloads"]];
            //self.directories = [NSMutableSet setWithArray: [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:@[] options:0]];
        //}
        //pre-catalina
        // watch all mounted volumes, but skip '/.file'
        //else
        /*{
            //watch all mounted volumes
            // note: skip '/' as it causes perf issues, but will watch it sub-directories
            for(NSURL* volume in [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:@[] options:0])
            {
                //skip '/'
                if(YES == [volume.path isEqualToString:@"/"]) continue;
            
                //add to set
                [self.directories addObject:volume];
            }
            
            //NSWorkspace (see setIcon:forFile:options)
            
            
            //also add all directories under '/'
            // ...but skip '/.file' otherwise is cause file writes to be delayed...
            for(NSURL* directory in [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:@"/"] includingPropertiesForKeys:@[] options:0 error:nil])
            {
                //skip '/.file'
                if(YES == [directory.path isEqualToString:@"/.file"]) continue;
                
                //add to set
                [self.directories addObject:directory];
                
                NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:directory.path];
                NSLog(@"OMG: icon for %@ is %@", directory.path, icon);
                
                [[NSWorkspace sharedWorkspace] setIcon:icon forFile:directory.path options:0];
                
                
            }
        }
        */
        
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"initializing 'watch' directories with: %@", self.directories]);
        
        //set directories
        [FIFinderSyncController defaultController].directoryURLs = self.directories;
        
        
        /*
        // Delay execution of my block for 10 seconds.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
            
            NSLog(@"OMG: checking icons now...");
            
            
            //Create App directory if not exists:
                  NSFileManager* fileManager = [[NSFileManager alloc] init];
                  NSString* bundleID = [[NSBundle mainBundle] bundleIdentifier];
                  NSArray* urlPaths = [fileManager URLsForDirectory:NSApplicationSupportDirectory
                                                          inDomains:NSUserDomainMask];

                  NSURL* appDirectory = [[urlPaths objectAtIndex:0] URLByAppendingPathComponent:bundleID isDirectory:YES];
                   int count = 0;
                   for(NSURL* dir in self.directories)
                   {
                       NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:dir.path];
                       NSLog(@"OMG: icon for %@ is %@", dir.path, icon);
                       
                       NSString* path = [NSString stringWithFormat:@"%@/now_%d.tif", appDirectory.path, count++];
                       
                       // Write to TIF
                       if(YES != [[icon TIFFRepresentation] writeToFile:path atomically:YES])
                       {
                           NSLog(@"OMG: failed to write %@ to file", path);
                       }
                       else
                       {
                           NSLog(@"OMG: wrote file to %@", path);
                       }
                   }
            
        });
        */
        
       
        
        
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
    
    //TODO: ignore /.file? or?
    
    
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
        [self.directories addObject:notification.userInfo[NSWorkspaceVolumeURLKey]];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            
            NSLog(@"OMG: setting icon!");
            
            //Create App directory if not exists:
                             NSFileManager* fileManager = [[NSFileManager alloc] init];
                             NSString* bundleID = [[NSBundle mainBundle] bundleIdentifier];
                             NSArray* urlPaths = [fileManager URLsForDirectory:NSApplicationSupportDirectory
                                                                     inDomains:NSUserDomainMask];

                             NSURL* appDirectory = [[urlPaths objectAtIndex:0] URLByAppendingPathComponent:bundleID isDirectory:YES];
            
            NSString* path = [notification.userInfo[NSWorkspaceVolumeURLKey] path];
            
            NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
            
            [[NSWorkspace sharedWorkspace] setIcon:icon forFile:path options:0];
            
            NSString* outPath = [NSString stringWithFormat:@"%@/now_777.tif", appDirectory.path];
            
            // Write to TIF
            if(YES != [[icon TIFFRepresentation] writeToFile:outPath atomically:YES])
            {
                NSLog(@"OMG: failed to write %@ to file", outPath);
            }
            else
            {
                NSLog(@"OMG: wrote file to %@", outPath);
            }
            
        });
    }
    
    //unmount?
    // remove volume
    else if(YES == [notification.name isEqualToString:NSWorkspaceDidUnmountNotification])
    {
        //dbg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"removing %@", [notification.userInfo[NSWorkspaceVolumeURLKey] path]]);
        
        //remove from set
        [self.directories removeObject:notification.userInfo[NSWorkspaceVolumeURLKey]];
    }
    
    //update watched directories
    [FIFinderSyncController defaultController].directoryURLs = self.directories;
    
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
