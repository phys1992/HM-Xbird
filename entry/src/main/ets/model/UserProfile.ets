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
}

export class UserSearchResult {
  users: UserProfile[] = [];
  cursor: string = '';
}
