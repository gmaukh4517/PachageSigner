//
//  MainView.m
//  PachageSigner
//
//  Created by CC on 2019/9/19.
//  Copyright © 2019 CC. All rights reserved.
//

#import "MainView.h"

@interface MainView ()

@property (nonatomic, assign) BOOL fileTypeIsOk;

@end

@implementation MainView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    if (self = [super initWithFrame:frameRect]) {
        [self registerForDraggedTypes:[NSArray arrayWithObjects:NSPasteboardTypeFileURL, nil]];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    if (self = [super initWithCoder:decoder]) {
        [self registerForDraggedTypes:[NSArray arrayWithObjects:NSPasteboardTypeFileURL, nil]];
    }
    return self;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    NSTextField *inputFileTextField = (NSTextField *)[self viewWithTag:1];
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    if (pasteboard.pasteboardItems.count <= 1) { // 判断是否是单文件
        NSURL *url = [NSURL URLFromPasteboard:pasteboard];
        if (url) {
            inputFileTextField.stringValue = url.path;
        }
    } else { //多文件
        NSArray *list = [pasteboard propertyListForType:NSPasteboardTypeFileURL];
        NSMutableArray *urlList = [NSMutableArray array];
        for (NSString *str in list) {
            [urlList addObject:[NSURL fileURLWithPath:str]];
        }

        if (urlList.count) {
            //            inputFileTextField.stringValue = url.path;
        }
    }
    return YES;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    NSDragOperation dragOperation = NSDragOperationNone;
    self.fileTypeIsOk = NO;
    if ([self checkExtension:sender]) {
        self.fileTypeIsOk = YES;
        dragOperation = sender.draggingSourceOperationMask;
    }

    return dragOperation;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
    NSDragOperation dragOperation = NSDragOperationNone;
    if (self.fileTypeIsOk)
        dragOperation = sender.draggingSourceOperationMask;
    return dragOperation;
}

- (BOOL)checkExtension:(id<NSDraggingInfo>)sender
{
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    if (pasteboard.pasteboardItems.count <= 1) {
        NSURL *url = [NSURL URLFromPasteboard:pasteboard];
        if (url)
            return !url.path.pathExtension.lowercaseString.length;
    }

    if (pasteboard.types) {
        if ([pasteboard.types containsObject:NSPasteboardTypeURL]) {
            NSURL *url = [NSURL URLFromPasteboard:pasteboard];
            if (url)
                return !url.pathExtension.lowercaseString.length;
        }
    }

    return YES;
}

@end
