//
//  BarrrageBubblingSprite.h
//  YunBoLive
//
//  Created by 田祥根 on 2017/5/16.
//  Copyright © 2017年 1234tv. All rights reserved.
//

#import <BarrageRenderer/BarrageRenderer.h>

@interface BarrrageBubblingSprite : BarrageWalkSprite

@property (nonatomic,assign) CGFloat speedUp; //加速度

@property (nonatomic,assign) CGFloat stay; //到达终点后的停留时间

@end
