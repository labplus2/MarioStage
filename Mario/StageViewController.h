//
//  ViewController.h
//  Mario
//
//  Created by elpeo on 2014/02/15.
//  Copyright (c) 2014年 elpeo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>

@interface StageViewController : UIViewController<UIWebViewDelegate>
{
    CMMotionManager *manager;
    CMDeviceMotionHandler handler;
    UITextView* textView;
    UIScrollView *scrollView;
    UIWebView *webView;
    float distance;
    CGPoint dpcm;
    CGPoint origin;
}

-(void)calibration;

@end
