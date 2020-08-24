//
//  HomeViewController.m
//  PachageSigner
//
//  Created by CC on 2019/9/16.
//  Copyright © 2019 CC. All rights reserved.
//

#import "HomeViewController.h"
#import "NSTask+CCAdd.h"
#import "ProvisioningProfile.h"
#import <Foundation/Foundation.h>

NSString *const kSECURITYPATH = @"/usr/bin/security";

@interface HomeViewController ()

@property (weak) IBOutlet NSTextField *inputFileTextField;

@property (weak) IBOutlet NSPopUpButton *signingCretificatePopup;

@property (weak) IBOutlet NSPopUpButton *provisioningProfilePopup;

@property (weak) IBOutlet NSPopUpButton *distributionMethodPopup;

@property (weak) IBOutlet NSPopUpButton *buildMethodPopup;

@property (weak) IBOutlet NSPopUpButton *publishMethodPopup;

@property (weak) IBOutlet NSTextField *bundleIdentifierTextField;

@property (weak) IBOutlet NSTextField *displayNameTextField;

@property (weak) IBOutlet NSTextField *appVersionTextField;

@property (weak) IBOutlet NSTextField *appBuildVersionTextField;

@property (weak) IBOutlet NSTextField *appChannelTextField;

@property (weak) IBOutlet NSTextField *appSavePathTextField;

@property (unsafe_unretained) IBOutlet NSTextView *messageTextView;

@property (nonatomic, strong) NSArray *provisioningProfiles;

@property (nonatomic, copy) NSString *profileFilename;

@property (nonatomic, copy) NSString *profileTeamID;

@property (nonatomic, copy) NSString *saveIPAName;

/// 苹果开发者账号
@property (nonatomic, copy) NSString *appstoreAccount;
/// 苹果开发者账号
@property (nonatomic, copy) NSString *appstorePassword;

/// 蒲公英UserKey
@property (nonatomic, copy) NSString *pgyerUserKey;
/// 蒲公英ApiKey
@property (nonatomic, copy) NSString *pgyerApiKey;

/// FIRtoken
@property (nonatomic, copy) NSString *firToken;

//选择的配置文件是 “*‘ 并且 plist bundleIdentifier = $(PRODUCT_BUNDLE_IDENTIFIER) 的时候使用
@property (nonatomic, copy) NSString *projectBundleIdentifier;
// 备份project.pbxproj 路径
@property (nonatomic, copy) NSString *projectPbxprojCopyPath;
// 备份plist 路径
@property (nonatomic, copy) NSString *plistCopyPath;
// 备份export plist 路径
@property (nonatomic, copy) NSString *exportPlistCopyPath;
// 备份archive 路径
@property (nonatomic, copy) NSString *archiveCopyPath;
@property (strong) IBOutlet NSPanel *pa;

@end

@implementation HomeViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
    [self initLoadData];
}

- (void)initLoadData
{
    [self.inputFileTextField setAllowsEditingTextAttributes:YES];
    [self populateCodesigningCerts];
    [self populateProvisioningProfiles];
    [self populateMethod];
    
    if (![self checkXcodeCLI]) {
        if (@available(macOS 10.10, *)) {
            [self installXcodeCLI];
        } else {
            NSAlert *alert = [NSAlert new];
            alert.messageText = @"Please install the Xcode command line tools and re-launch this application.";
            [alert runModal];
        }
    }
}

// 获取证书
- (void)populateCodesigningCerts
{
    [self.signingCretificatePopup removeAllItems];
    NSMutableArray *codesigningCerts = [NSMutableArray array];
    AppSignerEntity *securityResult = [[NSTask new] execute:kSECURITYPATH workingDirectory:nil arguments:@[ @"find-identity", @"-v", @"-p", @"codesigning" ]];
    if (securityResult.output.length >= 1) {
        NSArray *rawResult = [securityResult.output componentsSeparatedByString:@"\""];
        for (NSInteger i = 0; i < rawResult.count; i++) {
            if (i % 2)
                [codesigningCerts addObject:[rawResult objectAtIndex:i]];
        }
        [self.signingCretificatePopup addItemsWithTitles:codesigningCerts];
        
        NSString *defaultCert = [[NSUserDefaults standardUserDefaults] objectForKey:@"signingCertificate"];
        if ([codesigningCerts containsObject:defaultCert])
            [self.signingCretificatePopup selectItemWithTitle:defaultCert];
    } else {
        [self showCodesignCertsErrorAlert];
    }
}

- (void)populateProvisioningProfiles
{
    self.provisioningProfiles = [ProvisioningProfile.getProfiles sortedArrayUsingComparator:^NSComparisonResult(ProvisioningProfile *_Nonnull obj1, ProvisioningProfile *_Nonnull obj2) {
        return (obj1.name == obj2.name && obj1.created.timeIntervalSince1970 > obj2.created.timeIntervalSince1970) || obj1.name < obj2.name;
    }];
    [self.provisioningProfilePopup removeAllItems];
    [self.provisioningProfilePopup addItemsWithTitles:@[ @"Re-Sign Only", @"Choose Custom File", @"––––––––––––––––––––––" ]];
    
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterMediumStyle;
    
    NSMutableArray *newProfiles = [NSMutableArray array];
    
    for (ProvisioningProfile *profile in self.provisioningProfiles) {
        if (profile.expires.timeIntervalSince1970 > [NSDate date].timeIntervalSince1970) {
            [newProfiles addObject:profile];
            
            [self.provisioningProfilePopup addItemWithTitle:[NSString stringWithFormat:@"%@ (%@) ", profile.name, profile.teamID]];
            
            NSArray *toolTipItems = @[ profile.name,
                                       @"",
                                       [NSString stringWithFormat:@"Team ID: %@", profile.teamID],
                                       [NSString stringWithFormat:@"Created: %@", [formatter stringFromDate:profile.created]],
                                       [NSString stringWithFormat:@"Expires: %@", [formatter stringFromDate:profile.expires]] ];
            self.provisioningProfilePopup.lastItem.toolTip = [toolTipItems componentsJoinedByString:@"\n"];
        }
    }
    self.provisioningProfiles = newProfiles;
}

// 初始化 打包方式、构建模式、发布方式
- (void)populateMethod
{
    [self.distributionMethodPopup removeAllItems];
    [self.distributionMethodPopup addItemsWithTitles:@[ @"ad-hoc", @"app-store", @"enterprise", @"development" ]];
    
    [self.buildMethodPopup removeAllItems];
    [self.buildMethodPopup addItemsWithTitles:@[ @"Release", @"Debug" ]];
    
    [self.publishMethodPopup removeAllItems];
    [self.publishMethodPopup addItemsWithTitles:@[ @"Re-Bale Only", @"App Store", @"蒲公英", @"FIR", @"内部" ]];
}

#pragma mark -
#pragma mark :. handler event

- (AppSignerEntity *)installXcodeCLI
{
    return [[NSTask new] execute:@"/usr/bin/xcode-select" workingDirectory:nil arguments:@[ @"--install" ]];
}

- (BOOL)checkXcodeCLI
{
    if (@available(macOS 10.10, *)) {
        if ([[NSTask new] execute:@"/usr/bin/xcode-select" workingDirectory:nil arguments:@[ @"-p" ]].status != 0)
            return NO;
    } else {
        if ([[NSTask new] execute:@"/usr/sbin/pkgutil" workingDirectory:nil arguments:@[ @"--pkg-info=com.apple.pkg.DeveloperToolsCLI" ]].status != 0)
            return NO;
    }
    
    return YES;
}

- (void)showCodesignCertsErrorAlert
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"No codesigning certificates found";
    alert.informativeText = @"I can attempt to fix this automatically, would you like me to try?";
    [alert addButtonWithTitle:@"YES"];
    [alert addButtonWithTitle:@"NO"];
    [alert runModal];
}

- (void)checkProfileID:(ProvisioningProfile *)profile
{
    if (profile) {
        self.profileFilename = profile.name;
        self.profileTeamID = profile.teamID;
        if (profile.expires.timeIntervalSince1970 < [NSDate date].timeIntervalSince1970) {
            [self.provisioningProfilePopup selectItemAtIndex:0];
            [self chooseProvisioningProfile:self.provisioningProfilePopup];
        }
        
        if ([profile.appID rangeOfString:@"*"].location == NSNotFound) {
            self.bundleIdentifierTextField.stringValue = profile.appID;
            self.bundleIdentifierTextField.enabled = NO;
        } else {
            if (!self.bundleIdentifierTextField.isEnabled) {
                self.bundleIdentifierTextField.stringValue = @"";
                self.bundleIdentifierTextField.enabled = YES;
            }
        }
    } else {
        [self.provisioningProfilePopup selectItemAtIndex:0];
        [self chooseProvisioningProfile:self.provisioningProfilePopup];
    }
}

- (IBAction)browseButtonClick:(NSButton *)sender
{
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    openPanel.canChooseFiles = YES;
    openPanel.canChooseDirectories = NO;
    openPanel.allowsMultipleSelection = NO;
    openPanel.allowsOtherFileTypes = NO;
    openPanel.allowedFileTypes = @[ @"ipa", @"deb", @"app", @"appex", @"xcarchive" ];
    
    [openPanel beginSheetModalForWindow:self.view.window
                      completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSModalResponseOK) {
            self.inputFileTextField.stringValue = openPanel.URLs.firstObject.path;
        }
    }];
}

- (IBAction)chooseSigningCertificate:(NSPopUpButton *)sender
{
    [[NSUserDefaults standardUserDefaults] setValue:sender.selectedItem.title forKey:@"signingCertificate"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)chooseProvisioningProfile:(NSPopUpButton *)sender
{
    switch (sender.indexOfSelectedItem) {
        case 0:
            self.profileFilename = nil;
            if (!self.bundleIdentifierTextField.isEnabled) {
                self.bundleIdentifierTextField.enabled = YES;
                self.bundleIdentifierTextField.stringValue = @"";
            }
            break;
        case 1: {
            NSOpenPanel *openDialog = [NSOpenPanel new];
            openDialog.canChooseFiles = YES;
            openDialog.canChooseDirectories = NO;
            openDialog.allowsMultipleSelection = NO;
            openDialog.allowsOtherFileTypes = NO;
            openDialog.allowedFileTypes = @[ @"mobileprovision" ];
            [openDialog runModal];
            
            if (openDialog.URLs.firstObject) {
                [self checkProfileID:[[ProvisioningProfile alloc] initFileName:[openDialog.URLs.firstObject path]]];
            } else {
                [sender selectItemAtIndex:0];
                [self chooseProvisioningProfile:sender];
            }
            
            break;
        }
        case 2: {
            [sender selectItemAtIndex:0];
            [self chooseProvisioningProfile:sender];
            break;
        }
        default: {
            [self checkProfileID:[self.provisioningProfiles objectAtIndex:sender.indexOfSelectedItem - 3]];
            break;
        }
    }
}

- (IBAction)choosePublishMethod:(NSPopUpButton *)sender
{
    if (![sender.title isEqualToString:@"Re-Bale Only"]) {
        [self pupupPublishMethod];
    }
}

/// 启动打包事件
/// @param sender 按钮对象
- (IBAction)startButtonClick:(NSButton *)sender
{
    [self handlerMessage:@""];
    [self handlerMessage:@"开始打包..."];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYY-MM-dd_HH-mm-ss"];
    NSString *fileName = [NSString stringWithFormat:@"%@%@", [self.inputFileTextField.stringValue componentsSeparatedByString:@"/"].lastObject, [formatter stringFromDate:[NSDate date]]];
    self.appSavePathTextField.stringValue = [NSString stringWithFormat:@"%@%@", [[NSFileManager defaultManager] URLsForDirectory:NSDesktopDirectory inDomains:NSUserDomainMask].firstObject, fileName];
    self.appSavePathTextField.stringValue = [self.appSavePathTextField.stringValue stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    if ([self projectPlistConstructHandler] && [self projectExportPlistConstructHandler] && [self projectArchiveConstructHandler]) {
        [self handlerMessage:@"正在打包，请稍等片刻..."];
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSString *packScriptPath = [[NSBundle mainBundle] pathForResource:@"archive" ofType:@"sh"];
            NSError *error = nil;
            NSString *commandString = [NSString stringWithContentsOfFile:packScriptPath encoding:NSUTF8StringEncoding error:&error];
            system([commandString UTF8String]);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self handlerMessage:@"打包完成"];
                [self clearConstructConfig];
                system([[@"open " stringByAppendingString:self.appSavePathTextField.stringValue] UTF8String]);
            });
        });
    } else {
        [self handlerMessage:@"打包失败..."];
        [self clearConstructConfig];
    }
}

#pragma mark -
#pragma mark :. handler publish method

- (void)pupupPublishMethod
{
    NSPanel *panel = [[NSPanel alloc] initWithContentRect:CGRectMake(0, 0, 420, 150) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
    
    NSTextField *titleTextField = [[NSTextField alloc] initWithFrame:CGRectMake(0, panel.frame.size.height - 55, panel.frame.size.width, 20)];
    titleTextField.font = [NSFont systemFontOfSize:15];
    [titleTextField setEnabled:NO];
    [titleTextField setBordered:NO];
    titleTextField.backgroundColor = [NSColor clearColor];
    titleTextField.textColor = [NSColor whiteColor];
    titleTextField.alignment = NSTextAlignmentCenter;
    titleTextField.stringValue = self.publishMethodPopup.selectedItem.title;
    [panel.contentView addSubview:titleTextField];
    
    NSArray *arr;
    if ([self.publishMethodPopup.selectedItem.title isEqualToString:@"App Store"]) {
        arr = @[ @"account:", @"password:" ];
    } else if ([self.publishMethodPopup.selectedItem.title isEqualToString:@"蒲公英"]) {
        arr = @[ @"userKey:", @"apiKey:" ];
    } else if ([self.publishMethodPopup.selectedItem.title isEqualToString:@"FIR"]) {
        arr = @[ @"token:" ];
    }
    
    CGFloat y = titleTextField.frame.origin.y - titleTextField.frame.size.height - 15;
    NSInteger index = 1;
    for (NSString *tips in arr) {
        NSTextField *tipsTextField = [[NSTextField alloc] initWithFrame:CGRectMake(0, y, 90, 20)];
        tipsTextField.font = [NSFont systemFontOfSize:15];
        [tipsTextField setEnabled:NO];
        [tipsTextField setBordered:NO];
        tipsTextField.backgroundColor = [NSColor clearColor];
        tipsTextField.textColor = [NSColor whiteColor];
        tipsTextField.alignment = NSTextAlignmentRight;
        tipsTextField.stringValue = tips;
        [panel.contentView addSubview:tipsTextField];
        
        CGFloat x = tipsTextField.frame.origin.x + tipsTextField.frame.size.width + 10;
        
        NSTextField *accountTextField = [[NSTextField alloc] initWithFrame:CGRectMake(x, tipsTextField.frame.origin.y, panel.frame.size.width - x - 10, 20)];
        accountTextField.tag = index;
        [panel.contentView addSubview:accountTextField];
        
        y -= 35;
        index++;
    }
    
    NSButton *cancelButton = [[NSButton alloc] initWithFrame:CGRectMake(panel.frame.size.width - 120, 10, 50, 30)];
    [cancelButton setButtonType:NSButtonTypePushOnPushOff];
    [cancelButton setBezelStyle:NSBezelStyleTexturedRounded];
    cancelButton.title = @"取消";
    [panel.contentView addSubview:cancelButton];
    [cancelButton setTarget:self];
    [cancelButton setAction:@selector(cancelButtonClick:)];
    
    NSButton *okButton = [[NSButton alloc] initWithFrame:CGRectMake(panel.frame.size.width - 60, 10, 50, 30)];
    [okButton setButtonType:NSButtonTypePushOnPushOff];
    [okButton setBezelStyle:NSBezelStyleTexturedRounded];
    okButton.title = @"确定";
    [panel.contentView addSubview:okButton];
    [okButton setTarget:self];
    [okButton setAction:@selector(okButtonClick:)];
    
    [self.view.window beginSheet:panel
               completionHandler:^(NSModalResponse returnCode){
        
    }];
}

- (void)cancelButtonClick:(NSButton *)sender
{
    [self.view.window endSheet:sender.window];
    
    if ([self.publishMethodPopup.selectedItem.title isEqualToString:@"App Store"]) {
        self.appstoreAccount = nil;
        self.appstorePassword = nil;
    } else if ([self.publishMethodPopup.selectedItem.title isEqualToString:@"蒲公英"]) {
        self.pgyerUserKey = nil;
        self.pgyerApiKey = nil;
    } else if ([self.publishMethodPopup.selectedItem.title isEqualToString:@"FIR"]) {
        self.firToken = nil;
    }
    
    [self.publishMethodPopup selectItemAtIndex:0];
}

- (void)okButtonClick:(NSButton *)sender
{
    NSTextField *accountTextField = [(NSTextField *)sender.superview viewWithTag:1];
    NSTextField *passwordTextField = [(NSTextField *)sender.superview viewWithTag:2];
    
    if ([self.publishMethodPopup.selectedItem.title isEqualToString:@"App Store"]) {
        if (accountTextField.stringValue.length == 0) {
            [self handlerMessage:@"用户名不能为空"];
            return;
        }
        if (passwordTextField.stringValue.length == 0) {
            [self handlerMessage:@"密码不能为空"];
            return;
        }
        
        self.appstoreAccount = accountTextField.stringValue;
        self.appstorePassword = passwordTextField.stringValue;
    } else if ([self.publishMethodPopup.selectedItem.title isEqualToString:@"蒲公英"]) {
        if (accountTextField.stringValue.length == 0) {
            [self handlerMessage:@"UserKey不能为空"];
            return;
        }
        if (passwordTextField.stringValue.length == 0) {
            [self handlerMessage:@"ApiKey不能为空"];
            return;
        }
        self.pgyerUserKey = accountTextField.stringValue;
        self.pgyerApiKey = passwordTextField.stringValue;
    } else if ([self.publishMethodPopup.selectedItem.title isEqualToString:@"FIR"]) {
        if (accountTextField.stringValue.length == 0) {
            [self handlerMessage:@"Token不能为空"];
            return;
        }
        
        self.firToken = accountTextField.stringValue;
    }
    [self.view.window endSheet:sender.window];
}

#pragma mark -
#pragma mark :. handler message

- (void)handlerMessage:(NSString *)log
{
    NSString *tips = @"I: ";
    if ([log hasPrefix:@"--------------------------------------------------------"] || !log.length)
        tips = @"";
    
    self.messageTextView.string = [self.messageTextView.string stringByAppendingString:[NSString stringWithFormat:@"%@%@\n", tips, log]];
    [self.messageTextView scrollRangeToVisible:NSMakeRange(self.messageTextView.string.length, 0)];
}


#pragma mark -
#pragma mark :. project Plist Construct
// plist 配置构建
- (BOOL)projectPlistConstructHandler
{
    [self handlerMessage:@"--------------------------------------------------------Config Plist---------------------------------------------------------"];
    [self handlerMessage:@"读取配置..."];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *projectName = [self.inputFileTextField.stringValue componentsSeparatedByString:@"/"].lastObject;
    NSString *plistPath = [self.inputFileTextField.stringValue stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/Info.plist", projectName]];
    if (![fileManager fileExistsAtPath:plistPath])
        plistPath = [self.inputFileTextField.stringValue stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/Supporting Files/Info.plist", projectName]];
    
    if (![fileManager fileExistsAtPath:plistPath]) {
        [self handlerMessage:@"没有找到 Plist"];
        [self handlerMessage:@"--------------------------------------------------------end Config Plist--------------------------------------------------------- \n"];
        return NO;
    }
    
    self.plistCopyPath = [plistPath stringByReplacingOccurrencesOfString:@"Info.plist" withString:@"copyInfo.plist"];
    
    if ([fileManager fileExistsAtPath:self.plistCopyPath])
        [fileManager removeItemAtPath:self.plistCopyPath error:nil];
    
    NSError *error = nil;
    if ([fileManager copyItemAtPath:plistPath toPath:self.plistCopyPath error:&error]) {
        [self handlerMessage:@"备份Plist成功..."];
    }
    
    NSMutableDictionary *plistDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
    [self handlerMessage:@"替换 Bundle Identifier"];
    if (self.bundleIdentifierTextField.stringValue.length && [plistDictionary objectForKey:@"CFBundleIdentifier"]) {
        [plistDictionary setObject:self.bundleIdentifierTextField.stringValue forKey:@"CFBundleIdentifier"];
        if (![self bundleIdentifierConstructHandler])
            return NO;
        self.projectBundleIdentifier = self.bundleIdentifierTextField.stringValue;
    } else if (self.bundleIdentifierTextField.enabled && [[plistDictionary objectForKey:@"CFBundleIdentifier"] isEqualToString:@"$(PRODUCT_BUNDLE_IDENTIFIER)"]) {
        self.projectBundleIdentifier = [self obtainBundleIdentifier];
        if (!self.projectBundleIdentifier) {
            [self handlerMessage:@"获取 Bundle Identifier 失败"];
            [self handlerMessage:@"--------------------------------------------------------end Config Plist--------------------------------------------------------- \n"];
            return NO;
        }
    }
    
    [self handlerMessage:@"替换 Display Name"];
    if (self.displayNameTextField.stringValue.length) { // && [plistDictionary objectForKey:@"CFBundleDisplayName"]
        [plistDictionary setObject:self.displayNameTextField.stringValue forKey:@"CFBundleDisplayName"];
    }
    
    [self handlerMessage:@"替换 version"];
    if (self.appVersionTextField.stringValue.length && [plistDictionary objectForKey:@"CFBundleShortVersionString"]) {
        [plistDictionary setObject:self.appVersionTextField.stringValue forKey:@"CFBundleShortVersionString"];
    }
    
    [self handlerMessage:@"替换 bundle version"];
    if (self.appBuildVersionTextField.stringValue.length && [plistDictionary objectForKey:@"CFBundleVersion"]) {
        [plistDictionary setObject:self.appBuildVersionTextField.stringValue forKey:@"CFBundleVersion"];
    }
    
    [self handlerMessage:@"替换 channel Identifier"];
    if (self.appChannelTextField.stringValue.length) {
        [plistDictionary setObject:self.appChannelTextField.stringValue forKey:@"CFBundleChannelIdentifier"];
    }
    
    [plistDictionary writeToFile:plistPath atomically:YES];
    [self handlerMessage:@"保存 Plist 配置"];
    
    NSString *displayName = [plistDictionary objectForKey:@"CFBundleDisplayName"];
    if (!displayName)
        displayName = self.displayNameTextField.stringValue;
    
    self.saveIPAName = [NSString stringWithFormat:@"%@_(%@)(%@)", displayName, [plistDictionary objectForKey:@"CFBundleShortVersionString"], [plistDictionary objectForKey:@"CFBundleVersion"]];
    [self handlerMessage:@"--------------------------------------------------------end Config Plist--------------------------------------------------------- \n"];
    return YES;
}

- (NSString *)obtainBundleIdentifier
{
    NSString *projectName = [self.inputFileTextField.stringValue componentsSeparatedByString:@"/"].lastObject;
    NSData *projectData = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@.xcodeproj/project.pbxproj", [self.inputFileTextField.stringValue stringByAppendingPathComponent:projectName]]];
    NSString *projecttring = [[NSString alloc] initWithData:projectData encoding:NSUTF8StringEncoding];
    NSError *error = NULL;
    NSRegularExpression *regularExpression = [NSRegularExpression regularExpressionWithPattern:@"(?<=PRODUCT_BUNDLE_IDENTIFIER = )((.*?));"
                                                                                       options:NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators
                                                                                         error:&error];
    NSTextCheckingResult *result = [regularExpression firstMatchInString:projecttring options:NSMatchingReportProgress range:NSMakeRange(0, [projecttring length])];
    NSMutableArray *matchArray = [[NSMutableArray alloc] initWithCapacity:0];
    for (NSInteger i = 1; i < [result numberOfRanges]; i++) {
        if ([result rangeAtIndex:i].location != NSNotFound)
            [matchArray addObject:[projecttring substringWithRange:[result rangeAtIndex:i]]];
    }
    
    return [[NSSet setWithArray:matchArray] allObjects].firstObject;
}

// 设置新的bundleIdentifier 对工程的 project.pbxproj 调整
- (BOOL)bundleIdentifierConstructHandler
{
    [self handlerMessage:@"--------------------------------------------------------Construct project.pbxproj---------------------------------------------------------"];
    [self handlerMessage:@"读取 project.pbxproj"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *projectName = [self.inputFileTextField.stringValue componentsSeparatedByString:@"/"].lastObject;
    NSString *projectPbxprojPath = [NSString stringWithFormat:@"%@/%@.xcodeproj/project.pbxproj", self.inputFileTextField.stringValue, projectName];
    if (![fileManager fileExistsAtPath:projectPbxprojPath]) {
        [self handlerMessage:@"没有找到 project.pbxproj"];
        [self handlerMessage:@"--------------------------------------------------------end Construct project.pbxproj--------------------------------------------------------- \n"];
        return NO;
    }
    
    self.projectPbxprojCopyPath = [projectPbxprojPath stringByReplacingOccurrencesOfString:@"project.pbxproj" withString:@"copyproject.pbxproj"];
    [fileManager removeItemAtPath:self.archiveCopyPath error:nil];
    if ([fileManager copyItemAtPath:projectPbxprojPath toPath:self.projectPbxprojCopyPath error:nil])
        [self handlerMessage:@"备份project.pbxproj成功..."];
    
    NSData *projectPbxprojData = [[NSFileHandle fileHandleForReadingAtPath:projectPbxprojPath] readDataToEndOfFile];
    NSString *xmlString = [[NSString alloc] initWithData:projectPbxprojData encoding:NSUTF8StringEncoding];
    
    [self handlerMessage:@"配置 PRODUCT_BUNDLE_IDENTIFIER"];
    xmlString = [self archiveConfigReplaceWithxmlString:xmlString pattern:@"(?<=PRODUCT_BUNDLE_IDENTIFIER = )((.*?));" template:[NSString stringWithFormat:@"%@;", self.bundleIdentifierTextField.stringValue]];
    
    [self handlerMessage:@"保存配置..."];
    [fileManager removeItemAtURL:[NSURL fileURLWithPath:projectPbxprojPath] error:nil];
    [fileManager createFileAtPath:projectPbxprojPath contents:[xmlString dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    [self handlerMessage:@"--------------------------------------------------------end Construct project.pbxproj--------------------------------------------------------- \n"];
    
    return YES;
}

#pragma mark -
#pragma mark :. ExportPlist Construct

// 配置生成IPA配置Plist
- (BOOL)projectExportPlistConstructHandler
{
    [self handlerMessage:@"--------------------------------------------------------Construct export Plist---------------------------------------------------------"];
    [self handlerMessage:@"读取 export Plist"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *plistName = @"exportOptions";
    if ([self.publishMethodPopup.selectedItem.title isEqualToString:@"App Store"])
        plistName = @"exportAppStore";
    
    NSString *exportPath = [[NSBundle mainBundle] pathForResource:plistName ofType:@"plist"];
    if (![fileManager fileExistsAtPath:exportPath]) {
        [self handlerMessage:@"没有找到 export plist"];
        [self handlerMessage:@"--------------------------------------------------------end export Plist--------------------------------------------------------- \n"];
        return NO;
    }
    
    self.exportPlistCopyPath = [exportPath stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@.plist", plistName] withString:[NSString stringWithFormat:@"copy%@.plist", plistName]];
    if ([fileManager fileExistsAtPath:self.exportPlistCopyPath])
        [fileManager removeItemAtPath:self.exportPlistCopyPath error:nil];
    
    NSError *error = nil;
    if ([fileManager copyItemAtPath:exportPath toPath:self.exportPlistCopyPath error:&error]) {
        [self handlerMessage:@"备份export Plist成功..."];
    }
    
    NSMutableDictionary *plistDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:exportPath];
    
    [self handlerMessage:@"替换 Provisioning Profile Name"];
    [self handlerMessage:@"替换 Bundle Identifier"];
    NSMutableDictionary *provisioningProfiles = [[NSMutableDictionary alloc] initWithDictionary:[plistDictionary objectForKey:@"provisioningProfiles"]];
    [provisioningProfiles removeAllObjects];
    [provisioningProfiles setObject:self.projectBundleIdentifier forKey:self.profileFilename];
    [plistDictionary setObject:provisioningProfiles forKey:@"provisioningProfiles"];
    
    [self handlerMessage:@"替换 teamID"];
    if ([plistDictionary objectForKey:@"teamID"]) {
        [plistDictionary setObject:self.profileTeamID forKey:@"teamID"];
    }
    
    [self handlerMessage:@"替换 distribution method"];
    if ([plistDictionary objectForKey:@"method"]) {
        [plistDictionary setObject:self.distributionMethodPopup.selectedItem.title forKey:@"method"];
    }
    
    [plistDictionary writeToFile:exportPath atomically:YES];
    [self handlerMessage:@"保存 export Plist 配置"];
    [self handlerMessage:@"--------------------------------------------------------end export Plist--------------------------------------------------------- \n"];
    return YES;
}


// archive 配置修改（打包命令）
- (BOOL)projectArchiveConstructHandler
{
    [self handlerMessage:@"--------------------------------------------------------Construct Archive---------------------------------------------------------"];
    [self handlerMessage:@"读取 Archive"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *archivePath = [[NSBundle mainBundle] pathForResource:@"archive" ofType:@"sh"];
    if (![fileManager fileExistsAtPath:archivePath]) {
        [self handlerMessage:@"没有找到 Archive"];
        [self handlerMessage:@"--------------------------------------------------------end Construct Archive--------------------------------------------------------- \n"];
        return NO;
    }
    
    self.archiveCopyPath = [archivePath stringByReplacingOccurrencesOfString:@"archive.sh" withString:@"copyArchive.sh"];
    [fileManager removeItemAtPath:self.archiveCopyPath error:nil];
    if ([fileManager copyItemAtPath:archivePath toPath:self.archiveCopyPath error:nil])
        [self handlerMessage:@"备份Archive成功..."];
    
    NSData *archiveData = [[NSFileHandle fileHandleForReadingAtPath:archivePath] readDataToEndOfFile];
    NSString *xmlString = [[NSString alloc] initWithData:archiveData encoding:NSUTF8StringEncoding];
    
    [self handlerMessage:@"配置 IPA Name"];
    xmlString = [self archiveConfigReplaceWithxmlString:xmlString pattern:@"(?<=IPA_NAME=)(\"(.*?)\")" template:[NSString stringWithFormat:@"\"%@\"", self.saveIPAName]];
    
    [self handlerMessage:@"配置 IPA save Path"];
    xmlString = [self archiveConfigReplaceWithxmlString:xmlString pattern:@"(?<=APP_DIR=)(\"(.*?)\")" template:[NSString stringWithFormat:@"\"%@\"", self.appSavePathTextField.stringValue]];
    
    NSString *projectName = [self.inputFileTextField.stringValue componentsSeparatedByString:@"/"].lastObject;
    [self handlerMessage:@"配置 Project Path"];
    xmlString = [self archiveConfigReplaceWithxmlString:xmlString pattern:@"(?<=PROJECT_DIR=)(\"(.*?)\")" template:[NSString stringWithFormat:@"\"%@\"", [self.inputFileTextField.stringValue stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@/", projectName] withString:@""]]];
    
    NSString *plistName = @"exportOptions.plist";
    if ([self.publishMethodPopup.selectedItem.title isEqualToString:@"App Store"])
        plistName = @"exportAppStore.plist";
    [self handlerMessage:@"配置 ExportOptions Path"];
    xmlString = [self archiveConfigReplaceWithxmlString:xmlString pattern:@"(?<=EXPORT_DIR=)(\"(.*?)\")" template:[NSString stringWithFormat:@"\"%@\"", [archivePath stringByReplacingOccurrencesOfString:@"archive.sh" withString:plistName]]];
    
    [self handlerMessage:@"配置 Workplace Name"];
    xmlString = [self archiveConfigReplaceWithxmlString:xmlString pattern:@"(?<=PROJECT_NAME=)(\"(.*?)\")" template:[NSString stringWithFormat:@"\"%@\"", projectName]];
    
    [self handlerMessage:@"配置 scheme Name"];
    xmlString = [self archiveConfigReplaceWithxmlString:xmlString pattern:@"(?<=SCHEME_NAME=)(\"(.*?)\")" template:[NSString stringWithFormat:@"\"%@\"", projectName]];
    
    [self handlerMessage:@"配置 upLoad method"];
    xmlString = [self archiveConfigReplaceWithxmlString:xmlString pattern:@"(?<=UPLOAD_ADDRESS=)(\"(.*?)\")" template:[NSString stringWithFormat:@"\"%@\"", self.publishMethodPopup.selectedItem.title]];
    
    
    if ([self.publishMethodPopup.selectedItem.title isEqualToString:@"App Store"]) {
        [self handlerMessage:@"配置发布App Store 用户名"];
        xmlString = [self archiveConfigReplaceWithxmlString:xmlString pattern:@"(?<=APPSTORE_ACCOUNT=)(\"(.*?)\")" template:[NSString stringWithFormat:@"\"%@\"", self.appstoreAccount]];
        
        [self handlerMessage:@"配置发布App Store 密码"];
        xmlString = [self archiveConfigReplaceWithxmlString:xmlString pattern:@"(?<=APPSTORE_PASSWORD=)(\"(.*?)\")" template:[NSString stringWithFormat:@"\"%@\"", self.appstorePassword]];
    } else if ([self.publishMethodPopup.selectedItem.title isEqualToString:@"蒲公英"]) {
        [self handlerMessage:@"配置发布蒲公英 uKey"];
        xmlString = [self archiveConfigReplaceWithxmlString:xmlString pattern:@"(?<=PGYER_USER_KEY=)(\"(.*?)\")" template:[NSString stringWithFormat:@"\"%@\"", self.pgyerUserKey]];
        
        [self handlerMessage:@"配置发布蒲公英 apiKey"];
        xmlString = [self archiveConfigReplaceWithxmlString:xmlString pattern:@"(?<=PGYER_API_KEY=)(\"(.*?)\")" template:[NSString stringWithFormat:@"\"%@\"", self.pgyerApiKey]];
    } else if ([self.publishMethodPopup.selectedItem.title isEqualToString:@"FIR"]) {
        // 需要先在本地安装 fir 插件,安装fir插件命令: gem install fir-cli
        [self handlerMessage:@"配置发布FIR token"];
        xmlString = [self archiveConfigReplaceWithxmlString:xmlString pattern:@"(?<=FIR_TOKEN=)(\"(.*?)\")" template:[NSString stringWithFormat:@"\"%@\"", self.firToken]];
    }
    
    [self handlerMessage:@"保存配置..."];
    [fileManager removeItemAtURL:[NSURL fileURLWithPath:archivePath] error:nil];
    [fileManager createFileAtPath:archivePath contents:[xmlString dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    [self handlerMessage:@"--------------------------------------------------------end Construct Archive--------------------------------------------------------- \n"];
    
    return YES;
}

/**
 *  匹配字符串中的结果并替换
 *
 *  @param xmlString 源数据
 *  @param pattern  正则字符串
 *  @param template 替换字符串
 */
- (NSString *)archiveConfigReplaceWithxmlString:(NSString *)xmlString
                                        pattern:(NSString *)pattern
                                       template:(NSString *)template
{
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    NSTextCheckingResult *result = [regex firstMatchInString:xmlString options:0 range:NSMakeRange(0, xmlString.length)];
    if (result) // 替换匹配结果
        xmlString = [regex stringByReplacingMatchesInString:xmlString options:0 range:NSMakeRange(0, xmlString.length) withTemplate:template];
    
    return xmlString;
}

#pragma mark -
#pragma mark :. clear Construct

- (void)clearConstructConfig
{
    [self handlerMessage:@"--------------------------------------------------------Clear Construct---------------------------------------------------------"];
    [self handlerMessage:@"读取项目备份Plist"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *plistPath = [self.plistCopyPath stringByReplacingOccurrencesOfString:@"copyInfo.plist" withString:@"Info.plist"];
    
    NSError *error = nil;
    [fileManager removeItemAtPath:plistPath error:nil];
    if ([fileManager copyItemAtPath:self.plistCopyPath toPath:plistPath error:&error]) {
        [self handlerMessage:@"还原备份 Plist 成功..."];
    }
    
    if ([fileManager fileExistsAtPath:self.plistCopyPath]) {
        [fileManager removeItemAtPath:self.plistCopyPath error:nil];
        [self handlerMessage:@"清理构建 Plist 成功..."];
    }
    
    if (self.projectPbxprojCopyPath) {
        [self handlerMessage:@"读取打包备份project.pbxproj"];
        NSString *projectPbxprojPath = [self.projectPbxprojCopyPath stringByReplacingOccurrencesOfString:@"copyproject.pbxproj" withString:@"project.pbxproj"];
        if ([fileManager copyItemAtPath:self.projectPbxprojCopyPath toPath:projectPbxprojPath error:&error]) {
            [self handlerMessage:@"还原 project.pbxproj 成功..."];
        }
        
        if ([fileManager fileExistsAtPath:self.projectPbxprojCopyPath]) {
            [fileManager removeItemAtPath:self.projectPbxprojCopyPath error:nil];
            [self handlerMessage:@"清理构建 project.pbxproj 成功..."];
        }
    }
    
    [self handlerMessage:@"读取打包备份Archive"];
    NSString *archivePath = [self.archiveCopyPath stringByReplacingOccurrencesOfString:@"copyArchive.sh" withString:@"archive.sh"];
    [fileManager removeItemAtPath:archivePath error:nil];
    if ([fileManager copyItemAtPath:self.archiveCopyPath toPath:archivePath error:&error]) {
        [self handlerMessage:@"还原打包 Archive 成功..."];
    }
    
    if ([fileManager fileExistsAtPath:self.archiveCopyPath]) {
        [fileManager removeItemAtPath:self.archiveCopyPath error:nil];
        [self handlerMessage:@"清理 Archive 成功..."];
    }
    
    [self handlerMessage:@"读取打包备份Plist"];
    NSString *exportPlistPath = [self.exportPlistCopyPath stringByReplacingOccurrencesOfString:@"copyexportOptions.plist" withString:@"exportOptions.plist"];
    [fileManager removeItemAtPath:exportPlistPath error:nil];
    if ([fileManager copyItemAtPath:self.exportPlistCopyPath toPath:exportPlistPath error:&error]) {
        [self handlerMessage:@"还原打包备份 Plist 成功..."];
    }
    
    if ([fileManager fileExistsAtPath:self.exportPlistCopyPath]) {
        [fileManager removeItemAtPath:self.exportPlistCopyPath error:nil];
        [self handlerMessage:@"清理打包构建 Plist 成功..."];
    }
    
    [self handlerMessage:@"--------------------------------------------------------end Clear Construct---------------------------------------------------------"];
}

@end
