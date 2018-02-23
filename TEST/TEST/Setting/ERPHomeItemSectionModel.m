//
//  ERPHomeItemSectionModel.m
//  CoreAnimation
//
//  Created by Yuen on 16/8/31.
//  Copyright © 2016年 Yuen. All rights reserved.
//

#import "ERPHomeItemSectionModel.h"
#import "ERPHomeItemCellModel.h"

@implementation ERPHomeItemSectionModel

+ (NSDictionary *)modelContainerPropertyGenericClass {
    return @{
             @"cells" : [ERPHomeItemCellModel class],
             };
}

@end
