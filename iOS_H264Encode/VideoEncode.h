//
//  VideoEncode.h
//  iOS_H264Encode
//
//  Created by pedoe on 4/14/16.
//  Copyright © 2016 NTU. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

@protocol H264HwEncoderDelegate <NSObject>

- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps;
- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame;

@end

@interface VideoEncode : NSObject
- (void) initEncode:(int)width  height:(int)height;
- (void) encode:(CMSampleBufferRef )sampleBuffer;

@property (weak, nonatomic) id<H264HwEncoderDelegate> delegate;

@end
