//
//  ERPHomeItemSectionModel.h
//  CoreAnimation
//
//  Created by Yuen on 16/8/31.
//  Copyright © 2016年 Yuen. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ERPHomeItemCellModel;

@interface ERPHomeItemSectionModel : NSObject

@property (nonatomic, copy) NSString *section;
@property (nonatomic, strong) NSArray<ERPHomeItemCellModel *> *cells;

@end
