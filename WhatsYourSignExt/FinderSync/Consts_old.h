//
//  Consts.h
//  WhatsYourSign
//
//  Created by Patrick Wardle on 2/4/15.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef WYS_Consts_h
#define WYS_Consts_h

//success
#define STATUS_SUCCESS 0

//product url
#define PRODUCT_URL @"https://objective-see.com/products/whatsyoursign.html"

//installed extensions
#define INSTALLED_EXTENSIONS @"~/Library/Preferences/com.apple.preferences.extensions.FinderSync.plist"

//frame shift
// ->for status msg to avoid activity indicator
#define FRAME_SHIFT 45

//hotkey 'w'
#define KEYCODE_W 0xD

//hotkey 'q'
#define KEYCODE_Q 0xC

//signature status
#define KEY_SIGNATURE_STATUS @"signatureStatus"

//signing auths
#define KEY_SIGNING_AUTHORITIES @"signingAuthorities"

//file belongs to apple?
#define KEY_SIGNING_IS_APPLE @"signedByApple"

//OS version x
#define OS_MAJOR_VERSION_X 10

//OS minor version yosemite
#define OS_MINOR_VERSION_YOSEMITE 10

//OS minor version el capitan
#define OS_MINOR_VERSION_EL_CAPITAN 11

//path to file command
#define FILE @"/usr/bin/file"

//action to install
// ->also button title
#define ACTION_INSTALL @"Install"

//action to uninstall
// ->also button title
#define ACTION_UNINSTALL @"Uninstall"

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//flag to install
#define ACTION_INSTALL_FLAG 1

#endif
