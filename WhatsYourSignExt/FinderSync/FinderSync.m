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

//init
-(instancetype)init
{
    self = [super init];
    if(nil != self)
    {
        //dbg msg
        logMsg(LOG_DEBUG, [NSString stringWithFormat:@"extension (%@) off and running", [[NSBundle mainBundle] bundlePath]]);
        
        //watch all directories
        [FIFinderSyncController defaultController].directoryURLs = [NSSet setWithObject:[NSURL fileURLWithPath:@"/"]];
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
