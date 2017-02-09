//
//  LY_AudioPalyTool.m
//  CocoMobileV1
//
//  Created by 前海睿科 on 16/4/27.
//  Copyright © 2016年 Qhrico. All rights reserved.
//

#import "LY_AudioPalyTool.h"

@implementation LY_AudioPalyTool
LYSingletonM


#pragma mark - Getter


+ (instancetype)sharedAudioPaly
{
    return [[[self class] alloc]init];
}

- (AVPlayer *)lY_AudioPlayer
{
    if (_lY_AudioPlayer == nil) {
        
        // 一开始播放的是LightNotice
        AVPlayerItem *firstItem = [self playFirstItemForResourceName:@"LightNotice"];
        
        // 根据指定的播放源来创建播放器
        _lY_AudioPlayer = [[AVPlayer alloc] initWithPlayerItem:firstItem];
    }
    
    return _lY_AudioPlayer;
}

// 根据下标来生成一个PlayerItem对象
- (AVPlayerItem *)playFirstItemForResourceName:(NSString *)name
{
    NSURL *url = [[NSBundle mainBundle] URLForResource:name withExtension:@"mp3"];
    
    return [AVPlayerItem playerItemWithURL:url];
}

- (void)PlayLatterResourceWithName:(NSString *)name
{
    NSURL *url = [[NSBundle mainBundle] URLForResource:name withExtension:@"mp3"];
     AVPlayerItem *currentPlayerItem = [AVPlayerItem playerItemWithURL:url];
    // 切换播放源
    [self.lY_AudioPlayer replaceCurrentItemWithPlayerItem:currentPlayerItem];
    
}


- (void)play
{
    // audioPlayer.rate 播放的速度，当是0.0是暂停，大于0是播放
    // 如果当前播放器在暂停就让他播放，如果播放就让他暂停
   if (self.lY_AudioPlayer.rate <= 0) {
        // 播放
        [self.lY_AudioPlayer play];
        
    }
}
- (void)stop
{
    //  暂停
    if (self.lY_AudioPlayer.rate > 0) {
        
        [self.lY_AudioPlayer pause];
        
    }
}
@end
