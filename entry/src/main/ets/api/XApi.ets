import { http } from '@kit.NetworkKit';
import { QueryIds } from './QueryIds';
import { TweetItem } from '../model/TweetItem';
import { NotificationItem, NotificationPage } from '../model/NotificationItem';
import { UserProfile, UserSearchResult } from '../model/UserProfile';
import { TrendItem } from '../model/TrendItem';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

const BEARER = 'Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA';
const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36';

const READ_FEATURES: Record<string, boolean> = {
  'rweb_tipjar_consumption_enabled': true,
  'responsive_web_graphql_exclude_directive_enabled': true,
  'verified_phone_label_enabled': false,
  'creator_subscriptions_tweet_preview_api_enabled': true,
  'responsive_web_graphql_timeline_navigation_enabled': true,
  'responsive_web_graphql_skip_user_profile_image_extensions_enabled': false,
  'communities_web_enable_tweet_community_results_fetch': true,
  'c9s_tweet_anatomy_moderator_badge_enabled': true,
  'articles_preview_enabled': true,
  'responsive_web_edit_tweet_api_enabled': true,
  'graphql_is_translatable_rweb_tweet_is_translatable_enabled': true,
  'view_counts_everywhere_api_enabled': true,
  'longform_notetweets_consumption_enabled': true,
  'responsive_web_twitter_article_tweet_consumption_enabled': true,
  'tweet_awards_web_tipping_enabled': false,
  'creator_subscriptions_quote_tweet_preview_enabled': false,
  'freedom_of_speech_not_reach_fetch_enabled': true,
  'standardized_nudges_misinfo': true,
  'tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled': true,
  'rweb_video_timestamps_enabled': true,
  'longform_notetweets_rich_text_read_enabled': true,
  'longform_notetweets_inline_media_enabled': true,
  'responsive_web_enhance_cards_enabled': false,
  'responsive_web_media_download_video_enabled': false,
  'rweb_video_screen_enabled': true,
  'premium_content_api_read_enabled': false,
  'responsive_web_grok_analyze_button_fetch_trends_enabled': false,
  'responsive_web_grok_analyze_post_followups_enabled': false,
  'responsive_web_grok_annotations_enabled': false,
  'responsive_web_jetfuel_frame': true,
  'post_ctas_fetch_enabled': true,
  'responsive_web_grok_share_attachment_enabled': true,
  'responsive_web_grok_show_grok_translated_post': false,
  'responsive_web_grok_analysis_button_from_backend': true,
  'profile_label_improvements_pcf_label_in_post_enabled': true,
  'responsive_web_profile_redirect_enabled': false,
  'responsive_web_grok_community_note_auto_translation_is_enabled': false,
  'responsive_web_grok_image_annotation_enabled': true,
  'responsive_web_grok_imagine_annotation_enabled': true
};

export function errorText(value: Object): string {
  if (value instanceof Error) return (value as Error).message;
  try {
    const text = JSON.stringify(value);
    return text.length > 0 ? text : '未知错误';
  } catch (e) {
    return '未知错误';
  }
}

export class HomeResult {
  tweets: TweetItem[] = [];
  cursor: string = '';
}

function asObj(value: Object | undefined | null): Record<string, Object> | null {
  if (value == null) return null;
  if (typeof value != 'object') return null;
  return value as Record<string, Object>;
}

function asArr(value: Object | undefined | null): Array<Object> {
  if (value == null) return [];
  if (Array.isArray(value)) return value as Array<Object>;
  return [];
}

function asString(value: Object | undefined | null): string {
  if (typeof value == 'string') return value as string;
  return '';
}

function asText(value: Object | undefined | null): string {
  if (typeof value == 'string') return value as string;
  if (typeof value == 'number') return `${value as number}`;
  return '';
}

function asNumber(value: Object | undefined | null): number {
  if (typeof value == 'number') return value as number;
  return 0;
}

function parseUser(result: Record<string, Object> | null): TweetItem {
  const item = new TweetItem();
  const core = asObj(result == null ? null : result['core']);
  const userResults = asObj(core == null ? null : core['user_results']);
  const userResult = asObj(userResults == null ? null : userResults['result']);
  const legacy = asObj(userResult == null ? null : userResult['legacy']);
  const userCore = asObj(userResult == null ? null : userResult['core']);
  const avatar = asObj(userResult == null ? null : userResult['avatar']);
  item.authorName = asString(legacy == null ? null : legacy['name']);
  item.authorHandle = asString(legacy == null ? null : legacy['screen_name']);
  item.avatarUrl = asString(legacy == null ? null : legacy['profile_image_url_https']);
  if (item.authorName.length == 0) item.authorName = asString(userCore == null ? null : userCore['name']);
  if (item.authorHandle.length == 0) item.authorHandle = asString(userCore == null ? null : userCore['screen_name']);
  if (item.avatarUrl.length == 0) item.avatarUrl = asString(avatar == null ? null : avatar['image_url']);
  return item;
}

function isPromotedEntry(entry: Record<string, Object>): boolean {
  const entryId = asString(entry['entryId']);
  if (entryId.indexOf('promoted-') >= 0 || entryId.indexOf('promoted-tweet') >= 0) return true;
  const content = asObj(entry['content']);
  const itemContent = asObj(content == null ? null : content['itemContent']);
  if (itemContent == null) return false;
  if (itemContent['promotedMetadata'] != undefined) return true;
  return asString(itemContent['tweetDisplayType']) == 'Promoted';
}

function parseTweet(entry: Record<string, Object>, depth: number = 0): TweetItem | null {
  const content = asObj(entry['content']);
  const itemContent = asObj(content == null ? null : content['itemContent']);
  if (itemContent != null && itemContent['promotedMetadata'] != undefined) return null;
  const tweetResults = asObj(itemContent == null ? null : itemContent['tweet_results']);
  let result = asObj(tweetResults == null ? null : tweetResults['result']);
  if (result == null) return null;
  if (result['tweet'] != null) {
    result = asObj(result['tweet']);
  }
  if (result == null) return null;

  const legacy = asObj(result['legacy']);
  if (legacy == null) return null;

  const item = parseUser(result);
  item.id = asString(result['rest_id']);
  item.text = asString(legacy['full_text']);
  item.lang = asString(legacy['lang']);
  item.isReply = asString(legacy['in_reply_to_status_id_str']).length > 0;
  item.isRetweet = legacy['retweeted_status_result'] != undefined || asString(legacy['retweeted_status_id_str']).length > 0;
  item.createdAt = asString(legacy['created_at']);
  item.replyCount = asNumber(legacy['reply_count']);
  item.retweetCount = asNumber(legacy['retweet_count']);
  item.likeCount = asNumber(legacy['favorite_count']);

  const extended = asObj(legacy['extended_entities']);
  const media = asArr(extended == null ? null : extended['media']);
  if (media.length > 0) {
    const first = asObj(media[0]);
    if (first != null) {
      const type = asString(first['type']);
      item.mediaType = type;
      if (type == 'photo') {
        item.imageUrl = asString(first['media_url_https']);
      } else if (type == 'video' || type == 'animated_gif') {
        const videoInfo = asObj(first['video_info']);
        const variants = asArr(videoInfo == null ? null : videoInfo['variants']);
        let best = '';
        let bestRate = -1;
        for (const rawVariant of variants) {
          const variant = asObj(rawVariant);
          if (variant == null) continue;
          const rate = asNumber(variant['bitrate']);
          const vurl = asString(variant['url']);
          const isMp4 = vurl.indexOf('.mp4') >= 0;
          if (vurl.length > 0 && (isMp4 || best.length == 0) && rate >= bestRate) {
            best = vurl;
            bestRate = rate;
          }
        }
        item.videoUrl = best;
        item.imageUrl = asString(first['media_url_https']);
      }
    }
  }

  if (depth < 1) {
    let quoted = asObj(result['quoted_status_result']);
    if (quoted == null) quoted = asObj(legacy['quoted_status_result']);
    const quotedResult = asObj(quoted == null ? null : quoted['result']);
    if (quotedResult != null) {
      const tweetResults2: Record<string, Object> = { 'result': quotedResult };
      const itemContent2: Record<string, Object> = { 'tweet_results': tweetResults2 };
      const content2: Record<string, Object> = { 'itemContent': itemContent2 };
      const synthetic: Record<string, Object> = { 'content': content2 };
      const child = parseTweet(synthetic, depth + 1);
      if (child != null) {
        item.quotedId = child.id;
        item.quotedText = child.text;
        item.quotedAuthorName = child.authorName;
        item.quotedAuthorHandle = child.authorHandle;
        item.quotedAvatarUrl = child.avatarUrl;
      }
    }
  }
  return item;
}


function parseRestTweet(raw: Object): TweetItem | null {
  const tweet = asObj(raw);
  if (tweet == null) return null;
  const item = new TweetItem();
  item.id = asString(tweet['id_str']);
  item.text = asString(tweet['full_text']);
  item.createdAt = asString(tweet['created_at']);
  item.replyCount = asNumber(tweet['reply_count']);
  item.retweetCount = asNumber(tweet['retweet_count']);
  item.likeCount = asNumber(tweet['favorite_count']);
  const user = asObj(tweet['user']);
  if (user != null) {
    item.authorName = asString(user['name']);
    item.authorHandle = asString(user['screen_name']);
    item.avatarUrl = asString(user['profile_image_url_https']);
  }
  const extended = asObj(tweet['extended_entities']);
  const media = asArr(extended == null ? null : extended['media']);
  if (media.length > 0) {
    const first = asObj(media[0]);
    if (first != null && asString(first['type']) == 'photo') {
      item.imageUrl = asString(first['media_url_https']);
    }
  }
  return item;
}

export class XApi {
  private static headers(cookie: string): Record<string, string> {
    const csrf = XApi.cookieValue(cookie, 'ct0');
    return {
      'cookie': cookie,
      'authorization': BEARER,
      'x-csrf-token': csrf,
      'x-twitter-auth-type': 'OAuth2Session',
      'x-twitter-active-user': 'yes',
      'x-twitter-client-language': 'en',
      'content-type': 'application/json',
      'user-agent': USER_AGENT,
      'accept': '*/*'
    };
  }

  private static cookieValue(cookie: string, name: string): string {
    const parts = cookie.split(';');
    for (const part of parts) {
      const trimmed = part.trim();
      const eq = trimmed.indexOf('=');
      if (eq > 0 && trimmed.substring(0, eq) == name) {
        return trimmed.substring(eq + 1);
      }
    }
    return '';
  }

  static async homeLatest(cookie: string, cursor: string): Promise<HomeResult> {
    try {
      return await XApi.homeLatestRest(cookie, cursor);
    } catch (restError) {
      try {
        return await XApi.homeLatestGraphql(cookie, cursor);
      } catch (graphqlError) {
        throw new Error(`时间线加载失败：REST ${errorText(restError)}；GraphQL ${errorText(graphqlError)}`);
      }
    }
  }

  private static async homeLatestRest(cookie: string, cursor: string): Promise<HomeResult> {
    let url = 'https://x.com/i/api/1.1/statuses/home_timeline.json' +
      '?count=20&tweet_mode=extended&include_entities=true&include_rts=true';
    if (cursor.length > 0) {
      url += `&max_id=${cursor}`;
    }
    const request = http.createHttp();
    let text = '';
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: XApi.headers(cookie),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        const body = (response.result as string).substring(0, 300);
        throw new Error(`HTTP ${response.responseCode} ${body}`);
      }
      text = response.result as string;
    } finally {
      request.destroy();
    }

    if (text.trim().length == 0) throw new Error('REST 返回空响应');
    const parsed = JSON.parse(text) as Object;
    const result = new HomeResult();
    for (const raw of asArr(parsed)) {
      const tweet = parseRestTweet(raw);
      if (tweet != null && tweet.id.length > 0) {
        result.tweets.push(tweet);
      }
    }
    if (result.tweets.length > 0) {
      const lastId = Number(result.tweets[result.tweets.length - 1].id);
      if (!isNaN(lastId) && lastId > 0) {
        result.cursor = `${lastId - 1}`;
      }
    }
    return result;
  }

  private static async homeLatestGraphql(cookie: string, cursor: string): Promise<HomeResult> {
    try {
      return await XApi.homeGraphql(cookie, cursor, 'HomeLatestTimeline', false);
    } catch (e) {
      return await XApi.homeGraphql(cookie, cursor, 'HomeTimeline', false);
    }
  }

  private static async homeGraphql(cookie: string, cursor: string, operation: string,
    promoted: boolean): Promise<HomeResult> {
    const queryId = await QueryIds.resolve(cookie, operation);
    const variables: Record<string, Object> = {
      'count': 20,
      'includePromotedContent': promoted,
      'latestControlAvailable': true,
      'requestContext': 'launch',
      'withCommunity': true
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }

    const url = `https://x.com/i/api/graphql/${queryId}/${operation}` +
      `?variables=${encodeURIComponent(JSON.stringify(variables))}` +
      `&features=${encodeURIComponent(JSON.stringify(READ_FEATURES))}`;

    const request = http.createHttp();
    let text = '';
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: XApi.headers(cookie),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      text = response.result as string;
    } finally {
      request.destroy();
    }

    const root = asObj(JSON.parse(text) as Object);
    const data = asObj(root == null ? null : root['data']);
    const home = asObj(data == null ? null : data['home']);
    const timeline = asObj(home == null ? null : home['home_timeline_urt']);
    const instructions = asArr(timeline == null ? null : timeline['instructions']);

    const result = new HomeResult();
    for (const rawInstruction of instructions) {
      const instruction = asObj(rawInstruction);
      if (instruction == null) continue;
      if (asString(instruction['type']) != 'TimelineAddEntries') continue;

      for (const rawEntry of asArr(instruction['entries'])) {
        const entry = asObj(rawEntry);
        if (entry == null) continue;
        const entryId = asString(entry['entryId']);
        if (entryId.indexOf('cursor-bottom') >= 0) {
          const content = asObj(entry['content']);
          result.cursor = asString(content == null ? null : content['value']);
          continue;
        }
        if (isPromotedEntry(entry)) continue;
        if (entryId.indexOf('tweet-') < 0) continue;
        const tweet = parseTweet(entry);
        if (tweet != null && tweet.id.length > 0) {
          result.tweets.push(tweet);
        }
      }
    }
    return result;
  }


  private static async graphqlPost(cookie: string, queryId: string, operation: string,
    variables: Record<string, Object>, fieldToggles?: Record<string, Object>): Promise<string> {
    const url = `https://x.com/i/api/graphql/${queryId}/${operation}`;
    const bodyObj: Record<string, Object> = {
      'variables': variables,
      'features': READ_FEATURES,
      'queryId': queryId
    };
    if (fieldToggles != undefined) bodyObj['fieldToggles'] = fieldToggles;
    const body = JSON.stringify(bodyObj);
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: XApi.headers(cookie),
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      const text = response.result as string;
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode} ${text.substring(0, 120)}`);
      }
      return text;
    } finally {
      request.destroy();
    }
  }

  private static async graphqlGet(cookie: string, queryId: string, operation: string,
    variables: Record<string, Object>): Promise<string> {
    const url = `https://x.com/i/api/graphql/${queryId}/${operation}` +
      `?variables=${encodeURIComponent(JSON.stringify(variables))}` +
      `&features=${encodeURIComponent(JSON.stringify(READ_FEATURES))}`;
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: XApi.headers(cookie),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      const text = response.result as string;
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode} ${text.substring(0, 120)}`);
      }
      return text;
    } finally {
      request.destroy();
    }
  }

  static async mutate(cookie: string, operation: string, variables: Record<string, Object>): Promise<string> {
    const queryId = await QueryIds.resolve(cookie, operation);
    const url = `https://x.com/i/api/graphql/${queryId}/${operation}`;
    const body = JSON.stringify({
      'variables': variables,
      'features': READ_FEATURES,
      'queryId': queryId
    });
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: XApi.headers(cookie),
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      const text = response.result as string;
      console.info(`XHMutate ${operation} status=${response.responseCode} body=${text.substring(0, 240)}`);
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode} ${text.substring(0, 200)}`);
      }
      const root = asObj(JSON.parse(text) as Object);
      const errors = asArr(root == null ? null : root['errors']);
      if (errors.length > 0) {
        const first = asObj(errors[0]);
        const message = asString(first == null ? null : first['message']);
        throw new Error(message.length > 0 ? message : 'X 返回错误');
      }
      return text;
    } finally {
      request.destroy();
    }
  }

  static async search(cookie: string, query: string, cursor: string = '', product: string = 'Top'): Promise<HomeResult> {
    const variables: Record<string, Object> = {
      'rawQuery': query,
      'count': 20,
      'querySource': 'typed_query',
      'product': product,
      'withGrokTranslatedBio': true,
      'withQuickPromoteEligibilityTweetFields': false
    };
    if (cursor.length > 0) variables['cursor'] = cursor;
    const fieldToggles: Record<string, Object> = { 'withArticleRichContentState': false };
    const candidates: string[] = [];
    try { candidates.push(await QueryIds.resolve(cookie, 'SearchTimeline')); } catch (e) {}
    candidates.push('hz_94eVAtrtQo_vO3my7Rw');
    candidates.push('GcXk9vN_d1jUfHNqLacXQA');
    candidates.push('M1jEez78PEfVfbQLvlWMvQ');
    let firstPage: HomeResult | null = null;
    let lastError: Error = new Error('搜索失败');
    for (const qid of candidates) {
      if (qid.length == 0 || candidates.indexOf(qid) != candidates.lastIndexOf(qid)) continue;
      try {
        const text = await XApi.graphqlPost(cookie, qid, 'SearchTimeline', variables, fieldToggles);
        console.info(`XHSearch qid=${qid} len=${text.length} body=${text.substring(0, 240)}`);
        const root = asObj(JSON.parse(text) as Object);
        if (root != null && asArr(root['errors']).length > 0) continue;
        const data = asObj(root == null ? null : root['data']);
        const search = asObj(data == null ? null : data['search_by_raw_query']);
        const searchTimeline = asObj(search == null ? null : search['search_timeline']);
        const timeline = asObj(searchTimeline == null ? null : searchTimeline['timeline']);
        const page = XApi.parseTimeline(timeline);
        if (firstPage == null) firstPage = page;
        if (page.tweets.length > 0) return page;
      } catch (e) {
        lastError = e as Error;
        console.error(`XHSearch error qid=${qid} ${lastError.message}`);
      }
    }
    if (firstPage != null) return firstPage;
    throw lastError;
  }

  private static parseTimeline(timeline: Record<string, Object> | null): HomeResult {
    const result = new HomeResult();
    const instructions = asArr(timeline == null ? null : timeline['instructions']);
    for (const rawInstruction of instructions) {
      const instruction = asObj(rawInstruction);
      if (instruction == null) continue;
      if (asString(instruction['type']) != 'TimelineAddEntries') continue;
      for (const rawEntry of asArr(instruction['entries'])) {
        const entry = asObj(rawEntry);
        if (entry == null) continue;
        const entryId = asString(entry['entryId']);
        if (entryId.indexOf('cursor-bottom') >= 0) {
          const content = asObj(entry['content']);
          result.cursor = asString(content == null ? null : content['value']);
          continue;
        }
        if (isPromotedEntry(entry)) continue;
        if (entryId.indexOf('tweet-') < 0) continue;
        const tweet = parseTweet(entry);
        if (tweet != null && tweet.id.length > 0) result.tweets.push(tweet);
      }
    }
    return result;
  }


  private static async restPost(cookie: string, url: string, body: string): Promise<void> {
    const request = http.createHttp();
    try {
      const header = XApi.headers(cookie);
      header['content-type'] = 'application/x-www-form-urlencoded';
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: header,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode} ${(response.result as string).substring(0, 120)}`);
      }
    } finally {
      request.destroy();
    }
  }

  static async setFavorite(cookie: string, tweetId: string, favorite: boolean): Promise<void> {
    try {
      await XApi.mutate(cookie, favorite ? 'FavoriteTweet' : 'UnfavoriteTweet', {
        'tweet_id': tweetId
      });
      return;
    } catch (e) {
      const endpoint = favorite ? 'create' : 'destroy';
      await XApi.restPost(cookie,
        `https://x.com/i/api/1.1/favorites/${endpoint}.json`,
        `id=${encodeURIComponent(tweetId)}&include_entities=true`);
    }
  }

  static async setRetweet(cookie: string, tweetId: string, retweet: boolean): Promise<void> {
    try {
      if (retweet) {
        await XApi.mutate(cookie, 'CreateRetweet', {
          'tweet_id': tweetId,
          'dark_request': false
        });
      } else {
        await XApi.mutate(cookie, 'DeleteRetweet', {
          'source_tweet_id': tweetId,
          'dark_request': false
        });
      }
      return;
    } catch (e) {
      const action = retweet ? 'retweet' : 'unretweet';
      await XApi.restPost(cookie,
        `https://x.com/i/api/1.1/statuses/${action}/${encodeURIComponent(tweetId)}.json`,
        '');
    }
  }

  private static mediaMime(uri: string): string {
    const lower = uri.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    return 'image/jpeg';
  }

  private static mediaCategory(mime: string): string {
    if (mime.startsWith('video/')) return 'tweet_video';
    if (mime == 'image/gif') return 'tweet_gif';
    return 'tweet_image';
  }

  private static async uploadForm(url: string, headers: Record<string, Object>, extra?: ArrayBuffer): Promise<string> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: extra,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 120000
      });
      const text = response.result as string;
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`媒体上传 HTTP ${response.responseCode}: ${text.substring(0, 120)}`);
      }
      return text;
    } finally {
      request.destroy();
    }
  }

  private static mediaMetadataBody(mediaId: string): Record<string, Object> {
    const alt: Record<string, Object> = { 'text': '' };
    const body: Record<string, Object> = {
      'media_id': mediaId,
      'alt_text': alt,
      'allow_download': true
    };
    return body;
  }

  static async uploadImage(cookie: string, uri: string): Promise<string> {
    const path = uri.startsWith('file://') ? uri.substring(7) : uri;
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    let bytes = new Uint8Array(0);
    try {
      const stat = fileIo.statSync(file.fd);
      const raw = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, raw);
      bytes = new Uint8Array(raw);
    } finally {
      fileIo.closeSync(file);
    }
    const mime = XApi.mediaMime(uri);
    const category = XApi.mediaCategory(mime);
    const headers = XApi.headers(cookie);
    headers['origin'] = 'https://x.com';
    headers['referer'] = 'https://x.com/compose/post';
    const base = 'https://upload.x.com/i/media/upload.json';
    const initUrl = `${base}?command=INIT&total_bytes=${bytes.length}` +
      `&media_type=${encodeURIComponent(mime)}&media_category=${category}`;
    console.info(`XHMedia INIT mime=${mime} bytes=${bytes.length}`);
    const initText = await XApi.uploadForm(initUrl, headers);
    console.info(`XHMedia INIT response ${initText.substring(0, 160)}`);
    const initRoot = asObj(JSON.parse(initText) as Object);
    const mediaId = asString(initRoot == null ? null : initRoot['media_id_string']);
    if (mediaId.length == 0) throw new Error('媒体 INIT 未返回 media_id');

    const chunkSize = 1024 * 1024;
    const encoder = new util.TextEncoder();
    for (let offset = 0, segment = 0; offset < bytes.length; offset += chunkSize, segment++) {
      const end = Math.min(bytes.length, offset + chunkSize);
      const chunk = bytes.slice(offset, end);
      const boundary = `----XBoundary${Date.now()}${segment}`;
      const head = encoder.encodeInto(`--${boundary}\r\nContent-Disposition: form-data; name="media"; filename="blob"\r\nContent-Type: application/octet-stream\r\n\r\n`);
      const tail = encoder.encodeInto(`\r\n--${boundary}--\r\n`);
      const body = new Uint8Array(head.length + chunk.length + tail.length);
      body.set(head, 0);
      body.set(chunk, head.length);
      body.set(tail, head.length + chunk.length);
      const appendHeaders = XApi.headers(cookie);
      appendHeaders['origin'] = 'https://x.com';
      appendHeaders['referer'] = 'https://x.com/compose/post';
      appendHeaders['content-type'] = `multipart/form-data; boundary=${boundary}`;
      const appendUrl = `${base}?command=APPEND&media_id=${encodeURIComponent(mediaId)}&segment_index=${segment}`;
      console.info(`XHMedia APPEND segment=${segment} bytes=${chunk.length}`);
      await XApi.uploadForm(appendUrl, appendHeaders, body.buffer as ArrayBuffer);
    }

    const finalUrl = `${base}?command=FINALIZE&media_id=${encodeURIComponent(mediaId)}`;
    console.info('XHMedia FINALIZE');
    const finalText = await XApi.uploadForm(finalUrl, headers);
    console.info(`XHMedia FINALIZE response ${finalText.substring(0, 160)}`);
    const finalRoot = asObj(JSON.parse(finalText) as Object);
    const processing = asObj(finalRoot == null ? null : finalRoot['processing_info']);
    if (processing != null) {
      let state = asString(processing['state']);
      let checks = 0;
      while (state != 'succeeded' && state != 'failed' && checks < 30) {
        const info = asObj(processing['error']);
        if (state == 'failed') break;
        await new Promise<void>((resolve) => setTimeout(resolve, 1000));
        const statusUrl = `${base}?command=STATUS&media_id=${encodeURIComponent(mediaId)}`;
        const statusText = await XApi.uploadForm(statusUrl, headers);
        const statusRoot = asObj(JSON.parse(statusText) as Object);
        const p = asObj(statusRoot == null ? null : statusRoot['processing_info']);
        state = asString(p == null ? null : p['state']);
        checks++;
      }
      if (state == 'failed') throw new Error('视频转码失败');
    }
    try {
      const metaHeaders = XApi.headers(cookie);
      metaHeaders['content-type'] = 'application/json';
      metaHeaders['referer'] = 'https://x.com/compose/post';
      const meta = http.createHttp();
      try {
        await meta.request('https://x.com/i/api/1.1/media/metadata/create.json', {
          method: http.RequestMethod.POST,
          header: metaHeaders,
          extraData: JSON.stringify(XApi.mediaMetadataBody(mediaId)),
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 20000,
          readTimeout: 30000
        });
      } finally {
        meta.destroy();
      }
    } catch (e) {
      console.info(`XHMedia metadata failed: ${e}`);
    }
    return mediaId;
  }

  static async updateProfileImage(cookie: string, path: string): Promise<void> {
    const cleanPath = path.startsWith('file://') ? path.substring(7) : path;
    const file = fileIo.openSync(cleanPath, fileIo.OpenMode.READ_ONLY);
    let bytes = new ArrayBuffer(0);
    try {
      const stat = fileIo.statSync(file.fd);
      bytes = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, bytes);
    } finally {
      fileIo.closeSync(file);
    }
    const base64 = new util.Base64Helper().encodeToStringSync(new Uint8Array(bytes));
    const request = http.createHttp();
    try {
      const headers = XApi.headers(cookie);
      headers['content-type'] = 'application/x-www-form-urlencoded';
      const response = await request.request('https://x.com/i/api/1.1/account/update_profile_image', {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: `image=${encodeURIComponent(base64)}&return_user=true`,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 60000
      });
      const text = response.result as string;
      console.info(`XHProfileImage status=${response.responseCode} body=${text.substring(0, 120)}`);
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`头像上传 HTTP ${response.responseCode}`);
      }
      const root = asObj(JSON.parse(text) as Object);
      const errors = asArr(root == null ? null : root['errors']);
      if (errors.length > 0) {
        const first = asObj(errors[0]);
        throw new Error(asString(first == null ? null : first['message']));
      }
    } finally {
      request.destroy();
    }
  }

  static async updateProfile(cookie: string, name: string, description: string,
    location: string, website: string, birthDate: string): Promise<void> {
    const fields: string[] = [];
    fields.push('return_user=true');
    fields.push(`name=${encodeURIComponent(name)}`);
    fields.push(`description=${encodeURIComponent(description)}`);
    fields.push(`location=${encodeURIComponent(location)}`);
    fields.push(`url=${encodeURIComponent(website)}`);
    if (birthDate.length > 0) fields.push(`birthdate=${encodeURIComponent(birthDate)}`);
    const body = fields.join('&');
    const request = http.createHttp();
    try {
      const headers = XApi.headers(cookie);
      headers['content-type'] = 'application/x-www-form-urlencoded';
      const response = await request.request('https://x.com/i/api/1.1/account/update_profile', {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 30000
      });
      const text = response.result as string;
      console.info(`XHProfileUpdate status=${response.responseCode} body=${text.substring(0, 160)}`);
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode} ${text.substring(0, 120)}`);
      }
      const root = asObj(JSON.parse(text) as Object);
      const errors = asArr(root == null ? null : root['errors']);
      if (errors.length > 0) {
        const first = asObj(errors[0]);
        throw new Error(asString(first == null ? null : first['message']));
      }
    } finally {
      request.destroy();
    }
  }

  static async createTweet(cookie: string, text: string, replyToId: string, quoteUrl: string, mediaIds: string[] = []): Promise<void> {
    const entities: Object[] = [];
    for (const id of mediaIds) {
      const entity: Record<string, Object> = { 'media_id': id, 'tagged_users': [] };
      entities.push(entity);
    }
    const media: Record<string, Object> = {
      'media_entities': entities,
      'possibly_sensitive': false
    };
    const variables: Record<string, Object> = {
      'tweet_text': text,
      'dark_request': false,
      'media': media,
      'semantic_annotation_ids': []
    };
    if (replyToId.length > 0) {
      const reply: Record<string, Object> = {
        'in_reply_to_tweet_id': replyToId,
        'exclude_reply_user_ids': []
      };
      variables['reply'] = reply;
    }
    if (quoteUrl.length > 0) {
      variables['attachment_url'] = quoteUrl;
    }
    try {
      console.info(`XHCreate text=${text.substring(0, 80)} media=${mediaIds.length}`);
      const textResult = await XApi.mutate(cookie, 'CreateTweet', variables);
      const root = asObj(JSON.parse(textResult) as Object);
      const data = asObj(root == null ? null : root['data']);
      const create = asObj(data == null ? null : data['create_tweet']);
      const results = asObj(create == null ? null : create['tweet_results']);
      const result = asObj(results == null ? null : results['result']);
      const id = asString(result == null ? null : result['rest_id']);
      if (id.length == 0) throw new Error('X 未返回新推文 ID');
    } catch (e) {
      if (mediaIds.length > 0) throw e as Error;
      await XApi.createTweetRest(cookie, text, replyToId, quoteUrl);
    }
  }

  private static async createTweetRest(cookie: string, text: string, replyToId: string,
    quoteUrl: string): Promise<void> {
    let body = `status=${encodeURIComponent(text)}&tweet_mode=extended`;
    if (replyToId.length > 0) {
      body += `&in_reply_to_status_id=${encodeURIComponent(replyToId)}&auto_populate_reply_metadata=true`;
    }
    if (quoteUrl.length > 0) {
      body += `&attachment_url=${encodeURIComponent(quoteUrl)}`;
    }
    await XApi.restPost(cookie, 'https://x.com/i/api/1.1/statuses/update.json', body);
  }


  static async viewerProfile(cookie: string): Promise<UserProfile> {
    const queryId = '_8ClT24oZ8tpylf_OSuNdg';
    const url = `https://x.com/i/api/graphql/${queryId}/Viewer` +
      `?variables=${encodeURIComponent('{}')}` +
      `&features=${encodeURIComponent(JSON.stringify(READ_FEATURES))}`;
    const request = http.createHttp();
    let text = '';
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: XApi.headers(cookie),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      text = response.result as string;
    } finally {
      request.destroy();
    }
    const root = asObj(JSON.parse(text) as Object);
    const data = asObj(root == null ? null : root['data']);
    const viewer = asObj(data == null ? null : data['viewer']);
    const userResults = asObj(viewer == null ? null : viewer['user_results']);
    const result = asObj(userResults == null ? null : userResults['result']);
    if (result == null) throw new Error('Viewer 未返回用户资料');
    const legacy = asObj(result['legacy']);
    const core = asObj(result['core']);
    const avatar = asObj(result['avatar']);
    const profile = new UserProfile();
    profile.id = asString(result['rest_id']);
    profile.name = asString(core == null ? null : core['name']);
    if (profile.name.length == 0) profile.name = asString(legacy == null ? null : legacy['name']);
    profile.handle = asString(core == null ? null : core['screen_name']);
    if (profile.handle.length == 0) profile.handle = asString(legacy == null ? null : legacy['screen_name']);
    profile.description = asString(legacy == null ? null : legacy['description']);
    profile.avatarUrl = asString(avatar == null ? null : avatar['image_url']);
    if (profile.avatarUrl.length == 0) profile.avatarUrl = asString(legacy == null ? null : legacy['profile_image_url_https']);
    profile.bannerUrl = asString(legacy == null ? null : legacy['profile_banner_url']);
    profile.followers = asNumber(legacy == null ? null : legacy['followers_count']);
    profile.following = asNumber(legacy == null ? null : legacy['friends_count']);
    profile.verified = result['is_blue_verified'] == true || (legacy != null && legacy['verified'] == true);
    profile.createdAt = asString(core == null ? null : core['created_at']);
    if (profile.createdAt.length == 0) profile.createdAt = asString(legacy == null ? null : legacy['created_at']);
    profile.location = asString(legacy == null ? null : legacy['location']);
    const entities = asObj(legacy == null ? null : legacy['entities']);
    const urlEntity = asObj(entities == null ? null : entities['url']);
    const urlList = asArr(urlEntity == null ? null : urlEntity['urls']);
    if (urlList.length > 0) {
      const firstUrl = asObj(urlList[0]);
      profile.website = asString(firstUrl == null ? null : firstUrl['expanded_url']);
    }
    profile.birthDate = asString(legacy == null ? null : legacy['birthdate']);
    if (profile.id.length == 0) throw new Error('Viewer 未返回用户 ID');
    return profile;
  }

  static async viewerId(cookie: string): Promise<string> {
    return (await XApi.viewerProfile(cookie)).id;
  }

  static async forYou(cookie: string, cursor: string): Promise<HomeResult> {
    // Without a captured WebView bundle, prefer the REST timeline instead of
    // waiting for a queryId scan that may never find HomeTimeline.
    if (!QueryIds.hasBundles()) {
      try {
        return await XApi.homeLatestRest(cookie, cursor);
      } catch (e) {
        // Fall through to GraphQL.
      }
    }
    try {
      return await XApi.homeGraphql(cookie, cursor, 'HomeTimeline', true);
    } catch (e) {
      return await XApi.homeGraphql(cookie, cursor, 'HomeLatestTimeline', true);
    }
  }


  static async tweetDetail(cookie: string, tweetId: string): Promise<HomeResult> {
    try {
      return await XApi.tweetDetailGraphql(cookie, tweetId);
    } catch (e) {
      return await XApi.tweetDetailRest(cookie, tweetId);
    }
  }

  private static async tweetDetailGraphql(cookie: string, tweetId: string): Promise<HomeResult> {
    const queryId = await QueryIds.resolve(cookie, 'TweetDetail');
    const variables: Record<string, Object> = {
      'focalTweetId': tweetId,
      'with_rux_injections': false,
      'includePromotedContent': false,
      'withCommunity': true,
      'withBirdwatchNotes': true,
      'withVoice': true,
      'withV2Timeline': true
    };
    const fieldToggles: Record<string, Object> = {
      'withArticleRichContentState': true,
      'withArticlePlainText': false,
      'withGrokAnalyze': false,
      'withDisallowedReplyControls': false
    };
    const url = `https://x.com/i/api/graphql/${queryId}/TweetDetail` +
      `?variables=${encodeURIComponent(JSON.stringify(variables))}` +
      `&features=${encodeURIComponent(JSON.stringify(READ_FEATURES))}` +
      `&fieldToggles=${encodeURIComponent(JSON.stringify(fieldToggles))}`;
    const request = http.createHttp();
    let text = '';
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: XApi.headers(cookie),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      text = response.result as string;
    } finally {
      request.destroy();
    }

    const root = asObj(JSON.parse(text) as Object);
    const data = asObj(root == null ? null : root['data']);
    const result = new HomeResult();

    // Focal tweet (some query variants return it separately).
    const tweetResult = asObj(data == null ? null : data['tweetResult']);
    const focal = asObj(tweetResult == null ? null : tweetResult['result']);
    if (focal != null) {
      const tweetResults: Record<string, Object> = { 'result': focal };
      const itemContent: Record<string, Object> = { 'tweet_results': tweetResults };
      const content: Record<string, Object> = { 'itemContent': itemContent };
      const synthetic: Record<string, Object> = { 'content': content };
      const item = parseTweet(synthetic);
      if (item != null && item.id.length > 0) result.tweets.push(item);
    }

    const threaded = asObj(data == null ? null : data['threaded_conversation_with_injections_v2']);
    const instructions = asArr(threaded == null ? null : threaded['instructions']);
    for (const rawInstruction of instructions) {
      const instruction = asObj(rawInstruction);
      if (instruction == null || asString(instruction['type']) != 'TimelineAddEntries') continue;
      for (const rawEntry of asArr(instruction['entries'])) {
        const entry = asObj(rawEntry);
        if (entry == null) continue;
        const entryId = asString(entry['entryId']);
        if (isPromotedEntry(entry)) continue;
        if (entryId.indexOf('tweet-') >= 0) {
          const item = parseTweet(entry);
          if (item != null && item.id.length > 0) result.tweets.push(item);
          continue;
        }
        if (entryId.indexOf('conversationthread-') >= 0) {
          const content = asObj(entry['content']);
          for (const rawItem of asArr(content == null ? null : content['items'])) {
            const wrapped = asObj(rawItem);
            const inner = asObj(wrapped == null ? null : wrapped['item']);
            if (inner == null) continue;
            const synthetic: Record<string, Object> = { 'content': inner };
            const item = parseTweet(synthetic);
            if (item != null && item.id.length > 0) {
              if (!result.tweets.some((t: TweetItem) => t.id == item.id)) result.tweets.push(item);
            }
          }
        }
      }
    }
    if (result.tweets.length == 0) {
      throw new Error('推文详情为空');
    }
    return result;
  }



  private static async tweetDetailRest(cookie: string, tweetId: string): Promise<HomeResult> {
    const request = http.createHttp();
    const result = new HomeResult();
    try {
      const showUrl = `https://x.com/i/api/1.1/statuses/show.json?id=${encodeURIComponent(tweetId)}` +
        `&tweet_mode=extended&include_entities=true`;
      const response = await request.request(showUrl, {
        method: http.RequestMethod.GET,
        header: XApi.headers(cookie),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (response.responseCode >= 200 && response.responseCode < 300) {
        const focused = parseRestTweet(JSON.parse(response.result as string) as Object);
        if (focused != null) result.tweets.push(focused);
      }

      const convUrl = `https://x.com/i/api/2/timeline/conversation/${encodeURIComponent(tweetId)}.json` +
        `?count=20&tweet_mode=extended&include_entities=true`;
      const conv = await request.request(convUrl, {
        method: http.RequestMethod.GET,
        header: XApi.headers(cookie),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (conv.responseCode >= 200 && conv.responseCode < 300) {
        const root = asObj(JSON.parse(conv.result as string) as Object);
        const globalObjects = asObj(root == null ? null : root['globalObjects']);
        const tweets = asObj(globalObjects == null ? null : globalObjects['tweets']);
        if (tweets != null) {
          for (const key of Object.keys(tweets)) {
            const item = parseRestTweet(tweets[key] as Object);
            if (item != null && item.id.length > 0 &&
              !result.tweets.some((t: TweetItem) => t.id == item.id)) {
              result.tweets.push(item);
            }
          }
        }
      }
    } finally {
      request.destroy();
    }
    if (result.tweets.length == 0) throw new Error('推文详情为空（REST）');
    return result;
  }

  static async notifications(cookie: string): Promise<NotificationItem[]> {
    return (await XApi.notificationsPage(cookie, '')).items;
  }

  static async notificationsPage(cookie: string, cursor: string): Promise<NotificationPage> {
    try {
      return await XApi.notificationsGraphql(cookie, cursor);
    } catch (e) {
      return await XApi.notificationsRest(cookie);
    }
  }

  private static async notificationsGraphql(cookie: string, cursor: string): Promise<NotificationPage> {
    let queryId = '';
    let operation = 'NotificationsTimeline';
    try {
      queryId = await QueryIds.resolve(cookie, 'NotificationsTimeline');
    } catch (e) {
      operation = 'Notifications';
      queryId = await QueryIds.resolve(cookie, 'Notifications');
    }
    const variables: Record<string, Object> = {
      'count': 20,
      'includePromotedContent': false,
      'withClientEventToken': false,
      'withBirdwatchNotes': false,
      'withVoice': true,
      'timeline_type': 'All'
    };
    if (cursor.length > 0) variables['cursor'] = cursor;
    let text = '';
    try {
      text = await XApi.graphqlGet(cookie, queryId, operation, variables);
    } catch (e) {
      if (queryId != '8kmedJD_u653xqEjZIS7yA') {
        text = await XApi.graphqlGet(cookie, '8kmedJD_u653xqEjZIS7yA', 'NotificationsTimeline', variables);
      } else {
        throw new Error(`${e}`);
      }
    }
    const root = asObj(JSON.parse(text) as Object);
    const data = asObj(root == null ? null : root['data']);
    let urt = asObj(data == null ? null : (data['notifications_urt'] != undefined ? data['notifications_urt'] : data['notifications']));
    if (urt == null && data != null) {
      const viewer = asObj(data['viewer_v2']);
      const userResults = asObj(viewer == null ? null : viewer['user_results']);
      const userResult = asObj(userResults == null ? null : userResults['result']);
      const notificationTimeline = asObj(userResult == null ? null : userResult['notification_timeline']);
      if (notificationTimeline != null) {
        urt = asObj(notificationTimeline['timeline']);
      }
    }
    const instructions = asArr(urt == null ? null : urt['instructions']);
    const page = new NotificationPage();
    const result: NotificationItem[] = page.items;
    for (const rawInstruction of instructions) {
      const instruction = asObj(rawInstruction);
      if (instruction == null || asString(instruction['type']) != 'TimelineAddEntries') continue;
      for (const rawEntry of asArr(instruction['entries'])) {
        const entry = asObj(rawEntry);
        if (entry == null) continue;
        const entryId = asString(entry['entryId']);
        if (entryId.indexOf('cursor-bottom') >= 0) {
          const content = asObj(entry['content']);
          page.cursor = asString(content == null ? null : content['value']);
          continue;
        }
        if (entryId.indexOf('notification-') < 0) continue;
        const content = asObj(entry['content']);
        const itemContent = asObj(content == null ? null : content['itemContent']);
        const notificationResults = asObj(itemContent == null ? null : itemContent['notification_results']);
        const notification = asObj(notificationResults == null ? null : notificationResults['result']);
        if (notification == null) continue;
        const item = new NotificationItem();
        item.id = asString(notification['id']);
        item.type = asString(notification['notification_type']);
        item.message = asString(notification['message']);
        const fromUsers = asArr(notification['from_users']);
        if (fromUsers.length > 0) {
          const user = asObj(fromUsers[0]);
          if (user != null) {
            item.authorName = asString(user['name']);
            item.authorHandle = asString(user['screen_name']);
            item.avatarUrl = asString(user['profile_image_url_https']);
          }
        }
        const tweetResults = asObj(notification['tweet_results']);
        const tweet = asObj(tweetResults == null ? null : tweetResults['result']);
        if (tweet != null) {
          item.tweetId = asString(tweet['rest_id']);
        }
        if (item.id.length > 0) result.push(item);
      }
    }
    return page;
  }


  static async userByRestId(cookie: string, userId: string): Promise<UserProfile> {
    const queryId = await QueryIds.resolve(cookie, 'UserByRestId');
    const variables: Record<string, Object> = {
      'userId': userId,
      'withSafetyModeUserFields': true
    };
    const url = `https://x.com/i/api/graphql/${queryId}/UserByRestId` +
      `?variables=${encodeURIComponent(JSON.stringify(variables))}` +
      `&features=${encodeURIComponent(JSON.stringify(READ_FEATURES))}`;
    const request = http.createHttp();
    let text = '';
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: XApi.headers(cookie),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      text = response.result as string;
    } finally {
      request.destroy();
    }
    const root = asObj(JSON.parse(text) as Object);
    const data = asObj(root == null ? null : root['data']);
    const user = asObj(data == null ? null : data['user']);
    const result = asObj(user == null ? null : user['result']);
    const legacy = asObj(result == null ? null : result['legacy']);
    if (legacy == null) throw new Error('用户资料为空');
    const profile = new UserProfile();
    profile.id = asString(result == null ? null : result['rest_id']);
    profile.name = asString(legacy['name']);
    profile.handle = asString(legacy['screen_name']);
    profile.description = asString(legacy['description']);
    profile.avatarUrl = asString(legacy['profile_image_url_https']);
    profile.bannerUrl = asString(legacy['profile_banner_url']);
    profile.followers = asNumber(legacy['followers_count']);
    profile.following = asNumber(legacy['friends_count']);
    return profile;
  }


  private static async notificationsRest(cookie: string): Promise<NotificationPage> {
    const url = 'https://x.com/i/api/1.1/notifications/all.json' +
      '?count=20&tweet_mode=extended&include_entities=true';
    const request = http.createHttp();
    let text = '';
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: XApi.headers(cookie),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      text = response.result as string;
    } finally {
      request.destroy();
    }
    const root = asObj(JSON.parse(text) as Object);
    const globalObjects = asObj(root == null ? null : root['globalObjects']);
    const users = asObj(globalObjects == null ? null : globalObjects['users']);
    const timeline = asObj(root == null ? null : root['timeline']);
    const instructions = asArr(timeline == null ? null : timeline['instructions']);
    const page = new NotificationPage();
    const result: NotificationItem[] = page.items;
    for (const rawInstruction of instructions) {
      const instruction = asObj(rawInstruction);
      if (instruction == null) continue;
      const addEntries = asObj(instruction['addEntries']);
      for (const rawEntry of asArr(addEntries == null ? null : addEntries['entries'])) {
        const entry = asObj(rawEntry);
        if (entry == null) continue;
        const content = asObj(entry['content']);
        const n = asObj(content == null ? null : content['notification']);
        if (n == null) continue;
        const item = new NotificationItem();
        item.id = asText(n['id']);
        item.type = asText(n['notification_type']);
        item.message = asText(n['message']);
        item.tweetId = asText(n['tweet_id']);
        const fromId = asText(n['from_user_id']);
        const user = asObj(users == null ? null : users[fromId]);
        if (user != null) {
          item.authorName = asText(user['name']);
          item.authorHandle = asText(user['screen_name']);
          item.avatarUrl = asText(user['profile_image_url_https']);
        }
        if (item.id.length > 0) result.push(item);
      }
    }
    if (result.length == 0) throw new Error('通知为空（REST）');
    return page;
  }



  private static profileFromUserResult(result: Record<string, Object>): UserProfile {
    const legacy = asObj(result['legacy']);
    const core = asObj(result['core']);
    const avatar = asObj(result['avatar']);
    const p = new UserProfile();
    p.id = asString(result['rest_id']);
    p.name = asString(core == null ? null : core['name']);
    if (p.name.length == 0) p.name = asString(legacy == null ? null : legacy['name']);
    p.handle = asString(core == null ? null : core['screen_name']);
    if (p.handle.length == 0) p.handle = asString(legacy == null ? null : legacy['screen_name']);
    p.description = asString(legacy == null ? null : legacy['description']);
    p.avatarUrl = asString(avatar == null ? null : avatar['image_url']);
    if (p.avatarUrl.length == 0) p.avatarUrl = asString(legacy == null ? null : legacy['profile_image_url_https']);
    p.bannerUrl = asString(legacy == null ? null : legacy['profile_banner_url']);
    p.followers = asNumber(legacy == null ? null : legacy['followers_count']);
    p.following = asNumber(legacy == null ? null : legacy['friends_count']);
    p.verified = result['is_blue_verified'] == true || (legacy != null && legacy['verified'] == true);
    p.createdAt = asString(core == null ? null : core['created_at']);
    if (p.createdAt.length == 0) p.createdAt = asString(legacy == null ? null : legacy['created_at']);
    return p;
  }

  static async userList(cookie: string, userId: string, kind: string, cursor: string = ''): Promise<UserSearchResult> {
    const result = new UserSearchResult();
    if (kind == 'followers') {
      let url = `https://x.com/i/api/1.1/followers/list.json?user_id=${encodeURIComponent(userId)}&count=20`;
      if (cursor.length > 0) url += `&cursor=${encodeURIComponent(cursor)}`;
      const request = http.createHttp();
      let text = '';
      try {
        const response = await request.request(url, {
          method: http.RequestMethod.GET,
          header: XApi.headers(cookie),
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: 20000,
          readTimeout: 20000
        });
        if (response.responseCode < 200 || response.responseCode >= 300) throw new Error(`HTTP ${response.responseCode}`);
        text = response.result as string;
      } finally {
        request.destroy();
      }
      const root = asObj(JSON.parse(text) as Object);
      const users = asArr(root == null ? null : root['users']);
      for (const raw of users) {
        const u = asObj(raw);
        if (u == null) continue;
        const p = new UserProfile();
        p.id = asString(u['id_str']);
        if (p.id.length == 0) p.id = asString(u['id']);
        p.name = asString(u['name']);
        p.handle = asString(u['screen_name']);
        p.description = asString(u['description']);
        p.avatarUrl = asString(u['profile_image_url_https']);
        p.followers = asNumber(u['followers_count']);
        p.following = asNumber(u['friends_count']);
        p.verified = u['verified'] == true;
        p.createdAt = asString(u['created_at']);
        if (p.handle.length > 0) result.users.push(p);
      }
      result.cursor = asString(root == null ? null : root['next_cursor_str']);
      if (result.cursor == '0') result.cursor = '';
      return result;
    }

    const candidates: string[] = ['zx6e-TLzRkeDO_a7p4b3JQ', 'OLm4oHZBfqWx8jbcEhWoFw'];
    const variables: Record<string, Object> = {
      'userId': userId,
      'count': 20,
      'includePromotedContent': false
    };
    if (cursor.length > 0) variables['cursor'] = cursor;
    let text = '';
    for (const qid of candidates) {
      try {
        text = await XApi.graphqlGet(cookie, qid, 'Following', variables);
        if (text.length > 0) break;
      } catch (e) {}
    }
    if (text.length == 0) throw new Error('关注列表加载失败');
    const root = asObj(JSON.parse(text) as Object);
    const data = asObj(root == null ? null : root['data']);
    const user = asObj(data == null ? null : data['user']);
    const userResult = asObj(user == null ? null : user['result']);
    const timeline = asObj(userResult == null ? null : userResult['timeline']);
    const inner = asObj(timeline == null ? null : timeline['timeline']);
    const instructions = asArr(inner == null ? null : inner['instructions']);
    for (const rawIns of instructions) {
      const ins = asObj(rawIns);
      if (ins == null || asString(ins['type']) != 'TimelineAddEntries') continue;
      for (const rawEntry of asArr(ins['entries'])) {
        const entry = asObj(rawEntry);
        if (entry == null) continue;
        const entryId = asString(entry['entryId']);
        const content = asObj(entry['content']);
        if (entryId.indexOf('cursor-bottom') >= 0) {
          result.cursor = asString(content == null ? null : content['value']);
          continue;
        }
        const itemContent = asObj(content == null ? null : content['itemContent']);
        const userResults = asObj(itemContent == null ? null : itemContent['user_results']);
        const ur = asObj(userResults == null ? null : userResults['result']);
        if (ur == null) continue;
        const p = XApi.profileFromUserResult(ur);
        if (p.handle.length > 0) result.users.push(p);
      }
    }
    return result;
  }

  static async userTweets(cookie: string, userId: string, cursor: string): Promise<HomeResult> {
    const queryId = await QueryIds.resolve(cookie, 'UserTweets');
    const variables: Record<string, Object> = {
      'userId': userId,
      'count': 20,
      'includePromotedContent': false,
      'withVoice': true
    };
    if (cursor.length > 0) variables['cursor'] = cursor;
    const url = `https://x.com/i/api/graphql/${queryId}/UserTweets` +
      `?variables=${encodeURIComponent(JSON.stringify(variables))}` +
      `&features=${encodeURIComponent(JSON.stringify(READ_FEATURES))}`;
    const request = http.createHttp();
    let text = '';
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: XApi.headers(cookie),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      text = response.result as string;
    } finally {
      request.destroy();
    }
    const root = asObj(JSON.parse(text) as Object);
    const data = asObj(root == null ? null : root['data']);
    const user = asObj(data == null ? null : data['user']);
    const resultObj = asObj(user == null ? null : user['result']);
    const timelineV2 = asObj(resultObj == null ? null : resultObj['timeline_v2']);
    const timeline = asObj(timelineV2 == null ? null : timelineV2['timeline']);
    const instructions = asArr(timeline == null ? null : timeline['instructions']);
    const result = new HomeResult();
    for (const rawInstruction of instructions) {
      const instruction = asObj(rawInstruction);
      if (instruction == null || asString(instruction['type']) != 'TimelineAddEntries') continue;
      for (const rawEntry of asArr(instruction['entries'])) {
        const entry = asObj(rawEntry);
        if (entry == null) continue;
        const entryId = asString(entry['entryId']);
        if (entryId.indexOf('cursor-bottom') >= 0) {
          const content = asObj(entry['content']);
          result.cursor = asString(content == null ? null : content['value']);
          continue;
        }
        if (isPromotedEntry(entry)) continue;
        if (entryId.indexOf('tweet-') < 0) continue;
        const item = parseTweet(entry);
        if (item != null && item.id.length > 0) result.tweets.push(item);
      }
    }
    return result;
  }


  static async userByScreenName(cookie: string, screenName: string): Promise<UserProfile> {
    const queryId = await QueryIds.resolve(cookie, 'UserByScreenName');
    const variables: Record<string, Object> = {
      'screen_name': screenName,
      'withSafetyModeUserFields': true
    };
    const url = `https://x.com/i/api/graphql/${queryId}/UserByScreenName` +
      `?variables=${encodeURIComponent(JSON.stringify(variables))}` +
      `&features=${encodeURIComponent(JSON.stringify(READ_FEATURES))}`;
    const request = http.createHttp();
    let text = '';
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: XApi.headers(cookie),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      text = response.result as string;
    } finally {
      request.destroy();
    }
    const root = asObj(JSON.parse(text) as Object);
    const data = asObj(root == null ? null : root['data']);
    const user = asObj(data == null ? null : data['user']);
    const result = asObj(user == null ? null : user['result']);
    const legacy = asObj(result == null ? null : result['legacy']);
    if (legacy == null) throw new Error('用户不存在');
    const profile = new UserProfile();
    profile.id = asString(result == null ? null : result['rest_id']);
    profile.name = asString(legacy['name']);
    profile.handle = asString(legacy['screen_name']);
    profile.description = asString(legacy['description']);
    profile.avatarUrl = asString(legacy['profile_image_url_https']);
    profile.bannerUrl = asString(legacy['profile_banner_url']);
    profile.followers = asNumber(legacy['followers_count']);
    profile.following = asNumber(legacy['friends_count']);
    const core = asObj(result == null ? null : result['core']);
    profile.verified = (result != null && result['is_blue_verified'] == true) || legacy['verified'] == true;
    profile.createdAt = asString(core == null ? null : core['created_at']);
    if (profile.createdAt.length == 0) profile.createdAt = asString(legacy['created_at']);
    return profile;
  }


  static async trends(cookie: string, woeid: number = 1): Promise<TrendItem[]> {
    const request = http.createHttp();
    let text = '';
    try {
      const response = await request.request(`https://x.com/i/api/1.1/trends/place.json?id=${woeid}`, {
        method: http.RequestMethod.GET,
        header: XApi.headers(cookie),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      text = response.result as string;
    } finally {
      request.destroy();
    }
    const parsed = JSON.parse(text) as Object;
    const places = asArr(parsed);
    const result: TrendItem[] = [];
    if (places.length == 0) return result;
    const first = asObj(places[0]);
    const trends = asArr(first == null ? null : first['trends']);
    for (const raw of trends) {
      const obj = asObj(raw);
      if (obj == null) continue;
      const item = new TrendItem();
      item.name = asString(obj['name']);
      item.query = asString(obj['query']);
      item.volume = asNumber(obj['tweet_volume']);
      if (item.name.length > 0) result.push(item);
    }
    return result;
  }



  static async searchUsers(cookie: string, query: string, cursor: string = ''): Promise<UserSearchResult> {
    const variables: Record<string, Object> = {
      'rawQuery': query,
      'count': 20,
      'querySource': 'typed_query',
      'product': 'People',
      'withGrokTranslatedBio': true
    };
    if (cursor.length > 0) variables['cursor'] = cursor;
    const fieldToggles: Record<string, Object> = { 'withArticleRichContentState': false };
    const candidates: string[] = [];
    try { candidates.push(await QueryIds.resolve(cookie, 'SearchTimeline')); } catch (e) {}
    candidates.push('hz_94eVAtrtQo_vO3my7Rw');
    candidates.push('GcXk9vN_d1jUfHNqLacXQA');
    let firstPage: UserSearchResult | null = null;
    let lastError: Error = new Error('用户搜索失败');
    for (const qid of candidates) {
      if (qid.length == 0 || candidates.indexOf(qid) != candidates.lastIndexOf(qid)) continue;
      try {
        const text = await XApi.graphqlPost(cookie, qid, 'SearchTimeline', variables, fieldToggles);
        const root = asObj(JSON.parse(text) as Object);
        if (root != null && asArr(root['errors']).length > 0) continue;
        const data = asObj(root == null ? null : root['data']);
        const search = asObj(data == null ? null : data['search_by_raw_query']);
        const searchTimeline = asObj(search == null ? null : search['search_timeline']);
        const timeline = asObj(searchTimeline == null ? null : searchTimeline['timeline']);
        const instructions = asArr(timeline == null ? null : timeline['instructions']);
        const result = new UserSearchResult();
        for (const rawInstruction of instructions) {
          const instruction = asObj(rawInstruction);
          if (instruction == null || asString(instruction['type']) != 'TimelineAddEntries') continue;
          for (const rawEntry of asArr(instruction['entries'])) {
            const entry = asObj(rawEntry);
            if (entry == null) continue;
            const entryId = asString(entry['entryId']);
            if (entryId.indexOf('cursor-bottom') >= 0) {
              const content = asObj(entry['content']);
              result.cursor = asString(content == null ? null : content['value']);
              continue;
            }
            const content = asObj(entry['content']);
            const itemContent = asObj(content == null ? null : content['itemContent']);
            const userResults = asObj(itemContent == null ? null : itemContent['user_results']);
            const userResult = asObj(userResults == null ? null : userResults['result']);
            if (userResult == null) continue;
            const legacy = asObj(userResult['legacy']);
            const core = asObj(userResult['core']);
            const avatar = asObj(userResult['avatar']);
            const profile = new UserProfile();
            profile.id = asString(userResult['rest_id']);
            profile.name = asString(legacy == null ? null : legacy['name']);
            profile.handle = asString(legacy == null ? null : legacy['screen_name']);
            profile.description = asString(legacy == null ? null : legacy['description']);
            profile.avatarUrl = asString(legacy == null ? null : legacy['profile_image_url_https']);
            if (profile.name.length == 0) profile.name = asString(core == null ? null : core['name']);
            if (profile.handle.length == 0) profile.handle = asString(core == null ? null : core['screen_name']);
            if (profile.avatarUrl.length == 0) profile.avatarUrl = asString(avatar == null ? null : avatar['image_url']);
            profile.followers = asNumber(legacy == null ? null : legacy['followers_count']);
            profile.following = asNumber(legacy == null ? null : legacy['friends_count']);
            if (profile.handle.length > 0) result.users.push(profile);
          }
        }
        if (firstPage == null) firstPage = result;
        if (result.users.length > 0) return result;
      } catch (e) {
        lastError = e as Error;
      }
    }
    if (firstPage != null) return firstPage;
    throw lastError;
  }

  private static translationCache: Map<string, string> = new Map();

  static async translateTweet(cookie: string, tweetId: string, destLang: string): Promise<string> {
    const key = `${tweetId}:${destLang}`;
    const cached = XApi.translationCache.get(key);
    if (cached != undefined && cached.length > 0) return cached;
    const queryId = 'hE1HCUzioO9QSLpvIBvvYA';
    const variables: Record<string, Object> = {
      'includeTweetImpression': true,
      'includeHasBirdwatchNotes': false,
      'includeEditPerspective': false,
      'tweet_id': tweetId,
      'includeEditControl': true
    };
    const url = `https://x.com/i/api/graphql/${queryId}/TranslateTweetQuery` +
      `?variables=${encodeURIComponent(JSON.stringify(variables))}` +
      `&features=${encodeURIComponent(JSON.stringify({}))}`;
    const headers = XApi.headers(cookie);
    headers['x-twitter-client-language'] = destLang;
    headers['accept-language'] = destLang;
    const request = http.createHttp();
    let text = '';
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      text = response.result as string;
    } finally {
      request.destroy();
    }
    const root = asObj(JSON.parse(text) as Object);
    const data = asObj(root == null ? null : root['data']);
    const tweetResult = asObj(data == null ? null : data['tweet_result']);
    const result = asObj(tweetResult == null ? null : tweetResult['result']);
    const translated = asObj(result == null ? null : result['translated']);
    const translation = asString(translated == null ? null : translated['translation']);
    if (translation.length == 0) throw new Error('没有可用翻译');
    if (XApi.translationCache.size >= 80) {
      const keys: string[] = [];
      XApi.translationCache.forEach((value: string, k: string) => { keys.push(k); });
      if (keys.length > 0) XApi.translationCache.delete(keys[0]);
    }
    XApi.translationCache.set(key, translation);
    return translation;
  }

}
