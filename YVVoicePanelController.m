//
//  YVVoicePanelController.m
//

#import "YVVoicePanelController.h"
#import "YVSilkUtil.h"

static NSString * const kYVCellID = @"YVVoiceCell";

#pragma mark - Cell

@interface YVVoiceCell : UITableViewCell
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, copy) void (^onSend)(void);
- (void)configureWithItem:(YVVoiceItem *)item;
@end

@implementation YVVoiceCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _nameLabel.textColor = [UIColor labelColor];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_nameLabel];

        _metaLabel = [[UILabel alloc] init];
        _metaLabel.font = [UIFont systemFontOfSize:12];
        _metaLabel.textColor = [UIColor secondaryLabelColor];
        _metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_metaLabel];

        _sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_sendButton setTitle:@"发送" forState:UIControlStateNormal];
        _sendButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        _sendButton.backgroundColor = [UIColor systemBlueColor];
        [_sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _sendButton.layer.cornerRadius = 14;
        _sendButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_sendButton addTarget:self action:@selector(sendTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_sendButton];

        [NSLayoutConstraint activateConstraints:@[
            [_nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_nameLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
            [_nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_sendButton.leadingAnchor constant:-8],

            [_metaLabel.leadingAnchor constraintEqualToAnchor:_nameLabel.leadingAnchor],
            [_metaLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:2],
            [_metaLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_sendButton.leadingAnchor constant:-8],

            [_sendButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_sendButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_sendButton.widthAnchor constraintEqualToConstant:64],
            [_sendButton.heightAnchor constraintEqualToConstant:28],

            [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:60],
        ]];
    }
    return self;
}

- (void)configureWithItem:(YVVoiceItem *)item {
    self.nameLabel.text = item.name;
    self.metaLabel.text = [NSString stringWithFormat:@"%@ · %@",
                           item.displayTime,
                           [NSByteCountFormatter stringFromByteCount:(long long)item.fileSize
                                                          countStyle:NSByteCountFormatterCountStyleFile]];
}

- (void)sendTapped { if (self.onSend) self.onSend(); }

@end


#pragma mark - Panel

@interface YVVoicePanelController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<YVVoiceItem *> *items;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIButton *refreshButton;
@end

@implementation YVVoicePanelController

+ (void)presentFromViewController:(UIViewController *)vc {
    if (!vc) return;

    YVVoicePanelController *panel = [YVVoicePanelController new];
    panel.target = [YVVoiceSender targetFromViewController:vc];
    panel.modalPresentationStyle = UIModalPresentationPageSheet;

    if (@available(iOS 15.0, *)) {
        if (panel.sheetPresentationController) {
            panel.sheetPresentationController.detents = @[
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent]
            ];
            panel.sheetPresentationController.prefersGrabberVisible = YES;
        }
    }

    [vc presentViewController:panel animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"语音包";

    // 关闭按钮
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                      target:self
                                                      action:@selector(closeTapped)];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                      target:self
                                                      action:@selector(reloadTapped)];

    // 包一层导航控制器，方便显示标题
    // （present 时外面已经包了，这里用自定义顶栏）
    [self buildHeader];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;
    self.tableView.tableFooterView = [UIView new];
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.tableView registerClass:[YVVoiceCell class] forCellReuseIdentifier:kYVCellID];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:52],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.text = [NSString stringWithFormat:
        @"暂无语音文件\n\n请把 .silk 文件放入：\n%@", [YVSilkUtil voiceDirPath]];
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:13];
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.emptyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.emptyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
    ]];

    [self reloadData];
}

- (void)buildHeader {
    UIView *bar = [[UIView alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:bar];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = @"语音包";
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [bar addSubview:titleLabel];

    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.text = self.target.title.length ? self.target.title : @"当前会话";
    subLabel.font = [UIFont systemFontOfSize:12];
    subLabel.textColor = [UIColor secondaryLabelColor];
    subLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [bar addSubview:subLabel];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeBtn setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    closeBtn.tintColor = [UIColor tertiaryLabelColor];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [closeBtn addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:closeBtn];

    UIButton *refreshBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [refreshBtn setImage:[UIImage systemImageNamed:@"arrow.clockwise"] forState:UIControlStateNormal];
    refreshBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [refreshBtn addTarget:self action:@selector(reloadTapped) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:refreshBtn];

    [NSLayoutConstraint activateConstraints:@[
        [bar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [bar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [bar.heightAnchor constraintEqualToConstant:52],

        [titleLabel.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:16],
        [titleLabel.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor constant:-7],

        [subLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subLabel.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor constant:9],

        [closeBtn.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-16],
        [closeBtn.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [closeBtn.widthAnchor constraintEqualToConstant:28],
        [closeBtn.heightAnchor constraintEqualToConstant:28],

        [refreshBtn.trailingAnchor constraintEqualToAnchor:closeBtn.leadingAnchor constant:-14],
        [refreshBtn.centerYAnchor constraintEqualToAnchor:bar.centerYAnchor],
        [refreshBtn.widthAnchor constraintEqualToConstant:28],
        [refreshBtn.heightAnchor constraintEqualToConstant:28],
    ]];
}

- (void)reloadData {
    self.items = [YVSilkUtil scanVoiceFiles];
    self.emptyLabel.hidden = (self.items.count > 0);
    [self.tableView reloadData];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)reloadTapped {
    [self reloadData];
}

#pragma mark - UITableView

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    YVVoiceCell *cell = [tableView dequeueReusableCellWithIdentifier:kYVCellID forIndexPath:indexPath];
    YVVoiceItem *item = self.items[indexPath.row];
    [cell configureWithItem:item];

    __weak typeof(self) weakSelf = self;
    cell.onSend = ^{
        [weakSelf sendItem:item];
    };
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - 发送

- (void)sendItem:(YVVoiceItem *)item {
    if (!self.target.peerUid && !self.target.peerUin) {
        [self toast:@"未获取到当前会话，请先进入具体聊天"];
        return;
    }

    [self toast:[NSString stringWithFormat:@"正在发送 %@ ...", item.name]];

    __weak typeof(self) weakSelf = self;
    [YVVoiceSender sendVoiceItem:item target:self.target completion:^(BOOL ok, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf toast:ok ? [NSString stringWithFormat:@"✅ %@", msg]
                              : [NSString stringWithFormat:@"❌ %@", msg]];
        });
    }];
}

- (void)toast:(NSString *)text {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil
                                                               message:text
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:ac animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [ac dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

@end