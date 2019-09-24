//
//  AppSignerEntity.h
//  PachageSigner
//
//  Created by CC on 2019/9/16.
//  Copyright © 2019 CC. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppSignerEntity : NSObject

@property (nonatomic, copy) NSString *output;
@property (nonatomic, assign) NSInteger status;

+ (instancetype)initWithOutPut:(NSString *)output status:(NSInteger)status;

@end

NS_ASSUME_NONNULL_END
