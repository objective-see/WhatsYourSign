//
//  Utilities.m
//  WhatsYourSign
//
//  Created by Patrick Wardle on 7/7/16.
//  Copyright (c) 2016 Objective-See. All rights reserved.
//

#import "consts.h"
#import "utilities.h"

#import <signal.h>
#import <unistd.h>
#import <libproc.h>
#import <sys/sysctl.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <SystemConfiguration/SystemConfiguration.h>

@import Foundation;

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
    //logMsg(LOG_DEBUG, [NSString stringWithFormat:@"execing task, %@ (arguments: %@)", task.launchPath, task.arguments]);
    
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
    
    //handle
    NSFileHandle* handle = nil;
    
    //path
    // might be app's binary
    NSString* path = nil;
    
    //offset
    NSUInteger offset = 0;
    
    //file's contents
    // per chunk (to handle big files)
    NSData* chunk = nil;
    
    //md5 context
    CC_MD5_CTX md5Context = {0};
    
    //hash digest (md5)
    uint8_t md5Digest[CC_MD5_DIGEST_LENGTH] = {0};
    
    //md5 hash as string
    NSMutableString* md5 = nil;
    
    //sha1 context
    CC_SHA1_CTX sha1Context = {0};
    
    //hash digest (sha1)
    uint8_t sha1Digest[CC_SHA1_DIGEST_LENGTH] = {0};
    
    //sha1 hash as string
    NSMutableString* sha1 = nil;
    
    //sha256 context
    CC_SHA256_CTX sha256Context = {0};
    
    //hash digest (sha256)
    uint8_t sha256Digest[CC_SHA256_DIGEST_LENGTH] = {0};
    
    //sha256 hash as string
    NSMutableString* sha256 = nil;
    
    //sha512 context
    CC_SHA512_CTX sha512Context = {0};
    
    //hash digest (sha512)
    uint8_t sha512Digest[CC_SHA512_DIGEST_LENGTH] = {0};
    
    //sha512 hash as string
    NSMutableString* sha512 = nil;
    
    //index var
    NSUInteger index = 0;
    
    //init md5 hash string
    md5 = [NSMutableString string];
    
    //init sha1 hash string
    sha1 = [NSMutableString string];
    
    //init sha256 string
    sha256 = [NSMutableString string];
    
    //init sha512 string
    sha512 = [NSMutableString string];
    
    //init path
    // might be updated if app bundle
    path = filePath;
    
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
        
        //update path
        path = bundle.executablePath;
    }
    
    //open handle to file
    handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if(nil == handle) goto bail;
    
    //init hash contexts
    CC_MD5_Init(&md5Context);
    CC_SHA1_Init(&sha1Context);
    CC_SHA256_Init(&sha256Context);
    CC_SHA512_Init(&sha512Context);
                 
    //read/hash file
    // in chunks, to handle large files
    while(YES)
    {
        //wrap
        // 'readDataOfLength' can throw
        @try
        {
            //read in chunk
            chunk = [handle readDataOfLength:1024*1024];
            if(chunk.length == 0) break;
        }
        @catch(NSException* exception)
        {
            //bail
            goto bail;
        }
        
        //hash updates
        CC_MD5_Update(&md5Context, (const void *)chunk.bytes, (CC_LONG)chunk.length);
        CC_SHA1_Update(&sha1Context, (const void *)chunk.bytes, (CC_LONG)chunk.length);
        CC_SHA256_Update(&sha256Context, (const void *)chunk.bytes, (CC_LONG)chunk.length);
        CC_SHA512_Update(&sha512Context, (const void *)chunk.bytes, (CC_LONG)chunk.length);
        
        //inc
        offset += chunk.length;

        //advance handle
        [handle seekToFileOffset:offset];
    }
    
    //finalize hashes
    CC_MD5_Final(md5Digest, &md5Context);
    CC_SHA1_Final(sha1Digest, &sha1Context);
    CC_SHA256_Final(sha256Digest, &sha256Context);
    CC_SHA512_Final(sha512Digest, &sha512Context);
    
    //convert md5 to NSString
    for(index=0; index < CC_MD5_DIGEST_LENGTH; index++)
    {
        //format/append
        [md5 appendFormat:@"%02lX", (unsigned long)md5Digest[index]];
    }
    
    //convert sha1 to NSString
    for(index=0; index < CC_SHA1_DIGEST_LENGTH; index++)
    {
        //format/append
        [sha1 appendFormat:@"%02lX", (unsigned long)sha1Digest[index]];
    }
    
    //convert sha256 to NSString
    for(index=0; index < CC_SHA256_DIGEST_LENGTH; index++)
    {
        //format/append
        [sha256 appendFormat:@"%02lX", (unsigned long)sha256Digest[index]];
    }
    
    //convert sha256 to NSString
    for(index=0; index < CC_SHA512_DIGEST_LENGTH; index++)
    {
        //format/append
        [sha512 appendFormat:@"%02lX", (unsigned long)sha512Digest[index]];
    }
    
    //init hash dictionary
    hashes = @{KEY_HASH_MD5:md5, KEY_HASH_SHA1:sha1, KEY_HASH_SHA256:sha256, KEY_HASH_SHA512:sha512};
    
bail:

    //close handle?
    if(nil != handle)
    {
        //close
        [handle closeFile];
        handle = nil;
    }
    
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
    //logMsg(LOG_DEBUG, @"relaunched Finder.app");
    
    return;
}

//check if (full) dark mode
// meaning, Mojave+ and dark mode enabled
BOOL isDarkMode()
{
    //flag
    BOOL darkMode = NO;
    
    //appearance
    NSAppearanceName appearanceName = nil;
    
    //10.14+ introduced dark mode
    // check via effective appearance
    if(@available(macOS 10.14, *))
    {
        //get appearance name
        appearanceName = [NSApplication.sharedApplication.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
        
        //set
        darkMode = [appearanceName isEqualToString:NSAppearanceNameDarkAqua];
    }
    
    return darkMode;
}
