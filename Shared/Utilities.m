//
//  Utilities.m
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "Consts.h"
#import "Logging.h"
#import "Utilities.h"

#import <signal.h>
#import <unistd.h>
#import <libproc.h>
#import <sys/sysctl.h>
#import <Security/Security.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <SystemConfiguration/SystemConfiguration.h>

//get app's version
// ->extracted from Info.plist
NSString* getAppVersion()
{
    //read and return 'CFBundleVersion' from bundle
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}

//given a path to binary
// parse it back up to find app's bundle
NSBundle* findAppBundle(NSString* path)
{
    //app's bundle
    NSBundle* appBundle = nil;
    
    //app's path
    NSString* appPath = nil;
    
    //first just try full path
    appPath = path;
    
    //try to find the app's bundle/info dictionary
    do
    {
        //try to load app's bundle
        appBundle = [NSBundle bundleWithPath:appPath];
        
        //got bundle?
        // check if path is for app, or binary matches
        if(nil != appBundle)
        {
            //path is for app, or binary matches
            if( (YES == [path hasSuffix:@".app"]) ||
                (YES == [appBundle.executablePath isEqualToString:path]) )
            {
                //all set
                break;
            }
        }
        
        //always unset bundle var since it's being returned
        // ->and at this point, its not a match
        appBundle = nil;
        
        //remove last part
        // ->will try this next
        appPath = [appPath stringByDeletingLastPathComponent];
        
    //scan until we get to root
    // ->of course, loop will exit if app info dictionary is found/loaded
    } while( (nil != appPath) &&
             (YES != [appPath isEqualToString:@"/"]) &&
             (YES != [appPath isEqualToString:@""]) );
    
    return appBundle;
}

//check if file is (likely) fat binary
BOOL isBinaryFat(NSString* path)
{
    //fat
    BOOL isFat = NO;
    
    //handle
    NSFileHandle *handle = nil;
    
    //magic (4-bytes)
    NSData *magic = nil;
    
    //open
    handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if(nil == handle)
    {
        //bail
        goto bail;
    }
    
    //wrap
    @try
    {
        //read first 4 bytes
        magic = [handle readDataOfLength:0x4];
    }
    @catch(NSException *exception)
    {
        //bail
        goto bail;
    }
    
    //sanity check
    if(magic.length < 0x4)
    {
        //bail
        goto bail;
    }
    
    //universal (fat)?
    if( (FAT_MAGIC != *(const uint32_t *)magic.bytes) &&
        (FAT_CIGAM != *(const uint32_t *)magic.bytes) )
    {
        //bail
        goto bail;
    }
    
    //ok fat!
    isFat = YES;
    
bail:
    
    //close handle
    if(nil != handle)
    {
        //close
        [handle closeFile];
        
        //unset
        handle = nil;
    }
    
    return isFat;
}

//exec a process and grab it's stdout/stderr/exit code
NSMutableDictionary* execTask(NSString* binaryPath, NSArray* arguments)
{
    //task
    NSTask* task = nil;
    
    //output pipe for stdout
    NSPipe* stdOutPipe = nil;
    
    //output pipe for stderr
    NSPipe* stdErrPipe = nil;
    
    //read handle for stdout
    NSFileHandle* stdOutReadHandle = nil;
    
    //read handle for stderr
    NSFileHandle* stdErrReadHandle = nil;
    
    //results dictionary
    NSMutableDictionary* results = nil;
    
    //output for stdout
    NSMutableData *stdOutData = nil;
    
    //output for stderr
    NSMutableData *stdErrData = nil;
    
    //init dictionary for results
    results = [NSMutableDictionary dictionary];
    
    //init task
    task = [NSTask new];
    
    //init stdout pipe
    stdOutPipe = [NSPipe pipe];
    
    //init stderr pipe
    stdErrPipe = [NSPipe pipe];
    
    //init stdout read handle
    stdOutReadHandle = [stdOutPipe fileHandleForReading];
    
    //init stderr read handle
    stdErrReadHandle = [stdErrPipe fileHandleForReading];

    //init stdout output buffer
    stdOutData = [NSMutableData data];
    
    //init stderr output buffer
    stdErrData = [NSMutableData data];
    
    //set task's path
    task.launchPath = binaryPath;
    
    //set task's args
    task.arguments = arguments;
    
    //set task's stdout
    task.standardOutput = stdOutPipe;
    
    //set task's stderr
    task.standardError = stdErrPipe;
    
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"execing task, %@ (arguments: %@)", task.launchPath, task.arguments]);
    
    //wrap task launch
    @try
    {
        //launch
        [task launch];
    }
    @catch(NSException *exception)
    {
        //bail
        goto bail;
    }
    
    //read in stdout/stderr
    while(YES == [task isRunning])
    {
        //accumulate stdout
        [stdOutData appendData:[stdOutReadHandle readDataToEndOfFile]];
        
        //accumulate stderr
        [stdErrData appendData:[stdErrReadHandle readDataToEndOfFile]];
    }
    
    //grab any leftover stdout
    [stdOutData appendData:[stdOutReadHandle readDataToEndOfFile]];
    
    //grab any leftover stderr
    [stdErrData appendData:[stdErrReadHandle readDataToEndOfFile]];
    
    //add stdout
    if(0 != stdOutData.length)
    {
        //add
        results[STDOUT] = stdOutData;
    }
    
    //add stderr
    if(0 != stdErrData.length)
    {
        //add
        results[STDERR] = stdErrData;
    }

    //add exit code
    results[EXIT_CODE] = [NSNumber numberWithInteger:task.terminationStatus];
    
bail:
    
    return results;
}

//get OS's major or minor version
SInt32 getVersion(OSType selector)
{
    //version
    // ->major or minor
    SInt32 version = -1;
    
    //get version info
    if(noErr != Gestalt(selector, &version))
    {
        //reset version
        version = -1;
        
        //err
        goto bail;
    }
    
bail:
    
    return version;
}

//get process's path
NSString* getProcessPath(pid_t pid)
{
    //task path
    NSString* processPath = nil;
    
    //buffer for process path
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE] = {0};
    
    //status
    int status = -1;
    
    //'management info base' array
    int mib[3] = {0};
    
    //system's size for max args
    int systemMaxArgs = 0;
    
    //process's args
    char* taskArgs = NULL;
    
    //# of args
    int numberOfArgs = 0;
    
    //size of buffers, etc
    size_t size = 0;
    
    //reset buffer
    bzero(pathBuffer, PROC_PIDPATHINFO_MAXSIZE);
    
    //first attempt to get path via 'proc_pidpath()'
    status = proc_pidpath(pid, pathBuffer, sizeof(pathBuffer));
    if(0 != status)
    {
        //init task's name
        processPath = [NSString stringWithUTF8String:pathBuffer];
    }
    //otherwise
    // ->try via task's args ('KERN_PROCARGS2')
    else
    {
        //init mib
        // ->want system's size for max args
        mib[0] = CTL_KERN;
        mib[1] = KERN_ARGMAX;
        
        //set size
        size = sizeof(systemMaxArgs);
        
        //get system's size for max args
        if(-1 == sysctl(mib, 2, &systemMaxArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //alloc space for args
        taskArgs = malloc(systemMaxArgs);
        if(NULL == taskArgs)
        {
            //bail
            goto bail;
        }
        
        //init mib
        // ->want process args
        mib[0] = CTL_KERN;
        mib[1] = KERN_PROCARGS2;
        mib[2] = pid;
        
        //set size
        size = (size_t)systemMaxArgs;
        
        //get process's args
        if(-1 == sysctl(mib, 3, taskArgs, &size, NULL, 0))
        {
            //bail
            goto bail;
        }
        
        //sanity check
        // ->ensure buffer is somewhat sane
        if(size <= sizeof(int))
        {
            //bail
            goto bail;
        }
        
        //extract number of args
        // ->at start of buffer
        memcpy(&numberOfArgs, taskArgs, sizeof(numberOfArgs));
        
        //extract task's name
        // ->follows # of args (int) and is NULL-terminated
        processPath = [NSString stringWithUTF8String:taskArgs + sizeof(int)];
    }
    
bail:
    
    //free process args
    if(NULL != taskArgs)
    {
        //free
        free(taskArgs);
        
        //reset
        taskArgs = NULL;
    }
    
    return processPath;
}


//find a process by name
pid_t findProcess(NSString* processName)
{
    //pid
    pid_t processID = -1;
    
    //status
    int status = -1;
    
    //# of procs
    int numberOfProcesses = 0;
    
    //array of pids
    pid_t* pids = NULL;
    
    //process path
    NSString* processPath = nil;
    
    //get # of procs
    numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    
    //alloc buffer for pids
    pids = calloc(numberOfProcesses, sizeof(pid_t));
    
    //get list of pids
    status = proc_listpids(PROC_ALL_PIDS, 0, pids, numberOfProcesses * sizeof(pid_t));
    if(status < 0)
    {
        //bail
        goto bail;
    }
    
    //iterate over all pids
    // ->get name for each via helper function
    for(int i = 0; i < numberOfProcesses; ++i)
    {
        //skip blank pids
        if(0 == pids[i])
        {
            //skip
            continue;
        }
        
        //get name
        processPath = getProcessPath(pids[i]);
        if( (nil == processPath) ||
            (0 == processPath.length) )
        {
            //skip
            continue;
        }
        
        //match?
        // last path component is name
        if(YES == [processPath.lastPathComponent isEqualToString:processName])
        {
            //save
            processID = pids[i];
            
            //pau
            break;
        }
        
    }//all procs
    
bail:
    
    //free buffer
    if(NULL != pids)
    {
        //free
        free(pids);
    }
    
    return processID;
}

//hash a file
// md5/sha1/sha256
NSDictionary* hashFile(NSString* filePath)
{
    //file hashes
    NSDictionary* hashes = nil;
    
    //directory flag
    BOOL isDirectory = NO;
    
    //bundle
    NSBundle* bundle = nil;
    
    //file's contents
    NSData* fileContents = nil;
    
    //hash digest (md5)
    uint8_t digestMD5[CC_MD5_DIGEST_LENGTH] = {0};
    
    //md5 hash as string
    NSMutableString* md5 = nil;
    
    //hash digest (sha1)
    uint8_t digestSHA1[CC_SHA1_DIGEST_LENGTH] = {0};
    
    //sha1 hash as string
    NSMutableString* sha1 = nil;
    
    //hash digest (sha256)
    uint8_t digestSHA256[CC_SHA256_DIGEST_LENGTH] = {0};
    
    //sha1 hash as string
    NSMutableString* sha256 = nil;
    
    //index var
    NSUInteger index = 0;
    
    //init md5 hash string
    md5 = [NSMutableString string];
    
    //init sha1 hash string
    sha1 = [NSMutableString string];
    
    //init sha256 string
    sha256 = [NSMutableString string];
    
    //directory?
    // try see if its a bundle with an executable
    if( (YES == [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDirectory]) &&
        (YES == isDirectory) )
    {
        //load bundle
        bundle = [NSBundle bundleWithPath:filePath];
        
        //sanity check
        // bundle w/ executable path?
        if( (nil == bundle) ||
            (nil == bundle.executablePath) )
        {
            //bail
            goto bail;
        }
        
        //load file
        fileContents = [NSData dataWithContentsOfFile:bundle.executablePath];
    }
    //file
    // load directly
    else
    {
        //load
        fileContents = [NSData dataWithContentsOfFile:filePath];
    }

    //sanity check
    if(nil == fileContents)
    {
        //bail
        goto bail;
    }
    
    //md5 it
    CC_MD5(fileContents.bytes, (unsigned int)fileContents.length, digestMD5);
    
    //convert to NSString
    // ->iterate over each bytes in computed digest and format
    for(index=0; index < CC_MD5_DIGEST_LENGTH; index++)
    {
        //format/append
        [md5 appendFormat:@"%02lX", (unsigned long)digestMD5[index]];
    }
    
    //sha1 it
    CC_SHA1(fileContents.bytes, (unsigned int)fileContents.length, digestSHA1);
    
    //convert to NSString
    // ->iterate over each bytes in computed digest and format
    for(index=0; index < CC_SHA1_DIGEST_LENGTH; index++)
    {
        //format/append
        [sha1 appendFormat:@"%02lX", (unsigned long)digestSHA1[index]];
    }
    
    //sha256 it
    CC_SHA256(fileContents.bytes, (unsigned int)fileContents.length, digestSHA256);
    
    //convert to NSString
    // ->iterate over each bytes in computed digest and format
    for(index=0; index < CC_SHA256_DIGEST_LENGTH; index++)
    {
        //format/append
        [sha256 appendFormat:@"%02lX", (unsigned long)digestSHA256[index]];
    }
    
    //init hash dictionary
    hashes = @{KEY_HASH_MD5:md5, KEY_HASH_SHA1:sha1, KEY_HASH_SHA256:sha256};
    
bail:
    
    return hashes;
}

//restart Finder.app
void restartFinder()
{
    //relaunch Finder
    // ensures plugin gets loaded, etc
    execTask(KILLALL, @[@"-SIGHUP", @"Finder"]);
    
    //give it a second to restart
    [NSThread sleepForTimeInterval:1.0f];
    
    //tell Finder to activate
    // otherwise it's fully background'd when app exits for some reason!?
    //system("osascript -e \"tell application \\\"Finder\\\" to activate\"");
    
    //dbg msg
    logMsg(LOG_DEBUG, @"relaunched Finder.app");
    
    return;
}

//check if (full) dark mode
// meaning, Mojave+ and dark mode enabled
BOOL isDarkMode()
{
    //flag
    BOOL darkMode = NO;
    
    //not mojave?
    // bail, since not true dark mode
    if(YES != [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 14, 0}])
    {
        //bail
        goto bail;
    }
    
    //not dark mode?
    if(YES != [[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"] isEqualToString:@"Dark"])
    {
        //bail
        goto bail;
    }
    
    //dark mode
    darkMode = YES;
    
bail:
    
    return darkMode;
}

