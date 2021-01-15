//
//  EntitlementsWindowController.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 12/19/17.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "EntitlementsWindowController.h"


@implementation EntitlementsWindowController

//window load
- (void)windowDidLoad
{
    //super
    [super windowDidLoad];
    
    //set font
    self.entitlements.font = [NSFont fontWithName:@"Menlo" size:11];
    
    //set inset
    self.entitlements.textContainerInset = NSMakeSize(0, 10);
    
    //add entitlements
    self.entitlements.string = [self.signingInfo[KEY_SIGNING_ENTITLEMENTS] description];
    
    //make first responder
    // calling this without a timeout sometimes fails :/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        //and make it first responder
        [self.window makeFirstResponder:self.closeButton];
        
    });
    
    return;
}

//close
// end sheet
-(IBAction)close:(id)sender
{
    //end sheet
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    
    return;
}

@end
