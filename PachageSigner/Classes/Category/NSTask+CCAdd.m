//
//  NSTask+CCAdd.m
//  PachageSigner
//
//  Created by CC on 2019/9/16.
//  Copyright © 2019 CC. All rights reserved.
//


#import "NSTask+CCAdd.h"

@implementation NSTask (CCAdd)

- (AppSignerEntity *)launchSyncronous
{
    self.standardInput = NSFileHandle.fileHandleWithNullDevice;
    NSPipe *pipe = [NSPipe new];
    self.standardOutput = pipe;
    self.standardError = pipe;
    NSFileHandle *pipeFile = pipe.fileHandleForReading;
    [self launch];

    NSMutableData *data = [NSMutableData new];
    while (self.isRunning)
        [data appendData:pipeFile.availableData];

    [pipeFile closeFile];
    [self terminate];

    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (output) {
        return [AppSignerEntity initWithOutPut:output status:self.terminationStatus];
    }
    return [AppSignerEntity initWithOutPut:@"" status:self.terminationStatus];
}

- (AppSignerEntity *)execute:(NSString *)launchPath
            workingDirectory:(NSString *)workingDirectory
                   arguments:(NSArray<NSString *> *)arguments
{
    self.launchPath = launchPath;
    if (arguments)
        self.arguments = arguments;

    if (workingDirectory)
        self.currentDirectoryPath = workingDirectory;
    return [self launchSyncronous];
}

@end
