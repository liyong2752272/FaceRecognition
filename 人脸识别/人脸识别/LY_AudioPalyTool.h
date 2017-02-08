//
//  LY_AudioPalyTool.h
//  CocoMobileV1
//
//  Created by 前海睿科 on 16/4/27.
//  Copyright © 2016年 Qhrico. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LYSingleton.h"

@interface LY_AudioPalyTool : NSObject
LYSingletonH

/** 音频管理者 */
@property (nonatomic, strong) AVPlayer *lY_AudioPlayer;

+ (instancetype)sharedAudioPaly;

- (AVPlayerItem *)playFirstItemForResourceName:(NSString *)name;

- (void)PlayLatterResourceWithName:(NSString *)name;
- (void)play;
- (void)stop;
@end
