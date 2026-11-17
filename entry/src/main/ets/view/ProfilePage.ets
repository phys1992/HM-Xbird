import { TweetItem } from '../model/TweetItem';
import { UserProfile } from '../model/UserProfile';
import { XApi } from '../api/XApi';
import { ProfileTabPage } from './ProfileTabPage';
import { I18n } from '../model/I18n';
import { UserListPage } from './UserListPage';
import { SettingsPageHeader } from './SettingsPageHeader';
import { ProfileCache } from '../model/ProfileCache';
import { CacheStore } from '../model/CacheStore';
import { common } from '@kit.AbilityKit';

@Component
export struct ProfilePage {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  bottomInset: number = 76;
  embedded: boolean = false;
  videoPane: string = 'left';
  cookie: string = '';
  @Prop @Watch('onHandleChanged') handle: string = '';
  @Prop @Watch('onKnownProfileChanged') knownProfile: UserProfile | null = null;
  onClose: () => void = () => {};
  onEditProfile: () => void = () => {};
  onOpenConnections: (kind: string, userId: string, title: string) => void = () => {};
  onOpenTweet: (item: TweetItem) => void = () => {};
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onPlay: (item: TweetItem, startTime: number) => void = () => {};
  onImage: (url: string) => void = () => {};
  onOpenQuoted: (id: string) => void = () => {};
  onOpenUser: (handle: string) => void = () => {};
  @State profile: UserProfile | null = null;
  @State loading: boolean = true;
  @State error: string = '';
  @State activeTab: number = 0;
  @State displayIndex: number = 0;
  @State indicatorX: number = 0;
  @State tabBarW: number = 0;
  @State years0: string[] = [];
  @State years1: string[] = [];
  @State years2: string[] = [];
  @State yearCounts0: number[] = [];
  @State yearCounts1: number[] = [];
  @State yearCounts2: number[] = [];
  @State showYearMenu: boolean = false;
  @State userListVisible: boolean = false;
  @State userListKind: string = 'followers';
  @State userListId: string = '';
  @State userListTitle: string = '';
  @State visibleYear0: string = '';
  @State visibleYear1: string = '';
  @State visibleYear2: string = '';
  @State jumpYear: string = '';
  @State jumpTick: number = 0;
  @State loadTick1: number = 0;
  @State loadTick2: number = 0;
  @State private autoLoadTabs: boolean = false;
  private initialTabsTriggered: boolean = false;
  private prefetched1: boolean = false;
  private prefetched2: boolean = false;
  private controller: SwiperController = new SwiperController();
  private readonly indicatorW: number = 52;

  onHandleChanged(): void {
    this.profile = null;
    this.activeTab = 0;
    this.prefetched1 = false;
    this.prefetched2 = false;
    this.initialTabsTriggered = false;
    this.refreshAutoLoad();
    this.load(false);
  }

  onKnownProfileChanged(): void {
    if (this.knownProfile != null && this.knownProfile.handle == this.handle) {
      this.profile = this.knownProfile;
    }
  }

  aboutToAppear(): void {
    this.refreshAutoLoad();
    this.load(false);
  }

  private refreshAutoLoad(): void {
    if (!this.ownProfile()) {
      this.autoLoadTabs = true;
      return;
    }
    try {
      const context = getContext(this) as common.UIAbilityContext;
      let cached = false;
      for (let tab = 0; tab < 3; tab++) {
        if (CacheStore.loadFor(context, this.handle, tab, this.ownProfile()).length > 0) {
          cached = true;
          break;
        }
      }
      this.autoLoadTabs = !cached;
    } catch (e) {
      this.autoLoadTabs = true;
    }
  }

  private triggerInitialTabs(): void {
    if (!this.autoLoadTabs || this.initialTabsTriggered) return;
    this.initialTabsTriggered = true;
    this.loadTick1 += 1;
    this.loadTick2 += 1;
  }

  private ownProfile(): boolean {
    return this.knownProfile != null && this.knownProfile.handle == this.handle;
  }

  private profileTitle(): string {
    if (this.knownProfile != null && this.knownProfile.handle == this.handle) {
      return this.tr('我的资料');
    }
    return this.tr('用户资料');
  }

  private async load(force: boolean): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      if (this.knownProfile != null && this.knownProfile.handle == this.handle) {
        this.profile = this.knownProfile;
        this.loading = false;
        this.triggerInitialTabs();
        return;
      }
      if (!force) {
        const cached = ProfileCache.load(getContext(this) as common.UIAbilityContext, this.handle);
        if (cached != null) {
          this.profile = cached;
          this.loading = false;
          return;
        }
      }
      const profile = await XApi.userByScreenName(this.cookie, this.handle);
      this.profile = profile;
      ProfileCache.save(getContext(this) as common.UIAbilityContext, profile);
      this.triggerInitialTabs();
    } catch (e) {
      this.error = `${e}`;
    } finally {
      this.loading = false;
    }
  }

  private async refresh(): Promise<void> {
    if (this.knownProfile != null && this.knownProfile.handle == this.handle) {
      this.loading = true;
      try {
        this.profile = await XApi.viewerProfile(this.cookie);
        if (this.profile != null) {
          ProfileCache.save(getContext(this) as common.UIAbilityContext, this.profile);
          ProfileCache.saveSelf(getContext(this) as common.UIAbilityContext, this.profile);
        }
      }
      catch (e) { this.error = `${e}`; }
      finally { this.loading = false; }
      return;
    }
    this.load(true);
  }

  private hasBio(): boolean {
    return this.profile != null && this.profile.description.trim().length > 0;
  }

  private joined(): string {
    if (this.profile == null || this.profile.createdAt.length == 0) return '';
    const date = new Date(this.profile.createdAt);
    if (isNaN(date.getTime())) return '';
    return this.tr(`${date.getFullYear()}年${date.getMonth() + 1}月加入`);
  }

  private yearsFor(index: number): string[] {
    if (index == 1) return this.years1;
    if (index == 2) return this.years2;
    return this.years0;
  }

  private countsFor(index: number): number[] {
    if (index == 1) return this.yearCounts1;
    if (index == 2) return this.yearCounts2;
    return this.yearCounts0;
  }

  private tabLeft(index: number): number {
    if (this.tabBarW <= 0) return 0;
    const slot = this.tabBarW / 3;
    return index * slot + (slot - this.indicatorW) / 2;
  }

  private animateIndicatorTo(index: number, duration: number): void {
    const target = this.tabLeft(index);
    if (duration <= 0) {
      this.indicatorX = target;
      return;
    }
    animateTo({ duration: duration, curve: Curve.EaseOut }, () => {
      this.indicatorX = target;
    });
  }

  private updateSwipeIndicator(index: number, offset: number): void {
    if (this.tabBarW <= 0) return;
    const slot = this.tabBarW / 3;
    const ratio = Math.min(1, Math.abs(offset) / this.tabBarW);
    let next = index;
    if (offset < 0 && index < 2) next = index + 1;
    else if (offset > 0 && index > 0) next = index - 1;
    const fraction = index + (next - index) * ratio;
    this.indicatorX = fraction * slot + (slot - this.indicatorW) / 2;
    this.displayIndex = ratio > 0.5 ? next : index;
  }

  private countFor(year: string): number {
    const years = this.yearsFor(this.activeTab);
    const counts = this.countsFor(this.activeTab);
    for (let i = 0; i < years.length; i++) {
      if (years[i] == year) return i < counts.length ? counts[i] : 0;
    }
    return 0;
  }

  private visibleYearFor(index: number): string {
    if (index == 1) return this.visibleYear1;
    if (index == 2) return this.visibleYear2;
    return this.visibleYear0;
  }

  private currentYear(): string {
    const list = this.yearsFor(this.activeTab);
    const visible = this.visibleYearFor(this.activeTab);
    for (const year of list) {
      if (year == visible) return visible;
    }
    return list.length > 0 ? list[0] : '';
  }

  private handleYears(tab: number, years: string[], counts: number[]): void {
    if (tab == 1) {
      this.years1 = years;
      this.yearCounts1 = counts;
    } else if (tab == 2) {
      this.years2 = years;
      this.yearCounts2 = counts;
    } else {
      this.years0 = years;
      this.yearCounts0 = counts;
    }
  }

  private handleVisibleYear(tab: number, year: string): void {
    if (year.length == 0) return;
    if (tab == 1) this.visibleYear1 = year;
    else if (tab == 2) this.visibleYear2 = year;
    else this.visibleYear0 = year;
  }

  private openConnections(kind: string, title: string): void {
    if (this.profile == null) return;
    this.userListKind = kind;
    this.userListId = this.profile!.id;
    this.userListTitle = title;
    this.userListVisible = true;
  }

  private requestYearJump(year: string): void {
    if (year.length == 0) return;
    if (this.activeTab == 1) this.visibleYear1 = year;
    else if (this.activeTab == 2) this.visibleYear2 = year;
    else this.visibleYear0 = year;
    this.jumpYear = year;
    this.jumpTick += 1;
  }


  private switchTab(index: number): void {
    this.displayIndex = index;
    this.activeTab = index;
    this.animateIndicatorTo(index, 280);
    this.controller.changeIndex(index, true);
  }

  @Builder
  tabItem(index: number, title: string) {
    Column() {
      Text(this.tr(title)).fontSize(14)
        .fontWeight(this.displayIndex == index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.displayIndex == index ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
    }
    .layoutWeight(1).height(48).justifyContent(FlexAlign.Center)
    .onClick(() => this.switchTab(index))
  }

  @Builder
  yearMenuBuilder() {
    Column() {
      Text(this.tr('跳转到年份'))
        .fontSize(10).fontColor($r('app.color.text_secondary'))
        .width('100%').padding({ left: 10, right: 10, top: 5, bottom: 5 })
      ForEach(this.yearsFor(this.activeTab), (year: string, index: number) => {
        Row() {
          Text(year).fontSize(14)
            .fontColor(year == this.currentYear() ? $r('app.color.accent') : $r('app.color.text_primary'))
            .fontWeight(year == this.currentYear() ? FontWeight.Medium : FontWeight.Normal)
          Blank()
          Text(`${this.countFor(year)}`)
            .fontSize(10).fontColor($r('app.color.text_secondary')).margin({ right: 8 })
          if (year == this.currentYear()) {
            Text('✓').fontSize(12).fontColor($r('app.color.accent')).width(14)
          } else {
            Row().width(14)
          }
        }
        .width('100%').height(38).padding({ left: 10, right: 8 })
        .onClick(() => {
          this.requestYearJump(year);
          this.showYearMenu = false;
        })
      }, (year: string) => year)
      Divider().strokeWidth(1).color($r('app.color.divider')).margin({ left: 10, right: 10, top: 3 })
      Text(this.tr('未加载的年份需要先加载更早分页'))
        .fontSize(9).fontColor($r('app.color.text_secondary'))
        .width('100%').padding({ left: 10, right: 10, top: 7, bottom: 6 })
    }
    .width('100%')
  }

  private onTabLoadDone(tab: number): void {
    // Do not prefetch inactive tabs. Profile timelines share a strict X rate
    // limit; loading all three tabs on entry was the main source of HTTP 429.
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
      if (this.embedded) {
        SettingsPageHeader({ title: this.profileTitle() })
      } else {
        Row() {
          Button() {
            Text('‹').fontSize(27).fontColor($r('app.color.text_primary'))
          }
          .width(40).height(40).borderRadius(20)
          .backgroundColor($r('app.color.surface'))
          .onClick(() => this.onClose())
          Text(this.profileTitle()).fontSize(26).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).margin({ left: 10 }).layoutWeight(1)
        }.width('100%').height(52)
        .padding({ left: 16, right: 20, top: 8, bottom: 8 })
      }

      if (this.profile == null) {
        Row() {
          Text(`@${this.handle}`).fontSize(17).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).layoutWeight(1)
        }.width('100%').height(40).padding({ left: 8, right: 12 })
      }

      if (this.loading && this.profile == null) {
        Column() { LoadingProgress().width(32).height(32) }
          .layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 && this.profile == null) {
        Column() {
          Text(this.error).fontSize(13).fontColor('#F4212E').padding(16)
          Button(this.tr('重试')).onClick(() => this.load(true))
        }.layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.profile != null) {
        Column() {
        Column() {
          if (this.profile!.bannerUrl.length > 0) {
            Stack({ alignContent: Alignment.TopStart }) {
              Image(this.profile!.bannerUrl).width('100%').height(64).objectFit(ImageFit.Cover)
            }.width('100%').height(64)
          }

          Row() {
            if (this.profile!.avatarUrl.length > 0) {
              Image(this.profile!.avatarUrl).width(52).height(52).borderRadius(26)
                .border({ width: 2, color: $r('app.color.bg') })
            } else {
              Circle({ width: 52, height: 52 }).fill($r('app.color.accent'))
                .border({ width: 2, color: $r('app.color.bg') })
            }
            Column() {
              Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
                Text(this.profile!.name).fontSize(17).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary')).margin({ right: 5 })
                if (this.profile!.verified) {
                  Text('✓').fontSize(9).fontColor('#FFFFFF')
                    .width(15).height(15).textAlign(TextAlign.Center)
                    .backgroundColor($r('app.color.accent')).borderRadius(8).margin({ right: 5 })
                }
                Text(`@${this.profile!.handle}`).fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
              }.width('100%')
            }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 11 })
            if (this.ownProfile()) {
              Button(this.tr('编辑')).height(30).fontSize(12)
                .backgroundColor($r('app.color.surface_secondary')).fontColor($r('app.color.text_primary'))
                .margin({ left: 6 })
                .onClick(() => this.onEditProfile())
            } else {
              Button(this.tr('刷新')).height(30).fontSize(12)
                .backgroundColor($r('app.color.surface_secondary')).fontColor($r('app.color.text_primary'))
                .margin({ left: 6 })
                .onClick(() => this.refresh())
            }
          }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 4 })
          .alignItems(VerticalAlign.Center)

          Column() {
            if (this.hasBio()) {
              Text(this.profile!.description).fontSize(13).lineHeight(18)
                .fontColor($r('app.color.text_primary')).maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
            }

            Row() {
              Column() {
                Text(`${this.profile!.following}`).fontSize(17).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Text(this.tr('正在关注')).fontSize(11).fontColor($r('app.color.text_secondary')).margin({ top: 2 })
              }
              .layoutWeight(1).height(48)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .onClick(() => this.openConnections('following', this.tr('正在关注')))

              Divider().vertical(true).height(24).color($r('app.color.divider'))

              Column() {
                Text(`${this.profile!.followers}`).fontSize(17).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Text(this.tr('关注者')).fontSize(11).fontColor($r('app.color.text_secondary')).margin({ top: 2 })
              }
              .layoutWeight(1).height(48)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .onClick(() => this.openConnections('followers', this.tr('关注者')))
            }
            .width('100%').height(48)
            .backgroundColor($r('app.color.surface_secondary')).borderRadius(14)
            .margin({ top: 10 })
          }.width('100%').padding({ left: 16, right: 16, top: 6, bottom: 12 })
        }
        .width('100%')
        .backgroundColor($r('app.color.surface'))
        .borderRadius(20).clip(true)
        .margin({ top: this.embedded ? 0 : 6 })

        Column() {
        Row() {
          Stack({ alignContent: Alignment.BottomStart }) {
            Row() {
              this.tabItem(0, '发帖')
              this.tabItem(1, '回复')
              this.tabItem(2, '转帖')
            }.width('100%').height(48)
            .onAreaChange((oldValue: Area, newValue: Area) => {
              const w = parseFloat(`${newValue.width}`);
              if (!isNaN(w) && w > 0) {
                this.tabBarW = w;
                this.indicatorX = this.tabLeft(this.displayIndex);
              }
            })

            Rect({ width: this.indicatorW, height: 3 })
              .fill($r('app.color.accent'))
              .radius(2)
              .position({ x: this.indicatorX, y: 45 })
          }.layoutWeight(1).height(48)

          Divider().vertical(true).height(24).color($r('app.color.divider')).margin({ left: 6, right: 6 })

          if (this.yearsFor(this.activeTab).length > 0) {
            Row() {
              Text(this.currentYear())
                .fontSize(14).fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.accent'))
              Image($r('app.media.ic_chevron_down'))
                .width(13).height(13)
                .fillColor($r('app.color.accent'))
                .margin({ left: 3 })
            }
            .height(32).padding({ left: 8, right: 8 })
            .alignItems(VerticalAlign.Center)
            .margin({ right: 10 })
            .onClick(() => { this.showYearMenu = !this.showYearMenu; })
            .bindPopup(this.showYearMenu, {
              builder: this.yearMenuBuilder,
              placement: Placement.Bottom,
              popupColor: $r('app.color.surface'),
              backgroundBlurStyle: BlurStyle.NONE,
              width: 196,
              autoCancel: true,
              onStateChange: (event) => {
                if (!event.isVisible) this.showYearMenu = false;
              }
            })
            .accessibilityText(this.tr('选择年份'))
          } else {
            Row().width(58).height(30).margin({ right: 10 })
          }
        }.width('100%')
        Divider().strokeWidth(1).color($r('app.color.divider'))

        Swiper(this.controller) {
          ProfileTabPage({
            cookie: this.cookie, handle: this.profile!.handle, userId: this.profile!.id, tab: 0,
            loadTick: 0, ownProfile: this.ownProfile(), preferCache: true, autoLoad: this.autoLoadTabs, followed: this.profile != null ? this.profile.isFollowing : false, onLoadDone: (tab: number) => this.onTabLoadDone(tab),
            active: this.activeTab == 0, bottomInset: this.bottomInset, videoPane: this.videoPane,
            jumpYear: this.jumpYear, jumpTick: this.jumpTick,
            onYearsChanged: (years: string[], counts: number[]) => this.handleYears(0, years, counts),
            onVisibleYear: (year: string) => this.handleVisibleYear(0, year),
            onReply: (item: TweetItem) => this.onReply(item),
            onQuote: (item: TweetItem) => this.onQuote(item),
            onOpen: (item: TweetItem) => this.onOpenTweet(item),
            onPlay: (item: TweetItem, time: number) => this.onPlay(item, time),
            onImage: (url: string) => this.onImage(url),
            onOpenQuoted: (id: string) => this.onOpenQuoted(id),
            onOpenUser: (handle: string) => this.onOpenUser(handle)
          })
          ProfileTabPage({
            cookie: this.cookie, handle: this.profile!.handle, userId: this.profile!.id, tab: 1,
            loadTick: this.loadTick1, ownProfile: this.ownProfile(), preferCache: true, autoLoad: this.autoLoadTabs, followed: this.profile != null ? this.profile.isFollowing : false, onLoadDone: (tab: number) => this.onTabLoadDone(tab),
            active: this.activeTab == 1, bottomInset: this.bottomInset, videoPane: this.videoPane,
            jumpYear: this.jumpYear, jumpTick: this.jumpTick,
            onYearsChanged: (years: string[], counts: number[]) => this.handleYears(1, years, counts),
            onVisibleYear: (year: string) => this.handleVisibleYear(1, year),
            onReply: (item: TweetItem) => this.onReply(item),
            onQuote: (item: TweetItem) => this.onQuote(item),
            onOpen: (item: TweetItem) => this.onOpenTweet(item),
            onPlay: (item: TweetItem, time: number) => this.onPlay(item, time),
            onImage: (url: string) => this.onImage(url),
            onOpenQuoted: (id: string) => this.onOpenQuoted(id),
            onOpenUser: (handle: string) => this.onOpenUser(handle)
          })
          ProfileTabPage({
            cookie: this.cookie, handle: this.profile!.handle, userId: this.profile!.id, tab: 2,
            loadTick: this.loadTick2, ownProfile: this.ownProfile(), preferCache: true, autoLoad: this.autoLoadTabs, followed: this.profile != null ? this.profile.isFollowing : false, onLoadDone: (tab: number) => this.onTabLoadDone(tab),
            active: this.activeTab == 2, bottomInset: this.bottomInset, videoPane: this.videoPane,
            jumpYear: this.jumpYear, jumpTick: this.jumpTick,
            onYearsChanged: (years: string[], counts: number[]) => this.handleYears(2, years, counts),
            onVisibleYear: (year: string) => this.handleVisibleYear(2, year),
            onReply: (item: TweetItem) => this.onReply(item),
            onQuote: (item: TweetItem) => this.onQuote(item),
            onOpen: (item: TweetItem) => this.onOpenTweet(item),
            onPlay: (item: TweetItem, time: number) => this.onPlay(item, time),
            onImage: (url: string) => this.onImage(url),
            onOpenQuoted: (id: string) => this.onOpenQuoted(id),
            onOpenUser: (handle: string) => this.onOpenUser(handle)
          })
        }
        .index(this.activeTab)
        .onChange((index: number) => {
          this.activeTab = index;
          this.displayIndex = index;
          if (this.tabBarW > 0) this.indicatorX = this.tabLeft(index);
        })
        .onAnimationStart((index: number, targetIndex: number, event: SwiperAnimationEvent) => {
          this.displayIndex = targetIndex;
          this.animateIndicatorTo(targetIndex, 280);
        })
        .onGestureSwipe((index: number, event: SwiperAnimationEvent) => {
          this.updateSwipeIndicator(index, event.currentOffset);
        })
        .onAnimationEnd((index: number, event: SwiperAnimationEvent) => {
          this.activeTab = index;
          this.displayIndex = index;
          this.indicatorX = this.tabLeft(index);
        })
        .indicator(false).loop(false)
        .duration(280).curve(Curve.EaseOut)
        .cachedCount(3)
        .layoutWeight(1).width('100%')
        }
        .layoutWeight(1).width('100%')
        .backgroundColor($r('app.color.surface'))
        .borderRadius(20).clip(true)
        .margin({ top: 10, bottom: 8 })
        }
        .layoutWeight(1).width('100%').padding({ left: 16, right: 16 })
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.bg'))

      if (this.userListVisible) {
        UserListPage({
          cookie: this.cookie,
          userId: this.userListId,
          kind: this.userListKind,
          title: this.userListTitle,
          onClose: () => { this.userListVisible = false; },
          onOpenUser: (handle: string) => {
            this.userListVisible = false;
            this.onOpenUser(handle);
          }
        })
          .width('100%').height('100%')
          .backgroundColor($r('app.color.bg'))
      }
    }.width('100%').height('100%')
  }
}
