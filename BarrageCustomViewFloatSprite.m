//
//  BarrageCustomViewFloatSprite.m
//  YunBoLive
//
//  Created by 田祥根 on 2017/5/16.
//  Copyright © 2017年 1234tv. All rights reserved.
//

#import "BarrageCustomViewFloatSprite.h"
#import <SDWebImage/UIImageView+WebCache.h>

@interface BarrageCustomView ()

@property (nonatomic,strong) UIImageView* avatarView;

@property (nonatomic,strong) UILabel* giftInfoLabel;

@property (nonatomic,strong) UIImageView* giftAvatarView;

@property (nonatomic,strong) UILabel* giftNum;

@end

@implementation BarrageCustomView

- (id)initWithGift:(NSString *)senderAvatarUrl withToName:(NSString *)name giftUrl:(NSURL *)giftUrl giftNum:(NSInteger)giftNum{
    self = [super initWithFrame:CGRectMake(0, 0, 150, 40)];
    if (self != nil ){
        
        self.layer.masksToBounds = YES;
        self.layer.cornerRadius = 20.f;
        
        _avatarView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        _avatarView.layer.masksToBounds = YES;
        _avatarView.layer.cornerRadius = 20.f;
        [_avatarView sd_setImageWithURL:[NSURL URLWithString:senderAvatarUrl] placeholderImage:[UIImage imageNamed:@"no_dl"]];
        [self addSubview:_avatarView];
        
        UILabel* aa = [[UILabel alloc] initWithFrame:CGRectMake(45, 5, 75, 10)];
        aa.text = @"送给";
        aa.font = [UIFont systemFontOfSize:10];
        aa.textColor = [UIColor whiteColor];
        aa.textAlignment = NSTextAlignmentCenter;
        [self addSubview:aa];
        
        _giftInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, 15, 75, 25)];
        _giftInfoLabel.text = name;
        _giftInfoLabel.numberOfLines = 2;
        _giftInfoLabel.font = [UIFont systemFontOfSize:12];
        _giftInfoLabel.textAlignment = NSTextAlignmentCenter;
        _giftInfoLabel.textColor = [UIColor redColor];
        [self addSubview:_giftInfoLabel];
        
        _giftAvatarView = [[UIImageView alloc] initWithFrame:CGRectMake(120, 0, 40, 40)];
        _giftAvatarView.layer.masksToBounds = YES;
        _giftAvatarView.layer.cornerRadius = 20.f;
        [_giftAvatarView sd_setImageWithURL:giftUrl];
        [self addSubview:_giftAvatarView];
        
        _giftNum = [[UILabel alloc] initWithFrame:CGRectMake(160, 0, 40, 40)];
        _giftNum.textColor = [UIColor greenColor];
        _giftNum.font = [UIFont systemFontOfSize:20];
        _giftNum.textAlignment = NSTextAlignmentCenter;
        _giftNum.text = [NSString stringWithFormat:@"x%ld",(long)giftNum];
        [self addSubview:_giftNum];
    }
    return self;
}

- (CGSize)sizeThatFits:(CGSize)size{
    
    return CGSizeMake(200, 40);
}

@end

@implementation BarrageCustomViewFloatSprite

@synthesize customView = _customView;

- (instancetype)init{
    if (self = [super init]){
        _customView = nil;
    }
    return self;
}

- (UIView*)bindingView{
    return _customView;
}

@end
