//
//  ERPStaffManageTableViewCell.h
//  JJERP
//
//  Created by 李承阳 on 16/10/12.
//  Copyright © 2016年 JiJi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ERPStaffInfoModel.h"
#import "SWTableViewCell.h"

@interface ERPStaffManageTableViewCell : SWTableViewCell
/**
 *  配置员工信息
 *  @param model     员工模型
 */
- (void)configureWithModel:(ERPStaffInfoModel *)model withIndexPath:(NSIndexPath *)indexPath;

@end
