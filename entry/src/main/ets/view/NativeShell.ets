import { display } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { TweetItem } from '../model/TweetItem';
import { SessionStore } from '../model/SessionStore';
import { BackDispatcher } from '../model/BackDispatcher';
import { LoginView } from './LoginView';
import { HomeFeed } from './HomeFeed';
import { SearchView } from './SearchView';
import { ComposeView } from './ComposeView';

@Component
export struct NativeShell {
  @State cookie: string = '';
  @State loggedIn: boolean = false;
  @State tab: number = 0;
  @State paneWidth: number = 360;
  @State expanded: boolean = false;
  @State selected: TweetItem | null = null;
  @State composing: boolean = false;
  @State replyId: string = '';
  @State replyHandle: string = '';
  @State quoteId: string = '';
  @State quoteHandle: string = '';
  @State quoteText: string = '';

  aboutToAppear(): void {
    BackDispatcher.handler = () => this.handleBack();
    const context = getContext(this) as common.UIAbilityContext;
    const saved = SessionStore.loadCookie(context);
    if (saved.length > 0) {
      this.cookie = saved;
      this.loggedIn = true;
    }
    try {
      this.expanded = display.getFoldStatus() == display.FoldStatus.FOLD_STATUS_EXPANDED;
    } catch (e) {}
  }

  aboutToDisappear(): void {
    try {
      display.off('foldStatusChange');
    } catch (e) {}
  }

  private handleBack(): boolean {
    if (this.composing) {
      this.composing = false;
      return true;
    }
    if (this.selected != null) {
      this.selected = null;
      return true;
    }
    if (this.tab != 0) {
      this.tab = 0;
      return true;
    }
    return false;
  }

  private openReply(item: TweetItem): void {
    this.replyId = item.id;
    this.replyHandle = item.authorHandle;
    this.quoteId = '';
    this.quoteText = '';
    this.composing = true;
  }

  private openQuote(item: TweetItem): void {
    this.quoteId = item.id;
    this.quoteHandle = item.authorHandle;
    this.quoteText = item.text;
    this.replyId = '';
    this.replyHandle = '';
    this.composing = true;
  }

  private logout(): void {
    SessionStore.clear(getContext(this) as common.UIAbilityContext);
    this.cookie = '';
    this.loggedIn = false;
    this.selected = null;
    this.tab = 0;
  }

  @Builder
  navItem(index: number, icon: Resource, label: string) {
    Column() {
      Image(icon).width(22).height(22)
        .fillColor(this.tab == index ? '#1D9BF0' : '#536471')
      Text(label).fontSize(10)
        .fontColor(this.tab == index ? '#1D9BF0' : '#536471')
        .margin({ top: 2 })
    }
    .layoutWeight(1).height(52).justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.tab = index;
      this.selected = null;
    })
  }

  @Builder
  bottomBar() {
    Row() {
      this.navItem(0, $r('app.media.ic_home'), '主页')
      this.navItem(1, $r('app.media.ic_search'), '搜索')
      Column() {
        Button() {
          Image($r('app.media.ic_plus')).width(20).height(20).fillColor('#FFFFFF')
        }
        .width(44).height(44).borderRadius(22).backgroundColor('#0F1419')
        .onClick(() => {
          this.replyId = '';
          this.quoteId = '';
          this.composing = true;
        })
      }.layoutWeight(1).height(52).justifyContent(FlexAlign.Center)
      this.navItem(2, $r('app.media.ic_bell'), '通知')
      this.navItem(3, $r('app.media.ic_user'), '我的')
    }
    .width(320).height(60).borderRadius(30)
    .backgroundColor('#F2FFFFFF')
    .shadow({ radius: 16, color: '#1A000000', offsetY: 4 })
    .padding({ left: 6, right: 6 })
    .margin({ bottom: 12 })
  }

  @Builder
  mePage() {
    Column() {
      Row() {
        Circle({ width: 52, height: 52 }).fill('#1D9BF0')
        Column() {
          Text('tuichuang').fontSize(17).fontWeight(FontWeight.Bold)
          Text('已登录 X').fontSize(13).fontColor('#536471').margin({ top: 2 })
        }.alignItems(HorizontalAlign.Start).margin({ left: 12 })
      }.width('100%').padding(16)

      Divider().color('#EFF3F4')
      Row() {
        Text('分栏设置').fontSize(15).layoutWeight(1)
        Text(this.expanded ? '当前已展开' : '折叠屏展开后启用').fontSize(12).fontColor('#536471')
      }.width('100%').padding(16)

      Row() {
        Text('退出登录').fontSize(15).fontColor('#F4212E')
      }.width('100%').padding(16).onClick(() => this.logout())
      Blank()
    }.width('100%').height('100%')
  }

  @Builder
  notificationsPage() {
    Column() {
      Text('通知').fontSize(20).fontWeight(FontWeight.Bold).width('100%').padding(16)
      Text('通知接口将在下一阶段接入').fontSize(14).fontColor('#536471')
      Blank()
    }.width('100%').height('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  detailPane() {
    Column() {
      if (this.selected == null) {
        Text('选择左侧推文').fontSize(15).fontColor('#536471')
      } else {
        Scroll() {
          Column() {
            Row() {
              Circle({ width: 40, height: 40 }).fill('#E1E8ED')
              Column() {
                Text(this.selected!.authorName).fontSize(15).fontWeight(FontWeight.Bold)
                Text(`@${this.selected!.authorHandle}`).fontSize(12).fontColor('#536471')
              }.alignItems(HorizontalAlign.Start).margin({ left: 10 })
            }.width('100%')
            Text(this.selected!.text).fontSize(16).lineHeight(23).margin({ top: 12 })
            if (this.selected!.imageUrl.length > 0) {
              Image(this.selected!.imageUrl).width('100%').aspectRatio(1.7)
                .objectFit(ImageFit.Cover).borderRadius(12).margin({ top: 12 })
            }
            Divider().color('#EFF3F4').margin({ top: 16, bottom: 16 })
            Text('评论接口将在下一阶段接入').fontSize(13).fontColor('#536471')
          }.width('100%').padding(16).alignItems(HorizontalAlign.Start)
        }.layoutWeight(1).width('100%')
      }
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  @Builder
  contentPage() {
    if (this.tab == 0) {
      HomeFeed({
        cookie: this.cookie,
        onReply: (item: TweetItem) => this.openReply(item),
        onQuote: (item: TweetItem) => this.openQuote(item),
        onOpen: (item: TweetItem) => this.selected = item
      })
    } else if (this.tab == 1) {
      SearchView({
        cookie: this.cookie,
        onReply: (item: TweetItem) => this.openReply(item),
        onQuote: (item: TweetItem) => this.openQuote(item)
      })
    } else if (this.tab == 2) {
      this.notificationsPage()
    } else {
      this.mePage()
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (!this.loggedIn) {
        LoginView({
          onLoggedIn: (cookie: string, jsUrls: string) => {
            const context = getContext(this) as common.UIAbilityContext;
            SessionStore.saveCookie(context, cookie);
            SessionStore.saveJsUrls(context, jsUrls);
            this.cookie = cookie;
            this.loggedIn = true;
          }
        })
      } else {
        SideBarContainer(SideBarContainerType.Embed) {
          Column() {
            this.contentPage()
          }.width('100%').height('100%')

          Column() {
            this.detailPane()
          }.width('100%').height('100%')
        }
        .showSideBar(true)
        .sideBarWidth(this.expanded ? this.paneWidth * 0.5 : this.paneWidth)
        .minSideBarWidth(1)
        .maxSideBarWidth(this.paneWidth)
        .minContentWidth(0)
        .showControlButton(false)
        .autoHide(false)
        .width('100%').height('100%')
        .onAreaChange((oldValue: Area, newValue: Area) => {
          const w = parseFloat(`${newValue.width}`);
          if (!isNaN(w)) {
            this.paneWidth = w;
            this.expanded = w >= 600;
          }
        })

        Column() {
          this.bottomBar()
        }
        .width('100%').height(76)
        .justifyContent(FlexAlign.Center)
        .hitTestBehavior(HitTestMode.Transparent)

        if (this.composing) {
          ComposeView({
            cookie: this.cookie,
            replyToId: this.replyId,
            replyToHandle: this.replyHandle,
            quoteId: this.quoteId,
            quoteHandle: this.quoteHandle,
            quoteText: this.quoteText,
            onClose: () => this.composing = false
          })
          .width('100%').height('100%')
        }
      }
    }
    .width('100%').height('100%')
    .backgroundColor('#FFFFFF')
  }
}
