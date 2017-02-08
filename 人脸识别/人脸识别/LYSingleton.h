//
//  LYSingleton.h
//  webSockettest
//
//  Created by 前海睿科 on 16/4/5.
//  Copyright © 2016年 Qhrico. All rights reserved.
//

// .h文件
#define LYSingletonH + (instancetype)sharedInstance;


// .m文件
#define LYSingletonM \
static id _instace; \
\
+ (instancetype)allocWithZone:(struct _NSZone *)zone \
{ \
static dispatch_once_t onceToken; \
dispatch_once(&onceToken, ^{ \
_instace = [super allocWithZone:zone]; \
}); \
return _instace; \
} \
\
+ (instancetype)sharedInstance \
{ \
static dispatch_once_t onceToken; \
dispatch_once(&onceToken, ^{ \
_instace = [[self alloc] init]; \
}); \
return _instace; \
} \
\
- (id)copyWithZone:(NSZone *)zone \
{ \
return _instace; \
}
