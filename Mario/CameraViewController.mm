//
//  CameraViewController.m
//  MarioTracker
//
//  Created by 吉田一星 on 2014/02/15.
//  Copyright (c) 2014年 yahoo! japan. All rights reserved.
//

#import "CameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import "UIImage+OpenCV.h"

@interface CameraViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (strong,nonatomic) UIImageView *imageView;
@property (strong,nonatomic) AVCaptureSession* captureSession;
@property (strong,nonatomic) NSLock* lock;
@property (nonatomic) cv::Mat hsv;
@property (nonatomic) cv::Mat mask;
@property (nonatomic) cv::Mat hist;
@property (nonatomic) cv::Mat histimg;
@property (nonatomic) cv::Mat backproj;
@property (nonatomic) int trackObject;
@property (nonatomic) cv::Rect trackWindow;
@property (nonatomic) cv::Rect selection;
@property (nonatomic) cv::Mat m_prevImg;
@property (nonatomic) std::vector<cv::Point2f>  m_prevPts;
@property (nonatomic) cv::Ptr<cv::FeatureDetector> m_detector;
@end

@implementation CameraViewController

- (void)tapped:(UITapGestureRecognizer *)recognizer {
    CGPoint point = [recognizer locationInView:self.view];
    //NSLog(@"%f,%f",self.view.bounds.size.width, self.view.bounds.size.height);
    //NSLog(@"%f,%f",point.x, point.y);
    //point.x *= 360.0/320.0;
    //point.y *= 480.0/568.0;
    float x = point.x * 480.0/568.0;
    float y = point.y * 360.0/320.0;
    self.selection = cv::Rect(MAX(x-15,0),MAX(y-15,0),30,30);
    self.trackObject = -1;
    _histimg = cv::Scalar::all(0);
    _m_prevPts.clear();
}

- (void) execImageProcessingKLT:(UIImage *)inputImage
{
    double startTime = CFAbsoluteTimeGetCurrent();
    cv::Mat m_nextImg = [inputImage CVGrayscaleMat];
    cv::Mat outputFrame = [inputImage CVMat];
    
    if(self.trackObject){
        std::vector<unsigned char> m_status;
        std::vector<float>         m_error;
        std::vector<cv::Point2f>  m_nextPts;
        if (self.m_prevPts.size() > 0) {
            cv::calcOpticalFlowPyrLK(_m_prevImg, m_nextImg, _m_prevPts, m_nextPts, m_status, m_error);
        }
        std::vector<cv::Point2f> trackedPts;
        std::vector<cv::KeyPoint> m_nextKeypoints;

        for (size_t i=0; i<m_status.size(); i++) {
            if (m_status[i]) {
                trackedPts.push_back(m_nextPts[i]);
                //cv::line(outputFrame, _m_prevPts[i], m_nextPts[i], CV_RGB(0,250,0));
                cv::circle(outputFrame, m_nextPts[i], 3, CV_RGB(0,250,0), CV_FILLED);
            }
        }
        
        if (self.trackObject < 0) {
            self.m_detector->detect(m_nextImg, m_nextKeypoints);
            
            for (size_t i=0; i<m_nextKeypoints.size(); i++) {
                if (m_nextKeypoints[i].pt.x >= self.selection.x && m_nextKeypoints[i].pt.x <= self.selection.x + self.selection.width && m_nextKeypoints[i].pt.y >= self.selection.y && m_nextKeypoints[i].pt.y <= self.selection.y + self.selection.height) {
                    trackedPts.push_back(m_nextKeypoints[i].pt);
                    cv::circle(outputFrame, m_nextKeypoints[i].pt, 5, cv::Scalar(255,0,255), -1);
                }
            }
            self.trackObject = 1;
        }
        
        self.m_prevPts = trackedPts;
        m_nextImg.copyTo(_m_prevImg);
    }
    
    self.imageView.image = [UIImage imageWithCVMat:outputFrame];
    double endTime = CFAbsoluteTimeGetCurrent();
    //NSLog(@"%f", endTime - startTime);
}

- (void) execImageProcessing:(UIImage *)inputImage
{
    //NSLog(@"%f,%f",inputImage.size.width, inputImage.size.height);
    //int vmin = 10, vmax = 256, smin = 30;
    cv::Mat hue;
    int hsize = 16;
    float hranges[] = {0,180};
    const float* phranges = hranges;
    
    double startTime = CFAbsoluteTimeGetCurrent();
    
    cv::Mat img = [inputImage CVMat];
    
    cv::cvtColor(img, _hsv, cv::COLOR_BGR2HSV);
    
    if(self.trackObject){
        //int _vmin = vmin, _vmax = vmax;
        
        //cv::inRange(_hsv, cv::Scalar(0, smin, MIN(_vmin,_vmax)),
        //            cv::Scalar(180, 256, MAX(_vmin, _vmax)), _mask);
        cv::inRange(_hsv, cv::Scalar(0, 60, 32),
                    cv::Scalar(180, 255, 255), _mask);
        int ch[] = {0, 0};
        hue.create(self.hsv.size(), self.hsv.depth());
        cv::mixChannels(&_hsv, 1, &hue, 1, ch, 1);
        
        if( self.trackObject < 0 )
        {
            cv::Mat roi(hue, _selection), maskroi(_mask, _selection);
            cv::calcHist(&roi, 1, 0, maskroi, _hist, 1, &hsize, &phranges);
            cv::normalize(_hist, _hist, 0, 255, cv::NORM_MINMAX);
            
            self.trackWindow = _selection;
            self.trackObject = 1;
            
            _histimg = cv::Scalar::all(0);
            int binW = self.histimg.cols / hsize;
            cv::Mat buf(1, hsize, CV_8UC3);
            for( int i = 0; i < hsize; i++ )
                buf.at<cv::Vec3b>(i) = cv::Vec3b(cv::saturate_cast<uchar>(i*180./hsize), 255, 255);
            cvtColor(buf, buf, cv::COLOR_HSV2BGR);
            
            for( int i = 0; i < hsize; i++ )
            {
                int val = cv::saturate_cast<int>(self.hist.at<float>(i)*self.histimg.rows/255);
                cv::rectangle( _histimg, cv::Point(i*binW,self.histimg.rows),
                          cv::Point((i+1)*binW,self.histimg.rows - val),
                          cv::Scalar(buf.at<cv::Vec3b>(i)), -1, 8 );
            }
        }
        cv::calcBackProject(&hue, 1, 0, _hist, _backproj, &phranges);
        self.backproj &= self.mask;
        cv::RotatedRect trackBox;
        try {
            //trackBox =  cv::CamShift(_backproj, _trackWindow, cv::TermCriteria( cv::TermCriteria::EPS | cv::TermCriteria::COUNT, 10, 1 ));
            cv::meanShift(_backproj, _trackWindow, cv::TermCriteria( cv::TermCriteria::EPS | cv::TermCriteria::COUNT, 10, 1 ));
        } catch (cv::Exception& e) {
            NSLog(@"%s", e.what());
        }
        if( self.trackWindow.area() <= 1 )
        {
            int cols = self.backproj.cols, rows = self.backproj.rows, r = (MIN(cols, rows) + 5)/6;
            self.trackWindow = cv::Rect(self.trackWindow.x - r, self.trackWindow.y - r,
                               self.trackWindow.x + r, self.trackWindow.y + r) &
            cv::Rect(0, 0, cols, rows);
        }
        
        //cvtColor( self.backproj, img, cv::COLOR_GRAY2BGR );
        try {
            //cv::ellipse( img, trackBox, cv::Scalar(0,0,255), 3 );
            cv::rectangle(img, _trackWindow, cv::Scalar(0,0,255));
        } catch (cv::Exception& e) {
            NSLog(@"%s", e.what());
        }
    }
                
    self.imageView.image = [UIImage imageWithCVMat:img];
    
    double endTime = CFAbsoluteTimeGetCurrent();
    //NSLog(@"%f", endTime - startTime);
}

#pragma mark - AVCaptureSession delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
	   fromConnection:(AVCaptureConnection *)connection
{
    if (![self.lock tryLock]) {
        return;
    }
	/*We create an autorelease pool because as we are not in the main_queue our code is
	 not executed in the main thread. So we have to create an autorelease pool for the thread we are in*/
	
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    /*Lock the image buffer*/
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    /*Get information about the image*/
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    //NSLog(@"imagesize:%d,%d",width,height);
    
    /*Create a CGImageRef from the CVImageBufferRef*/
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef origContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef origImageRef = CGBitmapContextCreateImage(origContext);
    
    UIDeviceOrientation o = [[UIDevice currentDevice] orientation];
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    unsigned char *buf = (unsigned char*)malloc(sizeof(unsigned char) * width * height * 4);
    /*
    if (o == UIDeviceOrientationLandscapeLeft) {
        transform = CGAffineTransformIdentity;
    } else if (o == UIDeviceOrientationLandscapeRight) {
        transform = CGAffineTransformMakeTranslation(width, height);
        transform = CGAffineTransformRotate(transform, M_PI);
    } else if (o == UIDeviceOrientationPortraitUpsideDown) {
        transform = CGAffineTransformMakeTranslation(height, 0.0);
        transform = CGAffineTransformRotate(transform, M_PI / 2.0);
    } else {
        transform = CGAffineTransformMakeTranslation(0.0, width);
        transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
    }
    */
    size_t newWidth = width;
    size_t newHeight = height;
    //if (o != UIDeviceOrientationLandscapeLeft && o != UIDeviceOrientationLandscapeRight) {
    //    newWidth = height;
    //    newHeight = width;
    //}

    CGContextRef newContext = CGBitmapContextCreate(buf, newWidth, newHeight,
                                                    8, newWidth*4,
                                                    colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGContextConcatCTM(newContext, transform);
    CGContextDrawImage(newContext, CGRectMake(0, 0, width, height), origImageRef);
    CGImageRef newImageRef = CGBitmapContextCreateImage(newContext);
    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];
    
    free(buf);
	
    /*We release some components*/
    CGContextRelease(origContext);
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
	/*We display the result on the image view (We need to change the orientation of the image so that the video is displayed correctly).
	 Same thing as for the CALayer we are not in the main thread so ...*/
	//UIImage *image= [UIImage imageWithCGImage:newImage scale:1.0 orientation:UIImageOrientationRight];
	
	/*We relase the CGImageRef*/
	CGImageRelease(origImageRef);
    CGImageRelease(newImageRef);
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self execImageProcessing:newImage];
    });
    
	/*We unlock the  image buffer*/
	CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    [self.lock unlock];
}

#pragma mark - Camera

- (AVCaptureDevice *)cameraDevice:(BOOL)isBackCamera
{
    AVCaptureDevice *captureDevice = nil;
    
    if (!isBackCamera) {
        NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in videoDevices) {
            if (device.position == AVCaptureDevicePositionFront) {
                captureDevice = device;
                break;
            }
        }
    }
    
    if (!captureDevice) {
        captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    return captureDevice;
}

- (void)loadCamera{
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPresetMedium]) {
        self.captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    }
    self.captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    NSError *error = nil;
    AVCaptureDevice *captureDevice = [self cameraDevice:YES];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if (!input) {
        NSLog(@"input error");
    }
    [self.captureSession addInput:input];
    
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
	[captureOutput setSampleBufferDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    
	NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
	NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
	NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
	[captureOutput setVideoSettings:videoSettings];
    [self.captureSession addOutput:captureOutput];
    
    /*
     AVCaptureVideoPreviewLayer *videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
     videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
     videoPreviewLayer.frame = self.view.bounds;
     [self.view.layer insertSublayer:videoPreviewLayer atIndex:0];
     
    [self.captureSession startRunning];
    */
}

#pragma mark - Setter / Getter

- (NSLock *)lock
{
    if (!_lock){
        _lock = [[NSLock alloc] init];
    }
    return _lock;
}

- (AVCaptureSession *)captureSession
{
    if (!_captureSession) {
        _captureSession = [[AVCaptureSession alloc] init];
    }
    return _captureSession;
}

#pragma mark - Application lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self loadCamera];
    self.trackObject = 0;
    UITapGestureRecognizer *tapGesture =
    [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapped:)];
    [self.view addGestureRecognizer:tapGesture];
    self.imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 568, 320)];
    [self.view addSubview:self.imageView];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.captureSession startRunning];
    CGRect mainRect = [[UIScreen mainScreen] bounds];
    //self.imageView.transform = CGAffineTransformMakeRotation(90 * M_PI / 180);
    //self.imageView.frame = CGRectMake(0, 0, 320, 568);
    //self.imageView.center = CGPointMake(mainRect.size.width / 2, mainRect.size.height / 2);
    
    self.m_detector = cv::FeatureDetector::create("GridFAST");
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.captureSession stopRunning];
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
