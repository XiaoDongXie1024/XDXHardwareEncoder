//
//  ERPSettingController.m
//  JJERP
//
//  Created by 李承阳 on 16/10/11.
//  Copyright © 2016年 JiJi. All rights reserved.
//

#import "ERPSettingController.h"
#import "ERPLoginController.h"
#import "ERPStaffListController.h"

#import "ERPHomeItemSectionModel.h"
#import "ERPHomeItemCellModel.h"

#import "ERPHomeItemCell.h"
#import "JJAlertView.h"

#import "ERPUserManager.h"

#import "JJAPIList.h"

static NSString *const kReuseCellID = @"ERPHomeItemCell";
static CGFloat const kCellHeight = 41;
@interface ERPSettingController ()<UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSArray<ERPHomeItemSectionModel *> *dataSourceArray;

@property (weak, nonatomic) IBOutlet UITableView *tableView;



@end

@implementation ERPSettingController
#pragma mark - Init

#pragma mark - LifeCycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self configureData];
    [self configureViews];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

#pragma mark - Setter / Getter

#pragma mark- GetDataAndRefreshView
- (void)configureData {
    self.dataSourceArray = [NSArray yy_modelArrayWithClass:ERPHomeItemSectionModel.class json:[[NSArray alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:NSStringFromClass(self.class) ofType:@"plist"]]];
}

#pragma mark - Setup

- (void)configureViews {
    self.navigationItem.title = @"设置";
    
    [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([ERPHomeItemCell class]) bundle:nil] forCellReuseIdentifier:kReuseCellID];
    self.tableView.separatorInset = UIEdgeInsetsZero;
    self.tableView.rowHeight = kCellHeight;
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, CGFLOAT_MIN)];
    // 处理cell间距,默认tableView分组样式,有额外头部和尾部间距
    self.tableView.sectionHeaderHeight = 0;
    self.tableView.sectionFooterHeight = 12;
}
#pragma mark - Action

#pragma mark - Layout

#pragma mark - Other

#pragma mark - Notification

#pragma mark - Delegate Methods
#pragma mark UITableView
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataSourceArray.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
//#if RELEASE
//    if (section == 3) {
//        return self.dataSourceArray[section].cells.count - 1;
//    }
//#endif
    return self.dataSourceArray[section].cells.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ERPHomeItemCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kReuseCellID forIndexPath:indexPath];
    ERPHomeItemCellModel *model = self.dataSourceArray[indexPath.section].cells[indexPath.row];
    [cell configWithIsImageShow:NO model:model withIndexPath:indexPath];
    if (indexPath.section == 1) {
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.textLabel.textColor = RGB(30, 130, 210);
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        if (indexPath.row == 0) {
            cell.textLabel.text = @"退出当前账号";
        }
//        else {
//            cell.textLabel.text = @"删除个人信息数据库，重新登录";
//        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    WEAK_SELF;
    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0: {
                [self.navigationController pushViewController:[[ERPStaffListController alloc] init] animated:YES];
                break;
            }
            case 1: {
                break;
            }
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            [self showLoading];
            [JJNetService logoutWithSuccess:^(id objModel) {
                STRONG_SELF;
                [self hideHUD];
                [[ERPUserManager sharedManager] deleteUserInfo];
                [JJAlertView showDialogueWithTitle:@""
                                           message:@"您已退出登录"
                                      buttonTitles:@[@"去登录"]
                                      confirmBlock:^{
                                          [UIApplication sharedApplication].keyWindow.rootViewController = [[UINavigationController alloc] initWithRootViewController:[[ERPLoginController alloc] init]];
                                      }];
            } failure:^(NSError *error) {
                STRONG_SELF;
                [self hideHUD];
                [self showHUDWithTitle:error.domain];
            }];
        } else {
            [[ERPUserManager sharedManager] deleteUserInfo];
            [UIApplication sharedApplication].keyWindow.rootViewController = [[UINavigationController alloc] initWithRootViewController:[[ERPLoginController alloc] init]];
        }
    }
}


@end
