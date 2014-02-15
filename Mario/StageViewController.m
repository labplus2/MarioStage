//
//  ViewController.m
//  Mario
//
//  Created by elpeo on 2014/02/15.
//  Copyright (c) 2014年 elpeo. All rights reserved.
//

#import "StageViewController.h"

@interface StageViewController ()

@end

@implementation StageViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    manager = [[CMMotionManager alloc] init];
    //    manager.deviceMotionUpdateInterval = 0.1f;
    
    float projector[] = {80, 40.6, 22.8}; // プロジェクタ小
    //float projector[] = {186, 125.2, 71}; // プロジェクタ大
    
    distance = 90; // プロジェクタとスクリーンの距離(cm)
    //CGSize halfRadian = CGSizeMake(0.2423625801479178, 0.14345226330365873); // プロジェクタの画角の半分(radian)
    CGSize halfRadian = CGSizeMake(atan2f(projector[1]/2, projector[0]), atan2f(projector[2]/2, projector[0])); // プロジェクタの画角の半分(radian)
    CGSize halfCm = CGSizeMake(distance*tanf(halfRadian.width), distance*tanf(halfRadian.height)); // スクリーンサイズの半分(cm)
    dpcm = CGPointMake(284/halfCm.width, 160/halfCm.height); // 1cmあたりのピクセル数
    origin = CGPointZero;
    
    /*
    scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 568, 320)];
    [scrollView setContentSize:CGSizeMake(1920,1200)];
    [self.view addSubview:scrollView];
    UIImageView* paper = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"paper.jpg"]];
    [scrollView addSubview:paper];
    scroll.contentOffset = CGPointMake(676, 440);
     */

    webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 568, 320)];
    webView.delegate = self;
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://dl.dropboxusercontent.com/u/2221891/ohd2/OpenHackDay2/index.html"] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:60];
    [webView loadRequest:request];
    [self.view addSubview:webView];

    textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 400, 18)];
    textView.font = [UIFont fontWithName:@"Arial" size:18];
    textView.contentInset = UIEdgeInsetsMake(-11,-4,0,0);
    [self.view addSubview:textView];
    textView.hidden = YES;
}

- (CGSize)angleToPx:(CGSize)radians
{
    return CGSizeMake(distance*tanf(radians.width)*dpcm.x, distance*tanf(radians.height)*dpcm.y);
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

-(void)calibration
{
    origin = CGPointZero;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView_
{
    if(manager.deviceMotionActive) return;

    [manager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical
                                                 toQueue:[NSOperationQueue currentQueue]
                                             withHandler:^(CMDeviceMotion *motion, NSError *error)
     {
         CGPoint rad = CGPointMake(motion.attitude.yaw, motion.attitude.roll);
         if(CGPointEqualToPoint(origin, CGPointZero)){
             origin = rad;
             return;
         }
         
         CGSize px = [self angleToPx:CGSizeMake(rad.x-origin.x, rad.y-origin.y)];
         //[scrollView setContentOffset:CGPointMake(676-px.width, 440+px.height) animated:NO];
         
         NSString* script = [NSString stringWithFormat:@"entryPoint(\"scroll\",%f,%f);", -px.width, -px.height];
         [webView stringByEvaluatingJavaScriptFromString:script];
         
         /*
          float x = motion.attitude.pitch * 180 / M_PI;
          float y = motion.attitude.roll * 180 / M_PI;
          float z = motion.attitude.yaw * 180 / M_PI;
          textView.text = [NSString stringWithFormat:@"%f %f %f %f %f", x, y, z, px.width, px.height];
          */
         textView.text = [NSString stringWithFormat:@"[%d] %@", motion.magneticField.accuracy, script];
     }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
