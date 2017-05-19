//
//  BarrrageBubblingSprite.m
//  YunBoLive
//
//  Created by 田祥根 on 2017/5/16.
//  Copyright © 2017年 1234tv. All rights reserved.
//

#import "BarrrageBubblingSprite.h"

static NSUInteger const STRIP_NUM = 80; // 总共的网格条数


@interface BarrrageBubblingSprite ()

@property (nonatomic,assign) NSTimeInterval currentStamp;

@property (nonatomic,assign) NSTimeInterval destinationStamp;

@property (nonatomic,assign) NSTimeInterval delayLeft;

@end

@implementation BarrrageBubblingSprite


- (instancetype)init{
    if (self = [super init]){
        self.trackNumber = 4;
        self.speedUp = 3000;
        self.stay = 6;
    }
    return self;
}


- (void)dismiss{
    _valid = NO;
}


- (BarrageWalkSide)defaultSideWithDirection:(BarrageWalkDirection)direction
{
    if (direction == BarrageWalkDirectionR2L) return BarrageWalkSideRight;
    else if (direction == BarrageWalkDirectionL2R) return BarrageWalkSideLeft;
    else if (direction == BarrageWalkDirectionT2B) return BarrageWalkSideRight;
    else if (direction == BarrageWalkDirectionB2T) return BarrageWalkSideLeft;
    return BarrageWalkSideRight; // Chinese way
}


//计算精灵的剩余存活时间

- (double)countTimeByDistance:(CGFloat)distance{
    CGFloat a = 0.5*self.speedUp;
    CGFloat b = self.speed;
    CGFloat c = -distance;
    CGFloat delt = sqrt(b*b - 4*a*c);
    double t = (-b+delt)/(2*a);
    return t;
}

- (NSTimeInterval)estimateActiveTime
{
    CGFloat activeDistance = 0;
    switch (self.direction) {
        case BarrageWalkDirectionR2L:
            activeDistance = self.position.x - _destination.x;
            break;
        case BarrageWalkDirectionL2R:
            activeDistance = _destination.x - self.position.x;
            break;
        case BarrageWalkDirectionT2B:
            activeDistance = _destination.y - self.position.y;
            break;
        case BarrageWalkDirectionB2T:
            activeDistance = self.position.y - _destination.y;
        default:
            break;
    }
    NSTimeInterval leftTime = 0.0;
    CGFloat time = [self countTimeByDistance:activeDistance];
    if (time > 0){
        leftTime = time + self.stay;
    }else{
        leftTime = self.stay - (self.currentStamp - self.destinationStamp);
    }
    return leftTime;
}

- (BOOL)validWithTime:(NSTimeInterval)time{
    self.currentStamp = time;
    return  [self estimateActiveTime] > 0;
}

- (CGRect)rectWithTime:(NSTimeInterval)time{
    CGFloat X = self.destination.x - self.origin.x;
    CGFloat Y = self.destination.y - self.origin.y;
        
    CGFloat L = sqrt(X*X + Y*Y);
    NSTimeInterval duration = time - self.timestamp;
    CGPoint position = CGPointMake(self.origin.x + duration * self.speed * X/L, self.origin.y + duration * self.speed * Y/L);
    if (position.x >= self.destination.x) {
        position.x = self.destination.x;
    }else{
        self.destinationStamp = time;
        self.speed = duration*self.speedUp;
    }
    if(position.y >= self.destination.y) {
        position.y = self.destination.y;
      
    }else{
        self.destinationStamp = time;
        self.speed = duration*self.speedUp;
    }
    return CGRectMake(position.x, position.y, self.size.width, self.size.height);
}


- (CGPoint)originInBounds:(CGRect)rect withSprites:(NSArray *)sprites
{
    // 获取同方向精灵
    NSMutableArray * synclasticSprites = [[NSMutableArray alloc]initWithCapacity:sprites.count];
    for (BarrageWalkSprite * sprite in sprites) {
        if (sprite.direction == self.direction && sprite.side == self.side) { // 找寻同道中人
            [synclasticSprites addObject:sprite];
        }
    }
    
    NSUInteger stripNum = MIN(STRIP_NUM, MAX(self.trackNumber, 1)); // between (1,STRIP_NUM)
    CGFloat stripHeight = rect.size.height/stripNum; // 水平条高度
    CGFloat stripWidth = rect.size.width/stripNum; // 竖直条宽度
    BOOL oritation = self.direction == BarrageWalkDirectionL2R || self.direction == BarrageWalkDirectionR2L; // 方向, YES代表水平弹幕
    BOOL rotation = self.side == [self defaultSideWithDirection:self.direction];
    /// 计算数据结构,便于应用算法
    NSUInteger overlandStripNum = 1; // 横跨网格条数目
    if (oritation) { // 水平
        overlandStripNum = (NSUInteger)ceil((double)self.size.height/stripHeight);
    }
    else // 竖直
    {
        overlandStripNum = (NSUInteger)ceil((double)self.size.width/stripWidth);
    }

    NSUInteger availableFrom = 0;
    BarrrageBubblingSprite* lastTimeSprite = self;
    NSInteger lastSpriteIndex = 0;
    
    
    for (NSUInteger i = 0; i < stripNum; i++) {
        //寻找当前行里包含的sprites
        CGFloat stripFrom = i * (oritation?stripHeight:stripWidth);
        CGFloat stripTo = stripFrom + (oritation?stripHeight:stripWidth);
        if (!rotation) {
            CGFloat preStripFrom = stripFrom;
            stripFrom = (oritation?rect.size.height:rect.size.width) - stripTo;
            stripTo = (oritation?rect.size.height:rect.size.width) - preStripFrom;
        }
        CGFloat exsitSprite = NO;
        for (BarrrageBubblingSprite * sprite in synclasticSprites) {
            CGFloat spriteFrom = oritation?sprite.origin.y:sprite.origin.x;
            CGFloat spriteTo = spriteFrom + (oritation?sprite.size.height:sprite.size.width);
            if ((spriteTo-spriteFrom)+(stripTo-stripFrom)>MAX(stripTo-spriteFrom, spriteTo-stripFrom)) { // 在条条里
                exsitSprite = YES;
              
                if (sprite.timestamp < lastTimeSprite.timestamp){
                    lastTimeSprite = sprite;
                    lastSpriteIndex = i;
                }
                break;
            }
        }
        if (exsitSprite) {
            availableFrom = i+1;
        }else{ //第一行就是空的
            break;
        }
        
    }
    if (availableFrom == stripNum) { // 超出最大的轨道数，挤掉最上层精灵
        availableFrom = lastSpriteIndex;
        lastTimeSprite.stay = 0;
    }
    
    CGPoint origin = CGPointZero;
    if (oritation) { // 水平
        _destination.y = origin.y = (rotation?stripHeight*availableFrom:rect.size.height-stripHeight * availableFrom-self.size.height)+rect.origin.y;
        origin.x = (self.direction == BarrageWalkDirectionL2R)?rect.origin.x - self.size.width:rect.origin.x + rect.size.width;
        _destination.x = (self.direction == BarrageWalkDirectionL2R)?rect.origin.x + rect.size.width - self.size.width :rect.origin.x + self.size.width;
    }
    else
    {
        _destination.x = origin.x = (rotation?stripWidth*availableFrom:rect.size.width-stripWidth*availableFrom -self.size.width)+rect.origin.x;
        origin.y = (self.direction == BarrageWalkDirectionT2B)?rect.origin.y - self.size.height:rect.origin.y + rect.size.height;
        _destination.y = (self.direction == BarrageWalkDirectionT2B)?rect.origin.y + rect.size.height - self.size.height:rect.origin.y + self.size.height;
    }
    return origin;
}




@end
