//
//  BarrageCustomViewFloatSprite.h
//  YunBoLive
//
//  Created by 田祥根 on 2017/5/16.
//  Copyright © 2017年 1234tv. All rights reserved.
//

#import <BarrageRenderer/BarrageRenderer.h>
#import "BarrrageBubblingSprite.h"

@interface BarrageCustomView : UIView

- (id)initWithGift:(NSString*)senderAvatarUrl withToName:(NSString*)name giftUrl:(NSURL*)giftUrl giftNum:(NSInteger)giftNum;

@end

@protocol BarrageCustomViewProtocol <BarrageViewProtocol>

@required
@property(nonatomic,strong)UIView * customView;

@end

@interface BarrageCustomViewFloatSprite : BarrrageBubblingSprite<BarrageCustomViewProtocol>

@end
