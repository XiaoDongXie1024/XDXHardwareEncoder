//
//  ERPStaffInfoModel.h
//  JJKit
//
//  Created by 李承阳 on 16/10/13.
//  Copyright © 2016年 JiJi. All rights reserved.
//
#import <Foundation/Foundation.h>

@interface ERPStaffInfoModel : NSObject

@property (copy, nonatomic) NSString *name; ///< 员工名称
@property (copy, nonatomic) NSString *ID;
@property (copy, nonatomic) NSString *storeName; ///< 所属门店
@property (assign, nonatomic) NSInteger storeId;
@property (copy, nonatomic) NSString *createTime; ///< 创建时间
@property (copy, nonatomic) NSString *companyId; 
@property (copy, nonatomic) NSString *createBy;
@property (copy, nonatomic) NSString *email;
@property (copy, nonatomic) NSString *imgUrl;
@property (copy, nonatomic) NSString *isAlloperation;
@property (copy, nonatomic) NSString *isEnable;
@property (copy, nonatomic) NSString *loginDate;
@property (copy, nonatomic) NSString *loginIp;
@property (copy, nonatomic) NSString *updateBy;
@property (copy, nonatomic) NSString *updateTime;
@property (copy, nonatomic) NSString *username;
@property (copy, nonatomic) NSString *mobile;
@property (nonatomic, strong) NSArray<NSNumber *> *roleIds;

@property (nonatomic, copy) NSString *remark;

#pragma mark - 非JSON中出现的字段
@property (nonatomic, assign) BOOL isSelected;
@end
