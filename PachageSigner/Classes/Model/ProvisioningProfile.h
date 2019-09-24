//
//  ProvisioningProfile.h
//  PachageSigner
//
//  Created by CC on 2019/9/16.
//  Copyright © 2019 CC. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProvisioningProfile : NSObject

@property (nonatomic,copy) NSString *filename;
@property (nonatomic,copy) NSString *name;
@property (nonatomic,copy) NSDate *created;
@property (nonatomic,copy) NSDate *expires;
@property (nonatomic,copy) NSString *appID;
@property (nonatomic,copy) NSString *teamID;
@property (nonatomic,copy) NSString *rawXML;
@property (nonatomic,copy) id entitlements;

- (instancetype)initFileName:(NSString *)fileName;

+(NSArray *)getProfiles;

@end

NS_ASSUME_NONNULL_END
