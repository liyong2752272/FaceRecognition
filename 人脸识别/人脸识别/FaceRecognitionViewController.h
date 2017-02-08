//
//  FaceRecognitionViewController.h
//  CocoMobileV1
//
//  Created by 前海睿科 on 16/3/24.
//  Copyright © 2016年 Qhrico. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 等待拍照时间
 */
extern NSTimeInterval JGFCameraDefaultPauseBeforeShutterInterval; // 2.0f

/**
 倒计时间隔
 */
extern NSTimeInterval JGFCameraDefaultFeedbackIntervalWhileWaitingForShutter; // 1.0f

/**
 眨眼保持开启拍照时间
 */
extern NSTimeInterval JGFCameraDefaultMinimumWinkDurationForAutomaticTrigger; // 0.3f


@interface FaceRecognitionViewController : UIViewController

@property (nonatomic,copy)NSString *UpStyle;

@property (nonatomic, assign) NSTimeInterval minimumWinkDurationForAutomaticTrigger;

@end
