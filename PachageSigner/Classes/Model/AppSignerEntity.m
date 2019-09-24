//
//  AppSignerEntity.m
//  PachageSigner
//
//  Created by CC on 2019/9/16.
//  Copyright © 2019 CC. All rights reserved.
//

#import "AppSignerEntity.h"

@implementation AppSignerEntity

+ (instancetype)initWithOutPut:(NSString *)output status:(NSInteger)status
{
    AppSignerEntity *entity = [AppSignerEntity new];
    entity.output = output;
    entity.status = status;
    return entity;
}

@end
