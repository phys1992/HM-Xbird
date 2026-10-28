import { promptAction } from '@kit.ArkUI';
import { TweetItem } from '../model/TweetItem';
import { HomeFeed } from './HomeFeed';
import { SearchView } from './SearchView';
import { ComposeView } from './ComposeView';

@Component
export struct MainView {
  cookie: string = '';
  onLogout: () => void = () => {};
  @State tab: number = 0;
  @State drawer: boolean = false;
  @State composing: boolean = false;
  @State replyId: string = '';
  @State replyHandle: string = '';
  @State quoteId: string = '';
  @State quoteHandle: string = '';
  @State quoteText: string = '';

  private title(): string {
    return this.tab == 1 ? 'Explore' : 'Home';
  }

  private openReply(item: TweetItem): void {
    this.replyId = item.id;
    this.replyHandle = item.authorHandle;
    this.quoteId = '';
    this.quoteHandle = '';
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

  private resetCompose(): void {
    this.composing = false;
    this.replyId = '';
    this.replyHandle = '';
    this.quoteId = '';
    this.quoteHandle = '';
    this.quoteText = '';
  }

  @Builder
  navItem(index: number, icon: string, label: string) {
    Column() {
      Text(icon).fontSize(22).fontColor(this.tab == index ? '#0F1419' : '#536471')
      if (this.tab == index) {
        Circle({ width: 4, height: 4 }).fill('#1D9BF0').margin({ top: 2 })
      }
    }
    .layoutWeight(1)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .onClick(() => this.tab = index)
  }

  @Builder
  drawerContent() {
    Column() {
      Row() {
        Circle({ width: 48, height: 48 }).fill('#1D9BF0')
        Column() {
          Text('tuichuang').fontSize(16).fontWeight(FontWeight.Bold)
          Text('@signed_in').fontSize(13).fontColor('#536471')
          Row() {
            Text('— Following').fontSize(12).fontColor('#536471')
            Text('— Followers').fontSize(12).fontColor('#536471').margin({ left: 12 })
          }.margin({ top: 4 })
        }.alignItems(HorizontalAlign.Start).margin({ left: 10 })
      }.width('100%').padding(16)

      Divider().strokeWidth(1.5).color('#EFF3F4')
      this.drawerItem('个人资料', 'Profile')
      Blank()
      Divider().strokeWidth(1.5).color('#EFF3F4')
      this.drawerItem('设置与隐私', 'Settings')
      Row() {
        Text('退出登录').fontSize(14).fontColor('#F4212E')
      }.width('100%').padding(16).onClick(() => this.onLogout())
    }
    .width(300).height('100%').backgroundColor('#FFFFFF')
  }

  @Builder
  drawerItem(title: string, tag: string) {
    Row() {
      Text(title).fontSize(15).fontColor('#0F1419')
    }
    .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => {
      promptAction.showToast({ message: `${title} 后续接入` });
      this.drawer = false;
    })
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Row() {
          Button('☰').backgroundColor('#00000000').fontColor('#0F1419').fontSize(20)
            .onClick(() => this.drawer = true)
          Text(this.title()).fontSize(17).fontWeight(FontWeight.Bold).layoutWeight(1)
            .textAlign(TextAlign.Center)
          Button('⚙').backgroundColor('#00000000').fontColor('#0F1419').fontSize(18)
            .onClick(() => promptAction.showToast({ message: '设置后续接入' }))
        }
        .width('100%').height(48).padding({ left: 4, right: 4 })

        Column() {
          if (this.tab == 0) {
            HomeFeed({
              cookie: this.cookie,
              onReply: (item: TweetItem) => this.openReply(item),
              onQuote: (item: TweetItem) => this.openQuote(item)
            })
          } else {
            SearchView({
              cookie: this.cookie,
              onReply: (item: TweetItem) => this.openReply(item),
              onQuote: (item: TweetItem) => this.openQuote(item)
            })
          }
        }
        .width('100%').layoutWeight(1)

        Row() {
          this.navItem(0, '⌂', 'Home')
          this.navItem(1, '⌕', 'Search')
        }
        .width('100%').height(56).backgroundColor('#FFFFFF')
        .border({ width: { top: 1 }, color: '#EFF3F4' })
      }
      .width('100%').height('100%').backgroundColor('#FFFFFF')

      Button('+')
        .width(56).height(56).borderRadius(28)
        .backgroundColor('#0F1419').fontColor('#FFFFFF').fontSize(26)
        .margin({ right: 16, bottom: 72 })
        .onClick(() => {
          this.replyId = '';
          this.quoteId = '';
          this.composing = true;
        })

      if (this.drawer) {
        Row() {
          this.drawerContent()
          Blank().onClick(() => this.drawer = false)
        }
        .width('100%').height('100%')
        .backgroundColor('#66000000')
        .alignItems(VerticalAlign.Top)
      }

      if (this.composing) {
        Column() {
          ComposeView({
            cookie: this.cookie,
            replyToId: this.replyId,
            replyToHandle: this.replyHandle,
            quoteId: this.quoteId,
            quoteHandle: this.quoteHandle,
            quoteText: this.quoteText,
            onClose: () => this.resetCompose()
          })
        }
        .width('100%').height('100%').backgroundColor('#FFFFFF')
      }
    }
    .width('100%').height('100%')
  }
}
