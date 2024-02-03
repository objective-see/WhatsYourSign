//
//  Consts.h
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef WYS_Consts_h
#define WYS_Consts_h

//success
#define STATUS_SUCCESS 0

//product url
#define PRODUCT_URL @"https://objective-see.com/products/whatsyoursign.html"

//bundle ID of finder sync extension
#define EXTENSION_BUNDLE_ID @"com.objective-see.WhatsYourSignExt.FinderSync"

//extension folder
// ->for older versions of the app
#define OLD_LOCATION @"~/Library/WhatsYourSign"

//extension name
#define EXTENSION_NAME @"WhatsYourSign.appex"

//app folder (newer versions)
#define NEW_LOCATION @"/Applications/WhatsYourSign.app"

//patreon url
#define PATREON_URL @"https://www.patreon.com/bePatron?c=701171"

//app location
// ->set to 'NEW_LOCATION'
#define APP_LOCATION NEW_LOCATION

//app name
#define APP_NAME @"WhatsYourSign.app"

//key for stdout output
#define STDOUT @"stdOutput"

//key for stderr output
#define STDERR @"stdError"

//key for exit code
#define EXIT_CODE @"exitCode"

//max enable attempts
#define MAX_ENABLE_ATTEMPTS 10

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

//entitlements
#define KEY_SIGNING_ENTITLEMENTS @"entitlements"

//file belongs to apple?
#define KEY_SIGNING_IS_APPLE @"signedByApple"

//file signed with apple dev id
#define KEY_SIGNING_IS_APPLE_DEV_ID @"signedWithDevID"

//from app store
#define KEY_SIGNING_IS_APP_STORE @"fromAppStore"

//is notarized?
#define KEY_SIGNING_IS_NOTARIZED @"notarized"

//flags
#define KEY_SIGNING_FLAGS @"flags"

//path to file binary
#define FILE @"/usr/bin/file"

//path to pluginkit binary
#define PLUGIN_KIT @"/usr/bin/pluginkit"

//path to pkgutil
#define PKG_UTIL @"/usr/sbin/pkgutil"

//path to spctl
#define SPCTL @"/usr/sbin/spctl"

//path to xattr
#define XATTR @"/usr/bin/xattr"

//path to open
#define OPEN @"/usr/bin/open"

//path to killall
#define KILLALL @"/usr/bin/killall"

//button title: upgrade
#define ACTION_UPGRADE @"Upgrade"

//action to uninstall
// ->also button title
#define ACTION_UNINSTALL @"Uninstall"

//button title: close
#define ACTION_CLOSE @"Close"

//button title: restart
#define ACTION_RESTART @"Restart Finder"

//button title: next
#define ACTION_NEXT @"Next »"

//flag to uninstall
#define ACTION_UNINSTALL_FLAG 0

//flag to install
#define ACTION_INSTALL_FLAG 1

//flag to close
#define ACTION_CLOSE_FLAG 2

//flag for next
#define ACTION_RESTART_FLAG 3

//flag for next
#define ACTION_NEXT_FLAG 4

//flag for support
#define ACTION_SUPPORT_FLAG 5

//error msg
#define KEY_ERROR_MSG @"errorMsg"

//sub msg
#define KEY_ERROR_SUB_MSG @"errorSubMsg"

//error URL
#define KEY_ERROR_URL @"errorURL"

//flag for error popup
#define KEY_ERROR_SHOULD_EXIT @"shouldExit"

//general error URL
#define FATAL_ERROR_URL @"https://objective-see.org/errors.html"

//support us button tag
#define BUTTON_SUPPORT_US 100

//more info button tag
#define BUTTON_MORE_INFO 101

//key md5
#define KEY_HASH_MD5 @"MD5"

//key sha1
#define KEY_HASH_SHA1 @"SHA1"

//key sha256
#define KEY_HASH_SHA256 @"SHA256"

//key sha512
#define KEY_HASH_SHA512 @"SHA512"

#endif
