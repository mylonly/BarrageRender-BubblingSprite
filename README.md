# 基于BarrageRender自定义弹幕动画
> [BarrageRender](https://github.com/unash/BarrageRenderer) 是iOS上一个非常出名的弹幕渲染开源框架,其可以让我们在App中非常方便的集成弹幕功能，其作者在代码中提供了两种方式的弹幕动画，`BarrageFloatSprite`和`BarrageWalkSprite`。可以说移动和浮动这两种动画方式基本上已经满足了大部分App的需求，但是仍然有部分App需要在弹幕的展现形式上更加的自由，例如各大直播平台的礼物弹幕。笔者将在这篇文章中分享自己在BarrageRender的基础上编写自定义礼物弹幕的过程。

<!-- more -->
###先展示效果
![弹幕效果](http://pic.mylonly.com/2017-05-19-1234.gif)

###再介绍BarrageWalkSprite原理

> BarrageWalkSprite和本文将要实现的自定义Sprite有一定的关联性，所以就通过分析BarrageWalkSprite的源码来展示BarrageRender渲染弹幕的原理，另外一个BarrageFloatSprite的渲染方式稍有不同，但是如果你能搞清楚BarrageWalkSprite的原理，理解FloatSprite的渲染方式也是很轻松的。

#### 弹幕的初始位置
    
   BarrageRender在BarrageDispatcher的调度下触发activeWithContext方法，而在此方法中，BarrageRender调用了Sprite的originInBounds:withSprite方法来确定每个精灵的初始位置
   
   ```Objc
   - (void)activeWithContext:(NSDictionary *)context
    {
        CGRect rect = [[context objectForKey:kBarrageRendererContextCanvasBounds]CGRectValue];
        NSArray * sprites = [context objectForKey:kBarrageRendererContextRelatedSpirts];
        NSTimeInterval timestamp = [[context objectForKey:kBarrageRendererContextTimestamp]doubleValue];
        _timestamp = timestamp;
        _view = [self bindingView];
        [self configView];
        [_view sizeToFit];
        if (!CGSizeEqualToSize(_mandatorySize, CGSizeZero)) {
            _view.frame = CGRectMake(0, 0, _mandatorySize.width, _mandatorySize.height);
        }
        _origin = [self originInBounds:rect withSprites:sprites];
        _view.frame = CGRectMake(_origin.x, _origin.y, self.size.width, self.size.height);
    }
   ```
    
BarrageWalkSpirte在originInBounds:withSprite方法中,根据当前屏幕上已经存在的Sprite来计算自己的初始位置。
     
```Objc
    
- (CGPoint)originInBounds:(CGRect)rect withSprites:(NSArray *)sprites
{
   // 获取同方向精灵
   NSMutableArray * synclasticSprites = [[NSMutableArray alloc]initWithCapacity:sprites.count];
   for (BarrageWalkSprite * sprite in sprites) {
       if (sprite.direction == _direction && sprite.side == self.side) { // 找寻同道中人
           [synclasticSprites addObject:sprite];
       }
   }
   
   static BOOL const AVAERAGE_STRATEGY = YES; // YES:条纹平均精灵策略(体验会好一些); NO:最快时间策略
   NSTimeInterval stripMaxActiveTimes[STRIP_NUM]={0}; // 每一条网格 已有精灵中最后退出屏幕的时间
   NSUInteger stripSpriteNumbers[STRIP_NUM]={0}; // 每一条网格 包含精灵的数目
   NSUInteger stripNum = MIN(STRIP_NUM, MAX(self.trackNumber, 1)); // between (1,STRIP_NUM)
   CGFloat stripHeight = rect.size.height/stripNum; // 水平条高度
   CGFloat stripWidth = rect.size.width/stripNum; // 竖直条宽度
   BOOL oritation = _direction == BarrageWalkDirectionL2R || _direction == BarrageWalkDirectionR2L; // 方向, YES代表水平弹幕
   BOOL rotation = self.side == [self defaultSideWithDirection:_direction];
   /// 计算数据结构,便于应用算法
   NSUInteger overlandStripNum = 1; // 横跨网格条数目
   if (oritation) { // 水平
       overlandStripNum = (NSUInteger)ceil((double)self.size.height/stripHeight);
   }
   else // 竖直
   {
       overlandStripNum = (NSUInteger)ceil((double)self.size.width/stripWidth);
   }
   /// 当前精灵需要的时间,左边碰到边界, 不是真实的活跃时间
   NSTimeInterval maxActiveTime = oritation?rect.size.width/self.speed:rect.size.height/self.speed;
   NSUInteger availableFrom = 0;
   NSUInteger leastActiveTimeStrip = 0; // 最小时间的行
   NSUInteger leastActiveSpriteStrip = 0; // 最小网格的行
   
   for (NSUInteger i = 0; i < stripNum; i++) {
       //寻找当前行里包含的sprites
       CGFloat stripFrom = i * (oritation?stripHeight:stripWidth);
       CGFloat stripTo = stripFrom + (oritation?stripHeight:stripWidth);
       if (!rotation) {
           CGFloat preStripFrom = stripFrom;
           stripFrom = (oritation?rect.size.height:rect.size.width) - stripTo;
           stripTo = (oritation?rect.size.height:rect.size.width) - preStripFrom;
       }
       CGFloat lastDistanceAllOut = YES;
       for (BarrageWalkSprite * sprite in synclasticSprites) {
           CGFloat spriteFrom = oritation?sprite.origin.y:sprite.origin.x;
           CGFloat spriteTo = spriteFrom + (oritation?sprite.size.height:sprite.size.width);
           if ((spriteTo-spriteFrom)+(stripTo-stripFrom)>MAX(stripTo-spriteFrom, spriteTo-stripFrom)) { // 在条条里
               stripSpriteNumbers[i]++;
               NSTimeInterval activeTime = [sprite estimateActiveTime];
               if (activeTime > stripMaxActiveTimes[i]){ // 获取最慢的那个
                   stripMaxActiveTimes[i] = activeTime;
                   CGFloat distance = oritation?fabs(sprite.position.x-sprite.origin.x):fabs(sprite.position.y-sprite.origin.y);
                   lastDistanceAllOut = distance > (oritation?sprite.size.width:sprite.size.height);
               }
           }
       }
       if (stripMaxActiveTimes[i]>maxActiveTime || !lastDistanceAllOut) {
           availableFrom = i+1;
       }
       else if (i - availableFrom >= overlandStripNum - 1){
           break; // eureka!
       }
       if (i <= stripNum - overlandStripNum) {
           if (stripMaxActiveTimes[i] < stripMaxActiveTimes[leastActiveTimeStrip]) {
               leastActiveTimeStrip = i;
           }
           if (stripSpriteNumbers[i] < stripSpriteNumbers[leastActiveSpriteStrip]) {
               leastActiveSpriteStrip = i;
           }
       }
   }
   if (availableFrom > stripNum - overlandStripNum) { // 那就是没有找到喽
       availableFrom = AVAERAGE_STRATEGY?leastActiveSpriteStrip:leastActiveTimeStrip; // 使用最小个数 or 使用最短时间
   }
   
   CGPoint origin = CGPointZero;
   if (oritation) { // 水平
       _destination.y = origin.y = (rotation?stripHeight*availableFrom:rect.size.height-stripHeight * availableFrom-self.size.height)+rect.origin.y;
       origin.x = (self.direction == BarrageWalkDirectionL2R)?rect.origin.x - self.size.width:rect.origin.x + rect.size.width;
       _destination.x = (self.direction == BarrageWalkDirectionL2R)?rect.origin.x + rect.size.width:rect.origin.x - self.size.width;
   }
   else
   {
       _destination.x = origin.x = (rotation?stripWidth*availableFrom:rect.size.width-stripWidth*availableFrom -self.size.width)+rect.origin.x;
       origin.y = (self.direction == BarrageWalkDirectionT2B)?rect.origin.y - self.size.height:rect.origin.y + rect.size.height;
       _destination.y = (self.direction == BarrageWalkDirectionT2B)?rect.origin.y + rect.size.height:rect.origin.y - self.size.height;
   }
   return origin;
}
```
    
代码虽然很长，但是主要就是为了实现下面几个逻辑:

    1. BarrageWalkSprite先获取了同方向的所有精灵
    2. 根据屏幕轨道的frame范围找到每一个轨道内的所有精灵
    3. 在同一轨道内的所有精灵中找到存活时间最长的精灵(速度最慢)
    4. 判断速度最慢的那个精灵的尾部是否已经完全进入弹幕显示区域
    5. 如果速度最慢的精灵尾部已经进入弹幕显示区域，则可以确定自己的可以紧跟在后面出现，如果还没有完全进入弹幕显示区域，则继续在下一个轨道获取合适的位置
    6. 根据计算得到的自己可以出现的轨道，加上该轨道上最后一个精灵的位置，得到自己的起始位置

    
#### 弹幕的运动轨迹 
    
BarrageRender绘制每个精灵的运动轨迹的方式非常简单，在BarrageRender中，内置的时钟引擎`BarrageClock`负责在间隔时间内调用所有已经激活精灵基类`BarrageSprite`中的updateWithTime方法。
   
   ```Objc
   - (void)initClock
    {
        __weak id weakSelf = self;
        _clock = [BarrageClock clockWithHandler:^(NSTimeInterval time){
            BarrageRenderer * strongSelf = weakSelf;
            strongSelf->_time = time;
            [strongSelf update];
        }];
    }
    
    /// 每个刷新周期执行一次
    - (void)update
    {
        [_dispatcher dispatchSprites]; // 分发精灵
        for (BarrageSprite * sprite in _dispatcher.activeSprites) {
            [sprite updateWithTime:_time];
        }
    }

   ```

   而在`BarrageSprite`的updateWithTime方法中, 每个精灵重新更改了自身的frame属性，以此来达到动画位移的效果。其中`_valid`属性是Sprite存活的唯一标志，标记为NO之后，Sprite就会从队列中彻底移除
   
   ```Objc
     //BarrageSprite
   - (void)updateWithTime:(NSTimeInterval)time
    {
        _valid = [self validWithTime:time];
        _view.frame = [self rectWithTime:time];
    }
   ```
  
  BarrageWalkSprite通过属性speed来实时改变自己的frame位置,同时计算剩下的destination和speed来算出自己的存活时间以用来标记valid属性
  
  ```Objc  
  //BarrageWalkSprite
  
  - (BOOL)validWithTime:(NSTimeInterval)time
    {
        return [self estimateActiveTime] > 0;
    }
    
  - (NSTimeInterval)estimateActiveTime
    {
        CGFloat activeDistance = 0;
        switch (_direction) {
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
        return activeDistance/self.speed;
    }
  
  - (CGRect)rectWithTime:(NSTimeInterval)time
    {
        CGFloat X = self.destination.x - self.origin.x;
        CGFloat Y = self.destination.y - self.origin.y;
        CGFloat L = sqrt(X*X + Y*Y);
        NSTimeInterval duration = time - self.timestamp;
        CGPoint position = CGPointMake(self.origin.x + duration * self.speed * X/L, self.origin.y + duration * self.speed * Y/L);
        return CGRectMake(position.x, position.y, self.size.width, self.size.height);
    }
    
  ```
#### 弹幕终点
BarrageWalkSprite的终点计算很简单，弹幕的显示的距离加上Sprite自身的宽度就是整个精灵需要位移的距离，这个destination的计算已经体现在了起点位置的获取当中

```Objc
CGPoint origin = CGPointZero;
if (oritation) { // 水平
   _destination.y = origin.y = (rotation?stripHeight*availableFrom:rect.size.height-stripHeight * availableFrom-self.size.height)+rect.origin.y;
   origin.x = (self.direction == BarrageWalkDirectionL2R)?rect.origin.x - self.size.width:rect.origin.x + rect.size.width;
   _destination.x = (self.direction == BarrageWalkDirectionL2R)?rect.origin.x + rect.size.width:rect.origin.x - self.size.width;
}
else
{
   _destination.x = origin.x = (rotation?stripWidth*availableFrom:rect.size.width-stripWidth*availableFrom -self.size.width)+rect.origin.x;
   origin.y = (self.direction == BarrageWalkDirectionT2B)?rect.origin.y - self.size.height:rect.origin.y + rect.size.height;
   _destination.y = (self.direction == BarrageWalkDirectionT2B)?rect.origin.y + rect.size.height:rect.origin.y - self.size.height;
}
return origin;
```
  
### 自定义Sprite

> BarrageBubblingSprite的运动轨迹和BarrageWalkSprite有很多重合之处，所以自定义的BarrageBubblingSprite直接继承BarrageWalkSprite以获取其direction,side,speed,trackNumber等多个属性，当然还需要另外加上加速度speedUp和停留时间stay属性

```Objc
@interface BarrrageBubblingSprite : BarrageWalkSprite

@property (nonatomic,assign) CGFloat speedUp; //加速度

@property (nonatomic,assign) CGFloat stay; //到达终点后的停留时间

@end
```

#### 起点位置

BubblingSprite的起点位置的获取逻辑和WalkSprite的起点逻辑类似，不同的地方在于:

1. *即使轨道内最慢的那个精灵已经完全进入弹幕显示区域，只要该精灵仍然存活，就不能紧跟其后,而是要另外找寻其他轨道*
2. *当所有轨道都已经有精灵占据的时候，找到存活时间最短的那个精灵，通过将其的stay属性设置为0让其直接消失，然后让自己占据该精灵所在轨道*


```Objc
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

```  
   

#### 运动轨迹

BarrageBubblingSprite的运动轨迹和BarrageWalkSprite的运动轨迹不同的地方在于，BarrageWalkSprite是匀速前进，二BarrageBubblingSprite是加速前进，这样，在计算某个时段Sprite的位置就需要考虑加速度的存在。

```Objc
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
```

在存活时间上，与BarrageWalkSprite不同的地方在于，BarrageWalkSprite在位移到终点的时候消失，而BarrageBubblingSprite在到达终点之后仍然需要停留stay的时间。这里引入了currentStamp和destinationStamp时间戳用于来计算stay时间是否已经到达。

```Objc
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
```

#### 自定义弹幕样式

类似BarrageWalkImageSprite，我们也通过继承BarrageSpirte的bindingView 来将自定义的弹幕view返回给BarrageRender


###完整代码

[BarrageRender-BubblingSprite](https://github.com/mylonly/BarrageRender-BubblingSprite)



