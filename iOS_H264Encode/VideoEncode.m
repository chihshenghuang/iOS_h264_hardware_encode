//
//  VideoEncode.m
//  iOS_H264Encode
//
//  Created by pedoe on 4/14/16.
//  Copyright © 2016 NTU. All rights reserved.
//

#import "VideoEncode.h"

@interface VideoEncode()

void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,CMSampleBufferRef sampleBuffer );

@end

@implementation VideoEncode
{
    NSString *error;
    VTCompressionSessionRef encodeSession;
    dispatch_queue_t encodeQueue;
    CMFormatDescriptionRef format;
    BOOL initialized;
    int frameCount;
    NSData *sps;
    NSData *pps;
}

- (id)init
{
    self = [super init];
    if(self) {
        
        //NSLog(@"H264VideoEncode init");
        [self initVariables];
    }
    return self;
}

- (void)initVariables
{
    encodeSession = nil;
    initialized = true;
    encodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    frameCount = 0;
    sps = NULL;
    pps = NULL;
}


void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,CMSampleBufferRef sampleBuffer )
{
    //NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) {
        // for debug
        assert(status == 0);
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        //NSLog(@"didCompressH264 data is not ready");
    }
    
    VideoEncode *THIS = (__bridge VideoEncode*)outputCallbackRefCon;
    
    //Check if we have got a key frame first
    bool keyframe = !CFDictionaryContainsKey((CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    if (keyframe) {
        
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        // CFDictionaryRef extensionDict = CMFormatDescriptionGetExtensions(format);
        // Get the extensions
        // From the extensions get the dictionary with key "SampleDescriptionExtensionAtoms"
        // From the dict, get the value for the key "avcC"
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,
                                                                                 0,
                                                                                 &sparameterSet,
                                                                                 &sparameterSetSize,
                                                                                 &sparameterSetCount, 0);
        
        if (statusCode == noErr) {
            
            assert(status == 0);
            
            // Found sps and now check the pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format,
                                                                                     1,
                                                                                     &pparameterSet,
                                                                                     &pparameterSetSize,
                                                                                     &pparameterSetCount, 0);
            if (statusCode == noErr) {
                
                assert(status == 0);
                
                // Found pps
                THIS->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                THIS->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                
                if (THIS->_delegate) {
                    [THIS->_delegate gotSpsPps:THIS->sps pps:THIS->pps];
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        assert(statusCodeRet == 0);
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // Convert the length value from Big-endian to Little-endian
            // After converting the length value, the start 4 byte will present the NALUnitLength
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData *data = [[NSData alloc]initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            
            if (THIS->_delegate) {
                [THIS->_delegate gotEncodedData:data isKeyFrame:keyframe];
            }
            
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}


- (void)initEncode:(int)width height:(int)height
{
    dispatch_sync(encodeQueue, ^{
        // For testing out the logic, lets read from a file and then send it to encoder to create h264 stream
        
        // Create the compression session
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self), &encodeSession);
        
        NSLog(@"H264: VTCompressionSessionCreate %d", (int)status);
        
        if (status != 0) {
            NSLog(@"H264: Unable to create H264 session");
            error = @"H264: Unable to create H264 session";
            
            return;
        }
        
        // Set the properties
        VTSessionSetProperty(encodeSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(encodeSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFNumberRef)@(10.0)); // change the frame number between 2 I frame
        VTSessionSetProperty(encodeSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
    
        // Tell the encoder to start encoding
        VTCompressionSessionPrepareToEncodeFrames(encodeSession);
    });
}


- (void)encode:(CMSampleBufferRef)sampleBuffer
{
    dispatch_sync(encodeQueue, ^{
        frameCount++;
        // Get the CV Image buffer
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        
        // Create properties
        CMTime presentationTimeStamp = CMTimeMake(frameCount, 1000);
        //CMTime duration = CMTimeMake(1, DURATION);
        VTEncodeInfoFlags flags;
        
        // Pass it to the encoder
        OSStatus statusCode = VTCompressionSessionEncodeFrame(encodeSession,
                                                              imageBuffer,
                                                              presentationTimeStamp,
                                                              kCMTimeInvalid,
                                                              NULL, NULL, &flags);
        
        // Check for error
        if (statusCode != noErr) {
            
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            error = @"H264: VTCompressionSessionEncodeFrame failed ";
            
            // End the session
            VTCompressionSessionInvalidate(encodeSession);
            CFRelease(encodeSession);
            encodeSession = NULL;
            error = NULL;
            return;
        }
        NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
    });

}

@end