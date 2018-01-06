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
- (void)windowDidLoad
{
    //formatted hashes
    NSMutableString* formattedHashes = nil;
    
    //super
    [super windowDidLoad];
    
    //init
    formattedHashes = [NSMutableString string];
    
    //set font
    self.hashes.font = [NSFont fontWithName:@"Menlo" size:11];
    
    //set inset
    self.hashes.textContainerInset = NSMakeSize(0, 10);
    
    //add md5
    if(nil != self.signingInfo[KEY_SIGNING_HASHES][KEY_HASH_MD5])
    {
        [formattedHashes appendString:[NSString stringWithFormat:@"%@:    %@\n", KEY_HASH_MD5, self.signingInfo[KEY_SIGNING_HASHES][KEY_HASH_MD5]]];
    }
    
    //add sha1
    if(nil != self.signingInfo[KEY_SIGNING_HASHES][KEY_HASH_SHA1])
    {
        [formattedHashes appendString:[NSString stringWithFormat:@"%@:   %@\n", KEY_HASH_SHA1, self.signingInfo[KEY_SIGNING_HASHES][KEY_HASH_SHA1]]];
    }
    
    //add sha256
    if(nil != self.signingInfo[KEY_SIGNING_HASHES][KEY_HASH_SHA256])
    {
        [formattedHashes appendString:[NSString stringWithFormat:@"%@: %@\n", KEY_HASH_SHA256, self.signingInfo[KEY_SIGNING_HASHES][KEY_HASH_SHA256]]];
    }
    
    //add hashes
    self.hashes.string = formattedHashes;
    
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
