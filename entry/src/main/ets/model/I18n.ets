import { i18n } from '@kit.LocalizationKit';

const EN: Record<string, string> = {
  '主页': 'Home',
  '趋势': 'Explore',
  '通知': 'Notifications',
  '我的': 'Profile',
  '设置': 'Settings',
  '全屏初始音量': 'Fullscreen starting volume',
  '播放': 'Playback',
  '发送': 'Send',
  '发送与播放': 'Sending and playback',
  '浏览': 'Browsing',
  '自动翻译': 'Auto-translate',
  '发布与浏览': 'Publishing and browsing',
  '主题与显示': 'Theme and display',
  '外观': 'Appearance',
  '实心底栏': 'Solid navigation bar',
  '我的资料': 'My profile',
  '用户资料': 'User profile',
  '压缩': 'Compressed',
  '已转帖': 'Reposted',
  '你已转帖': 'You reposted',
  '帖子、回复和转贴': 'Posts, replies, and reposts',
  '显示与主题': 'Theme settings',
  '主题设置': 'Theme settings',
  '浅色': 'Light',
  '深色': 'Dark',
  '跟随系统': 'Use system setting',
  '推文设置': 'Post settings',
  '多媒体设置': 'Media settings',
  '自动播放已开启': 'Autoplay on',
  '自动播放已关闭': 'Autoplay off',
  '本地缓存': 'Local cache',
  '关于 HM-Xbird': 'About HM-Xbird',
  '帖子': 'Post',
  '帖子列表': 'Posts',
  '推文': 'Posts',
  '转推': 'Reposts',
  '推文、回复和转推': 'Posts, replies, and reposts',
  '重试': 'Retry',
  '加载评论…': 'Loading replies…',
  '正在加载资料…': 'Loading profile…',
  '正在关注': 'Following',
  '更早': 'Earlier',
  '关注者': 'Followers',
  '选择左侧推文': 'Select a post',
  '关闭': 'Close',
  '暂无通知': 'No notifications yet',
  '打开通知时加载': 'Loads when you open notifications',
  '为你推荐': 'For you',
  '暂无内容': 'Nothing here yet',
  '加载更多…': 'Loading more…',
  '搜索 X': 'Search X',
  '搜索': 'Search',
  '热门': 'Top',
  '最新': 'Latest',
  '用户': 'People',
  '全球趋势': 'Trends for you',
  '编辑资料': 'Edit profile',
  '编辑': 'Edit',
  '刷新': 'Refresh',
  '回复': 'Replies',
  '转帖': 'Reposts',
  '翻译中…': 'Translating…',
  '查看翻译': 'View translation',
  '已翻译 · 查看原文': 'Translated · View original',
  '翻译': 'Translate',
  '发推': 'Post',
  '发布中…': 'Posting…',
  '发布': 'Post',
  '取消': 'Cancel',
  '已发布': 'Posted',
  '视频': 'Video',
  '有什么新鲜事？': 'What’s happening?',
  '图片/视频': 'Photos/video',
  '拍照': 'Camera',
  '录像': 'Record video',
  '表情': 'Emoji',
  '可在系统选择器中编辑': 'You can edit this in the system picker',
  '使用表情后会出现在这里': 'Emojis you use will appear here',
  '内容不能为空': 'A post can’t be empty',
  '视频超过 512MB，请压缩后再上传': 'Videos over 512 MB can’t be uploaded. Compress the video first.',
  '登录 X': 'Sign in to X',
  '选择一种登录方式': 'Choose a sign-in method',
  '继续使用已保存账号': 'Continue with a saved account',
  '暂无保存的账号': 'No saved accounts',
  '使用 Cookie 登录': 'Sign in with cookies',
  '分别填写 auth_token 与 ct0': 'Enter auth_token and ct0',
  '使用网页登录': 'Sign in on the web',
  '登录 X 后自动获取 Cookie': 'Sign in to X to capture cookies automatically',
  '已保存账号': 'Saved accounts',
  '使用 ›': 'Use ›',
  '使用保存账号需要先通过系统指纹、人脸或锁屏密码认证。': 'Verify with your fingerprint, face, or screen lock to use a saved account.',
  '粘贴 auth_token 的值': 'Paste auth_token',
  '粘贴 ct0 的值': 'Paste ct0',
  '保存此账号': 'Save this account',
  '导入 Cookie 并登录': 'Import cookies and sign in',
  '如何获取 Cookie': 'How to get cookies',
  '1. 浏览器登录 x.com；\n2. 开发者工具 → Application → Cookies → x.com；\n3. 分别复制 auth_token 和 ct0 的值，填入上方两个输入框。': '1. Sign in to x.com in your browser.\n2. Open Developer Tools → Application → Cookies → x.com.\n3. Copy auth_token and ct0 into the fields above.',
  '请分别填写 auth_token 和 ct0': 'Enter both auth_token and ct0',
  'auth_token 和 ct0 中不能包含分号': 'auth_token and ct0 can’t contain semicolons',
  '请在下方登录 X，成功后点“完成”': 'Sign in to X below, then tap Done.',
  '还没拿到 auth_token，请确认已经登录成功': 'auth_token not found. Make sure you’re signed in.',
  '已捕获接口请求与 Cookie': 'Captured API requests and cookies',
  '未捕获到接口请求，将尝试扫描脚本': 'No API request captured. Trying a script scan.',
  '网页登录': 'Web sign-in',
  '处理中…': 'Working…',
  '完成': 'Done',
  '已到主页，点“完成”保存登录': 'You’re signed in. Tap Done to save.',
  '开源许可': 'Open-source licenses',
  '本应用采用 MIT License 开源。': 'This app is open source under the MIT License.',
  '第三方组件': 'Third-party components',
  'HarmonyOS / ArkUI 与 OpenHarmony 相关组件遵循其各自开源许可。本应用为非官方个人项目，与任何商标权利人无隶属或授权关系。': 'HarmonyOS, ArkUI, and OpenHarmony components follow their respective licenses. This is an unofficial personal project, not affiliated with or endorsed by any trademark holder.',
  '关于': 'About',
  'HarmonyOS 原生应用': 'HarmonyOS native app',
  'HM-Xbird 是一个基于 HarmonyOS 原生技术开发的应用，使用 ArkTS / ArkUI 构建界面，注重折叠屏适配与系统交互。': 'HM-Xbird is built with native HarmonyOS technology and ArkTS / ArkUI, with a focus on foldable-screen adaptation and system integration.',
  '版本': 'Version',
  '发布者': 'Publisher',
  '应用名称': 'App name',
  '包名': 'Bundle name',
  '技术栈': 'Tech stack',
  '本应用为非官方个人项目。': 'This is an unofficial personal project.',
  '同步中…': 'Syncing…',
  '资料已同步': 'Profile synced',
  '保存失败，请在页面内重试': 'Save failed. Please retry in the page.',
  '在 X 官方页面修改资料，完成后点“完成”同步到应用。': 'Edit your profile on X, then tap Done to sync it here.',
  '加载 X 资料编辑页…': 'Loading X profile editor…',
  '正在准备 X 登录状态…': 'Preparing your X session…',
  '账户': 'Account',
  '通知过滤': 'Notification filters',
  '暂无用户': 'No users yet',
  '根据系统浅色/深色设置自动切换': 'Automatically match your system light or dark appearance',
  '启用分栏': 'Use split view',
  '底栏纯白模式': 'Solid navigation bar',
  '深色模式会同步调整状态栏、导航栏和底栏材质。': 'Dark mode also adjusts the status bar, navigation bar, and tab bar materials.',
  '图片大小上限': 'Image size limit',
  'GIF 大小上限': 'GIF size limit',
  '压缩质量': 'Compression quality',
  '原图': 'Original',
  '高': 'High',
  '标准': 'Standard',
  '省流': 'Data saver',
  'GIF动图': 'GIFs',
  '图片': 'Images',
  '自定义': 'Custom',
  '原画': 'Original',
  'GIF 质量': 'GIF quality',
  '图片质量': 'Image quality',
  '原图不压缩；超过大小上限时会提示。其他档位会在上传前压缩，并继续降质/缩放直到低于上限。': 'Original keeps the file untouched and warns you if it exceeds the limit. Other levels compress before upload and keep reducing quality or size until the file fits.',
  '视频超过 512 MB 时不会压缩，会提示先压缩再上传。': 'Videos over 512 MB are not compressed. Compress them before uploading.',
  '视频和原画即使超过大小上限也不会压缩。省流、标准、高会在发送前按比例压缩；仍超限时会继续降质至省流，省流仍超限则提示文件过大。': 'Videos and Original are never compressed, even when they exceed the size limit. Data saver, Standard, and High compress before sending; if still over the limit, quality drops further down to Data saver, and the file is reported as too large if it still does not fit.',
  '视频和原画不压缩。其余质量发送时默认按所选质量压缩；若仍超过大小上限，会逐档降低至省流。': 'Videos and Original are not compressed. Other qualities compress before sending; if still over the size limit, quality steps down to Data saver.',
  '省流、标准、高发送前都会压缩；档位之间可连续调节。压缩后仍超过大小上限时会继续降低质量，最低到省流；仍超限则提示文件过大。原画未超限时保留原文件。': 'Data saver, Standard, and High compress before sending; drag between stops for proportional quality. If the result is still over the limit, quality keeps dropping down to Data saver; if it still does not fit, the file is reported as too large. Original keeps the file when it is within the limit.',
  'GIF 压缩到省流后仍超过大小上限，请先裁剪尺寸': 'The GIF still exceeds the size limit at Data saver quality. Crop or reduce it and try again.',
  '图片压缩到省流后仍超过大小上限，请裁剪尺寸': 'The image still exceeds the size limit at Data saver quality. Crop it and try again.',
  'GIF 使用相同的质量档位；省流、标准、高会重新压缩，仍超过上限时继续降质，省流仍超限则提示文件过大。': 'GIFs use the same quality levels. Data saver, Standard, and High recompress the file; quality is reduced further if needed, and the file is reported as too large if Data saver still exceeds the limit.',
  '省流、标准、高会按对应比例压缩，即使没有超过大小上限；超过上限时会继续降低质量，最低到省流仍超限则提示图片过大。': 'Data saver, Standard, and High compress at their ratios even below the size limit. If still over the limit, quality is reduced further; if Data saver still exceeds it, the image is reported as too large.',
  '自动播放': 'Autoplay',
  '自动播放时静音': 'Mute autoplay',
  '横向滑动': 'Swipe horizontally',
  '左右滑动切换演示': 'Swipe left or right to switch demos',
  '全屏视频': 'Full-screen video',
  '播放进度': 'Playback position',
  '音量调节': 'Volume',
  '亮度调节': 'Brightness',
  '开启后左半屏调亮度，右半屏调音量，横向滑动调进度': 'When on, the left half adjusts brightness, the right half adjusts volume, and horizontal swipes seek.',
  '全屏播放手势与演示': 'Full-screen gesture controls and demo',
  '控制手势': 'Gesture controls',
  '默认音量': 'Default volume',
  '内嵌播放': 'Inline playback',
  '初始音量': 'Starting volume',
  '全屏播放': 'Full-screen playback',
  '全屏手势': 'Full-screen gestures',
  '静音': 'Muted',
  '全屏与手势': 'Full screen & gestures',
  '点击查看全屏滑动区域': 'Tap to view full-screen gesture areas',
  '手势说明': 'Gesture guide',
  '进入全屏时的初始音量；拖到最左为静音': 'Initial volume when entering full screen; drag to the far left to mute',
  '拖到最左为静音': 'Drag to the far left to mute',
  '全屏默认音量': 'Default full-screen volume',
  '浏览设置': 'Browsing',
  '视频可见超过一半并停留后播放；同一视频本次运行仅自动播放一次': 'Play when more than half visible and held on screen. Each video autoplays once per session.',
  '自动播放默认静音': 'Start autoplay muted',
  '自动播放开始时保持静音': 'Keep autoplay muted when it begins',
  '全屏播放默认静音': 'Start full screen muted',
  '每次进入全屏时默认静音': 'Mute automatically when entering full screen',
  '自动播放音量': 'Autoplay volume',
  '全屏手势控制': 'Full-screen gestures',
  '开启后左半屏调亮度、右半屏调音量并隐藏音量条；关闭后显示可拖动的进度和音量条': 'When on, drag on the left half for brightness and the right half for volume, with no volume slider. When off, show draggable seek and volume sliders.',
  '全屏手势提示': 'Full-screen gestures',
  '亮度': 'Brightness',
  '音量': 'Volume',
  '进度': 'Seek',
  '左侧上下滑动': 'Swipe up or down on the left',
  '右侧上下滑动': 'Swipe up or down on the right',
  '左右滑动': 'Swipe left or right',
  '提示：当前系统未提供公开的官方手势演示组件，此处使用系统风格静态示意。': 'This is a static, system-style illustration; HarmonyOS doesn’t currently expose a public gesture demo component.',
  '无上限': 'No limit',
  '无限制': 'No limit',
  '条': 'posts',
  '已缓存': 'Cached',
  '已占用缓存': 'Cache storage',
  '已用容量': 'Cache used',
  '缓存总上限': 'Total cache limit',
  '浏览历史': 'Browsing history',
  '搜索历史': 'Search history',
  '搜索历史条数': 'Search history entries',
  '保留历史': 'History retained',
  '退出时清除浏览记录': 'Clear browsing history on exit',
  '退出时清除搜索历史': 'Clear search history on exit',
  '发帖': 'Posts',
  '转发': 'Reposts',
  '清除缓存': 'Clear cache',
  '清除浏览历史': 'Clear browsing history',
  '清除搜索历史': 'Clear search history',
  '清除我的资料': 'Clear my profile cache',
  '清除全部缓存': 'Clear all cache',
  '选择要清除的内容': 'Choose what to clear',
  '主页时间线和其他浏览缓存': 'Home timeline and other browsing caches',
  '搜索词条和当前结果快照': 'Search terms and current result snapshots',
  '我的发帖、回复、转帖缓存': 'Cached posts, replies, and reposts',
  '以上三类缓存全部清除': 'Clear all three cache groups',
  '保留本机账号和缓存数据': 'Keep the saved account and local cache',
  '同时删除账号和本机缓存数据': 'Delete the account and local cache',
  '最近搜索': 'Recent searches',
  '清空全部': 'Clear all',
  '清除': 'Clear',
  '将删除主页时间线缓存和其他浏览缓存；不会删除搜索历史和我的资料。': 'This clears the home timeline and other browsing caches. Search history and your profile cache are kept.',
  '将删除搜索词条和当前搜索结果的运行时快照。': 'This deletes search terms and the current search result snapshots.',
  '将删除我的发帖、回复、转帖三个子标签的本地缓存。': 'This deletes local caches for your posts, replies, and reposts tabs.',
  '将清除浏览历史、搜索历史和我的资料缓存；登录凭据、账号信息和设置会保留。': 'This clears browsing history, search history, and your profile cache. Sign-in credentials, account info, and settings are kept.',
  '浏览历史已清除': 'Browsing history cleared',
  '搜索历史已清除': 'Search history cleared',
  '我的资料缓存已清除': 'Profile cache cleared',
  '全部缓存已清除': 'All cache cleared',
  '已用空间': 'Cache used',
  '资料页帖子、回复、转贴缓存占用': 'Posts, replies, and reposts cached from your profile',
  '资料页缓存条数上限': 'Profile cache limit',
  '资料页缓存存储上限': 'Profile cache storage limit',
  '资料页存储上限': 'Profile storage limit',
  '清理本地缓存': 'Clear local cache',
  '清理资料页缓存；保留登录凭据和账号信息': 'Clears cached profile posts while keeping your sign-in credentials and account info.',
  '将删除资料页帖子/回复/转贴缓存和已缓存图片；登录凭据、账号信息和设置会保留。': 'This deletes cached posts, replies, reposts, and images from your profile. Sign-in credentials, account info, and settings are kept.',
  '清理': 'Clear',
  '缓存已清理，正在重新缓存': 'Cache cleared. Rebuilding it now…',
  '退出登录？': 'Sign out?',
  '删除并退出': 'Delete and sign out',
  '将删除本机保存的 Cookie、登录状态和账号信息。此操作无法恢复，之后需要重新登录。': 'This will delete the cookies, sign-in state, and account information saved on this device. This cannot be undone and you will need to sign in again.',
  '删除本机账号？': 'Delete this device account?',
  '删除本机账号并退出': 'Delete this device account and sign out',
  '仅退出登录': 'Sign out only',
  '退出后当前账号将不再保持登录。你可以保留本机保存的账号，或同时删除本机账号数据。': 'After signing out, this account will no longer stay signed in. You can keep the saved account on this device or delete it as well.',
  '保留已保存账号时，下次可以直接恢复登录。': 'Keep this saved account to sign back in next time.',
  '保留账号退出': 'Sign out and keep account',
  '删除账号退出': 'Sign out and delete account',
  '删除保存的账号？': 'Delete saved account?',
  '将同时删除该账号保存在本机的 Cookie，删除后只能重新登录。此操作不可恢复。': 'This also removes the account’s Cookie from this device. You’ll need to sign in again. This can’t be undone.',
  '确认删除': 'Delete',
  '语言设置': 'Language',
  '应用界面语言。选择“跟随系统”时会使用系统语言。': 'Choose the language used in the app. Follow system uses your system language.',
  '“为你推荐”暂不可用，已显示关注时间线': '“For you” is unavailable. Showing your Following timeline.',
  '引用': 'Quote',
  '退出登录': 'Sign out',
  '账号保存失败': 'Couldn’t save account',
  '验证身份以使用保存的账号': 'Verify your identity to use a saved account',
  '系统认证未通过，无法使用保存的账号': 'System authentication failed. Saved account unavailable.',
  '保存的登录信息不存在': 'Saved sign-in information was not found',
  '未知错误': 'Unknown error',
  'REST 返回空响应': 'Empty response from REST',
  'X 返回错误': 'X returned an error',
  '搜索失败': 'Search failed',
  '媒体 INIT 未返回 media_id': 'Media INIT returned no media_id',
  '视频转码失败': 'Video transcoding failed',
  'X 未返回新推文 ID': 'X returned no new post ID',
  'Viewer 未返回用户资料': 'Viewer returned no profile',
  'Viewer 未返回用户 ID': 'Viewer returned no user ID',
  '推文详情为空': 'Post details are empty',
  '推文详情为空（REST）': 'Post details are empty (REST)',
  '用户资料为空': 'User profile is empty',
  '通知为空（REST）': 'Notifications are empty (REST)',
  '关注列表加载失败': 'Couldn’t load follows',
  '用户不存在': 'User not found',
  '用户搜索失败': 'User search failed',
  '没有可用翻译': 'No translation available',
  'GIF 压缩后仍超过大小上限，请先裁剪尺寸': 'The compressed GIF is still over the size limit. Crop it first.',
  '恢复账号失败：': 'Couldn’t restore account: ',
  '刷新失败：': 'Refresh failed: ',
  '趋势加载失败：': 'Couldn’t load trends: ',
  '页面加载失败：': 'Page failed to load: ',
  '读取登录态失败：': 'Couldn’t read sign-in state: ',
  '同步登录状态失败：': 'Couldn’t sync sign-in state: ',
  '资料同步失败：': 'Couldn’t sync profile: ',
  '播放器初始化失败：': 'Couldn’t initialize the player: ',
  '播放失败：': 'Playback failed: ',
  '视频源设置失败：': 'Couldn’t set the video source: ',
  '点赞失败：': 'Couldn’t like the post: ',
  '转推失败：': 'Couldn’t repost: ',
  '选择图片失败：': 'Couldn’t select media: ',
  '拍摄失败：': 'Couldn’t capture media: ',
  '读取 Cookie 失败：': 'Couldn’t read cookies: ',
  '页面 JS 错误：': 'Page JavaScript error: ',
  '资源加载失败：': 'Resource failed to load: ',
  '内容超过 ': 'Post exceeds the ',
};

const MONTHS: string[] = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'];

export class I18n {
  private static lang: string = 'zh';

  static setLanguage(lang: string): void {
    I18n.lang = lang == 'en' ? 'en' : 'zh';
  }

  static language(): string {
    return I18n.lang;
  }

  static isEnglish(): boolean {
    return I18n.lang == 'en';
  }

  static systemLanguageIsChinese(): boolean {
    try {
      return i18n.System.getSystemLanguage().toLowerCase().startsWith('zh');
    } catch (e) {
      return true;
    }
  }

  static followSystemLabel(): string {
    return I18n.systemLanguageIsChinese() ? '跟随系统' : 'Follow system';
  }

  static emojiGroup(name: string): string {
    if (!I18n.isEnglish()) return name;
    if (name == '最近') return 'Recent';
    if (name == '表情') return 'Smileys';
    if (name == '人物') return 'People';
    if (name == '自然') return 'Nature';
    if (name == '食物') return 'Food & drink';
    if (name == '旅行') return 'Travel & places';
    if (name == '活动') return 'Activities';
    if (name == '物品') return 'Objects';
    if (name == '符号') return 'Symbols';
    if (name == '旗帜') return 'Flags';
    return name;
  }

  static t(zh: string): string {
    if (I18n.lang != 'en' || zh.length == 0) return zh;
    const exact = EN[zh];
    if (exact != undefined) return exact;

    let m = zh.match(/^(\d+) 正在关注$/);
    if (m != null) return `${m[1]} Following`;
    m = zh.match(/^(\d+) 关注者$/);
    if (m != null) return `${m[1]} Followers`;
    m = zh.match(/^(\d+) 帖子$/);
    if (m != null) return `${m[1]} posts`;
    m = zh.match(/^(\d+) 条$/);
    if (m != null) return `${m[1]} posts`;
    m = zh.match(/^已保存 (\d+) 个账号$/);
    if (m != null) return `${m[1]} saved accounts`;
    m = zh.match(/^回复 @(.+)$/);
    if (m != null) return `Replying to @${m[1]}`;
    m = zh.match(/^引用 @(.+)$/);
    if (m != null) return `Quoting @${m[1]}`;
    m = zh.match(/^(\d+)年(\d+)月加入$/);
    if (m != null) {
      const month = Math.max(1, Math.min(12, parseInt(m[2]))) - 1;
      return `Joined ${MONTHS[month]} ${m[1]}`;
    }
    m = zh.match(/^内容超过 (\d+) 字限制$/);
    if (m != null) return `Post exceeds the ${m[1]}-character limit`;
    m = zh.match(/^媒体上传 HTTP (\d+): (.*)$/);
    if (m != null) return `Media upload failed: HTTP ${m[1]}: ${m[2]}`;
    m = zh.match(/^头像上传 HTTP (\d+)$/);
    if (m != null) return `Avatar upload failed: HTTP ${m[1]}`;
    m = zh.match(/^时间线加载失败：REST (.*)；GraphQL (.*)$/);
    if (m != null) return `Timeline failed. REST: ${m[1]}. GraphQL: ${m[2]}.`;
    m = zh.match(/^文件 (.*)MB 超过上限 (.*)MB，请选择压缩质量$/);
    if (m != null) return `File is ${m[1]} MB, over the ${m[2]} MB limit. Choose a compression level.`;
    m = zh.match(/^无法解析 (.*) 的 queryId（已扫描 (\d+) 个脚本）$/);
    if (m != null) return `Couldn’t resolve queryId for ${m[1]} (scanned ${m[2]} scripts)`;

    const colon = zh.indexOf('：');
    if (colon > 0) {
      const prefix = EN[zh.substring(0, colon + 1)];
      if (prefix != undefined) return prefix + zh.substring(colon + 1);
    }
    return zh;
  }
}
