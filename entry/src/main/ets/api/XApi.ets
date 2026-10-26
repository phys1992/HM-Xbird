import { http } from '@kit.NetworkKit';
import { QueryIds } from './QueryIds';
import { TweetItem } from '../model/TweetItem';

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
  'responsive_web_media_download_video_enabled': false
};

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
  if (legacy != null) {
    item.authorName = asString(legacy['name']);
    item.authorHandle = asString(legacy['screen_name']);
    item.avatarUrl = asString(legacy['profile_image_url_https']);
  }
  return item;
}

function parseTweet(entry: Record<string, Object>): TweetItem | null {
  const content = asObj(entry['content']);
  const itemContent = asObj(content == null ? null : content['itemContent']);
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
  item.createdAt = asString(legacy['created_at']);
  item.replyCount = asNumber(legacy['reply_count']);
  item.retweetCount = asNumber(legacy['retweet_count']);
  item.likeCount = asNumber(legacy['favorite_count']);

  const extended = asObj(legacy['extended_entities']);
  const media = asArr(extended == null ? null : extended['media']);
  if (media.length > 0) {
    const first = asObj(media[0]);
    if (first != null && asString(first['type']) == 'photo') {
      item.imageUrl = asString(first['media_url_https']);
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
        throw new Error(`时间线加载失败：REST ${restError}；GraphQL ${graphqlError}`);
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
    const queryId = await QueryIds.resolve(cookie, 'HomeLatestTimeline');
    const variables: Record<string, Object> = {
      'count': 20,
      'includePromotedContent': false,
      'latestControlAvailable': true,
      'requestContext': 'launch',
      'withCommunity': true
    };
    if (cursor.length > 0) {
      variables['cursor'] = cursor;
    }

    const url = `https://x.com/i/api/graphql/${queryId}/HomeLatestTimeline` +
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
        if (entryId.indexOf('tweet-') < 0) continue;
        const tweet = parseTweet(entry);
        if (tweet != null && tweet.id.length > 0) {
          result.tweets.push(tweet);
        }
      }
    }
    return result;
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
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`HTTP ${response.responseCode} ${text.substring(0, 200)}`);
      }
      return text;
    } finally {
      request.destroy();
    }
  }

  static async search(cookie: string, query: string): Promise<HomeResult> {
    const queryId = await QueryIds.resolve(cookie, 'SearchTimeline');
    const variables: Record<string, Object> = {
      'rawQuery': query,
      'count': 20,
      'querySource': 'typed_query',
      'product': 'Top'
    };
    const url = `https://x.com/i/api/graphql/${queryId}/SearchTimeline` +
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
        throw new Error(`搜索失败：HTTP ${response.responseCode}`);
      }
      text = response.result as string;
    } finally {
      request.destroy();
    }
    const root = asObj(JSON.parse(text) as Object);
    const data = asObj(root == null ? null : root['data']);
    const search = asObj(data == null ? null : data['search_by_raw_query']);
    const timeline = asObj(search == null ? null : search['search_timeline']);
    return XApi.parseTimeline(timeline);
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
        if (entryId.indexOf('tweet-') < 0) continue;
        const tweet = parseTweet(entry);
        if (tweet != null && tweet.id.length > 0) result.tweets.push(tweet);
      }
    }
    return result;
  }


  static async setFavorite(cookie: string, tweetId: string, favorite: boolean): Promise<void> {
    await XApi.mutate(cookie, favorite ? 'FavoriteTweet' : 'UnfavoriteTweet', {
      'tweet_id': tweetId
    });
  }

  static async setRetweet(cookie: string, tweetId: string, retweet: boolean): Promise<void> {
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
  }

  static async createTweet(cookie: string, text: string, replyToId: string, quoteUrl: string): Promise<void> {
    const media: Record<string, Object> = {
      'media_entities': [],
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
    await XApi.mutate(cookie, 'CreateTweet', variables);
  }


  static async forYou(cookie: string, cursor: string): Promise<HomeResult> {
    const queryId = await QueryIds.resolve(cookie, 'HomeTimeline');
    const variables: Record<string, Object> = {
      'count': 20,
      'includePromotedContent': true,
      'latestControlAvailable': true,
      'requestContext': 'launch',
      'withCommunity': true
    };
    if (cursor.length > 0) variables['cursor'] = cursor;
    const url = `https://x.com/i/api/graphql/${queryId}/HomeTimeline` +
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
    return XApi.parseTimeline(timeline);
  }

}
