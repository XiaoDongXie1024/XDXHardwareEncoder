//
//  ERPHomeItemCell.h
//  JJERP
//
//  Created by Yuen on 16/9/30.
//  Copyright © 2016年 JiJi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ERPHomeItemCellModel.h"

@class ERPMenuAuthorityModel;
@interface ERPHomeItemCell : UITableViewCell

- (void)configWithModel:(ERPHomeItemCellModel *)model withIndexPath:(NSIndexPath *)indexPath;
- (void)configWithIsImageShow:(BOOL)isShow model:(ERPHomeItemCellModel *)model withIndexPath:(NSIndexPath *)indexPath;

- (void)configWithAuthorityModel:(ERPMenuAuthorityModel *)model indexPath:(NSIndexPath *)indexPath;

- (void)configWithLocalModel:(ERPMenuAuthorityModel *)model indexPath:(NSIndexPath *)indexPath;

@end

