//
//  main.h
//  WhatsYourSign_Installer
//
//  Created by Patrick Wardle on 9/30/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#ifndef main_h
#define main_h

#import "Consts.h"
#import "Logging.h"

#include <pwd.h>
#include <grp.h>

//check if app should be run with permissions
// ->basically if user is not an admin, or was installed via admin
BOOL shouldPrompt4Perms(void);

//spawn self as root
BOOL spawnAsRoot(const char* path2Self);

//checks if user has admin privs
BOOL hasAdminPrivileges(void);

#endif
