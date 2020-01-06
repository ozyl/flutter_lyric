# flutter_lyric

[![flutter_lyric](https://img.shields.io/badge/ozyl-flutterLyric-blue.svg)](https://github.com/ozyl/flutter_lyric)
[![pub package](https://img.shields.io/pub/v/flutter_lyric.svg)](https://pub.dartlang.org/packages/flutter_lyric)
![GitHub](https://img.shields.io/github/license/ozyl/flutter_lyric.svg)

Music lyric Library .

## Examples运行截图

![pic](https://ftp.bmp.ovh/imgs/2020/01/2f6baab3cce93de9.jpg)

## Usage

### 1. Add library to your pubspec.yaml

latest version: [![pub package](https://img.shields.io/pub/v/flutter_lyric.svg)](https://pub.dartlang.org/packages/flutter_lyric)

```yaml
dependencies:
  flutter_lyric: ^1.0.3 # such as version, you need use the latest version of pub.
```

### 2.new LyricController
```dart
    var controller = LyricController(vsync: this);
```

### 3.LyricStr To LyricList
```dart
  //歌词
  var songLyc =
      "[00:00.000] 作曲 : Maynard Plant/Blaise Plant/菊池拓哉 \n[00:00.226] 作词 : Maynard Plant/Blaise Plant/菊池拓哉\n[00:00.680]明日を照らすよSunshine\n[00:03.570]窓から射し込む…扉開いて\n[00:20.920]Stop!'cause you got me thinking\n[00:22.360]that I'm a little quicker\n[00:23.520]Go!Maybe the rhythm's off,\n[00:25.100]but I will never let you\n[00:26.280]Know!I wish that you could see it for yourself.\n[00:28.560]It's not,it's not,just stop,hey y'all!やだ!\n[00:30.930]I never thought that I would take over it all.\n[00:33.420]And now I know that there's no way I could fall.\n[00:35.970]You know it's on and on and off and on,\n[00:38.210]And no one gets away.\n[00:40.300]僕の夢は何処に在るのか?\n[00:45.100]影も形も見えなくて\n[00:50.200]追いかけていた守るべきもの\n[00:54.860]There's a sunshine in my mind\n[01:02.400]明日を照らすよSunshineどこまでも続く\n[01:07.340]目の前に広がるヒカリの先へ\n[01:12.870]未来の\n[01:15.420]輝く\n[01:18.100]You know it's hard,just take a chance.\n[01:19.670]信じて\n[01:21.289]明日も晴れるかな?\n[01:32.960]ほんの些細なことに何度も躊躇ったり\n[01:37.830]誰かのその言葉いつも気にして\n[01:42.850]そんな弱い僕でも「いつか必ずきっと!」\n[01:47.800]強がり?それも負け惜しみ?\n[01:51.940]僕の夢は何だったのか\n[01:56.720]大事なことも忘れて\n[02:01.680]目の前にある守るべきもの\n[02:06.640]There's a sunshine in my mind\n[02:14.500]明日を照らすよSunshineどこまでも続く\n[02:19.000]目の前に広がるヒカリの先へ\n[02:24.670]未来のSunshine\n[02:27.200]輝くSunshine\n[02:29.900]You know it's hard,just take a chance.\n[02:31.420]信じて\n[02:33.300]明日も晴れるかな?\n[02:47.200]Rain's got me now\n[03:05.650]I guess I'm waiting for that Sunshine\n[03:09.200]Why's It only shine in my mind\n[03:15.960]I guess I'm waiting for that Sunshine\n[03:19.110]Why's It only shine in my mind\n[03:25.970]明日を照らすよSunshineどこまでも続く\n[03:30.690]目の前に広がるヒカリの先へ\n[03:36.400]未来のSunshine\n[03:38.840]輝くSunshine\n[03:41.520]You know it's hard,just take a chance.\n[03:43.200]信じて\n[03:44.829]明日も晴れるかな?\n";
  var lyrics = LyricUtil.formatLyric(songLyc);
```

### 3.new LyricWidget
```dart
    var lyricWidget = LyricWidget(
                    size: Size(double.infinity, double.infinity),
                    lyrics: lyrics,
                    controller: controller,
                  );
```


## Api
### LyricWidget

#### Constructor

| 参数                     | 默认值                     | 描述                                   |
| ------------------------ | -------------------------- | -------------------------------------- |
| lyrics                   |                            | 歌词列表 使用LyricUtil.formatLyric转换 |
| remarkLyrics             |                            | 歌词列表 使用LyricUtil.formatLyric转换 |
| size                     |                            | 歌词布局大小                           |
| controller               |                            | 歌词控制器 用来控制进度、拖动、动画    |
| lyricStyle               | Colors.grey, fontSize: 14  | 歌词样式                               |
| currLyricStyle           | Colors.red, fontSize: 14   | 当前播放歌词样式                       |
| remarkStyle              | Colors.black, fontSize: 14 | 音译/翻译歌词样式                      |
| currRemarkLyricStyle     | currLyricStyle             | 当前音译/翻译歌词样式                  |
| draggingLyricStyle       | lyricStyle                 | 滑动选中的歌词样式                     |
| draggingRemarkLyricStyle | remarkStyle                | 滑动选中的音译/翻译歌词样式            |
| enableDrag               | true                       | 是否启用拖动                           |
| lyricGap                 | 10                         | 歌词跟底部的间距                       |
| remarkLyricGap           | 20                         | 音译/翻译歌词跟底部的间距              |
| lyricMaxWidth            |                            | 歌词最大宽度                           |

### LyricControll

#### Constructor

| 参数                  | 默认值     | 描述                                   |
| --------------------- | ---------- | -------------------------------------- |
| vsync                 | null       | 传入页面对象,切换进度时将含有动画      |
| draggingTimerDuration | seconds: 3 | 歌词列表 使用LyricUtil.formatLyric转换 |

#### Api

| 参数/方法        | 默认值 | 描述                   |
| ---------------- | ------ | ---------------------- |
| progress         | 0      | 通过该参数设置当前进度 |
| isDragging       | false  | 用来判断当前是否拖动   |
| draggingComplete |        | 移动歌词到滑动位置     |
| draggingProgress |        | 当前滑动到歌词的时间   |

