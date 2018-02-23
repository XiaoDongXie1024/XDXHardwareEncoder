//
//  ERPHomeItemCell.m
//  JJERP
//
//  Created by Yuen on 16/9/30.
//  Copyright © 2016年 JiJi. All rights reserved.
//

#import "ERPHomeItemCell.h"
#import "ERPMenuAuthorityModel.h"
#import "UIImageView+WebCache.h"

@interface ERPHomeItemCell ()

@property (weak, nonatomic) IBOutlet UIImageView *itemImageView;
@property (weak, nonatomic) IBOutlet UILabel *itemTitleLabel;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textLeadingContraint;

@end

@implementation ERPHomeItemCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    
    self.layoutMargins = UIEdgeInsetsZero;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)configWithModel:(ERPHomeItemCellModel *)model withIndexPath:(NSIndexPath *)indexPath {
    [self configWithIsImageShow:YES model:model withIndexPath:indexPath];
}

- (void)configWithIsImageShow:(BOOL)isShow model:(ERPHomeItemCellModel *)model withIndexPath:(NSIndexPath *)indexPath {
    if (isShow) {
        self.itemImageView.image = [UIImage imageNamed:model.imageName];
    } else {
        self.itemImageView.hidden = YES;
        self.textLeadingContraint.constant = 16;
    }
    self.itemTitleLabel.text = model.title;

}

- (void)configWithAuthorityModel:(ERPMenuAuthorityModel *)model indexPath:(NSIndexPath *)indexPath {
//    self.itemImageView.hidden = YES;
    [self.itemImageView sd_setImageWithURL:[NSURL URLWithString:model.icon] placeholderImage:[UIImage imageNamed:@"base_placeholder"]];
//    self.textLeadingContraint.constant = 16;
    self.itemTitleLabel.text = model.name;
}

- (void)configWithLocalModel:(ERPMenuAuthorityModel *)model indexPath:(NSIndexPath *)indexPath {
    self.itemImageView.image = [UIImage imageNamed:model.icon];
    self.itemTitleLabel.text = model.name;
}

@end
