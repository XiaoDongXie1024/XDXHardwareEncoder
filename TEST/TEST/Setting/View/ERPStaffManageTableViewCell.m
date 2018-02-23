//
//  ERPStaffManageTableViewCell.m
//  JJERP
//
//  Created by 李承阳 on 16/10/12.
//  Copyright © 2016年 JiJi. All rights reserved.
//

#import "ERPStaffManageTableViewCell.h"
#import "NSString+DisplayTime.h"
#import "NSMutableArray+SWUtilityButtons.h"

@interface ERPStaffManageTableViewCell ()

@property (weak, nonatomic) IBOutlet UILabel *staffName;
@property (weak, nonatomic) IBOutlet UILabel *classifyName;
@property (weak, nonatomic) IBOutlet UILabel *storeOwner;
@property (weak, nonatomic) IBOutlet UILabel *createTime;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

@end

@implementation ERPStaffManageTableViewCell

- (void)awakeFromNib {
    // Initialization code
    [super awakeFromNib];
    self.layoutMargins = UIEdgeInsetsZero;
    self.selectionStyle =UITableViewCellSelectionStyleNone;
    [self setRightUtilityButtons:[self rightButtons] WithButtonWidth:50];
}

- (void)configureWithModel:(ERPStaffInfoModel *)model withIndexPath:(NSIndexPath *)indexPath {
    self.staffName.text = model.name;
    self.storeOwner.text = model.storeName;
    self.createTime.text = [NSString getStringWithTimestamp:model.createTime.integerValue formatter:@"yyyy-MM-dd HH:mm"];
    self.statusLabel.hidden = [model.isEnable isEqualToString:@"1"];
}

#pragma mark SWTableViewCell的按钮
- (NSArray *)rightButtons
{
    NSMutableArray *rightUtilityButtons = [NSMutableArray new];
    [rightUtilityButtons sw_addUtilityButtonWithColor:RGB(30, 130, 210)
                                                 icon:[UIImage imageNamed:@"store_staff_profile_message"]];
    [rightUtilityButtons sw_addUtilityButtonWithColor:RGB(253, 198, 67)
                                                 icon:[UIImage imageNamed:@"store_staff_profile_phone"]];
    return rightUtilityButtons;
}

@end
