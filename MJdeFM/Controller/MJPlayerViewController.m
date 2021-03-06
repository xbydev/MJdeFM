//
//  MJPlayerViewController.m
//
//
//  Created by WangMinjun on 15/8/3.
//
//

#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "MJPlayerViewController.h"
#import "MJFetcher.h"
#import "MJChannelManager.h"
#import "MJSong.h"
#import "UIImageView+AFNetworking.h"
#import "MJUserInfoManager.h"
#import "MBProgressHUD.h"

/**
 n : None. Used for get a song list only.
 e : Ended a song normally.
 u : Unlike a hearted song.
 r : Like a song.
 s : Skip a song.
 b : Trash a song.
 p : Use to get a song list when the song in playlist was all played.
 */
#define GETSONGTLISTTYPE @"n"
#define SKIPSONGTYPE @"s"
#define DELETESONGTYPE @"b"

@interface MJPlayerViewController ()

@property (nonatomic, strong) MPMoviePlayerController* player;
@property (nonatomic, strong) NSMutableArray* playList;
@property (nonatomic, strong) MJSong* playingSong;
@property (nonatomic, assign) NSInteger currentSongIndex;
@property (nonatomic, assign, getter=isPlaying) BOOL playing;
@property (nonatomic, strong) NSTimer* timer;

@property (nonatomic, weak) IBOutlet UILabel* songTitle;
@property (nonatomic, weak) IBOutlet UILabel* songArtist;
@property (nonatomic, weak) IBOutlet UILabel* ChannelTitle;
@property (nonatomic, weak) IBOutlet UILabel* timerLabel;
@property (nonatomic, weak) IBOutlet UIProgressView* timerProgressBar;
@property (nonatomic, weak) IBOutlet UIImageView* picture;
@property (nonatomic, weak) IBOutlet UIImageView* pictureBlock;
@property (nonatomic, weak) IBOutlet UIButton* pauseButton;
@property (nonatomic, weak) IBOutlet UIButton* likeButton;
- (IBAction)pauseButton:(UIButton*)sender;
- (IBAction)likeButton:(UIButton*)sender;
- (IBAction)deleteButton:(UIButton*)sender;
- (IBAction)skipButton:(UIButton*)sender;

@end

@implementation MJPlayerViewController {
    NSString* totalTimeString;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(startPlay)
               name:MPMoviePlayerPlaybackDidFinishNotification
             object:nil];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(changeChannel:)
               name:MJChannelViewControllerDidSelectChannelNotification
             object:nil];

    [self setUp];

    [self loadPlayListWithType:GETSONGTLISTTYPE];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"MJPlayerViewController dealloc");
}

#pragma mark - local

- (MPMoviePlayerController*)player
{
    if (!_player) {
        _player = [[MPMoviePlayerController alloc] init];
    }
    return _player;
}

- (NSMutableArray*)playList
{
    if (!_playList) {
        _playList = [[NSMutableArray alloc] init];
    }
    return _playList;
}

- (void)setUp
{
    self.playing = YES;

    self.picture.layer.cornerRadius = self.picture.bounds.size.width / 2.0;
    self.picture.layer.masksToBounds = YES;

    self.pictureBlock.image = [UIImage imageNamed:@"albumBlock"];
    self.pictureBlock.userInteractionEnabled = YES;
    UITapGestureRecognizer* singleTap =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(pauseButton:)];
    [singleTap setNumberOfTapsRequired:1];
    [self.pictureBlock addGestureRecognizer:singleTap];

    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.02
                                                  target:self
                                                selector:@selector(updateProgress)
                                                userInfo:nil
                                                 repeats:YES];

    //后台播放
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
}

- (void)startPlay
{
    if (self.currentSongIndex > ([self.playList count] - 1)) {
        [self loadPlayListWithType:@"p"];
    }
    else {
        self.playingSong = self.playList[self.currentSongIndex];
    }
}

- (void)changeChannel:(NSNotification*)notification
{
    MJChannel* channel = notification.userInfo[@"channel"];
    [MJChannelManager sharedChannelManager].currentChannel = channel;
    [self loadPlayListWithType:GETSONGTLISTTYPE];
}

- (void)setPlayingSong:(MJSong*)playingSong
{
    _playingSong = playingSong;
    [self.player setContentURL:[NSURL URLWithString:playingSong.url]];
    [self.player play];
    self.currentSongIndex++;

    //    if (![self isFirstResponder]) {
    //        //远程控制
    //        [[UIApplication sharedApplication]
    //        beginReceivingRemoteControlEvents];
    //        [self becomeFirstResponder];
    //    }

    self.songTitle.text = playingSong.title;
    self.songArtist.text = playingSong.artist;
    self.ChannelTitle.text =
        [[MJChannelManager sharedChannelManager] currentChannel].name;
    [self.picture setImageWithURL:[NSURL URLWithString:playingSong.picture]];
    if (![playingSong.like intValue]) {
        [self.likeButton setBackgroundImage:[UIImage imageNamed:@"heart1"]
                                   forState:UIControlStateNormal];
    }
    else {
        [self.likeButton setBackgroundImage:[UIImage imageNamed:@"heart2"]
                                   forState:UIControlStateNormal];
    }

    //初始化timeLabel的总时间
    int totalTimeSeconds = [playingSong.length intValue] % 60;
    int totalTimeMinutes = [playingSong.length intValue] / 60;
    if (totalTimeSeconds < 10) {
        totalTimeString = [NSMutableString
            stringWithFormat:@"%d:0%d", totalTimeMinutes, totalTimeSeconds];
    }
    else {
        totalTimeString = [NSMutableString
            stringWithFormat:@"%d:%d", totalTimeMinutes, totalTimeSeconds];
    }
    [self.timer setFireDate:[NSDate date]];

    // 设置锁屏界面的播放信息
    [self configPlayingInfo];
}

- (void)updateProgress
{
    NSInteger currentTimeMinutes = (unsigned)self.player.currentPlaybackTime / 60;
    NSInteger currentTimeSeconds = (unsigned)self.player.currentPlaybackTime % 60;
    //专辑图片旋转
    self.picture.transform = CGAffineTransformRotate(self.picture.transform, M_PI / 1440);
    NSString* currentTimeString = nil;
    if (currentTimeSeconds < 10) {
        currentTimeString =
            [NSString stringWithFormat:@"%ld:0%ld", (long)currentTimeMinutes,
                      (long)currentTimeSeconds];
    }
    else {
        currentTimeString =
            [NSString stringWithFormat:@"%ld:%ld", (long)currentTimeMinutes,
                      (long)currentTimeSeconds];
    }
    NSString* timerLabelString =
        [NSString stringWithFormat:@"%@/%@", currentTimeString, totalTimeString];
    self.timerLabel.text = timerLabelString;
    self.timerProgressBar.progress = self.player.currentPlaybackTime / [self.playingSong.length intValue];
}

#pragma mark - Network

- (void)loadPlayListWithType:(NSString*)type
{
    [[MJFetcher sharedFetcher] fetchPlaylistwithType:type
        song:self.playingSong
        passedTime:0
        channel:[MJChannelManager sharedChannelManager].currentChannel
        success:^(MJFetcher* fetcher, id data) {
            [self.playList addObjectsFromArray:data];
            self.playingSong = self.playList[self.currentSongIndex];
        }
        failure:^(MJFetcher* fetcher, NSError* error) {
            NSLog(@"~~~~get an error:~~~~%@", error);
        }];
}

- (void)user:(MJUserInfo*)user
addHeartSong:(MJSong*)song
      action:(NSString*)action
{
    [[MJFetcher sharedFetcher] user:user
        addHeartSong:song
        action:action
        success:^(MJFetcher* fetcher, id data) {
            NSLog(@"添加红心：%@", action);
        }
        failure:^(MJFetcher* fetcher, NSError* error) {
            NSLog(@"%@", error);
        }];
}

#pragma mark - IBAction

- (IBAction)pauseButton:(UIButton*)sender
{
    if (self.isPlaying) {
        [self.player pause];
        self.picture.alpha = 0.2;
        self.pictureBlock.image = [UIImage imageNamed:@"albumBlock2"];
        [self.pauseButton setBackgroundImage:[UIImage imageNamed:@"play"]
                                    forState:UIControlStateNormal];
        [self.timer setFireDate:[NSDate distantFuture]];
    }
    else {
        [self.player play];
        self.picture.alpha = 1.0;
        self.pictureBlock.image = [UIImage imageNamed:@"albumBlock"];
        [self.pauseButton setBackgroundImage:[UIImage imageNamed:@"pause"]
                                    forState:UIControlStateNormal];
        [self.timer setFireDate:[NSDate date]];
    }
    self.playing = !self.isPlaying;
}

- (IBAction)likeButton:(UIButton*)sender
{
    MJUserInfo* user = [[MJUserInfoManager sharedUserInfoManager] userInfo];
    if (!user) {
        MBProgressHUD* hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];

        // Configure for text only and offset down
        hud.mode = MBProgressHUDModeText;
        hud.labelText = @"还没有登录，赶紧登录哦！";
        hud.margin = 10.f;
        hud.removeFromSuperViewOnHide = YES;

        [hud hide:YES afterDelay:3];

        return;
    }

    if (![self.playingSong.like intValue]) {
        self.playingSong.like = @"1";
        [self.likeButton setBackgroundImage:[UIImage imageNamed:@"heart2"]
                                   forState:UIControlStateNormal];
        [self user:user addHeartSong:self.playingSong action:@"y"];
    }
    else {
        self.playingSong.like = @"0";
        [self.likeButton setBackgroundImage:[UIImage imageNamed:@"heart1"]
                                   forState:UIControlStateNormal];
        [self user:user addHeartSong:self.playingSong action:@"n"];
    }
}

- (IBAction)deleteButton:(UIButton*)sender
{
    if (self.isPlaying == NO) {
        [self.player play];
        self.playing = YES;
        self.picture.alpha = 1.0f;
        self.pictureBlock.image = [UIImage imageNamed:@"albumBlock"];
        [self.pauseButton setBackgroundImage:[UIImage imageNamed:@"pause"]
                                    forState:UIControlStateNormal];
    }
    [self loadPlayListWithType:DELETESONGTYPE];
}

- (IBAction)skipButton:(UIButton*)sender
{
    [self.timer setFireDate:[NSDate distantFuture]];
    [self.player pause];
    if (self.isPlaying == NO) {
        self.picture.alpha = 1.0f;
        self.pictureBlock.image = [UIImage imageNamed:@"albumBlock"];
    }
    [self loadPlayListWithType:SKIPSONGTYPE];
}

#pragma mark - RemoteControl
//添加播放控制器（Remote Control Events）
- (void)remoteControlReceivedWithEvent:(UIEvent*)event
{
    if (event.type == UIEventTypeRemoteControl) {
        switch (event.subtype) {
        case UIEventSubtypeRemoteControlPause:
        case UIEventSubtypeRemoteControlPlay:
            [self pauseButton:nil]; // 切换播放、暂停按钮
            break;
        case UIEventSubtypeRemoteControlNextTrack:
            [self skipButton:nil]; // 播放下一曲按钮
            break;
        default:
            break;
        }
    }
}

// 在锁屏界面显示播放歌曲信息,就是设置一个全局变量的值，当系统处于音乐播放状态时，锁屏界面就会将NowPlayingInfo中的信息展示出来
- (void)configPlayingInfo
{
    if (NSClassFromString(@"MPNowPlayingInfoCenter")) {
        if (self.playingSong.title != nil) {
            NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
            [dict setObject:self.playingSong.title forKey:MPMediaItemPropertyTitle];
            [dict setObject:self.playingSong.artist forKey:MPMediaItemPropertyArtist];
            [dict setObject:[NSNumber
                                numberWithFloat:[self.playingSong.length floatValue]]
                     forKey:MPMediaItemPropertyPlaybackDuration];

            NSData* data = [NSData
                dataWithContentsOfURL:[NSURL URLWithString:self.playingSong.picture]];
            UIImage* posterImage = [UIImage imageWithData:data];
            if (posterImage) {
                [dict setObject:[[MPMediaItemArtwork alloc] initWithImage:posterImage]
                         forKey:MPMediaItemPropertyArtwork];
            }

            [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:dict];
        }
    }
}

@end
