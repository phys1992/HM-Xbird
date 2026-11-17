import { I18n } from '../model/I18n';
import { SettingsPageHeader } from './SettingsPageHeader';
import { common } from '@kit.AbilityKit';
import { SearchHistoryStore } from '../model/SearchHistoryStore';
import { CacheStore } from '../model/CacheStore';
import { AdaptiveSlider, AdaptiveSliderConfig } from './AdaptiveSlider';
import { ActionSheetDialog, DialogOption } from './ActionSheetDialog';

@Component
export struct CacheSettingsPage {
  @StorageProp('clientLang') clientLanguage: string = 'zh';
  private tr(value: string): string {
    return this.clientLanguage.length >= 0 ? I18n.t(value) : I18n.t(value);
  }

  @Prop bottomInset: number = 88;
  @Prop showBack: boolean = false;
  @Prop maxMb: number = 512;
  @Prop usedMb: number = 0;
  @Prop ownUsedMb: number = 0;
  @Prop ownPostsMax: number = 100;
  @Prop ownRepliesMax: number = 100;
  @Prop ownRepostsMax: number = 100;
  @Prop clearBrowsingOnExit: boolean = false;
  onClose: () => void = () => {};
  onMaxMbChange: (value: number) => void = () => {};
  onOwnPostsMaxChange: (value: number) => void = () => {};
  onOwnRepliesMaxChange: (value: number) => void = () => {};
  onOwnRepostsMaxChange: (value: number) => void = () => {};
  onClearBrowsingOnExitChange: (value: boolean) => void = () => {};
  onClearBrowsing: () => void = () => {};
  onClearSearch: () => void = () => {};
  onClearMyData: () => void = () => {};
  onClearAll: () => void = () => {};

  @State private ownCounts: number[] = [0, 0, 0];
  @State private historyMax: number = 10;
  @State private clearSearchOnExit: boolean = false;


  private readonly ownValues: number[] = [100, 200, 500, 0];
  private readonly mbValues: number[] = [128, 256, 512, 1024];
  private readonly historyLimits: number[] = [10, 20, 30, 50];
  private ownConfig: AdaptiveSliderConfig = AdaptiveSliderConfig.fixed(4);
  private maxMbConfig: AdaptiveSliderConfig = AdaptiveSliderConfig.fixed(4);
  private historyConfig: AdaptiveSliderConfig = AdaptiveSliderConfig.fixed(4);
  private clearDialog: CustomDialogController = new CustomDialogController({
    builder: ActionSheetDialog({
      title: '清除缓存',
      message: '选择要清除的内容',
      options: [
        new DialogOption('清除浏览历史', '主页时间线和其他浏览缓存', false, () => this.onClearBrowsing(),
          $r('app.media.ic_dialog_history')),
        new DialogOption('清除搜索历史', '搜索词条和当前结果快照', false, () => this.onClearSearch(),
          $r('app.media.ic_search')),
        new DialogOption('清除我的资料', '我的发帖、回复、转帖缓存', false, () => this.onClearMyData(),
          $r('app.media.ic_user')),
        new DialogOption('清除全部缓存', '以上三类缓存全部清除', true, () => this.onClearAll(),
          $r('app.media.ic_dialog_cache_all'))
      ]
    }),
    autoCancel: true,
    alignment: DialogAlignment.Bottom,
    customStyle: true,
    offset: { dx: 0, dy: -12 }
  });

  aboutToAppear(): void {
    const context = getContext(this) as common.UIAbilityContext;
    this.ownCounts = [CacheStore.ownCount(context, 0), CacheStore.ownCount(context, 1),
      CacheStore.ownCount(context, 2)];
    this.historyMax = SearchHistoryStore.maxEntries(context);
    this.clearSearchOnExit = SearchHistoryStore.clearOnExit(context);
  }

  private safeMb(value: number): number {
    return value > 0 && value < 1024 * 1024 ? value : 0;
  }


  private setClearOnExit(value: boolean): void {
    this.clearSearchOnExit = value;
    SearchHistoryStore.setClearOnExit(getContext(this) as common.UIAbilityContext, value);
  }

  private setHistoryMax(value: number): void {
    const index = Math.max(0, Math.min(3, Math.round(value * 3)));
    this.historyMax = this.historyLimits[index];
    const context = getContext(this) as common.UIAbilityContext;
    SearchHistoryStore.setMaxEntries(context, this.historyMax);
    SearchHistoryStore.load(context);
  }

  private ownValue(limit: number): number {
    const index = this.ownValues.indexOf(limit);
    return (index < 0 ? 0 : index) / 3;
  }

  private ownLimit(value: number): number {
    const index = Math.max(0, Math.min(3, Math.round(value * 3)));
    return this.ownValues[index];
  }

  private maxMbValue(): number {
    const index = this.mbValues.indexOf(this.maxMb);
    return (index < 0 ? 2 : index) / 3;
  }

  private maxMbLimit(value: number): number {
    const index = Math.max(0, Math.min(3, Math.round(value * 3)));
    return this.mbValues[index];
  }

  private historyMaxValue(): number {
    const index = this.historyLimits.indexOf(this.historyMax);
    return (index < 0 ? 0 : index) / 3;
  }

  private mbText(): string {
    return this.maxMb >= 1024 ? `${this.maxMb / 1024} GB` : `${this.maxMb} MB`;
  }

  private mbStepText(value: number): string {
    return value >= 1024 ? `${value / 1024} GB` : `${value} MB`;
  }

  private percentValue(used: number, limit: number): number {
    if (limit <= 0) return 0;
    return Math.max(0, Math.min(100, Math.round(used * 100 / limit)));
  }

  private percentText(used: number, limit: number): string {
    if (limit <= 0) return '';
    return `${this.percentValue(used, limit)}%`;
  }

  private countUnit(value: number): string {
    if (!I18n.isEnglish()) return '条';
    return value == 1 ? 'post' : 'posts';
  }

  private countLimitText(limit: number): string {
    if (limit == 0) return this.tr('无限制');
    return `${limit} ${this.countUnit(limit)}`;
  }

  private entriesText(value: number): string {
    if (!I18n.isEnglish()) return `${value} 条`;
    return `${value} ${value == 1 ? 'entry' : 'entries'}`;
  }

  private ownTotalCount(): number {
    return this.ownCounts[0] + this.ownCounts[1] + this.ownCounts[2];
  }

  private ownTotalLimit(): number {
    if (this.ownPostsMax == 0 || this.ownRepliesMax == 0 || this.ownRepostsMax == 0) return 0;
    return this.ownPostsMax + this.ownRepliesMax + this.ownRepostsMax;
  }


  private showClearMenu(): void {
    this.clearDialog.open();
  }

  @Builder
  sectionTitle(title: string) {
    Text(this.tr(title)).fontSize(13).fontColor($r('app.color.text_secondary'))
      .width('100%').padding({ left: 4, top: 20, bottom: 8 })
  }


  build() {
    Column() {
      SettingsPageHeader({ title: '本地缓存', showBack: this.showBack, onBack: () => this.onClose() })

      Scroll() {
        Column() {
          this.sectionTitle('我的资料')

          Column() {
            Row() {
              Text(this.tr('已缓存')).fontSize(13).fontColor($r('app.color.text_secondary')).layoutWeight(1)
              Text(`${this.ownUsedMb.toFixed(1)} MB`).fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }.width('100%').padding({ left: 16, right: 16, top: 15 })
            Row() {
              Row() {
                Text(this.ownTotalLimit() > 0 ? `${this.ownTotalCount()}` :
                  `${this.ownTotalCount()} ${this.countUnit(this.ownTotalCount())}`)
                  .fontSize(22).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
                Text(this.ownTotalLimit() > 0 ?
                  ` / ${this.ownTotalLimit()} ${this.countUnit(this.ownTotalLimit())}` :
                  ` / ${this.tr('无限制')}`)
                  .fontSize(12).fontColor($r('app.color.text_secondary')).margin({ left: 2, bottom: 3 })
              }.alignItems(VerticalAlign.Bottom).layoutWeight(1)
              if (this.ownTotalLimit() > 0) {
                Text(this.percentText(this.ownTotalCount(), this.ownTotalLimit()))
                  .fontSize(13).fontColor($r('app.color.accent'))
              }
            }.width('100%').padding({ left: 16, right: 16, top: 8, bottom: 5 })
            if (this.ownTotalLimit() > 0) {
              Stack({ alignContent: Alignment.Start }) {
                Row().width('100%').height(4).borderRadius(2).backgroundColor($r('app.color.divider'))
                Row().width(`${this.percentValue(this.ownTotalCount(), this.ownTotalLimit())}%`)
                  .height(4).borderRadius(2).backgroundColor($r('app.color.accent'))
              }.width('100%').height(4).padding({ left: 16, right: 16 })
            }
            Divider().strokeWidth(1).color($r('app.color.divider')).margin({ left: 16, right: 16, top: 9 })
            Column() {
              Row() {
                Text(this.tr('发帖')).fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
                Text(this.countLimitText(this.ownPostsMax)).fontSize(10)
                  .fontColor($r('app.color.accent')).backgroundColor($r('app.color.surface_secondary'))
                  .borderRadius(10).padding({ left: 8, right: 8, top: 3, bottom: 3 })
              }.width('100%')
              AdaptiveSlider({
                value: this.ownValue(this.ownPostsMax), config: this.ownConfig,
                onChange: (value: number) => this.onOwnPostsMaxChange(this.ownLimit(value))
              }).width('100%')
              Row() {
                ForEach(this.ownValues, (value: number) => {
                  Text(value == 0 ? this.tr('无限制') : `${value}`)
                    .fontSize(10).fontColor(value == this.ownPostsMax ?
                      $r('app.color.accent') : $r('app.color.text_secondary'))
                    .fontWeight(value == this.ownPostsMax ? FontWeight.Medium : FontWeight.Normal)
                }, (value: number) => `p${value}`)
              }.width('100%').justifyContent(FlexAlign.SpaceBetween).padding({ left: 4, right: 4 })
            }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 4 })
            Divider().strokeWidth(1).color($r('app.color.divider')).margin({ left: 16, right: 16 })
            Column() {
              Row() {
                Text(this.tr('回复')).fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
                Text(this.countLimitText(this.ownRepliesMax)).fontSize(10)
                  .fontColor($r('app.color.accent')).backgroundColor($r('app.color.surface_secondary'))
                  .borderRadius(10).padding({ left: 8, right: 8, top: 3, bottom: 3 })
              }.width('100%')
              AdaptiveSlider({
                value: this.ownValue(this.ownRepliesMax), config: this.ownConfig,
                onChange: (value: number) => this.onOwnRepliesMaxChange(this.ownLimit(value))
              }).width('100%')
              Row() {
                ForEach(this.ownValues, (value: number) => {
                  Text(value == 0 ? this.tr('无限制') : `${value}`)
                    .fontSize(10).fontColor(value == this.ownRepliesMax ?
                      $r('app.color.accent') : $r('app.color.text_secondary'))
                    .fontWeight(value == this.ownRepliesMax ? FontWeight.Medium : FontWeight.Normal)
                }, (value: number) => `r${value}`)
              }.width('100%').justifyContent(FlexAlign.SpaceBetween).padding({ left: 4, right: 4 })
            }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 4 })
            Divider().strokeWidth(1).color($r('app.color.divider')).margin({ left: 16, right: 16 })
            Column() {
              Row() {
                Text(this.tr('转帖')).fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
                Text(this.countLimitText(this.ownRepostsMax)).fontSize(10)
                  .fontColor($r('app.color.accent')).backgroundColor($r('app.color.surface_secondary'))
                  .borderRadius(10).padding({ left: 8, right: 8, top: 3, bottom: 3 })
              }.width('100%')
              AdaptiveSlider({
                value: this.ownValue(this.ownRepostsMax), config: this.ownConfig,
                onChange: (value: number) => this.onOwnRepostsMaxChange(this.ownLimit(value))
              }).width('100%')
              Row() {
                ForEach(this.ownValues, (value: number) => {
                  Text(value == 0 ? this.tr('无限制') : `${value}`)
                    .fontSize(10).fontColor(value == this.ownRepostsMax ?
                      $r('app.color.accent') : $r('app.color.text_secondary'))
                    .fontWeight(value == this.ownRepostsMax ? FontWeight.Medium : FontWeight.Normal)
                }, (value: number) => `t${value}`)
              }.width('100%').justifyContent(FlexAlign.SpaceBetween).padding({ left: 4, right: 4 })
            }.width('100%').padding({ left: 16, right: 16, top: 10, bottom: 4 })
            Blank().height(6)
          }.width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)

          this.sectionTitle('浏览历史')

          Column() {
            Row() {
              Column() {
                Text(this.tr('已用容量')).fontSize(13).fontColor($r('app.color.text_secondary'))
                Row() {
                  Text(`${this.usedMb.toFixed(1)} MB`).fontSize(22)
                    .fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
                  Text(` / ${this.mbText()}`).fontSize(12)
                    .fontColor($r('app.color.text_secondary')).margin({ left: 4, bottom: 3 })
                }.alignItems(VerticalAlign.Bottom).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              Text(this.percentText(this.usedMb, this.maxMb))
                .fontSize(13).fontColor($r('app.color.accent'))
            }.width('100%').padding({ left: 16, right: 16, top: 15, bottom: 7 })
            Stack({ alignContent: Alignment.Start }) {
              Row().width('100%').height(4).borderRadius(2).backgroundColor($r('app.color.divider'))
              Row().width(`${this.percentValue(this.usedMb, this.maxMb)}%`)
                .height(4).borderRadius(2).backgroundColor($r('app.color.accent'))
            }.width('100%').height(4).padding({ left: 16, right: 16 })
            Row() {
              Text(this.tr('缓存总上限')).fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text(this.mbText()).fontSize(13).fontColor($r('app.color.accent'))
            }.width('100%').padding({ left: 16, right: 16, top: 14 })
            AdaptiveSlider({
              value: this.maxMbValue(), config: this.maxMbConfig,
              onChange: (value: number) => this.onMaxMbChange(this.maxMbLimit(value))
            }).width('100%').padding({ left: 12, right: 12, bottom: 4 })
            Row() {
              ForEach(this.mbValues, (value: number) => {
                Text(this.mbStepText(value))
                  .fontSize(10).fontColor(value == this.maxMb ?
                    $r('app.color.accent') : $r('app.color.text_secondary'))
                  .fontWeight(value == this.maxMb ? FontWeight.Medium : FontWeight.Normal)
              }, (value: number) => `m${value}`)
            }.width('100%').justifyContent(FlexAlign.SpaceBetween).padding({ left: 16, right: 16, bottom: 4 })
            Row() {
              Text(this.tr('退出时清除浏览记录')).fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.clearBrowsingOnExit })
                .onChange((value: boolean) => this.onClearBrowsingOnExitChange(value))
            }.width('100%').padding({ left: 16, right: 16, top: 6, bottom: 12 })
          }.width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)

          this.sectionTitle('搜索历史')
          Column() {
            Row() {
              Text(this.tr('保留历史')).fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Text(this.entriesText(this.historyMax)).fontSize(13).fontColor($r('app.color.text_secondary'))
            }.width('100%').padding({ left: 16, right: 16, top: 14 })
            AdaptiveSlider({
              value: this.historyMaxValue(), config: this.historyConfig,
              onChange: (value: number) => this.setHistoryMax(value)
            }).width('100%').padding({ left: 12, right: 12, top: 2, bottom: 4 })
            Row() {
              ForEach(this.historyLimits, (value: number) => {
                Text(`${value}`)
                  .fontSize(10).fontColor(value == this.historyMax ?
                    $r('app.color.accent') : $r('app.color.text_secondary'))
                  .fontWeight(value == this.historyMax ? FontWeight.Medium : FontWeight.Normal)
              }, (value: number) => `h${value}`)
            }.width('100%').justifyContent(FlexAlign.SpaceBetween).padding({ left: 16, right: 16, bottom: 4 })
            Row() {
              Text(this.tr('退出时清除搜索历史')).fontSize(15).fontColor($r('app.color.text_primary')).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.clearSearchOnExit })
                .onChange((value: boolean) => this.setClearOnExit(value))
            }.width('100%').padding({ left: 16, right: 16, top: 6, bottom: 12 })
          }.width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)
          .margin({ top: 12 })

          this.sectionTitle('清除缓存')
          Column() {
            Row() {
              Text(this.tr('清除缓存')).fontSize(16).fontColor('#F4212E').layoutWeight(1)
              Text('›').fontSize(20).fontColor($r('app.color.text_secondary'))
            }.width('100%').height(52).padding({ left: 16, right: 16 })
            .onClick(() => this.showClearMenu())
          }.width('100%').backgroundColor($r('app.color.surface')).borderRadius(20)

          Blank().height(this.bottomInset + 16)
        }.width('100%').padding({ left: 16, right: 16 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.Top)
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor($r('app.color.grouped_bg'))
  }
}
