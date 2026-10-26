import { http } from '@kit.NetworkKit';

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36';

export class QueryIds {
  private static cache: Map<string, string> = new Map();
  private static bundleUrls: string[] = [];

  static setBundleUrls(urls: string[]): void {
    QueryIds.bundleUrls = urls;
    QueryIds.cache.clear();
  }

  private static headers(cookie: string): Record<string, string> {
    return {
      'cookie': cookie,
      'user-agent': USER_AGENT,
      'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'accept-language': 'en-US,en;q=0.9'
    };
  }

  private static async fetchText(url: string, cookie: string): Promise<string> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: QueryIds.headers(cookie),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (response.responseCode >= 200 && response.responseCode < 300) {
        return response.result as string;
      }
      return '';
    } finally {
      request.destroy();
    }
  }

  private static extract(js: string, operation: string): string {
    const marker = `"${operation}"`;
    let from = 0;
    while (true) {
      const index = js.indexOf(marker, from);
      if (index < 0) return '';
      const start = Math.max(0, index - 500);
      const end = Math.min(js.length, index + marker.length + 500);
      const window = js.substring(start, end);
      const match = window.match(/queryId\s*:\s*"([A-Za-z0-9_-]{8,64})"/);
      if (match != null && match.length > 1) {
        return match[1];
      }
      from = index + 1;
    }
  }

  private static extractFromUrl(url: string, operation: string): string {
    const marker = `/i/api/graphql/`;
    const at = url.indexOf(marker);
    if (at < 0) return '';
    const rest = url.substring(at + marker.length);
    const slash = rest.indexOf('/');
    if (slash <= 0) return '';
    const queryId = rest.substring(0, slash);
    const opName = rest.substring(slash + 1).split('?')[0];
    if (opName == operation && queryId.length > 0) return queryId;
    return '';
  }

  static async resolve(cookie: string, operation: string): Promise<string> {
    const cached = QueryIds.cache.get(operation);
    if (cached != undefined && cached.length > 0) return cached;

    // 0. Best case: the document-start hook captured the real GraphQL URL,
    //    e.g. /i/api/graphql/<queryId>/HomeLatestTimeline?...
    for (const captured of QueryIds.bundleUrls) {
      const id = QueryIds.extractFromUrl(captured, operation);
      if (id.length > 0) {
        QueryIds.cache.set(operation, id);
        return id;
      }
    }

    // 1. Otherwise scan JS bundles captured from the logged-in WebView.
    const urls: string[] = [];
    for (const url of QueryIds.bundleUrls) {
      if (url.indexOf('.js') >= 0 && urls.length < 40) urls.push(url);
    }

    // 1b. Fallback: scrape script tags from the logged-in shell.
    if (urls.length == 0) {
      const html = await QueryIds.fetchText('https://x.com/home', cookie);
      const regex = /src="([^"]+\.js[^"]*)"/g;
      let m = regex.exec(html);
      while (m != null && urls.length < 12) {
        const url = m[1];
        if (url.indexOf('twimg.com') >= 0 || url.indexOf('x.com') >= 0) {
          urls.push(url);
        }
        m = regex.exec(html);
      }
    }

    // 2. Scan bundles for `queryId:"..."` next to the operation name.
    for (const url of urls) {
      const js = await QueryIds.fetchText(url, cookie);
      if (js.length == 0) continue;
      const id = QueryIds.extract(js, operation);
      if (id.length > 0) {
        QueryIds.cache.set(operation, id);
        return id;
      }
    }
    if (operation == 'CreateTweet') {
      return 'uY34Pldm6W89yqswRmPMSQ';
    }
    throw new Error(`无法解析 ${operation} 的 queryId（已扫描 ${urls.length} 个脚本）`);
  }
}
