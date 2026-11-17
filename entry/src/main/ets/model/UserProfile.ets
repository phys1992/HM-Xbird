export class UserProfile {
  id: string = '';
  name: string = '';
  handle: string = '';
  description: string = '';
  avatarUrl: string = '';
  bannerUrl: string = '';
  followers: number = 0;
  following: number = 0;
  verified: boolean = false;
  createdAt: string = '';
  location: string = '';
  website: string = '';
  birthDate: string = '';
  isFollowing: boolean = false;
  isSelf: boolean = false;
  cachedAt: number = 0;
  avatarSource: string = '';
  bannerSource: string = '';
  avatarPath: string = '';
  bannerPath: string = '';
  avatarBytes: number = 0;
  bannerBytes: number = 0;
}

export class UserSearchResult {
  users: UserProfile[] = [];
  cursor: string = '';
}
