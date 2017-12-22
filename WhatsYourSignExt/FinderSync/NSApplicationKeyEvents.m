//
//  NSApplicationKeyEvents.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 7/11/15.
//  Copyright (c) 2015 Objective-See. All rights reserved.
//

#import "NSApplicationKeyEvents.h"

@implementation NSApplicationKeyEvents

//to enable copy/paste etc even though we don't have an 'Edit' menu
// details: http://stackoverflow.com/questions/970707/cocoa-keyboard-shortcuts-in-dialog-without-an-edit-menu
-(void) sendEvent:(NSEvent *)event
{
    //keydown
    if([event type] == NSKeyDown)
    {
        //command
        if(([event modifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSCommandKeyMask)
        {
            //+c
            if([[event charactersIgnoringModifiers] isEqualToString:@"c"])
            {
                if([self sendAction:@selector(copy:) to:nil from:self])
                {
                    return;
                }
            }
           
            //+a
            else if ([[event charactersIgnoringModifiers] isEqualToString:@"a"])
            {
                if ([self sendAction:@selector(selectAll:) to:nil from:self])
                {
                    return;
                }
            }
        }
    }
    
    //super
    [super sendEvent:event];
}

@end
