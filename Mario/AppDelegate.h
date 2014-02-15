//
//  AppDelegate.h
//  Mario
//
//  Created by elpeo on 2014/02/15.
//  Copyright (c) 2014年 elpeo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "StageViewController.h"
#import "CameraViewController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *cameraWindow;
@property (strong, nonatomic) UIWindow *stageWindow;
@property (strong, nonatomic) CameraViewController *cameraViewController;
@property (strong, nonatomic) StageViewController *stageViewController;

@end
