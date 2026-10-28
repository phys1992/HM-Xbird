import { UserProfile } from '../model/UserProfile';
import { XApi } from '../api/XApi';

@Component
export struct UserListPage {
  cookie: string = '';
  userId: string = '';
  kind: string = 'followers';
  title: string = '关注者';
  onClose: () => void = () => {};
  onOpenUser: (handle: string) => void = () => {};
  @State users: UserProfile[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State cursor: string = '';

  aboutToAppear(): void {
    this.load(false);
  }

  private async load(more: boolean): Promise<void> {
    if (this.loading) return;
    if (more && this.cursor.length == 0) return;
    this.loading = true;
    this.error = '';
    try {
      const page = await XApi.userList(this.cookie, this.userId, this.kind, more ? this.cursor : '');
      this.users = more ? this.users.concat(page.users) : page.users;
      this.cursor = page.cursor;
    } catch (e) {
      this.error = `${e}`;
    } finally {
      this.loading = false;
    }
  }

  @Builder
  userRow(item: UserProfile) {
    Column() {
      Row() {
        if (item.avatarUrl.length > 0) {
          Image(item.avatarUrl).width(48).height(48).borderRadius(24)
        } else {
          Circle({ width: 48, height: 48 }).fill($r('app.color.surface_secondary'))
        }
        Column() {
          Row() {
            Text(item.name).fontSize(15).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).maxLines(1).layoutWeight(1)
            if (item.verified) {
              Text('✓').fontSize(10).fontColor('#FFFFFF')
                .width(16).height(16).textAlign(TextAlign.Center)
                .backgroundColor($r('app.color.accent')).borderRadius(8).margin({ left: 4 })
            }
          }.width('100%')
          Text(`@${item.handle}`).fontSize(12).fontColor($r('app.color.text_secondary')).margin({ top: 2 })
          if (item.description.length > 0) {
            Text(item.description).fontSize(13).lineHeight(18).fontColor($r('app.color.text_primary'))
              .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 4 })
          }
        }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 })
      }
      .width('100%').padding(14)
      .onClick(() => this.onOpenUser(item.handle))
      Divider().strokeWidth(1).color($r('app.color.divider')).margin({ left: 74 })
    }.width('100%')
  }

  build() {
    Column() {
      Row() {
        Button() {
          Text('‹').fontSize(26).fontColor($r('app.color.text_primary'))
        }
        .width(40).height(40).borderRadius(20)
        .backgroundColor($r('app.color.surface'))
        .onClick(() => this.onClose())
        Text(this.title).fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).margin({ left: 14 }).layoutWeight(1)
      }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 10 })

      if (this.loading && this.users.length == 0) {
        Column() { LoadingProgress().width(30).height(30) }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 && this.users.length == 0) {
        Column() {
          Text(this.error).fontSize(13).fontColor('#F4212E').padding(16)
          Button('重试').onClick(() => this.load(false))
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.users.length == 0) {
        Text('暂无用户').fontSize(14).fontColor($r('app.color.text_secondary'))
          .width('100%').textAlign(TextAlign.Center).layoutWeight(1)
      } else {
        List() {
          ForEach(this.users, (item: UserProfile) => {
            ListItem() { this.userRow(item) }
          }, (item: UserProfile) => item.id)
          if (this.loading) {
            ListItem() {
              Row() { LoadingProgress().width(18).height(18) }
                .width('100%').justifyContent(FlexAlign.Center).padding(12)
            }
          }
        }
        .layoutWeight(1).width('100%').backgroundColor($r('app.color.bg'))
        .onReachEnd(() => this.load(true))
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.bg'))
  }
}
