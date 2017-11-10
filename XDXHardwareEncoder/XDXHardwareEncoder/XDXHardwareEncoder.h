//
//  XDXHardwareEncoder.h
//  XDXHardwareEncoder
//
//  Created by 小东邪 on 09/11/2017.
//  Copyright © 2017 小东邪. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface XDXHardwareEncoder : NSObject

@property (nonatomic, assign) BOOL          enableH264;
@property (nonatomic, assign) BOOL          enableH265;

+ (instancetype)getInstance;
- (void)prepareForEncode;
- (void)startWithWidth:(int)width andHeight:(int)height andFPS:(int)fps;
- (void)encode:(CMSampleBufferRef)sampleBuffer;

@end
