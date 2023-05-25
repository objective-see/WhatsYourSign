//
//  main.m
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/5/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "main.h"

@import Cocoa;

//main interface
// ->check if admin, if not, spawn with privs
int main(int argc, const char * argv[])
{
    //return var
    int retVar = -1;
    
    @autoreleasepool
    {
        //check if app should be spawned with privs
        if(YES == shouldPrompt4Perms())
        {
            //dbg msg
            //logMsg(LOG_DEBUG, @"non-privileged installer instance");
            
            //spawn as root
            if(YES != spawnAsRoot(argv[0]))
            {
                //err msg
                //logMsg(LOG_ERR, @"failed to spawn self with privileges");
                
                //bail
                goto bail;
            }
            
            //happy
            retVar = 0;
        }
        
        //otherwise
        // ->just kick off app, as we're admin/priv'd now
        else
        {
            //dbg msg
            //logMsg(LOG_DEBUG, @"privileged installer instance");
            
            //app away
            retVar = NSApplicationMain(argc, (const char **)argv);
        }
        
    }//pool
    
//bail
bail:
    
    return retVar;
}

//check if app should be run with permissions
// ->basically if user is not an admin, or was installed via admin
BOOL shouldPrompt4Perms(void)
{
    //flag
    BOOL shouldPrompt = YES;
    
    //root
    if(0 == geteuid())
    {
        //all g
        shouldPrompt = NO;
        
        //bail
        goto bail;
    }
    
    //admin & app deletable?
    if(YES == hasAdminPrivileges())
    {
        //app not there
        // ->all g
        if(YES != [[NSFileManager defaultManager] fileExistsAtPath:APP_LOCATION])
        {
            //all g
            shouldPrompt = NO;
            
            //bail
            goto bail;
        }
        
        //app there + deletable
        // ->all g
        if( (YES == [[NSFileManager defaultManager] fileExistsAtPath:APP_LOCATION]) &&
            (YES == [[NSFileManager defaultManager] isWritableFileAtPath:APP_LOCATION]) )
        {
            //all g
            shouldPrompt = NO;
            
            //bail
            goto bail;
        }
    }
    
//bail
bail:
    
    return shouldPrompt;
}

//checks if user has admin privs
// ->based off http://stackoverflow.com/questions/30000443/asking-for-admin-privileges-for-only-standard-accounts
BOOL hasAdminPrivileges(void)
{
    //flag
    BOOL isAdmin = NO;
    
    //password entry
    struct passwd* pwentry = NULL;
    
    //admin group
    struct group* adminGroup = NULL;
    
    //get password entry for current user
    pwentry = getpwuid(getuid());
    
    //get admin group
    adminGroup = getgrnam("admin");
    
    //iterate over entries
    // ->check if current user is part of the admin group
    while(*adminGroup->gr_mem != NULL)
    {
        //check if admin
        if (strcmp(pwentry->pw_name, *adminGroup->gr_mem) == 0)
        {
            //yay!
            isAdmin = YES;
            
            //exit loop
            break;
        }
        
        //try next
        adminGroup->gr_mem++;
    }
    
    return isAdmin;
}

//spawn self as root
BOOL spawnAsRoot(const char* path2Self)
{
    //return/status var
    BOOL bRet = NO;
    
    //authorization ref
    AuthorizationRef authorizatioRef = {0};
    
    //args
    char *args[] = {NULL};
    
    //flag creation of ref
    BOOL authRefCreated = NO;
    
    //status code
    OSStatus osStatus = -1;
    
    //create authorization ref
    // ->and check
    osStatus = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizatioRef);
    if(errAuthorizationSuccess != osStatus)
    {
        //err msg
        //logMsg(LOG_ERR, [NSString stringWithFormat:@"AuthorizationCreate() failed with %d", osStatus]);
        
        //bail
        goto bail;
    }
    
    //set flag indicating auth ref was created
    authRefCreated = YES;
    
    //spawn self as r00t w/ install flag (will ask user for password)
    // ->and check
    osStatus = AuthorizationExecuteWithPrivileges(authorizatioRef, path2Self, 0, args, NULL);
    
    //check
    if(errAuthorizationSuccess != osStatus)
    {
        //err msg
        //logMsg(LOG_ERR, [NSString stringWithFormat:@"AuthorizationExecuteWithPrivileges() failed with %d", osStatus]);
        
        //bail
        goto bail;
    }
    
    //no errors
    bRet = YES;
    
//bail
bail:
    
    //free auth ref
    if(YES == authRefCreated)
    {
        //free
        AuthorizationFree(authorizatioRef, kAuthorizationFlagDefaults);
    }
    
    return bRet;
}

