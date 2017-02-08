//
//  FaceRecognitionViewController.m
//  CocoMobileV1
//
//  Created by 前海睿科 on 16/3/24.
//  Copyright © 2016年 Qhrico. All rights reserved.
//

#import "FaceRecognitionViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "LY_AudioPalyTool.h"
@import CoreText;

NSTimeInterval JGFCameraDefaultPauseBeforeShutterInterval = 1.0f;
NSTimeInterval JGFCameraDefaultFeedbackIntervalWhileWaitingForShutter = 0.2f;
NSTimeInterval JGFCameraDefaultMinimumWinkDurationForAutomaticTrigger = 0.5f;
NSTimeInterval JGFCameraDefaultMinimumWinkDurationForOpenEyes = 0.8f;

@interface FaceRecognitionViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic ,strong) AVCaptureSession *session;
@property (strong) AVCaptureDevice *videoDevice;
@property (strong) AVCaptureDeviceInput *videoInput;
@property (strong) AVCaptureVideoDataOutput *frameOutput;
@property (nonatomic, strong) AVCaptureStillImageOutput   * stillImageOutput;
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;//相机拍摄预览图层

@property (strong,nonatomic) AVCaptureStillImageOutput *captureStillImageOutput;//照片输出流

@property (nonatomic,strong)UIImage *image;
@property (nonatomic, assign) BOOL faceFound;
@property (nonatomic, strong) CIContext *context;
@property (nonatomic, strong) CIDetector *faceDetector;
@property (weak, nonatomic) IBOutlet UIView *ViewContainer;

@property (weak, nonatomic) IBOutlet UIView *maoPoint;

@property (weak, nonatomic) IBOutlet UIImageView *spideImage;

@property (weak, nonatomic) IBOutlet UIView *bottomView;

@property (weak, nonatomic) IBOutlet UIButton *takePhotoBtn;

@property (weak, nonatomic) IBOutlet UILabel *tipsLab;

@property (weak, nonatomic) IBOutlet UIImageView *finalImageV;

@property (nonatomic,strong)UIImage *finalimage;

@property (nonatomic, strong) NSDate *startedDetectingWinkDate;
@property (nonatomic, strong) NSDate *endedDetectingWinkDate;


@property (nonatomic,assign)BOOL isGreen;
@property (nonatomic,strong)NSMutableArray *paixuArray;
@property (nonatomic,assign)BOOL isEyeTakePhoto;
@property (nonatomic,assign)BOOL isOpen;
@property (nonatomic, strong) NSTimer *shutterTimer;
@property (nonatomic, assign) NSTimeInterval cummulativeTimeInterval;
@property (nonatomic, assign) NSTimeInterval pauseAfterWinkDetectionBeforeShutter;
@property (nonatomic, assign) NSTimeInterval feedbackIntervalWhileWaitingForShutter;
@property (nonatomic, assign) NSTimeInterval minimumWinkDurationForAutomaticOPenEyes;

@property (nonatomic,strong) LY_AudioPalyTool *audioPalyTool;
@end

@implementation FaceRecognitionViewController

#pragma mark - 生命周期

- (void)viewDidLoad {
    [super viewDidLoad];
     self.isGreen = NO;
    
    _isEyeTakePhoto = YES;
   
    self->_feedbackIntervalWhileWaitingForShutter = JGFCameraDefaultFeedbackIntervalWhileWaitingForShutter;//1.0
    self->_pauseAfterWinkDetectionBeforeShutter = JGFCameraDefaultPauseBeforeShutterInterval;//2.0
    self->_minimumWinkDurationForAutomaticTrigger = JGFCameraDefaultMinimumWinkDurationForAutomaticTrigger;//0.3
    self->_minimumWinkDurationForAutomaticOPenEyes = JGFCameraDefaultMinimumWinkDurationForOpenEyes;//0.3
    
    self.session = [[AVCaptureSession alloc] init];
    
    // resolution for the preset
    self.session.sessionPreset = AVCaptureSessionPresetHigh;
    
    // setup video device
    self.videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // setup video input
    NSError *error = nil;
    self.videoInput = [AVCaptureDeviceInput deviceInputWithDevice:[self frontCamera] error:&error];
    if ( [self.session canAddInput:self.videoInput] )
    {
       [self.session addInput:self.videoInput];
        
    }
    
    // setup frame output
    self.frameOutput = [[AVCaptureVideoDataOutput alloc] init];
    if ( [self.session canAddOutput:self.frameOutput] )
    {
        [self.session addOutput:self.frameOutput];
        
    }
    
    dispatch_queue_t queue = dispatch_queue_create("cameraQueue", DISPATCH_QUEUE_SERIAL);
    
//   self.frameOutput.minFrameDuration = CMTimeMake(1, 25);
//    self.videoDevice.activeVideoMinFrameDuration = CMTimeMake(1, 30);
    [self.frameOutput setSampleBufferDelegate:self queue:queue];
    self.frameOutput.videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
                                      nil];
    
    //创建视频预览层，用于实时展示摄像头状态
    _captureVideoPreviewLayer=[[AVCaptureVideoPreviewLayer alloc]initWithSession:self.session];
    
    CALayer *layer=self.ViewContainer.layer;
    layer.masksToBounds=YES;
    
    _captureVideoPreviewLayer.frame=layer.bounds;
    _captureVideoPreviewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;//填充模式
    //将视频预览层添加到界面中
    [layer addSublayer:_captureVideoPreviewLayer];
    
    [self start];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
  
    if ([self.UpStyle isEqualToString:@"1"]) {
        _bottomView.hidden = NO;
        _isEyeTakePhoto = NO;
    }
}

- (void)dealloc{
    if (self.session) {
        
        [self.session stopRunning];
        [self.session removeInput:self.videoInput];
        self.videoInput = nil;
        [self.session removeOutput:self.frameOutput];
        self.frameOutput = nil;
        self.session= nil;
        self.videoDevice= nil;
        //移除localView里面的预览内容
        for(CALayer *layer in _ViewContainer.layer.sublayers){
            
            if ([layer isKindOfClass:[AVCaptureVideoPreviewLayer class]]){
                
                [layer removeFromSuperlayer];
                
                return;
                
            }
            
        }
        _ViewContainer = nil;
    }
}

#pragma mark - 懒加载

- (CIContext *)context
{
    if (!_context) {
        _context = [CIContext contextWithOptions:nil];
    }
    return _context;
}

- (CIDetector *)faceDetector
{
    if (!_faceDetector) {
        // setup the accuracy of the detector
        NSDictionary *detectorOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                         CIDetectorAccuracyHigh, CIDetectorAccuracy, nil];
        
        _faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
    }
    return _faceDetector;
}

- (LY_AudioPalyTool *)audioPalyTool
{
    if (!_audioPalyTool) {
        _audioPalyTool = [LY_AudioPalyTool sharedAudioPaly];
    }
    return _audioPalyTool;
}

#pragma mark - 摄像头配置

//返回前置摄像头
- (AVCaptureDevice *)frontCamera {
    
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
    
}
//返回后置摄像头
- (AVCaptureDevice *)backCamera {
    
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
    
}

//交换摄像头
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition) position {
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices) {
        
        if ([device position] == position) {
            
            return device;
            
        }
        
    }
    
    return nil;
    
}


- (void) shutterCamera
{
    AVCaptureConnection * videoConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    if (!videoConnection) {
        NSLog(@"take photo failed!");
        return;
    }
    
    
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer == NULL) {
            return;
        }
        NSData * imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage * image = [UIImage imageWithData:imageData];
        NSLog(@"image size = %@",NSStringFromCGSize(image.size));
    }];
}


#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
    _image = [self scaleToSize:[self imageFromSampleBuffer:sampleBuffer] size:CGSizeMake(Screen_Width, Screen_Height)];
    
    CIImage* myImage = [CIImage imageWithCGImage:_image.CGImage];
    NSDictionary *options = @{ CIDetectorSmile: [NSNumber numberWithBool:YES], CIDetectorEyeBlink: [NSNumber numberWithBool:YES]};
    NSArray *features = [self.faceDetector featuresInImage:myImage options:options];
    
    _faceFound = false;
    BOOL foundWink = NO;
    BOOL openWink = NO;
    for (CIFaceFeature * face in features) {
        
        if (face.hasLeftEyePosition && face.hasRightEyePosition && face.hasMouthPosition) {
            
            BOOL leftEyeFound = [face hasLeftEyePosition];
            BOOL rightEyeFound = [face hasRightEyePosition];
            
            // 没有眼睛，退出此次循环
            if ( ! leftEyeFound && ! rightEyeFound )
            {
                continue;
            }
            CGPoint maoCenter = CGPointMake((face.leftEyePosition.x + face.rightEyePosition.x) * 0.5,
                                            (face.mouthPosition.y+face.rightEyePosition.y) * 0.5);
            if(CGRectContainsPoint(_maoPoint.frame,maoCenter)){
                _faceFound = true;
                if (_isEyeTakePhoto == YES){
                
                    BOOL leftEyeClosed = [face leftEyeClosed];
                    BOOL rightEyeClosed = [face rightEyeClosed];
                    if ( ! leftEyeClosed && ! rightEyeClosed ){
                        openWink = YES;
                    }else if (face.leftEyeClosed == YES && face.rightEyeClosed == YES ) {
                        
                        foundWink = YES;
                    }else
                    {
                        continue;
                    }
                    
                }
            
            }
           
        }
    }
    
    
    //设置标志变绿
    if (_faceFound==YES) {
        
        [self performSelectorOnMainThread:@selector(displayImage) withObject:nil waitUntilDone:YES];
        if ([self.UpStyle isEqualToString:@"1"]) {
           
        }
        else
            [self performSelectorOnMainThread:@selector(playWithName:) withObject:@"zhayan" waitUntilDone:YES];
        
    }else if (_faceFound==NO){
        
        [self performSelectorOnMainThread:@selector(displayImage2) withObject:nil waitUntilDone:YES];
        if ([self.UpStyle isEqualToString:@"1"]) {
            
        }else
        [self performSelectorOnMainThread:@selector(playWithName:) withObject:@"LightNotice" waitUntilDone:YES];
        
    }
   
    if (![self.UpStyle isEqualToString:@"1"]) {
        //
        if (foundWink)
        {
    
            if ( self.startedDetectingWinkDate == nil )
            {
                self.startedDetectingWinkDate = [NSDate date];
            }
        
            NSDate *now = [NSDate date];
            NSTimeInterval StartTimeDifference = [now timeIntervalSinceDate:self.startedDetectingWinkDate];
          
            NSLog(@"-------StartTime-------- difference: %f", StartTimeDifference);
        
            if ( StartTimeDifference >= self.minimumWinkDurationForAutomaticTrigger)
            {
                
                  self.startedDetectingWinkDate = nil;
                  StartTimeDifference = 0.0;
                _isOpen = YES;
            }
          
        }
        if (openWink) {
            if (_isOpen == NO) {
                return;
            }
            if ( self.endedDetectingWinkDate == nil )
            {
                self.endedDetectingWinkDate = [NSDate date];
            }
            
            NSDate *now2 = [NSDate date];
            NSTimeInterval EndTimeDifference = [now2 timeIntervalSinceDate:self.endedDetectingWinkDate];

            NSLog(@"---------EndTime--------- difference: %f", EndTimeDifference);
            if (EndTimeDifference >= self.minimumWinkDurationForAutomaticOPenEyes) {
                self.endedDetectingWinkDate = nil;
                EndTimeDifference = 0.0;
                [self _scheduleShutterTimer];
            }
        }

    }
}

- (void)playWithName:(NSString *)name
{
    if (self.audioPalyTool.lY_AudioPlayer.rate > 0) {
        return;
    }else{
        [self.audioPalyTool PlayLatterResourceWithName:name];
        [self.audioPalyTool play];
    }
}
- (void)playSeccuseName:(NSString *)name
{
    [self.audioPalyTool PlayLatterResourceWithName:name];
    [self.audioPalyTool play];
}

#pragma mark -  眨眼拍照设置
//开启两秒之后自动拍照
- (void)_scheduleShutterTimer
{
    NSLog(@"保持了眨眼并打开全程动作，开启定时拍照!");
    [self performSelectorOnMainThread:@selector(playSeccuseName:) withObject:@"verygood" waitUntilDone:YES];
    
    [self performSelectorOnMainThread:@selector(displayTipsName:) withObject:@"主人，谢谢您的配合^_^ " waitUntilDone:YES];
    [self stop];
    _finalimage = [self getImageByCuttingImage:_image Rect:CGRectMake(0, 0,_image.size.width, _image.size.height - 88)];
    [self performSelectorOnMainThread:@selector(goUpdataWithImage:) withObject:_finalimage waitUntilDone:YES];
    
}

- (void)_shutterIntervalLapsed:(NSTimer *)timer
{
    self.cummulativeTimeInterval += timer.timeInterval;//1.0
    
    NSTimeInterval timeUntilShutter = ( self.pauseAfterWinkDetectionBeforeShutter - self.cummulativeTimeInterval );//2.0-1.0
    //这时候调是为了减一倒计时
    [self _notifyDelegateOfImpendingShutter:timeUntilShutter];//只会显示1 和 0
    //拍照
    [self takePhotoClick:nil];
}

//让执行倒计时UI动画操作和拍照的UI动画
- (void)_notifyDelegateOfImpendingShutter:(NSTimeInterval)timeUntilShutter
{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self cameraWillShutterIn:timeUntilShutter];
        });
}

//如果时间大于0就执行倒计时UI操作，为0就执行拍照的UI动画操作
- (void)cameraWillShutterIn:(NSTimeInterval)time
{
  
    if ( time > 0 )
    {
        [self _animateRemainingTime:time animationDuration:JGFCameraDefaultFeedbackIntervalWhileWaitingForShutter];
    }
    else if(time <= 0)
    {
        [self _animateShutter];
    }
}


#pragma mark - Animations
//倒计时ui动作
- (void)_animateRemainingTime:(NSTimeInterval)timeInterval animationDuration:(NSTimeInterval)animationDuration
{
    // Build the attributed string
    
    NSString *string = [NSNumberFormatter localizedStringFromNumber:@(timeInterval*10/2) numberStyle:NSNumberFormatterNoStyle]; // Expensive, but W/E. This is a demo.
    
    // White text with a black border, so that we can see it on light and on dark backgrounds.
    NSDictionary *attributes = @{ NSFontAttributeName : [UIFont fontWithName:@"Avenir-Medium" size:144],
                                  (id)kCTForegroundColorAttributeName: (id)[UIColor whiteColor].CGColor,
                                  (id)kCTStrokeWidthAttributeName: @(-1.0),
                                  (id)kCTStrokeColorAttributeName: (id)[UIColor colorWithWhite:0.2 alpha:1.0].CGColor };
    
    NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:string attributes:attributes];
    
    
    
    // Calculate the optimal frame
    CGRect textFrame = CGRectZero;
    textFrame.size = [attributed size];
    textFrame.origin.x = ( CGRectGetWidth( self.view.layer.frame ) - textFrame.size.width ) / 2;
    textFrame.origin.y = ( CGRectGetHeight( self.view.layer.frame ) - textFrame.size.height ) / 2;
    
    // Initialize the text layer
    CATextLayer *textLayer = [[CATextLayer alloc] init];
    textLayer.frame = textFrame;
    textLayer.string = attributed;
    textLayer.opacity = 0;
    [self.view.layer addSublayer:textLayer];
    
    [self _performInAndOutAnimationOnLayer:textLayer duration:animationDuration];
}

//拍照动作
- (void)_animateShutter
{
    CALayer *shutterLayer = [[CALayer alloc] init];
    shutterLayer.frame = self.view.layer.bounds;
    shutterLayer.backgroundColor = [UIColor whiteColor].CGColor;
    shutterLayer.opacity = 0;
    [self.view.layer addSublayer:shutterLayer];
    
    [self _performInAndOutAnimationOnLayer:shutterLayer duration:0.5f];
}

//动画封装
- (void)_performInAndOutAnimationOnLayer:(CALayer *)layer duration:(NSTimeInterval)duration
{
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:NSStringFromSelector(@selector(opacity))];
    animation.duration = duration;
    animation.keyTimes = @[@0, @(duration / 2), @(duration)];
    animation.values = @[@0, @1, @0];
    animation.removedOnCompletion = YES;
    animation.fillMode = kCAFillModeBoth;
    [layer addAnimation:animation forKey:nil];
}



//修改image的大小
- (UIImage *)scaleToSize:(UIImage *)img size:(CGSize)size{
    // 创建一个bitmap的context
    // 并把它设置成为当前正在使用的context
    UIGraphicsBeginImageContext(size);
    // 绘制改变大小的图片
    [img drawInRect:CGRectMake(0, 0, size.width, size.height)];
    // 从当前context中创建一个改变大小后的图片
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    // 使当前的context出堆栈
    UIGraphicsEndImageContext();
    // 返回新的改变大小后的图片
    return scaledImage;
}

- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // 为媒体数据设置一个CMSampleBuffer的Core Video图像缓存对象
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // 锁定pixel buffer的基地址
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // 得到pixel buffer的基地址
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // 得到pixel buffer的行字节数
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // 得到pixel buffer的宽和高
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // 创建一个依赖于设备的RGB颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // 用抽样缓存的数据创建一个位图格式的图形上下文（graphics context）对象
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // 根据这个位图context中的像素数据创建一个Quartz image对象
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // 解锁pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    //释放context和颜色空间
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // 用Quartz image创建一个UIImage对象image
    //UIImage *image = [UIImage imageWithCGImage:quartzImage];
    UIImage *image = [UIImage imageWithCGImage:quartzImage scale:1.0f orientation:UIImageOrientationRight];
    
    // 释放Quartz image对象
    CGImageRelease(quartzImage);
    
    return (image);
    
}


//裁剪图片的指定区域
- ( UIImage *)getImageByCuttingImage:( UIImage *)image Rect:( CGRect )rect{
    
    // 定义 myImageRect ，截图的区域
    CGRect myImageRect = rect;
    
    UIImage * bigImage= image;
    
    CGImageRef imageRef = bigImage. CGImage ;
    
    CGImageRef subImageRef = CGImageCreateWithImageInRect (imageRef, myImageRect);
    
    CGSize size;
    
    size. width = rect. size . width ;
    
    size. height = rect. size . height ;
    
    UIGraphicsBeginImageContext (size);
    
    CGContextRef context = UIGraphicsGetCurrentContext ();
    
    CGContextDrawImage (context, myImageRect, subImageRef);
    
    UIImage * smallImage = [ UIImage imageWithCGImage :subImageRef];
    
    CGImageRelease(subImageRef);
    UIGraphicsEndImageContext ();
    
    return smallImage;
    
}

#pragma mark - 人脸识别请求
- (void)goUpdataWithImage:(UIImage *)image
{

}

#pragma mark - expendAbleAlartViewDelegate提示框代理
- (void)negativeButtonAction
{
    NSLog(@"negative Action");
    [self recoverySetting];
}

- (void)positiveButtonAction
{
    NSLog(@"positive Action");
    [self goBack];
}

- (void)closeButtonAction
{
    NSLog(@"close Action");
     [self recoverySetting];
}

-(void)displayImage{
    _spideImage.image= [UIImage imageNamed:@"photo-facebox-green"];
    self.isGreen = YES;
    if ([self.UpStyle isEqualToString:@"1"]) {
    _tipsLab.text = @"主人，已经是最佳视角啦！ ^_^ ^_^";
    }else
    _tipsLab.text = @"主人，要闭上眼睛，慢慢睁开才行哦 ^_^ ^_^";
    
}

-(void)displayImage2{
    _spideImage.image= [UIImage imageNamed:@"photo-facebox-red"];
     self.isGreen = NO;
    _tipsLab.text = @"主人，请把脸正对相机";
}

-(void)displayTipsName:(NSString *)tipsname{
    
    _tipsLab.text = tipsname;
}


#pragma mark - 拍照

- (IBAction)takePhotoClick:(id)sender {
    
    if ([self.UpStyle isEqualToString:@"1"]) {
        self.takePhotoBtn.hidden = YES;
        [self stop];
        _finalimage = [self getImageByCuttingImage:_image Rect:CGRectMake(0, 0,_image.size.width, _image.size.height-88)];
        
    }else{
    //如果累加到2.0>=2.0 进来的的时候才会执行，其他的时候进来什么都不执行
        if ( self.cummulativeTimeInterval >= self.pauseAfterWinkDetectionBeforeShutter )
        {
            //销毁定时器
            [self.shutterTimer invalidate];
            self.shutterTimer = nil;
            self.cummulativeTimeInterval = 0;

            [self stop];
            
            _finalimage = [self getImageByCuttingImage:_image Rect:CGRectMake(0, 0,_image.size.width, _image.size.height-88)];
            
            _finalImageV.hidden = NO;
            _finalImageV.image = _image;
            [self goUpdataWithImage:_finalimage];
        }
    }
}

- (void)aotutakePhoto
{
    
    [self performSelector:@selector(takePhotoClick:) withObject:nil afterDelay:0.5];
}


#pragma mark - 复原拍照设置
- (void)recoverySetting
{
    self.takePhotoBtn.hidden = NO;
    [self start];
}

#pragma mark - Start and Stop Running

- (void)start
{
    if (![self.session isRunning]){
        [self.session startRunning];
         _isOpen = NO;//确保是打开又重新启动眼睛open的动作标识
        _spideImage.hidden = NO;
        _finalImageV.hidden = YES;
    }
}

- (void)stop
{
    if ( [self.session isRunning] ){
        _spideImage.hidden = YES;
        [self.session stopRunning];
    }
}


#pragma mark - 返回

- (void)goBack
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
