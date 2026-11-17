import { TweetItem } from '../model/TweetItem';
import { XApi } from '../api/XApi';
import { TweetCard } from './TweetCard';
import { CacheStore } from '../model/CacheStore';
import { CacheSettingsStore } from '../model/CacheSettings';
import { VideoAutoplay } from '../model/VideoAutoplay';
import { common } from '@kit.AbilityKit';
import { I18n } from '../model/I18n';

class ProfileFeedRow {
  header: boolean = false;
  year: string = '';
  item: TweetItem = new TweetItem();
  videoIndex: number = 0;
  count: number = 0;
  key: string = '';
}

@Component
export struct ProfileTabPage {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  @StorageProp('profileCacheUpdated') @Watch('onCacheUpdated') profileCacheUpdated: number = 0;
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  cookie: string = '';
  handle: string = '';
  userId: string = '';
  tab: number = 0;
  videoPane: string = 'left';
  bottomInset: number = 76;
  @Prop @Watch('onActiveChanged') active: boolean = false;
  @Prop @Watch('onLoadTick') loadTick: number = 0;
  @Prop ownProfile: boolean = false;
  @Prop preferCache: boolean = false;
  @Prop autoLoad: boolean = true;
  @Prop followed: boolean = false;
  @Prop jumpYear: string = '';
  @Prop @Watch('onJumpRequested') jumpTick: number = 0;
  onYearsChanged: (years: string[], counts: number[]) => void = () => {};
  onLoadDone: (tab: number) => void = () => {};
  onVisibleYear: (year: string) => void = () => {};
  onReply: (item: TweetItem) => void = () => {};
  onQuote: (item: TweetItem) => void = () => {};
  onOpen: (item: TweetItem) => void = () => {};
  onPlay: (item: TweetItem, startTime: number) => void = () => {};
  onImage: (url: string) => void = () => {};
  onOpenQuoted: (id: string) => void = () => {};
  onOpenUser: (handle: string) => void = () => {};
  @State tweets: TweetItem[] = [];
  @State loading: boolean = false;
  @State refreshing: boolean = false;
  @State error: string = '';
  @State cursor: string = '';
  private loadedHandle: string = '';
  private loadedTab: number = -1;
  private autoStarted: boolean = false;
  private listScroller: Scroller = new Scroller();
  private lastYears: string = '';
  private lastVisibleYear: string = '';

  aboutToAppear(): void {
    this.loadFromCache();
    this.emitYears();
    if (this.autoLoad) this.ensureLoaded();
  }

  onActiveChanged(): void {
    if (!this.active) return;
    if (this.loadedHandle != this.handle || this.loadedTab != this.tab) {
      this.loadFromCache();
    } else {
      this.mergeFromCache();
    }
    this.emitYears();
    this.emitCurrentVisibleYear();
    if (this.autoLoad) this.ensureLoaded();
  }

  onLoadTick(): void {
    if (this.loadTick > 0 && this.autoLoad) this.ensureLoaded();
  }

  private onCacheUpdated(): void {
    if (!this.active || !this.ownProfile) return;
    try {
      const cached = CacheStore.loadFor(getContext(this) as common.UIAbilityContext, this.handle, this.tab, this.ownProfile);
      if (cached.length > 0) {
        this.tweets = this.normalize(this.tweets.concat(cached));
        const saved = CacheStore.loadCursor(getContext(this) as common.UIAbilityContext, this.handle, this.tab, this.ownProfile);
        if (this.cursor.length == 0) this.cursor = saved;
      }
    } catch (e) {}
  }

  private mergeFromCache(): void {
    if (!this.ownProfile) return;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const cached = CacheStore.loadFor(context, this.handle, this.tab, this.ownProfile);
      if (cached.length > 0) this.tweets = this.normalize(this.tweets.concat(cached));
      if (this.cursor.length == 0) this.cursor = CacheStore.loadCursor(context, this.handle, this.tab, this.ownProfile);
      this.emitYears();
    } catch (e) {}
  }

  private loadFromCache(): void {
    if (!this.ownProfile) {
      this.tweets = [];
      this.cursor = '';
      this.loadedHandle = this.handle;
      this.loadedTab = this.tab;
      return;
    }
    try {
      const context = getContext(this) as common.UIAbilityContext;
      this.tweets = this.normalize(CacheStore.loadFor(context, this.handle, this.tab, this.ownProfile));
      this.cursor = CacheStore.loadCursor(context, this.handle, this.tab, this.ownProfile);
    } catch (e) {
      this.tweets = [];
      this.cursor = '';
    }
    this.loadedHandle = this.handle;
    this.loadedTab = this.tab;
    this.emitYears();
  }

  private ensureLoaded(): void {
    if (this.loading || this.autoStarted) return;
    if (this.preferCache && this.tweets.length > 0) return;
    this.autoStarted = true;
    this.load(false);
  }

  private query(): string {
    if (this.tab == 1) return `from:${this.handle} filter:replies`;
    if (this.tab == 2) return `from:${this.handle} filter:nativeretweets`;
    return `from:${this.handle} -filter:replies -filter:nativeretweets`;
  }

  private matchesTab(item: TweetItem): boolean {
    if (this.tab == 1) return item.isReply && !item.isRetweet;
    if (this.tab == 2) return item.isRetweet;
    return !item.isReply && !item.isRetweet;
  }

  private tweetTime(item: TweetItem): number {
    const t = new Date(item.createdAt).getTime();
    return isNaN(t) ? 0 : t;
  }

  private normalize(list: TweetItem[]): TweetItem[] {
    const out: TweetItem[] = [];
    for (const item of list) {
      if (item.id.length == 0 || !this.matchesTab(item)) continue;
      let duplicate = false;
      for (const existing of out) {
        if (existing.id == item.id) {
          duplicate = true;
          break;
        }
      }
      if (!duplicate) out.push(item);
    }
    out.sort((a: TweetItem, b: TweetItem): number => {
      const delta = this.tweetTime(b) - this.tweetTime(a);
      if (delta != 0) return delta;
      return a.id > b.id ? -1 : 1;
    });
    return out;
  }

  private feedRows(): ProfileFeedRow[] {
    const rows: ProfileFeedRow[] = [];
    const sorted = this.normalize(this.tweets);
    let lastYear = '';
    let videoIndex = 0;
    let headerIndex = -1;
    for (const item of sorted) {
      const date = new Date(item.createdAt);
      const year = isNaN(date.getTime()) ? this.tr('更早') : `${date.getFullYear()}`;
      if (year != lastYear) {
        const header = new ProfileFeedRow();
        header.header = true;
        header.year = year;
        header.key = `year:${year}`;
        rows.push(header);
        headerIndex = rows.length - 1;
        lastYear = year;
      }
      if (headerIndex >= 0) rows[headerIndex].count += 1;
      const row = new ProfileFeedRow();
      row.item = item;
      row.year = year;
      row.videoIndex = videoIndex;
      row.key = `tweet:${item.id}`;
      rows.push(row);
      videoIndex += 1;
    }
    return rows;
  }

  private years(): string[] {
    const out: string[] = [];
    for (const row of this.feedRows()) {
      if (row.header) out.push(row.year);
    }
    return out;
  }

  private emitYears(): void {
    const list = this.years();
    const counts: number[] = [];
    for (let i = 0; i < list.length; i++) counts.push(0);
    for (const row of this.feedRows()) {
      if (row.header) continue;
      for (let i = 0; i < list.length; i++) {
        if (list[i] == row.year) {
          counts[i] += 1;
          break;
        }
      }
    }
    const key = `${list.join('|')}:${counts.join(',')}`;
    if (key == this.lastYears) return;
    this.lastYears = key;
    this.onYearsChanged(list, counts);
  }

  private emitCurrentVisibleYear(): void {
    if (!this.active) return;
    if (this.lastVisibleYear.length > 0) {
      this.onVisibleYear(this.lastVisibleYear);
      return;
    }
    this.emitVisibleYear(0);
  }

  private emitVisibleYear(startIndex: number): void {
    if (!this.active) return;
    const rows = this.feedRows();
    if (rows.length == 0) return;
    const index = Math.max(0, Math.min(startIndex, rows.length - 1));
    const year = rows[index].year;
    if (year.length == 0 || year == this.lastVisibleYear) return;
    this.lastVisibleYear = year;
    this.onVisibleYear(year);
  }

  private findYearRow(year: string): number {
    const rows = this.feedRows();
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].year == year && (rows[i].header || i == 0)) return i;
    }
    for (let i = 0; i < rows.length; i++) {
      if (rows[i].year == year) return i;
    }
    return -1;
  }

  private async onJumpRequested(): Promise<void> {
    if (!this.active || this.jumpYear.length == 0) return;
    const target = this.jumpYear;
    let guard = 0;
    while (this.findYearRow(target) < 0 && this.cursor.length > 0 && guard < 20) {
      await this.load(true);
      guard += 1;
    }
    const row = this.findYearRow(target);
    if (row >= 0) {
      this.lastVisibleYear = target;
      this.onVisibleYear(target);
      setTimeout(() => {
        try {
          this.listScroller.scrollToIndex(row, true, ScrollAlign.START);
        } catch (e) {}
      }, 60);
    }
  }

  private async applyFreshProgressively(fresh: TweetItem[]): Promise<void> {
    const ordered = this.normalize(fresh).slice(0, 10);
    let working = this.tweets;
    for (const item of ordered) {
      working = this.normalize([item].concat(working.filter((old: TweetItem) => old.id != item.id)));
      this.tweets = working.slice(0, 10);
      await new Promise<void>((resolve) => {
        setTimeout(() => resolve(), 45);
      });
    }
    this.tweets = this.normalize(ordered.concat(working)).slice(0, 10);
  }

  private cachePage(page: TweetItem[], replaceExisting: boolean = false): void {
    if (!this.ownProfile || page.length == 0) return;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const settings = CacheSettingsStore.load(context);
      const ttl = this.ownProfile ? 0 :
        (this.followed ? 7 * 24 * 60 * 60 * 1000 : 24 * 60 * 60 * 1000);
      let maxItems = settings.maxItems;
      if (this.ownProfile) {
        if (this.tab == 0) maxItems = settings.ownPostsMax;
        else if (this.tab == 1) maxItems = settings.ownRepliesMax;
        else maxItems = settings.ownRepostsMax;
      }
      CacheStore.cacheTweets(context, this.handle, this.tab, page,
        maxItems, settings.maxMb, -1, replaceExisting, ttl, this.ownProfile).catch(() => {});
    } catch (e) {}
  }

  private newerThanCached(fresh: TweetItem[]): TweetItem[] {
    let newest = 0;
    for (const item of this.tweets) {
      const t = new Date(item.createdAt).getTime();
      if (!isNaN(t) && t > newest) newest = t;
    }
    if (newest <= 0) return fresh;
    return fresh.filter((item: TweetItem) => {
      const t = new Date(item.createdAt).getTime();
      return !isNaN(t) && t > newest;
    });
  }

  private async prependNewer(items: TweetItem[]): Promise<void> {
    const ordered = this.normalize(items);
    let working = this.tweets;
    for (const item of ordered) {
      working = this.normalize([item].concat(working));
      this.tweets = working;
      await new Promise<void>((resolve) => {
        setTimeout(() => resolve(), 45);
      });
    }
  }

  private failureMessage(e: Object): string {
    const text = `${e}`;
    if (text.indexOf('429') >= 0) return `${text}
${this.tr('建议 15 分钟后再手动刷新')}`;
    if (text.toLowerCase().indexOf('timeout') >= 0 || text.indexOf('网络') >= 0) {
      return `${text}
${this.tr('建议 1 分钟后再手动刷新')}`;
    }
    if (text.indexOf('401') >= 0 || text.indexOf('403') >= 0) {
      return `${text}
${this.tr('请重新登录后再手动刷新')}`;
    }
    return `${text}
${this.tr('建议 5 分钟后再手动刷新')}`;
  }

  private async load(more: boolean): Promise<void> {
    if (this.loading) return;
    if (more && this.cursor.length == 0) return;
    this.loading = true;
    this.error = '';
    try {
      const page = await XApi.userTweetsTab(
        this.cookie, this.userId, this.handle, this.tab, more ? this.cursor : '');
      let toCache: TweetItem[] = page.tweets;
      const updateNewestOnly = !more && this.ownProfile && this.refreshing && this.tweets.length > 0;
      if (updateNewestOnly) {
        const fresh = this.newerThanCached(page.tweets);
        toCache = fresh;
        await this.prependNewer(fresh);
      } else if (!more && this.preferCache && this.tweets.length > 0) {
        this.cursor = page.cursor;
        await this.applyFreshProgressively(page.tweets);
      } else {
        const merged = more ? this.normalize(this.tweets.concat(page.tweets)) :
          this.normalize(page.tweets.concat(this.tweets));
        this.tweets = more ? merged : merged.slice(0, 10);
        this.cursor = page.cursor;
      }
      this.loadedHandle = this.handle;
      const context = getContext(this) as common.UIAbilityContext;
      if (!updateNewestOnly && this.ownProfile) CacheStore.saveCursor(context, this.handle, this.tab, page.cursor, true);
      this.emitYears();
      this.cachePage(toCache, !this.ownProfile && this.tab == 2);
      let replyCount = 0;
      let retweetCount = 0;
      for (const item of page.tweets) {
        if (item.isReply) replyCount += 1;
        if (item.isRetweet) retweetCount += 1;
      }
      console.info(`HMProfileTimeline tweets=${page.tweets.length} replies=${replyCount} retweets=${retweetCount} tab=${this.tab}`);
    } catch (e) {
      this.error = this.failureMessage(e);
      if (!more && this.tweets.length == 0) this.tweets = [];
    } finally {
      this.loading = false;
      if (!more) this.onLoadDone(this.tab);
    }
  }

  private async loadOlder(): Promise<void> {
    if (this.loading) return;
    if (this.cursor.length > 0) {
      await this.load(true);
      return;
    }
    // A cache-only page has no cursor. Seed pagination once, then continue
    // with the older page instead of replacing the cached list.
    await this.load(false);
    if (this.cursor.length > 0) await this.load(true);
  }

  private async refresh(): Promise<void> {
    this.refreshing = true;
    try {
      await this.load(false);
    } finally {
      this.refreshing = false;
    }
  }

  @Builder
  yearHeader(year: string, count: number) {
    Row() {
      Row().width(3).height(16).borderRadius(2)
        .backgroundColor($r('app.color.accent')).margin({ right: 8 })
      Text(year).fontSize(16).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(this.tr(`${count} 条`)).fontSize(10)
        .fontColor($r('app.color.text_secondary')).margin({ left: 7 })
      Divider().layoutWeight(1).strokeWidth(1).color($r('app.color.divider'))
        .margin({ left: 9 })
    }
    .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 5 })
    .backgroundColor(Color.Transparent)
  }

  build() {
    Column() {
      if (this.loading && this.tweets.length == 0) {
        Column() { LoadingProgress().width(28).height(28) }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 && this.tweets.length == 0) {
        Column() {
          Text(this.error).fontSize(13).fontColor('#F4212E').width('100%').textAlign(TextAlign.Center).padding(16)
          Button(this.tr('重试')).onClick(() => this.load(false))
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: this.refreshing }) {
          List({ scroller: this.listScroller }) {
            if (this.tweets.length == 0) {
              ListItem() {
                Text(this.tr('暂无内容')).fontSize(13).fontColor($r('app.color.text_secondary'))
                  .width('100%').textAlign(TextAlign.Center).padding(28)
              }
            } else {
              ForEach(this.feedRows(), (row: ProfileFeedRow) => {
                ListItem() {
                  if (row.header) {
                    this.yearHeader(row.year, row.count)
                  } else {
                    Column() {
                      TweetCard({
                        item: row.item,
                        cookie: this.cookie,
                        onReply: (value: TweetItem) => this.onReply(value),
                        onQuote: (value: TweetItem) => this.onQuote(value),
                        onOpen: (value: TweetItem) => this.onOpen(value),
                        onPlay: (value: TweetItem, startTime: number) => this.onPlay(value, startTime),
                        onImage: (url: string) => this.onImage(url),
                        onOpenQuoted: (id: string) => this.onOpenQuoted(id),
                        onOpenUser: (handle: string) => this.onOpenUser(handle),
                        ownProfileRetweet: this.ownProfile,
                        videoPane: this.videoPane,
                        videoIndex: row.videoIndex
                      })
                      Divider().strokeWidth(1).color($r('app.color.divider'))
                    }
                  }
                }
              }, (row: ProfileFeedRow) => row.key)
            }
            if (this.loading && this.tweets.length > 0) {
              ListItem() {
                Row() {
                  LoadingProgress().width(20).height(20)
                  Text(this.tr('加载更多…')).fontSize(12)
                    .fontColor($r('app.color.text_secondary')).margin({ left: 8 })
                }.width('100%').height(44).justifyContent(FlexAlign.Center)
              }
            }
          }
          .width('100%').height('100%')
          .contentEndOffset(this.bottomInset)
          .onScrollIndex((start: number, end: number) => this.emitVisibleYear(start))
          .onScrollStart(() => VideoAutoplay.onScrollStart())
          .onScrollStop(() => VideoAutoplay.onScrollStop())
          .onReachEnd(() => this.loadOlder())
        }
        .onRefreshing(() => { this.refresh(); })
        .layoutWeight(1).width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor(Color.Transparent)
  }
}
