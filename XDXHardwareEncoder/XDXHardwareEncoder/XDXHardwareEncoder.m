//
//  XDXHardwareEncoder.m
//  XDXHardwareEncoder
//
//  Created by 小东邪 on 09/11/2017.
//  Copyright © 2017 小东邪. All rights reserved.
//

#import "XDXHardwareEncoder.h"
#import <UIKit/UIKit.h>
#import "sys/utsname.h"
#import <CoreMedia/CoreMedia.h>

#define XDXResolutionW 720
#define XDXResolutionH 1280
#define XDXFPS         30
#define XDXBitrate     1000

bool g_isSupportRealTimeEncoder = false;
Float64 g_vstarttime = 0.0;
uint32_t g_tvustartcaptureTime = 0;

static const size_t  startCodeLength = 4;
static const uint8_t startCode[]     = {0x00, 0x00, 0x00, 0x01};

typedef enum{
    Key_ExpectedFrameRate = 0,
    Key_RealTime,
    Key_ProfileLevel,
    Key_H264EntropyMode,
    Key_DataRateLimits,
    Key_MaxKeyFrameIntervalDuration,
    Key_AllowFrameReordering,
    Key_AverageBitRate,
    Key_PropertyCount,
}XDX_Encoder_Property_Key;

@interface XDXHardwareEncoder()
{
    BOOL                    initializedH264;
    BOOL                    initializedH265;
    NSLock                  *m_h264_lock;
    NSLock                  *m_h265_lock;
    VTCompressionSessionRef h264CompressionSession;
    VTCompressionSessionRef h265CompressionSession;
    FILE                    *_videoFile;   // save temporary asf file
    NSMutableArray          *bitrates;
    int                     frameID;
    float                   lastTime;
}

@property (assign, nonatomic) int width;
@property (assign, nonatomic) int height;
@property (assign, nonatomic) int fps;
@property (assign, nonatomic) int bitrate;//bps

@property (nonatomic, strong) NSArray *h264propertyFlags;
@property (nonatomic, strong) NSArray *h265PropertyFlags;

@property (nonatomic, assign) BOOL    deviceSupportH265;
@property (nonatomic, assign) int     h264ErrCount;
@property (nonatomic, assign) int     h265ErrCount;


@end

@implementation XDXHardwareEncoder

static XDXHardwareEncoder *m_encoder = NULL;
void   printfBuffer(uint8_t* buf, int size, char* name);
void   writeFile(uint8_t *buf, int size, FILE *videoFile, int frameCount);

#pragma mark H264 Callback
static void vtCallBack(void *outputCallbackRefCon,void *souceFrameRefCon,OSStatus status,VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    XDXHardwareEncoder *encoder = (__bridge XDXHardwareEncoder*)outputCallbackRefCon;
    if(status != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"H264: vtCallBack failed with %@", error);
        NSLog(@"XDXHardwareEncoder : encode frame failured! %s" ,error.debugDescription.UTF8String);
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH265 data is not ready ");
        return;
    }
    if (infoFlags == kVTEncodeInfo_FrameDropped) {
        NSLog(@"%s with frame dropped.", __FUNCTION__);
        return;
    }
    
    CMBlockBufferRef block = CMSampleBufferGetDataBuffer(sampleBuffer);
    BOOL isKeyframe = false;

    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);

    if(attachments != NULL) {
        CFDictionaryRef attachment =(CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFBooleanRef dependsOnOthers = (CFBooleanRef)CFDictionaryGetValue(attachment, kCMSampleAttachmentKey_DependsOnOthers);
        isKeyframe = (dependsOnOthers == kCFBooleanFalse);
    }

    if(isKeyframe) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        static uint8_t *spsppsNALBuff = NULL;
        static size_t  spsSize, ppsSize;

            size_t parmCount;
            const uint8_t*sps, *pps;
            int NALUnitHeaderLengthOut;
            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sps, &spsSize, &parmCount, &NALUnitHeaderLengthOut );
            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pps, &ppsSize, &parmCount, &NALUnitHeaderLengthOut );

            spsppsNALBuff = (uint8_t*)malloc(spsSize+4+ppsSize+4);
            memcpy(spsppsNALBuff, "\x00\x00\x00\x01", 4);
            memcpy(&spsppsNALBuff[4], sps, spsSize);
            memcpy(&spsppsNALBuff[4+spsSize], "\x00\x00\x00\x01", 4);
            memcpy(&spsppsNALBuff[4+spsSize+4], pps, ppsSize);
            NSLog(@"XDXHardwareEncoder : H264 spsSize : %zu, ppsSize : %zu",spsSize, ppsSize);
         writeFile(spsppsNALBuff,spsSize+4+ppsSize+4,encoder->_videoFile, 200);
    }

    size_t blockBufferLength;
    uint8_t *bufferDataPointer = NULL;
    CMBlockBufferGetDataPointer(block, 0, NULL, &blockBufferLength, (char **)&bufferDataPointer);

    size_t bufferOffset = 0;
    while (bufferOffset < blockBufferLength - startCodeLength) {
        uint32_t NALUnitLength = 0;
        memcpy(&NALUnitLength, bufferDataPointer+bufferOffset, startCodeLength);
        NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
        memcpy(bufferDataPointer+bufferOffset, startCode, startCodeLength);
        bufferOffset += startCodeLength + NALUnitLength;
    }
    writeFile(bufferDataPointer, blockBufferLength,encoder->_videoFile, 200);
}

#pragma mark H265 Callback
static void vtH265CallBack(void *outputCallbackRefCon,void *souceFrameRefCon,OSStatus status,VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    XDXHardwareEncoder *encoder = (__bridge XDXHardwareEncoder*)outputCallbackRefCon;
    if(status != noErr) {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        NSLog(@"H264: H265 vtH265CallBack failed with %@", error);
        NSLog(@"XDXHardwareEncoder : H265 encode frame failured! %s" ,error.debugDescription.UTF8String);
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH265 data is not ready ");
        return;
    }
    if (infoFlags == kVTEncodeInfo_FrameDropped) {
        NSLog(@"%s with frame dropped.", __FUNCTION__);
        return;
    }

    CMBlockBufferRef block = CMSampleBufferGetDataBuffer(sampleBuffer);
    BOOL isKeyframe = false;

    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);

    if(attachments != NULL) {
        CFDictionaryRef attachment =(CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFBooleanRef dependsOnOthers = (CFBooleanRef)CFDictionaryGetValue(attachment, kCMSampleAttachmentKey_DependsOnOthers);
        isKeyframe = (dependsOnOthers == kCFBooleanFalse);
    }

    if(isKeyframe) {
        CMFormatDescriptionRef format     = CMSampleBufferGetFormatDescription(sampleBuffer);
        static uint8_t *vpsspsppsNALBuff  = NULL;
        static size_t  vpsSize, spsSize, ppsSize;
            size_t parmCount;
            const uint8_t *vps, *sps, *pps;

            if (encoder.deviceSupportH265) {       // >= iPhone 7 && support ios11
                CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, 0, &vps, &vpsSize, &parmCount, 0);
                CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, 1, &sps, &spsSize, &parmCount, 0);
                CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(format, 2, &pps, &ppsSize, &parmCount, 0);

                vpsspsppsNALBuff = (uint8_t*)malloc(vpsSize+4+spsSize+4+ppsSize+4);
                memcpy(vpsspsppsNALBuff, "\x00\x00\x00\x01", 4);
                memcpy(&vpsspsppsNALBuff[4], vps, vpsSize);
                memcpy(&vpsspsppsNALBuff[4+vpsSize], "\x00\x00\x00\x01", 4);
                memcpy(&vpsspsppsNALBuff[4+vpsSize+4], sps, spsSize);
                memcpy(&vpsspsppsNALBuff[4+vpsSize+4+spsSize], "\x00\x00\x00\x01", 4);
                memcpy(&vpsspsppsNALBuff[4+vpsSize+4+spsSize+4], pps, ppsSize);
                NSLog(@"XDXHardwareEncoder : H265 vpsSize : %zu, spsSize : %zu, ppsSize : %zu",vpsSize,spsSize, ppsSize);
            }
             writeFile(vpsspsppsNALBuff, vpsSize+4+spsSize+4+ppsSize+4,encoder->_videoFile, 200);
    }

    size_t   blockBufferLength;
    uint8_t  *bufferDataPointer = NULL;
    CMBlockBufferGetDataPointer(block, 0, NULL, &blockBufferLength, (char **)&bufferDataPointer);

    size_t bufferOffset = 0;
    while (bufferOffset < blockBufferLength - startCodeLength) {
        uint32_t NALUnitLength = 0;
        memcpy(&NALUnitLength, bufferDataPointer+bufferOffset, startCodeLength);
        NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
        memcpy(bufferDataPointer+bufferOffset, startCode, startCodeLength);
        bufferOffset += startCodeLength + NALUnitLength;
    }

     writeFile(bufferDataPointer, blockBufferLength,encoder->_videoFile, 200);
}

#pragma mark  Print Buffer Content And Write File
void printfBuffer(uint8_t* buf, int size, char* name) {
    int i = 0;
    printf("%s:", name);
    for(i = 0; i < size; i++){
        printf("%02x,", buf[i]);
    }
    printf("\n");
}

void writeFile(uint8_t *buf, int size, FILE *videoFile, int frameCount) {
    static int count = 0;
    count++;
    
    if (frameCount == 0) {
        fwrite(buf, 1, size, videoFile);
        return;
    }
    
    if (count <  frameCount) fwrite(buf, 1, size, videoFile);
    if (count == frameCount) fclose(videoFile);
}


#pragma mark - Init
- (instancetype)init {
    NSLog(@"XDXHardwareEncoder : Init hardware encoder");
    self = [super init];
    if(self) {
        _width   = XDXResolutionW;
        _height  = XDXResolutionH;
        _fps     = XDXFPS;
        _bitrate = XDXBitrate << 10;//convert to bps
        frameID  = 0;
        
        _h264propertyFlags      = NULL;
        h264CompressionSession  = NULL;
        m_h264_lock             = [[NSLock alloc] init];
        initializedH264         = false;
        
        h265CompressionSession  = NULL;
        _h265PropertyFlags      = NULL;
        m_h265_lock             = [[NSLock alloc] init];
        initializedH265         = false;
        

        int is64Bit = sizeof(int*);
        g_isSupportRealTimeEncoder = (is64Bit == 8) ? true : false;
        
//        bitrates  = [[NSMutableArray alloc] init];

        if (@available(iOS 11.0, *)) {
            BOOL hardwareDecodeSupported = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC);
            if (hardwareDecodeSupported) {
                _deviceSupportH265 = YES;
                NSLog(@"XDXHardwareEncoder : Support H265 Encode/Decode!");
            }
        }else {
            _deviceSupportH265 = NO;
            NSLog(@"XDXHardwareEncoder : Not support H265 Encode/Decode!");
        }

        [self initSaveVideoFile];
    }
    return self;
}

- (void)initSaveVideoFile{
    // write file
    NSString *path               = (NSString *)[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *savePath           = [path stringByAppendingString:@"/test0.asf"];
    NSFileManager *fileManager   = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:savePath error:nil];
    if( (_videoFile = fopen([savePath UTF8String], "w+")) == NULL ){
        perror("XDXHardwareEncoder File error");
    }
}

- (OSStatus)setSessionProperty:(VTCompressionSessionRef)session key:(CFStringRef)key value:(CFTypeRef)value {
    OSStatus status = VTSessionSetProperty(session, key, value);
    if (status != noErr)  {
        NSString *sessionStr;
        if (session == h264CompressionSession) {
            sessionStr = @"h264 Session";
            self.h264ErrCount++;
        }else if (session == h265CompressionSession) {
            sessionStr = @"h265 Session";
            self.h265ErrCount++;
        }
        NSLog(@"XDXHardwareEncoder : Set %s of %s Failed, status = %d",CFStringGetCStringPtr(key, kCFStringEncodingUTF8),sessionStr.UTF8String,status);
    }
    return status;
}

- (BOOL)isSupportPropertyWithKey:(XDX_Encoder_Property_Key)key inArray:(NSArray *)array {
    return [[array objectAtIndex:key] intValue];
}

- (void)applyAllSessionProperty:(VTCompressionSessionRef)session propertyArr:(NSArray *)propertyArr {
    OSStatus status;
    if(!g_isSupportRealTimeEncoder) {
        /* increase max frame delay from 3 to 6 to reduce encoder pressure*/
        int         value = 3;
        CFNumberRef ref   = CFNumberCreate(NULL, kCFNumberSInt32Type, &value);
        [self setSessionProperty:session key:kVTCompressionPropertyKey_MaxFrameDelayCount value:ref];
        CFRelease(ref);
    }
    
    if(self.fps) {
        if([self isSupportPropertyWithKey:Key_ExpectedFrameRate inArray:propertyArr]) {
            int         value = self.fps;
            CFNumberRef ref   = CFNumberCreate(NULL, kCFNumberSInt32Type, &value);
            [self setSessionProperty:session key:kVTCompressionPropertyKey_ExpectedFrameRate value:ref];
            CFRelease(ref);
        }
    }else {
        NSLog(@"XDXHardwareEncoder : Current fps is 0");
    }
    
    if(self.bitrate) {
        if([self isSupportPropertyWithKey:Key_AverageBitRate inArray:propertyArr]) {
            int value = self.bitrate;
            if (session == h265CompressionSession) value = 2*1000;  // if current session is h265, Set birate 2M.
            CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &value);
            [self setSessionProperty:session key:kVTCompressionPropertyKey_AverageBitRate value:ref];
            CFRelease(ref);
        }
    }else {
        NSLog(@"XDXHardwareEncoder : Current bitrate is 0");
    }
    
    /*2016-11-15,@gang, iphone7/7plus do not support realtime encoding, so disable it
     otherwize ,we can not control encoding bit rate
     */
    if (![[self deviceVersion] isEqualToString:@"iPhone9,1"] && ![[self deviceVersion] isEqualToString:@"iPhone9,2"]) {
        if(g_isSupportRealTimeEncoder) {
            if([self isSupportPropertyWithKey:Key_RealTime inArray:propertyArr]) {
                NSLog(@"use RealTimeEncoder");
                NSLog(@"XDXHardwareEncoder : use realTimeEncoder");
                [self setSessionProperty:session key:kVTCompressionPropertyKey_RealTime value:kCFBooleanTrue];
            }
        }
    }
    
    if([self isSupportPropertyWithKey:Key_AllowFrameReordering inArray:propertyArr]) {
        [self setSessionProperty:session key:kVTCompressionPropertyKey_AllowFrameReordering value:kCFBooleanFalse];
    }
    
    if(g_isSupportRealTimeEncoder) {
        if([self isSupportPropertyWithKey:Key_ProfileLevel inArray:propertyArr]) {
            [self setSessionProperty:session key:kVTCompressionPropertyKey_ProfileLevel value:self.enableH264 ? kVTProfileLevel_H264_Main_AutoLevel : kVTProfileLevel_HEVC_Main_AutoLevel];
        }
    }else {
        if([self isSupportPropertyWithKey:Key_ProfileLevel inArray:propertyArr]) {
            [self setSessionProperty:session key:kVTCompressionPropertyKey_ProfileLevel value:self.enableH264 ? kVTProfileLevel_H264_Baseline_AutoLevel : kVTProfileLevel_HEVC_Main_AutoLevel];
        }
        
        if (self.enableH264) {
            if([self isSupportPropertyWithKey:Key_H264EntropyMode inArray:propertyArr]) {
                [self setSessionProperty:session key:kVTCompressionPropertyKey_H264EntropyMode value:kVTH264EntropyMode_CAVLC];
            }
        }
    }
    
    if([self isSupportPropertyWithKey:Key_MaxKeyFrameIntervalDuration inArray:propertyArr]) {
        int         value   = 1;
        CFNumberRef ref     = CFNumberCreate(NULL, kCFNumberSInt32Type, &value);
        [self setSessionProperty:session key:kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration value:ref];
        CFRelease(ref);
    }
}

#pragma mark - Main Function
+ (instancetype)getInstance {
    @synchronized(self) {
        if(m_encoder == NULL) {
            m_encoder = [[XDXHardwareEncoder alloc] init];
        }
        return m_encoder;
    }
}

- (void)prepareForEncode {
    
    if (self.enableH265) {
        if (@available(iOS 11.0, *)) {
            BOOL hardwareDecodeSupported = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC);
            if (hardwareDecodeSupported) {
                NSLog(@"Support H265 Encode/Decode!");
            }else {
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"当前设备不支持H265直播" message:nil preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:NULL]];
                UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
                [rootViewController presentViewController:alertController animated:YES completion:nil];
                return;
            }
        }else {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"H265直播仅在iOS 11以上支持" message:nil preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:NULL]];
            UIViewController *rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
            [rootViewController presentViewController:alertController animated:YES completion:nil];
            return;
        }
    }
    
    if(self.width == 0 || self.height == 0) {
        NSLog(@"XDXHardwareEncoder : VTSession need with and height for init,with = %d,height = %d",self.width, self.height);
        return;
    }
    
    if(g_isSupportRealTimeEncoder)  NSLog(@"XDXHardwareEncoder : Device processor is 64 bit");
    else                            NSLog(@"XDXHardwareEncoder : Device processor is not 64 bit");
    
    NSLog(@"XDXHardwareEncoder : Current h264 open state : %d, h265 open state : %d",self.enableH264, self.enableH265);
    
    OSStatus h264Status,h265Status;
    BOOL isRestart = NO;
    if (self.enableH264) {
        if (h264CompressionSession != NULL) {
            NSLog(@"XDXHardwareEncoder : H264 session not NULL");
            return;
        }
        [m_h264_lock lock];
        NSLog(@"XDXHardwareEncoder : Prepare H264 hardware encoder");
        
        //[self.delegate willEncoderStart];
        
        self.h264ErrCount = 0;
        
        h264Status = VTCompressionSessionCreate(NULL, self.width, self.height, kCMVideoCodecType_H264, NULL, NULL, NULL, vtCallBack,(__bridge void *)self, &h264CompressionSession);
        if (h264Status != noErr) {
            self.h265ErrCount++;
            NSLog(@"XDXHardwareEncoder : H264 VTCompressionSessionCreate Failed, status = %d",h264Status);
        }
        [self getSupportedPropertyFlags];
        
        [self applyAllSessionProperty:h264CompressionSession propertyArr:self.h264propertyFlags];
        
        h264Status = VTCompressionSessionPrepareToEncodeFrames(h264CompressionSession);
        if(h264Status != noErr) {
            NSLog(@"XDXHardwareEncoder : H264 VTCompressionSessionPrepareToEncodeFrames Failed, status = %d",h264Status);
        }else {
            initializedH264     = true;
            NSLog(@"XDXHardwareEncoder : H264 VTSession create success, with = %d, height = %d, framerate = %d",self.width,self.height,self.fps);
        }
        if(h264Status != noErr && self.h264ErrCount != 0) isRestart = YES;
        [m_h264_lock unlock];
    }
    
    if (self.enableH265) {
        if (h265CompressionSession != NULL) {
            NSLog(@"XDXHardwareEncoder : H265 session not NULL");
            return;
        }
        [m_h265_lock lock];
        NSLog(@"XDXHardwareEncoder : Prepare h265 hardware encoder");
        // [self.delegate willEncoderStart];
        
        self.h265ErrCount = 0;
        
        h265Status = VTCompressionSessionCreate(NULL, self.width, self.height, kCMVideoCodecType_HEVC, NULL, NULL, NULL, vtH265CallBack,(__bridge void *)self, &h265CompressionSession);
        if (h265Status != noErr) {
            self.h265ErrCount++;
            NSLog(@"XDXHardwareEncoder : H265 VTCompressionSessionCreate Failed, status = %d",h265Status);
        }
        
        [self getSupportedPropertyFlags];
        
        [self applyAllSessionProperty:h265CompressionSession propertyArr:self.h265PropertyFlags];
        
        h265Status = VTCompressionSessionPrepareToEncodeFrames(h265CompressionSession);
        if(h265Status != noErr) {
            NSLog(@"XDXHardwareEncoder : H265 VTCompressionSessionPrepareToEncodeFrames Failed, status = %d",h265Status);
        }else {
            initializedH265     = true;
            NSLog(@"XDXHardwareEncoder : H265 VTSession create success, with = %d, height = %d, framerate = %d",self.width,self.height,self.fps);
        }
        if(h265Status != noErr && self.h265ErrCount != 0) isRestart = YES;
        [m_h265_lock unlock];
    }
    
    if (isRestart) {
        NSLog(@"XDXHardwareEncoder : VTSession create failured!");
            static int count = 0;
            count ++;
            if (count == 3) {
                NSLog(@"TVUEncoder ： restart 5 times failured! exit!");
                return;
            }
            sleep(1);
            NSLog(@"TVUEncoder ： try to restart after 1 second!");
            NSLog(@"TVUEncoder ： vtsession error occured!,resetart encoder width: %d, height %d, times %d",self.width,self.height,count);
            [self tearDownSession];
            [self prepareForEncode];
    }
}

-(void)startWithWidth:(int)width andHeight:(int)height andFPS:(int)fps {
    if(_fps != fps) {
        _fps = fps;
        NSLog(@"TVUEncoder ： Encoder fps changed (%d -> %d)",fps,self.fps);
        
        int value = self.fps;
        CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &value);
        if (self.enableH264) {
            [m_h264_lock lock];
            if (self.fps) {
                if ([self isSupportPropertyWithKey:Key_ExpectedFrameRate inArray:self.h264propertyFlags]) {
                    OSStatus status = [self setSessionProperty:h264CompressionSession key:kVTCompressionPropertyKey_ExpectedFrameRate value:ref];
                    if(status != noErr) NSLog(@"TVUEncoder ： h264 encoder fps changed error!(%d -> %d)",fps,self.fps);
                }
            }
            [m_h264_lock unlock];
        }
        
        if (self.enableH265) {
            [m_h265_lock lock];
            if (self.fps) {
                if ([self isSupportPropertyWithKey:Key_ExpectedFrameRate inArray:self.h264propertyFlags]) {
                    OSStatus status = [self setSessionProperty:h265CompressionSession key:kVTCompressionPropertyKey_ExpectedFrameRate value:ref];
                    if(status != noErr) NSLog(@"TVUEncoder ： h265 encoder fps changed error!(%d -> %d)",fps,self.fps);
                }
            }
            [m_h265_lock unlock];
        }
    }
    
    if(_width != width || _height != height) {
        _width  = width;
        _height = height;
        NSLog(@"TVUEncoder ： resetart h264 encoder width: %d, height %d",self.width,self.height);
        [self tearDownSession];
        [self prepareForEncode];
    }
    
    NSLog(@"TVUEncoder ： send Format Input resolution(%d,%d),fps(%d)",self.width,self.height,self.fps);
}

-(void)encode:(CMSampleBufferRef)sampleBuffer {
    if (self.enableH264) {
        [m_h264_lock lock];
        if(h264CompressionSession == NULL) {
            [m_h264_lock unlock];
            return;
        }
        
        if(initializedH264 == false) {
            NSLog(@"TVUEncoder : h264 encoder is not ready\n");
            return;
        }
    }
    
    if (self.enableH265) {
        [m_h265_lock lock];
        if(h265CompressionSession == NULL) {
            [m_h265_lock unlock];
            return;
        }
        
        if(initializedH265 == false) {
            NSLog(@"TVUEncoder : h265 encoder is not ready\n");
            return;
        }
    }
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CMTime duration = CMSampleBufferGetOutputDuration(sampleBuffer);
    frameID++;
    CMTime presentationTimeStamp = CMTimeMake(frameID, 1000);
    

    
    [self doSetBitrate];
    
    OSStatus status;
    VTEncodeInfoFlags flags;
    if (self.enableH264) {
        status = VTCompressionSessionEncodeFrame(h264CompressionSession, imageBuffer, presentationTimeStamp, duration, NULL, imageBuffer, &flags);
        if(status != noErr) NSLog(@"TVUEncoder : H264 VTCompressionSessionEncodeFrame failed");
        [m_h264_lock unlock];
        
        if (status != noErr) {
            NSLog(@"TVUEncoder : VTCompressionSessionEncodeFrame failed");
            VTCompressionSessionCompleteFrames(h264CompressionSession, kCMTimeInvalid);
            VTCompressionSessionInvalidate(h264CompressionSession);
            CFRelease(h264CompressionSession);
            h264CompressionSession = NULL;
        }else {
            // NSLog(@"TVUEncoder : Success VTCompressionSessionCompleteFrames");
        }
    }
    
    
    
    if (self.enableH265) {
        status = VTCompressionSessionEncodeFrame(h265CompressionSession, imageBuffer, presentationTimeStamp, duration, NULL, imageBuffer, &flags);
        if(status != noErr) NSLog(@"TVUEncoder : H265 VTCompressionSessionEncodeFrame failed");
        [m_h265_lock unlock];
        
        if (status != noErr) {
            NSLog(@"TVUEncoder : VTCompressionSessionEncodeFrame failed");
            VTCompressionSessionCompleteFrames(h265CompressionSession, kCMTimeInvalid);
            VTCompressionSessionInvalidate(h265CompressionSession);
            CFRelease(h265CompressionSession);
            h265CompressionSession = NULL;
        }else {
            NSLog(@"TVUEncoder : Success VTCompressionSessionCompleteFrames");
        }
    }
    
    
}

-(void)getSupportedPropertyFlags
{
    CFDictionaryRef supportedPropertyDictionary;
    OSStatus h264Status, h265Status;
    if (self.enableH264) {
        h264Status = VTSessionCopySupportedPropertyDictionary(h264CompressionSession, &supportedPropertyDictionary);
        _h264propertyFlags = [[NSArray alloc ]initWithObjects:
                          [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_ExpectedFrameRate)],
                          [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_RealTime)],
                          [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_ProfileLevel)],
                          [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_H264EntropyMode)],
                          [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_DataRateLimits)],
                          [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration)],
                          [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_AllowFrameReordering)],
                          [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_AverageBitRate)],
                          nil];
        if (h264Status != noErr) NSLog(@"XDXHardwareEncoder : H264 VTSessionCopySupportedPropertyDictionary get failed");
        CFRelease(supportedPropertyDictionary);
    }
    
    if (self.enableH265) {
        h265Status = VTSessionCopySupportedPropertyDictionary(h265CompressionSession, &supportedPropertyDictionary);
        _h265PropertyFlags = [[NSArray alloc ]initWithObjects:
                              [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_ExpectedFrameRate)],
                              [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_RealTime)],
                              [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_ProfileLevel)],
                              [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_H264EntropyMode)],
                              [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_DataRateLimits)],
                              [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration)],
                              [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_AllowFrameReordering)],
                              [NSNumber numberWithBool:CFDictionaryContainsKey(supportedPropertyDictionary, kVTCompressionPropertyKey_AverageBitRate)],
                              nil];
        
        if (h265Status != noErr) NSLog(@"XDXHardwareEncoder : H265 VTSessionCopySupportedPropertyDictionary get failed");
        CFRelease(supportedPropertyDictionary);
    }
    
    NSLog(@"propertyFlag = %@ \n %@ \n",self.h264propertyFlags, self.h265PropertyFlags);
}

- (NSString *)deviceVersion
{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceString = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    return deviceString;
}

-(void)doSetBitrate {
    static int oldBitrate = 0;
    if(![self needAdjustBitrate]) return;
    
    int tmp         = _bitrate;
    int bytesTmp    = tmp >> 3;
    int durationTmp = 1;
    
    CFNumberRef bitrateRef   = CFNumberCreate(NULL, kCFNumberSInt32Type, &tmp);
    CFNumberRef bytes        = CFNumberCreate(NULL, kCFNumberSInt32Type, &bytesTmp);
    CFNumberRef duration     = CFNumberCreate(NULL, kCFNumberSInt32Type, &durationTmp);
    
    if (self.enableH264) {
        if (h264CompressionSession) {
            if ([self isSupportPropertyWithKey:Key_AverageBitRate inArray:self.h264propertyFlags]) {
                [self setSessionProperty:h264CompressionSession key:kVTCompressionPropertyKey_AverageBitRate value:bitrateRef];
            }else {
                NSLog(@"TVUEncoder : h264 set Key_AverageBitRate error");
            }
            
            // NSLog(@"TVUEncoder : h264 setBitrate bytes = %d, _bitrate = %d",bytesTmp, _bitrate);
            
            CFMutableArrayRef limit = CFArrayCreateMutable(NULL, 2, &kCFTypeArrayCallBacks);
            CFArrayAppendValue(limit, bytes);
            CFArrayAppendValue(limit, duration);
            if([self isSupportPropertyWithKey:Key_DataRateLimits inArray:self.h264propertyFlags]) {
                OSStatus ret = VTSessionSetProperty(h264CompressionSession, kVTCompressionPropertyKey_DataRateLimits, limit);
                if(ret != noErr){
                    NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
                    NSLog(@"H264: set DataRateLimits failed with %@", error.description);
                }
            }else {
                NSLog(@"TVUEncoder : H264 set Key_DataRateLimits error");
            }
            CFRelease(limit);
        }
    }
    
    if (self.enableH265) {
        /*  Not support for the moment */
    }
    
    CFRelease(bytes);
    CFRelease(duration);
    
    oldBitrate = _bitrate;
}

-(BOOL)needAdjustBitrate {
    if(!g_isSupportRealTimeEncoder) {
        CMClockRef   hostClockRef = CMClockGetHostTimeClock();
        CMTime       hostTime     = CMClockGetTime(hostClockRef);
        float lastTime = CMTimeGetSeconds(hostTime);
        float now = CMTimeGetSeconds(hostTime);
        if(now - lastTime < 0.5) {
            NSLog(@"bitrate = %d,count = %lu",_bitrate,(unsigned long)bitrates.count);
            [bitrates addObject:[NSNumber numberWithInt:_bitrate]];
            return NO;
        }else {
            NSUInteger count = [bitrates count];
            if(count == 0) return YES;
            
            int sum = 0;
            for (NSNumber *num in bitrates) {
                sum += num.intValue;
            }
            
            int average  = sum/count;
            _bitrate     = average;
            
            [bitrates removeAllObjects];
            lastTime = now;
        }
    }
    return YES;
}

#pragma mark - Dealloc
-(void)tearDownSession {
    NSLog(@"TVUEncoder : Delloc VTSession");
    [m_h264_lock lock];
    if(h264CompressionSession != NULL) {
        VTCompressionSessionCompleteFrames(h264CompressionSession, kCMTimeInvalid);
        VTCompressionSessionInvalidate(h264CompressionSession);
        CFRelease(h264CompressionSession);
        h264CompressionSession = NULL;
    }
    [m_h264_lock unlock];
    
    [m_h265_lock lock];
    if(h265CompressionSession != NULL) {
        VTCompressionSessionCompleteFrames(h265CompressionSession, kCMTimeInvalid);
        VTCompressionSessionInvalidate(h265CompressionSession);
        CFRelease(h265CompressionSession);
        h265CompressionSession = NULL;
    }
    [m_h265_lock unlock];
}

@end
