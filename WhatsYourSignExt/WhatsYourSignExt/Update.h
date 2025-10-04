//
//  file: Update.h
//  project: WYS (shared)
//  description: checks for new versions of
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//


#ifndef Update_h
#define Update_h

#define LATEST_VERSION @"version"
#define PRODUCT_NAME @"WhatsYourSign"
#define SUPPORTED_OS_MAJOR @"OSMajor"
#define SUPPORTED_OS_MINOR @"OSMinor"
#define PRODUCT_VERSIONS_URL @"https://objective-see.org/products.json"
#define PRODUCT_PAGE @"https://objective-see.org/products/whatsyoursign.html"

@import Cocoa;
@import Foundation;

//updates
typedef enum {Update_Error, Update_None, Update_NotSupported, Update_Available} UpdateStatus;

@interface Update : NSObject

//check for an update
// will invoke app delegate method to update UI when check completes
-(void)checkForUpdate:(void (^)(NSUInteger result, NSString* latestVersion))completionHandler;

@end

#endif /* Update_h */
