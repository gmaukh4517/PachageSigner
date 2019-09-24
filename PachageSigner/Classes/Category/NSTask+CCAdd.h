//
//  NSTask+CCAdd.h
//  PachageSigner
//
//  Created by CC on 2019/9/16.
//  Copyright © 2019 CC. All rights reserved.
//

#import "AppSignerEntity.h"
#import <Foundation/Foundation.h>

@interface NSTask (CCAdd)

- (AppSignerEntity *)execute:(NSString *)launchPath
            workingDirectory:(NSString *)workingDirectory
                   arguments:(NSArray<NSString *> *)arguments;

@end
