//
//  HashesWindowController.m
//  WhatsYourSignExt
//
//  Created by Patrick Wardle on 12/21/17.
//  Copyright (c) 2017 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "HashesWindowController.h"

@implementation HashesWindowController

//window load
-(void)windowDidLoad
{
    //formatted hashes
    NSMutableString* formattedHashes = nil;
    
    //super
    [super windowDidLoad];
    
    //init
    formattedHashes = [NSMutableString string];
    
    //set font
    self.hashList.font = [NSFont fontWithName:@"Menlo" size:11];
    
    //set inset
    self.hashList.textContainerInset = NSMakeSize(0, 10);
    
    //add md5
    if(nil != self.hashes[KEY_HASH_MD5])
    {
        [formattedHashes appendString:[NSString stringWithFormat:@"%@:    %@\n", KEY_HASH_MD5, self.hashes[KEY_HASH_MD5]]];
    }
    
    //add sha1
    if(nil != self.hashes[KEY_HASH_SHA1])
    {
        [formattedHashes appendString:[NSString stringWithFormat:@"%@:   %@\n", KEY_HASH_SHA1, self.hashes[KEY_HASH_SHA1]]];
    }
    
    //add sha256
    if(nil != self.hashes[KEY_HASH_SHA256])
    {
        [formattedHashes appendString:[NSString stringWithFormat:@"%@: %@\n", KEY_HASH_SHA256, self.hashes[KEY_HASH_SHA256]]];
    }
    
    //add sha512
    if(nil != self.hashes[KEY_HASH_SHA512])
    {
        [formattedHashes appendString:[NSString stringWithFormat:@"%@: %@\n", KEY_HASH_SHA512, self.hashes[KEY_HASH_SHA512]]];
    }
    
    //add hashes
    self.hashList.string = formattedHashes;
    
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
