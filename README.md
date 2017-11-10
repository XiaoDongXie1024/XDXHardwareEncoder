### ----------------------------------------------------------------------------------------------------------------
### 本例需求：使用H264, H265实现视频数据的编码并录制开始200帧存为文件.
##### 原理：比如做直播功能，需要将客户端的视频数据传给服务器，如果分辨率过大如2K,4K则传输压力太大，所以需要对视频数据进行编码，传给服务器后再解码以实现大数据量的视频数据的传输，而利用硬件编码则可以极大限度减小CPU压力，当前主流使用H264进行编码，iOS 11 之后，iPhone 7以上的设备可以支持新的编码器H265编码器，使得同等质量视频占用的存储空间更小。所以本例中可以使用两种方式实现视频数据的编码
### ----------------------------------------------------------------------------------------------------------------

#### 最终效果如下 ： h264 

![h264 编码](http://r.photo.store.qq.com/psb?/V14Id4Zj1TAt9e/Zs.FQtSqK3HEAV0KwhBWsd11gDVDBOGc6C8nEvLWvbI!/r/dLEAAAAAAAAA)

#### h265 :

![h265 编码](http://r.photo.store.qq.com/psb?/V14Id4Zj1TAt9e/0laaTVE7fYiJysspAOooBZ3fCdWlUxVfVNz66tO2jv4!/r/dBABAAAAAAAA)


### ----------------------------------------------------------------------------------------------------------------


### 源代码地址: [H264,H265Encode]()
### 博客地址:   [H264,H265Encode]()
### 简书地址:   [H264,H265Encode]()
### ----------------------------------------------------------------------------------------------------------------


## 实现方式：
### 1. H264 : H264是当前主流编码标准，以高压缩高质量和支持多种网络的流媒体传输著称
### 2. H265 ：H264编码器的下一代，它的主要优点提供的压缩比高，相同质量的视频是H264的两倍。

### ----------------------------------------------------------------------------------------------------------------

## 一.本文需要基本知识点
#### 注意:可以先通过[H264,H265编码器介绍](http://www.jianshu.com/p/668e6abbed8c)了解预备知识。

#### 1. 软编与硬编概念
- 软编码：使用CPU进行编码。
- 硬编码：不使用CPU进行编码，使用显卡GPU,专用的DSP、FPGA、ASIC芯片等硬件进行编码。
    - 比较
        - 软编码：实现直接、简单，参数调整方便，升级易，但CPU负载重，性能较硬编码低，低码率下质量通常比硬编码要好一点。
        - 性能高，低码率下通常质量低于软编码器，但部分产品在GPU硬件平台移植了优秀的软编码算法（如X264）的，质量基本等同于软编码。
        - 苹果在iOS 8.0系统之前，没有开放系统的硬件编码解码功能，不过Mac OS系统一直有，被称为Video ToolBox的框架来处理硬件的编码和解码，终于在iOS 8.0后，苹果将该框架引入iOS系统


#### 2.H265优点
- 压缩比高，在相同图片质量情况下，比JPEG高两倍
- 能增加如图片的深度信息，透明通道等辅助图片。
- 支持存放多张图片，类似相册和集合。(实现多重曝光的效果)
- 支持多张图片实现GIF和livePhoto的动画效果。
- 无类似JPEG的最大像素限制
- 支持透明像素
- 分块加载机制
- 支持缩略图


## 二.代码解析
#### 1.实现流程
- 初始化相机参数，设置相机代理，这里就固定只有竖屏模式。
- 初始化编码器参数，并启动编码器
- 在编码成功的回调中从开始录制200帧(文件大小可自行修改)的视频，存到沙盒中，可以通过连接数据线到电脑从itunes中将文件(test0.asf)提取出来

#### 2.编码器实现流程
- 创建编码器需要的session (h264, h265 或同时创建)
- 设置session属性,如实时编码，码率，fps, 编码的分辨率的宽高，相邻I帧的最大间隔等等
    -  ######    注意H265目前不支持码率的限制 
- 当相机回调AVCaptureVideoDataOutputSampleBufferDelegate采集到一帧数据的时候则使用H264/H265编码器对每一帧数据进行编码。
- 若编码成功会触发回调，回调函数首先检测是否有I帧出现，如果有I帧出现则将sps,pps信息写入否则遍历NALU码流并将startCode替换成{0x00, 0x00, 0x00, 0x01}

#### 3.主要方法解析
- 初始化编码器
首先选择使用哪种方式实现，在本例中可以设置[XDXHardwareEncoder getInstance].enableH264 = YES 或者 [XDXHardwareEncoder getInstance].enableH265 = YES，也可以同时设置，如果同时设置需要将其中一个回调函数中的writeFile的方法屏蔽掉，并且只有较新的iPhone(> iPhone8 稳定)才支持同时打开两个session。

> 判断当前设备是否支持H265编码，必须满足两个条件，一是iPhone 7 以上设备，二是版本大于iOS 11

```
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
```
系统已经提供VTIsHardwareDecodeSupported判断当前设备是否支持H265编码

> 初始化编码器操作

```
- (void)prepareForEncode {
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
```

1> `g_isSupportRealTimeEncoder = (is64Bit == 8) ? true : false;`用来判断当前设备是32位还是64位

2> 创建H264/H265Session 区别仅仅为参数的不同，h264为kCMVideoCodecType_H264。 h265为kCMVideoCodecType_HEVC，在创建Session指定了回调函数后，当编码成功一帧就会调用相应的回调函数。

3> 通过`[self getSupportedPropertyFlags];`获取当前编码器支持设置的属性，经过测试，H265不支持码率的限制。目前暂时得不到解决。等待苹果后续处理。

4> 之后设置编码器相关属性，下面会具体介绍，设置完成后则调用VTCompressionSessionPrepareToEncodeFrames准备编码。

- 设置编码器相关属性
```
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
```
上述方法主要设置启动编码器所需的各个参数

1> kVTCompressionPropertyKey_MaxFrameDelayCount : 压缩器被允许保持的最大帧数在输出一个压缩帧之前。例如如果最大帧延迟数是M,那么在编码帧N返回的调用之前，帧N-M必须被排出。

2> kVTCompressionPropertyKey_ExpectedFrameRate : 设置fps

3> kVTCompressionPropertyKey_AverageBitRate : 它不是强制的限制，bit rate可能会超出峰值

4> kVTCompressionPropertyKey_RealTime : 设置编码器是否实时编码，如果设置为False则不是实时编码，视频效果会更好一点。

5> kVTCompressionPropertyKey_AllowFrameReordering : 是否让帧进行重新排序。为了编码B帧，编码器必须对帧重新排序，这将意味着解码的顺序与显示的顺序不同。将其设置为false以防止帧重新排序。

6> kVTCompressionPropertyKey_ProfileLevel : 指定编码比特流的配置文件和级别

7> kVTCompressionPropertyKey_H264EntropyMode ：如果支持h264该属性设置编码器是否应该使用基于CAVLC 还是 CABAC

8> kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration : 两个I帧之间最大持续时间，该属性特别有用当frame rate是可变

- 相机回调中对每一帧数据进行编码
```
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if( !CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog( @"sample buffer is not ready. Skipping sample" );
        return;
    }
    
    if([XDXHardwareEncoder getInstance] != NULL) {
        [[XDXHardwareEncoder getInstance] encode:sampleBuffer];
    }
}
```

以上方法在每采集到一帧视频数据后会调用一次，我们将拿到的每一帧数据进行编码。

- 编码具体实现
```
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
```

1> 通过frameID的递增构造时间戳为了使编码后的每一帧数据连续

2> 设置最大码率的限制，注意：H265目前不支持设置码率的限制，等待官方后续通知。可以对H264进行码率限制

3> kVTCompressionPropertyKey_DataRateLimits : 将数据的bytes和duration封装到CFMutableArrayRef传给API进行调用

4> VTCompressionSessionEncodeFrame : 调用此方法成功后触发回调函数完成编码。


- 回调函数中处理头信息
```
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
```

1> 首先在回调函数中截取到I帧，从I帧中提取到(h265中新增vps),sps,pps信息并写入文件
2> 遍历其他帧将头信息0000,0001写入每个头信息中，再将该数据写入文件即可

## 二.码流数据结构介绍

这里我们简单介绍一下H264,H265码流信息

1. H264流数据是由一系列NAL单元(NAL Unit)组成的。

2. 一个NALU可能包含：视频帧，视频帧也就是视频片段，具体有I,P,B帧

 ![H264的码流](http://r.photo.store.qq.com/psb?/V14Id4Zj1TAt9e/KExDsa2RJzGpe6a9NBTKJClrkX3HpcT68p2i4pqoJyY!/r/dOAAAAAAAAAA)
 
3. H.264属性合集-FormatDesc(包含 SPS和PPS)

![属性集合](http://r.photo.store.qq.com/psb?/V14Id4Zj1TAt9e/yuYb34e.S.4UoETVIJDPI1L6DYdVGdlKfW80wULI.T8!/r/dHYBAAAAAAAA)

注意在H265流数据中新增vps在最前。



- H.264属性合集-FormatDesc(包含 SPS和PPS)
    
流数据中，属性集合可能是这样的：


经过处理之后，在Format Description中则是:

![Format Description](http://r.photo.store.qq.com/psb?/V14Id4Zj1TAt9e/YUsq7p4oq0E8Uvz5hYxFAxH2pA.NoV38kiwjRwYjtZY!/r/dGwBAAAAAAAA)

- NALU header 
对于流数据来说，一个NALU的Header中，可能是0x00 00 01或者是0x00 00 00 01作为开头(两者都有可能，下面以0x00 00 01作为例子)。0x00 00 01因此被称为开始码(Start code).所以我们需要在提取的数据中用0x00 00 00 01对数据内容进行替换

![NALU header](http://r.photo.store.qq.com/psb?/V14Id4Zj1TAt9e/6LWUuXOk2xoelipoT3Lbu6qJQDTfOemFXg55YP1dh.U!/r/dDwBAAAAAAAA)


> 总结以上知识，我们知道H264的码流由NALU单元组成，NALU单元包含视频图像数据和H264的参数信息。其中视频图像数据就是CMBlockBuffer，而H264的参数信息则可以组合成FormatDesc。具体来说参数信息包含SPS（Sequence Parameter Set）和PPS（Picture Parameter Set）.如下图显示了一个H.264码流结构：

![H.264码流](http://r.photo.store.qq.com/psb?/V14Id4Zj1TAt9e/dLoOAI2WwVn2yGsmI0W3nqkRQplUQzK0w5gl99vUYkU!/r/dOAAAAAAAAAA)
       
- 提取sps和pps生成FormatDesc
    - 每个NALU的开始码是0x00 00 01，按照开始码定位NALU
    - 通过类型信息找到sps和pps并提取，开始码后第一个byte的后5位，7代表sps，8代表pps
    - 使用CMVideoFormatDescriptionCreateFromH264ParameterSets函数来构建CMVideoFormatDescriptionRef

- 提取视频图像数据生成CMBlockBuffer
    - 通过开始码，定位到NALU
    - 确定类型为数据后，将开始码替换成NALU的长度信息（4 Bytes）
    - 使用CMBlockBufferCreateWithMemoryBlock接口构造CMBlockBufferRef

- 根据需要，生成CMTime信息。（实际测试时，加入time信息后，有不稳定的图像，不加入time信息反而没有，需要进一步研究，这里建议不加入time信息）

根据上述得到CMVideoFormatDescriptionRef、CMBlockBufferRef和可选的时间信息，使用CMSampleBufferCreate接口得到CMSampleBuffer数据这个待解码的原始的数据。如下图所示的H264数据转换示意图。

![CMSampleBufferCreate](http://r.photo.store.qq.com/psb?/V14Id4Zj1TAt9e/wNFEFe7Lz7M5qCeNJNPrrSwyQjJdG3.J75X1vkszvn8!/r/dCsAAAAAAAAA)


### 编码器知识可参考:[H264,H265编码器介绍](http://www.jianshu.com/p/668e6abbed8c)