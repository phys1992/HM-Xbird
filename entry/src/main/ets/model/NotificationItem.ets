export class NotificationItem {
  id: string = '';
  type: string = '';
  message: string = '';
  authorName: string = '';
  authorHandle: string = '';
  avatarUrl: string = '';
  tweetId: string = '';
}

export class NotificationPage {
  items: NotificationItem[] = [];
  cursor: string = '';
}
