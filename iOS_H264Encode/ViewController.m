//
//  ViewController.m
//  iOS_H264Encode
//
//  Created by pedoe on 4/14/16.
//  Copyright © 2016 NTU. All rights reserved.
//

#import "ViewController.h"
#import "VideoEncode.h"
@interface ViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate, H264HwEncoderDelegate>
{
    AVCaptureSession *captureSession;
    AVCaptureVideoPreviewLayer *previewLayer;
    AVCaptureConnection *connection;
    bool isStart;
    VideoEncode *videoEncode;
    NSFileHandle *fileHandle;
    NSString *h264File;
}
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    isStart = true;
    videoEncode = [[VideoEncode alloc]init];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)actionStartStop:(id)sender {
    if (isStart) {
        [self startCamera];
        isStart = false;
        [_startButton setTitle:@"Stop" forState:UIControlStateNormal];
    }
    else
    {
        isStart = true;
        [self stopCamera];
        [_startButton setTitle:@"Start" forState:UIControlStateNormal];
        
    }

}

- (void)startCamera
{
    // make input device
    NSError *deviceError;
    AVCaptureDeviceInput *inputDevice;
    for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        //if ([device position] == AVCaptureDevicePositionBack) {
        if ([device position] == AVCaptureDevicePositionFront) {
            inputDevice = [AVCaptureDeviceInput deviceInputWithDevice:device error:&deviceError];
        }
    }
    
    // make output device
    AVCaptureVideoDataOutput *outputDevice = [[AVCaptureVideoDataOutput alloc]init];
    NSString *key = (NSString *)kCVPixelBufferPixelFormatTypeKey;
    
    NSNumber *val = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:val forKey:key];
    outputDevice.videoSettings = videoSettings;
    [outputDevice setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    // initialize capture session
    captureSession = [[AVCaptureSession alloc]init];
    [captureSession addInput:inputDevice];
    [captureSession addOutput:outputDevice];
    
    // begin configuration for the AVCaptureSession
    [captureSession beginConfiguration];
    captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    connection = [outputDevice connectionWithMediaType:AVMediaTypeVideo];
    [captureSession commitConfiguration];
    
    // make preview layer and add so that camera's view is displayed on screen
    previewLayer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:captureSession];
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.myView.layer addSublayer:previewLayer];
    previewLayer.frame = self.myView.bounds;
    
    [captureSession startRunning];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    h264File = [documentsDirectory stringByAppendingPathComponent:@"myH264.h264"];
    [fileManager removeItemAtPath:h264File error:nil];
    [fileManager createFileAtPath:h264File contents:nil attributes:nil];

    fileHandle = [NSFileHandle fileHandleForWritingAtPath:h264File];
    
    [videoEncode initEncode:640 height:480];
    videoEncode.delegate = self;
}

- (void)stopCamera
{
    [captureSession stopRunning];
}

-(void) captureOutput:(AVCaptureOutput*)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection
{
    [videoEncode encode:sampleBuffer];
}

#pragma mark -  H264HwEncoderDelegate Implement
- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    NSLog(@"gotSpsPps %d %d", (int)[sps length], (int)[pps length]);

    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:sps];
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:pps];
    
}
- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    NSLog(@"gotEncodedData %d", (int)[data length]);
  
    if (fileHandle != NULL)
    {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
      
        [fileHandle writeData:ByteHeader];
        [fileHandle writeData:data];
    }
}


@end
