//
//  ProvisioningProfile.m
//  PachageSigner
//
//  Created by CC on 2019/9/16.
//  Copyright © 2019 CC. All rights reserved.
//

#import "ProvisioningProfile.h"
#import "NSTask+CCAdd.h"

@implementation ProvisioningProfile

- (instancetype)initFileName:(NSString *)fileName
{
    if (self = [super init]) {
        self.filename = fileName;
        [self initData];
    }
    return self;
}

- (void)initData
{
    NSArray *securityArgs = @[ @"cms", @"-D", @"-i", self.filename ];
    AppSignerEntity *taskOutput = [[NSTask new] execute:@"/usr/bin/security" workingDirectory:nil arguments:securityArgs];
    if (taskOutput.status == 0) {
        NSRange xmlIndex = [taskOutput.output rangeOfString:@"<?xml"];
        if (xmlIndex.location != NSNotFound) {
            self.rawXML = [taskOutput.output substringFromIndex:xmlIndex.location];
        } else {
            self.rawXML = taskOutput.output;
        }

        NSDictionary *results = [NSPropertyListSerialization propertyListWithData:[self.rawXML dataUsingEncoding:NSUTF8StringEncoding] options:NSPropertyListImmutable format:nil error:nil];
        if (results) {
            NSDictionary *entitlements = [results objectForKey:@"Entitlements"];
            NSString *applicationIdentifier = [entitlements objectForKey:@"application-identifier"];
            NSInteger periodIndex = [applicationIdentifier rangeOfString:@"."].location;
            self.expires = [results objectForKey:@"ExpirationDate"];
            self.created = [results objectForKey:@"CreationDate"];
            self.appID = [applicationIdentifier substringWithRange:NSMakeRange(periodIndex + 1, applicationIdentifier.length - periodIndex - 1)];
            self.teamID = [applicationIdentifier substringToIndex:periodIndex];
            self.name = [results objectForKey:@"Name"];
            self.entitlements = entitlements;
        }
    } else {
        NSLog(@"Error parsing");
        return;
    }
}

+ (NSArray *)getProfiles
{
    NSMutableArray *outputArray = [NSMutableArray array];
    NSFileManager *fileNanager = [NSFileManager defaultManager];
    NSURL *libraryDirectory = [fileNanager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask].firstObject;

    NSString *provisioningProfilesPath = [libraryDirectory.path stringByAppendingPathComponent:@"MobileDevice/Provisioning Profiles"];

    NSArray *provisioningProfiles = [fileNanager contentsOfDirectoryAtPath:provisioningProfilesPath error:nil];

    for (NSString *provFile in provisioningProfiles) {
        if ([provFile.pathExtension isEqualToString:@"mobileprovision"]) {
            NSString *profileFilename = [provisioningProfilesPath stringByAppendingPathComponent:provFile];
            [outputArray addObject:[[ProvisioningProfile alloc] initFileName:profileFilename]];
        }
    }

    outputArray = [outputArray sortedArrayUsingComparator:^NSComparisonResult(ProvisioningProfile *_Nonnull obj1, ProvisioningProfile *_Nonnull obj2) {
        return obj1.created.timeIntervalSince1970 > obj2.created.timeIntervalSince1970;
    }]
    .mutableCopy;

    NSMutableArray *newProfiles = [NSMutableArray array];
    NSMutableArray *nameArray = [NSMutableArray array];
    for (ProvisioningProfile *profile in outputArray) {
        NSString *name = [NSString stringWithFormat:@"%@%@", profile.name, profile.appID];
        if (![nameArray containsObject:name]) {
            [newProfiles addObject:profile];
            [nameArray addObject:name];
        }
    }
    return newProfiles;
}

@end
